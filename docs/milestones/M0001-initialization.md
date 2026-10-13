# Milestone — M0001 Initialization and native content package vertical slice

## Execution Profile

| Field | Value |
|---|---|
| Lifecycle state | ready |
| Mode | ai-executed-human-reviewed |
| Baseline implementation model | project default (guide v0.9.1) |
| Baseline executor readiness | confirmed |
| Decision preservation | confirmed |
| Execution tractability | confirmed |
| Execution ledger | `.execution/M0001-initialization.md` (planning-seeded) |
| Scope size | medium |
| Implementation autonomy | high within authority |
| Documentation sync | deferred; directly contradicted docs updated in scope |
| Focused validation | Tier 1 CLI/filesystem tests |
| Repository validation | Tier 2 build/test/documentation reconciliation |
| Integration validation | Tier 3 package round-trip and backend proof |
| Validation locus/platform | local Windows/Linux native-AOT-capable runner; .NET 11 RC SDK |
| Consumer/release validation | Tier 4 clean NuGet consumer plus published native binary |
| Human review | recommended (not blocking acceptance once evidence is complete) |

## Goal

Initialize a CLI product that manages arbitrary binary/test content through NuGet packages, and prove its smallest useful consumer-facing content package lifecycle using a self-contained Native AOT executable.

## Target State

A fresh repository provides an implemented CLI and build/test assets that create and read immutable NuGet content packages; the actual native executable and a separate .NET PackageReference consumer verify the intended result.

## Scope

Bootstrap the .NET 11 project, CLI, package creation/extraction, SHA-256 verification, defensive filesystem behavior, real NuGet content consumption, Native AOT build, documentation, and evidence. The ZIP contains documentation/planning scaffolding only; implementation is owned by the executor.

## Non-goals

Remote publishing, feeds/authentication, external binaries execution, automatic version increment, manifests as a requirement, history/diff, branches/merges, multi-user locking, complete NuGet editor compatibility, signatures, arbitrary package transformations, all platform RIDs, and first-release `dotnet tool` installation packaging.

## Decisions and Constraints

- `net11.0` and .NET 11 RC1 SDK `11.0.100-rc.1` are the initial implementation baseline. Do not target .NET 10 merely to support .NET 10-only runtimes; Native AOT avoids the managed-runtime dependency.
- Native AOT is mandatory for the CLI even if the backend pivots. Use `NuGet.Packaging` first. Pivot packaging only on reproducible AOT compilation/runtime incompatibility disproportionate to a focused fix, not on speculative concern. Document reason and tested alternative.
- Fallback uses `dotnet pack` with `.nuspec` and requires compatible SDK at package-operation runtime. Do not claim SDK-free functionality in fallback mode.
- Package contents are full immutable snapshots. Repacking requires distinct version. Preserve exact bytes and relative paths; standard `contentFiles` layout and copy settings are part of public semantics.
- Existing destinations and published version semantics must not be silently overwritten. Reject traversal/unsafe paths and corrupted archives.
- Keep configuration optional and no remote service required. Real consumers use ordinary NuGet mechanisms; do not invent a content resolver or custom restore.
- Executable/command syntax and diagnostic defaults are implementation-local so long as observable semantics and documentation/tests conform to `docs/SPECS.md` and `docs/ENGINEERING.md`.
- No NuGet.Packaging library API is promised publicly; it is internal implementation.

## Baseline Executor Readiness

All material runtime, backend order, fallback criteria, package layout, consumer boundary and first-slice scope decisions are set. Remaining command syntax and code organization are local implementation decisions.

## Decision Preservation

The intended product is content *consumption* through NuGet, not editing packages for its own sake. Both successful native deployment and real NuGet consumer validation are mandatory, not substitutable by internal tests or a managed executable.

## Execution Tractability

Each acceptance/completion obligation has its own stable ID and seeded ledger row. Distinct binary/text/native backend evidence is enumerated below. Implementation should form its own bounded work packages, never compress the obligations or substitute one aggregate test result.

## Required Authority

- `README.md`
- `AGENTS.md`
- `docs/TERMINOLOGY.md`
- `docs/SPECS.md`
- `docs/ENGINEERING.md`
- `docs/MILESTONES.md`

## Acceptance Criteria

- **AC-01** — The repository contains coherent project authority, CLI entry documentation, and a compilable `net11.0` solution for the initial native command-line product.
- **AC-02** — The CLI exposes discoverable help/version and documented non-interactive package creation and extraction commands with stable basic exit and diagnostics behavior.
- **AC-03** — A directory containing nested text and binary files can be packaged under an explicit ID and new exact version, then extracted with paths and bytes preserved.
- **AC-04** — The produced `.nupkg` uses correct `contentFiles` metadata and is consumed by a fresh isolated .NET 11 `PackageReference` project; restore/build copies nested files into its output.
- **AC-05** — Integrity operations calculate SHA-256 for package/files and reject a supplied incorrect expected package hash without reporting false success.
- **AC-06** — Unsafe archive paths, malformed package inputs, and preexisting output conflicts are rejected without silently clobbering user files or writing outside the target.
- **AC-07** — A Release Native AOT executable is successfully published and invoked for representative pack/unpack/help behavior; executable size and AOT/trim diagnostics are recorded.
- **AC-08** — Preferred NuGet.Packaging Native AOT feasibility is decided from build and runtime evidence; only if it fails for a reproducible material reason is the approved SDK CLI backend used and its SDK dependency documented.
- **DOC-01** — User-facing README and engineering documentation describe implemented CLI syntax, distribution requirements, backend choice and actual verified behavior without claiming unimplemented features.
- **ART-01** — Implementation preserves durable, criterion-specific completion evidence and records a milestone completion audit; no criterion is marked complete on aggregate green tests alone.

## Acceptance Evidence Topology

| ID | Parent obligation | Required evidence case | Why separate evidence is required |
|---|---|---|---|
| EC-03a | AC-03 | Nested text files retain bytes and paths | Different bytes, execution path, or fallback outcome can conceal distinct failure |
| EC-03b | AC-03 | Non-text binary files retain bytes and paths | Different bytes, execution path, or fallback outcome can conceal distinct failure |
| EC-07a | AC-07 | Native published executable launches and serves help/version | Different bytes, execution path, or fallback outcome can conceal distinct failure |
| EC-07b | AC-07 | Native published executable performs package round-trip | Different bytes, execution path, or fallback outcome can conceal distinct failure |
| EC-08a | AC-08 | Preferred AOT+NuGet.Packaging path receives actual build and execution evidence | Different bytes, execution path, or fallback outcome can conceal distinct failure |
| EC-08b | AC-08 | If preferred path fails, SDK fallback is exercised and its runtime prerequisite documented | Different bytes, execution path, or fallback outcome can conceal distinct failure |

`EC-08b` is conditional on a pivot: if primary `NuGet.Packaging` succeeds, record it as `not-applicable` with the primary-path success evidence, not as a fabricated executed test.

## Validation

| ID | Depth | Target | Locus/platform | Command/check | Proves | Expected evidence |
|---|---|---|---|---|---|---|
| VAL-01 | Tier 1 | CLI parser and filesystem behavior | local on chosen development OS / .NET 11 RC SDK | `dotnet test` focused CLI/filesystem tests | AC-02, AC-05, AC-06 | Passing focused tests and representative stderr/exit transcripts |
| VAL-02 | Tier 3 | Actual content package round-trip | local / .NET 11 RC SDK | `dotnet test` integration suite / invoke built CLI | EC-03a, EC-03b | Byte/path comparisons and hashes |
| VAL-03 | Tier 4 | NuGet PackageReference consumer | local isolated source/feed / .NET 11 RC SDK | `dotnet restore` + `dotnet build` isolated consumer | AC-04 | Output-path and byte comparison from clean consumer |
| VAL-04 | Tier 4 | Published Native AOT executable | native supported build host with AOT prerequisites | `dotnet publish -c Release -r <actual-RID>` then invoke published executable | EC-07a, EC-07b | Executable provenance, outputs, size, warning report |
| VAL-05 | Tier 3 | Packaging backend feasibility | local native AOT build target | AOT publish and pack/unpack smoke checks; fallback only if preferred backend fails | EC-08a, EC-08b | Reproducible primary evidence or documented pivot trigger/fallback evidence |
| VAL-06 | Tier 2 | Repository authority and obligation closure | local | Review delivered docs, seeded ledger, and criterion-specific evidence | AC-01, DOC-01, ART-01 | Authority links and reconciled completion audit |

AOT prerequisites (platform compiler/linker and SDK) must be available for validation; if absent from one environment, run the native gate on a supported host instead of downgrading the requirement. For the fallback, verify actual SDK presence and the CLI's failure message when absent.

## Human Review

Applicability: Recommended after automated evidence closure; not a separate blocking completion obligation.

## Documentation Policy

Update directly contradicted README/project engineering/specification facts during implementation. Defer broader normalization. Do not add placeholder research or copy guide material.

## Completion Expectations

Implementation agent owns complete closure: reread milestone and ledger; verify identical obligation and evidence-case ID sets; map each to specific implementation and executed validation evidence; perform completion audit and write compact durable evidence here. No unsupported claims from tests that did not exercise the stated target.

## Completion Evidence

Implementation-owned: populate only after successful final reconciliation. Trace each `AC-*`, `DOC-*`, `ART-*`, and material `EC-*` to concrete evidence, validation gate/target and result.

## Escalation Boundary

When unforeseen evidence requires changing product semantics, Native AOT requirement, consumer behavior, or fallback precedence, return that material decision to planning. The authorized pivot to the SDK CLI is already resolved and needs no new approval when its specified failure condition is met.
