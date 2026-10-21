# M0005 execution ledger

Primary milestone: `docs/milestones/M0005-project-workspaces.md`

## Obligation coverage

| ID | Obligation | Status | Work packages | Implementation evidence | Validation evidence |
|---|---|---|---|---|---|
| AC-01 | Versioned validated root marker, pinned members, deterministic aliases/paths, rejected mutations preserve files. | complete | WP-01 | `ProjectWorkspaceManifest`, strict JSON validation, root-relative normalization, case-insensitive alias/path overlap checks, staged root-marker writes. | VAL-01; EC-01a/01b assertions in `ProjectWorkspaceTests`. |
| AC-02 | Explicit workspace routing preserves legacy CLI/JSON behavior. | complete | WP-01, WP-04 | `Cli.RunAsync` routes only the `workspace` first token; legacy command switch and M0003 DTO/schema are unchanged. | VAL-01/04; legacy package-status JSON regression and installed help/lifecycle in validation transcript. |
| AC-03 | Init/add/list establish and enumerate independent local pins with meaningful errors. | complete | WP-01, WP-02 | `workspace init/add/list`; add validates a real managed package before atomic registration; list is read-only and reports directory presence. | VAL-02/04; two distinct package IDs and missing package case. |
| AC-04 | Unpack one/all safely materializes members, no overwrite, truthful partial outcomes. | complete | WP-02 | Workspace unpack delegates to managed package validation/extraction and commits each member independently. | VAL-02/04; installed byte checks; unit fixture verifies the successful first member and failed pre-existing second member. |
| AC-05 | Status reports missing/clean/modified/corrupt/mismatched deterministically. | complete | WP-02 | Versioned per-member status JSON and text states; baseline identity checked against the member pin. | VAL-01/02/04; each state exercised in unit/integration tests; clean and modified states exercised by installed tool. |
| AC-06 | Pack targets one member, rejects baseline identity mismatch before output, and preserves baseline/pin. | complete | WP-02 | `workspace pack` compares baseline package ID and version with the selected pin before output selection/publication; existing pack flow preserves immutable output and baseline. | VAL-01/02/04; unit checks ID and version mismatches create no output; installed version mismatch also creates no output; ordinary pack preserves marker and baseline bytes. |
| AC-07 | Explicit set verifies same-ID higher package, atomically selects a compatible work copy and preserves old content. | complete | WP-02 | `workspace set --directory` can select an absent destination when the existing baseline differs. It atomically advances the package pin and directory pointer without creating, replacing, moving or deleting directories; later unpack materializes the new clean copy. | VAL-02/04; unit and installed flows cover pack → failed set preservation → set to unused directory → unpack/clean; old edited directory, all package bytes, occupied target and independent member remain unchanged. |
| AC-08 | On-demand direct-use, central-version and optional previous-assets evidence, without restore/network/global claims. | complete | WP-03 | Local bounded scanner reads MSBuild project XML and `Directory.Packages.props`, plus each discovered project's adjacent assets file; labels previous assets freshness unknown. | VAL-03/04; direct+central, central-only-no-use, dynamic version and previous assets fixture assertions. |
| AC-09 | Bounded scans exclude unrelated/generated trees and do not mutate project files. | complete | WP-03 | Depth 40 and 250,000-entry caps; skips VCS, generated, dependency and member trees; no project/restore commands or writes. | VAL-03; ignored `.git`, `obj` and member projects excluded; deep fixture returns a coverage diagnostic and exit 1. |
| AC-10 | Public root/output schemas, CLI help and usable README examples; Windows-only scope retained. | complete | WP-04 | Root marker and CLI JSON schemas/docs; root help extension, README and NuGet README workspace quick starts; Windows x64 statement retained. | VAL-01/04; schema shape tests; installed root help and end-to-end README commands checked by installed gate. |
| ART-01 | Criterion, case and gate results reconciled with actual evidence. | complete | WP-04 | This ledger reconciles all seeded IDs and records Windows toolchain/artifact evidence. | VAL-05; final audit below. |

## Evidence cases

| ID | Parent | Proof required | Status | Evidence |
|---|---|---|---|---|
| EC-01a | AC-01 | Duplicate aliases, casing/path collisions, overlap, traversal and absolute paths rejected. | complete | Unit checks duplicate alias, overlapping/case-colliding directories, rooted and `..` paths; strict validator rejects before writes. |
| EC-01b | AC-01 | Rejected mutations preserve marker atomically. | complete | Unit compares marker bytes after missing-package, duplicate, overlap, case, absolute and traversal failures. Writes stage to unique sibling then rename/replace. |
| EC-02a | AC-02 | Legacy CLI and JSON regression. | complete | Legacy package-status JSON shape remains `kind: package`; complete installed legacy lifecycle/JSON/text checks in validation log. |
| EC-03a | AC-03 | Two package IDs, list and independent pins. | complete | Unit and installed fixtures register `sample.workspace.fixtures` and `sample.workspace.tools` as separate aliases; list JSON returns both. |
| EC-04a | AC-04 | Unpack one/all, pre-existing directory and second-member failure. | complete | Installed `--all` checks exact text/binary bytes; unit fixture preserves pre-existing second destination while first succeeds and reports both results. |
| EC-05a | AC-05 | Clean/changed/missing/mismatched baselines. | complete | Unit tests assert clean, modified, missing, corrupt and mismatched states; installed checks clean and modified. |
| EC-06a | AC-06 | Pack one, verify unchanged pin/baseline, reject ID/version mismatch before output. | complete | Unit test mutates selected pin ID and version independently and asserts pack exit 1, no explicit output, and unchanged baseline/payload. Installed test repeats version mismatch with no output, and verifies successful pack leaves root marker unchanged. |
| EC-07a | AC-07 | Pack-to-new-directory explicit transition, clean unpack, failed transition preservation and independent second member. | complete | Unit and installed test register two package IDs, unpack/modify/pack one, reject transition to current/occupied path without changing pin, package bytes or workspace content, set to a new absent directory, unpack and assert clean state while preserving old directory and second package pin/workspace. |
| EC-08a | AC-08 | Direct + centrally versioned references, central-only declaration, no false positive. | complete | Offline fixture checks direct reference with central version; a separate centrally declared package has no `useSites`. |
| EC-08b | AC-08 | Optional assets and stale/unknown provenance. | complete | Fixture reports prior `project.assets.json` as `previousRestoreUnknownFreshness`; central-only member has no assets evidence. |
| EC-09a | AC-09 | Large-repository traversal bounds and exclusion. | complete | Unit fixture excludes `.git`, `obj` project files and managed-member projects; 45-level tree triggers bounded-depth diagnostic rather than an unbounded scan. |
| EC-10a | AC-10 | Schema, installed help, end-to-end README quick start. | complete | Both schemas parsed/asserted; installed tool help matches authored contract; installed workspace lifecycle matches README command sequence. |

## Work packages

| ID | Scope | Result |
|---|---|---|
| WP-01 | Strict project marker model, root selection, path safety, atomic init/add/set and namespaced CLI. | Complete; v1 package manifest and M0003 legacy JSON paths remain unchanged. |
| WP-02 | Multi-member list/unpack/status/pack/set lifecycle using existing managed package semantics. | Complete; distinct member outcomes, immutable snapshots, baseline checks and explicit pins implemented. |
| WP-03 | Bounded on-demand project/package usage scanner and JSON/text output. | Complete; no MSBuild execution, restore, network, project editing or persisted scan cache. |
| WP-04 | Schemas, help/README, Windows unit/integration/installed qualification and evidence audit. | Complete; final test and installed-tool validation results recorded below. |

## Validation gates

| Gate | Locus | Proves | Status | Executed evidence |
|---|---|---|---|---|
| VAL-01 | Windows x64 .NET 11; local | AC-01, AC-02, EC-01a/01b, EC-02a | complete | Final `dotnet test DotnetNugetContent.sln -c Release --no-restore`: 21 passed, 0 failed. Includes strict path/schema/legacy checks; `git diff --check` clean. |
| VAL-02 | Windows x64; real temporary files and generated NuGet packages | EC-03a, EC-04a, EC-05a, EC-06a, EC-07a | complete | 21/21 Release unit tests passed. Unit and installed integration create real v1 packages, register two IDs, unpack/modify/pack/advance into a new absent directory/unpack/clean, reject ID/version baseline mismatch before output, and compare pin/package/workspace bytes across failed transitions. |
| VAL-03 | Windows x64; offline project fixtures | EC-08a/08b, EC-09a | complete | No restore/network invoked. Tests inspect project XML, central versions and fixture assets, assert central-only isn't use, excluded trees and depth-limit diagnostics. |
| VAL-04 | Windows x64 authorized installed-tool host and isolated local feed | AC-02, EC-06a/EC-07a, EC-10a, AC-10 | complete | `pwsh -NoProfile -File scripts/validate-tool.ps1` passed on .NET SDK `11.0.100-rc.1.26425.128`. Installed M0005 gate verifies mismatch rejection before output, failed transition preservation, old-folder retention, new-folder unpack/clean, independent second pin, plus the legacy lifecycle. It also installs the exact local top-level + `win-x64` packages and confirms Native AOT PE, global-equivalent/local installs, updates/uninstalls, 64 MiB streaming/interruption behavior and independent `PackageReference` consumer bytes. Full transcript: `.execution/M0005-installed-validation.log`. |
| VAL-05 | Repository evidence + Windows reports | ART-01, AC-09 | complete | Schemas, docs, README examples, manifest v1 and tool package layout reviewed; all criterion/case/gate IDs reconciled. No CI, feed publication, host install, CoreCLR or non-Windows changes. |

## Completion evidence

Completed on the authorized Windows x64 host with .NET SDK `11.0.100-rc.1.26425.128`. Release suite: 21/21 passed. The final installed-tool transcript records the revised M0005 workspace gate, a successfully installed AMD64 Native AOT executable, and the existing lifecycle/consumer/interruption checks. It records executable SHA-256 `E598413D5AF2CB1F69E12019B3E955D6B88B1E9CA16A139EA817FFE27FE61F3D`, top-level package SHA-256 `610D73BC0B33CEBEEBEC708482CCCBBD8C4FC0004B61ADEB218D8E939089A1D8`, and `win-x64` package SHA-256 `265D3D17D2F98B8B0086A6287212CEFB423812F24678BBADA6BEB6ED6E3D2C0D`. The package workflow confirms installed Native AOT execution, not a managed DLL substitution. The build reported an unavailable MSBuild server and successfully used its in-process fallback. No CI changes or publication occurred.

## Final reconciliation

- [x] AC-01 through AC-10 and ART-01 each map to work and executed evidence.
- [x] EC-01a/01b, EC-02a, EC-03a, EC-04a, EC-05a, EC-06a, EC-07a, EC-08a/08b, EC-09a and EC-10a each have distinct evidence.
- [x] VAL-01 through VAL-05 completed on Windows x64 with the required local and installed targets.
- [x] Public manifest v1, M0003 JSON v1, NuGet contentFiles layout and win-x64-only Native AOT distribution retained.
- [x] No material conflict with the operative contracts was encountered.
- [x] No restore/network/feed operations, automatic pin upgrades, CI changes, non-Windows support, CoreCLR migration or publication introduced.

## Resume point

Milestone implementation and validation complete. Next action: review and merge the implementation PR; no external blocker remains.
