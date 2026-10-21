# Project-integrated content workspace (2.0 design contract)

## Role and compatibility

A project workspace is a repository-scoped coordinator for multiple independently versioned, **managed** content NuGet packages. The existing single-package working copy `.nuget-content/manifest.json`, public package manifest v1, package history, JSON v1 outputs, Windows x64 Native AOT .NET tool installation and existing commands are unchanged. No Linux/macOS, CoreCLR transition, cross-package transaction, implicit NuGet feed restore, or new package format.

## Discovery and authority

- Explicit root marker: `<project-root>/nuget-content.json` (UTF-8 JSON). It is project-owned configuration and may be checked into source control. Must be validated with a versioned schema (`schemaVersion: 1`) and actionable diagnostics.
- Workspace CLI operations require `--workspace <root>` or use *exact current working directory* if it contains this marker. Never search ancestors or descend recursively to select a workspace. Do not reinterpret legacy `status`, `pack`, `unpack`, or `history` commands based on marker presence.
- Only one root marker per operation; aliases are unique under ordinal-ignore-case comparison (portable policy, even though v2 Windows-only). Paths are relative to root, forward slash in serialized JSON, normalized; absolute/traversal/outside-root paths, overlapping member directories, `.nuget-content` reserved metadata traversal, and conflicting output paths are forbidden. Case and slash collisions are rejected deterministically.
- The root manifest records per member: `alias`, `packageId`, `version`, `packageFile` (relative local `.nupkg`), and `directory` (relative managed work-copy root). Version and package file constitute a **pinned declaration**, not a feed query or lockfile. All members must have distinct local directories and aliases; the same package ID is allowed only with different aliases and distinct paths (for multiple versions) and does not imply shared identity/history. Unknown properties in schema must be handled explicitly; no ad-hoc silent repair.
- Store all paths relative to project root; do not persist machine paths, NuGet credentials, transient scans, source timestamps, resolved dependency graphs, or generated content inventories in the root manifest.

## Lifecycle and commands

Commands are namespaced `workspace ...` and never overload the original command arguments or JSON contracts:

- `workspace init [--workspace ROOT]` creates `nuget-content.json` with empty members and refuses overwrite. It does not create a managed package or infer references.
- `workspace add --alias NAME --package FILE [--directory REL] [--workspace ROOT]` verifies a valid existing managed NuGet package and records its embedded ID/version and a root-relative package file. Default working directory is `content/NAME` (validated). No automatic unpack or feed restore. A referenced file outside root may not be registered; user must place/copy it under root explicitly.
- `workspace list [--workspace ROOT] [--json]` displays pinned package ID, version, alias, local package file, managed directory, and whether a directory is present; read-only. Stable structured JSON output has its own versioned schema and tests; do not mutate M0003 JSON v1.
- `workspace unpack --alias NAME [--workspace ROOT]` extracts only that member's pinned local `.nupkg` into its absent directory, with existing atomic publication, no-overwrite, baseline/inventory validation. `workspace unpack --all` processes entries independently; stops and reports precisely which succeeded or failed. Never delete an existing directory. No all-or-nothing promise.
- `workspace status [--alias NAME | --all] [--workspace ROOT] [--json]` reports state for existing managed directories and clearly distinguishes missing/unpacked, invalid/corrupted baseline, and clean/changed. Defaults to all (not implicit member). A member's baseline ID/version must match its declared pin; mismatch is a visible error, not silent update.
- `workspace pack --alias NAME --version VERSION [--output FILE] [--message TEXT] [--workspace ROOT]` first verifies that the selected managed directory's baseline package ID and version match that member's declared pin, before checking or producing package output. It then delegates to existing managed packing semantics, including changed content, higher version, no overwrite and baseline preservation. Default output is **beside the managed member directory** as in v1 (provided it does not fall inside any member directory or reserved project metadata); the root manifest pin is **not silently updated** on success. Show new file and recommend explicit pin update.
- `workspace set --alias NAME --package FILE [--directory REL] [--workspace ROOT]` explicitly advances the declared pin to a verified local package of the **same package ID** with version greater than current. When the current working-copy baseline differs from the incoming package, `--directory REL` is required and must name a new, absent, safe member directory. The atomic manifest update changes both the pin and the selected directory; it does not create, replace, move or delete any directory. The old working copy remains at its original path. Run `workspace unpack --alias NAME` afterward to create the new directory from the advanced pin. An already-existing selected directory is accepted only when it is a clean managed baseline matching the incoming package. If a transition fails, the previous pin, all package files and all workspace directories remain unchanged. Repack does not modify the member baseline or root pin.
- `workspace usage [--alias NAME | --all] [--workspace ROOT] [--json]` scans **under the exact project root** on demand, reports where declared package IDs are referenced. No automatic restore, writes, parent traversal or organizational/global search. No persisted usage cache.

Every command has deterministic nonzero error behavior; partial `--all` operations report per-member outcomes. Failures leave existing member workspaces and the project manifest intact. Root-manifest modifications are staged and atomically published, with handled-failure cleanup. No automatic regeneration of project files and no package publication.

## Usage discovery contract

- Scan ordinary MSBuild project declarations (`*.csproj`, other SDK project files where applicable) plus `Directory.Packages.props` for central version declarations, without executing MSBuild targets/imports. Correlate `PackageReference Include/Update` to `packageId`; distinguish direct declaration, centrally declared version, and unresolved/dynamic expressions. Do not report a central-version-only declaration as actual use.
- When `obj/project.assets.json` is present, optionally read it as *previous restore evidence* with explicit stale/unknown state and associated project path. Distinguish observed resolved package from direct declarations and never imply restore is current. Avoid `bin`, `.git`, generated content member directories, and generic recursive `obj` scanning; inspect assets only for discovered projects.
- Produce exact relative use-site paths and classification, not claims of use outside the project. Case-insensitive NuGet package IDs, paths reported without host-specific separators. Malformed project XML / assets cause per-file diagnostics, not an overall fabricated success.
- Work proportional to configured root project files, with configurable or safe traversal limits, bounded memory, and documented behavior on giant repositories. Use no remote package metadata/network calls. Unresolved conditions must be labeled rather than inferred.

## Output schema

All new workspace JSON commands use a new explicit stable `schemaVersion`, documented schema, machine-readable per-member results/errors, predictable ordering, and stdout/stderr separation. Existing M0003 JSON remains unchanged. Root marker format is public and versioned; explicit input validation and examples are required.

The root marker schema is `M0005-project-workspace.schema.json`. List, status, and usage output share the discriminated schema `M0005-workspace-cli-json.schema.json`, with field semantics in `M0005-workspace-cli-json.md`.

## Human-facing documentation

Describe root selection, safe boundaries, immutable snapshots/pins, managed member directory lifecycle, optional use-site information, and explicit unsupported features. Keep legacy single-package quick start intact; add a separate project-workspace quick start.
