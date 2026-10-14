param(
    [string] $NativeExecutable = (Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts/win-x64/dotnet-nuget-content.exe'),
    [string] $PackagePath
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

try {
    New-Item -ItemType Directory -Force -Path $feed, (Join-Path $source 'nested/deeper'), $consumer | Out-Null
    if (-not $PackagePath) {
        $textBytes = [System.Text.Encoding]::UTF8.GetBytes("consumer text ☃`r`n")
        $binaryBytes = [byte[]](0, 255, 1, 128, 13, 10, 0, 42)
        [System.IO.File]::WriteAllBytes((Join-Path $source 'nested/deeper/data.txt'), $textBytes)
        [System.IO.File]::WriteAllBytes((Join-Path $source 'nested/payload.bin'), $binaryBytes)
        $expectedRoot = Join-Path $consumer 'expected'
        New-Item -ItemType Directory -Force -Path $expectedRoot | Out-Null
        Copy-Item -Path (Join-Path $source '*') -Destination $expectedRoot -Recurse
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
            $textBytes = $null
            $binaryBytes = $null
            foreach ($file in $manifest.files) {
                $payload = $archive.GetEntry("contentFiles/any/any/$($file.path)")
                if (-not $payload) { throw "Manifest payload missing: $($file.path)" }
                $input = $payload.Open(); $memory = [System.IO.MemoryStream]::new()
                try { $input.CopyTo($memory); $bytes = $memory.ToArray() } finally { $input.Dispose(); $memory.Dispose() }
                if ([Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)) -ne $file.sha256) { throw "Manifest hash mismatch: $($file.path)" }
                $expectedPath = Join-Path $consumer ("expected/" + $file.path.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $expectedPath) | Out-Null
                [System.IO.File]::WriteAllBytes($expectedPath, $bytes)
            }
        } finally { $archive.Dispose() }
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
    foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $consumer 'expected') -File -Recurse)) {
        $relative = [System.IO.Path]::GetRelativePath((Join-Path $consumer 'expected'), $file.FullName)
        $actual = Join-Path $output $relative
        if (-not (Test-Path -LiteralPath $actual) -or [Convert]::ToHexString([System.IO.File]::ReadAllBytes($actual)) -ne [Convert]::ToHexString([System.IO.File]::ReadAllBytes($file.FullName))) { throw "Consumer payload differs: $relative" }
    }
    if (Test-Path -LiteralPath (Join-Path $output '.nuget-content')) { throw 'Manifest metadata leaked into consumer output.' }

    Write-Output "Consumer validation passed using native executable: $nativePath"
    Write-Output "Consumer package: $package"
    Write-Output "Consumed manifest package: $packageId $version"
}
finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
