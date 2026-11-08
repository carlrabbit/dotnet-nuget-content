param([string] $CandidateDirectory)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repoRoot 'src/DotnetNugetContent/DotnetNugetContent.csproj'
$runId = [guid]::NewGuid().ToString('N')
$work = Join-Path ([System.IO.Path]::GetTempPath()) "dotnet nuget native validation $runId"
$publishDirectory = Join-Path $work 'native publish'
$executable = Join-Path $publishDirectory 'dotnet-nuget-content.exe'

function Invoke-CapturedProcess([string] $FilePath, [string[]] $Arguments, [string] $WorkingDirectory) {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.UseShellExecute = $false
    if ($WorkingDirectory) { $startInfo.WorkingDirectory = $WorkingDirectory }
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$startInfo.ArgumentList.Add($argument) }

    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    [pscustomobject]@{
        ExitCode = $process.ExitCode
        Stdout = $stdoutTask.GetAwaiter().GetResult()
        Stderr = $stderrTask.GetAwaiter().GetResult()
    }
}

function Invoke-Native([string[]] $Arguments) {
    Invoke-CapturedProcess $executable $Arguments
}

function Assert-NativeResult($Result, [int] $ExitCode, [string] $ExpectedStdout, [string] $ExpectedStderr, [string] $Label) {
    if ($Result.ExitCode -ne $ExitCode -or $Result.Stdout -ne $ExpectedStdout -or $Result.Stderr -ne $ExpectedStderr) {
        throw "$Label failed. Expected exit=$ExitCode, stdout=[$ExpectedStdout], stderr=[$ExpectedStderr]; got exit=$($Result.ExitCode), stdout=[$($Result.Stdout)], stderr=[$($Result.Stderr)]."
    }
}

function Add-ZipTextEntry([System.IO.Compression.ZipArchive] $Archive, [string] $Name, [string] $Text) {
    $entry = $Archive.CreateEntry($Name)
    $writer = [System.IO.StreamWriter]::new($entry.Open(), [System.Text.UTF8Encoding]::new($false))
    try { $writer.Write($Text) } finally { $writer.Dispose() }
}

try {
    New-Item -ItemType Directory -Force -Path $publishDirectory, $work | Out-Null

    New-Item -ItemType Directory -Force -Path $publishDirectory, $work | Out-Null
    if ($CandidateDirectory) {
        $candidateRoot = (Resolve-Path -LiteralPath $CandidateDirectory).Path
        $ridPackage = Join-Path $candidateRoot 'dotnet-nuget-content.win-x64.2.0.0.nupkg'
        if (-not (Test-Path -LiteralPath $ridPackage -PathType Leaf)) { throw "Candidate RID package is missing: $ridPackage" }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [System.IO.Compression.ZipFile]::OpenRead($ridPackage)
        try {
            $nativeEntry = $archive.GetEntry('tools/any/win-x64/dotnet-nuget-content.exe')
            if (-not $nativeEntry) { throw 'Candidate RID package has no win-x64 Native AOT executable.' }
            $entryStream = $nativeEntry.Open()
            $targetStream = [System.IO.File]::Open($executable, [System.IO.FileMode]::CreateNew)
            try { $entryStream.CopyTo($targetStream) } finally { $targetStream.Dispose(); $entryStream.Dispose() }
        } finally { $archive.Dispose() }
        Write-Output "Using exact candidate RID package: $ridPackage"
        Write-Output "Candidate RID package SHA-256: $((Get-FileHash -LiteralPath $ridPackage -Algorithm SHA256).Hash)"
    } else {
        $publish = Invoke-CapturedProcess 'dotnet' @(
            'publish', $project, '-c', 'Release', '-r', 'win-x64', '--self-contained', 'true', '-o', $publishDirectory
        )
        if ($publish.Stdout) { Write-Output $publish.Stdout.TrimEnd() }
        if ($publish.Stderr) { [Console]::Error.WriteLine($publish.Stderr.TrimEnd()) }
        if ($publish.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $executable -PathType Leaf)) {
            throw "Fresh Native AOT publish failed with exit code $($publish.ExitCode)."
        }
    }

    $help = Invoke-Native @('--help')
    if ($help.ExitCode -ne 0 -or $help.Stderr -ne '' -or $help.Stdout -notmatch '(?m)^Usage:') { throw 'Native --help did not return usage on stdout with exit 0 and empty stderr.' }
    $version = Invoke-Native @('--version')
    Assert-NativeResult $version 0 "2.0.0$([Environment]::NewLine)" '' 'Native --version'
    $unknown = Invoke-Native @('no-such-command')
    if ($unknown.ExitCode -ne 2 -or $unknown.Stdout -ne '' -or $unknown.Stderr -notmatch "^error: Unknown command 'no-such-command'\.") { throw 'Unknown command did not return the documented usage error on stderr with exit 2.' }
    $badOptions = Invoke-Native @('pack', '--id', 'sample')
    if ($badOptions.ExitCode -ne 2 -or $badOptions.Stdout -ne '' -or $badOptions.Stderr -notmatch '^error: Specify exactly one of --version, --major, --minor, or --patch\.') { throw 'Malformed command options did not return the documented usage error on stderr with exit 2.' }

    $source = Join-Path $work 'source files with spaces'
    $feed = Join-Path $work 'package feed with spaces'
    $destination = Join-Path $work 'extracted content with spaces'
    New-Item -ItemType Directory -Force -Path (Join-Path $source 'nested/deeper'), $feed | Out-Null
    $textBytes = [System.Text.Encoding]::UTF8.GetBytes("native text ☃`r`n")
    $binaryBytes = [byte[]](0, 255, 1, 128, 13, 10, 0, 42)
    $textPath = Join-Path $source 'nested/deeper/readme.txt'
    $binaryPath = Join-Path $source 'nested/payload.bin'
    [System.IO.File]::WriteAllBytes($textPath, $textBytes)
    [System.IO.File]::WriteAllBytes($binaryPath, $binaryBytes)
    $package = Join-Path $feed 'sample.native.1.2.3.nupkg'

    $packed = Invoke-Native @('pack', '--id', 'sample.native', '--version', '1.2.3', '--source', $source, '--output', $package)
    Assert-NativeResult $packed 0 "Created $package$([Environment]::NewLine)" '' 'Native pack with paths containing spaces'
    $unpacked = Invoke-Native @('unpack', '--package', $package, '--destination', $destination)
    Assert-NativeResult $unpacked 0 "Extracted to $destination$([Environment]::NewLine)" '' 'Native unpack with paths containing spaces'
    if ([Convert]::ToHexString([System.IO.File]::ReadAllBytes((Join-Path $destination 'nested/deeper/readme.txt'))) -ne [Convert]::ToHexString($textBytes)) { throw 'Native text round-trip changed bytes.' }
    if ([Convert]::ToHexString([System.IO.File]::ReadAllBytes((Join-Path $destination 'nested/payload.bin'))) -ne [Convert]::ToHexString($binaryBytes)) { throw 'Native binary round-trip changed bytes.' }

    $clean = Invoke-Native @('status', '--source', $destination)
    Assert-NativeResult $clean 0 "Clean$([Environment]::NewLine)" '' 'Managed clean status'
    $implicitStatus = Invoke-CapturedProcess $executable @('status') $destination
    Assert-NativeResult $implicitStatus 0 "Clean$([Environment]::NewLine)" '' 'Implicit current-directory status'
    [System.IO.File]::WriteAllText((Join-Path $destination 'nested/deeper/readme.txt'), 'managed update')
    Remove-Item -LiteralPath (Join-Path $destination 'nested/payload.bin')
    [System.IO.File]::WriteAllText((Join-Path $destination 'added.json'), '{"added":true}')
    $changed = Invoke-Native @('status', '--source', $destination)
    if ($changed.ExitCode -ne 0 -or $changed.Stdout -notmatch 'Added: added.json' -or $changed.Stdout -notmatch 'Modified: nested/deeper/readme.txt' -or $changed.Stdout -notmatch 'Deleted: nested/payload.bin') { throw 'Managed status did not distinguish added, modified, and deleted files.' }
    $managedPackage = Join-Path $work 'sample.native.1.2.4.nupkg'
    $implicitPack = Invoke-CapturedProcess $executable @('pack', '--patch', '--message', 'native lifecycle') $destination
    Assert-NativeResult $implicitPack 0 "Created $managedPackage$([Environment]::NewLine)" '' 'Implicit-root managed pack default output'
    $implicitInventory = Invoke-Native @('status', '--source', $destination)
    Assert-NativeResult $implicitInventory 0 "Clean$([Environment]::NewLine)" '' 'Managed pack advances the existing baseline'
    $history = Invoke-Native @('history', '--package', $managedPackage)
    if ($history.ExitCode -ne 0 -or $history.Stdout -notmatch '1.2.3' -or $history.Stdout -notmatch '1.2.4' -or $history.Stdout -notmatch 'native lifecycle') { throw 'Managed package history did not show ordered lineage and its supplied message.' }
    $implicitHistory = Invoke-CapturedProcess $executable @('history') $destination
    if ($implicitHistory.ExitCode -ne 0 -or $implicitHistory.Stdout -notmatch '1.2.3' -or $implicitHistory.Stdout -notmatch '1.2.4') { throw 'Implicit current-directory history did not read the advanced workspace baseline.' }
    $packageStatus = Invoke-Native @('status', '--package', $managedPackage)
    if ($packageStatus.ExitCode -ne 0 -or $packageStatus.Stdout -notmatch 'Package valid: 2 files') { throw 'Managed package inventory validation failed.' }
    $nestedStatus = Invoke-CapturedProcess $executable @('status') (Join-Path $destination 'nested')
    if ($nestedStatus.ExitCode -ne 1 -or $nestedStatus.Stdout -ne '' -or $nestedStatus.Stderr -notmatch 'Managed workspace marker not found') { throw 'Nested current directory unexpectedly discovered a workspace ancestor.' }

    $packageHash = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash
    $hash = Invoke-Native @('hash', '--path', $package, '--expect', $packageHash)
    Assert-NativeResult $hash 0 "$packageHash$([Environment]::NewLine)" '' 'Native hash with a path containing spaces'
    $hashMismatch = Invoke-Native @('hash', '--path', $package, '--expect', ('0' * 64))
    if ($hashMismatch.ExitCode -ne 1 -or $hashMismatch.Stdout -ne '' -or $hashMismatch.Stderr -notmatch '^error: SHA-256 mismatch') { throw 'Hash mismatch did not return an operation failure on stderr with exit 1.' }

    $existingDestination = Join-Path $work 'existing destination with spaces'
    New-Item -ItemType Directory -Path $existingDestination | Out-Null
    $keepPath = Join-Path $existingDestination 'keep.txt'
    [System.IO.File]::WriteAllText($keepPath, 'preserve me')
    $existing = Invoke-Native @('unpack', '--package', $package, '--destination', $existingDestination)
    if ($existing.ExitCode -ne 1 -or $existing.Stdout -ne '' -or $existing.Stderr -ne "error: Destination already exists: $existingDestination$([Environment]::NewLine)") { throw 'Existing destination did not fail predictably.' }
    if ([System.IO.File]::ReadAllText($keepPath) -ne 'preserve me') { throw 'Existing destination file was modified.' }

    $malformedPackage = Join-Path $work 'malformed package.nupkg'
    [System.IO.File]::WriteAllText($malformedPackage, 'not a ZIP package')
    $malformedDestination = Join-Path $work 'malformed output with spaces'
    $malformed = Invoke-Native @('unpack', '--package', $malformedPackage, '--destination', $malformedDestination)
    Assert-NativeResult $malformed 1 '' "error: Invalid NuGet package.$([Environment]::NewLine)" 'Malformed package diagnostics'
    if (Test-Path -LiteralPath $malformedDestination) { throw 'Malformed package created a destination.' }

    $partialPackage = Join-Path $work 'partial package.nupkg'
    $stream = [System.IO.File]::Create($partialPackage)
    try {
        $archive = [System.IO.Compression.ZipArchive]::new($stream, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            Add-ZipTextEntry $archive 'partial.nuspec' '<?xml version="1.0"?><package xmlns="http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd"><metadata><id>partial</id><version>1.0.0</version><authors>test</authors><description>test</description></metadata></package>'
            Add-ZipTextEntry $archive 'contentFiles/any/any/first.txt' 'must not be committed'
            Add-ZipTextEntry $archive 'contentFiles/any/any/../../escape.txt' 'unsafe'
        } finally { $archive.Dispose() }
    } finally { $stream.Dispose() }
    $partialDestination = Join-Path $work 'partial output with spaces'
    $partial = Invoke-Native @('unpack', '--package', $partialPackage, '--destination', $partialDestination)
    if ($partial.ExitCode -ne 1 -or $partial.Stdout -ne '' -or $partial.Stderr -notmatch "^error: Unsafe package path 'contentFiles/any/any/\.\./\.\./escape\.txt'\.") { throw 'Unsafe package failure did not produce the expected operation diagnostic.' }
    if (Test-Path -LiteralPath $partialDestination) { throw 'Failed extraction left a partial destination.' }
    if (@(Get-ChildItem -LiteralPath $work -Directory -Force -Filter '.partial output with spaces.*.tmp').Count -ne 0) { throw 'Failed extraction left a staging directory.' }

    $consumerScript = Join-Path $PSScriptRoot 'validate-consumer.ps1'
    $consumer = Invoke-CapturedProcess (Get-Command pwsh).Source @('-NoProfile', '-File', $consumerScript, '-NativeExecutable', $executable, '-PackagePath', $managedPackage, '-ExpectedSource', $destination)
    if ($consumer.Stdout) { Write-Output $consumer.Stdout.TrimEnd() }
    if ($consumer.Stderr) { [Console]::Error.WriteLine($consumer.Stderr.TrimEnd()) }
    if ($consumer.ExitCode -ne 0) { throw "Native NuGet consumer validation failed with exit code $($consumer.ExitCode)." }

    [System.IO.File]::WriteAllText((Join-Path $destination 'next.json'), '{"next":true}')
    $explicitDefault = Invoke-Native @('pack', '--patch', '--source', $destination)
    $explicitPackage = Join-Path $work 'sample.native.1.2.5.nupkg'
    Assert-NativeResult $explicitDefault 0 "Created $explicitPackage$([Environment]::NewLine)" '' 'Explicit-root managed pack default output'
    $workspaceStatus = Invoke-Native @('status', '--source', $destination)
    Assert-NativeResult $workspaceStatus 0 "Clean$([Environment]::NewLine)" '' 'Explicit-source managed pack advances its baseline'
    [System.IO.File]::WriteAllText((Join-Path $destination 'repeat.json'), '{"repeat":true}')
    $repeatedPatch = Invoke-CapturedProcess $executable @('pack', '--patch') $destination
    $repeatedPackage = Join-Path $work 'sample.native.1.2.6.nupkg'
    Assert-NativeResult $repeatedPatch 0 "Created $repeatedPackage$([Environment]::NewLine)" '' 'Repeated in-place managed patch'
    $repeatedStatus = Invoke-Native @('status', '--source', $destination)
    Assert-NativeResult $repeatedStatus 0 "Clean$([Environment]::NewLine)" '' 'Repeated managed patch leaves a clean baseline'
    $repeatedHistory = Invoke-CapturedProcess $executable @('history') $destination
    if ($repeatedHistory.ExitCode -ne 0 -or $repeatedHistory.Stdout -notmatch '1.2.4' -or $repeatedHistory.Stdout -notmatch '1.2.5' -or $repeatedHistory.Stdout -notmatch '1.2.6') { throw 'Repeated in-place patches did not append ordered baseline history.' }
    [System.IO.File]::WriteAllText((Join-Path $destination 'pending-output-check.json'), '{"pending":true}')
    $insideOutput = Join-Path $destination 'self.nupkg'
    $insideResult = Invoke-Native @('pack', '--patch', '--source', $destination, '--output', $insideOutput)
    if ($insideResult.ExitCode -ne 1 -or $insideResult.Stdout -ne '' -or $insideResult.Stderr -notmatch 'Managed package output cannot be inside the workspace' -or (Test-Path -LiteralPath $insideOutput)) { throw 'Explicit output inside the managed workspace was not rejected cleanly.' }

    $item = Get-Item -LiteralPath $executable
    $sha256 = (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash
    Write-Output "Native process validation passed: $executable"
    Write-Output "Native executable size: $($item.Length) bytes"
    Write-Output "Native executable SHA-256: $sha256"
    Write-Output 'Native help/version, stdout/stderr ownership, exit codes, spaced paths, hashes, malformed input, destination preservation, and byte-exact round-trip passed.'
}
finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
