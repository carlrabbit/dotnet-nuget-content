# dotnet-nuget-content

**Immutable content packages for .NET projects.** Package arbitrary datasets, test assets or other files into a versioned NuGet snapshot. Unpack into a managed workspace, inspect file changes, repack at a higher version, and consume the payload through ordinary `PackageReference`.

**Version 2.0.0; Windows x64 only.** Native AOT .NET tool; .NET CLI/SDK is required for installation. The tool is distributed as the `dotnet-nuget-content` NuGet tool package plus its matching `dotnet-nuget-content.win-x64` runtime package.

## Install

```powershell
dotnet tool install --global dotnet-nuget-content --version 2.0.0
```

For a repository-local installation instead:

```powershell
dotnet new tool-manifest
dotnet tool install dotnet-nuget-content --version 2.0.0
```

Both installation scopes support the same invocation: `dotnet nuget-content --version`. The package and executable remain named `dotnet-nuget-content`; the .NET CLI recognizes the `dotnet-` prefix.

## Use

Start with an example file and a local package feed:

```powershell
New-Item -ItemType Directory -Force ./assets, ./feed | Out-Null
Set-Content -LiteralPath ./assets/example.txt -Value 'Example content'
dotnet nuget-content pack --id example.assets --version 1.0.0 --source ./assets --output ./feed/example.assets.1.0.0.nupkg
dotnet nuget-content unpack --package ./feed/example.assets.1.0.0.nupkg --destination ./working-copy
dotnet nuget-content status --source ./working-copy
```

The `./working-copy` directory created by `unpack` is already editable—**no extra copy is required**. Edit it directly, then create another immutable package:

```powershell
Set-Content -LiteralPath ./working-copy/example.txt -Value 'Updated content'
dotnet nuget-content pack --source ./working-copy --minor --output ./feed/example.assets.1.1.0.nupkg
# The editable ./working-copy is removed after successful pack.
dotnet nuget-content history --package ./feed/example.assets.1.1.0.nupkg
```

Without `--output`, the new package is written beside the extracted directory. A successful managed `pack` verifies the new package and **removes the extracted working directory**. Failed package creation leaves the directory available. If cleanup fails, the published package is retained and the remaining extraction must be inspected. Unpack the new package again for further edits; do not run pack from inside the directory on Windows when another process may hold it open.

The installed `dotnet-nuget-content` tool and the generated `example.assets` content package are **different NuGet packages**. To consume `example.assets` in a .NET project:

```powershell
dotnet new console -o ./consumer
dotnet add ./consumer package example.assets --version 1.1.0 --source ./feed
dotnet build ./consumer
```

The generated project contains a `PackageReference` to `example.assets`, and its content files are copied to build output with relative paths preserved. The `--source` option above uses the local feed without adding it to the user's persistent NuGet configuration.

Use `status --json` and `history --json` for automation. The tool supports trusted content only; there is no cross-platform release or standalone executable download.

## Project workspaces

Repositories that use several content packages can create a checked-in project marker and pin local packages independently:

```powershell
dotnet nuget-content workspace init
dotnet nuget-content workspace add --alias fixtures --package ./feed/example.assets.1.1.0.nupkg
dotnet nuget-content workspace list --json
dotnet nuget-content workspace unpack --alias fixtures
# Edit ./content/fixtures/example.txt in place.
Set-Content -LiteralPath ./content/fixtures/example.txt -Value 'Workspace update'
dotnet nuget-content workspace status --alias fixtures --json
# Create the new version, advance the pin and remove the temporary extraction.
dotnet nuget-content workspace advance --alias fixtures --patch
dotnet nuget-content workspace inspect --alias fixtures --json
# Unpack the new pinned package only when you want to edit again.
dotnet nuget-content workspace unpack --alias fixtures
dotnet nuget-content workspace usage --all --json
```

Workspace package inputs must exist under the selected project root; no feed restore is performed. `workspace advance` creates the immutable package, updates its member pin, then removes the edited extraction without creating a second working copy. The same directory path is reused when the next `workspace unpack` is requested. Other members remain unchanged. `workspace pack` remains an explicit staging-only command: it writes a package but leaves the member's pin and extraction untouched. Ordinary `pack` removes its managed extraction without updating any project marker and should not be used directly on registered member directories. `workspace inspect` reports the active directory as missing until unpacked. Cleanup of obsolete historical sibling directories remains preview-first through `workspace cleanup`. See the [workspace contract](https://github.com/carlrabbit/dotnet-nuget-content/blob/main/docs/specs/M0005-project-workspace.md) and [M0007 lifecycle contract](https://github.com/carlrabbit/dotnet-nuget-content/blob/main/docs/specs/M0007-workspace-lifecycle.md).

[Complete documentation and source](https://github.com/carlrabbit/dotnet-nuget-content)

## Relative versions and consumer references

Managed `pack` and `workspace pack` accept exactly one of `--version VERSION`, `--major`, `--minor`, or `--patch`. Relative increments require a stable three-number baseline. Initial package creation with `pack --id` continues to require `--version`. Ordinary managed `pack` removes the extracted directory after package verification; `workspace pack` preserves the member baseline and pin and does not delete; `workspace advance` updates the pin and removes the extraction.

`workspace references update --alias NAME` previews local consuming project reference edits. It defaults to the pinned package version; an explicit `--version` must match exactly one valid registered workspace package for the same package ID. Pass `--apply` to write supported literal direct `PackageReference` and central `PackageVersion` declarations. Ambiguous, dynamic, conditional, imported or malformed declarations block updates. This command does not restore, publish or modify NuGet sources. Configure an isolated local source and restore/build separately. See the [M0006 contract](https://github.com/carlrabbit/dotnet-nuget-content/blob/main/docs/specs/M0006-versions-and-consumers.md) and [JSON schema](https://github.com/carlrabbit/dotnet-nuget-content/blob/main/docs/specs/M0006-reference-update.schema.json).
