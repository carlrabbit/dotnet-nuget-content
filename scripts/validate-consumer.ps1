$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repoRoot 'src/DotnetNugetContent/DotnetNugetContent.csproj'
$work = Join-Path ([System.IO.Path]::GetTempPath()) ('dotnet-nuget-content-consumer-' + [guid]::NewGuid().ToString('N'))
$feed = Join-Path $work 'feed'
$source = Join-Path $work 'source'
$consumer = Join-Path $work 'consumer'
$packageId = 'dnc.consumer.validation'
$version = '1.0.0'
$package = Join-Path $feed "$packageId.$version.nupkg"
$cliDll = Join-Path $repoRoot 'src/DotnetNugetContent/bin/Release/net11.0/dotnet-nuget-content.dll'

function Invoke-Dotnet([string[]] $Arguments) {
    & dotnet @Arguments
    if ($LASTEXITCODE -ne 0) { throw "dotnet $($Arguments -join ' ') failed with exit code $LASTEXITCODE" }
}

try {
    New-Item -ItemType Directory -Force -Path $feed, (Join-Path $source 'nested/deeper'), $consumer | Out-Null
    $textBytes = [System.Text.Encoding]::UTF8.GetBytes("consumer text ☃`r`n")
    $binaryBytes = [byte[]](0, 255, 1, 128, 13, 10, 0, 42)
    [System.IO.File]::WriteAllBytes((Join-Path $source 'nested/deeper/data.txt'), $textBytes)
    [System.IO.File]::WriteAllBytes((Join-Path $source 'nested/payload.bin'), $binaryBytes)

    Invoke-Dotnet @('build', $project, '--configuration', 'Release')
    Invoke-Dotnet @($cliDll, 'pack', '--id', $packageId, '--version', $version, '--source', $source, '--output', $package)

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

    Write-Output "Consumer validation passed: $package"
    Write-Output "Text SHA-256: $([Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($actualText)))"
    Write-Output "Binary SHA-256: $([Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($actualBinary)))"
}
finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
