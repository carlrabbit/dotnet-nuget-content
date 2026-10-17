# Product specification

## Purpose

Manage arbitrary, long-lived content—especially test data and external binary tools—through immutable NuGet packages. Ordinary NuGet `PackageReference` consumers receive only their files; editing/inspection is supported by the native CLI.

## Package and trust invariants

- Every newly created package is a complete, immutable versioned snapshot. Never silently overwrite any output; changed content requires a strictly increasing package version when repacking.
- Payload resides at `contentFiles/any/any/<relative-path>` with `buildAction=None`, `copyToOutput=true`, `flatten=false`. Relative paths and binary bytes are preserved exactly.
- Packages are trusted inputs from known/controlled sources. Continue to reject unsafe/traversing archive paths, duplicate/conflicting entries, malformed metadata, accidental overwrite and partial writes. General hostile archive resource defenses are not in scope.
- **All packages created by this product include the public v1 manifest at package ZIP-root `.nuget-content/manifest.json`, outside `contentFiles`.** Its format and invariants are defined by `docs/specs/manifest-v1.md` and `.schema.json`. The manifest is an interchange contract, not just internal metadata.
- Creation from an arbitrary untracked source directory needs no user-authored manifest; the CLI generates it. No released/legacy format exists: input packages without a valid supported manifest are not managed M0002 package inputs.
- The CLI remains noninteractive, executable without a managed runtime using Native AOT, and uses NuGet.Packaging in process. Explicit input paths resolve relative to invocation CWD.
- M0003 distributes and installs the CLI only as a NuGet .NET tool on Windows x64 through global or local tool manifests. Its top-level pointer selects the matching `win-x64` Native AOT package; standalone executable/archive downloads and other RID fallbacks are unsupported. `status` and `history` provide the optional JSON interchange defined in `docs/specs/M0003-cli-json.md`.

## Managed workspace

- Unpacking a valid managed package creates a working directory with extracted payload and a reserved `.nuget-content/manifest.json` baseline. Package metadata never counts as user payload and is not copied to a NuGet consumer.
- `status` compares workspace bytes and paths with baseline SHA-256; classify added/modified/deleted files, and report clean state. Do not mutate baseline during inspection. `status --package <nupkg>` validates current embedded inventory against actual ZIP content without extracting a workspace.
- `status`, `history`, and managed `pack` default to **the current working directory only** if `--source` is omitted. A managed workspace is recognized solely by `.nuget-content/manifest.json` at the specified directory root; do not search ancestors or descend to find a root. Missing/invalid marker produces an actionable nonzero error.
- `history` shows the stored chronological history from a workspace by default, or `--package <nupkg>`; no external feed/history service.
- `pack` from a managed workspace obtains package ID, baseline version and history from the marker, requires `--version` strictly greater than baseline, supports optional `--message`, and computes a new complete manifest + one appended history record. Reject creating a new version if content is unchanged. Preserve workspace baseline on pack success/failure; packaging creates a separate immutable artifact.
- For interactive managed `pack`, `--output` may be omitted: produce `<id>.<new-version>.nupkg` in the **parent directory of the resolved workspace root**, regardless of whether that root came from CWD or `--source`. Explicit `--output` selects an alternative, but package output must never be included as workspace payload (including if an explicit output path lies inside the workspace). Prefer rejecting in-workspace output rather than silently excluding arbitrary files. Existing outputs always fail without overwriting. Unmanaged initial `pack` retains `--id`, `--version`, `--source`, `--output` interface and emits first manifest/history automatically.
- Change detection uses normalized relative paths and hashes; no timestamp or rename heuristics. Changes are descriptive metadata, not a delta used to reconstruct historical content.

## Out of scope for M0002

No migration/legacy compatibility, version auto-increment, remote feeds/publish/restore, merges/branches, concurrent editors, author identity/authentication, historical payload reconstruction, user-defined manifest configurations, generalized untrusted-archive handling, or public reusable library API.
