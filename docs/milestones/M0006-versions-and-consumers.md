# M0006 — Version increments and consumer reference synchronization

## Execution profile

| Field | Value |
|---|---|
| Lifecycle state | ready |
| Execution mode | ai-executed-human-reviewed |
| Baseline implementation model | project default |
| Affected role | developer-facing CLI (not agent-specific) |
| Applicable guide scope | repository base + cli-tool, existing project specialization |
| Environment | existing authorized Windows x64 .NET 11 SDK + Native AOT |
| Test framework | retain existing xUnit; TUnit migration deferred |
| Execution ledger | `.execution/M0006-versions-and-consumers.md` |
| Human review | required PR review, no release or publication authorization |

## Goal / target state

Two coherent developer conveniences: increment package versions semantically while preserving immutable package semantics; preview/apply a safe update of supported local consuming project references, validated by real restore/build and package-output byte checks.

## Operative contract and decisions

`docs/specs/M0006-versions-and-consumers.md` is normative. The following are fixed: `--major|--minor|--patch|--version` exclusive, only managed pack supports increments, stable three-numeric-component baseline, no prerelease relative increment; reference updates default to preview and require explicit `--apply`; default target is *pinned* workspace version, explicit target needs verified local package; central references updated in their authoritative props file; ambiguous/dynamic/conditional sources are blocked rather than guessed; no implicit pin updates, feeds, restores, publication, project-format churn or new runtime. Preserve prior public contracts and independent package membership.

## Scope / exclusions

Scope: managed and workspace pack parsing/calculation, version documentation, `workspace references update`, bounded discovery/plan, conservative XML edits, versioned JSON output specification/schema, developer-facing help/README and real-package/consumer validation.

Exclude: 100-project scale qualification (defer to 2.0 release), automatic upgrades from pack/set, project reference creation/deletion, import graph evaluation, cross-repository usage index, feed download, NuGet.Config edits, automatic restore in product, cross-platform/CoreCLR, TUnit migration, changes to published manifest v1 and legacy JSON contracts, host installation/CI/public publication.

## Required authority

- `AGENTS.md`, `docs/SPECS.md`, `docs/ENGINEERING.md`, `docs/MILESTONES.md`
- `docs/specs/manifest-v1.md` and schema, `docs/specs/M0003-cli-json.md`
- `docs/specs/M0005-project-workspace.md` and schema, `docs/specs/M0005-workspace-cli-json.md` and schema
- `docs/specs/M0006-versions-and-consumers.md`
- Existing CLI, xUnit tests, and `scripts/validate-tool.ps1` for verified mechanics

## Acceptance criteria

- **AC-01** — Managed single-package and workspace pack accept mutually exclusive major/minor/patch/explicit-version selection and produce precisely calculated, normalized stable versions without changing initial pack behavior.
- **AC-02** — Real packages have consistent filename/nuspec/manifest/history and immutable existing workspace/root-pin semantics; invalid/unchanged/prerelease/conflicting/overflow/collision cases leave no final artifact or modified baseline.
- **AC-03** — `workspace references update` previews exact local target files, old/new versions and blockers without filesystem mutation; default version is pinned, explicit version requires verified local same-ID package.
- **AC-04** — Applying a supported plan updates literal direct references and central `PackageVersion` declarations correctly, without changing unrelated files, central-version-only unused declarations or workspace pins.
- **AC-05** — Ambiguous/dynamic/conditional/imported/malformed references are conservatively reported and prevent partial intentional updates; changed-source preflight and handled I/O failures preserve or recover original file contents with truthful partial-state diagnostics.
- **AC-06** — Reference-update JSON is versioned, documented, schema-valid and deterministic; CLI usage/help, README and NuGet README clearly explain dry-run vs apply and local-feed requirements without implying automatic restore.
- **AC-07** — Installed Windows x64 Native AOT tool completes a two-package, multi-project lifecycle using relative pack, explicit safe pin transition, reference preview/apply, independent local NuGet restore/build and exact content-byte comparison; second package and old snapshots unchanged.
- **AC-08** — Existing single-package, workspace JSON/public manifest and Windows Native AOT distribution behavior remain compatible; no CI, network/product-restore, test framework migration or public publication introduced.
- **ART-01** — Execution ledger records criterion-specific evidence, distinct cases and all gates, with final reconciliation and truthful status.

## Distinct evidence cases

| ID | Parent | Case |
|---|---|---|
| EC-01a | AC-01 | Stable major/minor/patch, zero-leading major, explicit version, parser exclusivity |
| EC-01b | AC-01 | Prerelease/build metadata, abnormal component count, overflow rejection |
| EC-02a | AC-02 | Actual package bytes/manifest/history and untouched baseline/pin |
| EC-02b | AC-02 | Unchanged/collision/invalid-output failure leaves existing data intact |
| EC-03a | AC-03 | Preview only, pinned default and local verified explicit override |
| EC-04a | AC-04 | Direct attribute/element and multiple projects; unrelated reference preserved |
| EC-04b | AC-04 | Shared central props updates once; unused central declaration unchanged |
| EC-05a | AC-05 | Dynamic/conditional/imported/duplicate and malformed file no-write |
| EC-05b | AC-05 | Changed file and handled mid-write failure; recovery/partial disclosure |
| EC-06a | AC-06 | Versioned JSON schema, text/help/README semantics |
| EC-07a | AC-07 | Installed Native AOT full lifecycle, independent actual consumer byte oracle |
| EC-08a | AC-08 | Legacy command and JSON contract regression; test framework stays xUnit |

## Validation gates

| ID | Depth | Command/check | Locus | Proves | Evidence |
|---|---|---|---|---|---|
| VAL-01 | Unit/contract | `dotnet test DotnetNugetContent.sln -c Release --no-restore`, targeted version/parser tests | Windows x64 .NET 11 | EC-01a/b, AC-01 | Test summary and asserted output table |
| VAL-02 | Integration | Real managed pack and package inspection using NuGet APIs, negative failure paths | Windows temp files | EC-02a/b, AC-02 | Package/version/sha receipts and preservation assertions |
| VAL-03 | Integration | Temporary real SDK projects, XML preview/apply/error and schema tests | Windows local fixture, no network | EC-03a, EC-04a/b, EC-05a/b, EC-06a | Before/after bytes, preview plans, failure results |
| VAL-04 | Installed product | `pwsh -NoProfile -File scripts/validate-tool.ps1`, expanded installed workflow and local feed restore/build | Authorized Windows x64 Native AOT | EC-07a, EC-08a, AC-07/08 | Exact executable/tool package SHAs, output bytes and test transcript |
| VAL-05 | Audit | Ledger ID reconciliation, docs + contract review, `git diff --check` | Repository and local receipts | ART-01, AC-06/08 | Criterion-specific completion record |

## Documentation / sync

Update `docs/SPECS.md` with M0006 capabilities; update `docs/MILESTONES.md`, CLI root/workspace help, GitHub README, NuGet README. Add versioned public JSON schema and documentation for reference-update result. Preserve existing installation instructions and 1.0-only release metadata until a separate 2.0 release milestone; do not claim published 2.0.

## Execution and review

Use the existing host and test framework; implementation owns code and test mechanics. Run focused tests iteratively; run full expensive installed-tool gate after implementation settles, then reconcile ledger and completion evidence. No artificial scale benchmark. PR requires human review of source rewriting and failure preservation before merge. Cross-file edits are not promised crash-atomic. Escalate any need to relax ambiguity rejection, allow imported MSBuild evaluation, introduce network, change public schemas outside this new interface, or choose a new versioning convention.

## Completion Evidence

Pending implementation. Record real Windows gate outputs, artifacts, source commit, and criterion-specific evidence here before marking done.
