# 2.0.0 NuGet public metadata contract

Public package ID `dotnet-nuget-content`, command `dotnet-nuget-content`, version `2.0.0`; matching Native AOT payload package `dotnet-nuget-content.win-x64`, also `2.0.0`. The top-level package points only to the `win-x64` Native AOT package. No `any` fallback, standalone binary, or other platform is supported.

Title: **dotnet-nuget-content — immutable content snapshots**

Description (exact): **Windows command-line tool for creating and maintaining immutable NuGet packages of arbitrary files. Supports versioned snapshots, workspace status, change history, SHA-256 verification, and JSON output. Generated packages integrate with ordinary .NET PackageReference consumers.**

Tags: `dotnet-tool nuget content files snapshots versioning nativeaot`

ProjectUrl / RepositoryUrl: `https://github.com/carlrabbit/dotnet-nuget-content`

Package README: `docs/nuget/README.md`; embed as NuGet readme, verify top-level and RID package metadata.

Release notes: **Windows x64 Native AOT 2.0.0 release. Immutable content snapshots, disposable unpack/edit/pack workspaces, managed multi-package workspaces with explicit pinning, bounded local usage discovery, consumer reference updates, coordinated advance and safe cleanup, public manifest v1, and ordinary PackageReference consumption.**

**Human-owned facts**: Inspect the repository LICENSE and actual author/owner. Do not invent a license or copyright owner. Set correct `PackageLicenseExpression` or `PackageLicenseFile`. If no verified distribution license exists, block release qualification and request a human decision. Do not silently create a new license.
