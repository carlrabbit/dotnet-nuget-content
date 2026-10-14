# Engineering and validation contract

## Runtime and distribution

- Target `net11.0`, .NET 11 RC SDK `11.0.100-rc.1`, native AOT standalone command on Windows x64 as initial Tier 4 target. Continue using `NuGet.Packaging` as the in-process reader/writer; the M0001 fallback policy remains only for demonstrated material Native AOT incompatibility.
- Noninteractive CLI; usage errors exit 2, operation/integrity failures exit 1, success exits 0. Diagnostics to stderr; successful outputs to stdout. Do not overwrite existing output and stage writes before committing. Paths relative to invocation CWD; no upward workspace discovery.
- The supported package trust boundary is trusted inputs. Preserve traversal, symlink escape where relevant, duplicate/conflict, no-clobber, malformed input and cleanup defenses; no ZIP-bomb/resource quota framework.

## Public metadata and workspace specialization

- Implement the publicly documented v1 interchange format in `docs/specs/manifest-v1.md` and `docs/specs/manifest-v1.schema.json`. The JSON Schema is part of the public contract; semantic validations not expressible in schema are normative in the Markdown companion.
- Package `.nuget-content/manifest.json` is ZIP-root metadata and must never enter `contentFiles` or the consuming project's output. Extract only content into a workspace, copying manifest to its reserved root marker. Reject source payload collision with `.nuget-content`.
- Hash actual file bytes using SHA-256. Use a case-independent collision policy for content paths so packages aren't ambiguous across Windows/Linux. Stable ordering is ordinal relative path order; semantic version comparisons must use NuGet version rules, not string comparisons.
- `status` and `history` are read-only. A new version is a new immutable output and leaves workspace baseline untouched; on any validation/pack failure leave no partial nupkg or destructive workspace changes.
- Do not add legacy/migration branches: no release yet exists. Do not introduce a manifest authoring prerequisite for initial arbitrary-directory pack.

## Required validation

- Tier 1/2: compile and test format serialization/validation, invalid/missing metadata, workspace root resolution, default/explicit source, clean/changed status, version progression, no-change refusal, message omission/presence, no-clobber and cleanup.
- Tier 3: actual initial pack -> unpack -> modify/add/delete -> status -> repack -> history through current CLI using text and binary fixtures, multiple successive versions, exact SHA/path and history assertions; package-level `status` validates embedded inventory; verify failures do not corrupt marker or outputs.
- Tier 4: extend `pwsh -NoProfile -File scripts/validate-native.ps1` (or equivalent repository-owned repeatable native validation) to prove the current published executable performs the M0002 workflow, and use a fresh isolated .NET 11 `PackageReference` consumer to verify only content files are copied, exact bytes/paths preserved, metadata excluded. Use actual current build and record native binary provenance/trim diagnostics; no managed DLL substitution.
- Completion evidence maps each AC/EC individually to the executed target, not a global passed-suite claim.

The manifest serializer uses source-generated `System.Text.Json` metadata for Native AOT. Package status validates the v1 manifest structure, history sequence and embedded payload inventory. Managed workspace discovery checks only the explicit source root or invocation current directory; the baseline marker remains unchanged during status and repack.

## Distribution boundary

No `.NET tool` installation packaging, no public library API, no feeds/authentication and no production multi-RID guarantee in M0002.
