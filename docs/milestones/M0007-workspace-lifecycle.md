# M0007 — Coordinated workspace lifecycle

## Execution profile

| Attribute | Value |
|---|---|
| State | ready |
| Mode | ai-executed-human-reviewed |
| Guide | agentic-project-guides 0.9.3 planning authority; no external guide reading during implementation |
| Registered profiles | `base`, `cli-tool` (repository-wide; profile metadata 0.9.1) |
| Repository maturity | initialization (registered metadata; existing project has completed M0001–M0006) |
| Baseline implementation model | repository/guide default |
| Target | Windows 11 x64, .NET 11 Native AOT, installed NuGet .NET tool |
| Review | Human PR review required before merge; no release authorization |

## Goal and target state

Provide one safe explicit advance workflow, read-only workspace inspection and strictly controlled manual cleanup of obsolete clean managed copies. Product is developer-facing; the agentic guide governs implementation only.

## Operative authority

- `AGENTS.md`, `docs/SPECS.md`, `docs/ENGINEERING.md`, `docs/TERMINOLOGY.md`, `docs/MILESTONES.md`
- `docs/specs/manifest-v1.md`, `docs/specs/M0005-project-workspace.md`, `docs/specs/M0006-versions-and-consumers.md`
- **`docs/specs/M0007-workspace-lifecycle.md`** (new normative contract)
- Existing source/validation commands for implementation mechanics

## Decisions

- `workspace advance` does pack → unpack new absent directory → verify → atomically switch root marker last; content/old pin never overwritten. On pre-commit failure completed new artifacts may remain and must be reported.
- New directory defaults to sibling `<alias>-<version>`, output default beside selected working copy, both within root. No implicit reference updates.
- `workspace inspect` is read-only and reports local consumer version drift without claiming current restore.
- `workspace cleanup` requires named single sibling target and explicit `--apply`; only lower-version, same-ID, fully clean managed directories can be deleted. Never delete nupkg artifacts or modified old copies.
- New versioned JSON schema(s); all existing JSON contracts retained.

## Non-goals

No automatic cleanup, deletion of .nupkg, feed operations, implicit consumer changes, cross-platform support, test-runner migration (existing xUnit remains for now), scale qualification (reserved for 2.0.0 release milestone), 2.0 tool-version bump, CI changes, host installs or publication.

## Acceptance criteria

- **AC-01** — Coordinated advance performs validated managed pack, clean new-directory unpack and atomic pin/directory switch; old data remains intact.
- **AC-02** — Advance enforces version/baseline/identity, path containment, collision/no-clobber and preflight invariants.
- **AC-03** — Partial failure keeps old pin and existing files intact; clearly reports new unregistered artifacts and supports non-destructive recovery.
- **AC-04** — Read-only inspect provides accurate pin, workspace state, consumer version drift and provenance/diagnostics.
- **AC-05** — Inspect candidate discovery is bounded to safe immediate siblings and never mislabels unproven candidates as disposable.
- **AC-06** — Cleanup preview cannot change files; apply deletes only one explicitly named, proven-clean older same-ID sibling; never package files.
- **AC-07** — Cleanup blocks modified, unknown, reparse, active, unrelated, overlapping or unsafe targets, revalidates immediately before removal and reports partial filesystem failure without false atomicity.
- **AC-08** — New JSON contracts, help and developer documentation are versioned, deterministic and preserve all previous command/output contracts.
- **AC-09** — Installed Windows x64 Native AOT workflow demonstrates advancement, consumer inspection and cleanup safety with real packages and local .NET consumers.
- **ART-01** — Evidence ledger reconciles every criterion, case and validation gate with executed results and exact current repository state.

## Distinct evidence cases

| ID | Parent | Required evidence |
|---|---|---|
| EC-01a | AC-01 | Advance from modified managed package creates new package and clean destination; pin switches last and old copy remains. |
| EC-02a | AC-02 | Reject mismatch, no changes, unsupported increment, collisions, outside-root paths and existing directory before publication. |
| EC-03a | AC-03 | Fault after package publication/before directory completion and after unpack/before marker update preserves old pin and reports artifacts. |
| EC-04a | AC-04 | Inspect clean, modified, missing, corrupt/mismatched states; literal central/direct drift and unresolved conditions. |
| EC-05a | AC-05 | Candidate scan excludes other/unproven dirs and never crosses sibling scope or reparse points. |
| EC-06a | AC-06 | Preview is byte-identical; explicit single clean obsolete sibling is removed, package files survive. |
| EC-07a | AC-07 | Reject modified/untracked files, active/other member, wrong ID/version, path overlap and symlinks; no deletion on rejection. |
| EC-07b | AC-07 | Handled delete failure and interruption reporting never claim atomic rollback or complete cleanup. |
| EC-08a | AC-08 | New JSON schema/ordering, CLI help/docs and prior JSON regression. |
| EC-09a | AC-09 | Installed Native AOT tool advances a member; independent member and real consumer bytes remain correct; cleanup only approved old clean copy. |

## Validation gates

| Gate | Locus | Required check | Obligations and cases |
|---|---|---|
| VAL-01 | Windows x64 .NET 11 local, existing xUnit | Focused version/path/baseline/advance safety tests | AC-01, AC-02, AC-03; EC-01a, EC-02a, EC-03a |
| VAL-02 | Windows x64 temporary real .nupkg/member trees | Inspect and cleanup integration including negative and injected failures | AC-04, AC-05, AC-06, AC-07; EC-04a, EC-05a, EC-06a, EC-07a, EC-07b |
| VAL-03 | Windows x64 project fixtures | Inspect use-site/drift provenance; stable JSON/schema and backward-compatibility tests | AC-04, AC-08; EC-04a, EC-08a |
| VAL-04 | Authorized Windows x64 host with installed Native AOT .NET tool | Existing scripts/validate-tool.ps1 plus end-to-end M0007 consumer and isolation scenarios | AC-01, AC-06, AC-09; EC-01a, EC-06a, EC-09a |
| VAL-05 | Repository documentation + Windows validation receipts | Fresh ledger reconciliation, docs and diff inspection, no scope/release overreach | ART-01, AC-08, AC-09 |

## Execution and evidence rules

Use existing authorized Windows x64/.NET 11 Native AOT toolchain and existing xUnit tests. Implementer owns work-package decomposition and concrete test files. Run focused checks during development; final installed-tool gate only when its code and fixtures are stable. Validate real packages and bytes, no mocks as substitute. Preserve full gate receipts/actual exit codes. Never claim crash-atomic deletion or cross-file transactions. No external host provisioning, CI/publishing changes or additional runtime installs.

## Documentation sync

Update `docs/SPECS.md`, `docs/MILESTONES.md`, developer `README.md`, `docs/nuget/README.md`, and CLI help with new user operations and safety warnings where required. Provide versioned JSON schema(s) and normative examples. Keep old command examples working. Do not copy guide files into repository.

## Human review and closure

Human review is required on PR before merge; implementation agent prepares evidence and a review request if the repository supplies a canonical review-check flow, but never records human approval. Mark criteria complete only against actual executed evidence, including partial-failure cases. A Windows validation capability block must be recorded as blocked rather than substituted with non-Windows simulation. Publishing 2.0.0 requires separate explicit human authorization.

## Escalation

Return to planning on any material conflict with M0005/M0006 public contracts, inability to enforce clean-only deletion, or proposed change to package/manifest formats. Do not silently weaken safety or broaden cleanup.
