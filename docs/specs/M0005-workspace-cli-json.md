# Project workspace CLI JSON v1

Workspace JSON output is separate from the legacy M0003 status/history JSON contract. Every output is one compact UTF-8 JSON object and newline on stdout. Errors that prevent a command from producing a result use stderr and existing exit codes (2 for usage, 1 for operation/integrity failures). Paths are project-root-relative with `/` separators. Arrays are always present and ordered by ordinal relative path or case-insensitive alias followed by ordinal alias.

## `workspace list --json`

`schemaVersion: 1`, `kind: "workspaceList"`, and `members`, each containing `alias`, `packageId`, `version`, `packageFile`, `directory`, and `directoryPresent`.

## `workspace status --json`

`schemaVersion: 1`, `kind: "workspaceStatus"`, and per-member results with `alias`, `packageId`, `version`, and `state`. State is `missing`, `clean`, `modified`, `corrupt`, or `mismatched`. `added`, `modified`, and `deleted` are path arrays. `error` appears only for corrupt or mismatched members. Missing is a normal unpacked state.

## `workspace usage --json`

`schemaVersion: 1`, `kind: "workspaceUsage"`, `members`, and `diagnostics`. Each member has `alias`, `packageId`, `useSites`, `centralVersionDeclarations`, and `previousAssetsEvidence`. Use-site classifications distinguish direct references with literal, centrally managed, unresolved, or dynamic versions. A `Directory.Packages.props` declaration appears separately as `centralVersionDeclarationNotUseByItself` and is not reported as use on its own. Asset entries are evidence from a previous restore with unknown freshness, never a current dependency claim.
