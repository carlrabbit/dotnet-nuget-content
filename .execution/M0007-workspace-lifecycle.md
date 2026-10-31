# M0007 execution ledger

Primary milestone: `docs/milestones/M0007-workspace-lifecycle.md`  
Implementation branch: `codex/m0007-workspace-lifecycle` (based on fetched `origin/main`, commit `2002a3a`).  
Validation host: Windows 11 x64, .NET SDK `11.0.100-rc.1.26425.128`, xUnit, Native AOT win-x64.  
No publication, release version change, CI modification, cross-platform target, or test framework migration was performed.

## Obligations

| ID | Status | Work package | Implementation evidence | Validation evidence |
|---|---|---|---|---|
| AC-01 | complete | `workspace advance` uses existing managed pack/unpack primitives and atomically writes the marker last. | `src/DotnetNugetContent/ProjectWorkspace.cs`; member replacement follows package publish, clean unpack and verification. | `ProjectWorkspaceTests.AdvancePublishesPackageAndCleanCopyBeforeChangingOnlySelectedPin`; VAL-04 real installed workflow. |
| AC-02 | complete | Version, baseline, identity, root containment, overlap, absent destination, output extension, no-clobber and unchanged-content preflight. | Same implementation; preflight validates prospective member list before creating artifacts. | `AdvancePreflightRejectsNoChangeExistingAndOutsideTargetsBeforePublication`; `WorkspacePackRejectsMismatchedBaselineBeforeCreatingOutput`; VAL-04. |
| AC-03 | complete | Pre-commit failures retain old pin and preserve completed artifacts with recovery details. | Stage-specific diagnostics report current pin and unregistered package/directory; no automatic rollback deletion. | `AdvanceFailureRetainsOldPinAndReportsRecoverableArtifacts` for post-package and post-unpack injected failures. |
| AC-04 | complete | Read-only inspect reports pin/path, workspace state, observed consumer declaration version/provenance and diagnostics. | `workspace inspect`; new schema v1. | `InspectReportsDirectAndCentralConsumerDriftWithVersionedContracts` covers clean, modified, missing, corrupt, mismatched, direct/central drift and dynamic values; VAL-03 and VAL-04. |
| AC-05 | complete | Candidate scan is immediate-sibling only; only same-ID lower-version managed workspaces are listed, marked clean/modified; reparse and registered members excluded. | `FindCandidatesAsync` enumerates only the pinned directory parent and does not traverse reparse points. | Advance/cleanup xUnit cases and installed workflow verify candidate identification; junction safeguards exercised in VAL-02. |
| AC-06 | complete | Preview is non-mutating; apply deletes one named proven clean obsolete sibling only. | `CleanupAsync` defaults to preview and revalidates immediately before one recursive removal. | `CleanupPreviewIsReadOnlyAndApplyRemovesOnlyCleanOlderDirectory`; installed real-package preview/apply; immutable package hash preserved. |
| AC-07 | complete with limitation | Active, modified, unrelated, overlapping, unsafe and reparse targets are blocked; deletion failure is reported as partial with no rollback claim. | `EnsureCleanupTarget`, `ValidateObsoleteCandidateAsync`, revalidation and partial-state handling. | Modified/active/junction rejection and injected delete failure are exercised. A forced process termination during recursive cleanup was not run; see EC-07b. |
| AC-08 | complete | New versioned inspect/cleanup JSON schemas, help and developer docs; legacy contracts retained. | `docs/specs/M0007-*`, `docs/SPECS.md`, `docs/MILESTONES.md`, READMEs, authored/root/workspace help. | JSON contract tests, pre-existing M0003/M0005/M0006 regression suite, `git diff --check`; `scripts/validate-tool.ps1` checks installed help and prior JSON workflows. |
| AC-09 | complete | Installed Native AOT tool workflow proves advance, consumer drift, isolation, byte preservation and approved cleanup. | `scripts/validate-tool.ps1` M0007 lifecycle section. | VAL-04 passed. Native executable SHA-256 `E2B52907353C76BD25B7E53CEA105BA3F8B0CFD3EE0967BDD4CAA6524EA5DC4F`; initial package SHA-256 `C90DB4E5E904A5E5F1B6517C3A3A4FA3BD6C560BDA35C583688EC752C4BB2DAF`; consumer bytes matched independently prepared source. |
| ART-01 | pending final PR | Reconcile all criteria/cases/gates and current branch state. | This ledger. | Implementation and validation are complete; update with PR URL and final commit after push. |

## Evidence cases

| ID | Status | Evidence |
|---|---|---|
| EC-01a | pass | xUnit and installed-tool advance from modified managed content; new package/directory clean, marker updated, previous copy and package bytes preserved. |
| EC-02a | pass | xUnit rejects baseline mismatch, no-change, conflicting/unsupported selection, outside-root directory/output, occupied destination/output; existing data and marker bytes retained. |
| EC-03a | pass | Injected failures after package publication and after unpack preserve prior marker/working files and report exact unregistered artifacts. |
| EC-04a | pass | Inspect tests cover clean, modified, missing, corrupt, mismatched; direct and central version drift and dynamic declaration classification. |
| EC-05a | pass | Candidate discovery returns immediate older managed siblings, excludes registered members, and does not cross reparse junctions. |
| EC-06a | pass | Preview leaves bytes unchanged; explicit apply removes only clean obsolete copy; immutable package hash remains unchanged. |
| EC-07a | pass | Modified, active and reparse-junction targets remain; implementation blocks unproven/unknown, unrelated and overlapping paths before deletion. |
| EC-07b | partial | Injected handled delete failure returns `partial`, preserves the directory and makes no rollback/atomicity claim. Abrupt process termination during deletion was not exercised. |
| EC-08a | pass | Both M0007 JSON schemas are versioned; help/docs synchronized; prior JSON/CLI regression tests remain in the 34-test xUnit suite and installed validator. |
| EC-09a | pass | `scripts/validate-tool.ps1`: installed win-x64 Native AOT tool advanced member; direct consumer drift observed; local .NET 11 consumer output matched an independent byte oracle; unrelated pin and old workspace/package retained; clean obsolete sibling previewed and removed. |

## Validation gates

| Gate | Status | Receipt |
|---|---|---|
| VAL-01 | pass | `dotnet test DotnetNugetContent.sln -c Release --no-restore`: 34 passed, 0 failed, xUnit on Windows x64/.NET 11 RC. Covers path/version/baseline/advance and injected advance failures. |
| VAL-02 | pass with limitation | Temporary real `.nupkg` and member trees in xUnit: inspect/cleanup positive and negative paths, clean preview/apply, modified/active/junction guards and injected handled deletion failure. Forced termination during deletion not exercised. |
| VAL-03 | pass | Project fixture inspection tests cover direct/central/dynamic consumer provenance, version drift, state classifications and M0007 schema. Existing M0003/M0005/M0006 JSON regressions passed. |
| VAL-04 | pass | `pwsh -NoProfile -File scripts/validate-tool.ps1` passed, including existing installed global/local NuGet-tool workflows and new M0007 real-package/consumer scenario. Fresh win-x64 Native AOT executable SHA-256 recorded above. Consumer source oracle SHA-256 `25336671F059CB34146CCFFFC9A1FA6EB1FB0FF151B82C02EE43E91B7C400B1C`; advanced pin `1.0.1`; cleanup removed only `content/fixtures-clean-old`. |
| VAL-05 | pending final PR | `pwsh -NoProfile -File scripts/validate-native.ps1` passed after correcting its stale version and M0006 usage-error expectations. `git diff --check` passed. Reconcile PR URL/final commit after push. |

## Validation notes and limitations

- `scripts/validate-tool.ps1` output confirmed existing M0005/M0006 installed-tool regressions, Native AOT install/update/uninstall, 64 MiB payload, interrupted package staging, and M0007 lifecycle passed. The M0007 consumer restored from an isolated local source and output bytes matched independently prepared source bytes.
- `scripts/validate-native.ps1` first exposed stale assertions (`0.1.0`, then pre-M0006 `--version` error text). The validator was corrected to match current product metadata and version-selection usage contract; rerun passed with Native executable SHA-256 `587637714ECAA5125B8D55BDD16F16C919EBB22C359D5CB1F3B6BC72D1C808CC`.
- Native AOT restore reports existing advisories for `System.Security.Cryptography.Pkcs` 8.0.1 (`GHSA-2fmv-rv2c-59x7`, moderate; `GHSA-846f-f764-76mx`, high). Dependency changes are outside M0007; no toolchain/runtime substitution was made.
- Cleanup intentionally has no cross-filesystem rollback or crash-atomic guarantee. The handled failure path is tested; no abrupt termination was injected during recursive deletion.

## Final reconciliation

Implementation branch is based on current fetched `origin/main`; all required product and developer documentation was updated. No `.NET` tool package was published and no release version was changed. Human PR review remains required by the milestone. PR URL and final commit: pending push/creation.
