# NuGet Content Manifest v1 — public interchange contract

## Authority and purpose

This is the initial public metadata interchange format. No prior version is released; do not implement migration, legacy acceptance, or compatibility emulation. The manifest describes the current complete content snapshot and its linear descriptive ancestry. It does not provide historical file bytes, signatures, or a package self-hash.

## Physical locations

- Package: `.nuget-content/manifest.json` at the **ZIP root**, outside `contentFiles`. It must not be selected by NuGet `contentFiles` patterns or copied into a consuming project's output.
- Workspace: `<workspace>/.nuget-content/manifest.json`, a faithful baseline descriptor copied from the unpacked package, not rewritten by `status` or on failed `pack`.
- `.nuget-content` is a reserved top-level content-directory name: source payloads containing that path are rejected. The same reserved namespace is used in package and workspace, with no additional config files in M0002.

## Data contract

A UTF-8 JSON object conforming to `docs/specs/manifest-v1.schema.json` and these semantic rules:

- `schemaVersion`: integer `1`.
- `package`: `{ "id": <NuGet package ID>, "version": <normalized exact NuGet version> }`, matching the `.nuspec` identity and version.
- `files`: complete snapshot inventory; one object per regular payload file with `path` (relative `/`-separated path rooted at `contentFiles/any/any`), `size` (uncompressed byte count), `sha256` (64 uppercase hexadecimal SHA-256 characters). Paths must be safe, unique using platform-independent ordinal-ignore-case collision detection, and ordered by ordinal path comparison. Never include metadata or Nuspec entries.
- `history`: chronological, non-empty array of version records. Each record has `version`, `previousVersion` (null on first entry, immediately preceding record's version otherwise), `changes` with `added`, `modified`, `deleted` arrays of distinct, ordinally sorted relative paths, and optional nonempty `message`. No timestamps or implicit author identity. All entries share the package ID established by the manifest and recorded history is descriptive, not proof of earlier payload bytes.
- `history[-1].version == package.version`. NuGet-version sequence strictly increases, including the current version. The initial entry has `previousVersion:null`, `added` equal to all initial file paths, and empty modified/deleted arrays. Each subsequent record's changes are calculated from previous manifest `files` versus current payload hashes and paths. The tool can validate internal syntactic/structural consistency and the latest change calculation when it has the baseline, but must not claim historical authenticity without historical packages.
- File changes are classified only by paths and SHA-256: same path with different bytes is modified; new path added; absent path deleted. Size is recorded but not used as substitute for hashing. No rename inference.
- `message` is omitted when not supplied (not `null` or an invented placeholder); whitespace-only messages are invalid.
- Every `required` property in the public JSON Schema must be present with its declared type; `null` is accepted only where explicitly permitted. Do not silently substitute deserializer defaults for missing/null fields or convert malformed nested objects/arrays into valid ones. Reject unknown `schemaVersion`, malformed schema, duplicate names, conflicting package identity, or inconsistent recorded metadata explicitly, not by unrelated runtime failures.
- Validate structural rules of the first history record (null predecessor, initial additions, empty modified/deleted lists) even when later history entries exist. When historical snapshots are unavailable, do not claim the initial file list can be proven equal to the latest snapshot after intervening changes.
- Manifest JSON field names and semantics are part of the public format. JSON object property ordering and insignificant whitespace are not contractual. Writers must produce a deterministic logical inventory and history order.

## Example

```json
{
  "schemaVersion": 1,
  "package": { "id": "sample.data", "version": "1.1.0" },
  "files": [{ "path": "data.txt", "size": 3, "sha256": "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD" }],
  "history": [
    { "version": "1.0.0", "previousVersion": null, "changes": { "added": ["data.txt"], "modified": [], "deleted": [] } },
    { "version": "1.1.0", "previousVersion": "1.0.0", "message": "Retain dataset", "changes": { "added": [], "modified": ["data.txt"], "deleted": [] } }
  ]
}
```

The example illustrates the shape, not a validated real-world ancestry: a changed version's listed final hash cannot establish what the previous bytes were.
