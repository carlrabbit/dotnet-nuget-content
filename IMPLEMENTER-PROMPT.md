# EXECUTE — M0008 2.0.0 release qualification

Repository: `carlrabbit/dotnet-nuget-content`.
Handoff: `G:\My Drive\Transfer\M0008-release-qualification.zip`.

Start from current `main` on a new M0008 implementation branch. Extract archive into repository root preserving relative paths. Read `docs/milestones/M0008-release-qualification.md`, `.execution/M0008-release-qualification.md`, the normative `docs/specs/M0008-release-qualification.md` and referenced repository authority. Implement milestone only, keeping current xUnit framework.

Update the tooling and release preparation to 2.0.0, qualify installed Windows x64 Native AOT exact package artifacts and real NuGet consumers, run specified 100-project/10-package scale qualification and negative safety gates, and reconcile criterion-by-criterion evidence. Keep `-Publish` uninvoked and all public publication separately human authorized. No CI, host provisioning, new features or platform expansion.

IMPORTANT: A pre-merge PR can supply preliminary implementation evidence only. Final authoritative 2.0.0 release qualification must run from clean **final merged source commit**, with artifact hashes, installed validation and release report bound to that commit. Never claim release qualification before it. Open a PR against main; report PR, tests, candidate status, unfulfilled post-merge gate and any blockers.
