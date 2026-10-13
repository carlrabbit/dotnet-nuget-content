# Execution Ledger — M0001

Primary milestone: `docs/milestones/M0001-initialization.md`

Planner-seeded coverage registry. Implementation owns work packages, evidence, progress and resume point. This ledger does not amend the milestone.

## Milestone Obligation Registry

| ID | Type | Obligation | Work package(s) | Implementation evidence | Validation evidence | Status |
|---|---|---|---|---|---|---|
| AC-01 | acceptance | The repository contains coherent project authority, CLI entry documentation, and a compilable `net11.0` solution for the initial native command-line product. | WP-01, WP-05 | `.sln`, `src/DotnetNugetContent/DotnetNugetContent.csproj`, root README | VAL-01 Release build/test under .NET 11 RC | done |
| AC-02 | acceptance | The CLI exposes discoverable help/version and documented non-interactive package creation and extraction commands with stable basic exit and diagnostics behavior. | WP-01, WP-03 | `Program.cs` command parser and README syntax/exit documentation | VAL-01 `CliHelpVersionAndExpectedHashHaveStableExitBehavior`; native help/version in VAL-04 | done |
| AC-03 | acceptance | A directory containing nested text and binary files can be packaged under an explicit ID and new exact version, then extracted with paths and bytes preserved. | WP-02, WP-03, WP-04 | `ContentPackages.PackAsync`/`UnpackAsync`; `PackAndUnpackPreserveNestedTextAndBinaryBytes` | VAL-02 separate text/binary byte/path assertions; VAL-04 native package round-trip | done |
| AC-04 | acceptance | The produced `.nupkg` uses correct `contentFiles` metadata and is consumed by a fresh isolated .NET 11 `PackageReference` project; restore/build copies nested files into its output. | WP-02, WP-04 | `ManifestContentFiles` metadata; `scripts/validate-consumer.ps1` | VAL-03 clean local-feed restore/build and output byte checks | done |
| AC-05 | acceptance | Integrity operations calculate SHA-256 for package/files and reject a supplied incorrect expected package hash without reporting false success. | WP-02, WP-03 | `Sha256Async`, expected-hash checks on `hash` and `unpack` | VAL-01 wrong expected hash returns code 2, stderr mismatch, no digest on stdout; package/file SHA tests | done |
| AC-06 | acceptance | Unsafe archive paths, malformed package inputs, and preexisting output conflicts are rejected without silently clobbering user files or writing outside the target. | WP-02, WP-03 | Path validation, duplicate checks, staging, non-overwrite guards | VAL-01 traversal, duplicate, malformed, invalid identity/version, package/output conflict tests | done |
| AC-07 | acceptance | A Release Native AOT executable is successfully published and invoked for representative pack/unpack/help behavior; executable size and AOT/trim diagnostics are recorded. | WP-04 | AOT publish has not run locally; current host lacks the Visual Studio C++ toolchain | VAL-04 pending local AOT-capable environment | todo |
| AC-08 | acceptance | Preferred NuGet.Packaging Native AOT feasibility is decided from build and runtime evidence; only if it fails for a reproducible material reason is the approved SDK CLI backend used and its SDK dependency documented. | WP-02, WP-04 | Package creation/reading uses `NuGet.Packaging` 7.9.0; AOT feasibility remains unverified locally | VAL-05 pending local AOT publish/runtime smoke; no backend pivot made | todo |
| DOC-01 | documentation | User-facing README and engineering documentation describe implemented CLI syntax, distribution requirements, backend choice and actual verified behavior without claiming unimplemented features. | WP-05 | `README.md`, `docs/ENGINEERING.md` | VAL-06 authority/document/evidence review | done |
| ART-01 | artifact | Implementation preserves durable, criterion-specific completion evidence and records a milestone completion audit; no criterion is marked complete on aggregate green tests alone. | WP-05 | This reconciled ledger and milestone completion trace | VAL-06 exact ID-set comparison and criterion-specific audit | done |

## Evidence Case Registry

| ID | Parent obligation | Required evidence case | Validation gate(s) | Evidence | Status |
|---|---|---|---|---|---|
| EC-03a | AC-03 | Nested text files retain bytes and paths | VAL-02 | `PackageLifecycleTests.PackAndUnpackPreserveNestedTextAndBinaryBytes`; VAL-03 consumer text SHA-256 `80708E852F8DAECDA67CB59ECC583E83734EEC8581784FB49319F1B9FCA6BA9F` | done |
| EC-03b | AC-03 | Non-text binary files retain bytes and paths | VAL-02 | `PackageLifecycleTests.PackAndUnpackPreserveNestedTextAndBinaryBytes`; VAL-03 consumer binary SHA-256 `F103C95A021522160E6BA79358839FC33B40916D671AFD205C7386EBDEE8CBAF` | done |
| EC-07a | AC-07 | Native published executable launches and serves help/version | VAL-04 | Pending local Native AOT publish and executable invocation | todo |
| EC-07b | AC-07 | Native published executable performs package round-trip | VAL-04 | Pending local Native AOT package round-trip | todo |
| EC-08a | AC-08 | Preferred AOT+NuGet.Packaging path receives actual build and execution evidence | VAL-05 | Pending local Native AOT publish and preferred-backend runtime smoke | todo |
| EC-08b | AC-08 | If preferred path fails, SDK fallback is exercised and its runtime prerequisite documented | VAL-05 | Conditional; decision waits for local preferred-path AOT evidence | todo |

## Work Packages

| ID | Work package | Scope | Obligations | Status |
|---|---|---|---|---|
| WP-01 | CLI substrate | Create solution, `net11.0` CLI, argument parsing, help/version, stable diagnostics. | AC-01, AC-02 | done |
| WP-02 | Package backend | Implement NuGet.Packaging package creation, safe extraction, file/package hashes and defenses. | AC-03, AC-05, AC-06, AC-08 | done |
| WP-03 | Automated validation | Add focused and integration tests for CLI, package round-trip, and malicious/conflict cases. | AC-02, AC-03, AC-05, AC-06 | done |
| WP-04 | Consumer and native proof | Validate isolated PackageReference consumer and publish/invoke Release Native AOT binary. | AC-04, AC-07, AC-08 | in-progress |
| WP-05 | Docs and audit | Align README/engineering docs, reconcile evidence registries, complete criterion audit. | DOC-01, ART-01 | in-progress |

## Validation Gates

| ID | Required validation | Target/locus | Proves evidence units | Status | Evidence |
|---|---|---|---|---|---|
| VAL-01 | `dotnet test --configuration Release` focused CLI/filesystem tests | CLI parser and filesystem behavior; local Windows / .NET 11 RC SDK 11.0.100-rc.1.26425.128 | AC-02, AC-05, AC-06 | done | 6 passed, 0 failed; package and hash failure diagnostics asserted |
| VAL-02 | `dotnet test --configuration Release` package integration suite | Actual content package round-trip; local Windows / .NET 11 RC SDK | EC-03a, EC-03b | done | nested UTF-8 text and arbitrary binary bytes/paths compared exactly; generated nuspec metadata asserted |
| VAL-03 | `pwsh -NoProfile -File scripts/validate-consumer.ps1` | Fresh isolated consumer, local package feed / .NET 11 RC SDK | AC-04 | done | restore/build succeeded; nested output bytes match; text SHA-256 `80708E852F8DAECDA67CB59ECC583E83734EEC8581784FB49319F1B9FCA6BA9F`; binary SHA-256 `F103C95A021522160E6BA79358839FC33B40916D671AFD205C7386EBDEE8CBAF` |
| VAL-04 | `dotnet publish -c Release -r win-x64 --self-contained true`, invoke artifact | Local Windows host with Native AOT prerequisites; .NET 11 RC SDK 11.0.100-rc.1.26425.128 | EC-07a, EC-07b | todo | Local publish attempted; SDK reports missing Visual Studio C++ tools. Awaiting user's local toolchain setup. |
| VAL-05 | Native AOT publish plus preferred backend pack/unpack smoke | Local native compiler host | EC-08a, EC-08b | todo | Preferred backend feasibility remains unverified under Native AOT. No fallback selected. |
| VAL-06 | Review delivered docs, ledger, and criterion-specific evidence | Repository authority and obligation closure | AC-01, DOC-01, ART-01 | in-progress | Ledger currently reconciles evidence IDs, but final audit awaits VAL-04 and VAL-05. |

## Resume Point

Implementation is complete except for the required local Native AOT publish/runtime validation and final audit. Resume after the local Windows C++ toolchain is available.

## Final Reconciliation

- [x] Reread milestone; verify exact set equality of milestone obligation IDs and this registry.
- [x] Verify exact set equality for `EC-*` IDs; preserve separate text, binary, native launch, native round-trip, and backend cases.
- [x] Ensure each gate proves only behavior executed on its stated target/locus.
- [ ] Validate remaining obligations individually after local Native AOT validation.
- [ ] Run the required native check on the user's locally prepared environment.
- [ ] Record preferred-backend feasibility and evaluate the authorized fallback only from that local evidence.
- [ ] Complete final criterion audit after VAL-04 and VAL-05.
- [ ] Write completion trace to the milestone after all gates pass.
