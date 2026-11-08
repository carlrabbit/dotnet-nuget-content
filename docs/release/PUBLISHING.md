# 2.0.0 candidate preparation and publication boundary

The release consists only of the NuGet .NET tool package `dotnet-nuget-content` 2.0.0 and its `dotnet-nuget-content.win-x64` Native AOT package 2.0.0. Windows x64 is the only supported distribution target. There is no standalone binary, other RID package, or GitHub Release.

## Prepare a local candidate

Run from a clean intended source commit on the existing authorized Windows x64 Native AOT host:

```powershell
pwsh -NoProfile -File eng/publish.ps1 -Prepare
```

Preparation is offline/local with respect to package feeds. It does not publish. It creates two immutable `.nupkg` files, a versioned `candidate.json`, SHA-256 values, toolchain and source provenance, validation logs, and a human checklist. Existing output directories are never replaced. Preparation on an implementation branch produces **preliminary** evidence only. The release candidate is authoritative only when freshly prepared and fully validated from a clean final merged `main` commit. Any source change after that run requires full requalification.

The candidate must pass both installed-tool installation modes and the M0001–M0007 regression lifecycle, independent local-feed consumer byte checks, the reproducible 100-project/10-package scale gate, release mock-publication checks, dependency audit, and release metadata checks. Candidate report and log hashes bind those results to the exact source commit, SDK/compiler, command and package bytes. The prepared directory is read-only; do not rebuild or edit its files.

## Publication controls

- Default invocation and `-Prepare` build local packages and never contact or push to NuGet.org.
- `-TestPublish` uses synthetic local packages and mocked push delegates. It checks RID-first ordering, stop-on-failure behavior at both push points, partial-state reporting, wrong-feed and wrong-confirmation rejection, hash tampering, and that no API key is emitted or persisted.
- Real `-Publish` is outside release qualification and was not invoked. It requires an explicitly supplied exact NuGet.org endpoint and confirmation phrase, a final-merged-source candidate receipt, passing and hash-verified validation receipts, exact package identities and hashes, and an unpublished candidate. It rechecks each package hash immediately before pushing.
- The win-x64 package is pushed first. The top-level pointer is pushed only after that push succeeds. A failed first push holds the pointer; a failed second push reports the RID package as the only package reported accepted. Recovery uses the unchanged files from the same candidate, never a rebuild.
- `NUGET_API_KEY` must be supplied through an external secure source only for a separately authorized publication invocation. It is never written to the candidate or logs.

The human operator must review `candidate.json`, all receipts, package metadata and the checklist, confirm ownership and publication rights, and separately authorize any real NuGet.org push. Candidate qualification does not itself authorize publication.

## M0008 qualification status

Implementation-branch validation is preliminary. After merge, run `eng/publish.ps1 -Prepare` on the clean merged `main` commit and retain that exact candidate and its receipts. Do not report 2.0.0 release qualification until the final merged-commit gates pass. No package or GitHub release is published by preparation.
