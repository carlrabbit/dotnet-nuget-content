# dotnet-nuget-content

**Immutable content packages for .NET projects.** Package arbitrary datasets, test assets or other files into a versioned NuGet snapshot. Unpack into a managed workspace, inspect file changes, repack at a higher version, and consume the payload through ordinary `PackageReference`.

**Windows x64 only.** Native AOT .NET tool; .NET CLI/SDK is required for installation.

## Install

```powershell
dotnet tool install --global dotnet-nuget-content --version 1.0.0
```

## Use

```powershell
dotnet-nuget-content pack --id example.assets --version 1.0.0 --source ./assets --output ./example.assets.1.0.0.nupkg
dotnet-nuget-content unpack --package ./example.assets.1.0.0.nupkg --destination ./working-copy
dotnet-nuget-content status --source ./working-copy
```

After editing the working copy:

```powershell
dotnet-nuget-content pack --source ./working-copy --version 1.1.0
```

The new package appears beside the workspace. Its baseline is not changed. Add the generated package to a .NET project:

```xml
<PackageReference Include="example.assets" Version="1.1.0" />
```

Use `status --json` and `history --json` for automation. The tool supports trusted content only; there is no cross-platform release or standalone executable download.

[Complete documentation and source](https://github.com/carlrabbit/dotnet-nuget-content)
