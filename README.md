# dotnet-nuget-content

Create **immutable NuGet packages containing arbitrary files**—datasets, test fixtures and external tools. Each version is a complete snapshot, with SHA-256 file inventory and descriptive change history. Generated packages work with ordinary .NET `PackageReference` consumers.

**Windows x64 only.** Distributed exclusively as a NuGet .NET tool. The Native AOT executable needs no installed managed runtime; installation requires the .NET CLI/SDK.

## Install

After publication to NuGet.org:

```powershell
dotnet tool install --global dotnet-nuget-content --version 1.0.0
dotnet-nuget-content --version
```

For local use in a repository:

```powershell
dotnet new tool-manifest
dotnet tool install dotnet-nuget-content --version 1.0.0
dotnet tool run dotnet-nuget-content -- --version
```

## Quick start

Create the first immutable package from a folder with files:

```powershell
dotnet-nuget-content pack --id example.assets --version 1.0.0 --source ./assets --output ./example.assets.1.0.0.nupkg
dotnet-nuget-content unpack --package ./example.assets.1.0.0.nupkg --destination ./working-copy
dotnet-nuget-content status --source ./working-copy
```

Change some files in `working-copy`. Then inspect and create the next version:

```powershell
dotnet-nuget-content status --source ./working-copy --json
dotnet-nuget-content pack --source ./working-copy --version 1.1.0 --message "Refresh assets"
dotnet-nuget-content history --package ./example.assets.1.1.0.nupkg
```

Managed pack defaults its output to the **parent of the workspace**. It never updates the workspace baseline. To work on the new version, unpack it into a new directory.

To consume the generated content package from a .NET project, make the `.nupkg` available through a NuGet source and add:

```xml
<ItemGroup>
  <PackageReference Include="example.assets" Version="1.1.0" />
</ItemGroup>
```

Content files preserve relative paths and are copied to output. The `.nuget-content` manifest is not copied into the consumer output.

## Command reference

| Command | Purpose |
|---|---|
| `pack --id ID --version VERSION --source DIR --output FILE` | Initial snapshot |
| `unpack --package FILE --destination DIR` | New managed workspace |
| `status [--source DIR] [--json]` | Compare working files with baseline |
| `status --package FILE [--json]` | Verify content package integrity |
| `history [--source DIR] [--json]` | Show workspace baseline history |
| `history --package FILE [--json]` | Show packaged history |
| `pack --version VERSION [--source DIR] [--output FILE] [--message TEXT]` | Create next immutable snapshot |
| `hash --path FILE [--expect SHA256]` | Hash/check a file |

Run `dotnet-nuget-content --help` for full syntax. Managed commands use the exact current directory when `--source` is omitted; they do not search parent directories. Existing packages and extraction destinations are never overwritten. JSON output is available for `status` and `history`; consult [the JSON contract](docs/specs/M0003-cli-json.md).

Exit codes: 0 success; 1 operation/integrity failure; 2 usage error. Errors go to stderr.

## Limitations

This tool handles **trusted** content packages, not hostile archives. It does not publish feeds, download content packages, execute packaged binaries, automatically choose versions, or support non-Windows systems. Package history is descriptive; later versions do not retain prior file bytes. Read the [manifest contract](docs/specs/manifest-v1.md).

## Development

On an authorized Windows x64 host with .NET 11 SDK and Native AOT prerequisites:

```powershell
dotnet test -c Release
pwsh -NoProfile -File scripts/validate-tool.ps1
```

See [product specification](docs/SPECS.md), [engineering contract](docs/ENGINEERING.md), and [milestones](docs/MILESTONES.md).
