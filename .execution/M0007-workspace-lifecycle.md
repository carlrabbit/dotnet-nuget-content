# M0007 execution ledger

Primary milestone: `docs/milestones/M0007-workspace-lifecycle.md`  
Implementation branch: `codex/m0007-workspace-lifecycle` (based on fetched `origin/main`, commit `2002a3a`; original implementation `1118edf`, with dependency/security and review-correction follow-ups).  
Pull request: https://github.com/carlrabbit/dotnet-nuget-content/pull/7 (open for required human review).  
Validation host: Windows 11 x64, .NET SDK `11.0.100-rc.1.26425.128`, xUnit, Native AOT win-x64.  
No publication, release version change, CI modification, cross-platform target, or test framework migration was performed.

## Obligations

| ID | Status | Work package | Implementation evidence | Validation evidence |
|---|---|---|---|---|
| AC-01 | complete | `workspace advance` uses existing managed pack/unpack primitives and atomically writes the marker last. | `src/DotnetNugetContent/ProjectWorkspace.cs`; member replacement follows package publish, clean unpack and verification. | `ProjectWorkspaceTests.AdvancePublishesPackageAndCleanCopyBeforeChangingOnlySelectedPin`; VAL-04 real installed workflow. |
| AC-02 | complete | Version, baseline, identity, root containment, overlap, absent destination, output extension, no-clobber and unchanged-content preflight; output ancestors use the established reparse-safe resolver. | `AdvanceAsync` resolves the root-relative package output through `ResolvePath` before publishing. | `AdvancePreflightRejectsNoChangeExistingAndOutsideTargetsBeforePublication`; `AdvanceRejectsPackageOutputThroughJunctionBeforePublishing`; junction test verifies marker/baseline and external target remain unchanged; VAL-04. |
| AC-03 | complete | Pre-commit failures retain old pin and preserve completed artifacts with recovery details. | Stage-specific diagnostics report current pin and unregistered package/directory; no automatic rollback deletion. | `AdvanceFailureRetainsOldPinAndReportsRecoverableArtifacts` for post-package and post-unpack injected failures. |
| AC-04 | complete | Read-only inspect reports pin/path, workspace state, observed consumer declaration version/provenance and diagnostics; ambiguous, conditional, malformed, unreadable or changing evidence is unresolved/diagnosed. | `workspace inspect`; bounded declaration inspection retains schema v1 and does not evaluate MSBuild. | `InspectReportsDirectAndCentralConsumerDriftWithVersionedContracts`; `InspectMarksAmbiguousAndChangingConsumerSourcesUnresolvedWithDiagnostics` covers conditions, duplicates/conflicts, malformed XML, changing source, diagnostics and no workspace mutation; VAL-03 and VAL-04. |
| AC-05 | complete | Candidate scan is immediate-sibling only; only same-ID lower-version managed workspaces are listed, marked clean/modified; reparse and registered members excluded. | `FindCandidatesAsync` enumerates only the pinned directory parent and does not traverse reparse points. | Advance/cleanup xUnit cases and installed workflow verify candidate identification; junction safeguards exercised in VAL-02. |
| AC-06 | complete | Preview is non-mutating; apply deletes one named proven clean obsolete sibling only. `applied` is true only after complete deletion. | `CleanupAsync` defaults to preview, revalidates immediately before one recursive removal, and sets `Applied` after `Directory.Delete` succeeds. | `CleanupPreviewIsReadOnlyAndApplyRemovesOnlyCleanOlderDirectory` asserts preview=false, blocked=false, partial=false, completed=true; installed real-package preview/apply; immutable package hash preserved. |
| AC-07 | complete | Active, modified, unrelated, overlapping, unsafe and reparse targets are blocked; deletion failure/interruption makes no rollback claim. | `EnsureCleanupTarget`, `ValidateObsoleteCandidateAsync`, revalidation and partial-state handling. | Modified/active/junction rejection and injected delete failure; controlled installed-tool process termination after observed file deletion; exact resulting filesystem state recorded at EC-07b. |
| AC-08 | complete | New versioned inspect/cleanup JSON schemas, help and developer docs; legacy contracts retained. | `docs/specs/M0007-*`, `docs/SPECS.md`, `docs/MILESTONES.md`, READMEs, authored/root/workspace help. | JSON contract tests, pre-existing M0003/M0005/M0006 regression suite, normative `applied` semantics documented without shape change, `git diff --check`; `scripts/validate-tool.ps1` checks installed help and prior JSON workflows. |
| AC-09 | complete | Installed Native AOT tool workflow proves advance, consumer drift, isolation, byte preservation and approved cleanup. | `scripts/validate-tool.ps1` M0007 lifecycle section and EC-07b isolated interruption fixture. | Final VAL-04 passed. Installed native executable SHA-256 `220F1D086B3B8C03960920EFA9FD9CB515C3C46BBDD1A321383D8F8F27B819D2`; initial package SHA-256 `63A0C6BC545AFB233D656A47EDBA5E909072E29B3AF481752C46DE8056A705FE`; consumer bytes matched independent source. |
| ART-01 | complete | Reconcile all criteria/cases/gates and current branch state. | This ledger. | Existing PR #7 against `main`; M0007 correction and final validation receipts recorded here. No release/publication action. |

## Evidence cases

| ID | Status | Evidence |
|---|---|---|
| EC-01a | pass | xUnit and installed-tool advance from modified managed content; new package/directory clean, marker updated, previous copy and package bytes preserved. |
| EC-02a | pass | xUnit rejects baseline mismatch, no-change, conflicting/unsupported selection, outside-root directory/output, occupied destination/output, and output through a project-root junction; existing data, marker, baseline and external target bytes retained. |
| EC-03a | pass | Injected failures after package publication and after unpack preserve prior marker/working files and report exact unregistered artifacts. |
| EC-04a | pass | Inspect tests cover clean, modified, missing, corrupt, mismatched; direct and central drift/dynamic; conditional and duplicate conflicting references unresolved; malformed XML diagnostic; changing source diagnostic with workspace files unchanged. |
| EC-05a | pass | Candidate discovery returns immediate older managed siblings, excludes registered members, and does not cross reparse junctions. |
| EC-06a | pass | Preview leaves bytes unchanged; explicit apply removes only clean obsolete copy; immutable package hash remains unchanged. |
| EC-07a | pass | Modified, active and reparse-junction targets remain; implementation blocks unproven/unknown, unrelated and overlapping paths before deletion. |
| EC-07b | pass | Injected handled delete failure returns `partial` and `applied:false`. Final installed Native AOT `validate-tool.ps1` isolated fixture observed payload count fall from 12,000 to 10,718 while cleanup remained alive, then killed it; afterward the obsolete directory existed with 8,833 payload files. Workspace marker and immutable package SHA-256 remained unchanged. The evidence records observed state only and makes no rollback, recovery, or atomicity claim. |
| EC-08a | pass | Both M0007 JSON schemas are versioned; help/docs synchronized; prior JSON/CLI regression tests remain in the 34-test xUnit suite and installed validator. |
| EC-09a | pass | `scripts/validate-tool.ps1`: installed win-x64 Native AOT tool advanced member; direct consumer drift observed; local .NET 11 consumer output matched an independent byte oracle; unrelated pin and old workspace/package retained; clean obsolete sibling previewed and removed. |

## Validation gates

| Gate | Status | Receipt |
|---|---|---|
| VAL-01 | pass | `dotnet test DotnetNugetContent.sln -c Release --no-restore`: 36 passed, 0 failed, xUnit on Windows x64/.NET 11 RC. Includes junction output rejection, conservative inspect diagnostics, cleanup applied-state contract and existing advance failure recovery. |
| VAL-02 | pass | Temporary real `.nupkg` and member trees: inspect/cleanup positive and negative paths, clean preview/apply, modified/active/junction guards, injected handled deletion failure, and controlled installed-process interruption after deletion began. |
| VAL-03 | pass | Project fixtures cover direct/central/dynamic provenance, drift, conditions, duplicates/conflicts, malformed XML, changing sources, diagnostics, unchanged schema and no workspace mutation. Existing M0003/M0005/M0006 JSON regressions passed. |
| VAL-04 | pass | Final `pwsh -NoProfile -File scripts/validate-tool.ps1` passed, including installed global/local tool workflows, real M0007 package/consumer lifecycle, and EC-07b. Installed win-x64 Native AOT executable SHA-256 `220F1D086B3B8C03960920EFA9FD9CB515C3C46BBDD1A321383D8F8F27B819D2`. Consumer source oracle SHA-256 `25336671F059CB34146CCFFFC9A1FA6EB1FB0FF151B82C02EE43E91B7C400B1C`; advanced pin `1.0.1`; cleanup removed only approved `content/fixtures-clean-old`. Interruption fixture observed `12000 -> 10718` files before termination and `8833` remaining afterward; pin and package remained unchanged. |
| VAL-05 | pass | `git diff --check` and PowerShell syntax parse passed; full current diff and normative docs reviewed; vulnerability audit reported no vulnerable packages; existing PR #7 still targets `main`. |

## Validation notes and limitations

- Final `scripts/validate-tool.ps1` confirmed existing M0005/M0006 installed-tool regressions, Native AOT install/update/uninstall, 64 MiB payload, interrupted package staging, M0007 lifecycle and the controlled cleanup interruption probe. Installed executable SHA-256: `220F1D086B3B8C03960920EFA9FD9CB515C3C46BBDD1A321383D8F8F27B819D2`. The M0007 consumer restored from an isolated local source and output bytes matched independently prepared source bytes.
- `scripts/validate-native.ps1` first exposed stale assertions (`0.1.0`, then pre-M0006 `--version` error text). The validator was corrected to match current product metadata and version-selection usage contract; rerun passed with Native executable SHA-256 `587637714ECAA5125B8D55BDD16F16C919EBB22C359D5CB1F3B6BC72D1C808CC`.
- Follow-up security fix pins transitive `System.Security.Cryptography.Pkcs` to 8.0.2 in `DotnetNugetContent.csproj`. The .NET advisories identify 8.0.2 as patched for both `GHSA-2fmv-rv2c-59x7` and `GHSA-846f-f764-76mx`. `dotnet list ... --vulnerable` now reports no vulnerable packages; `dotnet test` remains 34/34 passing; fresh Native AOT and installed-tool validators both passed without Pkcs vulnerability warnings. Patched Native AOT executable SHA-256 `71C4A3FB2045DF43D18A663B4F95D6FD97D5F10F4D04F3268C320F989B7CCB95`; patched installed-tool executable SHA-256 `EE54A32E90F24A9DB3004F7A3D3C08639AE65822967BE14406B0A8DDAA2DDC4C`.
- Cleanup intentionally has no cross-filesystem rollback or crash-atomic guarantee. Both handled failure and abrupt process termination during recursive deletion were exercised. The interruption probe records only the resulting state and makes no recovery claim.

## Final reconciliation

Implementation branch is `codex/m0007-workspace-lifecycle`, continuing the existing PR #7 against `main` at https://github.com/carlrabbit/dotnet-nuget-content/pull/7. This correction adds reparse-safe output resolution, conservative consumer inspection, truthful cleanup `applied` reporting and controlled EC-07b interruption evidence. Release test suite (36/36), final installed Native AOT validation, vulnerability audit and documentation reconciliation passed. No `.NET` tool package was published and no release version was changed. Human PR review remains required by the milestone.
