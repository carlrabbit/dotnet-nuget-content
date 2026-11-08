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
dotnet nuget-content status --source ./working-copy
dotnet nuget-content history --source ./working-copy
```

Without `--output`, the new immutable package is written beside the editable directory. Successful ordinary managed `pack` atomically advances that directory's `.nuget-content/manifest.json` to the exact manifest in the new package. The directory and user files stay in place, `status` becomes clean, and another edit followed by `pack --patch` advances from that new baseline. Existing package paths are never overwritten. If package creation fails, the old baseline and user files remain. If the package was published but baseline replacement fails, the command reports the partial outcome, package path, both versions, and non-destructive recovery guidance; it does not claim cross-artifact atomicity.

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
# Package changes without changing this member baseline or its root pin.
dotnet nuget-content workspace pack --alias fixtures --patch
dotnet nuget-content workspace advance --alias fixtures --patch
dotnet nuget-content workspace inspect --alias fixtures --json
dotnet nuget-content workspace usage --all --json
```

Workspace package inputs must already be under the selected project root. The tool does not restore feeds or change project references. The operations are intentionally distinct: ordinary managed `pack --source DIR --patch` advances that directory's baseline; `workspace pack --alias NAME --patch` creates a package but preserves the registered member baseline and root pin; `workspace advance --alias NAME --patch` preserves the old directory and baseline, creates a new clean work copy, then atomically moves that member's pin. No manual file copy is needed. The previous work copy and package remain. `workspace inspect --all` reports observed pin/workspace state, consumer declaration drift, and eligible older sibling candidates. Cleanup previews by default; `workspace cleanup --alias NAME --directory REL --apply` removes only that explicitly named clean obsolete sibling. Modified copies and package files are preserved. See the [workspace contract](https://github.com/carlrabbit/dotnet-nuget-content/blob/main/docs/specs/M0005-project-workspace.md) and [M0007 lifecycle contract](https://github.com/carlrabbit/dotnet-nuget-content/blob/main/docs/specs/M0007-workspace-lifecycle.md).

[Complete documentation and source](https://github.com/carlrabbit/dotnet-nuget-content)

## Relative versions and consumer references

Managed `pack` and `workspace pack` accept exactly one of `--version VERSION`, `--major`, `--minor`, or `--patch`. Relative increments require a stable three-number baseline. Initial package creation with `pack --id` continues to require `--version`. Ordinary managed `pack` advances its baseline after package publication; `workspace pack` preserves its member baseline and pin.

`workspace references update --alias NAME` previews local consuming project reference edits. It defaults to the pinned package version; an explicit `--version` must match exactly one valid registered workspace package for the same package ID. Pass `--apply` to write supported literal direct `PackageReference` and central `PackageVersion` declarations. Ambiguous, dynamic, conditional, imported or malformed declarations block updates. This command does not restore, publish or modify NuGet sources. Configure an isolated local source and restore/build separately. See the [M0006 contract](https://github.com/carlrabbit/dotnet-nuget-content/blob/main/docs/specs/M0006-versions-and-consumers.md) and [JSON schema](https://github.com/carlrabbit/dotnet-nuget-content/blob/main/docs/specs/M0006-reference-update.schema.json).
