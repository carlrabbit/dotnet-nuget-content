# Milestone — M0002 Managed content snapshots and public manifest

## Execution Profile

| Field | Value |
|---|---|
| Lifecycle state | implementing (correction pass; prior completion evidence under review) |
| Mode | ai-executed-human-reviewed |
| Baseline implementation model | project default (guide 0.9.1) |
| Baseline executor readiness | confirmed |
| Decision preservation | confirmed |
| Execution tractability | confirmed |
| Execution ledger | `.execution/M0002-managed-content.md` |
| Scope size | medium-large |
| Implementation autonomy | high within resolved decisions |
| Documentation sync | deferred; directly contradicted documentation only |
| Focused / repository | Tier 1/2 .NET tests |
| Integration | Tier 3 real package/workspace cycle |
| Consumer/release | Tier 4 native executable + isolated NuGet consumer |
| Locus | local Windows `win-x64` native-AOT host, .NET 11 RC SDK |
| Human review | recommended, nonblocking |

## Goal

Make long-lived NuGet content packages maintainable as self-contained immutable snapshots, with publicly specified metadata, managed working-copy status, and linear descriptive change history.

## Target State

A user can create an initial package without authoring metadata, unpack it into a managed working directory, inspect changes and lineage without explicit source arguments from workspace root, and produce a new higher immutable package version with accurate embedded history; ordinary NuGet consumers see only intended content.

## Scope and non-goals

Scope: initial package manifest, public JSON Schema, metadata validation, managed unpack, status, history, versioned repack, native and consumer proof. Exclude all legacy/compatibility adapters, feed/publish, automatic versions, history file reconstruction, merge/branch, locking, author identity, untrusted archive resource guards and generic configuration.

## Decisions and constraints

- `docs/SPECS.md` fixes command-default semantics; `docs/specs/manifest-v1.md` plus `.schema.json` are public format authority; `docs/ENGINEERING.md` fixes execution/validation and trust boundaries.
- No released version exists. There is **no legacy or compatibility requirement**. All new packages include a manifest. Unmanaged initial creation still does not require the user to write one.
- No ancestor search: a managed workspace is recognized at the supplied root or CWD root only. Status/history are read-only; new package must not mutate the baseline marker.
- Chronological linear ancestry is descriptive only. A new package is a complete snapshot, not a delta or historical payload store.
- Native AOT and NuGet.Packaging continue; preserve correct contentFiles consumer semantics and no-clobber/staging. No unrelated command/product expansion.
- Managed pack without `--output` writes `<id>.<version>.nupkg` to the parent of the resolved workspace root for either implicit CWD or explicit `--source`. Explicit outputs inside that root are rejected to prevent package self-inclusion.
- Manifest runtime validation must enforce the entire documented v1 schema and semantic history invariants, including multi-entry history. Large valid files must be processed by streaming without loading whole payloads in memory. Native consumer proof must compare final payload to independent workspace-source bytes.

## Baseline Executor Readiness and Decision Preservation

Public format, root resolution, history semantics, version/no-op policy, CLI required/default options and validation targets are settled in referenced project authority. The implementer chooses code structure and concrete test mechanics only; changes to any contract above return to planning.

## Execution Tractability

All applicable individually verifiable outcomes have stable IDs and preseeded ledger rows; heterogeneous behavior has evidence-case IDs. Execution can be decomposed by the implementer and resumed from the repository ledger without the planning conversation.

## Required Authority

- `AGENTS.md`
- `README.md`
- `docs/SPECS.md`
- `docs/ENGINEERING.md`
- `docs/TERMINOLOGY.md`
- `docs/MILESTONES.md`
- `docs/specs/manifest-v1.md`
- `docs/specs/manifest-v1.schema.json`

## Acceptance Criteria

- **AC-01** — An initial `pack` from an ordinary source directory produces a package with a valid, public v1 ZIP-root manifest matching nuspec identity and exact payload paths, sizes and SHA-256 hashes, and initial history.
- **AC-02** — `unpack` creates a managed working directory with correct payload bytes and a baseline marker at its root, while package/working metadata is excluded from contentFiles consumer output.
- **AC-03** — `status` in a managed workspace reports clean, added, modified and deleted state by SHA-256 and paths without changing the baseline.
- **AC-04** — Implicit CWD discovery for managed `status`, `history`, and `pack` works only at the workspace root; explicit source works; missing/invalid root marker yields an actionable failure without searching ancestors.
- **AC-05** — A managed `pack` produces a higher immutable version with complete current payload, correct updated snapshot hashes and one appended accurate linear history entry; `--message` is optional and not invented.
- **AC-06** — Managed pack rejects unchanged content, non-increasing versions, reserved metadata path collisions and existing output without modifying workspace baseline or leaving partial package outputs.
- **AC-07** — `history` displays recorded lineage from managed workspace or explicit package, in chronological order, including message when supplied.
- **AC-08** — `status --package` verifies a packaged manifest against actual embedded content and distinguishes valid from mismatched/malformed manifests with nonzero actionable failure.
- **AC-09** — The public JSON Schema and normative format document are valid, consistent and exercised by representative serialization/validation tests including rejected unknown versions and malformed history.
- **AC-10** — A freshly published Native AOT executable exercises a multi-version managed lifecycle and its new content package is consumed by an isolated NuGet PackageReference project with correct bytes/paths and no metadata leakage.
- **DOC-01** — README/help and directly affected engineering documentation accurately describe the delivered managed commands and initial interchange contract.
- **ART-01** — All M0002 obligations, evidence cases and validation gates are reconciled with actual executed criterion-specific evidence in the milestone and ledger.

## Acceptance Evidence Topology

| ID | Parent | Required case | Why separate |
|---|---|---|---|
| EC-03a | AC-03 | Clean workspace remains clean | Different behavioral path or target may mask failure |
| EC-03b | AC-03 | Added, modified and deleted files are independently distinguished | Different behavioral path or target may mask failure |
| EC-04a | AC-04 | Implicit CWD at exact root works | Different behavioral path or target may mask failure |
| EC-04b | AC-04 | Explicit source and nested/non-workspace failures work | Different behavioral path or target may mask failure |
| EC-05a | AC-05 | Optional message is present when supplied | Different behavioral path or target may mask failure |
| EC-05b | AC-05 | Message is absent when omitted, including subsequent versions | Different behavioral path or target may mask failure |
| EC-06a | AC-06 | No-op/non-increasing-version refusal preserves state | Different behavioral path or target may mask failure |
| EC-06b | AC-06 | Reserved path/output conflict refusal preserves state | Different behavioral path or target may mask failure |
| EC-10a | AC-10 | Published native process performs managed workflow | Different behavioral path or target may mask failure |
| EC-10b | AC-10 | NuGet consumer receives payload only | Different behavioral path or target may mask failure |
| EC-05c | AC-05 | Default output is outside workspace for implicit and explicit source; generated package is never payload | Default-path behavior can escape other repack assertions |
| EC-09a | AC-09 | Malformed required/null/typed/nested manifest data and multi-entry initial history are rejected | Syntax-only schema checks cannot prove runtime equivalence |
| EC-08a | AC-08 | Package validation/extraction streams a large valid binary without whole-file buffering | Small-file tests hide memory-proportional processing |
| EC-10c | AC-10 | Native consumer output matches independent final workspace bytes | Package-derived expectations can share the same defect as package content |

## Validation

| ID | Depth | Command / check | Target and locus | Proves | Expected evidence |
|---|---|---|---|---|---|
| VAL-01 | Tier 1/2 | `dotnet test --configuration Release`: schema, filesystem status, version guards, error semantics | local .NET 11 RC SDK | AC-01, AC-02, EC-03a, EC-03b, EC-04a, EC-04b, EC-05a, EC-05b, EC-06a, EC-06b, AC-07, AC-08, AC-09 | Executed per-case assertions, current artifact provenance and failure evidence |
| VAL-02 | Tier 3 | CLI pack/unpack/status/repack/history through multiple exact versions with real files | local filesystem + CLI | AC-01, AC-02, EC-03a, EC-03b, EC-05a, EC-05b, AC-07, AC-08 | Executed per-case assertions, current artifact provenance and failure evidence |
| VAL-03 | Tier 4 | Fresh `win-x64` Native AOT publish + actual native process integration (repeatable script) | local Windows with SDK 11 RC and native linker | EC-04a, EC-04b, EC-10a | Executed per-case assertions, current artifact provenance and failure evidence |
| VAL-04 | Tier 4 | Isolated .NET 11 PackageReference restore/build consuming freshly native-produced package | local isolated NuGet feed + SDK | EC-10b, AC-02 | Executed per-case assertions, current artifact provenance and failure evidence |
| VAL-05 | Tier 2 | Review authority/schema/help, seeded ledger and complete criterion-specific audit | repository, local | DOC-01, ART-01, AC-09 | Executed per-case assertions, current artifact provenance and failure evidence |
| VAL-06 | Tier 1/3 | Verify default output location, in-workspace output rejection, and large valid binary streaming through actual package operations | local .NET 11 RC SDK/filesystem | EC-05c, EC-08a | Default and explicit-root proof, clean inventory/no self-inclusion; large file bytes/hashes plus bounded-memory method evidence |
| VAL-07 | Tier 1/2 | Schema-wide positive/negative conformance cases and multi-entry initial-history checks | local .NET 11 RC SDK, public schema and runtime | EC-09a | Exact malformed cases, expected domain diagnostics, schema/runtime parity |
| VAL-08 | Tier 4 | Compare fresh native-produced package consumer files to independent final edited workspace fixture | local Windows Native AOT and isolated NuGet consumer | EC-10c | Independently sourced byte/path comparisons and no metadata leakage |

Run the published native executable from the current build, not a global install or managed DLL. If native toolchain is unavailable, report blocker rather than substituting hosted workflows or declaring completion. No tests have been executed by planning.

## Human Review

Recommended after full evidence closure; no blocking review obligation.

## Documentation Policy

Planning has authored the new authoritative contract and manifest schema. Implementation synchronizes only directly affected public README/help or genuinely contradicted project authority; do not reopen format design or broadly rewrite unrelated docs. Leave historical M0001 completion evidence intact.

## Completion Expectations

Read milestone and ledger; verify exact obligation/evidence-case ID sets; decompose into bounded work packages; execute all applicable validation; retain criterion-specific proof; perform fresh completion audit and record durable evidence below. Passing a broad test suite alone is insufficient.

## Completion Evidence

**Reopened by planning review.** The prior reported 9/9 tests and Native AOT/consumer execution are historical evidence from before these corrections, not proof of the newly required behaviors. The previous records report conflicting native executable SHA-256 values (milestone: `E219979FFE30A92553AC1D555219EF4D382FB4F1CA36420BBEE159CE7C37580B`; ledger VAL-03: `30576BDBEC8057E6A0F67585922DC87BDFAD83E89A49EA2C2C3B8EBB2CAFB0E3`). Do not claim a single validated artifact until final fresh evidence identifies the build and reconciles both records.

Implementation must replace this section with criterion/evidence-case-specific final proof only after all required gates, including VAL-06 through VAL-08, have passed. Preserve historical evidence elsewhere in the ledger with explicit stale labels; do not assert the milestone is complete in the interim.

## Escalation Boundary

Escalate only material departures from the now-resolved public manifest schema, default workspace output policy, linear history, streaming requirement, native distribution, or validation topology. The correction implementer owns code and test mechanics.
