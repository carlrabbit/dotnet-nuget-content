[CmdletBinding(DefaultParameterSetName = 'Prepare')]
param(
    [Parameter(ParameterSetName = 'Prepare')][switch] $Prepare,
    [Parameter(ParameterSetName = 'Prepare')][string] $OutputDirectory,
    [Parameter(ParameterSetName = 'Publish', Mandatory = $true)][switch] $Publish,
    [Parameter(ParameterSetName = 'Test')][switch] $TestPublish,
    [Parameter(ParameterSetName = 'Publish', Mandatory = $true)][string] $CandidateDirectory,
    [Parameter(ParameterSetName = 'Publish', Mandatory = $true)][string] $Confirmation,
    [Parameter(ParameterSetName = 'Publish')][string] $Source = 'https://api.nuget.org/v3/index.json'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repoRoot 'src/DotnetNugetContent/DotnetNugetContent.csproj'
$version = '1.0.0'
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

function Get-QualifiedCandidate([string] $Path) {
    $root = [System.IO.Path]::GetFullPath($Path)
    $manifestPath = Join-Path $root 'candidate.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Candidate manifest not found: $manifestPath" }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.qualified -ne $true -or $manifest.version -ne $version -or $manifest.sourceCommit -notmatch '^[0-9a-f]{40}$') {
        throw 'Candidate report is not qualified for the required 1.0.0 release.'
    }
    if ($manifest.published -ne $false) { throw 'Candidate report does not establish an unpublished release candidate.' }
    $gates = @($manifest.validation.installedTool, $manifest.validation.publicationMocks)
    if ($gates.Count -ne 2) { throw 'Candidate report must contain installed-tool and publication-mock validation receipts.' }
    foreach ($gate in $gates) {
        if ($gate.passed -ne $true -or -not $gate.log -or -not $gate.sha256) { throw 'Candidate report is missing a passing validation receipt.' }
        $logPath = Join-Path $root $gate.log
        if (-not (Test-Path -LiteralPath $logPath -PathType Leaf) -or (Get-FileHash -LiteralPath $logPath -Algorithm SHA256).Hash -cne $gate.sha256) {
            throw "Candidate validation receipt is missing or changed: $($gate.log)"
        }
    }
    if (@($manifest.packages).Count -ne 2) { throw 'Candidate must contain exactly the top-level and win-x64 packages.' }
    $ordered = @($manifest.packages | Sort-Object { if ($_.role -eq 'rid') { 0 } elseif ($_.role -eq 'top-level') { 1 } else { 2 } })
    if ($ordered[0].role -ne 'rid' -or $ordered[0].id -ne $ridId -or $ordered[1].role -ne 'top-level' -or $ordered[1].id -ne $topId) {
        throw 'Candidate package identities or publication roles are invalid.'
    }
    foreach ($package in $ordered) {
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
        try { $writer.Write("<package><metadata><id>$Id</id><version>1.0.0</version></metadata></package>") } finally { $writer.Dispose() }
    } finally { $archive.Dispose(); $stream.Dispose() }
}

function Invoke-MockPublicationChecks {
    $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('dnc-publish-mock-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    try {
        $ridFile = "$ridId.1.0.0.nupkg"; $topFile = "$topId.1.0.0.nupkg"
        New-TestPackage (Join-Path $testRoot $ridFile) $ridId
        New-TestPackage (Join-Path $testRoot $topFile) $topId
        $packages = @(
            [pscustomobject]@{ role = 'top-level'; id = $topId; version = $version; file = $topFile; sha256 = (Get-FileHash (Join-Path $testRoot $topFile) -Algorithm SHA256).Hash },
            [pscustomobject]@{ role = 'rid'; id = $ridId; version = $version; file = $ridFile; sha256 = (Get-FileHash (Join-Path $testRoot $ridFile) -Algorithm SHA256).Hash }
        )
        [System.IO.File]::WriteAllText((Join-Path $testRoot 'installed.log'), 'installed validation passed')
        [System.IO.File]::WriteAllText((Join-Path $testRoot 'mocks.log'), 'mock publication validation passed')
        $report = [pscustomobject]@{ qualified = $true; version = $version; sourceCommit = ('a' * 40); published = $false; validation = @{ installedTool = @{ passed = $true; log = 'installed.log'; sha256 = (Get-FileHash (Join-Path $testRoot 'installed.log') -Algorithm SHA256).Hash }; publicationMocks = @{ passed = $true; log = 'mocks.log'; sha256 = (Get-FileHash (Join-Path $testRoot 'mocks.log') -Algorithm SHA256).Hash } }; packages = $packages }
        $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $testRoot 'candidate.json') -Encoding utf8
        $candidate = Get-QualifiedCandidate $testRoot
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
        if ($mockStatus.failedPackage -ne $ridId -or @($mockStatus.published).Count -ne 0 -or $mockStatus.recovery -notmatch "Check NuGet.org for $ridId 1.0.0" -or $mockStatus.recovery -notmatch "Do not push $topId") {
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
        if ($secondStatus.failedPackage -ne $topId -or (@($secondStatus.published) -join ',') -ne $ridId -or $secondStatus.recovery -notmatch "Verify it on NuGet.org, then publish the unchanged top-level package $topId 1.0.0" -or $secondStatus.recovery -notmatch 'do not rebuild') {
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
        Write-Output 'Mock publication checks passed: default/prepare are non-publishing; RID-first ordering, both first- and second-push failure states, wrong feed, missing approval, and hash tampering are rejected or recorded.'
    } finally { Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue }
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
$candidateRoot = if ($OutputDirectory) { [System.IO.Path]::GetFullPath($OutputDirectory) } else { Join-Path $repoRoot "artifacts/release-candidate-$version-$sourceCommit" }
if (Test-Path -LiteralPath $candidateRoot) { throw "Candidate directory already exists and will not be overwritten: $candidateRoot" }
$sdkVersion = (& dotnet --version).Trim()
if ($LASTEXITCODE -ne 0 -or $sdkVersion -notmatch '^11\.0\.100-rc\.1') { throw "Expected the authorized .NET 11 RC SDK; found '$sdkVersion'." }
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) { throw 'The existing Visual Studio locator is unavailable; Native AOT prerequisites were not installed.' }
$compilerPath = (& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find 'VC/Tools/MSVC/**/bin/Hostx64/x64/cl.exe' | Select-Object -First 1)
if (-not $compilerPath -or -not (Test-Path -LiteralPath $compilerPath)) { throw 'The existing MSVC x64 compiler is unavailable; Native AOT prerequisites were not installed.' }
New-Item -ItemType Directory -Path $candidateRoot | Out-Null
try {
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
    $mockValidation = & pwsh -NoProfile -File $PSCommandPath -TestPublish 2>&1
    $mockValidation | Set-Content -LiteralPath (Join-Path $candidateRoot 'publishing-mock-validation.log') -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw 'Mock publishing validation failed. See publishing-mock-validation.log.' }
    $compilerInfo = (& $compilerPath 2>&1 | Select-String 'Version' | Select-Object -First 1).Line
    $toolchain = [ordered]@{ sdk = $sdkVersion; compiler = $compilerPath; compilerVersion = $compilerInfo }
    $packages = @(
        [ordered]@{ role = 'rid'; id = $ridId; version = $version; file = [System.IO.Path]::GetFileName($ridPath); sha256 = (Get-FileHash -LiteralPath $ridPath -Algorithm SHA256).Hash },
        [ordered]@{ role = 'top-level'; id = $topId; version = $version; file = [System.IO.Path]::GetFileName($topPath); sha256 = (Get-FileHash -LiteralPath $topPath -Algorithm SHA256).Hash }
    )
    $report = [ordered]@{ schemaVersion = 1; qualified = $true; version = $version; sourceCommit = $sourceCommit; sourceRepository = 'https://github.com/carlrabbit/dotnet-nuget-content'; preparedUtc = [DateTime]::UtcNow.ToString('o'); toolchain = $toolchain; packages = $packages; validation = [ordered]@{ installedTool = [ordered]@{ passed = $true; log = 'installed-tool-validation.log'; sha256 = (Get-FileHash -LiteralPath (Join-Path $candidateRoot 'installed-tool-validation.log') -Algorithm SHA256).Hash }; publicationMocks = [ordered]@{ passed = $true; log = 'publishing-mock-validation.log'; sha256 = (Get-FileHash -LiteralPath (Join-Path $candidateRoot 'publishing-mock-validation.log') -Algorithm SHA256).Hash } }; published = $false }
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $candidateRoot 'candidate.json') -Encoding utf8
    $checklist = @"
# Manual publication checklist — dotnet-nuget-content 1.0.0

- Review candidate.json and both SHA-256 values. Do not rebuild.
- Confirm source revision and installed-tool/consumer validation logs.
- Confirm the repository owner has approved publication rights and NuGet.org identity.
- Supply NUGET_API_KEY from an external secure source at invocation time.
- Run eng/publish.ps1 -Publish -CandidateDirectory <this directory> -Source https://api.nuget.org/v3/index.json -Confirmation 'PUBLISH TO NUGET.ORG'.
- Verify RID package acceptance first; the top-level pointer publishes only after it succeeds.
- Record NuGet.org package pages and publication time outside the candidate directory.

No package has been published by candidate preparation.
"@
    $checklist | Set-Content -LiteralPath (Join-Path $candidateRoot 'PUBLISH-CHECKLIST.md') -Encoding utf8
    Get-ChildItem -LiteralPath $candidateRoot -File | ForEach-Object { $_.IsReadOnly = $true }
    Write-Output "Qualified local candidate: $candidateRoot"
    Get-Content -LiteralPath (Join-Path $candidateRoot 'candidate.json')
} catch {
    if (Test-Path -LiteralPath $candidateRoot) { Remove-Item -LiteralPath $candidateRoot -Recurse -Force -ErrorAction SilentlyContinue }
    throw
}
