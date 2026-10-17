# Milestone — M0004 1.0 release candidate and publication tooling

## Execution Profile

| Field | Value |
|---|---|
| Lifecycle state | ready (human license decision may block completion if missing) |
| Mode | ai-executed-human-reviewed |
| Baseline implementation model | project default; guide 0.9.1 |
| Baseline executor readiness | confirmed for technical work |
| Decision preservation | confirmed |
| Execution tractability | confirmed |
| Execution ledger | `.execution/M0004-release-candidate.md` |
| Scope | medium-large |
| Implementation autonomy | high within public and release contracts |
| Locus | authorized local Windows x64; existing .NET 11 SDK and Native AOT prerequisites |
| Provisioning / infrastructure | no software installation, host configuration or CI modifications authorized |
| Human gate | explicit approval required for actual NuGet.org publication, outside M0004 |

## Goal

Prepare a genuinely qualified 1.0.0 Windows NuGet .NET tool release candidate with polished public copy and an explicit, safe `eng/publish.ps1` operator interface. **Do not publish**.

## Target State

Two validated 1.0.0 tool packages, a repeatable installed-tool/consumer release gate, legal/repository metadata, planning-authored README/NuGet README/help, and a safe publishing script that cannot publish by default.

## Scope and non-goals

Scope: editorial integration, verified package metadata, versioning, candidate build/checksums, local installed-tool release validation, publication script dry runs, release report. No public push, GitHub Releases, binary downloads, CI workflows, Linux/macOS, new commands, SDK installation, feed-management product features or manifest changes.

## Decisions and constraints

- Final public wording is pre-authored in `README.md`, `docs/nuget/README.md`, `docs/release/HELP-TEXT.md` and `docs/release/PACKAGE-METADATA.md`; implementation integrates it verbatim except objective corrections required by live source/SDK validation.
- `docs/release/PUBLISHING.md` governs publication interface, human approval, credentials and ordering. NuGet.org is the intended later target, not a validation locus.
- Preserve M0003 win-x64 only Native AOT tool pointer/RID semantics and M0002 public manifest v1 + stable JSON output.
- Validate license and owner from repository evidence. Do not invent licenses, grant publishing rights or push publicly. Missing verified license blocks RC completion and requires explicit human decision.
- Use existing authorized Windows environment. Host software installs, machine configuration, GitHub workflows/CI substitutes are not authorized.
- Completion means **release candidate qualified**, not 1.0.0 publicly released.

## Required Authority

- `AGENTS.md`
- `docs/SPECS.md`
- `docs/ENGINEERING.md`
- `docs/MILESTONES.md`
- `docs/specs/manifest-v1.md`
- `docs/specs/M0003-distribution.md`
- `docs/specs/M0003-cli-json.md`
- `docs/release/HELP-TEXT.md`
- `docs/release/PACKAGE-METADATA.md`
- `docs/release/PUBLISHING.md`

## Acceptance Criteria

- **AC-01** — Planning-authored GitHub README provides accurate, executable Windows-only install, pack/unpack/edit/repack and PackageReference quick start.
- **AC-02** — Installed tool root help uses planning-authored final CLI wording while maintaining existing commands and exit behavior.
- **AC-03** — Top-level NuGet package includes authored readme, description, tags, verified author/license, repository/project URL and release notes; RID package metadata is inspected.
- **AC-04** — Both 1.0.0 NuGet tool packages, installed Native AOT executable version and candidate report match; only win-x64 payload is supported.
- **AC-05** — eng/publish.ps1 prepares a qualified release candidate without publishing by default and records immutable source/artifact provenance.
- **AC-06** — Explicit publishing mode enforces NuGet.org confirmation, RID-first then top-level order, hash/identity verification, safe credential handling and failure-stop semantics without actually pushing.
- **AC-07** — Exact candidate packages install via global-equivalent and local-manifest tool mechanisms; installed command passes lifecycle, JSON, update/uninstall and independent PackageReference consumer checks.
- **AC-08** — Verified legal/license and package identity exist; any unavailable human licensing decision is a release blocker, not invented by Implementer.
- **AC-09** — Operator release checklist and report allow separately approved publishing of the exact qualified bytes without rebuilding.
- **ART-01** — All milestone obligations, heterogeneous evidence cases and validation gates are reconciled to real executed evidence; completion states do not claim public publication.

## Acceptance Evidence Topology

| ID | Parent | Required case | Why separate |
|---|---|---|---|
| EC-03a | AC-03 | Public top-level package metadata and README | Distinct target or failure surface |
| EC-03b | AC-03 | RID package identity and metadata | Distinct target or failure surface |
| EC-04a | AC-04 | Two packed artifact versions and checksums | Distinct target or failure surface |
| EC-04b | AC-04 | Installed Native AOT version and RID | Distinct target or failure surface |
| EC-05a | AC-05 | Default/prepare never publishes | Distinct target or failure surface |
| EC-06a | AC-06 | RID-first publication command order | Distinct target or failure surface |
| EC-06b | AC-06 | Failed first push stops pointer and records partial state | Distinct target or failure surface |
| EC-07a | AC-07 | Global-equivalent installed tool | Distinct target or failure surface |
| EC-07b | AC-07 | Local-manifest and independent consumer | Distinct target or failure surface |
| EC-08a | AC-08 | Verified license provenance | Distinct target or failure surface |
| EC-09a | AC-09 | Qualified hashes and human publication checklist | Distinct target or failure surface |

## Validation

| ID | Depth | Check | Locus | Proves | Evidence |
|---|---|---|---|---|---|
| VAL-01 | Tier 2/3/4 as applicable | Release .NET tests and help/README contract checks | Windows x64 .NET 11 | AC-01, AC-02 | Criterion-specific executed results, artifact provenance |
| VAL-02 | Tier 2/3/4 as applicable | Pack/inspect two 1.0.0 tool packages, metadata, license and PE | Windows x64 Native AOT | EC-03a, EC-03b, EC-04a, EC-08a | Criterion-specific executed results, artifact provenance |
| VAL-03 | Tier 2/3/4 as applicable | Install exact qualified nupkg files and run installed lifecycle, updates and consumer | Windows x64 local isolated feed | EC-04b, EC-07a, EC-07b | Criterion-specific executed results, artifact provenance |
| VAL-04 | Tier 2/3/4 as applicable | Test safe eng script default, mock push order/failure and hash tampering | PowerShell mock/local; no NuGet.org | EC-05a, EC-06a, EC-06b | Criterion-specific executed results, artifact provenance |
| VAL-05 | Tier 2/3/4 as applicable | Audit version/license, release checklist and evidence ledger | repository and candidate artifacts | AC-08, EC-09a, ART-01 | Criterion-specific executed results, artifact provenance |

## Human review and execution boundary

Public publication is forbidden during M0004. Human review of prepared candidate is recommended; a **new explicit human authorization** is mandatory before any `eng/publish.ps1 -Publish` execution. This milestone does not authorize new CI, installing tools or invoking a remote publishing API.

## Completion expectations

Implementation derives bounded work packages, reconciles all seeded rows, runs every gate against the same immutable candidate files, and writes criterion-specific completion evidence here. Missing legal permission/metadata or toolchain is a blocker, never silently substituted.

## Completion Evidence

Implementation-owned after final audit. Planning has run no build or publication tests.

## Escalation Boundary

License, packaging contract deviation, new CI/host provisioning and actual publication remain human/planning decisions.
