# M0009 execution ledger — current PR #10 amendment

**State: IMPLEMENTED IN BRANCH / VALIDATION NOT YET EXECUTED AFTER AMENDMENT.**

The previously reported 37 passing xUnit tests and native executable/package hashes belong to the earlier *in-place baseline advancement* implementation and **must not be reused** as evidence for this changed deletion lifecycle.

| Criterion | State | Implementation/evidence needed |
|---|---|---|
| AC-01 | pending validation | Initial pack source preserved |
| AC-02 | pending validation | Real immutable package; deleted extracted directory |
| AC-03 | pending validation | Failed pack/no-op retains source; post-publication mutation and cleanup failure |
| AC-04 | pending validation | Workspace pack unchanged staging-only behavior |
| AC-05 | pending validation | Workspace advance pin update, no duplicate working directory, cleanup |
| AC-06 | pending validation | Re-unpack pinned version and independent member check |
| AC-07 | source review pending | README, NuGet README, authored CLI help, release contract |
| AC-08 | pending Windows gate | Native AOT CLI and independent consumer |
| ART-01 | pending final audit | No prior receipts treated as final |

| Case | State |
|---|---|
| EC-01 | pending |
| EC-02 | pending |
| EC-03a | pending |
| EC-03b | pending |
| EC-04 | pending |
| EC-05 | pending |
| EC-06 | pending |
| EC-07 | pending |
| EC-08 | pending |

| Gate | State | Notes |
|---|---|---|
| VAL-01 | not executed | Changed unit and integration tests |
| VAL-02 | not executed | No dotnet SDK in authoring environment |
| VAL-03 | not executed | Requires authorized Windows x64 Native AOT host |
| VAL-04 | not executed | Requires authorized Windows x64 installed tool/consumer host |
| VAL-05 | incomplete | Docs/source alignment underway |

No publishing, release approval or final merged-source qualification is claimed.
