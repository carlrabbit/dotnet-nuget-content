# Root CLI help — 2.0.0 authored copy

This is the authored root help contract for the installed CLI. Keep the fenced output synchronized with `Cli.HelpText` and the installed-tool validation check.

```text
dotnet-nuget-content 2.0.0 — immutable NuGet packages for arbitrary files (Windows x64 only)

Usage:
  dotnet nuget-content --help
  dotnet nuget-content --version
  dotnet nuget-content pack --id <id> --version <version> --source <dir> --output <file.nupkg>
  dotnet nuget-content pack (--version <version> | --major | --minor | --patch) [--source <workspace>] [--output <file.nupkg>] [--message <text>]
  dotnet nuget-content unpack --package <file.nupkg> --destination <dir> [--sha256 <hash>]
  dotnet nuget-content status [--source <workspace> | --package <file.nupkg>] [--json]
  dotnet nuget-content history [--source <workspace> | --package <file.nupkg>] [--json]
  dotnet nuget-content hash --path <file> [--expect <hash>]

Workflow:
  First package: pack --id ... --version ... --source ... --output ...
  Update: unpack into a folder, edit files there, pack --patch; extraction removed after success
  Inspect: status and history; add --json for structured output.

  Managed status, history and pack use the current directory by default; they
never search parent directories. Managed pack needs changes and a higher
version. Relative --major/--minor/--patch use the stable baseline version.
Without --output it writes beside the extracted directory. Successful ordinary
managed pack removes that directory after verifying the immutable package.
Workspace pack stages a package only; workspace advance updates the project
pin and removes its extracted member directory. Unpack again to edit later.
Existing output files and extraction destinations are not replaced.

Exit codes: 0 success, 1 operation/integrity error, 2 usage error.
Errors are written to stderr.

Project workspaces:
  dotnet nuget-content workspace --help
  dotnet nuget-content workspace init|add|list|unpack|status|pack|advance|set|usage|inspect|cleanup|references
```
