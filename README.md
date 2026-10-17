# dotnet-nuget-content

`dotnet-nuget-content` creates immutable NuGet packages containing arbitrary files and extracts those packages into working directories. Consumers use ordinary NuGet `PackageReference` restore; package payloads are declared as `contentFiles` and copied to build output with their relative paths preserved.

The CLI targets `net11.0` and is distributed exclusively as a NuGet .NET tool. M0003 supports Windows x64 with Native AOT; the matching win-x64 tool package is selected by the top-level tool package. The installed executable does not require a managed runtime, while tool installation requires the .NET 11 SDK. Building the package requires the .NET 11 RC SDK and Windows native compiler toolchain. The implementation uses `NuGet.Packaging` 7.9.0 directly for package creation and reading; the SDK packaging fallback is not used.

Install the tool from a NuGet feed:

```powershell
dotnet tool install --global dotnet-nuget-content --version 0.1.0 --add-source ./feed
dotnet-nuget-content --version
```

For a repository-local installation, create or use a local tool manifest and run `dotnet tool install dotnet-nuget-content --local`. Invoke it with `dotnet tool run dotnet-nuget-content`. Update and uninstall through `dotnet tool update` and `dotnet tool uninstall` using the same installation scope. No standalone executable or archive is distributed.

## Commands

```text
dotnet-nuget-content --help
dotnet-nuget-content --version
dotnet-nuget-content pack --id sample.data --version 1.0.0 --source ./content --output ./feed/sample.data.1.0.0.nupkg
dotnet-nuget-content unpack --package ./feed/sample.data.1.0.0.nupkg --destination ./working-copy
dotnet-nuget-content unpack --package ./feed/sample.data.1.0.0.nupkg --destination ./working-copy --sha256 <expected-package-sha256>
dotnet-nuget-content status [--source ./working-copy]
dotnet-nuget-content status --package ./feed/sample.data.1.0.0.nupkg
dotnet-nuget-content status [--source ./working-copy | --package ./feed/sample.data.1.0.0.nupkg] --json
dotnet-nuget-content history [--source ./working-copy]
dotnet-nuget-content history --package ./feed/sample.data.1.0.0.nupkg
dotnet-nuget-content history [--source ./working-copy | --package ./feed/sample.data.1.0.0.nupkg] --json
dotnet-nuget-content pack --version 1.1.0 [--source ./working-copy] [--output ./feed/sample.data.1.1.0.nupkg] [--message "Refresh dataset"]
dotnet-nuget-content hash --path ./feed/sample.data.1.0.0.nupkg
dotnet-nuget-content hash --path ./content/file.bin --expect <expected-file-sha256>
```

Initial pack requires package ID, exact NuGet version, source and output; it generates the public v1 manifest automatically. Unpack creates a managed workspace with its baseline marker under `.nuget-content/`. Managed `status`, `history` and `pack` default to the current directory root; `--source` selects an explicit root and discovery never walks ancestors. Managed pack requires a strictly higher version, rejects unchanged content, and creates a separate immutable package; `--message` is optional. If `--output` is omitted, managed pack writes the package beside the resolved workspace root. Explicit output inside the workspace is rejected to prevent self-inclusion. `status --package` verifies the manifest inventory against package payload. Package payloads are hashed and extracted as streams, including large binary files. Existing outputs and destinations are never replaced. File hashes use SHA-256. `status --json` and `history --json` emit one structured UTF-8 JSON line; text output remains the default. The JSON shapes and error behavior are defined in the [M0003 CLI contract](docs/specs/M0003-cli-json.md). Successful commands return 0, malformed command input returns 2, and operation failures return 1; errors are written to stderr and successful results are written to stdout. See the [manifest v1 interchange contract](docs/specs/manifest-v1.md).

## Build and validation

```powershell
dotnet test --configuration Release
pwsh -NoProfile -File scripts/validate-native.ps1
pwsh -NoProfile -File scripts/validate-tool.ps1
```

The tool validation script creates top-level and win-x64 packages, installs them from a temporary isolated local feed into isolated tool paths and a local manifest, then checks invocation, update, uninstall, lifecycle, JSON output, and filesystem edge cases. It invokes `scripts/validate-consumer.ps1` with the package produced by the installed tool; the consumer restores from a local feed and compares every payload file with the independent workspace source. Native AOT publishing requires the platform prerequisites described by [.NET Native AOT deployment](https://learn.microsoft.com/dotnet/core/deploying/native-aot/).

The product does not publish to remote feeds, mutate existing package versions, or execute packaged content binaries. See [the product specification](docs/SPECS.md), [engineering contract](docs/ENGINEERING.md), the [manifest schema](docs/specs/manifest-v1.schema.json), and [M0003 distribution](docs/specs/M0003-distribution.md).
