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

## Final merged-source qualification

The M0004 implementation-branch candidate is **pre-merge evidence**, not automatically the final public release candidate. After PR merge and before requesting publication approval, run `eng/publish.ps1 -Prepare` again on the clean, intended final merged release commit using the authorized Windows x64 toolchain. Verify that the resulting `candidate.json` records that exact commit and that both newly created packages pass the complete installed-tool/consumer and mock-publishing gates. Keep these exact files, their SHA-256 values and receipts together; submit them for human approval. Only these approved bytes may be published, without rebuilding in `-Publish` mode. A further source change requires fresh qualification and approval.

Dry-run publication checks cover both failure points. If the RID push fails, record no successful package, check NuGet.org for ambiguous acceptance of the RID package before retrying, and hold the top-level pointer. If the RID push succeeds and the pointer push fails, record the RID package as accepted and the pointer as failed; verify the RID package on NuGet.org, then publish the unchanged pointer from the same candidate without rebuilding.
