# M0008 — 2.0.0 release qualification

## Execution profile

| Attribute | Value |
|---|---|
| State | ready |
| Mode | ai-executed-human-reviewed |
| Guide | agentic-project-guides 0.9.3; implementation follows project authority only |
| Registered scopes | base + cli-tool repository-wide; profile metadata v0.9.1 |
| Maturity | repository metadata initialization; release candidate qualification is actual scope |
| Baseline model | configured project default |
| Target | authorized Windows 11 x64/.NET 11 Native AOT |
| Human review | required PR review; real publication requires later separately explicit human authorization |

## Goal

Produce a verifiable Windows x64 Native AOT NuGet tool **2.0.0** release candidate from the final merged source commit, with full functional, scale, provenance, package and dry-run publication evidence. Do not publish.

## Authority

- `AGENTS.md`, `docs/SPECS.md`, `docs/ENGINEERING.md`, `docs/MILESTONES.md`
- `docs/specs/manifest-v1.md`, M0003–M0007 feature and JSON contracts
- **`docs/specs/M0008-release-qualification.md`** (this milestone’s normative release contract)
- `docs/release/PUBLISHING.md`, `docs/release/PACKAGE-METADATA.md`, `docs/release/HELP-TEXT.md`
- `eng/publish.ps1`, `scripts/validate-tool.ps1`, `scripts/validate-native.ps1`

## Scope boundaries

- Only release-specific versioning, documentation, validator compatibility, candidate preparation and demonstrated release blockers; no new product features.
- No nuget.org push, GitHub Release, CI/host changes, cross-platform/managed fallback, new formats, new benchmark system or xUnit→TUnit migration.
- Pre-merge tests are evidence for implementation PR, **not** authoritative final candidate. Final merged-commit gate is mandatory for release-qualified claim.

## Acceptance criteria

- **AC-01** — All M0001–M0007 behavior and published v1 manifest, workspace marker and JSON contracts remain compatible; regressions are verified against the final candidate.
- **AC-02** — Tool version, both NuGet package IDs/versions, nuspec metadata, installed executable version, README and help consistently identify 2.0.0 and Windows x64-only support.
- **AC-03** — Build from a clean, identified final merged source commit produces two immutable qualified 2.0.0 NuGet tool package artifacts with SHA-256 hashes and provenance; no publication occurs.
- **AC-04** — Exact candidate artifacts pass isolated local-feed global-equivalent and local-manifest installation, invocation, update/uninstall and independent consumer byte-verification checks.
- **AC-05** — Full developer lifecycle across multiple content packages, pin advancement, reference preview/apply, inspection and safe cleanup passes installed Native AOT acceptance including negative/failure scenarios.
- **AC-06** — Repository-scale qualification of local usage scanning, reference preview/apply and inspection runs on a reproducible 100-project/10-package fixture with bounded completion, correct scope and preserved unrelated files.
- **AC-07** — Release qualification covers adversarial paths, junctions, no-clobber, staged interruption, cleanup partial deletion and safe recovery claims; no unsupported cross-file crash atomicity is asserted.
- **AC-08** — Existing human-operated publication workflow is updated to require exact qualified 2.0.0 artifact identity, RID-first dry-run ordering, hash checks and explicit nuget.org approval; no real push occurs.
- **AC-09** — Public documentation, release notes, metadata and release/operator checklist accurately describe all 2.0 workflows, Windows restrictions, limitations and separate publication authorization; milestone index reflects merged M0007.
- **AC-10** — Security/dependency advisory and artifact provenance checks run on candidate dependencies; unresolved high-risk advisories or licensing/ownership defects block release qualification rather than being waived implicitly.
- **ART-01** — Planning-seeded ledger is reconciled criterion-by-criterion with current executed receipts, final SHA-256 and Git commit, and truthful human review/publication state.

## Evidence cases

| ID | Parent | Distinct proof |
|---|---|---|
| EC-01a | AC-01 | Legacy single-package and multi-package commands, schemas and output invariants. |
| EC-02a | AC-02 | Exact two 2.0.0 package metadata, installed tool version and authored docs. |
| EC-03a | AC-03 | Candidate exact merged Git SHA, clean tree, reproducible command, package hashes and immutable receipt. |
| EC-04a | AC-04 | Global-equivalent and local-manifest install, invoke, update/uninstall of candidate bytes. |
| EC-04b | AC-04 | Independent isolated-feed .NET consumer copies expected binary content byte-for-byte. |
| EC-05a | AC-05 | Multi-member lifecycle with selected-only advance, consumer update, inspect, cleanup; independent member untouched. |
| EC-06a | AC-06 | 100 SDK projects, 10 package IDs, direct/CPM/dynamic references, baseline correctness and preservation. |
| EC-06b | AC-06 | Repeatable measured elapsed and peak memory/bounds; explain variance and failures without invented performance SLA. |
| EC-07a | AC-07 | Invalid paths/junction/unsafe cleanup and no-clobber preserve source and pins. |
| EC-07b | AC-07 | Staged output and cleanup forced interruption after observed operation phase; precise partial-state evidence. |
| EC-08a | AC-08 | Prepare-only and mock publishing RID-first, pointer failure, wrong approval/feed, tampering, no secret leaks. |
| EC-09a | AC-09 | 2.0 README help quick-start and operator checklist executed/verified. |
| EC-10a | AC-10 | Dependency audit, SPDX/license and provenance inspection on exact candidate artifacts. |

## Validation gates

| ID | Locus | Check | Maps to |
|---|---|---|
| VAL-01 | Windows 11 x64 .NET 11 existing xUnit | dotnet test DotnetNugetContent.sln -c Release --no-restore and schema/CLI regression suite | AC-01, AC-02; EC-01a, EC-02a |
| VAL-02 | Windows 11 x64 actual repository/fixture | Reproducible 100-project/10-package local scanner, preview/apply, inspection with measured report and error bounds | AC-06; EC-06a, EC-06b |
| VAL-03 | Authorized Windows x64 installed Native AOT candidate | scripts/validate-tool.ps1 and scripts/validate-native.ps1 with exact candidate directory; full positive/negative, consumer-byte and interruption checks | AC-04, AC-05, AC-07; EC-04a, EC-04b, EC-05a, EC-07a, EC-07b |
| VAL-04 | Authorized Windows x64 release preparation | eng/publish.ps1 -Prepare on clean intended final merged commit; artifact identity/hashes/metadata, -TestPublish mock paths, security/license audit | AC-02, AC-03, AC-08, AC-10; EC-02a, EC-03a, EC-08a, EC-10a |
| VAL-05 | Repository and candidate provenance | Release checklist/doc parity, real evidence ledger audit and PR human review request | AC-09, ART-01; EC-09a |

## Execution constraints and sequencing

Use focused checks during implementation, then aggregate gates when corresponding surfaces are stable. Preserve valid current evidence when implementation changes do not invalidate a gate. `-Prepare` must use clean candidate source, and **the final approved candidate is qualified only on final merged commit**; implementation branch evidence is explicitly preliminary. If final merged commit is unavailable, record the gate pending and report awaiting post-merge qualification rather than invent a result. Maintain receipts and source fingerprints; do not claim human publication approval. Existing xUnit infrastructure remains unchanged.

## Human review and completion

Required human PR review of source, acceptance results, release candidate receipts, license/security findings and safety policy. Implementer cannot approve review, merge PR or publish on the human’s behalf. Human publication approval is a separate subsequent action and not part of this milestone. If outstanding blocking advisory, legal identity uncertainty, validation capability or missing final merged candidate exists, report BLOCKED / AWAITING FINAL MERGE QUALIFICATION accurately. No blanket release-approved status from pre-merge validation.

## Documentation sync

Update README, NuGet README, public help, release docs, operator publishing checklist, metadata, and `docs/MILESTONES.md`; keep historical milestones preserved. M0007 index must reflect merged reality.

## Escalation

Material changes to package format, distribution targets, public schemas, publication permissions or irreconcilable SDK/Native AOT behavior return to planning. Do not silently change release contract.
