# dotnet-nuget-content

**Immutable content packages for .NET projects.** Package arbitrary datasets, test assets or other files into a versioned NuGet snapshot. Unpack into a managed workspace, inspect file changes, repack at a higher version, and consume the payload through ordinary `PackageReference`.

**Windows x64 only.** Native AOT .NET tool; .NET CLI/SDK is required for installation.

## Install

```powershell
dotnet tool install --global dotnet-nuget-content --version 1.0.0
```

## Use

Start with an example file and a local package feed:

```powershell
New-Item -ItemType Directory -Force ./assets, ./feed | Out-Null
Set-Content -LiteralPath ./assets/example.txt -Value 'Example content'
dotnet-nuget-content pack --id example.assets --version 1.0.0 --source ./assets --output ./feed/example.assets.1.0.0.nupkg
dotnet-nuget-content unpack --package ./feed/example.assets.1.0.0.nupkg --destination ./working-copy
dotnet-nuget-content status --source ./working-copy
```

After editing the working copy:

```powershell
Set-Content -LiteralPath ./working-copy/example.txt -Value 'Updated content'
dotnet-nuget-content pack --source ./working-copy --version 1.1.0 --output ./feed/example.assets.1.1.0.nupkg
```

The new package is written to `./feed` as requested. Without `--output`, it would appear beside the workspace. The workspace baseline is unchanged.

The installed `dotnet-nuget-content` tool and the generated `example.assets` content package are **different NuGet packages**. To consume `example.assets` in a .NET project:

```powershell
dotnet new console -o ./consumer
dotnet add ./consumer package example.assets --version 1.1.0 --source ./feed
dotnet build ./consumer
```

The generated project contains a `PackageReference` to `example.assets`, and its content files are copied to build output with relative paths preserved. The `--source` option above uses the local feed without adding it to the user's persistent NuGet configuration.

Use `status --json` and `history --json` for automation. The tool supports trusted content only; there is no cross-platform release or standalone executable download.

[Complete documentation and source](https://github.com/carlrabbit/dotnet-nuget-content)
