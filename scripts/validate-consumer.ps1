param(
    [string] $NativeExecutable = (Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts/win-x64/dotnet-nuget-content.exe'),
    [string] $PackagePath,
    [string] $ExpectedSource
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$work = Join-Path ([System.IO.Path]::GetTempPath()) ('dotnet nuget content consumer-' + [guid]::NewGuid().ToString('N'))
$feed = Join-Path $work 'feed'
$source = Join-Path $work 'source'
$consumer = Join-Path $work 'consumer'
$packageId = 'dnc.consumer.validation'
$version = '1.0.0'
$package = Join-Path $feed "$packageId.$version.nupkg"

if (-not (Test-Path -LiteralPath $NativeExecutable -PathType Leaf)) {
    throw "Native executable not found: $NativeExecutable. Run scripts/validate-native.ps1 first."
}
$nativePath = (Resolve-Path -LiteralPath $NativeExecutable).Path

function Invoke-Dotnet([string[]] $Arguments) {
    & dotnet @Arguments
    if ($LASTEXITCODE -ne 0) { throw "dotnet $($Arguments -join ' ') failed with exit code $LASTEXITCODE" }
}

function Invoke-NativeCli([string[]] $Arguments) {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $nativePath
    $startInfo.UseShellExecute = $false
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

function Compare-FileBytes([string] $Left, [string] $Right) {
    $leftStream = [System.IO.File]::OpenRead($Left)
    $rightStream = [System.IO.File]::OpenRead($Right)
    try {
        if ($leftStream.Length -ne $rightStream.Length) { return $false }
        $leftBuffer = [byte[]]::new(65536)
        $rightBuffer = [byte[]]::new(65536)
        while ($true) {
            $leftCount = $leftStream.Read($leftBuffer, 0, $leftBuffer.Length)
            $rightCount = $rightStream.Read($rightBuffer, 0, $rightBuffer.Length)
            if ($leftCount -ne $rightCount) { return $false }
            if ($leftCount -eq 0) { return $true }
            for ($index = 0; $index -lt $leftCount; $index++) {
                if ($leftBuffer[$index] -ne $rightBuffer[$index]) { return $false }
            }
        }
    } finally { $leftStream.Dispose(); $rightStream.Dispose() }
}

try {
    New-Item -ItemType Directory -Force -Path $feed, (Join-Path $source 'nested/deeper'), $consumer | Out-Null
    if (-not $PackagePath) {
        $textBytes = [System.Text.Encoding]::UTF8.GetBytes("consumer text ☃`r`n")
        $binaryBytes = [byte[]](0, 255, 1, 128, 13, 10, 0, 42)
        [System.IO.File]::WriteAllBytes((Join-Path $source 'nested/deeper/data.txt'), $textBytes)
        [System.IO.File]::WriteAllBytes((Join-Path $source 'nested/payload.bin'), $binaryBytes)
        $ExpectedSource = $source
        $packResult = Invoke-NativeCli @('pack', '--id', $packageId, '--version', $version, '--source', $source, '--output', $package)
        if ($packResult.ExitCode -ne 0 -or $packResult.Stderr -ne '') { throw "Native pack failed in consumer validation: $($packResult.Stderr)" }
    } else {
        $archive = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $PackagePath).Path)
        try {
            $entry = $archive.GetEntry('.nuget-content/manifest.json')
            if (-not $entry) { throw 'Managed package is missing its public manifest.' }
            $reader = [System.IO.StreamReader]::new($entry.Open())
            try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
            $packageId = $manifest.package.id
            $version = $manifest.package.version
            $package = Join-Path $feed "$packageId.$version.nupkg"
            Copy-Item -LiteralPath $PackagePath -Destination $package
            if (-not $ExpectedSource -or -not (Test-Path -LiteralPath $ExpectedSource -PathType Container)) { throw 'An independent ExpectedSource workspace directory is required with PackagePath.' }
            $ExpectedSource = (Resolve-Path -LiteralPath $ExpectedSource).Path
            foreach ($file in $manifest.files) {
                $expectedPath = Join-Path $ExpectedSource $file.path.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
                if (-not (Test-Path -LiteralPath $expectedPath -PathType Leaf)) { throw "Independent workspace file missing: $($file.path)" }
                $item = Get-Item -LiteralPath $expectedPath
                if ($item.Length -ne $file.size -or (Get-FileHash -LiteralPath $expectedPath -Algorithm SHA256).Hash -ne $file.sha256) { throw "Workspace source differs from manifest: $($file.path)" }
            }
            $workspaceFiles = @(Get-ChildItem -LiteralPath $ExpectedSource -File -Recurse | ForEach-Object { [System.IO.Path]::GetRelativePath($ExpectedSource, $_.FullName).Replace('\', '/') } | Where-Object { $_ -ne '.nuget-content/manifest.json' } | Sort-Object -CaseSensitive)
            $manifestFiles = @($manifest.files | ForEach-Object { $_.path } | Sort-Object -CaseSensitive)
            if (($workspaceFiles -join "`n") -cne ($manifestFiles -join "`n")) { throw 'Workspace source file paths differ from package manifest inventory.' }
        } finally { $archive.Dispose() }
    }
    if (-not $manifestFiles) {
        $manifestFiles = @(Get-ChildItem -LiteralPath $ExpectedSource -File -Recurse | ForEach-Object { [System.IO.Path]::GetRelativePath($ExpectedSource, $_.FullName).Replace('\', '/') } | Sort-Object -CaseSensitive)
    }

    @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net11.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="$packageId" Version="$version" />
  </ItemGroup>
</Project>
"@ | Set-Content -LiteralPath (Join-Path $consumer 'Consumer.csproj') -Encoding utf8
    Set-Content -LiteralPath (Join-Path $consumer 'Program.cs') -Value 'Console.WriteLine("consumer build");' -Encoding utf8

    Invoke-Dotnet @('restore', (Join-Path $consumer 'Consumer.csproj'), '--source', $feed)
    Invoke-Dotnet @('build', (Join-Path $consumer 'Consumer.csproj'), '--configuration', 'Release', '--no-restore')

    $output = Join-Path $consumer 'bin/Release/net11.0'
    foreach ($relative in $manifestFiles) {
        $actual = Join-Path $output $relative
        $expectedPath = Join-Path $ExpectedSource $relative
        if (-not (Test-Path -LiteralPath $actual) -or -not (Compare-FileBytes $expectedPath $actual)) { throw "Consumer payload differs from independent workspace source: $relative" }
    }
    if (Test-Path -LiteralPath (Join-Path $output '.nuget-content')) { throw 'Manifest metadata leaked into consumer output.' }

    Write-Output "Consumer validation passed using native executable: $nativePath"
    Write-Output "Consumer package: $package"
    Write-Output "Consumed manifest package: $packageId $version"
    Write-Output "Independent expected source: $ExpectedSource"
}
finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
