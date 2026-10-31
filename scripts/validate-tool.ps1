param(
    [string] $Configuration = 'Release',
    [string] $CandidateDirectory,
    [string] $Version = '0.1.0',
    [string] $UpdateVersion
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repoRoot 'src/DotnetNugetContent/DotnetNugetContent.csproj'
$consumerScript = Join-Path $PSScriptRoot 'validate-consumer.ps1'
$runId = [guid]::NewGuid().ToString('N')
$work = Join-Path ([System.IO.Path]::GetTempPath()) "dotnet-nuget-content M0003 $runId"
$feed = Join-Path $work 'isolated local NuGet feed'
$toolPath = Join-Path $work 'isolated global-equivalent tools'
$localProject = Join-Path $work 'local manifest consumer'
$version = $Version
if (-not $UpdateVersion) { $UpdateVersion = if ($version -eq '0.1.0') { '0.1.1' } else { '1.0.1' } }
$updateVersion = $UpdateVersion
$packageId = 'dotnet-nuget-content'

function Invoke-CapturedProcess([string] $FilePath, [string[]] $Arguments, [string] $WorkingDirectory = $work) {
    if ([System.IO.Path]::GetExtension($FilePath) -in @('.cmd', '.bat')) {
        $stdoutPath = Join-Path $work ('.stdout-' + [guid]::NewGuid().ToString('N'))
        $stderrPath = Join-Path $work ('.stderr-' + [guid]::NewGuid().ToString('N'))
        try {
            Push-Location $WorkingDirectory
            try {
                & $FilePath @Arguments 1> $stdoutPath 2> $stderrPath
                $code = $LASTEXITCODE
            } finally { Pop-Location }
            return [pscustomobject]@{
                ExitCode = $code
                Stdout = if (Test-Path -LiteralPath $stdoutPath) { [System.IO.File]::ReadAllText($stdoutPath) } else { '' }
                Stderr = if (Test-Path -LiteralPath $stderrPath) { [System.IO.File]::ReadAllText($stderrPath) } else { '' }
            }
        } finally {
            Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
        }
    }

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.UseShellExecute = $false
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$startInfo.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    return [pscustomobject]@{ ExitCode = $process.ExitCode; Stdout = $stdoutTask.GetAwaiter().GetResult(); Stderr = $stderrTask.GetAwaiter().GetResult() }
}

function Invoke-Checked([string] $FilePath, [string[]] $Arguments, [string] $WorkingDirectory = $work) {
    $result = Invoke-CapturedProcess $FilePath $Arguments $WorkingDirectory
    if ($result.Stdout) { Write-Output $result.Stdout.TrimEnd() }
    if ($result.Stderr) { [Console]::Error.WriteLine($result.Stderr.TrimEnd()) }
    if ($result.ExitCode -ne 0) { throw "$FilePath $($Arguments -join ' ') failed with exit code $($result.ExitCode). stdout=[$($result.Stdout)] stderr=[$($result.Stderr)]" }
    return $result
}

function Invoke-Tool([string[]] $Arguments) { Invoke-CapturedProcess $toolShim $Arguments }
function Invoke-LocalTool([string[]] $Arguments) { Invoke-CapturedProcess 'dotnet' (@('tool', 'run', 'dotnet-nuget-content', '--') + $Arguments) $localProject }
function Assert-ToolResult($Result, [int] $ExitCode, [string] $Label) {
    if ($Result.ExitCode -ne $ExitCode) { throw "$Label returned exit $($Result.ExitCode), expected $ExitCode. stdout=[$($Result.Stdout)] stderr=[$($Result.Stderr)]" }
}
function Assert-JsonLine([string] $Text, [string] $Label) {
    if (-not $Text.EndsWith("`n") -or $Text.TrimEnd("`r", "`n").Contains("`n")) { throw "$Label did not emit exactly one JSON line." }
    return ($Text | ConvertFrom-Json -AsHashtable)
}
function New-ToolPackage([string] $PackageVersion, [string] $Output) {
    $topOutput = Join-Path $Output 'top-level'
    $ridOutput = Join-Path $Output 'win-x64'
    New-Item -ItemType Directory -Force -Path $topOutput, $ridOutput | Out-Null
    Invoke-Checked 'dotnet' @('pack', $project, '-c', $Configuration, '--no-restore', "-p:Version=$PackageVersion", '-o', $topOutput) | Out-Null
    Invoke-Checked 'dotnet' @('pack', $project, '-c', $Configuration, '-r', 'win-x64', '--no-restore', "-p:Version=$PackageVersion", '-o', $ridOutput) | Out-Null
}
function Assert-NativeAmd64([string] $Path) {
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $reader = [System.IO.BinaryReader]::new($stream)
        $stream.Position = 0x3c
        $peOffset = $reader.ReadInt32()
        $stream.Position = $peOffset + 4
        if ($reader.ReadUInt16() -ne 0x8664) { throw "Native executable is not PE AMD64: $Path" }
    } finally { $stream.Dispose() }
}
function Assert-PackageIdentity([System.IO.Compression.ZipArchive] $Archive, [string] $EntryName, [string] $ExpectedId, [string] $ExpectedVersion) {
    $nuspecEntry = $Archive.GetEntry($EntryName)
    if (-not $nuspecEntry) { throw "Package is missing its expected nuspec: $EntryName" }
    $nuspecReader = [System.IO.StreamReader]::new($nuspecEntry.Open())
    try { [xml] $nuspec = $nuspecReader.ReadToEnd() } finally { $nuspecReader.Dispose() }
    $identity = $nuspec.SelectSingleNode("//*[local-name()='metadata']/*[local-name()='id']").InnerText
    $packageVersion = $nuspec.SelectSingleNode("//*[local-name()='metadata']/*[local-name()='version']").InnerText
    if ($identity -ne $ExpectedId -or $packageVersion -ne $ExpectedVersion) { throw "Package identity/version mismatch in $EntryName." }
}
function Assert-ReleaseMetadata([System.IO.Compression.ZipArchive] $Archive, [string] $EntryName, [string] $ExpectedId) {
    $nuspecEntry = $Archive.GetEntry($EntryName)
    if (-not $nuspecEntry) { throw "Package is missing its expected nuspec: $EntryName" }
    $reader = [System.IO.StreamReader]::new($nuspecEntry.Open())
    try { [xml]$nuspec = $reader.ReadToEnd() } finally { $reader.Dispose() }
    $metadata = $nuspec.SelectSingleNode("//*[local-name()='metadata']")
    $expected = @{
        id = $ExpectedId
        version = $version
        title = 'dotnet-nuget-content — immutable content snapshots'
        description = 'Windows command-line tool for creating and maintaining immutable NuGet packages of arbitrary files. Supports versioned snapshots, workspace status, change history, SHA-256 verification, and JSON output. Generated packages integrate with ordinary .NET PackageReference consumers.'
        authors = 'Martin Koch'
        license = 'Unlicense'
        projectUrl = 'https://github.com/carlrabbit/dotnet-nuget-content'
        repositoryUrl = 'https://github.com/carlrabbit/dotnet-nuget-content'
        releaseNotes = 'First stable Windows x64 Native AOT .NET tool release. Immutable arbitrary-content package snapshots, managed workspace status and repack, manifest v1, history, SHA-256 validation, JSON inspection, and ordinary PackageReference consumption.'
    }
    foreach ($name in $expected.Keys) {
        $actual = switch ($name) {
            'license' { [string]$metadata.license.InnerText }
            'repositoryUrl' { [string]$metadata.repository.url }
            default { [string]$metadata.SelectSingleNode("*[local-name()='$name']").InnerText }
        }
        if ($actual -cne $expected[$name]) { throw "NuGet metadata '$name' mismatch in $ExpectedId ${version}: '$actual'." }
    }
    if ([string]$metadata.license.type -cne 'expression' -or [string]$metadata.repository.type -cne 'git') { throw "NuGet license or repository metadata type is invalid in $ExpectedId." }
    $tags = [string]$metadata.tags
    if ($tags -cne 'dotnet-tool nuget content files snapshots versioning nativeaot') { throw "NuGet tags mismatch in $ExpectedId $version." }
    $embeddedReadme = $Archive.GetEntry('README.md')
    if (-not $embeddedReadme) { throw "Package $ExpectedId is missing its embedded README.md." }
    $readmeReader = [System.IO.StreamReader]::new($embeddedReadme.Open())
    try { $readme = $readmeReader.ReadToEnd() } finally { $readmeReader.Dispose() }
    $authoredReadme = [System.IO.File]::ReadAllText((Join-Path $repoRoot 'docs/nuget/README.md'))
    if ($readme.TrimEnd() -cne $authoredReadme.TrimEnd()) { throw "Embedded README does not match docs/nuget/README.md in $ExpectedId." }
}

try {
    New-Item -ItemType Directory -Force -Path $work, $feed, $toolPath, $localProject | Out-Null
    $config = Join-Path $work 'NuGet.Config'
    $feedPath = [System.Security.SecurityElement]::Escape($feed)
    Set-Content -LiteralPath $config -Encoding utf8 -Value "<configuration><packageSources><clear/><add key=`"isolated`" value=`"$feedPath`" /></packageSources></configuration>"

    $topBuild = Join-Path $work 'top-level pack'
    $ridBuild = Join-Path $work 'win-x64 pack'
    New-Item -ItemType Directory -Force -Path $topBuild, $ridBuild | Out-Null
    if ($CandidateDirectory) {
        $candidateRoot = (Resolve-Path -LiteralPath $CandidateDirectory).Path
        $topCandidate = Join-Path $candidateRoot "$packageId.$version.nupkg"
        $ridCandidate = Join-Path $candidateRoot "$packageId.win-x64.$version.nupkg"
    } else {
        Invoke-Checked 'dotnet' @('pack', $project, '-c', $Configuration, '--no-restore', "-p:Version=$version", '-o', $topBuild) | Out-Null
        Invoke-Checked 'dotnet' @('pack', $project, '-c', $Configuration, '-r', 'win-x64', '--no-restore', "-p:Version=$version", '-o', $ridBuild) | Out-Null
        $topCandidate = Join-Path $topBuild "$packageId.$version.nupkg"
        $ridCandidate = Join-Path $ridBuild "$packageId.win-x64.$version.nupkg"
    }
    foreach ($candidate in @($topCandidate, $ridCandidate)) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { throw "Expected tool package was not produced: $candidate" }
        Copy-Item -LiteralPath $candidate -Destination $feed
    }
    if ((@(Get-ChildItem -LiteralPath $feed -Filter '*.nupkg')).Count -ne 2) { throw 'The local feed must contain only the matching top-level pointer and win-x64 tool package.' }
    $topPackage = Join-Path $feed "$packageId.$version.nupkg"
    $ridPackage = Join-Path $feed "$packageId.win-x64.$version.nupkg"
    $topArchive = [System.IO.Compression.ZipFile]::OpenRead($topPackage)
    $ridArchive = [System.IO.Compression.ZipFile]::OpenRead($ridPackage)
    try {
        Assert-PackageIdentity $topArchive "$packageId.nuspec" $packageId $version
        Assert-PackageIdentity $ridArchive "$packageId.win-x64.nuspec" "$packageId.win-x64" $version
        Assert-ReleaseMetadata $topArchive "$packageId.nuspec" $packageId
        Assert-ReleaseMetadata $ridArchive "$packageId.win-x64.nuspec" "$packageId.win-x64"
        $topSpec = $topArchive.GetEntry('tools/any/any/DotnetToolSettings.xml')
        if (-not $topSpec) { throw 'Top-level tool pointer package is missing DotnetToolSettings.xml.' }
        $topReader = [System.IO.StreamReader]::new($topSpec.Open())
        try { $toolSettings = $topReader.ReadToEnd() } finally { $topReader.Dispose() }
        if ($toolSettings -notmatch 'dotnet-nuget-content') { throw 'Tool pointer does not declare the requested command name.' }
        if ($ridArchive.Entries.FullName -notcontains 'tools/any/win-x64/dotnet-nuget-content.exe') { throw 'win-x64 tool package is missing its native executable.' }
        if ($ridArchive.Entries.FullName -match 'tools/any/(?!win-x64)[^/]+/dotnet-nuget-content\.exe') { throw 'The tool package includes an unsupported RID fallback.' }
    } finally { $topArchive.Dispose(); $ridArchive.Dispose() }

    $install = Invoke-Checked 'dotnet' @('tool', 'install', $packageId, '--tool-path', $toolPath, '--version', $version, '--configfile', $config)
    $script:toolShim = Join-Path $toolPath 'dotnet-nuget-content.cmd'
    if (-not (Test-Path -LiteralPath $toolShim -PathType Leaf)) { throw 'Isolated global-equivalent install did not create its command shim.' }
    $versionResult = Invoke-Tool @('--version')
    Assert-ToolResult $versionResult 0 'Installed global-equivalent --version'
    if ($versionResult.Stdout -ne "$version`r`n" -or $versionResult.Stderr) { throw 'Installed tool version output does not match the package version.' }
    $helpResult = Invoke-Tool @('--help')
    Assert-ToolResult $helpResult 0 'Installed root help'
    if ($helpResult.Stderr) { throw 'Installed root help emitted stderr.' }
    $helpSource = [System.IO.File]::ReadAllText((Join-Path $repoRoot 'docs/release/HELP-TEXT.md'))
    $helpMatch = [regex]::Match($helpSource, '(?s)```text\r?\n(.*?)\r?\n```')
    if (-not $helpMatch.Success -or $helpResult.Stdout.Replace("`r`n", "`n").TrimEnd("`n") -cne $helpMatch.Groups[1].Value.Replace("`r`n", "`n")) { throw 'Installed root help differs from the authored release help contract.' }
    $shimLine = (Get-Content -LiteralPath $toolShim | Select-Object -First 2 | Select-Object -Last 1)
    $nativeExe = [regex]::Match($shimLine, '"%~dp0([^" ]+\.exe)"').Groups[1].Value
    if (-not $nativeExe) { throw 'Could not resolve the installed native executable through its shim.' }
    $installedExe = Join-Path $toolPath $nativeExe
    Assert-NativeAmd64 $installedExe
    $nativeHash = (Get-FileHash -LiteralPath $installedExe -Algorithm SHA256).Hash

    $localManifest = Join-Path $localProject '.config/dotnet-tools.json'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $localManifest) | Out-Null
    Invoke-Checked 'dotnet' @('new', 'tool-manifest', '--output', (Split-Path -Parent $localManifest)) $localProject | Out-Null
    Invoke-Checked 'dotnet' @('tool', 'install', $packageId, '--local', '--tool-manifest', $localManifest, '--version', $version, '--configfile', $config) $localProject | Out-Null
    $localVersion = Invoke-LocalTool @('--version')
    Assert-ToolResult $localVersion 0 'Local manifest invocation'
    if ($localVersion.Stdout -ne "$version`r`n" -or $localVersion.Stderr) { throw 'Local manifest invocation reported an unexpected version or diagnostic.' }

    $projectRoot = Join-Path $work 'M0005 project workspace'
    $fixtureSource = Join-Path $work 'workspace fixture source'
    $toolSource = Join-Path $work 'workspace tool source'
    $workspaceFeed = Join-Path $projectRoot 'feed'
    New-Item -ItemType Directory -Force -Path $projectRoot, $workspaceFeed, $fixtureSource, $toolSource | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $fixtureSource 'fixture.txt'), 'fixtures v1')
    [System.IO.File]::WriteAllBytes((Join-Path $fixtureSource 'fixture.bin'), [byte[]](0, 255, 17, 128))
    [System.IO.File]::WriteAllText((Join-Path $toolSource 'tool.txt'), 'tools v1')
    $fixturePackage = Join-Path $workspaceFeed 'sample.workspace.fixtures.1.0.0.nupkg'
    $toolPackage = Join-Path $workspaceFeed 'sample.workspace.tools.2.0.0.nupkg'
    Assert-ToolResult (Invoke-Tool @('pack', '--id', 'sample.workspace.fixtures', '--version', '1.0.0', '--source', $fixtureSource, '--output', $fixturePackage)) 0 'M0005 fixture package creation'
    Assert-ToolResult (Invoke-Tool @('pack', '--id', 'sample.workspace.tools', '--version', '2.0.0', '--source', $toolSource, '--output', $toolPackage)) 0 'M0005 tools package creation'
    Assert-ToolResult (Invoke-Tool @('workspace', 'init', '--workspace', $projectRoot)) 0 'M0005 workspace init'
    Assert-ToolResult (Invoke-Tool @('workspace', 'add', '--alias', 'fixtures', '--package', $fixturePackage, '--workspace', $projectRoot)) 0 'M0005 fixture registration'
    Assert-ToolResult (Invoke-Tool @('workspace', 'add', '--alias', 'tools', '--package', $toolPackage, '--workspace', $projectRoot)) 0 'M0005 tools registration'
    $listed = Invoke-Tool @('workspace', 'list', '--workspace', $projectRoot, '--json')
    Assert-ToolResult $listed 0 'M0005 deterministic member list'
    if ((Assert-JsonLine $listed.Stdout 'M0005 workspace list').members.Count -ne 2) { throw 'M0005 workspace did not list both independently pinned packages.' }
    Assert-ToolResult (Invoke-Tool @('workspace', 'unpack', '--all', '--workspace', $projectRoot)) 0 'M0005 unpack all'
    $fixtureCopy = Join-Path $projectRoot 'content/fixtures'
    $toolCopy = Join-Path $projectRoot 'content/tools'
    foreach ($relative in @('fixture.txt', 'fixture.bin')) {
        if ((Get-FileHash -LiteralPath (Join-Path $fixtureSource $relative) -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath (Join-Path $fixtureCopy $relative) -Algorithm SHA256).Hash) { throw "M0005 unpack changed fixture bytes: $relative" }
    }
    if ([System.IO.File]::ReadAllText((Join-Path $toolCopy 'tool.txt')) -ne 'tools v1') { throw 'M0005 tools member unpack changed content.' }
    $cleanMembers = Invoke-Tool @('workspace', 'status', '--all', '--workspace', $projectRoot, '--json')
    Assert-ToolResult $cleanMembers 0 'M0005 all-member clean status'
    if ((Assert-JsonLine $cleanMembers.Stdout 'M0005 status').members.state -contains 'modified') { throw 'M0005 unpacked members were not clean.' }

    [System.IO.File]::WriteAllText((Join-Path $projectRoot 'Directory.Packages.props'), '<Project><ItemGroup><PackageVersion Include="sample.workspace.fixtures" Version="1.0.0" /></ItemGroup></Project>')
    [System.IO.File]::WriteAllText((Join-Path $projectRoot 'App.csproj'), '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><PackageReference Include="sample.workspace.fixtures" /></ItemGroup></Project>')
    $assetsDir = Join-Path $projectRoot 'obj'; New-Item -ItemType Directory -Force -Path $assetsDir | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $assetsDir 'project.assets.json'), '{"version":3,"libraries":{"sample.workspace.fixtures/1.0.0":{"type":"package"}}}')
    $usage = Invoke-Tool @('workspace', 'usage', '--all', '--workspace', $projectRoot, '--json')
    Assert-ToolResult $usage 0 'M0005 usage discovery'
    $usageJson = Assert-JsonLine $usage.Stdout 'M0005 usage'
    $fixtureUsage = $usageJson.members | Where-Object { $_.alias -eq 'fixtures' }
    if ($fixtureUsage.useSites.Count -ne 1 -or $fixtureUsage.useSites[0].classification -ne 'directPackageReferenceWithCentralVersion') { throw 'M0005 did not classify a direct centrally-versioned PackageReference.' }
    if ($fixtureUsage.previousAssetsEvidence.Count -ne 1 -or $fixtureUsage.previousAssetsEvidence[0].state -ne 'previousRestoreUnknownFreshness') { throw 'M0005 did not label previous assets evidence with unknown freshness.' }

    $workspaceMarker = Join-Path $projectRoot 'nuget-content.json'
    $markerBeforePack = [System.IO.File]::ReadAllBytes($workspaceMarker)
    [System.IO.File]::WriteAllText((Join-Path $fixtureCopy 'fixture.txt'), 'fixtures v2')
    $modifiedMember = Invoke-Tool @('workspace', 'status', '--alias', 'fixtures', '--workspace', $projectRoot, '--json')
    Assert-ToolResult $modifiedMember 0 'M0005 modified member status'
    if ((Assert-JsonLine $modifiedMember.Stdout 'M0005 modified status').members[0].state -ne 'modified') { throw 'M0005 modified member status was not classified.' }
    $workspacePack = Invoke-Tool @('workspace', 'pack', '--alias', 'fixtures', '--version', '1.1.0', '--workspace', $projectRoot)
    Assert-ToolResult $workspacePack 0 'M0005 member pack'
    $nextFixturePackage = Join-Path $projectRoot 'content/sample.workspace.fixtures.1.1.0.nupkg'
    if (-not (Test-Path -LiteralPath $nextFixturePackage) -or [Convert]::ToHexString($markerBeforePack) -cne [Convert]::ToHexString([System.IO.File]::ReadAllBytes($workspaceMarker))) { throw 'M0005 member pack changed its pin or failed to create its new package.' }
    $oldWorkspaceContent = [System.IO.File]::ReadAllBytes((Join-Path $fixtureCopy 'fixture.txt'))
    $newPackageBytes = [System.IO.File]::ReadAllBytes($nextFixturePackage)
    $originalFixturePackageBytes = [System.IO.File]::ReadAllBytes($fixturePackage)
    $independentToolPackageBytes = [System.IO.File]::ReadAllBytes($toolPackage)
    $markerText = [System.Text.Encoding]::UTF8.GetString($markerBeforePack)
    [System.IO.File]::WriteAllText($workspaceMarker, $markerText.Replace('"version":"1.0.0"', '"version":"1.0.1"', [System.StringComparison]::Ordinal))
    $mismatchedPackOutput = Join-Path $projectRoot 'content/mismatched-baseline.nupkg'
    $mismatchedPack = Invoke-Tool @('workspace', 'pack', '--alias', 'fixtures', '--version', '1.2.0', '--output', $mismatchedPackOutput, '--workspace', $projectRoot)
    Assert-ToolResult $mismatchedPack 1 'M0005 reject mismatched baseline before output'
    if (Test-Path -LiteralPath $mismatchedPackOutput) { throw 'M0005 mismatch pack created package output.' }
    [System.IO.File]::WriteAllBytes($workspaceMarker, $markerBeforePack)
    $failedSet = Invoke-Tool @('workspace', 'set', '--alias', 'fixtures', '--package', $nextFixturePackage, '--workspace', $projectRoot)
    Assert-ToolResult $failedSet 1 'M0005 incompatible working-copy pin transition'
    $occupiedDirectory = Join-Path $projectRoot 'content/occupied'
    New-Item -ItemType Directory -Path $occupiedDirectory | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $occupiedDirectory 'keep.txt'), 'keep')
    $failedTargetSet = Invoke-Tool @('workspace', 'set', '--alias', 'fixtures', '--package', $nextFixturePackage, '--directory', 'content/occupied', '--workspace', $projectRoot)
    Assert-ToolResult $failedTargetSet 1 'M0005 reject occupied adoption directory'
    if ($failedSet.Stdout -or $failedTargetSet.Stdout -or [Convert]::ToHexString($markerBeforePack) -cne [Convert]::ToHexString([System.IO.File]::ReadAllBytes($workspaceMarker)) -or [Convert]::ToHexString($oldWorkspaceContent) -cne [Convert]::ToHexString([System.IO.File]::ReadAllBytes((Join-Path $fixtureCopy 'fixture.txt'))) -or [Convert]::ToHexString($newPackageBytes) -cne [Convert]::ToHexString([System.IO.File]::ReadAllBytes($nextFixturePackage)) -or [Convert]::ToHexString($originalFixturePackageBytes) -cne [Convert]::ToHexString([System.IO.File]::ReadAllBytes($fixturePackage)) -or [Convert]::ToHexString($independentToolPackageBytes) -cne [Convert]::ToHexString([System.IO.File]::ReadAllBytes($toolPackage)) -or [System.IO.File]::ReadAllText((Join-Path $occupiedDirectory 'keep.txt')) -ne 'keep') { throw 'M0005 rejected transition changed pins, package files, or workspace content.' }
    $nextFixtureCopy = Join-Path $projectRoot 'content/fixtures-1.1.0'
    Assert-ToolResult (Invoke-Tool @('workspace', 'set', '--alias', 'fixtures', '--package', $nextFixturePackage, '--directory', 'content/fixtures-1.1.0', '--workspace', $projectRoot)) 0 'M0005 explicit pin advancement to new directory'
    if ([System.IO.File]::ReadAllText((Join-Path $fixtureCopy 'fixture.txt')) -ne 'fixtures v2' -or (Test-Path -LiteralPath $nextFixtureCopy)) { throw 'M0005 pin transition replaced the old directory or pre-created the new directory.' }
    Assert-ToolResult (Invoke-Tool @('workspace', 'unpack', '--alias', 'fixtures', '--workspace', $projectRoot)) 0 'M0005 unpack advanced pin'
    if ([System.IO.File]::ReadAllText((Join-Path $nextFixtureCopy 'fixture.txt')) -ne 'fixtures v2') { throw 'M0005 advanced pin did not materialize its package snapshot.' }
    $cleanAdvanced = Invoke-Tool @('workspace', 'status', '--alias', 'fixtures', '--json', '--workspace', $projectRoot)
    Assert-ToolResult $cleanAdvanced 0 'M0005 clean advanced workspace'
    if ((Assert-JsonLine $cleanAdvanced.Stdout 'M0005 advanced status').members[0].state -ne 'clean') { throw 'M0005 newly unpacked advanced workspace was not clean.' }
    $independentStatus = Invoke-Tool @('workspace', 'status', '--alias', 'tools', '--json', '--workspace', $projectRoot)
    Assert-ToolResult $independentStatus 0 'M0005 independent package remains clean'
    if ((Assert-JsonLine $independentStatus.Stdout 'M0005 independent status').members[0].version -ne '2.0.0') { throw 'M0005 advancing fixtures changed the independent tools pin.' }
    Write-Output 'M0005 installed workspace validation passed: two independent pins, unpack/modify/pack with unchanged baseline, mismatched-baseline rejection before output, failed-transition preservation, explicit higher-version adoption into a new directory, clean new workspace, and unchanged old workspace.'

    $source = Join-Path $work 'independent source'
    $workspace = Join-Path $work 'managed workspace'
    $initialPackage = Join-Path $work 'initial snapshot.nupkg'
    New-Item -ItemType Directory -Force -Path (Join-Path $source 'nested/deeper') | Out-Null
    $expectedText = [System.Text.Encoding]::UTF8.GetBytes("original snowman ☃`r`n")
    $expectedBinary = [byte[]](0, 255, 1, 128, 13, 10, 0, 42)
    [System.IO.File]::WriteAllBytes((Join-Path $source 'nested/deeper/readme.txt'), $expectedText)
    [System.IO.File]::WriteAllBytes((Join-Path $source 'nested/payload.bin'), $expectedBinary)
    $created = Invoke-Tool @('pack', '--id', 'sample.installed', '--version', '1.0.0', '--source', $source, '--output', $initialPackage)
    Assert-ToolResult $created 0 'Installed tool initial pack'
    $unpacked = Invoke-Tool @('unpack', '--package', $initialPackage, '--destination', $workspace)
    Assert-ToolResult $unpacked 0 'Installed tool unpack'
    foreach ($relative in @('nested/deeper/readme.txt', 'nested/payload.bin')) {
        $expected = [System.IO.File]::ReadAllBytes((Join-Path $source $relative))
        $actual = [System.IO.File]::ReadAllBytes((Join-Path $workspace $relative))
        if ([Convert]::ToHexString($actual) -cne [Convert]::ToHexString($expected)) { throw "Installed tool unpack changed bytes: $relative" }
    }
    $clean = Invoke-Tool @('status', '--source', $workspace, '--json')
    Assert-ToolResult $clean 0 'Clean workspace JSON'
    if ($clean.Stderr) { throw 'Clean workspace JSON emitted stderr.' }
    $cleanJson = Assert-JsonLine $clean.Stdout 'Clean workspace status'
    if ($cleanJson.schemaVersion -ne 1 -or $cleanJson.kind -ne 'workspace' -or -not $cleanJson.clean -or $cleanJson.changes.added.Count -ne 0 -or $cleanJson.changes.modified.Count -ne 0 -or $cleanJson.changes.deleted.Count -ne 0) { throw 'Clean workspace JSON does not match the public contract.' }

    [System.IO.File]::WriteAllText((Join-Path $workspace 'nested/deeper/readme.txt'), 'changed')
    Remove-Item -LiteralPath (Join-Path $workspace 'nested/payload.bin')
    [System.IO.File]::WriteAllText((Join-Path $workspace 'added.json'), '{"added":true}')
    $dirty = Invoke-Tool @('status', '--source', $workspace, '--json')
    Assert-ToolResult $dirty 0 'Dirty workspace JSON'
    $dirtyJson = Assert-JsonLine $dirty.Stdout 'Dirty workspace status'
    if ($dirtyJson.clean -or $dirtyJson.changes.added[0] -ne 'added.json' -or $dirtyJson.changes.modified[0] -ne 'nested/deeper/readme.txt' -or $dirtyJson.changes.deleted[0] -ne 'nested/payload.bin') { throw 'Dirty workspace JSON does not classify paths correctly.' }
    $textMode = Invoke-Tool @('status', '--source', $workspace)
    Assert-ToolResult $textMode 0 'Text status retention'
    if ($textMode.Stdout -notmatch 'Added: added.json' -or $textMode.Stderr) { throw 'Text status mode no longer reports changes on stdout.' }
    $conflictingSelectors = Invoke-Tool @('status', '--source', $workspace, '--package', $initialPackage, '--json')
    Assert-ToolResult $conflictingSelectors 2 'Conflicting status selectors'
    if ($conflictingSelectors.Stdout -or $conflictingSelectors.Stderr -notmatch 'cannot be used together') { throw 'Conflicting selectors did not fail cleanly as a usage error.' }

    $managedPackage = Join-Path $work 'managed snapshot.nupkg'
    $markerPath = Join-Path $workspace '.nuget-content/manifest.json'
    $markerBefore = [System.IO.File]::ReadAllBytes($markerPath)
    $repack = Invoke-Tool @('pack', '--source', $workspace, '--version', '1.1.0', '--message', 'installed update', '--output', $managedPackage)
    Assert-ToolResult $repack 0 'Installed tool managed repack'
    if ([Convert]::ToHexString($markerBefore) -cne [Convert]::ToHexString([System.IO.File]::ReadAllBytes($markerPath))) { throw 'Managed repack changed its baseline marker.' }
    $workspaceHistory = Invoke-Tool @('history', '--source', $workspace, '--json')
    Assert-ToolResult $workspaceHistory 0 'Workspace history JSON'
    $workspaceHistoryJson = Assert-JsonLine $workspaceHistory.Stdout 'Workspace history'
    if ($workspaceHistoryJson.package.version -ne '1.0.0' -or $workspaceHistoryJson.history.Count -ne 1 -or $workspaceHistoryJson.history[0].ContainsKey('message')) { throw 'Workspace history JSON does not preserve the baseline chronology or omitted message.' }
    $packageHistory = Invoke-Tool @('history', '--package', $managedPackage, '--json')
    Assert-ToolResult $packageHistory 0 'Package history JSON'
    $packageHistoryJson = Assert-JsonLine $packageHistory.Stdout 'Package history'
    if ($packageHistoryJson.package.version -ne '1.1.0' -or $packageHistoryJson.history.Count -ne 2 -or $packageHistoryJson.history[1].message -ne 'installed update') { throw 'Package history JSON does not include chronological versions and its supplied message.' }
    $packageStatus = Invoke-Tool @('status', '--package', $managedPackage, '--json')
    Assert-ToolResult $packageStatus 0 'Valid package JSON status'
    $packageStatusJson = Assert-JsonLine $packageStatus.Stdout 'Package status'
    if ($packageStatusJson.kind -ne 'package' -or -not $packageStatusJson.valid -or $packageStatusJson.fileCount -ne 2) { throw 'Package JSON status does not match the public contract.' }
    $badPackagePath = Join-Path $work 'malformed package.nupkg'
    [System.IO.File]::WriteAllText($badPackagePath, 'not a package')
    $badStatus = Invoke-Tool @('status', '--package', $badPackagePath, '--json')
    Assert-ToolResult $badStatus 1 'Invalid package JSON status'
    if ($badStatus.Stdout -or -not $badStatus.Stderr.StartsWith('error:')) { throw 'Invalid package JSON status emitted JSON or failed to use stderr.' }

    $consumer = Invoke-CapturedProcess (Get-Command pwsh).Source @('-NoProfile', '-File', $consumerScript, '-NativeExecutable', $toolShim, '-PackagePath', $managedPackage, '-ExpectedSource', $workspace) $work
    if ($consumer.Stdout) { Write-Output $consumer.Stdout.TrimEnd() }
    if ($consumer.Stderr) { [Console]::Error.WriteLine($consumer.Stderr.TrimEnd()) }
    Assert-ToolResult $consumer 0 'Independent PackageReference consumer'

    $heavySource = Join-Path $work 'many Unicode files'; $heavyWorkspace = Join-Path $work 'many Unicode unpacked'; $heavyPackage = Join-Path $work 'many Unicode.nupkg'
    $deep = $heavySource
    New-Item -ItemType Directory -Force -Path $deep | Out-Null
    foreach ($part in @('über', '深い', 'nested-segment-1234567890', 'nested-segment-abcdefghij', 'more-segment-123456', 'final-segment-abcdef')) { $deep = Join-Path $deep $part; New-Item -ItemType Directory -Force -Path $deep | Out-Null }
    $unicodePath = Join-Path $deep 'данные-☃.bin'
    $unicodeRelative = [System.IO.Path]::GetRelativePath($heavySource, $unicodePath).Replace('\', '/')
    if ($unicodePath.Length -lt 190 -or $unicodePath.Length -ge 260) { throw "Nested Unicode path length $($unicodePath.Length) did not exercise a deep supported Windows path." }
    [System.IO.File]::WriteAllBytes($unicodePath, $expectedBinary)
    for ($i = 0; $i -lt 300; $i++) { [System.IO.File]::WriteAllText((Join-Path $heavySource ("file-{0:D4}.txt" -f $i)), "value $i") }
    $heavyPack = Invoke-Tool @('pack', '--id', 'sample.many', '--version', '1.0.0', '--source', $heavySource, '--output', $heavyPackage)
    Assert-ToolResult $heavyPack 0 'Many-file Unicode pack'
    $heavyUnpack = Invoke-Tool @('unpack', '--package', $heavyPackage, '--destination', $heavyWorkspace)
    Assert-ToolResult $heavyUnpack 0 'Many-file Unicode unpack'
    if ([Convert]::ToHexString([System.IO.File]::ReadAllBytes((Join-Path $heavyWorkspace $unicodeRelative))) -cne [Convert]::ToHexString($expectedBinary)) { throw 'Unicode nested path or its bytes changed.' }
    $heavyStatus = Invoke-Tool @('status', '--package', $heavyPackage, '--json')
    Assert-ToolResult $heavyStatus 0 'Many-file package validation'
    if ((Assert-JsonLine $heavyStatus.Stdout 'Many-file package status').fileCount -ne 301) { throw 'Many-file package inventory count was incorrect.' }

    $largeSource = Join-Path $work 'large source'; $largePackage = Join-Path $work 'large payload.nupkg'; $largeWorkspace = Join-Path $work 'large workspace'
    New-Item -ItemType Directory -Force -Path $largeSource | Out-Null
    $largePath = Join-Path $largeSource 'large.bin'
    $buffer = [byte[]]::new(1MB)
    $random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $largeStream = [System.IO.File]::OpenWrite($largePath)
    try { for ($i = 0; $i -lt 64; $i++) { $random.GetBytes($buffer); $largeStream.Write($buffer) } } finally { $largeStream.Dispose(); $random.Dispose() }
    $largePackInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $largePackInfo.FileName = $installedExe
    $largePackInfo.UseShellExecute = $false
    $largePackInfo.WorkingDirectory = $work
    $largePackInfo.RedirectStandardOutput = $true
    $largePackInfo.RedirectStandardError = $true
    foreach ($argument in @('pack', '--id', 'sample.large', '--version', '1.0.0', '--source', $largeSource, '--output', $largePackage)) { [void]$largePackInfo.ArgumentList.Add($argument) }
    $largePackProcess = [System.Diagnostics.Process]::Start($largePackInfo)
    $largeStdoutTask = $largePackProcess.StandardOutput.ReadToEndAsync()
    $largeStderrTask = $largePackProcess.StandardError.ReadToEndAsync()
    $largeStageObserved = $false
    $largeFinalValidWhenObserved = $false
    $largePackWatch = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not $largePackProcess.HasExited -and $largePackWatch.Elapsed.TotalSeconds -lt 60) {
        $stagingCandidates = [System.IO.Directory]::EnumerateFiles($work, ([System.IO.Path]::GetFileName($largePackage) + '.*.tmp'))
        foreach ($candidate in $stagingCandidates) {
            if ([System.IO.FileInfo]::new($candidate).Length -ge 65536) {
                $largeStageObserved = $true
                break
            }
        }
        if (Test-Path -LiteralPath $largePackage) {
            $activeLargeStages = @([System.IO.Directory]::EnumerateFiles($work, ([System.IO.Path]::GetFileName($largePackage) + '.*.tmp')) | Where-Object { [System.IO.FileInfo]::new($_).Length -ge 65536 })
            if ($activeLargeStages.Count -gt 0) { throw 'A successful pack exposed its final package path while staged package bytes were still being written.' }
            $publishedArchive = [System.IO.Compression.ZipFile]::OpenRead($largePackage)
            try { $largeFinalValidWhenObserved = $publishedArchive.Entries.Count -gt 0 } finally { $publishedArchive.Dispose() }
            if (-not $largeFinalValidWhenObserved) { throw 'The final package path became visible before a readable package was published.' }
        }
        Start-Sleep -Milliseconds 2
    }
    $largePackWatch.Stop()
    if (-not $largePackProcess.HasExited) { $largePackProcess.Kill($true); $largePackProcess.WaitForExit(); throw 'Successful atomic-publication check exceeded 60 seconds.' }
    $largePackProcess.WaitForExit()
    $largeStdout = $largeStdoutTask.GetAwaiter().GetResult()
    $largeStderr = $largeStderrTask.GetAwaiter().GetResult()
    $largeExitCode = $largePackProcess.ExitCode
    $largePackProcess.Dispose()
    if ($largeExitCode -ne 0) { throw "64 MiB installed tool pack failed: exit=$largeExitCode stdout=[$largeStdout] stderr=[$largeStderr]" }
    if (-not (Test-Path -LiteralPath $largePackage -PathType Leaf)) { throw 'Successful pack did not publish its final package.' }
    $finalArchive = [System.IO.Compression.ZipFile]::OpenRead($largePackage)
    try { $largeFinalValidWhenObserved = $largeFinalValidWhenObserved -or $finalArchive.Entries.Count -gt 0 } finally { $finalArchive.Dispose() }
    if (-not $largeStageObserved -or -not $largeFinalValidWhenObserved) { throw 'The validation did not observe staged writes followed by a readable final package.' }
    $largeStatus = Invoke-Tool @('status', '--package', $largePackage, '--json')
    Assert-ToolResult $largeStatus 0 '64 MiB package streaming validation'
    $largeUnpack = Invoke-Tool @('unpack', '--package', $largePackage, '--destination', $largeWorkspace)
    Assert-ToolResult $largeUnpack 0 '64 MiB installed tool unpack'
    if ((Get-FileHash -LiteralPath $largePath -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath (Join-Path $largeWorkspace 'large.bin') -Algorithm SHA256).Hash) { throw 'Large payload bytes changed in installed tool lifecycle.' }

    $interruptedPath = Join-Path $work 'interrupted managed package.nupkg'
    $markerBeforeInterrupt = [System.IO.File]::ReadAllBytes($markerPath)
    $interruptPayload = Join-Path $workspace 'interrupt-large.bin'
    Copy-Item -LiteralPath $largePath -Destination $interruptPayload
    $interruptPayloadHash = (Get-FileHash -LiteralPath $interruptPayload -Algorithm SHA256).Hash
    $interruptInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $interruptInfo.FileName = $installedExe
    $interruptInfo.UseShellExecute = $false
    $interruptInfo.WorkingDirectory = $work
    foreach ($argument in @('pack', '--source', $workspace, '--version', '1.2.0', '--output', $interruptedPath)) { [void]$interruptInfo.ArgumentList.Add($argument) }
    $interruptedProcess = [System.Diagnostics.Process]::Start($interruptInfo)
    $stageFile = $null
    $stageWatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        while (-not $interruptedProcess.HasExited -and $stageWatch.Elapsed.TotalSeconds -lt 30) {
            $stagingCandidates = [System.IO.Directory]::EnumerateFiles($work, ([System.IO.Path]::GetFileName($interruptedPath) + '.*.tmp'))
            foreach ($candidate in $stagingCandidates) {
                if ([System.IO.FileInfo]::new($candidate).Length -ge 65536) { $stageFile = $candidate; break }
            }
            if ($stageFile) { break }
            Start-Sleep -Milliseconds 2
        }
        if (-not $stageFile) { throw 'Could not observe the managed package staging file exceed 64 KiB before process exit or the 30-second observation limit.' }
        $stageLengthAtTermination = [System.IO.FileInfo]::new($stageFile).Length
        if ($stageFile -notmatch '\.nupkg\.[0-9a-f]{32}\.tmp$') { throw "Observed staging path was not uniquely named: $stageFile" }
        if (Test-Path -LiteralPath $interruptedPath) { throw 'Final package path became visible while the staging file was still being written.' }
        $interruptedProcess.Kill($true)
        $interruptedProcess.WaitForExit()
    } catch {
        if (-not $interruptedProcess.HasExited) { $interruptedProcess.Kill($true); $interruptedProcess.WaitForExit() }
        throw
    } finally {
        $stageWatch.Stop()
        $interruptedProcess.Dispose()
    }
    if (Test-Path -LiteralPath $interruptedPath) { throw 'Interrupted managed pack committed a package.' }
    $remainingStage = Test-Path -LiteralPath $stageFile
    if ($remainingStage -and ([System.IO.Path]::GetExtension($stageFile) -ne '.tmp' -or (Get-Item -LiteralPath $stageFile).Length -lt 65536)) { throw 'Abrupt termination left an unexpected staging remnant.' }
    if ((Get-FileHash -LiteralPath $interruptPayload -Algorithm SHA256).Hash -ne $interruptPayloadHash) { throw 'Interrupted managed pack changed source content.' }
    if ([Convert]::ToHexString($markerBeforeInterrupt) -cne [Convert]::ToHexString([System.IO.File]::ReadAllBytes($markerPath))) { throw 'Interrupted managed pack changed its baseline marker.' }

    $conflictOutput = Join-Path $work 'preserved output.nupkg'
    [System.IO.File]::WriteAllText($conflictOutput, 'keep')
    $conflictPack = Invoke-Tool @('pack', '--id', 'sample.conflict', '--version', '1.0.0', '--source', $source, '--output', $conflictOutput)
    Assert-ToolResult $conflictPack 1 'Existing package output conflict'
    if ([System.IO.File]::ReadAllText($conflictOutput) -ne 'keep') { throw 'Existing package output was modified.' }
    $insideOutput = Join-Path $workspace 'self.nupkg'
    $insidePack = Invoke-Tool @('pack', '--source', $workspace, '--version', '1.2.0', '--output', $insideOutput)
    Assert-ToolResult $insidePack 1 'Managed workspace output conflict'
    if (Test-Path -LiteralPath $insideOutput) { throw 'Rejected managed output left a file in the workspace.' }
    $failedDestination = Join-Path $work 'failed extraction'
    $badUnpack = Invoke-Tool @('unpack', '--package', $badPackagePath, '--destination', $failedDestination)
    Assert-ToolResult $badUnpack 1 'Malformed package extraction cleanup'
    if (Test-Path -LiteralPath $failedDestination) { throw 'Malformed package left a partial extraction destination.' }
    if (@(Get-ChildItem -LiteralPath $work -Directory -Filter '.failed extraction.*.tmp').Count -ne 0) { throw 'Handled malformed-package failure left an extraction staging directory.' }

    # M0006: relative versioning, explicit pin transition, preview/apply, and real consumers.
    $projectRoot = Join-Path $work 'M0006 project root'
    $contentFeed = Join-Path $projectRoot 'feed'
    $alphaSource = Join-Path $work 'M0006 alpha source'
    $betaSource = Join-Path $work 'M0006 beta source'
    New-Item -ItemType Directory -Force -Path $projectRoot, $contentFeed, (Join-Path $alphaSource 'nested'), (Join-Path $betaSource 'nested') | Out-Null
    $alphaOriginal = [byte[]](0, 1, 2, 255, 128, 13, 10, 42)
    $alphaNext = [byte[]](9, 8, 7, 0, 255, 64, 13, 10)
    $betaOriginal = [System.Text.Encoding]::UTF8.GetBytes("beta stays pinned`r`n")
    [System.IO.File]::WriteAllBytes((Join-Path $alphaSource 'nested/payload.bin'), $alphaOriginal)
    [System.IO.File]::WriteAllBytes((Join-Path $betaSource 'nested/payload.txt'), $betaOriginal)
    $alphaInitial = Join-Path $contentFeed 'sample.alpha.1.0.0.nupkg'
    $betaInitial = Join-Path $contentFeed 'sample.beta.2.0.0.nupkg'
    foreach ($result in @(
        (Invoke-CapturedProcess $installedExe @('pack', '--id', 'sample.alpha', '--version', '1.0.0', '--source', $alphaSource, '--output', $alphaInitial) $work),
        (Invoke-CapturedProcess $installedExe @('pack', '--id', 'sample.beta', '--version', '2.0.0', '--source', $betaSource, '--output', $betaInitial) $work)
    )) { Assert-ToolResult $result 0 'M0006 initial content package creation' }
    $alphaInitialHash = (Get-FileHash -LiteralPath $alphaInitial -Algorithm SHA256).Hash
    $betaInitialHash = (Get-FileHash -LiteralPath $betaInitial -Algorithm SHA256).Hash
    $workspaceInit = Invoke-CapturedProcess $installedExe @('workspace', 'init', '--workspace', $projectRoot) $work
    Assert-ToolResult $workspaceInit 0 'M0006 workspace init'
    $alphaAdd = Invoke-CapturedProcess $installedExe @('workspace', 'add', '--alias', 'alpha', '--package', 'feed/sample.alpha.1.0.0.nupkg', '--workspace', $projectRoot) $work
    Assert-ToolResult $alphaAdd 0 'M0006 alpha workspace add'
    $betaAdd = Invoke-CapturedProcess $installedExe @('workspace', 'add', '--alias', 'beta', '--package', 'feed/sample.beta.2.0.0.nupkg', '--workspace', $projectRoot) $work
    Assert-ToolResult $betaAdd 0 'M0006 beta workspace add'
    Assert-ToolResult (Invoke-CapturedProcess $installedExe @('workspace', 'unpack', '--all', '--workspace', $projectRoot) $work) 0 'M0006 workspace unpack'
    $oldAlphaWork = Join-Path $projectRoot 'content/alpha/nested/payload.bin'
    [System.IO.File]::WriteAllBytes($oldAlphaWork, $alphaNext)
    $oracle = Join-Path $work 'M0006 independent expected source'
    New-Item -ItemType Directory -Force -Path (Join-Path $oracle 'nested') | Out-Null
    [System.IO.File]::WriteAllBytes((Join-Path $oracle 'nested/payload.bin'), $alphaNext)
    $alphaMarkerBeforePack = [System.IO.File]::ReadAllBytes((Join-Path $projectRoot 'nuget-content.json'))
    $relativePack = Invoke-CapturedProcess $installedExe @('workspace', 'pack', '--alias', 'alpha', '--patch', '--workspace', $projectRoot) $work
    Assert-ToolResult $relativePack 0 'M0006 workspace relative patch pack'
    $alphaNextPackage = Join-Path $projectRoot 'content/sample.alpha.1.0.1.nupkg'
    if (-not (Test-Path -LiteralPath $alphaNextPackage -PathType Leaf)) { throw 'M0006 relative pack did not produce its normalized 1.0.1 artifact.' }
    Copy-Item -LiteralPath $alphaNextPackage -Destination $contentFeed
    if ([Convert]::ToHexString($alphaMarkerBeforePack) -cne [Convert]::ToHexString([System.IO.File]::ReadAllBytes((Join-Path $projectRoot 'nuget-content.json')))) { throw 'M0006 workspace pack changed the root pin.' }
    $alphaOldBytes = [System.IO.File]::ReadAllBytes($oldAlphaWork)
    $setPin = Invoke-CapturedProcess $installedExe @('workspace', 'set', '--alias', 'alpha', '--package', 'content/sample.alpha.1.0.1.nupkg', '--directory', 'content/alpha-1.0.1', '--workspace', $projectRoot) $work
    Assert-ToolResult $setPin 0 'M0006 explicit safe pin transition'
    Assert-ToolResult (Invoke-CapturedProcess $installedExe @('workspace', 'unpack', '--alias', 'alpha', '--workspace', $projectRoot) $work) 0 'M0006 unpack advanced pin'
    $propsPath = Join-Path $projectRoot 'Directory.Packages.props'
    [System.IO.File]::WriteAllText($propsPath, '<Project><PropertyGroup><ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally></PropertyGroup><ItemGroup><PackageVersion Include="sample.alpha" Version="1.0.0" /><PackageVersion Include="sample.beta" Version="2.0.0" /></ItemGroup></Project>')
    $consumerA = Join-Path $projectRoot 'consumers/central/Consumer.csproj'
    $consumerB = Join-Path $projectRoot 'consumers/direct/Consumer.csproj'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $consumerA), (Split-Path -Parent $consumerB) | Out-Null
    @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net11.0</TargetFramework></PropertyGroup>
  <ItemGroup><PackageReference Include="sample.alpha" /><PackageReference Include="sample.beta" /></ItemGroup>
</Project>
'@ | Set-Content -LiteralPath $consumerA -Encoding utf8
    @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net11.0</TargetFramework><ManagePackageVersionsCentrally>false</ManagePackageVersionsCentrally></PropertyGroup>
  <ItemGroup><PackageReference Include="sample.alpha" Version="1.0.0" /><PackageReference Include="sample.beta" Version="2.0.0" /></ItemGroup>
</Project>
'@ | Set-Content -LiteralPath $consumerB -Encoding utf8
    Set-Content -LiteralPath (Join-Path (Split-Path -Parent $consumerA) 'Program.cs') -Value 'System.Console.WriteLine("central consumer");' -Encoding utf8
    Set-Content -LiteralPath (Join-Path (Split-Path -Parent $consumerB) 'Program.cs') -Value 'System.Console.WriteLine("direct consumer");' -Encoding utf8
    $preview = Invoke-CapturedProcess $installedExe @('workspace', 'references', 'update', '--alias', 'alpha', '--workspace', $projectRoot, '--json') $work
    Assert-ToolResult $preview 0 'M0006 reference preview'
    $previewPlan = Assert-JsonLine $preview.Stdout 'M0006 preview plan'
    if ($previewPlan.targetVersion -ne '1.0.1' -or -not $previewPlan.canApply -or $previewPlan.changes.Count -ne 2) { throw 'M0006 preview did not target the pinned version and both supported declarations.' }
    if ((Get-Content -Raw $propsPath) -notmatch 'sample.alpha" Version="1\.0\.0') { throw 'M0006 preview changed central version XML.' }
    $apply = Invoke-CapturedProcess $installedExe @('workspace', 'references', 'update', '--alias', 'alpha', '--workspace', $projectRoot, '--apply', '--json') $work
    Assert-ToolResult $apply 0 'M0006 reference apply'
    $applyPlan = Assert-JsonLine $apply.Stdout 'M0006 applied plan'
    if (-not $applyPlan.applied -or $applyPlan.targetVersion -ne '1.0.1') { throw 'M0006 apply result did not report the applied pinned version.' }
    if ((Get-Content -Raw $propsPath) -notmatch 'sample.alpha" Version="1\.0\.1' -or (Get-Content -Raw $consumerB) -notmatch 'sample.alpha" Version="1\.0\.1') { throw 'M0006 apply missed a central or direct declaration.' }
    $contentConfig = Join-Path $work 'M0006 content NuGet.Config'
    $escapedContentFeed = [System.Security.SecurityElement]::Escape($contentFeed)
    Set-Content -LiteralPath $contentConfig -Encoding utf8 -Value "<configuration><packageSources><clear/><add key=`"local-content`" value=`"$escapedContentFeed`" /></packageSources></configuration>"
    foreach ($projectFile in @($consumerA, $consumerB)) {
        Invoke-Checked 'dotnet' @('restore', $projectFile, '--configfile', $contentConfig) $work | Out-Null
        Invoke-Checked 'dotnet' @('build', $projectFile, '--configuration', 'Release', '--no-restore') (Split-Path -Parent $projectFile) | Out-Null
        $outputPayload = Join-Path (Split-Path -Parent $projectFile) 'bin/Release/net11.0/nested/payload.bin'
        if (-not (Test-Path -LiteralPath $outputPayload) -or (Get-FileHash -LiteralPath $outputPayload -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath (Join-Path $oracle 'nested/payload.bin') -Algorithm SHA256).Hash) { throw "M0006 consumer output bytes differ from the independently prepared source: $projectFile" }
        if (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $projectFile) 'bin/Release/net11.0/.nuget-content')) { throw 'M0006 package manifest metadata leaked into consumer output.' }
    }
    if ([Convert]::ToHexString($alphaOldBytes) -cne [Convert]::ToHexString([System.IO.File]::ReadAllBytes($oldAlphaWork))) { throw 'M0006 pin transition changed the old alpha work copy.' }
    if ((Get-FileHash -LiteralPath $alphaInitial -Algorithm SHA256).Hash -ne $alphaInitialHash -or (Get-FileHash -LiteralPath $betaInitial -Algorithm SHA256).Hash -ne $betaInitialHash) { throw 'M0006 lifecycle changed an original package snapshot.' }
    $pins = Invoke-CapturedProcess $installedExe @('workspace', 'list', '--workspace', $projectRoot, '--json') $work
    Assert-ToolResult $pins 0 'M0006 final pin listing'
    $pinList = Assert-JsonLine $pins.Stdout 'M0006 pin list'
    if ($pinList.members[0].alias -ne 'alpha' -or $pinList.members[0].version -ne '1.0.1' -or $pinList.members[1].alias -ne 'beta' -or $pinList.members[1].version -ne '2.0.0') { throw 'M0006 lifecycle changed an unrelated package pin.' }
    Write-Output "M0006 installed reference workflow passed. alpha initial SHA-256: $alphaInitialHash; beta snapshot SHA-256: $betaInitialHash; independent output oracle: $((Get-FileHash -LiteralPath (Join-Path $oracle 'nested/payload.bin') -Algorithm SHA256).Hash)"

    $updateTop = Join-Path $work 'update pack'
    New-ToolPackage $updateVersion $updateTop
    Copy-Item -LiteralPath (Join-Path $updateTop "top-level/$packageId.$updateVersion.nupkg") -Destination $feed
    Copy-Item -LiteralPath (Join-Path $updateTop "win-x64/$packageId.win-x64.$updateVersion.nupkg") -Destination $feed
    Invoke-Checked 'dotnet' @('tool', 'update', $packageId, '--tool-path', $toolPath, '--version', $updateVersion, '--configfile', $config) | Out-Null
    $updated = Invoke-Tool @('--version')
    Assert-ToolResult $updated 0 'Updated global-equivalent tool'
    if ($updated.Stdout -ne "$updateVersion`r`n") { throw 'Global-equivalent update did not select the requested version.' }
    Invoke-Checked 'dotnet' @('tool', 'update', $packageId, '--local', '--tool-manifest', $localManifest, '--version', $updateVersion, '--configfile', $config) $localProject | Out-Null
    $localUpdated = Invoke-LocalTool @('--version')
    Assert-ToolResult $localUpdated 0 'Updated local manifest tool'
    if ($localUpdated.Stdout -ne "$updateVersion`r`n") { throw 'Local manifest update did not select the requested version.' }
    Invoke-Checked 'dotnet' @('tool', 'uninstall', $packageId, '--tool-path', $toolPath) | Out-Null
    if (Test-Path -LiteralPath $toolShim) { throw 'Global-equivalent uninstall left the tool shim.' }
    Invoke-Checked 'dotnet' @('tool', 'uninstall', $packageId, '--local', '--tool-manifest', $localManifest) $localProject | Out-Null
    $localList = Invoke-Checked 'dotnet' @('tool', 'list', '--local') $localProject
    if ($localList.Stdout -match [regex]::Escape($packageId)) { throw 'Local tool uninstall left the package in its manifest.' }

    Write-Output "M0003 installed tool validation passed."
    Write-Output "Local feed: $feed"
    Write-Output "Global-equivalent/local installs, updates and uninstalls: $version -> $updateVersion"
    Write-Output "Installed Native AOT PE: $installedExe"
    Write-Output "Installed executable SHA-256: $nativeHash"
    Write-Output "Top-level package SHA-256: $((Get-FileHash -LiteralPath $topPackage -Algorithm SHA256).Hash)"
    Write-Output "win-x64 package SHA-256: $((Get-FileHash -LiteralPath $ridPackage -Algorithm SHA256).Hash)"
    Write-Output "Longest tested Unicode path length: $($unicodePath.Length) characters"
    Write-Output "Forced termination observed a $stageLengthAtTermination-byte staging file; final path stayed absent; staging remnant after kill: $remainingStage."
    Write-Output 'Handled malformed-package failure separately removed its staging directory; installed lifecycle, JSON/text streams, independent consumer byte oracle, 301 files, nested Unicode path, 64 MiB payload, and conflict checks passed.'
}
finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
