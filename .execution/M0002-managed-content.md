# Execution Ledger — M0002

Primary milestone: `docs/milestones/M0002-managed-content.md`

Operational state; the milestone and its referenced project authority are definitive. Planner seeds IDs, obligations, evidence cases and gates; implementer owns work-package mapping and results.

## Milestone Obligation Registry

| ID | Type | Obligation | Work package(s) | Implementation evidence | Validation evidence | Status |
|---|---|---|---|---|---|---|
| AC-01 | acceptance | An initial `pack` from an ordinary source directory produces a package with a valid, public v1 ZIP-root manifest matching nuspec identity and exact payload paths, sizes and SHA-256 hashes, and initial history. | WP-01/WP-08 | WP-01: v1 manifest from source-generated model; nuspec identity and file SHA-256/size/path inventory. | VAL-01: manifest round-trip, root ZIP location, exact inventory; VAL-03: same manifest behavior in native pack. | done |
| AC-02 | acceptance | `unpack` creates a managed working directory with correct payload bytes and a baseline marker at its root, while package/working metadata is excluded from contentFiles consumer output. | WP-02/WP-05/WP-08 | WP-02/WP-05: transactional staged streamed unpack writes root marker separate from content payload. | VAL-01/03: streamed unpack preserves fixture bytes and root marker; VAL-04/08: package metadata absent from consumer output. | done |
| AC-03 | acceptance | `status` in a managed workspace reports clean, added, modified and deleted state by SHA-256 and paths without changing the baseline. | WP-02/WP-08 | WP-02: status compares normalized paths and streamed file hashes read-only. | VAL-01: clean and independent add/modify/delete assertions; VAL-03: explicit and implicit clean/change status; marker remains unchanged. | done |
| AC-04 | acceptance | Implicit CWD discovery for managed `status`, `history`, and `pack` works only at the workspace root; explicit source works; missing/invalid root marker yields an actionable failure without searching ancestors. | WP-02/WP-08 | WP-02: only explicit root or CWD root marker is resolved. | VAL-03: implicit root status/history/pack and explicit source; nested CWD failure proves no ancestor search. | done |
| AC-05 | acceptance | A managed `pack` produces a higher immutable version with complete current payload, correct updated snapshot hashes and one appended accurate linear history entry; `--message` is optional and not invented. | WP-02/WP-05/WP-08 | WP-02/WP-05: immutable higher-version package and linear change calculation; output path is outside root. | VAL-01/02: 1.0.0→1.1.0 append/message; subsequent 1.1.0→1.2.0 omission; VAL-06: implicit/explicit defaults resolve beside workspace and avoid self-inclusion. | done |
| AC-06 | acceptance | Managed pack rejects unchanged content, non-increasing versions, reserved metadata path collisions and existing output without modifying workspace baseline or leaving partial package outputs. | WP-02/WP-05/WP-08 | WP-02/WP-05: refusal guards precede artifact commit; baseline is unchanged. | VAL-01: no-op, non-increasing version, reserved namespace, existing output and in-workspace output fail without mutation. | done |
| AC-07 | acceptance | `history` displays recorded lineage from managed workspace or explicit package, in chronological order, including message when supplied. | WP-02/WP-08 | WP-02: chronological recorded history rendered from marker/package. | VAL-01/03: chronological package history, supplied message, and implicit workspace baseline history. | done |
| AC-08 | acceptance | `status --package` verifies a packaged manifest against actual embedded content and distinguishes valid from mismatched/malformed manifests with nonzero actionable failure. | WP-01/WP-05/WP-08 | WP-01/WP-05: runtime schema and semantic validation plus streamed actual inventory verification. | VAL-01/07: valid package accepted; inventory mismatch, unknown schema and malformed history rejected. VAL-06: 64 MiB package validation/extraction remains under payload-sized allocation threshold. | done |
| AC-09 | acceptance | The public JSON Schema and normative format document are valid, consistent and exercised by representative serialization/validation tests including rejected unknown versions and malformed history. | WP-01/WP-06/WP-08 | WP-01/WP-06: complete structural validator plus semantic version/path/history invariants. | VAL-01/07: public schema requirements and runtime validation; missing/null/wrong-typed/nested/unknown fields and multi-entry initial-history errors rejected. | done |
| AC-10 | acceptance | A freshly published Native AOT executable exercises a multi-version managed lifecycle and its new content package is consumed by an isolated NuGet PackageReference project with correct bytes/paths and no metadata leakage. | WP-03/WP-07/WP-08 | WP-03/WP-07: repeatable Native AOT process and isolated PackageReference oracle use independent workspace bytes. | VAL-03/04/08: fresh native 1.2.3→1.2.4→1.2.5 lifecycle; isolated consumer compares every payload byte with independent edited workspace source. | done |
| DOC-01 | documentation | README/help and directly affected engineering documentation accurately describe the delivered managed commands and initial interchange contract. | WP-03/WP-08 | WP-03: README/help describe parent output default, self-inclusion refusal, stream processing and lifecycle. | VAL-05: README/help/engineering behavior reviewed against revised authority and schema. | done |
| ART-01 | artifact | All M0002 obligations, evidence cases and validation gates are reconciled with actual executed criterion-specific evidence in the milestone and ledger. | WP-04/WP-08 | WP-08: all obligations/cases/gates re-audited against current fresh evidence. | VAL-05: exact obligation/case/gate ID sets reconciled; current evidence recorded; old hashes explicitly superseded. | done |

## Evidence Case Registry

| ID | Parent obligation | Required evidence case | Validation gate(s) | Evidence | Status |
|---|---|---|---|---|---|
| EC-03a | AC-03 | Clean workspace remains clean | VAL-01, VAL-02 | VAL-01/02: test asserts exact Clean; VAL-03 native explicit and implicit CWD status both Clean. | done |
| EC-03b | AC-03 | Added, modified and deleted files are independently distinguished | VAL-01, VAL-02 | VAL-01/02/03: clean→added/modified/deleted fixture deltas each independently asserted. | done |
| EC-04a | AC-04 | Implicit CWD at exact root works | VAL-01, VAL-03 | VAL-03: native status/history/managed pack from workspace CWD pass at exact root. | done |
| EC-04b | AC-04 | Explicit source and nested/non-workspace failures work | VAL-01, VAL-03 | VAL-01/03: explicit source works; nested current directory fails with marker path and no ancestor search. | done |
| EC-05a | AC-05 | Optional message is present when supplied | VAL-01, VAL-02 | VAL-01/02/03: supplied message appears in packaged history. | done |
| EC-05b | AC-05 | Message is absent when omitted, including subsequent versions | VAL-01, VAL-02 | VAL-01/02: next version created from unpacked latest snapshot omits message property. | done |
| EC-06a | AC-06 | No-op/non-increasing-version refusal preserves state | VAL-01 | VAL-01: unchanged/equal-version failures preserve marker and create no package. | done |
| EC-06b | AC-06 | Reserved path/output conflict refusal preserves state | VAL-01 | VAL-01/06: reserved path, existing output and in-workspace output rejected; marker/output preserved. | done |
| EC-10a | AC-10 | Published native process performs managed workflow | VAL-03 | VAL-03: fresh executable completed 1.2.3→1.2.4→1.2.5 native lifecycle, including both default output roots. | done |
| EC-10b | AC-10 | NuGet consumer receives payload only | VAL-04 | VAL-04: isolated consumer restored/built native 1.2.4; metadata absent and manifest payload paths copied. | done |
| EC-05c | AC-05 | Default output is outside workspace for implicit and explicit source; generated package is never payload | VAL-06 | VAL-06: implicit CWD and explicit --source default outputs both created in workspace parent; status confirms neither package enters inventory; in-root explicit output fails. | done |
| EC-09a | AC-09 | Malformed required/null/typed/nested manifest data and multi-entry initial history are rejected | VAL-07 | VAL-07: missing required, empty array, null package/hash/changes/array, wrong size type, missing nested field, unknown nested field, plus multi-entry first modified/predecessor violations all fail domain validation. | done |
| EC-08a | AC-08 | Package validation/extraction streams a large valid binary without whole-file buffering | VAL-06 | VAL-06: 64 MiB binary pack→status --package→unpack passed; measured total allocations below 64 MiB; streamed SHA/size and extracted hash/length match. | done |
| EC-10c | AC-10 | Native consumer output matches independent final workspace bytes | VAL-08 | VAL-08: consumer Compare-FileBytes streams every manifest path against edited workspace source; source size/SHA also independently agrees with manifest. | done |

## Work Packages

| ID | Work package | Obligations |
|---|---|---|
| WP-01 | Manifest v1 model, schema/semantic validation, package inventory and initial history | AC-01, AC-08, AC-09 |
| WP-02 | Managed workspace unpack/status/root discovery/linear repack/history and refusal semantics | AC-02–AC-07, EC-03a/b, EC-04a/b, EC-05a/b, EC-06a/b |
| WP-03 | User documentation and repeatable native lifecycle + isolated consumer validation | DOC-01, AC-10, EC-10a/b |
| WP-04 | Tiered validation, evidence reconciliation and final audit | ART-01, all validation gates |
| WP-05 | Correct managed output placement, self-inclusion refusal, and bounded-memory payload streaming | AC-02, AC-05, AC-06, AC-08, EC-05c, EC-08a |
| WP-06 | Enforce complete JSON Schema structure/nullability and first-entry invariants across history | AC-08, AC-09, EC-09a |
| WP-07 | Compare native consumer output with independent final workspace source; extend Tier 4 cases | AC-10, EC-10c |
| WP-08 | Freshly rerun all gates, reconcile provenance, and complete final evidence audit | all obligations, evidence cases, VAL-01–VAL-08 |

## Validation Gates

| ID | Required validation | Target/locus | Proves evidence units | Status | Evidence |
|---|---|---|---|---|---|
| VAL-01 | `dotnet test --configuration Release`: schema, filesystem status, version guards, error semantics | local .NET 11 RC SDK | AC-01, AC-02, EC-03a, EC-03b, EC-04a, EC-04b, EC-05a, EC-05b, EC-06a, EC-06b, AC-07, AC-08, AC-09 | done | dotnet test --configuration Release passed: 12 passed, 0 failed on .NET SDK 11.0.100-rc.1.26425.128; includes schema invalid cases, large binary allocation and managed state guards. |
| VAL-02 | CLI pack/unpack/status/repack/history through multiple exact versions with real files | local filesystem + CLI | AC-01, AC-02, EC-03a, EC-03b, EC-05a, EC-05b, AC-07, AC-08 | done | Real package lifecycle through current implementation and fresh native CLI: initial 1.2.3 unpack, change/status, repack 1.2.4 and 1.2.5, history and package inventory validation. |
| VAL-03 | Fresh `win-x64` Native AOT publish + actual native process integration (repeatable script) | local Windows with SDK 11 RC and native linker | EC-04a, EC-04b, EC-10a | done | Fresh win-x64 Native AOT from clean implementation source commit bcc01e3; harness revision 62d344f; artifact artifacts/native validation 1a95375cfde84634b2968510af842f5a/dotnet-nuget-content.exe; 10,199,552 bytes; SHA-256 B3102CB117CF11C1B1DC54D0998D41D6B490CB132ED96C8A28B25F4659672FB3; process matrix and managed lifecycle passed; no AOT/trim warnings (SDK preview notice only). |
| VAL-04 | Isolated .NET 11 PackageReference restore/build consuming freshly native-produced package | local isolated NuGet feed + SDK | EC-10b, AC-02 | done | The same fresh native-produced sample.native 1.2.4 package restored from an isolated local feed and built in net11.0 consumer; all payload bytes compared to independently edited workspace files; no .nuget-content output. |
| VAL-05 | Review authority/schema/help, seeded ledger and complete criterion-specific audit | repository, local | DOC-01, ART-01, AC-09 | done | Reviewed current AGENTS, README, SPECS, ENGINEERING, TERMINOLOGY, MILESTONES, manifest Markdown/schema, revised milestone and full ledger; exact 12 obligation IDs, 14 evidence IDs and 8 gate IDs reconciled. |
| VAL-06 | Default/explicit root output placement, in-workspace output rejection, large valid binary streamed | local SDK/filesystem | EC-05c, EC-08a | done | Native script confirmed implicit and explicit-source omitted-output packages land at workspace parent, workspace inventory excludes them and explicit inside-root output fails. 64 MiB streamed pack/package-status/unpack test passed with total allocations below 67,108,864 bytes and exact size/SHA. |
| VAL-07 | Full schema conformance and multi-entry historical initial record | local SDK + public schema | EC-09a | done | 12-test suite exercised required/schema nested types, nullability, unknown names and semantic initial entries including a multi-record history; all malformed cases returned CliException exit 1. |
| VAL-08 | Native consumer bytes independently compared with edited workspace | Windows native + isolated consumer | EC-10c | done | Fresh native PackageReference consumer used independent workspace path; script verified source against manifest size/SHA, compared every output file byte-by-byte with fixed-size streaming buffers, and checked metadata exclusion. |

## Reconciled Historical Native Receipts

The pre-correction milestone hash `E219979FFE30A92553AC1D555219EF4D382FB4F1CA36420BBEE159CE7C37580B` and ledger hash `30576BDBEC8057E6A0F67585922DC87BDFAD83E89A49EA2C2C3B8EBB2CAFB0E3` refer to older, non-correction runs and are superseded. Neither is claimed as the current deliverable. The single final correction artifact is recorded under VAL-03 with its source commit, harness revision, path, size, and hash.

## Resume Point

Correction work packages and validation receipts are complete. Prior receipts remain historical only and are superseded where noted above.

Last completed work package: WP-08

Current work package: none

Next concrete action: none; M0002 evidence closure is complete.

Known agent-resolvable gaps: none.

External blockers or planning escalations: none currently known.

## Final Reconciliation

- [x] Reconcile exact milestone obligation and evidence-case IDs, including EC-05c, EC-08a, EC-09a, EC-10c.
- [x] Run fresh VAL-01 through VAL-08 against corrected code/artifact, recording individual evidence.
- [x] Reconcile recorded native artifact identity and contradictory historical hashes.
- [x] Reaudit every obligation and case, preserving independently valid historical evidence only where still applicable.
- [x] Publish durable final criterion-specific completion evidence to the milestone before marking done.
