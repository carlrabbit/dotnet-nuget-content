Implement M0005 in `carlrabbit/dotnet-nuget-content` following project authority.

From current main, create a new feature branch and PR. Extract this package into the repository root, preserving paths. Read `AGENTS.md`, `docs/milestones/M0005-project-workspaces.md`, `docs/specs/M0005-project-workspace.md`, the seeded `.execution/M0005-project-workspaces.md`, and referenced project specifications.

Implement the project-integrated multi-package workspace and on-demand usage discovery; maintain existing v1 commands, manifest v1, Windows x64 Native AOT distribution and JSON contracts. No cross-platform/CoreCLR work, feeds, publishing, CI changes, host installs or automatic package upgrades.

Own implementation work packages and actual test mechanics. Keep the obligation/evidence ledger current; run the required Windows integration and installed-tool gates before claiming completion. Push a PR containing results and execution evidence. Escalate only substantive contract conflicts; do not make new product decisions.
