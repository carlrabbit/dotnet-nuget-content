# Terminology

- **Content package:** A NuGet `.nupkg` with arbitrary files distributed as `contentFiles`; it is not a conventional assembly library.
- **Snapshot:** A complete immutable content package identified by package ID and exact version.
- **Working directory:** Extracted, editable copy of content from a package; it is not source control.
- **Package backend:** Mechanism used to read and create valid content packages; preferred embedded `NuGet.Packaging`, fallback .NET SDK CLI.
- **Consumer:** A separate .NET project referencing a generated content package with `PackageReference`.
- **Native artifact:** A published Native AOT standalone executable, not a managed build output.
- **Integrity:** Per-file SHA-256 and, where an expected value is provided, full `.nupkg` SHA-256 comparison. A hash without trusted expected value is informative, not authentication.
