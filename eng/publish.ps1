[CmdletBinding(DefaultParameterSetName = 'Prepare')]
param(
    [Parameter(ParameterSetName = 'Prepare')][switch] $Prepare,
    [Parameter(ParameterSetName = 'Prepare')][string] $OutputDirectory,
    [Parameter(ParameterSetName = 'Prepare')][string] $ExpectedReleaseCommit,
    [Parameter(ParameterSetName = 'Publish', Mandatory = $true)][switch] $Publish,
    [Parameter(ParameterSetName = 'Test')][switch] $TestPublish,
    [Parameter(ParameterSetName = 'Publish', Mandatory = $true)][string] $CandidateDirectory,
    [Parameter(ParameterSetName = 'Publish', Mandatory = $true)][string] $Confirmation,
    [Parameter(ParameterSetName = 'Publish')][string] $Source = 'https://api.nuget.org/v3/index.json'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repoRoot 'src/DotnetNugetContent/DotnetNugetContent.csproj'
$version = '2.0.0'
$topId = 'dotnet-nuget-content'
$ridId = 'dotnet-nuget-content.win-x64'
$expectedSource = 'https://api.nuget.org/v3/index.json'
$approvalPhrase = 'PUBLISH TO NUGET.ORG'

function Get-PackageIdentity([string] $Path) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entry = @($archive.Entries | Where-Object FullName -Match '\.nuspec$') | Select-Object -First 1
        if (-not $entry) { throw "Package has no nuspec: $Path" }
        $reader = [System.IO.StreamReader]::new($entry.Open())
        try { [xml]$nuspec = $reader.ReadToEnd() } finally { $reader.Dispose() }
        $metadata = $nuspec.SelectSingleNode("//*[local-name()='metadata']")
        return [pscustomobject]@{
            Id = [string]$metadata.SelectSingleNode("*[local-name()='id']").InnerText
            Version = [string]$metadata.SelectSingleNode("*[local-name()='version']").InnerText
        }
    } finally { $archive.Dispose() }
}

function Get-CurrentSourceIdentity {
    $commit = (& git -C $repoRoot rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') { throw 'Unable to identify the current Git revision.' }
    $tree = (& git -C $repoRoot rev-parse 'HEAD^{tree}').Trim()
    if ($LASTEXITCODE -ne 0 -or $tree -notmatch '^[0-9a-f]{40}$') { throw 'Unable to identify the current Git source tree.' }
    $branch = (& git -C $repoRoot branch --show-current).Trim()
    $dirty = [bool](& git -C $repoRoot status --porcelain)
    return [pscustomobject]@{ Commit = $commit; Tree = $tree; Branch = $branch; WorkingTreeClean = -not $dirty }
}

function Assert-ReleaseCommitIdentity($Manifest, $CurrentIdentity) {
    if ($Manifest.expectedReleaseCommit -notmatch '^[0-9a-f]{40}$') { throw 'Final release qualification requires an explicit full expected release commit SHA.' }
    if ($Manifest.sourceCommit -cne $Manifest.expectedReleaseCommit -or $Manifest.actualCommit -cne $Manifest.expectedReleaseCommit -or $CurrentIdentity.Commit -cne $Manifest.expectedReleaseCommit) {
        throw 'Expected, reported, and current Git commit identities must match exactly.'
    }
    if ($Manifest.sourceTree -notmatch '^[0-9a-f]{40}$' -or $CurrentIdentity.Tree -cne $Manifest.sourceTree) { throw 'Candidate source-tree provenance does not match the current expected commit.' }
    if ($Manifest.sourceBranch -cne 'main' -or $CurrentIdentity.Branch -cne 'main') { throw 'Final release qualification and publication require the current main branch.' }
    if ($Manifest.workingTreeClean -ne $true -or $CurrentIdentity.WorkingTreeClean -ne $true) { throw 'Final release qualification and publication require a clean working tree.' }
}

function Get-QualifiedCandidate([string] $Path, $CurrentIdentity = $null) {
    $root = [System.IO.Path]::GetFullPath($Path)
    $manifestPath = Join-Path $root 'candidate.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Candidate manifest not found: $manifestPath" }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.schemaVersion -ne 2 -or $manifest.qualified -ne $true -or $manifest.releaseQualified -ne $true -or $manifest.version -ne $version -or $manifest.sourceCommit -notmatch '^[0-9a-f]{40}$' -or $manifest.sourceTree -notmatch '^[0-9a-f]{40}$' -or $manifest.workingTreeClean -ne $true) {
        throw 'Candidate report is not qualified for the required final merged-source 2.0.0 release.'
    }
    if (-not $CurrentIdentity) { $CurrentIdentity = Get-CurrentSourceIdentity }
    Assert-ReleaseCommitIdentity $manifest $CurrentIdentity
    if ($manifest.qualificationScope -cne 'final-merged-main') { throw 'Only an explicitly qualified final merged main candidate is eligible for publication.' }
    if ($manifest.published -ne $false) { throw 'Candidate report does not establish an unpublished release candidate.' }
    if ($manifest.licenseReview.passed -ne $true) { throw 'Candidate does not contain a passing repository license/identity review.' }
    $gates = @($manifest.validation.regressionTests, $manifest.validation.installedTool, $manifest.validation.native, $manifest.validation.repositoryScale, $manifest.validation.publicationMocks, $manifest.validation.dependencyAudit)
    if ($gates.Count -ne 6) { throw 'Candidate report must contain regression, installed-tool, native, scale, dependency-audit, and publication-mock receipts.' }
    foreach ($gate in $gates) {
        if ($gate.passed -ne $true -or -not $gate.log -or -not $gate.sha256) { throw 'Candidate report is missing a passing validation receipt.' }
        $logPath = Join-Path $root $gate.log
        if (-not (Test-Path -LiteralPath $logPath -PathType Leaf) -or (Get-FileHash -LiteralPath $logPath -Algorithm SHA256).Hash -cne $gate.sha256) {
            throw "Candidate validation receipt is missing or changed: $($gate.log)"
        }
    }
    $scaleReportPath = Join-Path $root $manifest.validation.repositoryScale.report
    if (-not $manifest.validation.repositoryScale.report -or -not (Test-Path -LiteralPath $scaleReportPath -PathType Leaf) -or (Get-FileHash -LiteralPath $scaleReportPath -Algorithm SHA256).Hash -cne $manifest.validation.repositoryScale.reportSha256) {
        throw 'Candidate scale report is missing or its SHA-256 does not match.'
    }
    if (@($manifest.packages).Count -ne 2) { throw 'Candidate must contain exactly the top-level and win-x64 packages.' }
    $ordered = @($manifest.packages | Sort-Object { if ($_.role -eq 'rid') { 0 } elseif ($_.role -eq 'top-level') { 1 } else { 2 } })
    if ($ordered[0].role -ne 'rid' -or $ordered[0].id -ne $ridId -or $ordered[1].role -ne 'top-level' -or $ordered[1].id -ne $topId) {
        throw 'Candidate package identities or publication roles are invalid.'
    }
    foreach ($package in $ordered) {
        if ([System.IO.Path]::GetFileName([string]$package.file) -cne [string]$package.file) { throw 'Candidate package paths must be file names within the candidate directory.' }
        if ($package.version -ne $version) { throw "Candidate package version mismatch: $($package.file)" }
        $packagePath = Join-Path $root $package.file
        if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) { throw "Candidate package missing: $packagePath" }
        $actualHash = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash
        if ($actualHash -cne $package.sha256) { throw "Candidate SHA-256 mismatch: $($package.file)" }
        $identity = Get-PackageIdentity $packagePath
        if ($identity.Id -ne $package.id -or $identity.Version -ne $version) { throw "Candidate nuspec identity mismatch: $($package.file)" }
    }
    return [pscustomobject]@{ Root = $root; Manifest = $manifest; Packages = $ordered }
}

function Assert-PublishApproval([string] $Target, [string] $Phrase) {
    if ($Target -cne $expectedSource) { throw "Publication target must be exactly $expectedSource." }
    if ($Phrase -cne $approvalPhrase) { throw "Publication requires explicit confirmation text: $approvalPhrase" }
}

function Invoke-PublishSequence($Candidate, [scriptblock] $Push) {
    $completed = [System.Collections.Generic.List[string]]::new()
    $script:publishCompleted = @()
    foreach ($package in $Candidate.Packages) {
        $path = Join-Path $Candidate.Root $package.file
        & $Push $path $package.id $package.sha256
        $completed.Add($package.id)
        $script:publishCompleted = $completed.ToArray()
    }
    return $completed.ToArray()
}

function Save-PublicationFailureStatus($Candidate, [string[]] $Completed, [string] $ErrorText, [string] $Path) {
    $completedPackages = @($Completed)
    $status = [ordered]@{
        target = $expectedSource
        sourceCommit = $Candidate.Manifest.sourceCommit
        published = $completedPackages
        failedPackage = if ($completedPackages.Count -eq 0) { $ridId } else { $topId }
        error = $ErrorText
        recovery = if ($completedPackages.Count -eq 1) {
            "RID package $ridId $version was reported accepted. Verify it on NuGet.org, then publish the unchanged top-level package $topId $version from candidate.json; do not rebuild."
        } else {
            "No successful push was reported. Check NuGet.org for $ridId $version before retrying; if absent, correct the cause and retry the same candidate. Do not push $topId until RID package acceptance is confirmed."
        }
    }
    $status | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Invoke-DotnetPush([string] $Path, [string] $Id, [string] $Hash) {
    # The API key is read only for this authorized invocation. dotnet nuget push
    # accepts it only as an argument; it is never echoed or written to disk.
    $apiKey = [Environment]::GetEnvironmentVariable('NUGET_API_KEY')
    if ([string]::IsNullOrWhiteSpace($apiKey)) { throw 'NUGET_API_KEY must be supplied by the operator through a secure external source.' }
    $verified = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($verified -cne $Hash) { throw "Package changed immediately before push: $Id" }
    & dotnet nuget push $Path --source $expectedSource --api-key $apiKey
    if ($LASTEXITCODE -ne 0) { throw "NuGet push failed for $Id with exit code $LASTEXITCODE." }
}

function New-TestPackage([string] $Path, [string] $Id) {
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::CreateNew)
    $archive = [System.IO.Compression.ZipArchive]::new($stream, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $entry = $archive.CreateEntry("$Id.nuspec")
        $writer = [System.IO.StreamWriter]::new($entry.Open())
        try { $writer.Write("<package><metadata><id>$Id</id><version>$version</version></metadata></package>") } finally { $writer.Dispose() }
    } finally { $archive.Dispose(); $stream.Dispose() }
}

function Invoke-MockPublicationChecks {
    $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('dnc-publish-mock-' + [guid]::NewGuid().ToString('N'))
    $priorApiKey = [Environment]::GetEnvironmentVariable('NUGET_API_KEY')
    $secretSentinel = 'M0008-SYNTHETIC-API-KEY-DO-NOT-LEAK'
    [Environment]::SetEnvironmentVariable('NUGET_API_KEY', $secretSentinel)
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    try {
        $ridFile = "$ridId.$version.nupkg"; $topFile = "$topId.$version.nupkg"
        New-TestPackage (Join-Path $testRoot $ridFile) $ridId
        New-TestPackage (Join-Path $testRoot $topFile) $topId
        $packages = @(
            [pscustomobject]@{ role = 'top-level'; id = $topId; version = $version; file = $topFile; sha256 = (Get-FileHash (Join-Path $testRoot $topFile) -Algorithm SHA256).Hash },
            [pscustomobject]@{ role = 'rid'; id = $ridId; version = $version; file = $ridFile; sha256 = (Get-FileHash (Join-Path $testRoot $ridFile) -Algorithm SHA256).Hash }
        )
        foreach ($receipt in @('regression.log', 'installed.log', 'native.log', 'scale.log', 'dependencies.log', 'mocks.log', 'scale-report.json')) { [System.IO.File]::WriteAllText((Join-Path $testRoot $receipt), "$receipt passed") }
        $mockCommit = 'a' * 40
        $mockTree = 'b' * 40
        $mockCurrentIdentity = [pscustomobject]@{ Commit = $mockCommit; Tree = $mockTree; Branch = 'main'; WorkingTreeClean = $true }
        $report = [pscustomobject]@{
            schemaVersion = 2; qualified = $true; releaseQualified = $true; qualificationScope = 'final-merged-main'
            version = $version; sourceCommit = $mockCommit; actualCommit = $mockCommit; expectedReleaseCommit = $mockCommit; sourceTree = $mockTree; sourceBranch = 'main'; workingTreeClean = $true; published = $false
            licenseReview = @{ passed = $true }
            validation = @{
                regressionTests = @{ passed = $true; log = 'regression.log'; sha256 = (Get-FileHash (Join-Path $testRoot 'regression.log') -Algorithm SHA256).Hash }
                installedTool = @{ passed = $true; log = 'installed.log'; sha256 = (Get-FileHash (Join-Path $testRoot 'installed.log') -Algorithm SHA256).Hash }
                native = @{ passed = $true; log = 'native.log'; sha256 = (Get-FileHash (Join-Path $testRoot 'native.log') -Algorithm SHA256).Hash }
                repositoryScale = @{ passed = $true; log = 'scale.log'; sha256 = (Get-FileHash (Join-Path $testRoot 'scale.log') -Algorithm SHA256).Hash; report = 'scale-report.json'; reportSha256 = (Get-FileHash (Join-Path $testRoot 'scale-report.json') -Algorithm SHA256).Hash }
                dependencyAudit = @{ passed = $true; log = 'dependencies.log'; sha256 = (Get-FileHash (Join-Path $testRoot 'dependencies.log') -Algorithm SHA256).Hash }
                publicationMocks = @{ passed = $true; log = 'mocks.log'; sha256 = (Get-FileHash (Join-Path $testRoot 'mocks.log') -Algorithm SHA256).Hash }
            }
            packages = $packages
        }
        $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $testRoot 'candidate.json') -Encoding utf8
        # A final main candidate with a matching operator-supplied SHA and all passing receipts is accepted.
        Assert-ReleaseCommitIdentity $report $mockCurrentIdentity
        $candidate = Get-QualifiedCandidate $testRoot $mockCurrentIdentity

        # Feature-branch evidence remains preliminary and cannot become publishable by setting report flags.
        $preliminary = $report | ConvertTo-Json -Depth 8 | ConvertFrom-Json
        $preliminary.sourceBranch = 'codex/feature'
        $preliminary.qualified = $false; $preliminary.releaseQualified = $false; $preliminary.qualificationScope = 'preliminary-implementation-branch'
        $preliminary.expectedReleaseCommit = $null
        $preliminaryIdentity = [pscustomobject]@{ Commit = $mockCommit; Tree = $mockTree; Branch = 'codex/feature'; WorkingTreeClean = $true }
        $rejected = $false
        try { Assert-ReleaseCommitIdentity $preliminary $preliminaryIdentity } catch { $rejected = $true }
        if (-not $rejected) { throw 'A preliminary feature-branch candidate was accepted for final qualification.' }
        $preliminary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $testRoot 'candidate.json') -Encoding utf8
        $rejected = $false
        try { Get-QualifiedCandidate $testRoot $preliminaryIdentity } catch { $rejected = $true }
        if (-not $rejected) { throw 'A preliminary feature-branch candidate was accepted for publication.' }
        $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $testRoot 'candidate.json') -Encoding utf8

        # Omitted and mismatched expected SHAs cannot qualify; a dirty worktree is independently rejected.
        foreach ($case in @(
            @{ Expected = $null; Commit = $mockCommit; Branch = 'main'; Clean = $true },
            @{ Expected = ('c' * 40); Commit = $mockCommit; Branch = 'main'; Clean = $true },
            @{ Expected = $mockCommit; Commit = $mockCommit; Branch = 'main'; Clean = $false }
        )) {
            $identityManifest = $report | ConvertTo-Json -Depth 8 | ConvertFrom-Json
            $identityManifest.expectedReleaseCommit = $case.Expected
            $identityIdentity = [pscustomobject]@{ Commit = $case.Commit; Tree = $mockTree; Branch = $case.Branch; WorkingTreeClean = $case.Clean }
            $rejected = $false
            try { Assert-ReleaseCommitIdentity $identityManifest $identityIdentity } catch { $rejected = $true }
            if (-not $rejected) { throw 'Missing/mismatched expected SHA or dirty worktree was accepted for final qualification.' }
        }

        # Candidate metadata claiming main cannot override the current local branch/commit identity.
        $metadataBypassIdentity = [pscustomobject]@{ Commit = $mockCommit; Tree = $mockTree; Branch = 'codex/feature'; WorkingTreeClean = $true }
        $rejected = $false
        try { Get-QualifiedCandidate $testRoot $metadataBypassIdentity } catch { $rejected = $true }
        if (-not $rejected) { throw 'Candidate metadata bypassed current branch and expected-commit checks.' }

        # Regression evidence is mandatory and bound to the exact candidate receipt hash.
        $regressionGate = $report.validation.regressionTests
        $report.validation.Remove('regressionTests')
        $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $testRoot 'candidate.json') -Encoding utf8
        $rejected = $false
        try { Get-QualifiedCandidate $testRoot $mockCurrentIdentity } catch { $rejected = $true }
        if (-not $rejected) { throw 'A candidate without a regression receipt was accepted.' }
        $report.validation['regressionTests'] = $regressionGate
        $report.validation.regressionTests.passed = $false
        $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $testRoot 'candidate.json') -Encoding utf8
        $rejected = $false
        try { Get-QualifiedCandidate $testRoot $mockCurrentIdentity } catch { $rejected = $true }
        if (-not $rejected) { throw 'A candidate with a failed regression receipt was accepted.' }
        $report.validation.regressionTests.passed = $true
        $report.validation.regressionTests.sha256 = (Get-FileHash (Join-Path $testRoot 'regression.log') -Algorithm SHA256).Hash
        [System.IO.File]::AppendAllText((Join-Path $testRoot 'regression.log'), 'tampered')
        $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $testRoot 'candidate.json') -Encoding utf8
        $rejected = $false
        try { Get-QualifiedCandidate $testRoot $mockCurrentIdentity } catch { $rejected = $true }
        if (-not $rejected) { throw 'A tampered regression receipt was accepted.' }
        [System.IO.File]::WriteAllText((Join-Path $testRoot 'regression.log'), 'regression.log passed')
        $report.validation.regressionTests.sha256 = (Get-FileHash (Join-Path $testRoot 'regression.log') -Algorithm SHA256).Hash
        $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $testRoot 'candidate.json') -Encoding utf8
        $candidate = Get-QualifiedCandidate $testRoot $mockCurrentIdentity
        $trace = [System.Collections.Generic.List[string]]::new()
        $complete = Invoke-PublishSequence $candidate { param($path, $id, $hash) $trace.Add($id) }
        if (($complete -join ',') -ne "$ridId,$topId" -or ($trace -join ',') -ne "$ridId,$topId") { throw 'Mock publish order did not push the RID package before the pointer.' }

        $failedTrace = [System.Collections.Generic.List[string]]::new()
        try {
            Invoke-PublishSequence $candidate { param($path, $id, $hash) $failedTrace.Add($id); throw 'mock first push failure' }
            throw 'Mock first push failure was not propagated.'
        } catch {
            if ($_.Exception.Message -ne 'mock first push failure') { throw }
        }
        if (($failedTrace -join ',') -ne $ridId) { throw 'A failed RID push did not stop before the top-level pointer.' }
        $mockStatusPath = Join-Path $testRoot 'mock-publication-status.json'
        Save-PublicationFailureStatus $candidate @($script:publishCompleted) 'mock first push failure' $mockStatusPath
        $mockStatus = Get-Content -LiteralPath $mockStatusPath -Raw | ConvertFrom-Json
        if ($mockStatus.failedPackage -ne $ridId -or @($mockStatus.published).Count -ne 0 -or $mockStatus.recovery -notmatch "Check NuGet.org for $ridId $version" -or $mockStatus.recovery -notmatch "Do not push $topId") {
            throw 'A failed first push did not record honest partial publication state and recovery guidance.'
        }

        # A failure after the RID package succeeds must record the partial public state.
        $secondTrace = [System.Collections.Generic.List[string]]::new()
        try {
            Invoke-PublishSequence $candidate {
                param($path, $id, $hash)
                $secondTrace.Add($id)
                if ($id -eq $topId) { throw 'mock second push failure' }
            }
            throw 'Mock second push failure was not propagated.'
        } catch {
            if ($_.Exception.Message -ne 'mock second push failure') { throw }
        }
        if (($secondTrace -join ',') -ne "$ridId,$topId" -or (@($script:publishCompleted) -join ',') -ne $ridId) {
            throw 'Second-push failure did not preserve RID-only completion state.'
        }
        $secondStatusPath = Join-Path $testRoot 'mock-second-publication-status.json'
        Save-PublicationFailureStatus $candidate @($script:publishCompleted) 'mock second push failure' $secondStatusPath
        $secondStatus = Get-Content -LiteralPath $secondStatusPath -Raw | ConvertFrom-Json
        if ($secondStatus.failedPackage -ne $topId -or (@($secondStatus.published) -join ',') -ne $ridId -or $secondStatus.recovery -notmatch "Verify it on NuGet.org, then publish the unchanged top-level package $topId $version" -or $secondStatus.recovery -notmatch 'do not rebuild') {
            throw 'Second-push failure did not record correct partial-publication recovery.'
        }

        foreach ($case in @(
            @{ Target = 'https://example.invalid/v3/index.json'; Phrase = $approvalPhrase },
            @{ Target = $expectedSource; Phrase = 'yes' }
        )) {
            $rejected = $false
            try { Assert-PublishApproval $case.Target $case.Phrase } catch { $rejected = $true }
            if (-not $rejected) { throw 'Wrong feed or missing exact human confirmation was accepted.' }
        }
        $tamperPath = Join-Path $testRoot $ridFile
        [System.IO.File]::AppendAllText($tamperPath, 'tamper')
        $rejected = $false
        try { Get-QualifiedCandidate $testRoot } catch { $rejected = $true }
        if (-not $rejected) { throw 'Candidate hash tampering was not rejected.' }
        foreach ($receipt in Get-ChildItem -LiteralPath $testRoot -File -Recurse | Where-Object { $_.Extension -in @('.json', '.log') }) {
            if ([System.IO.File]::ReadAllText($receipt.FullName).Contains($secretSentinel, [StringComparison]::Ordinal)) { throw 'Mock publication persisted synthetic API-key material.' }
        }
        $mockOutput = 'Mock publication checks passed: regression receipt missing/failed/tampered cases, final commit identity, preliminary branch rejection, clean main requirement, default/prepare non-publishing, RID-first order, partial failure states, approval/feed controls, hash tampering, and secret non-disclosure.'
        if ($mockOutput.Contains($secretSentinel, [StringComparison]::Ordinal)) { throw 'Mock publication output leaked synthetic API-key material.' }
        Write-Output $mockOutput
    } finally {
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        [Environment]::SetEnvironmentVariable('NUGET_API_KEY', $priorApiKey)
    }
}

if ($TestPublish) { Invoke-MockPublicationChecks; exit 0 }

if ($Publish) {
    Assert-PublishApproval $Source $Confirmation
    $candidate = Get-QualifiedCandidate $CandidateDirectory
    try {
        $published = Invoke-PublishSequence $candidate { param($path, $id, $hash) Invoke-DotnetPush $path $id $hash }
        Write-Output "Published $($published -join ' then ') to NuGet.org."
    } catch {
        $completedPackages = @($script:publishCompleted)
        $statusPath = Join-Path (Split-Path -Parent $candidate.Root) ('publication-status-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + '.json')
        Save-PublicationFailureStatus $candidate $completedPackages $_.Exception.Message $statusPath
        throw "Publication stopped. Partial state is recorded at $statusPath. $($_.Exception.Message)"
    }
    exit 0
}

# No mode, or -Prepare, means prepare a local candidate only. Neither path
# contacts a package feed or invokes any publishing command.
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $sourceCommit -notmatch '^[0-9a-f]{40}$') { throw 'Unable to identify the Git source revision.' }
if (& git -C $repoRoot status --porcelain) { throw 'Candidate build requires a clean source worktree.' }
$sourceBranch = (& git -C $repoRoot branch --show-current).Trim()
$sourceTree = (& git -C $repoRoot rev-parse 'HEAD^{tree}').Trim()
if ($LASTEXITCODE -ne 0 -or $sourceTree -notmatch '^[0-9a-f]{40}$') { throw 'Unable to identify the Git source tree.' }
$actualCommit = $sourceCommit
$releaseQualified = $false
$expectedCommit = $null
if (-not [string]::IsNullOrWhiteSpace($ExpectedReleaseCommit)) {
    if ($ExpectedReleaseCommit -notmatch '^[0-9a-f]{40}$') { throw 'ExpectedReleaseCommit must be a full lowercase 40-character Git commit SHA.' }
    if ($ExpectedReleaseCommit -cne $actualCommit) { throw 'Expected release commit does not match current HEAD.' }
    if ($sourceBranch -cne 'main') { throw 'Expected-release-commit qualification is only allowed on main.' }
    $expectedCommit = $ExpectedReleaseCommit
    $releaseQualified = $true
}
$qualificationScope = if ($releaseQualified) { 'final-merged-main' } elseif ($sourceBranch -ceq 'main') { 'preliminary-main-without-expected-commit' } else { 'preliminary-implementation-branch' }
$candidateRoot = if ($OutputDirectory) { [System.IO.Path]::GetFullPath($OutputDirectory) } else { Join-Path $repoRoot "artifacts/release-candidate-$version-$sourceCommit" }
if (Test-Path -LiteralPath $candidateRoot) { throw "Candidate directory already exists and will not be overwritten: $candidateRoot" }
$sdkVersion = (& dotnet --version).Trim()
if ($LASTEXITCODE -ne 0 -or $sdkVersion -notmatch '^11\.0\.100-rc\.') { throw "Expected the authorized .NET 11 RC SDK; found '$sdkVersion'." }
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) { throw 'The existing Visual Studio locator is unavailable; Native AOT prerequisites were not installed.' }
$compilerPath = (& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find 'VC/Tools/MSVC/**/bin/Hostx64/x64/cl.exe' | Select-Object -First 1)
if (-not $compilerPath -or -not (Test-Path -LiteralPath $compilerPath)) { throw 'The existing MSVC x64 compiler is unavailable; Native AOT prerequisites were not installed.' }
New-Item -ItemType Directory -Path $candidateRoot | Out-Null
try {
    $regressionOutput = & dotnet test (Join-Path $repoRoot 'DotnetNugetContent.sln') -c Release --no-restore 2>&1
    $regressionOutput | Set-Content -LiteralPath (Join-Path $candidateRoot 'regression-tests.log') -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw 'Complete Release regression suite failed. See regression-tests.log; candidate qualification is blocked.' }
    & dotnet pack $project -c Release --no-restore "-p:Version=$version" -o $candidateRoot
    if ($LASTEXITCODE -ne 0) { throw 'Top-level pointer package build failed.' }
    & dotnet pack $project -c Release -r win-x64 --no-restore "-p:Version=$version" -o $candidateRoot
    if ($LASTEXITCODE -ne 0) { throw 'win-x64 Native AOT package build failed.' }
    $topPath = Join-Path $candidateRoot "$topId.$version.nupkg"
    $ridPath = Join-Path $candidateRoot "$ridId.$version.nupkg"
    foreach ($package in @(
        @{ Path = $topPath; Id = $topId },
        @{ Path = $ridPath; Id = $ridId }
    )) {
        if (-not (Test-Path -LiteralPath $package.Path -PathType Leaf)) { throw "Build did not produce $($package.Path)." }
        $identity = Get-PackageIdentity $package.Path
        if ($identity.Id -ne $package.Id -or $identity.Version -ne $version) { throw "Package identity/version mismatch: $($package.Path)" }
    }
    $toolValidation = & pwsh -NoProfile -File (Join-Path $repoRoot 'scripts/validate-tool.ps1') -CandidateDirectory $candidateRoot -Version $version 2>&1
    $toolValidation | Set-Content -LiteralPath (Join-Path $candidateRoot 'installed-tool-validation.log') -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw 'Installed-tool validation against the exact candidate packages failed. See installed-tool-validation.log.' }
    $nativeValidation = & pwsh -NoProfile -File (Join-Path $repoRoot 'scripts/validate-native.ps1') -CandidateDirectory $candidateRoot 2>&1
    $nativeValidation | Set-Content -LiteralPath (Join-Path $candidateRoot 'native-validation.log') -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw 'Native AOT candidate validation failed. See native-validation.log.' }
    $scaleValidation = & pwsh -NoProfile -File (Join-Path $repoRoot 'scripts/validate-scale.ps1') -CandidateDirectory $candidateRoot 2>&1
    $scaleValidation | Set-Content -LiteralPath (Join-Path $candidateRoot 'repository-scale-validation.log') -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw '100-project/10-package scale validation failed. See repository-scale-validation.log.' }
    $dependencyOutput = & dotnet list $project package --vulnerable --include-transitive 2>&1
    $dependencyOutput | Set-Content -LiteralPath (Join-Path $candidateRoot 'dependency-audit.log') -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw 'Dependency advisory audit failed. See dependency-audit.log.' }
    $dependencyText = $dependencyOutput -join "`n"
    if ($dependencyText -match '(?im)^\s*(Critical|High)\s+') { throw 'High-risk dependency advisory found; release qualification is blocked.' }
    $projectXml = [xml][System.IO.File]::ReadAllText($project)
    $licenseExpression = [string]$projectXml.Project.PropertyGroup.PackageLicenseExpression
    $authors = [string]$projectXml.Project.PropertyGroup.Authors
    $licenseText = [System.IO.File]::ReadAllText((Join-Path $repoRoot 'LICENSE'))
    $knownAuthors = @(& git -C $repoRoot log --format='%an' --all -- 'src/DotnetNugetContent')
    $remoteUrl = (& git -C $repoRoot remote get-url origin).Trim()
    if ($licenseExpression -cne 'Unlicense' -or $authors -notin $knownAuthors -or $licenseText -notmatch 'public domain' -or $remoteUrl -notmatch 'github\.com[:/]carlrabbit/dotnet-nuget-content(?:\.git)?$') { throw 'Repository LICENSE, package author attribution, and project-owner metadata do not reconcile; human ownership/license review is required.' }
    $licenseReview = [ordered]@{ passed = $true; packageLicenseExpression = $licenseExpression; packageAuthors = $authors; recordedProjectAuthors = @($knownAuthors | Select-Object -Unique); repositoryOwner = 'carlrabbit'; origin = $remoteUrl; basis = 'LICENSE text, csproj attribution, Git project history, and origin repository identity were compared; human review of legal ownership and publication rights remains required.' }
    $mockValidation = & pwsh -NoProfile -File $PSCommandPath -TestPublish 2>&1
    $mockValidation | Set-Content -LiteralPath (Join-Path $candidateRoot 'publishing-mock-validation.log') -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw 'Mock publishing validation failed. See publishing-mock-validation.log.' }
    $compilerInfo = (& $compilerPath 2>&1 | Select-String 'Version' | Select-Object -First 1).Line
    $toolchain = [ordered]@{ sdk = $sdkVersion; compiler = $compilerPath; compilerVersion = $compilerInfo }
    $packages = @(
        [ordered]@{ role = 'rid'; id = $ridId; version = $version; file = [System.IO.Path]::GetFileName($ridPath); sha256 = (Get-FileHash -LiteralPath $ridPath -Algorithm SHA256).Hash },
        [ordered]@{ role = 'top-level'; id = $topId; version = $version; file = [System.IO.Path]::GetFileName($topPath); sha256 = (Get-FileHash -LiteralPath $topPath -Algorithm SHA256).Hash }
    )
    $report = [ordered]@{
        schemaVersion = 2; qualified = $releaseQualified; releaseQualified = $releaseQualified; qualificationScope = $qualificationScope
        version = $version; sourceCommit = $sourceCommit; actualCommit = $actualCommit; expectedReleaseCommit = $expectedCommit
        sourceTree = $sourceTree; sourceBranch = $sourceBranch; workingTreeClean = $true
        sourceRepository = 'https://github.com/carlrabbit/dotnet-nuget-content'; command = if ($expectedCommit) { "pwsh -NoProfile -File eng/publish.ps1 -Prepare -ExpectedReleaseCommit $expectedCommit" } else { 'pwsh -NoProfile -File eng/publish.ps1 -Prepare' }
        preparedUtc = [DateTime]::UtcNow.ToString('o'); toolchain = $toolchain; packages = $packages
        licenseReview = $licenseReview
        validation = [ordered]@{
            regressionTests = [ordered]@{ passed = $true; log = 'regression-tests.log'; sha256 = (Get-FileHash -LiteralPath (Join-Path $candidateRoot 'regression-tests.log') -Algorithm SHA256).Hash }
            installedTool = [ordered]@{ passed = $true; log = 'installed-tool-validation.log'; sha256 = (Get-FileHash -LiteralPath (Join-Path $candidateRoot 'installed-tool-validation.log') -Algorithm SHA256).Hash }
            native = [ordered]@{ passed = $true; log = 'native-validation.log'; sha256 = (Get-FileHash -LiteralPath (Join-Path $candidateRoot 'native-validation.log') -Algorithm SHA256).Hash }
            repositoryScale = [ordered]@{ passed = $true; log = 'repository-scale-validation.log'; sha256 = (Get-FileHash -LiteralPath (Join-Path $candidateRoot 'repository-scale-validation.log') -Algorithm SHA256).Hash; report = 'repository-scale-report.json'; reportSha256 = (Get-FileHash -LiteralPath (Join-Path $candidateRoot 'repository-scale-report.json') -Algorithm SHA256).Hash }
            dependencyAudit = [ordered]@{ passed = $true; log = 'dependency-audit.log'; sha256 = (Get-FileHash -LiteralPath (Join-Path $candidateRoot 'dependency-audit.log') -Algorithm SHA256).Hash; licenseReview = $licenseReview }
            publicationMocks = [ordered]@{ passed = $true; log = 'publishing-mock-validation.log'; sha256 = (Get-FileHash -LiteralPath (Join-Path $candidateRoot 'publishing-mock-validation.log') -Algorithm SHA256).Hash }
        }
        published = $false
    }
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $candidateRoot 'candidate.json') -Encoding utf8
    $checklist = @"
# Manual publication checklist — dotnet-nuget-content 2.0.0

- Verify actualCommit, expectedReleaseCommit, sourceTree, and the full Release regression receipt match this local clean main checkout. Preliminary candidates are never publishable.
- Review candidate.json and both SHA-256 values. Do not rebuild.
- Confirm this is a final-merged-main candidate and review regression, installed-tool, native, 100-project scale, dependency, consumer and publication-mock logs.
- Confirm the repository owner has approved publication rights and NuGet.org identity.
- Supply NUGET_API_KEY from an external secure source at invocation time.
- Run eng/publish.ps1 -Publish -CandidateDirectory <this directory> -Source https://api.nuget.org/v3/index.json -Confirmation 'PUBLISH TO NUGET.ORG'.
- Verify RID package acceptance first; the top-level pointer publishes only after it succeeds.
- Record NuGet.org package pages and publication time outside the candidate directory.

No package has been published by candidate preparation.
"@
    $checklist | Set-Content -LiteralPath (Join-Path $candidateRoot 'PUBLISH-CHECKLIST.md') -Encoding utf8
    Get-ChildItem -LiteralPath $candidateRoot -File | ForEach-Object { $_.IsReadOnly = $true }
    Write-Output "Prepared local candidate ($qualificationScope): $candidateRoot"
    Get-Content -LiteralPath (Join-Path $candidateRoot 'candidate.json')
} catch {
    if (Test-Path -LiteralPath $candidateRoot -PathType Container) {
        $failurePath = Join-Path $candidateRoot 'preparation-failure.txt'
        [System.IO.File]::WriteAllText($failurePath, "Preparation failed at $([DateTime]::UtcNow.ToString('o')).`n$($_.Exception.Message)`nThis directory is incomplete and not publishable.`n", [System.Text.UTF8Encoding]::new($false))
        throw "Local preparation failed. Incomplete, non-publishable diagnostics were retained at $candidateRoot. $($_.Exception.Message)"
    }
    throw
}
