# Execution Ledger — M0002

Primary milestone: `docs/milestones/M0002-managed-content.md`

Operational state; the milestone and its referenced project authority are definitive. Planner seeds IDs, obligations, evidence cases and gates; implementer owns work-package mapping and results.

## Milestone Obligation Registry

| ID | Type | Obligation | Work package(s) | Implementation evidence | Validation evidence | Status |
|---|---|---|---|---|---|---|
| AC-01 | acceptance | An initial `pack` from an ordinary source directory produces a package with a valid, public v1 ZIP-root manifest matching nuspec identity and exact payload paths, sizes and SHA-256 hashes, and initial history. | WP-01/WP-08 | WP-01: deterministic v1 manifest with nuspec identity, exact payload path/size/SHA-256, initial history. | VAL-01 ManagedContentTests: public root manifest fields and file inventory; VAL-03 native lifecycle. | todo |
| AC-02 | acceptance | `unpack` creates a managed working directory with correct payload bytes and a baseline marker at its root, while package/working metadata is excluded from contentFiles consumer output. | WP-02/WP-05/WP-08 | WP-01/WP-02: unpack validates package inventory and stages payload plus root marker; metadata emitted outside contentFiles. | VAL-01 and VAL-03/04: marker and bytes preserved; consumer output excludes metadata. | todo |
| AC-03 | acceptance | `status` in a managed workspace reports clean, added, modified and deleted state by SHA-256 and paths without changing the baseline. | WP-02/WP-08 | WP-02: hash/path diff against immutable marker; status read-only. | STALE pre-correction; revalidate VAL-01/02: EC-03a clean; EC-03b added/modified/deleted assertions. | todo |
| AC-04 | acceptance | Implicit CWD discovery for managed `status`, `history`, and `pack` works only at the workspace root; explicit source works; missing/invalid root marker yields an actionable failure without searching ancestors. | WP-02/WP-08 | WP-02: exact root marker resolution only; source option and CWD defaults. | VAL-03: implicit current-root status/history/pack pass; nested-root marker failure; explicit-source tests. | todo |
| AC-05 | acceptance | A managed `pack` produces a higher immutable version with complete current payload, correct updated snapshot hashes and one appended accurate linear history entry; `--message` is optional and not invented. | WP-02/WP-05/WP-08 | WP-02: higher NuGet version, complete payload, appended changes and optional message. | STALE pre-correction; revalidate VAL-01/02: 1.0.0→1.1.0 message present; subsequent 1.1.0→1.2.0 omitted; hashes and complete inventory checked. | todo |
| AC-06 | acceptance | Managed pack rejects unchanged content, non-increasing versions, reserved metadata path collisions and existing output without modifying workspace baseline or leaving partial package outputs. | WP-02/WP-05/WP-08 | WP-02: no-op/version/reserved path/output guards before commit. | VAL-01: no-op, non-increasing version, reserved namespace and existing output refused; marker/output preserved. | todo |
| AC-07 | acceptance | `history` displays recorded lineage from managed workspace or explicit package, in chronological order, including message when supplied. | WP-02/WP-08 | WP-02: ordered history rendered from workspace marker or explicit package. | VAL-01/02/03: chronological package history and message observed. | todo |
| AC-08 | acceptance | `status --package` verifies a packaged manifest against actual embedded content and distinguishes valid from mismatched/malformed manifests with nonzero actionable failure. | WP-01/WP-05/WP-08 | WP-01: package reader compares manifest inventory to actual embedded payload. | STALE pre-correction; revalidate VAL-01: valid package accepted; payload hash mismatch, unsupported schema and malformed history rejected. | todo |
| AC-09 | acceptance | The public JSON Schema and normative format document are valid, consistent and exercised by representative serialization/validation tests including rejected unknown versions and malformed history. | WP-01/WP-06/WP-08 | WP-01: source-generated v1 JSON model, strict properties and semantic history validation. | STALE pre-correction; revalidate VAL-01/05: schema parsed and const checked; unknown schema and malformed history tests rejected. | todo |
| AC-10 | acceptance | A freshly published Native AOT executable exercises a multi-version managed lifecycle and its new content package is consumed by an isolated NuGet PackageReference project with correct bytes/paths and no metadata leakage. | WP-03/WP-07/WP-08 | WP-03: native validation script repacks 1.2.3 to 1.2.4 and passes that nupkg to isolated consumer. | STALE pre-correction; revalidate VAL-03/04: fresh win-x64 AOT process and isolated net11 consumer of native-produced 1.2.4 package passed. | todo |
| DOC-01 | documentation | README/help and directly affected engineering documentation accurately describe the delivered managed commands and initial interchange contract. | WP-03/WP-08 | WP-03: README/help and engineering guidance updated for M0002 command and format. | VAL-05: README/help/ENGINEERING reviewed against SPECS and manifest v1 authority. | todo |
| ART-01 | artifact | All M0002 obligations, evidence cases and validation gates are reconciled with actual executed criterion-specific evidence in the milestone and ledger. | WP-04/WP-08 | WP-04: final ID reconciliation and executed evidence recorded below. | STALE pre-correction; revalidate VAL-05: all obligation/case/gate IDs reconciled; criterion evidence and final audit recorded. | todo |

## Evidence Case Registry

| ID | Parent obligation | Required evidence case | Validation gate(s) | Evidence | Status |
|---|---|---|---|---|---|
| EC-03a | AC-03 | Clean workspace remains clean | STALE pre-correction: VAL-01, VAL-02 | VAL-01: clean status exact; VAL-03 native explicit and implicit status both output Clean. | todo |
| EC-03b | AC-03 | Added, modified and deleted files are independently distinguished | VAL-01, VAL-02 | VAL-01/03: added new.txt/added.json, modified nested files, deleted bin files each separately listed. | todo |
| EC-04a | AC-04 | Implicit CWD at exact root works | VAL-01, VAL-03 | VAL-03: status, history and managed pack from workspace process CWD succeed. | todo |
| EC-04b | AC-04 | Explicit source and nested/non-workspace failures work | VAL-01, VAL-03 | VAL-01/03: explicit root succeeds; nested CWD fails with marker path; unmarked root fails actionably. | todo |
| EC-05a | AC-05 | Optional message is present when supplied | STALE pre-correction: VAL-01, VAL-02 | VAL-01/03: supplied curated update/native lifecycle message appears in package history. | todo |
| EC-05b | AC-05 | Message is absent when omitted, including subsequent versions | STALE pre-correction: VAL-01, VAL-02 | VAL-01: second repack from unpacked latest version omits message property. | todo |
| EC-06a | AC-06 | No-op/non-increasing-version refusal preserves state | VAL-01 | VAL-01: unchanged and equal-version pack rejected; marker remains byte-identical and no output created. | todo |
| EC-06b | AC-06 | Reserved path/output conflict refusal preserves state | VAL-01 | VAL-01: reserved namespace and pre-existing output rejected; existing bytes and baseline remain intact. | todo |
| EC-10a | AC-10 | Published native process performs managed workflow | STALE pre-correction: VAL-03 | VAL-03: fresh native lifecycle 1.2.3→1.2.4, status/history/root behavior passed. | todo |
| EC-10b | AC-10 | NuGet consumer receives payload only | STALE pre-correction: VAL-04 | VAL-04: isolated restore/build consumes native repack; all manifest files byte-equal; no .nuget-content output. | todo |

| EC-05c | AC-05 | Default output is outside workspace for implicit and explicit source; generated package is never payload | VAL-06 | | todo |
| EC-09a | AC-09 | Malformed required/null/typed/nested manifest data and multi-entry initial history are rejected | VAL-07 | | todo |
| EC-08a | AC-08 | Package validation/extraction streams a large valid binary without whole-file buffering | VAL-06 | | todo |
| EC-10c | AC-10 | Native consumer output matches independent final workspace bytes | VAL-08 | | todo |

## Work Packages

| WP-05 | Correct managed output placement, self-inclusion refusal, and bounded-memory payload streaming | AC-02, AC-05, AC-06, AC-08, EC-05c, EC-08a |
| WP-06 | Enforce complete JSON Schema structure/nullability and first-entry invariants across history | AC-08, AC-09, EC-09a |
| WP-07 | Compare native consumer output with independent final workspace source; extend Tier 4 cases | AC-10, EC-10c |
| WP-08 | Freshly rerun all gates, reconcile provenance, and complete final evidence audit | all obligations, evidence cases, VAL-01–VAL-08 |
| WP-01 | Manifest v1 model, schema/semantic validation, package inventory and initial history | AC-01, AC-08, AC-09 |
| WP-02 | Managed workspace unpack/status/root discovery/linear repack/history and refusal semantics | AC-02–AC-07, EC-03a/b, EC-04a/b, EC-05a/b, EC-06a/b |
| WP-03 | User documentation and repeatable native lifecycle + isolated consumer validation | DOC-01, AC-10, EC-10a/b |
| WP-04 | Tiered validation, evidence reconciliation and final audit | ART-01, all validation gates |

## Validation Gates

| ID | Required validation | Target/locus | Proves evidence units | Status | Evidence |
|---|---|---|---|---|---|
| VAL-01 | `dotnet test --configuration Release`: schema, filesystem status, version guards, error semantics | local .NET 11 RC SDK | AC-01, AC-02, EC-03a, EC-03b, EC-04a, EC-04b, EC-05a, EC-05b, EC-06a, EC-06b, AC-07, AC-08, AC-09 | todo | STALE pre-correction: dotnet test --configuration Release; .NET 11 RC 11.0.100-rc.1.26425.128; 9 passed, 0 failed. |
| VAL-02 | CLI pack/unpack/status/repack/history through multiple exact versions with real files | local filesystem + CLI | AC-01, AC-02, EC-03a, EC-03b, EC-05a, EC-05b, AC-07, AC-08 | todo | STALE pre-correction: ManagedContentTests real package lifecycle + native script multiversion workflow; exact file inventory and history checks passed. |
| VAL-03 | Fresh `win-x64` Native AOT publish + actual native process integration (repeatable script) | local Windows with SDK 11 RC and native linker | EC-04a, EC-04b, EC-10a | todo | STALE pre-correction: pwsh scripts/validate-native.ps1; fresh win-x64 Native AOT; size 10,183,168 bytes; SHA-256 30576BDBEC8057E6A0F67585922DC87BDFAD83E89A49EA2C2C3B8EBB2CAFB0E3; no AOT/trim warnings (SDK preview notice only). |
| VAL-04 | Isolated .NET 11 PackageReference restore/build consuming freshly native-produced package | local isolated NuGet feed + SDK | EC-10b, AC-02 | todo | STALE pre-correction: Same fresh native-produced sample.native 1.2.4 nupkg restored/built via isolated local feed; consumer payload byte comparisons and no metadata leakage passed. |
| VAL-05 | Review authority/schema/help, seeded ledger and complete criterion-specific audit | repository, local | DOC-01, ART-01, AC-09 | todo | STALE pre-correction: Reviewed AGENTS, README, SPECS, ENGINEERING, TERMINOLOGY, MILESTONES, schema/spec and exact seeded ID sets; help and schema/history checks passed. |
| VAL-06 | Default/explicit root output placement, in-workspace output rejection, large valid binary streamed | local SDK/filesystem | EC-05c, EC-08a | todo | |
| VAL-07 | Full schema conformance and multi-entry historical initial record | local SDK + public schema | EC-09a | todo | |
| VAL-08 | Native consumer bytes independently compared with edited workspace | Windows native + isolated consumer | EC-10c | todo | |

## Resume Point

Prior WP results and validation receipts are historical and need reassessment against corrected implementation. Preserve IDs and map additional correction work packages during execution.

Last completed work package: pre-correction WP-04 (historical only)

Current work package: WP-05 through WP-07

Next concrete action: reconcile revised milestone IDs and seed work packages before modifying production code.

Known agent-resolvable gaps: output location, complete schema enforcement, streaming, independent consumer oracle, inconsistent artifact hashes.

External blockers or planning escalations: none currently known.

## Final Reconciliation

- [ ] Reconcile exact milestone obligation and evidence-case IDs, including EC-05c, EC-08a, EC-09a, EC-10c.
- [ ] Run fresh VAL-01 through VAL-08 against corrected code/artifact, recording individual evidence.
- [ ] Reconcile recorded native artifact identity and contradictory historical hashes.
- [ ] Reaudit every obligation and case, preserving independently valid historical evidence only where still applicable.
- [ ] Publish durable final criterion-specific completion evidence to the milestone before marking done.
