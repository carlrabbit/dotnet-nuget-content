# Execution Ledger — M0003

Primary milestone: `docs/milestones/M0003-windows-tool.md`

Planner-seeded IDs, cases and validation gates. Implementation owns work packages, mapping, evidence, statuses and resume point.

## Milestone Obligation Registry

| ID | Type | Obligation | Work package(s) | Implementation evidence | Validation evidence | Status |
|---|---|---|---|---|---|---|
| AC-01 | acceptance | Produce top-level and matching win-x64 Native AOT NuGet .NET tool packages with consistent version; no any or other RID fallback. | WP-01 | `DotnetNugetContent.csproj` declares PackAsTool and only `ToolPackageRuntimeIdentifiers=win-x64`. | VAL-02 passed: top-level pack and `-r win-x64` pack inspected; nuspec IDs/versions match 0.1.0, RID package contains `tools/any/win-x64` executable and no other RID. | done |
| AC-02 | acceptance | Fresh tool packages install and invoke via an isolated global-equivalent tool installation on Windows x64. | WP-03 | Installed via `dotnet tool install --tool-path` from isolated feed. | VAL-03 passed: isolated shim invoked `--version` as 0.1.0; installed PE machine is AMD64. | done |
| AC-03 | acceptance | Local manifest installation, invocation, tool update and uninstall succeed without modifying the user’s normal tool installations. | WP-03 | Isolated `.config/dotnet-tools.json` and tool path under temporary validation root. | VAL-03 passed: local/global-equivalent install and invocation, both updated 0.1.0→0.1.1 and uninstalled; global/local state isolated. | done |
| AC-04 | acceptance | Installed tool executes full content lifecycle and produces a managed package consumed by an isolated PackageReference project byte-for-byte, without metadata leakage. | WP-03 | Installed tool performed pack, unpack, status, managed repack and history. | VAL-04 passed: independent .NET 11 PackageReference consumer restored from local feed, built, compared final bytes to workspace source and found no `.nuget-content` output. | done |
| AC-05 | acceptance | status --json matches the public contract for clean/dirty workspace and package validation; text-mode behavior remains available. | WP-02, WP-03 | Source-generated workspace/package JSON result models; text remains default. | VAL-01 and VAL-05 passed: clean/dirty workspace, valid/malformed package, parsed fields and arrays, one JSON line, stdout/stderr/exit codes; text status retained. | done |
| AC-06 | acceptance | history --json matches the public chronology/message contract for both workspace and package. | WP-02, WP-03 | Source-generated history JSON preserves optional omitted message. | VAL-01 and VAL-05 passed: workspace/package history parsed, chronology and baseline version checked, initial absent message omitted, supplied message present. | done |
| AC-07 | acceptance | New and existing command modes preserve deterministic output, stdout/stderr and error code semantics, rejecting conflicting selectors. | WP-02, WP-03 | Valueless `--json` recognized only by status/history; selectors are mutually exclusive. | VAL-01 and VAL-05 passed: conflicting selector exits 2 on stderr with no stdout; invalid package exits 1 with no JSON; text behavior and compact JSON checked. | done |
| AC-08 | acceptance | Valid large binary, many files, Unicode names and deep supported Windows paths preserve exact bytes and behavior without payload-sized memory buffering. | WP-03 | Existing streamed hashing/extraction retained; installed validation covers 301 payload files and 64 MiB binary. | VAL-06 passed: 64 MiB pack/status/unpack SHA-256 match; 301 files and 226-character nested Unicode path round-trip exactly. | done |
| AC-09 | acceptance | Failed/interrupted operations and output conflicts protect existing files/baselines and do not commit partial packages or destinations. | WP-03 | Same-volume staging plus final `File.Move` package publication; staged extraction plus final `Directory.Move`; installed-tool checks observe both paths. | Corrected VAL-06 passed: during successful 64 MiB pack, observed staged writes while final path was absent; final path then opened as a valid archive. Separately killed managed pack after observing 197,893 bytes in its unique `.tmp`; no final package appeared, source SHA-256 and baseline marker stayed unchanged. A temp remnant remained, as permitted. Handled malformed-unpack failure separately removed its staging directory and left no destination. | done |
| AC-10 | acceptance | Installed Native AOT tool reports consistent product version and provenance; unsupported RIDs do not acquire framework-dependent fallback. | WP-01, WP-03 | AOT project version 0.1.0, tool pointer and win-x64 RID package. | VAL-02/VAL-03 passed: installed `--version`=0.1.0, AMD64 PE, only win-x64 runtime path. SDK 11.0.100-rc.1.26425.128; VS 18 MSVC 14.51.36231. Installed PE SHA-256 `9B6EB1F709866F037580FF5DB57E5999BD2171218F7E09355F1761ACE822F525`; top-level package SHA-256 `26B54B70D20C1F00BEC493A45ACC7A910246C34F4024F8C2377730C7CCE0E350`; win-x64 package SHA-256 `D716D8A6692BE7F9CBD6BAB832B45137B77D51822B53CFA001DEE018B67E2325`. | done |
| DOC-01 | documentation | Sync directly affected technical installation and structured-output contract documentation; defer help-text wording review and release presentation polish to M0004. | WP-01, WP-02 | Updated README, SPECS, ENGINEERING and M0003 JSON contract. | VAL-07 passed: docs checked against distribution/JSON authority; help-text editorial review and release publication remain assigned to M0004. | done |
| ART-01 | artifact | Reconcile every obligation, evidence case and validation gate using executed criterion-specific evidence and final audit. | WP-03 | Criterion and case evidence recorded in this ledger; package hashes and provenance recorded above. | Final VAL-07 audit passed after corrected EC-09a evidence; all milestone/ledger IDs match and all seven gates are complete. | done |

## Evidence Case Registry

| ID | Parent obligation | Required evidence case | Validation gate(s) | Evidence | Status |
|---|---|---|---|---|---|
| EC-02a | AC-02 | Installed global-equivalent native invocation | VAL-03 | Local-feed tool install, shim invocation, 0.1.0 output and AMD64 PE verified. | done |
| EC-03a | AC-03 | Local manifest install/invocation | VAL-03 | Temporary manifest installation invoked through `dotnet tool run`; reported 0.1.0. | done |
| EC-03b | AC-03 | Update and uninstall with isolated state | VAL-03 | Global-equivalent and manifest installations updated to 0.1.1 and uninstalled; no normal user tool path used. | done |
| EC-04a | AC-04 | Installed tool full managed lifecycle | VAL-04 | Installed command packed, unpacked, reported status, repacked version 1.1.0 and read both history versions. | done |
| EC-04b | AC-04 | Independent NuGet consumer verification | VAL-04 | Isolated consumer restored/built from local feed; its output was compared bytewise against independent workspace files and metadata absence checked. | done |
| EC-05a | AC-05 | Clean and dirty workspace structured result | VAL-05 | External PowerShell JSON parser checked schemaVersion, kind, package, clean and all change arrays. | done |
| EC-05b | AC-05 | Package success and failure structured behavior | VAL-05 | Valid package returned `valid:true` and count; malformed package emitted no stdout JSON and exited 1. | done |
| EC-06a | AC-06 | Workspace/package history and message omission | VAL-05 | Workspace initial entry omitted message; package history kept ordered versions and `installed update`. | done |
| EC-07a | AC-07 | Installed process stdout/stderr, errors and text mode | VAL-05 | JSON single-line stdout, no diagnostics on success; selector conflict exit 2 and package failure exit 1; text mode retained. | done |
| EC-08a | AC-08 | Large binary and many files | VAL-06 | 64 MiB SHA-256-preserving round trip and 301-file package inventory passed. | done |
| EC-08b | AC-08 | Unicode and nested Windows paths | VAL-06 | Unicode path length 226 characters and bytes preserved on pack/unpack. | done |
| EC-09a | AC-09 | Handled-failure cleanup and no-clobber; forced termination at a confirmed meaningful operation phase demonstrates final-path atomicity and baseline preservation | VAL-06 | Successful pack: staging file observed above 64 KiB, final path absent during staged write, then complete archive opened. Abrupt kill: uniquely named temp observed at 197,893 bytes; final absent before and after kill; source hash and workspace marker unchanged; temp remnant permitted. Separate handled malformed-unpack error removed staging directory and left no destination. | done |
| EC-10a | AC-10 | Native RID selection and consistent version | VAL-02 | Top-level pointer and win-x64 AOT package versions match; installed version and PE architecture verified; no `any`/other RID executable. | done |

## Work Packages

| ID | Work package | Scope and evidence |
|---|---|---|
| WP-01 | NuGet tool packaging and technical docs | SDK `PackAsTool`, command name, win-x64 RID-only selection, package identity/version and installation documentation. |
| WP-02 | Structured status/history output | Source-generated compact JSON DTOs, valueless switch parsing, selector conflict checks, unit-level shape and error tests. |
| WP-03 | Installed tool and consumer proof | Local isolated feeds and tool states; lifecycle, JSON, consumer, filesystem stress, failure/interruption and provenance checks. |

## Validation Gates

| ID | Required validation | Target/locus | Proves evidence units | Status | Evidence |
|---|---|---|---|---|---|
| VAL-01 | dotnet test -c Release, including JSON shape/error and file integrity tests | local Windows SDK | AC-05, AC-06, AC-07, AC-09 | passed | `dotnet test DotnetNugetContent.sln -c Release --no-restore`: 14 passed, 0 failed, SDK 11.0.100-rc.1.26425.128. |
| VAL-02 | dotnet pack top-level and dotnet pack -r win-x64 Native AOT, inspect package metadata | local Windows SDK/native linker | AC-01, EC-10a | passed | Executed by `scripts/validate-tool.ps1`; top-level and win-x64 packages version 0.1.0; nuspec identity/version and payload paths verified. No other RID package. |
| VAL-03 | Install, invoke, update, uninstall top-level tool from isolated local feed via global-equivalent and local manifest modes | local Windows isolated tool state | EC-02a, EC-03a, EC-03b | passed | Executed by `scripts/validate-tool.ps1`; isolated local feed; tool-path and temporary manifest install/invoke/update/uninstall 0.1.0→0.1.1. |
| VAL-04 | Installed tool pack/unpack/status/repack/history and isolated dotnet restore/build consumer with independent byte oracle | local Windows installed tool/consumer | EC-04a, EC-04b | passed | Installed tool produced managed 1.1.0 snapshot; isolated consumer build succeeded and compared output bytes with workspace source, metadata absent. |
| VAL-05 | Installed status/history JSON, malformed cases, output streams, exit codes and text mode | local Windows installed tool | EC-05a, EC-05b, EC-06a, EC-07a | passed | Executed by `scripts/validate-tool.ps1`; PowerShell parsed all JSON cases and checked stream ownership, message presence/omission, exit codes and text mode. |
| VAL-06 | Large file/many files/deep-Unicode Windows paths and handled-error cleanup and meaningful-stage interruption checks | local Windows filesystem | EC-08a, EC-08b, EC-09a | passed | Final `scripts/validate-tool.ps1` run: 64 MiB streamed pack/status/unpack, 301 files, 226-character Unicode path, output conflicts, malformed extraction cleanup, successful staged-to-final publication check, and forced kill after 197,893 staged bytes. Final package absent after kill; baseline and source hashes unchanged; allowed `.tmp` remnant observed. |
| VAL-07 | Reconcile referenced project authority, milestone, ledger and artifact provenance | repository and installed artifact | DOC-01, ART-01, AC-10 | passed | Reread current authority; all 12 AC/DOC/ART IDs, 13 EC IDs and 7 VAL IDs match milestone and ledger sets. AC-09, EC-09a, VAL-06 and completion evidence updated; installed artifact and package hashes from this run recorded above. |

## Resume Point

Last completed work package: WP-03

Current work package: complete; correction ready to commit and push to PR #3

Next concrete action: commit and push the evidence correction to the existing PR #3

Known agent-resolvable gaps: EC-09a stage-aware interruption proof and revised AC-09 reconciliation

External blockers/escalations: none known; missing toolchain must be reported

## Final Reconciliation

- [x] Exact milestone/ledger obligation and evidence-case ID equality.
- [x] Each obligation and evidence case linked to implemented behavior and executed validation at declared target/locus.
- [x] Installed tool/consumer proofs and native artifact provenance recorded; no substitutes.
- [x] Repeat the interruption portion of VAL-06 at a verified meaningful stage; distinguish forced-kill remnants from handled-error cleanup.
- [x] Rerun VAL-07 and final audit; update criterion-specific durable M0003 evidence after EC-09a closure.
