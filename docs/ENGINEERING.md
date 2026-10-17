# Engineering and validation contract

## Runtime and distribution

- Target `net11.0`, .NET 11 RC SDK `11.0.100-rc.1`, native AOT standalone command on Windows x64 as initial Tier 4 target. Continue using `NuGet.Packaging` as the in-process reader/writer; the M0001 fallback policy remains only for demonstrated material Native AOT incompatibility.
- Noninteractive CLI; usage errors exit 2, operation/integrity failures exit 1, success exits 0. Diagnostics to stderr; successful outputs to stdout. Do not overwrite existing output and stage writes before committing. Paths relative to invocation CWD; no upward workspace discovery.
- M0003 distribution is exclusively a NuGet .NET tool for Windows x64, packaged as a top-level tool pointer plus matching `win-x64` Native AOT package. Do not add standalone downloads, `any`/other-RID fallbacks, managed fallback or remote-feed operations. Global and local manifest installs are supported; publication is deferred to M0004.
- M0003 `status --json` and `history --json` are optional valueless switches. Emit one compact JSON object plus newline on stdout, use camelCase keys and slash-separated ordinal paths, and retain text output by default. Reject simultaneous `--source` and `--package`; JSON failures produce no stdout and preserve usage/operation exit codes. The public schemas are in `docs/specs/M0003-cli-json.md`.
- The supported package trust boundary is trusted inputs. Preserve traversal, symlink escape where relevant, duplicate/conflict, no-clobber, malformed input and cleanup defenses; no ZIP-bomb/resource quota framework.

## Public metadata and workspace specialization

- Implement the publicly documented v1 interchange format in `docs/specs/manifest-v1.md` and `docs/specs/manifest-v1.schema.json`. The JSON Schema is part of the public contract; semantic validations not expressible in schema are normative in the Markdown companion.
- Package `.nuget-content/manifest.json` is ZIP-root metadata and must never enter `contentFiles` or the consuming project's output. Extract only content into a workspace, copying manifest to its reserved root marker. Reject source payload collision with `.nuget-content`.
- Hash actual file bytes using SHA-256. Use a case-independent collision policy for content paths so packages aren't ambiguous across Windows/Linux. Stable ordering is ordinal relative path order; semantic version comparisons must use NuGet version rules, not string comparisons.
- `status` and `history` are read-only. A new version is a new immutable output and leaves workspace baseline untouched; on any validation/pack failure leave no partial nupkg or destructive workspace changes.
- Do not add legacy/migration branches: no release yet exists. Do not introduce a manifest authoring prerequisite for initial arbitrary-directory pack.

## Valid package processing and bounded memory

- Content packages may contain large, valid binary files. Package inspection, hash validation, and extraction must stream payload bytes and use memory bounded independently of individual payload length; do not buffer an entire payload or require a single byte array for it. This is an efficiency/correctness requirement, not an untrusted-archive security policy. Do not add hostile-archive quotas.
- Generated output must not contaminate a managed workspace inventory. The default managed output is placed in the parent of the resolved workspace root; reject explicit output inside that workspace rather than letting it become payload. Keep staging, conflict checks, and baseline immutability.
- Validate all requirements of the published JSON Schema, including required properties, nullability, and nested types, as well as companion semantic rules. A full schema-validator dependency is optional; externally observable validation must agree with the public interchange contract. Validate historical initial-entry structure and path-list invariants for multi-entry histories too.

## Atomic publication and interruption semantics

- For pack and unpack, final published package/destination paths are commit boundaries: never expose partially written output at the final path and never overwrite existing user files. An interrupted operation must not corrupt source content or the managed workspace baseline.
- On ordinary handled failures, clean staged artifacts. An abrupt external termination (for example, process kill) bypasses in-process cleanup and **may leave uniquely named temporary files**. Such remnants must not be mistaken for valid final artifacts, overwrite existing data, or be included in managed workspace payload. No crash-recovery service, journaling, or guarantee of cleanup after a forced kill is required.
- Interruption validation must establish a meaningful operation phase (preferably after staging begins), not infer it from an arbitrary short delay. Test final-path atomicity and baseline preservation after forced termination separately from cleanup after ordinary errors. If deterministic stage observation cannot be achieved, do not claim that the relevant stage was exercised.

## Required validation

- Tier 1/2: compile and test format serialization/validation, invalid/missing metadata, workspace root resolution, default/explicit source, clean/changed status, version progression, no-change refusal, message omission/presence, no-clobber and cleanup, schema-invalid missing/null/wrong-typed nested properties, and multi-entry history invariants. Include a representative large valid binary file and evidence of bounded-memory processing.
- Tier 3: actual initial pack -> unpack -> modify/add/delete -> status -> repack -> history through current CLI using text and binary fixtures, multiple successive versions, default/explicit output outside the workspace and no self-inclusion, exact SHA/path and history assertions; package-level `status` validates embedded inventory; verify failures do not corrupt marker or outputs.
- Tier 4: extend `pwsh -NoProfile -File scripts/validate-native.ps1` (or equivalent repository-owned repeatable native validation) to prove the current published executable performs the M0002 workflow, and use a fresh isolated .NET 11 `PackageReference` consumer to verify only content files are copied, exact bytes/paths preserved, metadata excluded, with final consumer bytes compared to independently prepared workspace source bytes rather than only data read back from the package. Use actual current build and record native binary provenance/trim diagnostics; no managed DLL substitution.
- Completion evidence maps each AC/EC individually to the executed target, not a global passed-suite claim.

The manifest serializer uses source-generated `System.Text.Json` metadata for Native AOT. Package status validates the v1 manifest structure, history sequence and embedded payload inventory. Managed workspace discovery checks only the explicit source root or invocation current directory; the baseline marker remains unchanged during status and repack.

## Distribution boundary

No `.NET tool` installation packaging, no public library API, no feeds/authentication and no production multi-RID guarantee in M0002.
