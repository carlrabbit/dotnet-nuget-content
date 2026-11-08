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
dotnet nuget-content status --source ./working-copy
dotnet nuget-content history --source ./working-copy
```

Successful ordinary managed `pack` writes the complete immutable package beside the editable directory, then atomically advances that directory's `.nuget-content/manifest.json` to the exact manifest in the package. The working directory and user files stay in place, so `status` is clean and you can continue editing there and run `pack --patch` again. Existing package files are never overwritten. If package creation fails, the old baseline remains. If package creation succeeds but baseline replacement fails, the command reports the package path, both versions and non-destructive recovery steps; the old baseline and published package are retained.

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

# Create a package only; the registered pin and member baseline remain unchanged.
dotnet nuget-content workspace pack --alias fixtures --patch

# Create 1.1.1, unpack a clean new working copy, and advance this alias.
dotnet nuget-content workspace advance --alias fixtures --patch
dotnet nuget-content workspace inspect --alias fixtures --json
dotnet nuget-content workspace usage --all --json
```

The unpacked `content/fixtures` folder is the editable work area: edit its files directly. `workspace advance` packages those edits, materializes a new clean directory (for this example, `content/fixtures-1.1.1`), and updates the selected alias's pin. Continue editing in the newly selected directory. Nothing must be copied manually. Add other package aliases independently as needed. The earlier working directory and package remain. A pre-commit failure keeps the old pin and reports any new package or directory so you can recover without overwriting it. `workspace inspect --all --json` shows member state, locally observed consumer version drift, and proven older sibling candidates. `workspace cleanup --alias fixtures --directory content/fixtures-old` is a preview; add `--apply` to remove that one target only when it is a clean, lower-version managed sibling. Modified work copies and package files are preserved. Usage discovery examines local project declarations and optional previous `project.assets.json` evidence without running restore. See the [workspace contracts](docs/specs/M0005-project-workspace.md) and [M0007 lifecycle/JSON contracts](docs/specs/M0007-workspace-lifecycle.md).

The three packaging operations have distinct effects: ordinary `pack --source DIR --patch` advances that directory's baseline in place; `workspace pack --alias NAME --patch` creates an immutable package but preserves the member baseline and root pin; `workspace advance --alias NAME --patch` preserves the old directory, creates a new clean copy, and atomically advances the root pin.

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
dotnet nuget-content pack --source ./working-copy --patch
# or: --minor / --major

dotnet nuget-content workspace pack --alias fixtures --patch
```

`--version VERSION` remains available, and initial `pack --id ...` still requires an explicit version. Relative increments require a stable three-number baseline. Ordinary managed `pack` advances its baseline after package publication; `workspace pack` preserves its member baseline and pin; `workspace advance` preserves the existing directory while creating a new clean copy and advancing the pin.

To synchronize local consuming projects, preview first:

```powershell
dotnet nuget-content workspace references update --alias fixtures --json
# use --version VERSION only when exactly one registered package is valid locally
# pass --apply to make the supported XML edits
dotnet nuget-content workspace references update --alias fixtures --apply
```

The default target is the pinned version. Preview makes no changes. Apply updates supported literal direct `PackageReference` and effective central `PackageVersion` declarations, and blocks uncertain or malformed declarations. It does not restore packages or edit NuGet sources. Configure a local package source and restore/build consumers separately. The versioned result contract is documented in [M0006](docs/specs/M0006-versions-and-consumers.md) and [its JSON schema](docs/specs/M0006-reference-update.schema.json).
