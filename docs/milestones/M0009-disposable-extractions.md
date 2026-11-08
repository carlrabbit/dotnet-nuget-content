# M0009 — Disposable managed content extractions

| Field | Value |
|---|---|
| State | implementation in PR #10; not accepted |
| Guide | agentic-project-guides 0.9.3 |
| Repository | carlrabbit/dotnet-nuget-content |
| Implementation branch | codex/managed-pack-baseline-advancement |
| Target | Windows x64, .NET 11 Native AOT |
| Normative contract | docs/specs/M0009-disposable-extractions.md |
| Evidence ledger | .execution/M0009-disposable-extractions.md |
| Publication | Not authorized |

## Goal

Replace duplicate-extraction and in-place-baseline-retention behavior with the straightforward unpack → edit → pack → delete temporary extraction lifecycle. A NuGet package contains the new manifest/history; a project workspace additionally advances its pin. No second full-size copy.

## Acceptance criteria

- **AC-01** Initial unmanaged pack never deletes the arbitrary source directory.
- **AC-02** Ordinary managed pack creates a valid higher immutable package, records updated manifest/history, then deletes the verified extracted directory.
- **AC-03** Package errors preserve the extracted directory; post-publication cleanup errors retain the package and report accurate remaining state. Unsafe or changed data never triggers automatic deletion.
- **AC-04** Optional staging-only workspace pack preserves its extracted directory and selected project pin.
- **AC-05** Workspace advance updates selected pin to the verified package, retains the registered directory path and deletes only that selected extracted directory, with no new directory copy.
- **AC-06** Next workspace unpack restores the updated pinned package into the same directory path. Other packages, pins and working directories remain unchanged.
- **AC-07** CLI help, README, NuGet README, specs and release metadata document the actual behavior without suggesting in-place continuous editing after pack.
- **AC-08** Real native installed Windows x64 CLI and independent .NET PackageReference consumer pass lifecycle/bytes checks. No publication.
- **ART-01** Evidence is criterion-specific, recorded truthfully, and implementation-branch receipts are not reused for final release qualification.

## Distinct evidence cases

| Case | Acceptance | Proof |
|---|---|---|
| EC-01 | AC-01 | Initial pack source survives |
| EC-02 | AC-02 | Package valid, extraction absent, history in package |
| EC-03a | AC-03 | No-op, invalid output, collision preserve extraction |
| EC-03b | AC-03 | Post-publish changed-file and cleanup-failure retain package and report state |
| EC-04 | AC-04 | Staging-only pack preserves member baseline/pin/dir |
| EC-05 | AC-05 | Selected pin updated and no second directory created |
| EC-06 | AC-06 | Re-unpack creates clean selected directory; other member unchanged |
| EC-07 | AC-07 | Authored help equals CLI; public docs consistent |
| EC-08 | AC-08 | Installed native and consumer proof |

## Validation gates

| Gate | Required execution |
|---|---|
| VAL-01 | Focused xUnit package and project-workspace integration |
| VAL-02 | Full `dotnet test DotnetNugetContent.sln -c Release --no-restore` |
| VAL-03 | `pwsh -NoProfile -File scripts/validate-native.ps1` |
| VAL-04 | `pwsh -NoProfile -File scripts/validate-tool.ps1` and consumer byte comparison |
| VAL-05 | Doc/help parity, `git diff --check`, AC/EC/VAL reconciliation |

Do not execute full validation prematurely; focused checks during implementation, complete gates at completion. Requalify the 2.0.0 release candidate only after the final merge.
