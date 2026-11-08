# M0008 execution ledger — planning seed

Primary milestone: `docs/milestones/M0008-release-qualification.md`
No implementation status or receipts seeded.

## Obligations

| ID | Exact obligation | Status | Work packages | Evidence |
|---|---|---|---|---|
| AC-01 | All M0001–M0007 behavior and published v1 manifest, workspace marker and JSON contracts remain compatible; regressions are verified against the final candidate. | pending | — | — |
| AC-02 | Tool version, both NuGet package IDs/versions, nuspec metadata, installed executable version, README and help consistently identify 2.0.0 and Windows x64-only support. | pending | — | — |
| AC-03 | Build from a clean, identified final merged source commit produces two immutable qualified 2.0.0 NuGet tool package artifacts with SHA-256 hashes and provenance; no publication occurs. | pending | — | — |
| AC-04 | Exact candidate artifacts pass isolated local-feed global-equivalent and local-manifest installation, invocation, update/uninstall and independent consumer byte-verification checks. | pending | — | — |
| AC-05 | Full developer lifecycle across multiple content packages, pin advancement, reference preview/apply, inspection and safe cleanup passes installed Native AOT acceptance including negative/failure scenarios. | pending | — | — |
| AC-06 | Repository-scale qualification of local usage scanning, reference preview/apply and inspection runs on a reproducible 100-project/10-package fixture with bounded completion, correct scope and preserved unrelated files. | pending | — | — |
| AC-07 | Release qualification covers adversarial paths, junctions, no-clobber, staged interruption, cleanup partial deletion and safe recovery claims; no unsupported cross-file crash atomicity is asserted. | pending | — | — |
| AC-08 | Existing human-operated publication workflow is updated to require exact qualified 2.0.0 artifact identity, RID-first dry-run ordering, hash checks and explicit nuget.org approval; no real push occurs. | pending | — | — |
| AC-09 | Public documentation, release notes, metadata and release/operator checklist accurately describe all 2.0 workflows, Windows restrictions, limitations and separate publication authorization; milestone index reflects merged M0007. | pending | — | — |
| AC-10 | Security/dependency advisory and artifact provenance checks run on candidate dependencies; unresolved high-risk advisories or licensing/ownership defects block release qualification rather than being waived implicitly. | pending | — | — |
| ART-01 | Planning-seeded ledger is reconciled criterion-by-criterion with current executed receipts, final SHA-256 and Git commit, and truthful human review/publication state. | pending | — | — |

## Distinct evidence cases

| ID | Parent | Exact required proof | Status | Evidence |
|---|---|---|---|---|
| EC-01a | AC-01 | Legacy single-package and multi-package commands, schemas and output invariants. | pending | — |
| EC-02a | AC-02 | Exact two 2.0.0 package metadata, installed tool version and authored docs. | pending | — |
| EC-03a | AC-03 | Candidate exact merged Git SHA, clean tree, reproducible command, package hashes and immutable receipt. | pending | — |
| EC-04a | AC-04 | Global-equivalent and local-manifest install, invoke, update/uninstall of candidate bytes. | pending | — |
| EC-04b | AC-04 | Independent isolated-feed .NET consumer copies expected binary content byte-for-byte. | pending | — |
| EC-05a | AC-05 | Multi-member lifecycle with selected-only advance, consumer update, inspect, cleanup; independent member untouched. | pending | — |
| EC-06a | AC-06 | 100 SDK projects, 10 package IDs, direct/CPM/dynamic references, baseline correctness and preservation. | pending | — |
| EC-06b | AC-06 | Repeatable measured elapsed and peak memory/bounds; explain variance and failures without invented performance SLA. | pending | — |
| EC-07a | AC-07 | Invalid paths/junction/unsafe cleanup and no-clobber preserve source and pins. | pending | — |
| EC-07b | AC-07 | Staged output and cleanup forced interruption after observed operation phase; precise partial-state evidence. | pending | — |
| EC-08a | AC-08 | Prepare-only and mock publishing RID-first, pointer failure, wrong approval/feed, tampering, no secret leaks. | pending | — |
| EC-09a | AC-09 | 2.0 README help quick-start and operator checklist executed/verified. | pending | — |
| EC-10a | AC-10 | Dependency audit, SPDX/license and provenance inspection on exact candidate artifacts. | pending | — |

## Validation gates

| ID | Locus | Required check | Obligation IDs | Status | Receipt |
|---|---|---|---|---|---|
| VAL-01 | Windows 11 x64 .NET 11 existing xUnit | dotnet test DotnetNugetContent.sln -c Release --no-restore and schema/CLI regression suite | AC-01, AC-02; EC-01a, EC-02a | pending | — |
| VAL-02 | Windows 11 x64 actual repository/fixture | Reproducible 100-project/10-package local scanner, preview/apply, inspection with measured report and error bounds | AC-06; EC-06a, EC-06b | pending | — |
| VAL-03 | Authorized Windows x64 installed Native AOT candidate | scripts/validate-tool.ps1 and scripts/validate-native.ps1 with exact candidate directory; full positive/negative, consumer-byte and interruption checks | AC-04, AC-05, AC-07; EC-04a, EC-04b, EC-05a, EC-07a, EC-07b | pending | — |
| VAL-04 | Authorized Windows x64 release preparation | eng/publish.ps1 -Prepare on clean intended final merged commit; artifact identity/hashes/metadata, -TestPublish mock paths, security/license audit | AC-02, AC-03, AC-08, AC-10; EC-02a, EC-03a, EC-08a, EC-10a | pending | — |
| VAL-05 | Repository and candidate provenance | Release checklist/doc parity, real evidence ledger audit and PR human review request | AC-09, ART-01; EC-09a | pending | — |
