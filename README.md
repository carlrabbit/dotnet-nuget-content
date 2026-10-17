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
dotnet-nuget-content status [--source ./working-copy]
dotnet-nuget-content status --package ./feed/sample.data.1.0.0.nupkg
dotnet-nuget-content history [--source ./working-copy]
dotnet-nuget-content history --package ./feed/sample.data.1.0.0.nupkg
dotnet-nuget-content pack --version 1.1.0 [--source ./working-copy] [--output ./feed/sample.data.1.1.0.nupkg] [--message "Refresh dataset"]
dotnet-nuget-content hash --path ./feed/sample.data.1.0.0.nupkg
dotnet-nuget-content hash --path ./content/file.bin --expect <expected-file-sha256>
```

Initial pack requires package ID, exact NuGet version, source and output; it generates the public v1 manifest automatically. Unpack creates a managed workspace with its baseline marker under `.nuget-content/`. Managed `status`, `history` and `pack` default to the current directory root; `--source` selects an explicit root and discovery never walks ancestors. Managed pack requires a strictly higher version, rejects unchanged content, and creates a separate immutable package; `--message` is optional. If `--output` is omitted, managed pack writes the package beside the resolved workspace root. Explicit output inside the workspace is rejected to prevent self-inclusion. `status --package` verifies the manifest inventory against package payload. Package payloads are hashed and extracted as streams, including large binary files. Existing outputs and destinations are never replaced. File hashes use SHA-256. Successful commands return 0, malformed command input returns 2, and operation failures return 1; errors are written to stderr and successful results are written to stdout. See the [manifest v1 interchange contract](docs/specs/manifest-v1.md).

## Build and validation

```powershell
dotnet test --configuration Release
pwsh -NoProfile -File scripts/validate-native.ps1
```

The native validation script publishes a fresh `win-x64` executable, checks process output streams and exit codes, exercises pack/unpack/status/repack/history across exact versions, and invokes `scripts/validate-consumer.ps1` with the repacked package. The consumer check creates an isolated .NET 11 project and local package source, restores a `PackageReference`, builds it, and compares every manifested payload file while checking that metadata does not leak. Native AOT publishing requires the platform prerequisites described by [.NET Native AOT deployment](https://learn.microsoft.com/dotnet/core/deploying/native-aot/).

The tool does not publish to remote feeds, mutate existing package versions, execute packaged binaries, or produce a `dotnet tool` package. See [the product specification](docs/SPECS.md), [engineering contract](docs/ENGINEERING.md), the [manifest schema](docs/specs/manifest-v1.schema.json), and [M0001 completion evidence](docs/milestones/M0001-initialization.md).
