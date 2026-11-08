# 2.0.0 candidate preparation and publication boundary

The release consists only of the NuGet .NET tool package `dotnet-nuget-content` 2.0.0 and its `dotnet-nuget-content.win-x64` Native AOT package 2.0.0. Windows x64 is the only supported distribution target. There is no standalone binary, other RID package, or GitHub Release.

## Prepare a local candidate

Run from a clean source commit on the existing authorized Windows x64 Native AOT host. A normal implementation-branch preparation is preliminary:

```powershell
pwsh -NoProfile -File eng/publish.ps1 -Prepare
```

Preparation is offline/local with respect to package feeds. It does not publish. It creates two immutable `.nupkg` files, a versioned `candidate.json`, SHA-256 values, toolchain and source provenance, validation logs, and a human checklist. Existing output directories are never replaced. Preparation on an implementation branch produces **preliminary** evidence only. The release candidate is authoritative only when freshly prepared and fully validated from a clean final merged `main` commit. Any source change after that run requires full requalification.

Final qualification must be run on `main` with the intended full commit SHA explicitly supplied by the operator:

```powershell
pwsh -NoProfile -File eng/publish.ps1 -Prepare -ExpectedReleaseCommit <full-merged-commit-sha>
```

The script requires that SHA to match current `HEAD`, confirms `main`, a clean worktree, and the source tree for that commit, then records expected and actual commit identity in `candidate.json`. Omitting the expected SHA—even on `main`—produces preliminary evidence only. A dirty worktree or mismatched SHA is rejected. Preparation performs these checks locally without contacting GitHub.

Every candidate preparation runs the complete existing Release regression suite with `dotnet test DotnetNugetContent.sln -c Release --no-restore` and saves `regression-tests.log` in the candidate directory. A nonzero test result stops preparation. The candidate report records the passing status and SHA-256; publication rechecks this receipt with all other validation logs. Missing, failed, or changed regression evidence blocks publication. The complete suite is required in addition to installed-tool, Native AOT, independent consumer-byte, reproducible 100-project/10-package scale, publishing mock, dependency, and metadata checks. Candidate report and receipt hashes bind those results to source commit, SDK/compiler, command and package bytes. The prepared directory is read-only; do not rebuild or edit its files.

## Publication controls

- Default invocation and `-Prepare` build local packages and never contact or push to NuGet.org.
- `-TestPublish` uses synthetic local packages and mocked push delegates. It checks RID-first ordering, stop-on-failure behavior at both push points, partial-state reporting, wrong-feed and wrong-confirmation rejection, hash tampering, and that no API key is emitted or persisted.
- Real `-Publish` is outside release qualification and was not invoked. It requires an explicitly supplied exact NuGet.org endpoint and confirmation phrase, a final-merged-source candidate receipt with expected/source/current full commit identities matching the same clean local `main` checkout, passing and hash-verified regression and other validation receipts, exact package identities and hashes, and an unpublished candidate. It rechecks each package hash immediately before pushing.
- The win-x64 package is pushed first. The top-level pointer is pushed only after that push succeeds. A failed first push holds the pointer; a failed second push reports the RID package as the only package reported accepted. Recovery uses the unchanged files from the same candidate, never a rebuild.
- `NUGET_API_KEY` must be supplied through an external secure source only for a separately authorized publication invocation. It is never written to the candidate or logs.

The human operator must review `candidate.json`, all receipts, package metadata and the checklist, confirm ownership and publication rights, and separately authorize any real NuGet.org push. Candidate qualification does not itself authorize publication.

## M0008 qualification status

Implementation-branch validation is preliminary. After merge, identify the intended merged `main` SHA and pass that exact full SHA to `-ExpectedReleaseCommit`; retain the candidate and its receipts. Do not report 2.0.0 release qualification until the full regression receipt, all other gates, and final merged-commit identity checks pass. No package or GitHub release is published by preparation.
