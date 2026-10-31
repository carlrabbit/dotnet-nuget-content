# M0007 — Coordinated workspace advancement, inspection and safe cleanup

## Purpose and compatibility
Developer-facing Windows x64 Native AOT .NET tool. Preserve M0001–M0006 CLI behavior, immutable content package/public manifest v1, root marker `nuget-content.json` v1, legacy/workspace/reference-update JSON contracts, and explicit reference-update preview/apply. Do not migrate xUnit to TUnit in this milestone. New commands are opt-in and namespaced under `workspace`.

## Coordinated advance
`workspace advance --alias NAME (--version VERSION | --major | --minor | --patch) [--directory REL] [--output FILE] [--message TEXT] [--workspace ROOT]`.

A successful advance creates exactly one new immutable content package from the selected member's managed directory, creates a new clean managed directory from that package, and atomically changes the project's pin (`version`, `packageFile`, `directory`) to the new package. It never rewrites consuming MSBuild declarations, publishes/downloads/restores, deletes old content or edits a prior baseline. The previous managed directory and old package remain intact.

Version selection follows M0006 managed-pack rules, strictly based on the selected directory baseline and its matching registered pin. Default package output uses the existing `workspace pack` location beside the existing member directory, but MUST be within the project root. The default new directory is the old member directory's parent plus `<alias>-<normalized-new-version>`; callers may specify a normalized root-relative `--directory`. The directory must be absent and disjoint from all registered directories, including the existing one; no overwrite. Explicit `--output` must be root-contained and disjoint from all registered member directories and metadata. Validate version, output paths, package identity, baseline, modified content requirement, path safety and collisions before publishing.

Commit sequencing: (1) preflight; (2) atomically publish package using existing pack; (3) safely unpack the new package into an absent directory using existing unpack atomicity; (4) validate the new copy is clean and matches the package; (5) atomically update root marker last. This deliberately provides a **manifest commit boundary**, not cross-artifact transactionality. On handled failure before marker commit, old pin/directory and all pre-existing artifacts remain unchanged; a completed new package or directory MAY remain as an unregistered artifact and must be reported precisely, never presented as successful advance. On failure after manifest commit the operation is complete; no later essential mutating step. Never automatically delete a successfully created package or directory to mask partial progress. Explicit messages identify current pin, created outputs and recovery choices. Reattempt does not overwrite leftover artifacts; user chooses new paths or explicitly handles leftovers.

## Lifecycle inspection
`workspace inspect [--alias NAME | --all] [--workspace ROOT] [--json]` is read-only. Report selected member's registered package ID, pinned version, registered package path, working directory and current status (`missing`, `clean`, `modified`, `corrupt`, `mismatched`). Include local consumer version drift only from existing bounded, on-demand local discovery, with direct and central declarations distinguished and unresolved/dynamic states explicit. No automatic project edits, no inferred current restores, no persistent scan state, no ancestor discovery. Missing or malformed project declarations produce precise diagnostics and incomplete/unknown coverage; no false clean claim. New JSON has its own versioned documented schema and stable ordering without changing existing JSON outputs.

Inspection may identify **candidate** obsolete sibling working directories only when it can safely establish they are managed copies of the same package ID and have lower baseline version than the selected pin; this is advisory, not automatic garbage collection. It must not scan recursively outside the immediate parent of the registered member directory or traverse reparse points. Unproven directories are not labeled safe for deletion.

## Explicit safe cleanup
`workspace cleanup --alias NAME --directory REL [--workspace ROOT] [--apply] [--json]`. Default is a non-mutating preview; `--apply` explicitly authorizes removal of the **single** nominated obsolete managed directory. No automatic cleanup in `advance` or `inspect`.

Cleanup may be approved only if all are true:
- target is normalized root-relative, an immediate sibling of the selected member directory, wholly within project root, not a reparse point and contains no reparse/symlink traversal anywhere in its tree;
- target is neither the active directory of any registered member nor overlaps one; target is not the root, package file, `.nuget-content` project-reserved path or marker;
- target has a fully valid managed baseline of **the same package ID** and **strictly lower version** than selected pin, and status/inventory is clean (no added, modified or deleted user files, including untracked extras);
- target state is revalidated immediately before deletion; any failed or ambiguous condition blocks the operation without deleting anything.

No package files or package history are deleted. Removal is not crash-atomic; interruption or filesystem errors may leave a partially removed obsolete directory. Report exact outcome and path, do not claim rollback, and never delete any other directory. If cleanup cannot prove safety, reject and leave the work copy to manual user management. Do not attempt to clean modified old workspaces, even those retained by `advance`.

## Common safety and outputs
Retain source permissions and root-relative path constraints, case-insensitive collisions, no-clobber, and existing trusted-package boundary. Explicit operations only. `workspace advance` returns meaningful text successes/partial failure diagnostics with existing exit codes; `inspect` and `cleanup` use separate documented versioned JSON contracts (one compact JSON object and newline, deterministic order; stderr for operation errors). No new global CLI commands or modification of existing output schemas.

## JSON output contracts

`workspace inspect --alias NAME --json` and `workspace inspect --all --json` emit one compact `workspaceInspect` schemaVersion 1 object, with members ordered by alias (ordinal-ignore-case, then ordinal). A member reports the declared pin and paths, one of `missing`, `clean`, `modified`, `corrupt`, or `mismatched`, sorted added/modified/deleted paths, local consumer declaration observations, and proven obsolete sibling candidates. Consumer records identify `direct` or `central` provenance and `pinned`, `drift`, `dynamic`, or `unresolved` state. These are observed local declarations; no restore freshness is implied. Diagnostics are ordered strings. The contract is `M0007-workspace-inspect.schema.json`.

`workspace cleanup ... --json` emits one compact `workspaceCleanup` schemaVersion 1 result. `eligible` means preview-only and `removed` means the explicitly authorized removal completed. `blocked` means safety could not be established before deletion. `partial` reports a deletion attempt that failed or was interrupted; no rollback is promised. `applied` is `false` for previews, blocked requests, and partial failures; it is `true` only after the requested deletion completes. Its contract is `M0007-workspace-cleanup.schema.json`.

```powershell
dotnet-nuget-content workspace advance --alias fixtures --patch
dotnet-nuget-content workspace inspect --all --json
dotnet-nuget-content workspace cleanup --alias fixtures --directory content/fixtures-old --json
dotnet-nuget-content workspace cleanup --alias fixtures --directory content/fixtures-old --apply
```

Advance does not update consuming project declarations. Inspect is read-only. Cleanup names exactly one directory; package archives and modified work copies remain untouched.

## Release boundary
M0007 is feature scope only. No 2.0 version bump or publication, no cross-platform, remote feeds, NuGet Config edits, consumer reference rewriting during advance, sweep/delete of package archives, automated retention policy, global usage index, broad scan performance qualification, CI change, host provisioning or framework migration. Full 2.0.0 qualification including scale belongs to the next release-readiness milestone.
