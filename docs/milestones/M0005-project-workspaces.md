# M0005 — Project-integrated multi-package workspaces

## Execution profile

| Attribute | Value |
|---|---|
| State | done |
| Mode | ai-executed-human-reviewed |
| Guide version | 0.9.3 planning entrypoint (implementation uses only product repository authority) |
| Baseline implementation model | project default |
| Environment | existing authorized Windows 11 x64, .NET 11 Native AOT prerequisites |
| Execution ledger | `.execution/M0005-project-workspaces.md` |
| Human review | required on PR; no production publishing |

## Goal and target state

Enable a .NET repository to declare, inspect, unpack, repack and discover local use of multiple independent immutable content NuGet packages. Preserve v1 single-package tooling and packaging. This is **project-integrated workspace (variant B)**, not merely a directory of maintenance packages.

## Decisions and scope

The new contract is `docs/specs/M0005-project-workspace.md`. Implement it without introducing new policy. Explicit `workspace` namespace, `nuget-content.json` root marker and manually pinned package files are fixed. Usage scanning is on demand, read-only and local to the selected project root. Native AOT Windows x64 stays the only distributed tool. A separate portable/CoreCLR/Linux/macOS workstream is **cancelled/deferred and not part of 2.0**. Retain public manifest v1, NuGet contentFiles representation, and legacy JSON v1. Root project manifest and workspace JSON require their own versioned schemas. Cross-package operations have independent outcomes, not transactions.

## Non-goals

Package restore/download from feeds; auto project-reference editing/upgrades; auto bump of package pins after pack; automatic Git repo/root ancestor discovery; historical revision payload retrieval; cross-repo/global usage indexes; NuGet restore during discovery; network; cross-platform support; broad performance infrastructure; public NuGet publishing; project-specific migrations outside the new v1 workspace marker.

## Authority

- `AGENTS.md`, `docs/SPECS.md`, `docs/ENGINEERING.md`, `docs/MILESTONES.md`
- `docs/specs/manifest-v1.md` and `.schema.json`, `docs/specs/M0003-cli-json.md`
- `docs/specs/M0005-project-workspace.md` (new operative contract)
- Relevant current CLI and tests (mechanics owned by implementer)

## Acceptance criteria

- **AC-01** — A versioned validated project-workspace manifest records multiple pinned local NuGet content packages with deterministic alias and path safety; invalid/overlapping/escaping entries never mutate files.
- **AC-02** — Explicit project-workspace discovery and namespaced command routing preserve unchanged behavior and JSON contracts of all legacy single-package commands.
- **AC-03** — Workspace init/add/list can establish and enumerate multiple independently pinned members, with read-only listing and meaningful errors for missing/invalid package input.
- **AC-04** — Workspace unpack single/all safely materializes distinct members using existing managed baseline semantics, prevents overwrites, and reports partial results honestly.
- **AC-05** — Workspace status single/all distinguishes missing, clean, modified and corrupt/mismatched member baselines, with deterministic machine-readable output.
- **AC-06** — Workspace pack targets exactly one member, enforces immutable version, content and atomicity requirements and leaves both member baseline and workspace pin unchanged.
- **AC-07** — Explicit workspace set updates a pin only after verified same-ID higher-version package and compatible working-copy state, atomically and without deleting content.
- **AC-08** — Workspace usage reports direct project PackageReference use sites, central-version-only declarations distinctly, and optionally previous resolved assets evidence, without restore, network access or false organization-wide coverage.
- **AC-09** — Workspace operations and discovery remain bounded on realistic multi-project repositories and do not traverse unrelated/ignored trees or mutate project files.
- **AC-10** — Public root marker and workspace JSON schemas plus CLI help and README examples are complete and executable, without claiming cross-platform or feed-management support.
- **ART-01** — Every acceptance criterion, distinct evidence case, validation gate and completion result is recorded with criterion-specific executed evidence and audit reconciliation.

## Evidence cases

| ID | Parent | Required distinct proof |
|---|---|---|
| EC-01a | AC-01 | Reject duplicate aliases, casing/path collisions, overlap, traversal and absolute paths |
| EC-01b | AC-01 | Atomically preserve manifest on rejected mutations |
| EC-02a | AC-02 | Original CLI semantics and JSON regression |
| EC-03a | AC-03 | Two package IDs, list and independent pins |
| EC-04a | AC-04 | Unpack one/all, pre-existing directory and second-member failure |
| EC-05a | AC-05 | Clean/changed/missing/mismatched baselines |
| EC-06a | AC-06 | Pack one and verify unchanged pin and baseline |
| EC-07a | AC-07 | Successful explicit set and failed incompatible transition |
| EC-08a | AC-08 | Direct + centrally versioned references, no false positive |
| EC-08b | AC-08 | Optional assets and stale/unknown provenance |
| EC-09a | AC-09 | Large-repository traversal bounds and exclusion |
| EC-10a | AC-10 | Schema, installed help, end-to-end README quick start |

## Validation gates

| ID | Depth | Required check | Locus | Proves |
|---|---|---|---|---|
| VAL-01 | Unit/contract | Root marker schema/path security, command selection, version pins, stable JSON | Windows x64 .NET 11; local | AC-01, AC-02, EC-01a, EC-01b, EC-02a |
| VAL-02 | Integration | Multi-member registration, unzip, status, repack and explicit pin transition with real NuGet packages | Windows x64; real temp files | EC-03a, EC-04a, EC-05a, EC-06a, EC-07a |
| VAL-03 | Integration | Fixture MSBuild projects, central management, assets provenance and bounded scans | Windows x64; offline local fixture | EC-08a, EC-08b, EC-09a |
| VAL-04 | Installed product | Native AOT NuGet tool install; workspace docs quick start and legacy command regression | Windows x64 authorized installed-tool host | AC-02, EC-10a, AC-10 |
| VAL-05 | Audit | Full milestone/ledger ID reconciliation and evidence for each criterion; package format unchanged | Repo evidence + Windows reports | ART-01, AC-09 |

## Execution constraints

Use authorized Windows x64 host and existing .NET 11 tools. Do not install runtimes, provision containers, modify CI or publish packages. Test relevant behavior on real local files and actual installed tool; small model/unit test doubles do not substitute for final integration checks. Concrete test files and implementation decomposition are implementer-owned. Avoid rerunning full expensive gates after every edit; execute affected gates at appropriate completion stage and rerun aggregate qualification on final candidate.

## Documentation impact

Add a project-workspace README section and CLI root help; introduce stable workspace marker and JSON schema documentation. Keep single-package instructions fully supported. Update `docs/SPECS.md` and `docs/MILESTONES.md` as appropriate to reflect the new authority. No guide files copied to product repo.

## Completion Evidence

AC-01 through AC-10, evidence cases EC-01a/01b, EC-02a, EC-03a, EC-04a, EC-05a, EC-06a, EC-07a, EC-08a/08b, EC-09a and EC-10a, and gates VAL-01 through VAL-05 are complete with criterion-specific evidence in `.execution/M0005-project-workspaces.md`. The final Windows installed Native AOT tool transcript is `.execution/M0005-installed-validation.log`. No material contract conflict or scope expansion occurred.

## Escalation boundaries

Escalate if existing code cannot preserve the managed baseline and package format under these rules, if implicit restore/project editing is technically unavoidable, or if path/security behavior materially conflicts with v1 contracts. Do not independently enlarge scope.
