# dotnet-nuget-content

Create **immutable NuGet packages containing arbitrary files**—datasets, test fixtures and external tools. Each version is a complete snapshot, with SHA-256 file inventory and descriptive change history. Generated packages work with ordinary .NET `PackageReference` consumers.

**Version 2.0.0; Windows x64 only.** Distributed exclusively as a NuGet .NET tool with a matching `dotnet-nuget-content.win-x64` Native AOT package. The executable needs no installed managed runtime; installation requires the .NET CLI/SDK. Content-package versions in the examples below are separate from the tool version.

## Install

After publication to NuGet.org:

```powershell
dotnet tool install --global dotnet-nuget-content --version 2.0.0
dotnet nuget-content --version
```

For local use in a repository:

```powershell
dotnet new tool-manifest
dotnet tool install dotnet-nuget-content --version 2.0.0
dotnet nuget-content --version
```

The command is **`dotnet nuget-content`** for both global and local installations. The installed tool still has the package ID and executable name `dotnet-nuget-content`; the .NET CLI resolves its `dotnet-` prefix. When a local tool manifest is in scope, that installation is selected. [See .NET tool invocation rules](https://learn.microsoft.com/en-us/dotnet/core/tools/global-tools#invoke-a-local-tool).

## Quick start

Create a working example in a new, empty directory:

```powershell
New-Item -ItemType Directory -Force ./assets, ./feed | Out-Null
Set-Content -LiteralPath ./assets/example.txt -Value 'Example content'
dotnet nuget-content pack --id example.assets --version 1.0.0 --source ./assets --output ./feed/example.assets.1.0.0.nupkg
dotnet nuget-content unpack --package ./feed/example.assets.1.0.0.nupkg --destination ./working-copy
dotnet nuget-content status --source ./working-copy
```

`unpack` creates `./working-copy` as an **editable directory**. No extra copy is needed: edit files there, inspect the changes, and pack a new immutable version:

```powershell
Set-Content -LiteralPath ./working-copy/example.txt -Value 'Updated content'
dotnet nuget-content status --source ./working-copy --json
dotnet nuget-content pack --source ./working-copy --minor --output ./feed/example.assets.1.1.0.nupkg --message "Refresh assets"
# ./working-copy has been removed after successful package verification.
dotnet nuget-content history --package ./feed/example.assets.1.1.0.nupkg
```

Successful managed `pack` writes and verifies the immutable package, then **deletes the extracted editable directory**. No extra working-directory copy is created. Existing package files are never overwritten. Failed package creation retains the extraction. If cleanup fails, the published package remains available and any remaining extracted files must be inspected before manual cleanup. To edit a new version later, unpack that package again. Run `pack --source ./working-copy` from its parent directory on Windows; cleanup may fail if a shell or another process holds the extraction open.

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

Run `dotnet nuget-content --help` for full syntax. Managed commands use the exact current directory when `--source` is omitted; they do not search parent directories. Existing packages and extraction destinations are never overwritten. JSON output is available for `status` and `history`; consult [the JSON contract](docs/specs/M0003-cli-json.md).

## Project-integrated package workspaces

A repository can coordinate several independent content packages with a checked-in `nuget-content.json`. Start in the project root. Package files are local, pinned inputs; the tool does not restore or download them.

```powershell
dotnet nuget-content workspace init
dotnet nuget-content workspace add --alias fixtures --package ./feed/example.assets.1.1.0.nupkg
dotnet nuget-content workspace unpack --alias fixtures

# Edit the unpacked directory directly — no separate copy.
Set-Content -LiteralPath ./content/fixtures/example.txt -Value 'Another update'
dotnet nuget-content workspace status --alias fixtures --json

# Publish 1.1.1, update the selected project pin and remove its extracted directory.
dotnet nuget-content workspace advance --alias fixtures --patch
dotnet nuget-content workspace inspect --alias fixtures --json

# The directory is absent until you unpack the new pinned package for another edit.
dotnet nuget-content workspace unpack --alias fixtures
dotnet nuget-content workspace usage --all --json
```

The `content/fixtures` directory is a temporary editable extraction. `workspace advance` creates the new immutable package, updates the selected member's `version` and `packageFile` in `nuget-content.json`, and **deletes that extraction**. The member's directory path is unchanged, so `workspace unpack --alias fixtures` recreates it from the new pinned package when needed. Other member pins and directories are unaffected. No 2 GB second extraction is created during the advance. `workspace inspect` reports the directory as `missing` between pack and the next unpack. `workspace pack` is an explicitly staging-only alternative: it creates a package but does not change the pin or remove the working directory. Ordinary managed `pack` deletes its extraction but does not update project pins; use `workspace advance` for registered members. Obsolete sibling directories from earlier workflows can still be removed through preview-first `workspace cleanup`. See the [workspace contracts](docs/specs/M0005-project-workspace.md) and [M0007 lifecycle contract](docs/specs/M0007-workspace-lifecycle.md).

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

## Relative versions and consumer references

For a managed workspace, choose a stable version increment from its baseline:

```powershell
# After unpacking a managed package into ./working-copy:
dotnet nuget-content pack --source ./working-copy --patch
# The extraction is removed on success. Unpack the new package before editing again.

dotnet nuget-content workspace pack --alias fixtures --patch
```

Initial `pack --id ...` still requires an explicit version. Relative increments use the stable three-component baseline in the extracted directory. A successful ordinary managed `pack` removes that extraction; `workspace pack` only stages a package, and `workspace advance` updates the pin then removes the extraction.

To synchronize local consuming projects, preview first:

```powershell
dotnet nuget-content workspace references update --alias fixtures --json
# use --version VERSION only when exactly one registered package is valid locally
# pass --apply to make the supported XML edits
dotnet nuget-content workspace references update --alias fixtures --apply
```

The default target is the pinned version. Preview makes no changes. Apply updates supported literal direct `PackageReference` and effective central `PackageVersion` declarations, and blocks uncertain or malformed declarations. It does not restore packages or edit NuGet sources. Configure a local package source and restore/build consumers separately. The versioned result contract is documented in [M0006](docs/specs/M0006-versions-and-consumers.md) and [its JSON schema](docs/specs/M0006-reference-update.schema.json).
