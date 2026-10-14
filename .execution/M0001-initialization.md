# Execution Ledger — M0001

Primary milestone: `docs/milestones/M0001-initialization.md`

Planner-seeded coverage registry. Implementation owns work packages, evidence, progress and resume point. This ledger does not amend the milestone.

## Milestone Obligation Registry

| ID | Type | Obligation | Work package(s) | Implementation evidence | Validation evidence | Status |
|---|---|---|---|---|---|---|
| AC-01 | acceptance | The repository contains coherent project authority, CLI entry documentation, and a compilable `net11.0` solution for the initial native command-line product. | WP-01, WP-05 | `.sln`, `src/DotnetNugetContent/DotnetNugetContent.csproj`, root README | VAL-01 Release build/test under .NET 11 RC | done |
| AC-02 | acceptance | The CLI exposes discoverable help/version and documented non-interactive package creation and extraction commands with stable basic exit and diagnostics behavior. | WP-01, WP-03 | `Program.cs` command parser; README exit contract; `scripts/validate-native.ps1` captures actual process streams and codes | VAL-01 CLI semantics plus VAL-04 native help/version, usage failure, success output, and error stream assertions | done |
| AC-03 | acceptance | A directory containing nested text and binary files can be packaged under an explicit ID and new exact version, then extracted with paths and bytes preserved. | WP-02, WP-03, WP-04 | `ContentPackages.PackAsync`/`UnpackAsync`; managed integration and native process checks | VAL-02 byte/path assertions; VAL-04 native byte round-trip using paths containing spaces | done |
| AC-04 | acceptance | The produced `.nupkg` uses correct `contentFiles` metadata and is consumed by a fresh isolated .NET 11 `PackageReference` project; restore/build copies nested files into its output. | WP-02, WP-04 | `ManifestContentFiles`; `scripts/validate-consumer.ps1` packs with supplied native executable | VAL-03 consumer restore/build from package created by fresh AOT binary, output byte checks | done |
| AC-05 | acceptance | Integrity operations calculate SHA-256 for package/files and reject a supplied incorrect expected package hash without reporting false success. | WP-02, WP-03 | `Sha256Async`, expected-hash checks on `hash` and `unpack` | VAL-01 wrong expected hash returns code 1, stderr mismatch, no digest on stdout; VAL-04 native match/mismatch process checks | done |
| AC-06 | acceptance | Unsafe archive paths, malformed package inputs, and preexisting output conflicts are rejected without silently clobbering user files or writing outside the target. | WP-02, WP-03 | Expected archive exceptions normalize to stable `Invalid NuGet package.`; staging, path validation, duplicate checks, non-overwrite guards | VAL-01 exact malformed exception/diagnostic assertions; VAL-04 native malformed ZIP, unsafe path after staged payload, no partial destination/staging, and existing-file preservation | done |
| AC-07 | acceptance | A Release Native AOT executable is successfully published and invoked for representative pack/unpack/help behavior; executable size and AOT/trim diagnostics are recorded. | WP-04 | Fresh local `win-x64` AOT executable from VAL-04; 9,487,872 bytes; SHA-256 `9F43ACE7AC1C2091C000BC6C855CE417063A6D0BAB7FACA0AD65A464F350F439` | VAL-04 process-level native validation and byte-exact package round-trip; no AOT/trim warnings | done |
| AC-08 | acceptance | Preferred NuGet.Packaging Native AOT feasibility is decided from build and runtime evidence; only if it fails for a reproducible material reason is the approved SDK CLI backend used and its SDK dependency documented. | WP-02, WP-04 | `NuGet.Packaging` 7.9.0 built and performed native pack/unpack and consumer-package creation; no backend pivot | VAL-04/05 fresh publish and native execution; EC-08b conditional | done |
| DOC-01 | documentation | User-facing README and engineering documentation describe implemented CLI syntax, distribution requirements, backend choice and actual verified behavior without claiming unimplemented features. | WP-05 | `README.md`, `docs/ENGINEERING.md` | VAL-06 authority/document/evidence review | done |
| ART-01 | artifact | Implementation preserves durable, criterion-specific completion evidence and records a milestone completion audit; no criterion is marked complete on aggregate green tests alone. | WP-05 | This reconciled ledger and milestone completion trace | VAL-06 exact ID-set comparison and criterion-specific audit | done |

## Evidence Case Registry

| ID | Parent obligation | Required evidence case | Validation gate(s) | Evidence | Status |
|---|---|---|---|---|---|
| EC-03a | AC-03 | Nested text files retain bytes and paths | VAL-02 | `PackageLifecycleTests.PackAndUnpackPreserveNestedTextAndBinaryBytes`; VAL-03 consumer text SHA-256 `80708E852F8DAECDA67CB59ECC583E83734EEC8581784FB49319F1B9FCA6BA9F` | done |
| EC-03b | AC-03 | Non-text binary files retain bytes and paths | VAL-02 | `PackageLifecycleTests.PackAndUnpackPreserveNestedTextAndBinaryBytes`; VAL-03 consumer binary SHA-256 `F103C95A021522160E6BA79358839FC33B40916D671AFD205C7386EBDEE8CBAF` | done |
| EC-07a | AC-07 | Native published executable launches and serves help/version | VAL-04 | Fresh script-published executable returned help/version on stdout, no stderr, code 0; usage error had empty stdout, stderr diagnostic and code 2 | done |
| EC-07b | AC-07 | Native published executable performs package round-trip | VAL-04 | Native `pack`/`unpack` preserved nested UTF-8 text and binary bytes exactly through paths containing spaces | done |
| EC-08a | AC-08 | Preferred AOT+NuGet.Packaging path receives actual build and execution evidence | VAL-04, VAL-05 | Fresh local AOT binary used NuGet.Packaging 7.9.0 to create/read a package and create the package consumed by the isolated .NET 11 consumer | done |
| EC-08b | AC-08 | If preferred path fails, SDK fallback is exercised and its runtime prerequisite documented | VAL-05 | not-applicable: preferred backend passed local AOT build and runtime smoke; fallback not attempted | not-applicable |

## Work Packages

| ID | Work package | Scope | Obligations | Status |
|---|---|---|---|---|
| WP-01 | CLI substrate | Create solution, `net11.0` CLI, argument parsing, help/version, stable diagnostics. | AC-01, AC-02 | done |
| WP-02 | Package backend | Implement NuGet.Packaging package creation, safe extraction, file/package hashes and defenses. | AC-03, AC-05, AC-06, AC-08 | done |
| WP-03 | Automated validation | Add focused and integration tests for CLI, package round-trip, and malicious/conflict cases. | AC-02, AC-03, AC-05, AC-06 | done |
| WP-04 | Consumer and native proof | Validate isolated PackageReference consumer and publish/invoke Release Native AOT binary. | AC-04, AC-07, AC-08 | done |
| WP-05 | Docs and audit | Align README/engineering docs, reconcile evidence registries, complete criterion audit. | DOC-01, ART-01 | done |

## Validation Gates

| ID | Required validation | Target/locus | Proves evidence units | Status | Evidence |
|---|---|---|---|---|---|
| VAL-01 | `dotnet test --configuration Release` focused CLI/filesystem tests | CLI parser and filesystem behavior; local Windows / .NET 11 RC SDK 11.0.100-rc.1.26425.128 | AC-02, AC-05, AC-06 | done | 6 passed, 0 failed. Malformed non-ZIP and malformed Nuspec inputs throw the expected `CliException` with stable text/code; unrelated `ArgumentNullException` remains unclassified. Duplicate and other unsafe package cases assert exact operation failures and no destination/staging residue. Hash mismatch returns 1 with stderr only. |
| VAL-02 | `dotnet test --configuration Release` package integration suite | Actual content package round-trip; local Windows / .NET 11 RC SDK | EC-03a, EC-03b | done | nested UTF-8 text and arbitrary binary bytes/paths compared exactly; generated nuspec metadata asserted |
| VAL-03 | `scripts/validate-consumer.ps1 -NativeExecutable <fresh-publish>` via VAL-04 | Fresh isolated consumer, local package feed / .NET 11 RC SDK; package created by actual native executable | AC-04 | done | restore/build succeeded; nested output bytes match; text SHA-256 `80708E852F8DAECDA67CB59ECC583E83734EEC8581784FB49319F1B9FCA6BA9F`; binary SHA-256 `F103C95A021522160E6BA79358839FC33B40916D671AFD205C7386EBDEE8CBAF` |
| VAL-04 | `pwsh -NoProfile -File scripts/validate-native.ps1` (fresh publish, native process checks, then VAL-03) | Local Windows host; .NET 11 RC SDK 11.0.100-rc.1.26425.128 and installed Visual Studio C++ tools | EC-07a, EC-07b, AC-02, AC-05, AC-06 | done | Fresh `win-x64` executable: 9,487,872 bytes; SHA-256 `9F43ACE7AC1C2091C000BC6C855CE417063A6D0BAB7FACA0AD65A464F350F439`. Help/version, usage and operational exit semantics/streams, hash match/mismatch, paths containing spaces, byte-exact native pack/unpack, malformed ZIP diagnostic, preservation of existing destination, and cleanup/no partial destination after a later unsafe entry passed. Consumer validation with same executable passed. No AOT/trim warnings; SDK preview informational message only. |
| VAL-05 | Native AOT publish plus preferred backend pack/unpack smoke | Local Windows native compiler host | EC-08a, EC-08b | done | Fresh native executable exercised NuGet.Packaging 7.9.0 end-to-end; fallback condition not met, EC-08b not-applicable. |
| VAL-06 | Review delivered docs, ledger, and criterion-specific evidence | Repository authority and obligation closure | AC-01, DOC-01, ART-01 | done | Obligation and evidence-case registries reconciled exactly; every criterion mapped to local executed evidence or explicitly conditional evidence; completion trace recorded in milestone. |

## Resume Point

Complete. All five work packages are closed; all required local validation gates passed.

## Final Reconciliation

- [x] Reread milestone; verify exact set equality of milestone obligation IDs and this registry.
- [x] Verify exact set equality for `EC-*` IDs; preserve separate text, binary, native launch, native round-trip, and backend cases.
- [x] Ensure each gate proves only behavior executed on its stated target/locus.
- [x] Validate every obligation individually against its criterion-specific evidence.
- [x] Run native process and consumer checks against artifacts produced from a fresh local publish.
- [x] Record preferred-backend feasibility from local AOT evidence; fallback was not triggered and has no SDK dependency to record.
- [x] Complete final criterion audit after VAL-04 and VAL-05.
- [x] Write completion trace to the milestone.
