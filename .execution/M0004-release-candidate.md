# Execution Ledger — M0004

Milestone: `docs/milestones/M0004-release-candidate.md`. Planner owns immutable obligation/case rows. Implementer owns work packages, validation receipts and progress.

## Milestone Obligation Registry

| ID | Type | Obligation | Work package(s) | Implementation evidence | Validation evidence | Status |
|---|---|---|---|---|---|---|
| AC-01 | acceptance | Planning-authored GitHub README provides accurate, executable Windows-only install, pack/unpack/edit/repack and PackageReference quick start. | | | | todo |
| AC-02 | acceptance | Installed tool root help uses planning-authored final CLI wording while maintaining existing commands and exit behavior. | | | | todo |
| AC-03 | acceptance | Top-level NuGet package includes authored readme, description, tags, verified author/license, repository/project URL and release notes; RID package metadata is inspected. | | | | todo |
| AC-04 | acceptance | Both 1.0.0 NuGet tool packages, installed Native AOT executable version and candidate report match; only win-x64 payload is supported. | | | | todo |
| AC-05 | acceptance | eng/publish.ps1 prepares a qualified release candidate without publishing by default and records immutable source/artifact provenance. | | | | todo |
| AC-06 | acceptance | Explicit publishing mode enforces NuGet.org confirmation, RID-first then top-level order, hash/identity verification, safe credential handling and failure-stop semantics without actually pushing. | | | | todo |
| AC-07 | acceptance | Exact candidate packages install via global-equivalent and local-manifest tool mechanisms; installed command passes lifecycle, JSON, update/uninstall and independent PackageReference consumer checks. | | | | todo |
| AC-08 | acceptance | Verified legal/license and package identity exist; any unavailable human licensing decision is a release blocker, not invented by Implementer. | | | | todo |
| AC-09 | acceptance | Operator release checklist and report allow separately approved publishing of the exact qualified bytes without rebuilding. | | | | todo |
| ART-01 | artifact | All milestone obligations, heterogeneous evidence cases and validation gates are reconciled to real executed evidence; completion states do not claim public publication. | | | | todo |

## Evidence Case Registry

| ID | Parent obligation | Required evidence case | Validation gate(s) | Evidence | Status |
|---|---|---|---|---|---|
| EC-03a | AC-03 | Public top-level package metadata and README | VAL-02 | | todo |
| EC-03b | AC-03 | RID package identity and metadata | VAL-02 | | todo |
| EC-04a | AC-04 | Two packed artifact versions and checksums | VAL-02 | | todo |
| EC-04b | AC-04 | Installed Native AOT version and RID | VAL-03 | | todo |
| EC-05a | AC-05 | Default/prepare never publishes | VAL-04 | | todo |
| EC-06a | AC-06 | RID-first publication command order | VAL-04 | | todo |
| EC-06b | AC-06 | Failed first push stops pointer and records partial state | VAL-04 | | todo |
| EC-07a | AC-07 | Global-equivalent installed tool | VAL-03 | | todo |
| EC-07b | AC-07 | Local-manifest and independent consumer | VAL-03 | | todo |
| EC-08a | AC-08 | Verified license provenance | VAL-02 | | todo |
| EC-09a | AC-09 | Qualified hashes and human publication checklist | VAL-05 | | todo |

## Work Packages

Implementation-owned: derive after inspecting the live repository.

## Validation Gates

| ID | Required validation | Target/locus | Proves | Status | Evidence |
|---|---|---|---|---|---|
| VAL-01 | Release .NET tests and help/README contract checks | Windows x64 .NET 11 | AC-01, AC-02 | todo | |
| VAL-02 | Pack/inspect two 1.0.0 tool packages, metadata, license and PE | Windows x64 Native AOT | EC-03a, EC-03b, EC-04a, EC-08a | todo | |
| VAL-03 | Install exact qualified nupkg files and run installed lifecycle, updates and consumer | Windows x64 local isolated feed | EC-04b, EC-07a, EC-07b | todo | |
| VAL-04 | Test safe eng script default, mock push order/failure and hash tampering | PowerShell mock/local; no NuGet.org | EC-05a, EC-06a, EC-06b | todo | |
| VAL-05 | Audit version/license, release checklist and evidence ledger | repository and candidate artifacts | AC-08, EC-09a, ART-01 | todo | |

## Resume Point

Last completed work package: none
Current work package: none; decomposition pending
Next action: verify current merged M0003 baseline and actual LICENSE, then reconcile all seeded IDs
Known agent-resolvable gaps: none at planning
External blockers: missing license/owner evidence or unavailable authorized toolchain

## Final Reconciliation

- [ ] Exact milestone/ledger obligation and evidence case ID sets match.
- [ ] Real Windows installed-tool checks against immutable candidate files.
- [ ] Both packages have verified legal metadata, provenance and checksums.
- [ ] Safe publishing behavior verified using mocks only, with no public pushes.
- [ ] Per-criterion evidence, release candidate report, and final milestone audit recorded.
