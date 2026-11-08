# M0009 — Disposable unpack/edit/pack lifecycle

## Goal

Provide a simple 80/20 NuGet content workflow: unpack a managed package to a temporary editable directory, edit data, create the next complete immutable package, update package metadata and (when project-integrated) the selected package pin, then delete the temporary extracted directory. Never clone the entire extraction merely to advance a version.

## Normative behavior

- Initial `pack --id ... --source DIR` packages an arbitrary user directory and **never deletes it**.
- Ordinary managed `pack --source DIR --patch|--minor|--major|--version` requires an extracted directory with its valid `.nuget-content/manifest.json`. Validate the edited content, write the updated manifest/history **inside the newly created immutable package**, verify package payload against the manifest and current extraction, then recursively remove the extracted directory. `--output` must be outside the directory, no clobber.
- `workspace pack --alias NAME` remains optional staging-only behavior: create package, preserve both registered pin and extracted member directory. It neither creates nor deletes other directories.
- `workspace advance --alias NAME` packages and verifies the selected member extraction, updates only that member's `version` and `packageFile` in `nuget-content.json`, keeps its registered `directory` path, and removes the edited extraction. The next `workspace unpack --alias NAME` recreates the directory from the latest pinned package. No new version-suffixed directory. The historical `--directory` argument may only repeat the registered path.
- No consumer references, other member pins, original package files or arbitrary user source trees are automatically changed or deleted.
- If package construction fails, the extraction remains. If cleanup fails after publication, return nonzero, keep the completed package, report residual directory and manual inspection guidance. If project pin was already updated, report that truthfully. Recursive deletion is not crash-atomic; no journal, rollback engine, cross-artifact transaction, extra managed work copy or restore service is required.
- Do not delete a directory if the published package's bytes fail verification, the source differs from the package immediately before cleanup, or a reparse point is detected. Avoid invoking from an open working-directory handle on Windows.
- Existing public manifest v1 and workspace JSON v1 schemas and Windows x64 Native AOT distribution remain unchanged.

## Validation

Require real package tests for unpack/edit/pack/delete, re-unpack and next version, no-op and existing-output preservation, failure between package publication and cleanup, file mutation during package build, registered multi-member pin-only changes, absence of second extraction, and independent package unchanged. Run focused xUnit tests, full Release xUnit, installed Windows x64 Native AOT and independent PackageReference consumer. Final release-qualified 2.0.0 packages must be rebuilt and validated on the eventual merged source commit. No NuGet.org publication in this milestone.
