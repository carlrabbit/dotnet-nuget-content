# Execution Ledger — M0001

Primary milestone: `docs/milestones/M0001-initialization.md`

Planner-seeded coverage registry. Implementation owns work packages, evidence, progress and resume point. This ledger does not amend the milestone.

## Milestone Obligation Registry

| ID | Type | Obligation | Work package(s) | Implementation evidence | Validation evidence | Status |
|---|---|---|---|---|---|---|
| AC-01 | acceptance | The repository contains coherent project authority, CLI entry documentation, and a compilable `net11.0` solution for the initial native command-line product. | | | | todo |
| AC-02 | acceptance | The CLI exposes discoverable help/version and documented non-interactive package creation and extraction commands with stable basic exit and diagnostics behavior. | | | | todo |
| AC-03 | acceptance | A directory containing nested text and binary files can be packaged under an explicit ID and new exact version, then extracted with paths and bytes preserved. | | | | todo |
| AC-04 | acceptance | The produced `.nupkg` uses correct `contentFiles` metadata and is consumed by a fresh isolated .NET 11 `PackageReference` project; restore/build copies nested files into its output. | | | | todo |
| AC-05 | acceptance | Integrity operations calculate SHA-256 for package/files and reject a supplied incorrect expected package hash without reporting false success. | | | | todo |
| AC-06 | acceptance | Unsafe archive paths, malformed package inputs, and preexisting output conflicts are rejected without silently clobbering user files or writing outside the target. | | | | todo |
| AC-07 | acceptance | A Release Native AOT executable is successfully published and invoked for representative pack/unpack/help behavior; executable size and AOT/trim diagnostics are recorded. | | | | todo |
| AC-08 | acceptance | Preferred NuGet.Packaging Native AOT feasibility is decided from build and runtime evidence; only if it fails for a reproducible material reason is the approved SDK CLI backend used and its SDK dependency documented. | | | | todo |
| DOC-01 | documentation | User-facing README and engineering documentation describe implemented CLI syntax, distribution requirements, backend choice and actual verified behavior without claiming unimplemented features. | | | | todo |
| ART-01 | artifact | Implementation preserves durable, criterion-specific completion evidence and records a milestone completion audit; no criterion is marked complete on aggregate green tests alone. | | | | todo |

## Evidence Case Registry

| ID | Parent obligation | Required evidence case | Validation gate(s) | Evidence | Status |
|---|---|---|---|---|---|
| EC-03a | AC-03 | Nested text files retain bytes and paths | VAL-02 | | todo |
| EC-03b | AC-03 | Non-text binary files retain bytes and paths | VAL-02 | | todo |
| EC-07a | AC-07 | Native published executable launches and serves help/version | VAL-04 | | todo |
| EC-07b | AC-07 | Native published executable performs package round-trip | VAL-04 | | todo |
| EC-08a | AC-08 | Preferred AOT+NuGet.Packaging path receives actual build and execution evidence | VAL-05 | | todo |
| EC-08b | AC-08 | If preferred path fails, SDK fallback is exercised and its runtime prerequisite documented | VAL-05 | | todo |

## Work Packages

| ID | Work package | Scope | Obligations | Status |
|---|---|---|---|---|
| WP-01 | CLI substrate | Create solution, `net11.0` CLI, argument parsing, help/version, stable diagnostics. | AC-01, AC-02 | in-progress |
| WP-02 | Package backend | Implement NuGet.Packaging package creation, safe extraction, file/package hashes and defenses. | AC-03, AC-05, AC-06, AC-08 | todo |
| WP-03 | Automated validation | Add focused and integration tests for CLI, package round-trip, and malicious/conflict cases. | AC-02, AC-03, AC-05, AC-06 | todo |
| WP-04 | Consumer and native proof | Validate isolated PackageReference consumer and publish/invoke Release Native AOT binary. | AC-04, AC-07, AC-08 | todo |
| WP-05 | Docs and audit | Align README/engineering docs, reconcile evidence registries, complete criterion audit. | DOC-01, ART-01 | todo |

## Validation Gates

| ID | Required validation | Target/locus | Proves evidence units | Status | Evidence |
|---|---|---|---|---|---|
| VAL-01 | `dotnet test` focused CLI/filesystem tests | CLI parser and filesystem behavior; local on chosen development OS / .NET 11 RC SDK | AC-02, AC-05, AC-06 | todo | |
| VAL-02 | `dotnet test` integration suite / invoke built CLI | Actual content package round-trip; local / .NET 11 RC SDK | EC-03a, EC-03b | todo | |
| VAL-03 | `dotnet restore` + `dotnet build` isolated consumer | NuGet PackageReference consumer; local isolated source/feed / .NET 11 RC SDK | AC-04 | todo | |
| VAL-04 | `dotnet publish -c Release -r <actual-RID>` then invoke published executable | Published Native AOT executable; native supported build host with AOT prerequisites | EC-07a, EC-07b | todo | |
| VAL-05 | AOT publish and pack/unpack smoke checks; fallback only if preferred backend fails | Packaging backend feasibility; local native AOT build target | EC-08a, EC-08b | todo | |
| VAL-06 | Review delivered docs, seeded ledger, and criterion-specific evidence | Repository authority and obligation closure; local | AC-01, DOC-01, ART-01 | todo | |

## Resume Point

Implementation-owned after decomposition. No work packages or results have been pre-seeded.

## Final Reconciliation

- [ ] Reread milestone; verify exact set equality of milestone obligation IDs and this registry.
- [ ] Verify exact set equality for `EC-*` IDs; do not merge or omit separate proof paths.
- [ ] Ensure each gate proves only behavior actually executed on its stated target/locus.
- [ ] Validate each obligation individually and downgrade unsupported `done` states.
- [ ] Run required native and consumer checks against current artifacts, not stale build outputs.
- [ ] Document authorized fallback trigger and consequent SDK dependency if used.
- [ ] Confirm all agent-resolvable work complete and final audit is current.
- [ ] Write compact durable completion trace to milestone before cleaning operational ledger.
