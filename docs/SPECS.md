# Product specification

## Purpose

Manage arbitrary, long-lived content—especially test data and external binary tools—through immutable NuGet packages. Consumers use ordinary NuGet content-file restore/copy behavior. Package editing is an enabling operation.

## Scope and invariants

- A content package is a complete versioned snapshot. Never silently overwrite the same published package ID/version.
- Default package layout uses `contentFiles/any/any/<relative-content-path>`, with `.nuspec` `contentFiles` declaration selecting `buildAction=None`, `copyToOutput=true`, `flatten=false`.
- Preserve relative directories and binary bytes exactly. Reject unsafe archive paths (absolute, traversal, escapes) and duplicate/conflicting entries.
- **Supported input trust boundary:** package inputs are trusted packages from known/controlled sources. Processing adversarial or untrusted packages is outside the supported product contract. This does not relax the required path-safety, duplicate/conflict, no-overwrite, or malformed-input failure behavior.
- Ordinary workflows require no manifest. Optional configuration/hash expectations may be supported later, without making it a dependency for basic usage.
- CLI is noninteractive for automation, with deterministic exit behavior and clear stdout/stderr ownership. Input paths are resolved relative to invocation working directory unless explicitly stated otherwise.
- Existing package versions remain immutable; repacking a modified working directory produces a new version.
- Operate without a installed managed .NET runtime when using the native binary. Embedded packaging is preferred to avoid relying on SDK CLI compatibility.

## Initial M0001 vertical slice

- Provide discoverable `--help` and `--version`.
- Provide a minimal package creation and extraction surface, with explicit package identity/version, input directory, `.nupkg` output and extraction destination; select final command spellings during implementation only if they preserve these semantics and are documented/tested.
- Include integrity computation/verification for files and package-level expected hashes where provided.
- Generate a consumable `contentFiles` NuGet package; verify with an isolated consuming .NET project rather than assuming ZIP validity alone.
- Create native AOT publication and execute the published executable.
- NuGet.Packaging is the preferred backend. If Native AOT compilation or end-to-end runtime behavior is not viable with reasonable fixes, pivot the packaging backend to the .NET 11 SDK `dotnet pack` command, while keeping the CLI itself Native AOT. Report the capability/dependency compromise explicitly.

## Out of scope for M0001

Publishing to remote feeds, automatic NuGet restore, complex configuration/manifest lifecycle, global artifact cache, diff/history, mutation orchestration, Git-like operations, signing, credentials, NuGet dependency graphs, arbitrary third-party nupkg preservation, and production-grade support for every OS/RID.
