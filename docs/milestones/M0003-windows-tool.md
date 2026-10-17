# Milestone — M0003 Windows NuGet tool and product hardening

## Execution Profile

| Field | Value |
|---|---|
| Lifecycle state | done |
| Mode | ai-executed-human-reviewed |
| Baseline implementation model | project default (guide v0.9.1) |
| Baseline executor readiness | confirmed |
| Decision preservation | confirmed |
| Execution tractability | confirmed |
| Execution ledger | `.execution/M0003-windows-tool.md` (planning-seeded) |
| Scope size | medium-large |
| Implementation autonomy | high within resolved authority |
| Documentation sync | deferred; directly contradicted docs only |
| Focused/repository validation | Tier 1/2 Release tests, pack checks, evidence audit |
| Integration validation | Tier 3 real Windows file lifecycle |
| Consumer/release validation | Tier 4 installed NuGet tool and isolated PackageReference consumer |
| Validation locus/platform | authorized local Windows x64, SDK 11, native linker |
| Environment authority | `docs/specs/M0003-distribution.md`; no host provisioning or CI changes |
| Human review | recommended, nonblocking |

## Goal

Make the existing managed content lifecycle a dependable Windows-only NuGet .NET tool with structured automation output and realistic filesystem proof.

## Target State

The native CLI is installed through normal NuGet tool mechanisms and operates full content workflows; consumers obtain correct snapshot payload, and agents can parse stable JSON status/history.

## Scope

Windows x64 Native AOT NuGet tool packaging, global/local installation, update/uninstall, structured read-only JSON, realistic reliability validation, directly affected technical docs.

## Non-goals

No standalone binary/ZIP download, non-Windows RIDs, managed fallback, NuGet feed operations in product, nuget.org publication, production release automation, tool commands beyond current set, automatic version increment, public manifest evolution, full help-text review or final UI wording polish (M0004).

## Decisions and Constraints

- Distribution, environment permissions and unsupported-RID policy are authoritative in `docs/specs/M0003-distribution.md`.
- JSON output schemas and error/format policy are authoritative in `docs/specs/M0003-cli-json.md`.
- Existing `docs/specs/manifest-v1.md`, `docs/SPECS.md` and `docs/ENGINEERING.md` remain authoritative for package semantics, immutable snapshots, and trusted-input boundaries, except where M0003's scoped specialization defines the newer distribution/CLI requirements.
- Preserve Native AOT and `NuGet.Packaging`. No extra infrastructure or dependencies absent a justified technical necessity.
- Update command usage to mention new flags if necessary, but defer editorial help-text review and final 1.0 presentation to M0004.
- Do not provision host tools, modify CI workflows, or use hosted substitutes without explicit authorization. If prerequisites missing, report BLOCKED rather than bypassing gates.

## Baseline Executor Readiness

All material distribution, RID, JSON schema, validation targets, and environment permissions are decided. Implementer owns exact SDK/configuration mechanics, implementation structures, tests and work-package breakdown.

## Decision Preservation

Neither a loose executable nor a framework-dependent tool counts as NuGet Native AOT tool delivery. Real installed-tool proof is mandatory. Exclude Linux/macOS, `any` fallback, external installer and final release work.

## Execution Tractability

Individually verifiable criteria and heterogeneous proof paths are seeded with stable IDs. Implementation can decompose work into bounded work packages and resume using the ledger.

## Required Authority

- `AGENTS.md`
- `docs/SPECS.md`
- `docs/ENGINEERING.md`
- `docs/MILESTONES.md`
- `docs/specs/manifest-v1.md`
- `docs/specs/manifest-v1.schema.json`
- `docs/specs/M0003-distribution.md`
- `docs/specs/M0003-cli-json.md`

## Acceptance Criteria

- **AC-01** — Produce top-level and matching win-x64 Native AOT NuGet .NET tool packages with consistent version; no any or other RID fallback.
- **AC-02** — Fresh tool packages install and invoke via an isolated global-equivalent tool installation on Windows x64.
- **AC-03** — Local manifest installation, invocation, tool update and uninstall succeed without modifying the user’s normal tool installations.
- **AC-04** — Installed tool executes full content lifecycle and produces a managed package consumed by an isolated PackageReference project byte-for-byte, without metadata leakage.
- **AC-05** — status --json matches the public contract for clean/dirty workspace and package validation; text-mode behavior remains available.
- **AC-06** — history --json matches the public chronology/message contract for both workspace and package.
- **AC-07** — New and existing command modes preserve deterministic output, stdout/stderr and error code semantics, rejecting conflicting selectors.
- **AC-08** — Valid large binary, many files, Unicode names and deep supported Windows paths preserve exact bytes and behavior without payload-sized memory buffering.
- **AC-09** — Handled failures and output conflicts preserve existing files/baselines, do not commit partial packages or destinations, and clean staging files. Abrupt termination must not publish partial final outputs or corrupt the workspace baseline; harmless uniquely named temporary remnants are permitted after forced termination.
- **AC-10** — Installed Native AOT tool reports consistent product version and provenance; unsupported RIDs do not acquire framework-dependent fallback.
- **DOC-01** — Sync directly affected technical installation and structured-output contract documentation; defer help-text wording review and release presentation polish to M0004.
- **ART-01** — Reconcile every obligation, evidence case and validation gate using executed criterion-specific evidence and final audit.

## Acceptance Evidence Topology

| ID | Parent obligation | Required evidence case | Why separate |
|---|---|---|---|
| EC-02a | AC-02 | Installed global-equivalent native invocation | Distinct behavior, installed surface, or failure path |
| EC-03a | AC-03 | Local manifest install/invocation | Distinct behavior, installed surface, or failure path |
| EC-03b | AC-03 | Update and uninstall with isolated state | Distinct behavior, installed surface, or failure path |
| EC-04a | AC-04 | Installed tool full managed lifecycle | Distinct behavior, installed surface, or failure path |
| EC-04b | AC-04 | Independent NuGet consumer verification | Distinct behavior, installed surface, or failure path |
| EC-05a | AC-05 | Clean and dirty workspace structured result | Distinct behavior, installed surface, or failure path |
| EC-05b | AC-05 | Package success and failure structured behavior | Distinct behavior, installed surface, or failure path |
| EC-06a | AC-06 | Workspace/package history and message omission | Distinct behavior, installed surface, or failure path |
| EC-07a | AC-07 | Installed process stdout/stderr, errors and text mode | Distinct behavior, installed surface, or failure path |
| EC-08a | AC-08 | Large binary and many files | Distinct behavior, installed surface, or failure path |
| EC-08b | AC-08 | Unicode and nested Windows paths | Distinct behavior, installed surface, or failure path |
| EC-09a | AC-09 | Handled-failure cleanup and no-clobber; forced termination at a confirmed meaningful operation phase demonstrates final-path atomicity and baseline preservation | Distinct behavior, installed surface, or failure path |
| EC-10a | AC-10 | Native RID selection and consistent version | Distinct behavior, installed surface, or failure path |

## Validation

| ID | Depth | Target/check | Locus/platform | Proves | Expected evidence |
|---|---|---|---|---|---|
| VAL-01 | Tier 1/2 | dotnet test -c Release, including JSON shape/error and file integrity tests | local Windows SDK | AC-05, AC-06, AC-07, AC-09 | Criterion-specific executed result and artifact provenance |
| VAL-02 | Tier 3 | dotnet pack top-level and dotnet pack -r win-x64 Native AOT, inspect package metadata | local Windows SDK/native linker | AC-01, EC-10a | Criterion-specific executed result and artifact provenance |
| VAL-03 | Tier 4 | Install, invoke, update, uninstall top-level tool from isolated local feed via global-equivalent and local manifest modes | local Windows isolated tool state | EC-02a, EC-03a, EC-03b | Criterion-specific executed result and artifact provenance |
| VAL-04 | Tier 4 | Installed tool pack/unpack/status/repack/history and isolated dotnet restore/build consumer with independent byte oracle | local Windows installed tool/consumer | EC-04a, EC-04b | Criterion-specific executed result and artifact provenance |
| VAL-05 | Tier 4 | Installed status/history JSON, malformed cases, output streams, exit codes and text mode | local Windows installed tool | EC-05a, EC-05b, EC-06a, EC-07a | Criterion-specific executed result and artifact provenance |
| VAL-06 | Tier 3/4 | Large file/many files/deep-Unicode Windows paths, handled-error staging cleanup, and interruption at a verified meaningful stage | local Windows filesystem | EC-08a, EC-08b, EC-09a | Criterion-specific executed result and artifact provenance |
| VAL-07 | Tier 2 | Reconcile referenced project authority, milestone, ledger and artifact provenance | repository and installed artifact | DOC-01, ART-01, AC-10 | Criterion-specific executed result and artifact provenance |

## Human Review

Recommended after execution evidence closure; nonblocking.

## Documentation Policy

Only directly contradicted installation/technical/JSON docs synchronized by implementer. Review of help texts, phrasing, user-facing polish and release documentation is explicitly postponed to M0004.

## Completion Expectations

Reread milestone and ledger; establish exact ID-set equality, map work packages, execute every gate at its declared locus, attach evidence per obligation/case, perform completion audit, and record durable evidence below before declaring done. Hosted or loose executable results cannot replace installed tool proof.

## Completion Evidence

Completed on the authorized local Windows x64 host with .NET SDK `11.0.100-rc.1.26425.128` and the existing Visual Studio 18/MSVC `14.51.36231` native toolchain; no host software or CI changes were made. `dotnet test DotnetNugetContent.sln -c Release --no-restore` passed (14/14). The final `scripts/validate-tool.ps1` run produced and inspected the top-level 0.1.0 pointer and matching `win-x64` Native AOT package, installed both global-equivalent and local-manifest forms from an isolated local feed, invoked/updated/uninstalled them in temporary state, exercised the installed managed lifecycle and JSON/text contracts, and built an independent `PackageReference` consumer whose output bytes were compared with the workspace source. The installed executable was an AMD64 PE and reported 0.1.0. AC-09/EC-09a interruption evidence now observes the staged package file growing to 197,893 bytes before forced process termination; the final package path remained absent, the source SHA-256 and workspace baseline marker were unchanged, and a uniquely named `.tmp` remnant was observed as allowed by the contract. A separate successful 64 MiB pack showed no final path while staged bytes were present and published a readable complete archive. An ordinary malformed-unpack failure separately removed its staging directory and left no destination. The same run verified 301 files, a 226-character nested Unicode path, 64 MiB streaming, and conflict handling. Exact criterion/case/gate mappings, executable and package SHA-256 provenance, and per-gate evidence are recorded in `.execution/M0003-windows-tool.md`. All M0003 obligations and gates are complete; final editorial help review and release publication remain M0004 work.

## Escalation Boundary

Escalate required changes to public schemas, RID/platform, packaging mechanism, security boundary, or unauthorized provisioning. Local mechanics are implementer-owned.
