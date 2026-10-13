# dotnet-nuget-content

`dotnet-nuget-content` creates immutable NuGet packages containing arbitrary files and extracts those packages into working directories. Consumers use ordinary NuGet `PackageReference` restore; package payloads are declared as `contentFiles` and copied to build output with their relative paths preserved.

The CLI targets `net11.0` and is published as a self-contained Native AOT executable. Published binaries do not require a .NET runtime or SDK to run. Building and publishing require the .NET 11 RC SDK; Native AOT also requires the platform's native compiler toolchain. The initial implementation uses `NuGet.Packaging` 7.9.0 directly for package creation and reading. The SDK `dotnet pack` fallback is not used.

## Commands

```text
dotnet-nuget-content --help
dotnet-nuget-content --version
dotnet-nuget-content pack --id sample.data --version 1.0.0 --source ./content --output ./feed/sample.data.1.0.0.nupkg
dotnet-nuget-content unpack --package ./feed/sample.data.1.0.0.nupkg --destination ./working-copy
dotnet-nuget-content unpack --package ./feed/sample.data.1.0.0.nupkg --destination ./working-copy --sha256 <expected-package-sha256>
dotnet-nuget-content hash --path ./feed/sample.data.1.0.0.nupkg
dotnet-nuget-content hash --path ./content/file.bin --expect <expected-file-sha256>
```

Package IDs and exact NuGet versions are required. Packing an existing package path or extracting to an existing destination fails without replacing it. Unpack validates archive paths and duplicate entries, stages extraction before creating the destination, and rejects a supplied package hash that does not match. File and package hashes use SHA-256. Successful commands return 0, malformed command input returns 2, and operation failures return 1; errors are written to stderr.

## Build and validation

```powershell
dotnet test --configuration Release
pwsh -NoProfile -File scripts/validate-consumer.ps1
dotnet publish src/DotnetNugetContent/DotnetNugetContent.csproj -c Release -r win-x64 --self-contained true -o artifacts/win-x64
```

The consumer validation creates an isolated .NET 11 project and local package source, restores a `PackageReference`, builds it, and compares nested text and binary output bytes. Native AOT publishing requires the platform prerequisites described by [.NET Native AOT deployment](https://learn.microsoft.com/dotnet/core/deploying/native-aot/).

The initial milestone does not publish to remote feeds, mutate existing package versions, execute packaged binaries, or produce a `dotnet tool` package. See [the product specification](docs/SPECS.md), [engineering contract](docs/ENGINEERING.md), and [M0001 completion evidence](docs/milestones/M0001-initialization.md).
