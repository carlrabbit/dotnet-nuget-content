# M0004 release and human approval boundary

Target publishing feed is **NuGet.org only**, exclusively as the top-level `.NET tool` and matching `win-x64` RID-specific Native AOT NuGet package. No GitHub Release, downloadable binaries, alternative installers, or CI workflow changes.

Build exact `1.0.0` candidate on existing authorized Windows x64 AOT toolchain from clean identified source. Produce both `.nupkg` files, SHA-256 receipts, NuGet metadata and README inspection, local-feed installed-tool tests, full managed snapshot + isolated independent PackageReference consumer. Record source revision and toolchain. A qualified release candidate must be immutable; publishing must use **identical files**, not rebuild them.

Implement repository-owned `eng/publish.ps1` (PowerShell) as a conventional operator-facing script, conceptually similar to `carlrabbit/yadg`. Planning could not verify the exact yadg implementation path; inspect its live scripts if accessible, but do not let resemblance override the following contract.

- Default command and explicit `-Prepare` mode cannot contact/publish to nuget.org.
- `-Publish` is a distinct explicit opt-in, accepts only an already qualified candidate directory/manifest with exact SHA-256 checks and version, and requires an unambiguous human confirmation of nuget.org target. No publishing invocation during M0004 implementation or testing.
- Publish RID-specific `.nupkg` **first**, then top-level pointer `.nupkg`. Failure of RID push stops immediately; partial publication is reported honestly with exact recovery guidance. No silent `--skip-duplicate` masking failed or mismatched package identity.
- Do not print, hardcode, persist or commit secrets. Read API key from an external secure source only at human-authorized invocation time; avoid insecure command-line exposure when supported by tooling.
- Provide testable dry-run/mocked push traces proving ordering, refusal, failure paths, wrong feed, missing approval and hash mismatch without real NuGet.org credentials.
- No implicit new CI infrastructure, tool provisioning, machine configuration changes, or production release execution.
- Output a durable candidate report containing exact Git SHA, SDK/compiler, version, package IDs/paths/hashes, installed command validation and consumer evidence, and a separate human publication checklist.
- Public release **is not part of M0004's completion**. Completion state means candidate qualified and manual publication tool ready; subsequent human approval is required.
