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

Create a working example in a new, empty directory:

```powershell
New-Item -ItemType Directory -Force ./assets, ./feed | Out-Null
Set-Content -LiteralPath ./assets/example.txt -Value 'Example content'
dotnet-nuget-content pack --id example.assets --version 1.0.0 --source ./assets --output ./feed/example.assets.1.0.0.nupkg
dotnet-nuget-content unpack --package ./feed/example.assets.1.0.0.nupkg --destination ./working-copy
dotnet-nuget-content status --source ./working-copy
```

Change a file in `working-copy`, then inspect and create the next version:

```powershell
Set-Content -LiteralPath ./working-copy/example.txt -Value 'Updated content'
dotnet-nuget-content status --source ./working-copy --json
dotnet-nuget-content pack --source ./working-copy --version 1.1.0 --output ./feed/example.assets.1.1.0.nupkg --message "Refresh assets"
dotnet-nuget-content history --package ./feed/example.assets.1.1.0.nupkg
```

Managed pack without `--output` defaults its output to the **parent of the workspace**. It never updates the workspace baseline. To work on the new version, unpack it into a new directory.

The generated `example.assets` package is distinct from the `dotnet-nuget-content` tool package. To consume it, create a .NET project and add the generated package using the local `feed` directory:

```powershell
dotnet new console -o ./consumer
dotnet add ./consumer package example.assets --version 1.1.0 --source ./feed
dotnet build ./consumer
```

This adds a `PackageReference` to `consumer.csproj`, equivalent to:

```xml
<ItemGroup>
  <PackageReference Include="example.assets" Version="1.1.0" />
</ItemGroup>
```

The `--source` option uses the local feed for the package-add operation without changing the user's persistent NuGet sources.

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

## Project-integrated package workspaces

A repository can coordinate several independent content packages with a checked-in `nuget-content.json`. Start in the project root. Package files are local, pinned inputs; the tool does not restore or download them.

```powershell
dotnet-nuget-content workspace init
dotnet-nuget-content workspace add --alias fixtures --package ./feed/example.assets.1.1.0.nupkg
dotnet-nuget-content workspace add --alias tools --package ./feed/example.tools.2.0.0.nupkg
dotnet-nuget-content workspace list --json
dotnet-nuget-content workspace unpack --all
dotnet-nuget-content workspace status --all --json
dotnet-nuget-content workspace usage --all --json
```

Each alias has its own managed directory under `content/` by default. Edit a member and create a new immutable package with `workspace pack --alias fixtures --version 1.2.0`; packing verifies the member baseline against its pin and leaves both unchanged. After placing the new package under the project root, advance the pin explicitly and select a fresh directory with `workspace set --alias fixtures --package ./feed/example.assets.1.2.0.nupkg --directory content/fixtures-1.2.0`, then run `workspace unpack --alias fixtures`. The old working copy stays untouched at its original path; set never creates or replaces directories. Usage discovery examines local project declarations and optional previous `project.assets.json` evidence without running restore. Its evidence is limited to the selected project tree and prior assets may be stale. See the [workspace contract](docs/specs/M0005-project-workspace.md) and [workspace JSON contract](docs/specs/M0005-workspace-cli-json.md).

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
