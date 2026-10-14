param(
    [string] $NativeExecutable = (Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts/win-x64/dotnet-nuget-content.exe')
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
    $textBytes = [System.Text.Encoding]::UTF8.GetBytes("consumer text ☃`r`n")
    $binaryBytes = [byte[]](0, 255, 1, 128, 13, 10, 0, 42)
    [System.IO.File]::WriteAllBytes((Join-Path $source 'nested/deeper/data.txt'), $textBytes)
    [System.IO.File]::WriteAllBytes((Join-Path $source 'nested/payload.bin'), $binaryBytes)

    $packResult = Invoke-NativeCli @('pack', '--id', $packageId, '--version', $version, '--source', $source, '--output', $package)
    if ($packResult.ExitCode -ne 0 -or $packResult.Stderr -ne '' -or $packResult.Stdout.Trim() -ne "Created $package") {
        throw "Native pack failed in consumer validation (exit $($packResult.ExitCode)). stdout: $($packResult.Stdout) stderr: $($packResult.Stderr)"
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
    $actualText = [System.IO.File]::ReadAllBytes((Join-Path $output 'nested/deeper/data.txt'))
    $actualBinary = [System.IO.File]::ReadAllBytes((Join-Path $output 'nested/payload.bin'))
    if ([Convert]::ToHexString($actualText) -ne [Convert]::ToHexString($textBytes)) { throw 'Consumer text content differs from the packaged source.' }
    if ([Convert]::ToHexString($actualBinary) -ne [Convert]::ToHexString($binaryBytes)) { throw 'Consumer binary content differs from the packaged source.' }

    Write-Output "Consumer validation passed using native executable: $nativePath"
    Write-Output "Consumer package: $package"
    Write-Output "Text SHA-256: $([Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($actualText)))"
    Write-Output "Binary SHA-256: $([Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($actualBinary)))"
}
finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
