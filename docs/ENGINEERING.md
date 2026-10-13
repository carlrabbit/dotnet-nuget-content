# Engineering and validation contract

## Runtime and packaging

- Build target: `net11.0`, .NET 11 RC baseline SDK `11.0.100-rc.1`; upgrade only with recorded compatibility evidence. Native AOT is mandatory for the initial delivery.
- Primary package writer/reader: `NuGet.Packaging`; use existing NuGet mechanisms for correct `.nuspec`, `contentFiles`, ZIP metadata where feasible.
- Fallback packaging backend: invoke .NET SDK `dotnet pack` with generated `.nuspec` only when the preferred backend is not viable under Native AOT. The CLI remains native, but the fallback requires a compatible SDK for package operations; do not conceal this prerequisite.
- Avoid unnecessary dependencies. Treat trim/AOT diagnostics and actual runtime behavior as release gates, not a compile-only check. `PublishAot` implies trimming; optimize size only after correctness.
- Target initial native publish/validation on `win-x64` and `linux-x64` where build infrastructure permits. M0001 requires at least one real native publish and invocation; unsupported target environments must be reported, not fabricated.

## CLI process behavior

- Non-interactive commands; `--help`/`--version` work without an SDK and return success.
- On success return exit code 0; on malformed input, integrity mismatch, unsafe paths, and package errors return nonzero with actionable stderr. Do not write progress/diagnostics into machine-readable stdout.
- Never silently delete/overwrite existing user files. Package output creation and extraction should use safe temporary staging or detect conflicts before making changes. Cleanup after failure.
- Treat path case/normalization and traversal protection as platform-sensitive. Reject Zip Slip payloads and symlink escapes where relevant.
- No network access or feed credentials are needed for the first slice.

## Required validation approach

- Test actual package creation and extraction using nontrivial nested text and binary fixtures, checking byte-for-byte content and computed hashes.
- Test invalid identities/versions, duplicate entries, malicious archive paths, mismatched hash, existing destination protection and actionable failures.
- Pack an actual consumer project referencing the newly produced `.nupkg` through an isolated local feed; `dotnet restore` and `dotnet build` must copy expected content into its output preserving relative paths. Use .NET 11 SDK for this external consumer; this does not weaken the requirement that the primary native tool itself work without the SDK at run time.
- Publish and execute actual Native AOT release artifact (not merely `dotnet run`); record size, AOT/trim warnings and exit behavior.
- Treat consumer boundary failures as product defects. No test containers required. Validation evidence should be attached individually to milestone/ledger obligations.

## M0001 implementation profile

- The CLI project is `src/DotnetNugetContent/DotnetNugetContent.csproj`, targets `net11.0`, and enables `PublishAot`.
- The preferred backend is implemented with `NuGet.Packaging` 7.9.0. `NuGet.Packaging` creates packages with `contentFiles/any/any/<relative-path>` entries and `buildAction=None`, `copyToOutput=true`, `flatten=false`; `PackageArchiveReader` reads packages for extraction.
- Commands are `pack`, `unpack`, and `hash`; the exact options and exit behavior are documented in the root README and discoverable through `--help`.
- Focused CLI and package lifecycle validation is `dotnet test --configuration Release`. The independent PackageReference boundary check is `pwsh -NoProfile -File scripts/validate-consumer.ps1`.
- AOT publication is RID-specific. For example, Windows x64 uses `dotnet publish src/DotnetNugetContent/DotnetNugetContent.csproj -c Release -r win-x64 --self-contained true -o artifacts/win-x64`. It requires the .NET 11 RC SDK and native compiler/linker prerequisites on the selected build host.

## Distribution boundary

Initial milestone proves a standalone native binary; standard .NET tool packaging is a potential later deliverable and not required in M0001. No reusable .NET library API is promised.
