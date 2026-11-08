# M0009 execution evidence ledger

**State: implementation branch validated; final merged-source M0008 qualification remains outstanding.**

Implementation branch: `codex/managed-pack-baseline-advancement`<br>
Tested implementation and integration-test commit: `837063e49f249873943002d8c6b452c83c52e4a0`<br>
Native/installed product source commit: `b8bbe5fe9ffa5b687c8d2e0fa89a31d351d27f41` (the follow-up commit only strengthened cleanup-diagnostic assertions)<br>
Target: Windows x64 Native AOT, .NET SDK `11.0.100-rc.3.26522.148`, xUnit.

Earlier 37-test and Native AOT receipts are superseded. The receipts below were generated after the disposable-extraction implementation and the focused validation changes at the tested commit above. No package or release was published.

## Acceptance criteria

| Criterion | State | Criterion-specific evidence |
|---|---|---|
| AC-01 | passed | `ManagedPackDeletesExtractionOnlyAfterPublishingVerifiedPackage` and both native validators create an initial package and confirm the arbitrary source directory and bytes remain. |
| AC-02 | passed | Real managed package tests verify package identity/version, embedded manifest, payload hashes/inventory and chronological history, then confirm the extracted directory is absent. Native installed lifecycle repeats pack after an explicit re-unpack. |
| AC-03 | passed | No-op, invalid output and collision cases retain the extraction. A post-publication file mutation is detected before deletion; the complete package is retained and edited extraction remains. A real Windows sharing violation during recursive deletion returns nonzero, reports the extraction path and retains the package/residual directory. Workspace advance cleanup failure reports the already-updated pin and package. |
| AC-04 | passed | `WorkspaceLifecycleKeepsIndependentPinsAndManagedBaselines` verifies staging-only `workspace pack` creates a valid higher package while preserving root pin, member baseline bytes and extraction directory. |
| AC-05 | passed | `AdvanceUpdatesOnlySelectedPinAndDeletesExtractionWithoutSecondCopy` and installed validation verify only selected version/packageFile change; directory path remains `content/advance`/`content/fixtures`; extraction is removed; no version-suffixed second directory appears; independent member and package bytes remain unchanged. |
| AC-06 | passed | Unit/integration and installed tests run `workspace unpack` after advance, recreate the same registered path, and verify clean status, updated content and package history. |
| AC-07 | passed | `scripts/validate-tool.ps1` verified compiled CLI help equals `docs/release/HELP-TEXT.md`, release package metadata and embedded README parity. README, NuGet README, product/workspace specs, M0009 contract, release notes and package metadata were reviewed for canonical `dotnet nuget-content` usage and disposable lifecycle semantics. |
| AC-08 | passed | Fresh Windows x64 Native AOT process validation and locally installed Native AOT tool validation passed. Independent .NET 11 PackageReference consumers compared output bytes against separately prepared source oracles. |
| ART-01 | passed | All AC/EC/VAL entries are reconciled below. Prior baseline-advancement receipts are explicitly superseded. This branch evidence remains preliminary; final release qualification must use the clean final merged source. |

## Evidence cases

| Case | State | Evidence |
|---|---|---|
| EC-01 | passed | Initial arbitrary source path and bytes remain after `pack --id`, verified in real-file xUnit and Native AOT validators. |
| EC-02 | passed | Package manifest/version, payload inventory and history validated; extracted path is absent after successful managed pack. Installed tool re-unpacks the new version for continued editing. |
| EC-03a | passed | No-op patch, existing output collision and invalid `.zip` output all fail before publication and retain extraction/content. |
| EC-03b | passed | Injected post-publication edit is caught by final package/source verification; package remains valid and extraction remains. A locked payload causes actual `Directory.Delete` failure with accurate partial-state message. Workspace pin-update/delete failure reports updated version, package path and stable extraction path. |
| EC-04 | passed | Workspace pack leaves pin, member manifest and member directory byte-identical/present. |
| EC-05 | passed | Workspace advance publishes and verifies one package; changes selected version/packageFile only; keeps selected directory path; deletes only its extraction and produces no second directory. Other member pin/content and original packages are unchanged. |
| EC-06 | passed | Re-unpack restores updated package at same configured directory; status is clean and updated bytes/history are present. |
| EC-07 | passed | Installed validator compares compiled root help to authored help and checks release metadata/README parity; `git diff --check` passes. |
| EC-08 | passed | Fresh AOT executable and installed win-x64 tool pass real lifecycle and isolated PackageReference byte comparison against independent source oracles. |

## Validation gates

| Gate | State | Actual execution and receipts |
|---|---|---|
| VAL-01 | passed | Focused command: `dotnet test DotnetNugetContent.sln -c Release --no-restore --filter "FullyQualifiedName~ManagedPackDeletesExtractionOnlyAfterPublishingVerifiedPackage|FullyQualifiedName~AdvanceUpdatesOnlySelectedPinAndDeletesExtractionWithoutSecondCopy|FullyQualifiedName~AdvanceReportsPublishedPackageAndTruthfulCleanupOrPinFailure|FullyQualifiedName~WorkspaceLifecycleKeepsIndependentPinsAndManagedBaselines"` — **5 passed, 0 failed, 0 skipped**. Includes actual Windows file-sharing deletion failure and assertions for package path plus previous/intended versions in partial-cleanup diagnostics. |
| VAL-02 | passed | `dotnet test DotnetNugetContent.sln -c Release --no-restore` — **37 passed, 0 failed, 0 skipped**. |
| VAL-03 | passed | `pwsh -NoProfile -File scripts/validate-native.ps1` exited 0. Fresh Native AOT executable, 11,257,856 bytes; SHA-256 `7C2D9EE3FE145D5E161C15E514E9EE55DAEA97B4D37AE8AD2EC4A43CBB92B093`. Same-directory native lifecycle published `sample.native` 1.2.4 SHA-256 `3639CF275E0DE9F33B7C50821876204DB952068969EC914358CBA476424041F4`, re-unpacked and repacked 1.2.5 SHA-256 `376733B26FCD4F6E9966E513726E6BCAA072276FEBA4A9E6E23347755C40B397`, then 1.2.6 SHA-256 `38E83A895EF1A543075C0199621AFB3F278CFDC70BEF3B682EFB9A6DBD7AA1A2`. Extraction absence and re-unpack cleanliness were checked; independent consumer matched two payload files against a separate oracle. |
| VAL-04 | passed | `pwsh -NoProfile -File scripts/validate-tool.ps1` exited 0 using the installed Native AOT tool and isolated local feed. Installed executable SHA-256 `7C2D9EE3FE145D5E161C15E514E9EE55DAEA97B4D37AE8AD2EC4A43CBB92B093`; top-level package SHA-256 `6ED2196D73F15F95706CA0756DC3D20E8352888238827F6814C10356DAAF83D7`; win-x64 package SHA-256 `7EF4E95AEFF1A60C624444D1015228AFDA99968392A25E8B7B4B2DDACF282B5E`. Installed managed package `sample.installed` 1.1.0 SHA-256 `E4C66CCB2DFBE609034899F5AC5423979459E1300DC0B7372A900ECC567FD59E`; repeated 1.1.1 SHA-256 `FCC18B2800C720EB4EE509FDAECA73D5FE1658FA437027C219DA33E494242503`; workspace advance 1.0.1 SHA-256 `98F4547095ECA2B3927A7A84483E98D74EEFC75930F15ED762C81936F4D2C504`. Verified unpack/edit/pack/delete/re-unpack, updated content/history, clean workspace state, unchanged prior package, workspace pin-only advance without duplicate extraction, and independent consumer bytes. Existing M0005/M0006/M0007 installs/consumers, 301-file inventory, 226-character Unicode path, 64 MiB streaming, malformed-input cleanup and meaningful forced-termination checks passed. |
| VAL-05 | passed | Authored/compiled help parity and release metadata/README parity passed within installed-tool validation. `git diff --check` passed. Exact AC-01–08, EC-01–08 and VAL-01–05 reconciled in this ledger. |

## Reconciliation and release boundary

- The M0009 archive was expanded to a staging directory and reconciled by relative path. All five packaged paths already existed in the updated PR branch; the package README explicitly warned not to overwrite those normative files, so the newer branch copies were retained.
- Managed `pack` now uses `DeleteAfterPack`; initial unmanaged pack does not delete arbitrary source. `workspace pack` explicitly selects `Preserve`; `workspace advance` packages once, updates selected pin, retains the configured directory path and deletes the extraction without creating a duplicate.
- Package-construction or pre-pin failures preserve extracted content. Published packages are retained on verification/cleanup failure. Post-publication mutation and real filesystem deletion failures return nonzero with package/path and partial-state guidance; no rollback or cross-artifact transaction is claimed.
- Manifest v1, workspace JSON v1, xUnit, Windows x64 Native AOT and existing package formats remain unchanged.
- PR #10 contains only preliminary implementation-branch evidence. Do not reuse these local artifacts or receipts as the 2.0.0 release candidate. After review and merge, rerun complete M0008 qualification from the clean final merged source commit. No NuGet.org publication, GitHub release, CI change or host provisioning was performed.
