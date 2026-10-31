# dotnet-nuget-content

**Immutable content packages for .NET projects.** Package arbitrary datasets, test assets or other files into a versioned NuGet snapshot. Unpack into a managed workspace, inspect file changes, repack at a higher version, and consume the payload through ordinary `PackageReference`.

**Windows x64 only.** Native AOT .NET tool; .NET CLI/SDK is required for installation.

## Install

```powershell
dotnet tool install --global dotnet-nuget-content --version 1.0.0
```

## Use

Start with an example file and a local package feed:

```powershell
New-Item -ItemType Directory -Force ./assets, ./feed | Out-Null
Set-Content -LiteralPath ./assets/example.txt -Value 'Example content'
dotnet-nuget-content pack --id example.assets --version 1.0.0 --source ./assets --output ./feed/example.assets.1.0.0.nupkg
dotnet-nuget-content unpack --package ./feed/example.assets.1.0.0.nupkg --destination ./working-copy
dotnet-nuget-content status --source ./working-copy
```

After editing the working copy:

```powershell
Set-Content -LiteralPath ./working-copy/example.txt -Value 'Updated content'
dotnet-nuget-content pack --source ./working-copy --version 1.1.0 --output ./feed/example.assets.1.1.0.nupkg
```

The new package is written to `./feed` as requested. Without `--output`, it would appear beside the workspace. The workspace baseline is unchanged.

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
dotnet-nuget-content workspace init
dotnet-nuget-content workspace add --alias fixtures --package ./feed/example.assets.1.1.0.nupkg
dotnet-nuget-content workspace list --json
dotnet-nuget-content workspace unpack --all
dotnet-nuget-content workspace status --all --json
dotnet-nuget-content workspace usage --all --json
```

Workspace package inputs must already be under the selected project root. The tool does not restore feeds or change project references. Use `workspace advance --alias NAME --patch` to create a new immutable package and clean work copy, then atomically move that member's pin. The previous work copy and package remain. `workspace inspect --all` reports observed pin/workspace state, consumer declaration drift, and eligible older sibling candidates. Cleanup previews by default; `workspace cleanup --alias NAME --directory REL --apply` removes only that explicitly named clean obsolete sibling. Modified copies and package files are preserved. See the [workspace contract](https://github.com/carlrabbit/dotnet-nuget-content/blob/main/docs/specs/M0005-project-workspace.md) and [M0007 lifecycle contract](https://github.com/carlrabbit/dotnet-nuget-content/blob/main/docs/specs/M0007-workspace-lifecycle.md).

[Complete documentation and source](https://github.com/carlrabbit/dotnet-nuget-content)

## Relative versions and consumer references

Managed `pack` and `workspace pack` accept exactly one of `--version VERSION`, `--major`, `--minor`, or `--patch`. Relative increments require a stable three-number baseline. Initial package creation with `pack --id` continues to require `--version`; packing never changes a workspace baseline or pin.

`workspace references update --alias NAME` previews local consuming project reference edits. It defaults to the pinned package version; an explicit `--version` must match exactly one valid registered workspace package for the same package ID. Pass `--apply` to write supported literal direct `PackageReference` and central `PackageVersion` declarations. Ambiguous, dynamic, conditional, imported or malformed declarations block updates. This command does not restore, publish or modify NuGet sources. Configure an isolated local source and restore/build separately. See the [M0006 contract](https://github.com/carlrabbit/dotnet-nuget-content/blob/main/docs/specs/M0006-versions-and-consumers.md) and [JSON schema](https://github.com/carlrabbit/dotnet-nuget-content/blob/main/docs/specs/M0006-reference-update.schema.json).
