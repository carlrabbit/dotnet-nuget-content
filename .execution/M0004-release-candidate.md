# Execution Ledger — M0004

Milestone: `docs/milestones/M0004-release-candidate.md`. Planner owns immutable obligation/case rows. Implementer owns work packages, validation receipts and progress.

## Milestone Obligation Registry

| ID | Type | Obligation | Work package(s) | Implementation evidence | Validation evidence | Status |
|---|---|---|---|---|---|---|
| AC-01 | acceptance | Planning-authored GitHub README provides accurate, executable Windows-only install, pack/unpack/edit/repack and PackageReference quick start. | WP-01 | `README.md`, `docs/nuget/README.md` | VAL-01; VAL-03 | complete |
| AC-02 | acceptance | Installed tool root help uses planning-authored final CLI wording while maintaining existing commands and exit behavior. | WP-02 | `src/DotnetNugetContent/Program.cs`; authored text in `docs/release/HELP-TEXT.md` | VAL-01; installed log checks help/version and existing exit tests | complete |
| AC-03 | acceptance | Top-level NuGet package includes authored readme, description, tags, verified author/license, repository/project URL and release notes; RID package metadata is inspected. | WP-02, WP-04 | `DotnetNugetContent.csproj`; both nupkg nuspecs and embedded `README.md` | VAL-02; metadata assertions in installed validation | complete |
| AC-04 | acceptance | Both 1.0.0 NuGet tool packages, installed Native AOT executable version and candidate report match; only win-x64 payload is supported. | WP-04 | `<candidate>/candidate.json`, two package files, installed validation log | VAL-02; VAL-03 | complete |
| AC-05 | acceptance | eng/publish.ps1 prepares a qualified release candidate without publishing by default and records immutable source/artifact provenance. | WP-03, WP-04 | `eng/publish.ps1`; `<candidate>/candidate.json`; read-only package/report files | VAL-04; actual `-Prepare` completed; report `published:false` | complete |
| AC-06 | acceptance | Explicit publishing mode enforces NuGet.org confirmation, RID-first then top-level order, hash/identity verification, safe credential handling and failure-stop semantics without actually pushing. | WP-03 | `eng/publish.ps1`; `<candidate>/publishing-mock-validation.log` | VAL-04; mock order/refusal/tamper/failure-state cases; no successful publish command | complete |
| AC-07 | acceptance | Exact candidate packages install via global-equivalent and local-manifest tool mechanisms; installed command passes lifecycle, JSON, update/uninstall and independent PackageReference consumer checks. | WP-04 | `<candidate>/installed-tool-validation.log` | VAL-03; exact candidate packages used from isolated local feed | complete |
| AC-08 | acceptance | Verified legal/license and package identity exist; any unavailable human licensing decision is a release blocker, not invented by Implementer. | WP-01, WP-02 | `LICENSE` (Unlicense); Git author history; package nuspecs | VAL-02; VAL-05 | complete |
| AC-09 | acceptance | Operator release checklist and report allow separately approved publishing of the exact qualified bytes without rebuilding. | WP-03, WP-04 | `<candidate>/candidate.json`, `<candidate>/PUBLISH-CHECKLIST.md`, package hashes | VAL-05; checklist names exact immutable candidate artifacts | complete |
| ART-01 | artifact | All milestone obligations, heterogeneous evidence cases and validation gates are reconciled to real executed evidence; completion states do not claim public publication. | WP-04 | This ledger and M0004 completion evidence | VAL-05; exact ID reconciliation below | complete |

## Evidence Case Registry

| ID | Parent obligation | Required evidence case | Validation gate(s) | Evidence | Status |
|---|---|---|---|---|---|
| EC-03a | AC-03 | Public top-level package metadata and README | VAL-02 | Top package ID/version, title, exact description/tags, author, Unlicense expression, URLs, release notes, and embedded authored README asserted | complete |
| EC-03b | AC-03 | RID package identity and metadata | VAL-02 | RID nuspec identity/version and same release metadata/readme asserted; PE/package RID inventory inspected | complete |
| EC-04a | AC-04 | Two packed artifact versions and checksums | VAL-02 | Top-level and `win-x64` package are both `1.0.0`; SHA-256 values independently recomputed and match `candidate.json` | complete |
| EC-04b | AC-04 | Installed Native AOT version and RID | VAL-03 | Exact local-feed candidate installs; shim runs AMD64 PE from `tools/any/win-x64`; `--version` is `1.0.0`; executable hash recorded in installed log | complete |
| EC-05a | AC-05 | Default/prepare never publishes | VAL-04 | `-Prepare` built and qualified locally; implementation places publish branch behind `-Publish`; preparation invokes local-feed validation only and report has `published:false` | complete |
| EC-06a | AC-06 | RID-first publication command order | VAL-04 | Mock trace asserted `dotnet-nuget-content.win-x64` before `dotnet-nuget-content` | complete |
| EC-06b | AC-06 | Failed first push stops pointer and records partial state | VAL-04 | Mock throws on first (RID) push; trace contains only RID; status JSON records none published, RID failed, and recovery guidance | complete |
| EC-07a | AC-07 | Global-equivalent installed tool | VAL-03 | Exact candidate installed under isolated `--tool-path`; version, lifecycle, update `1.0.1`, and uninstall passed | complete |
| EC-07b | AC-07 | Local-manifest and independent consumer | VAL-03 | Exact candidate installed/updated/uninstalled by isolated local manifest; consumer built from local feed and output bytes compared with independent workspace source | complete |
| EC-08a | AC-08 | Verified license provenance | VAL-02 | Repository `LICENSE` is Unlicense; commit author evidence identifies Martin Koch; package metadata is `Unlicense`; no missing-license decision | complete |
| EC-09a | AC-09 | Qualified hashes and human publication checklist | VAL-05 | Candidate report contains source SHA, toolchain, validation receipts and package hashes; checklist points to the exact same files; `published:false` | complete |

## Work Packages

Implementation-owned: derive after inspecting the live repository.

## Validation Gates

| ID | Required validation | Target/locus | Proves | Status | Evidence |
|---|---|---|---|---|---|
| VAL-01 | Release .NET tests and help/README contract checks | Windows x64 .NET 11 | AC-01, AC-02 | complete | `dotnet test DotnetNugetContent.sln -c Release --no-restore`: 14 passed. Installed root help byte-for-byte matched the authored block; authored README commands were checked against the installed workflow and independent consumer gate. |
| VAL-02 | Pack/inspect two 1.0.0 tool packages, metadata, license and PE | Windows x64 Native AOT | EC-03a, EC-03b, EC-04a, EC-08a | complete | SDK `11.0.100-rc.1.26425.128`; MSVC `19.51.36257` x64. Both nupkg metadata/readme assertions passed; AMD64 PE and win-x64-only payload asserted. Hashes and sizes in candidate report; independently rehashed. |
| VAL-03 | Install exact qualified nupkg files and run installed lifecycle, updates and consumer | Windows x64 local isolated feed | EC-04b, EC-07a, EC-07b | complete | `<candidate>/installed-tool-validation.log`: exact packages installed globally-equivalent and locally; `1.0.0 -> 1.0.1`, lifecycle/JSON/text, update/uninstall, 301 paths, 226-character Unicode path, 64 MiB stream/interruption, and independent consumer byte oracle passed. |
| VAL-04 | Test safe eng script default, mock push order/failure and hash tampering | PowerShell mock/local; no NuGet.org | EC-05a, EC-06a, EC-06b | complete | `-Prepare` produced candidate locally with no publishing action. Mock-only test passed order, first-push stop/status, wrong feed/approval, and hash tamper. No API key or successful push was used. |
| VAL-05 | Audit version/license, release checklist and evidence ledger | repository and candidate artifacts | AC-08, EC-09a, ART-01 | complete | License/author sources inspected; candidate report hashes/toolchain/receipts recomputed and matched; exact obligation/case/gate ID sets reconciled; no publication claimed. |

## Resume Point

Last completed work package: WP-04 candidate qualification and evidence audit
Current work package: complete
Next action: open implementation PR against `main`; public publication remains outside M0004
Known agent-resolvable gaps: none
External blockers: none; existing SDK/MSVC Native AOT toolchain and repository Unlicense were verified

## Final Reconciliation

- [x] Exact milestone/ledger obligation and evidence case ID sets match.
- [x] Real Windows installed-tool checks against immutable candidate files.
- [x] Both packages have verified legal metadata, provenance and checksums.
- [x] Safe publishing behavior verified using mocks only, with no successful public pushes.
- [x] Per-criterion evidence, release candidate report, and final milestone audit recorded.

## Executed Work Packages

| ID | Scope | Result |
|---|---|---|
| WP-01 | Integrate planning-authored root/NuGet README and verify repository license/author facts. | Complete; Unlicense is explicit in `LICENSE`; commit history identifies Martin Koch. |
| WP-02 | Set stable 1.0.0 package metadata and integrate exact authored root help. | Complete; package metadata/readme checks pass for both package identities; installed help matches authored block. |
| WP-03 | Implement local-only preparation and separately guarded publication in `eng/publish.ps1`. | Complete; dry preparation and isolated mocks pass; no successful NuGet.org push. |
| WP-04 | Build, inspect, install, exercise, hash and audit immutable candidate packages. | Complete; source commit `4cb2d534fb016f35eb36e1bce3144b88d865cb25`; candidate directory and artifacts are recorded below. |

## Candidate and source provenance

Candidate directory: `artifacts/release-candidate-1.0.0-4cb2d534fb016f35eb36e1bce3144b88d865cb25` (local, ignored build artifact directory; package/report files are read-only).

| Package | Version | Size (bytes) | SHA-256 |
|---|---:|---:|---|
| `dotnet-nuget-content.win-x64.1.0.0.nupkg` | 1.0.0 | 13,658,722 | `F6679408CD1118C878E44CB730A045E0E2139E106757E7B791A452133A085473` |
| `dotnet-nuget-content.1.0.0.nupkg` | 1.0.0 | 3,368 | `707E044423254C579E285E8EC556703823B84A887CD9657AB030B747CC97B35C` |

Candidate report: `<candidate>/candidate.json`; preparation timestamp `2026-10-17T22:31:41Z`; SDK `11.0.100-rc.1.26425.128`; MSVC x64 compiler `19.51.36257`. Candidate report hashes match independently recomputed file hashes. Installed executable reported `1.0.0`, was an AMD64 PE selected from `tools/any/win-x64`, and had SHA-256 `7D82AD42E25CE7CE5B017C08FEEFABC6B7FA7A9A635A465A97E7B50082368C6F` in this final validation run.

License/author verification: repository `LICENSE` is the Unlicense public-domain dedication, and Git author history records Martin Koch (`carlthedeadrabbit@googlemail.com`) on this repository. Both nupkg nuspecs carry author `Martin Koch` and license expression `Unlicense`; no license or environment blocker remains.

Publication audit: no API key was read and no package was pushed. The candidate report has `published:false`. One invalid-confirmation `-Publish` preflight was refused at the exact-confirmation check before candidate or credential access; no push process was invoked. All positive ordering/failure-path evidence came from `-TestPublish` mocks.

## Final Milestone Audit

All acceptance criteria AC-01 through AC-09, evidence cases EC-03a/03b, EC-04a/04b, EC-05a, EC-06a/06b, EC-07a/07b, EC-08a, EC-09a, and validation gates VAL-01 through VAL-05 have criterion-specific executed evidence above. The ID sets match the milestone package. M0004 is complete as a qualified local release candidate and publication tooling; the product is not publicly released.
