using System.Text.Json;

namespace DotnetNugetContent.Tests;

public sealed class ProjectWorkspaceTests : IDisposable
{
    private readonly string root = Path.Combine(Path.GetTempPath(), "dnc-project-" + Guid.NewGuid().ToString("N"));

    public ProjectWorkspaceTests() => Directory.CreateDirectory(root);

    [Fact]
    public async Task WorkspaceLifecycleKeepsIndependentPinsAndManagedBaselines()
    {
        var p1 = await Package("fixtures.pkg", "1.0.0", "fixture");
        var p2 = await Package("tools.pkg", "2.0.0", "tool");
        Assert.Equal(0, await Run(root, "workspace", "init"));
        var emptyMarker = await File.ReadAllBytesAsync(Path.Combine(root, "nuget-content.json"));
        Assert.Equal(1, await Run(root, "workspace", "add", "--alias", "missing", "--package", "feed/not-found.nupkg"));
        Assert.Equal(emptyMarker, await File.ReadAllBytesAsync(Path.Combine(root, "nuget-content.json")));
        Assert.Equal(0, await Run(root, "workspace", "add", "--alias", "fixtures", "--package", "feed/fixtures.pkg.nupkg"));
        Assert.Equal(0, await Run(root, "workspace", "add", "--alias", "tools", "--package", "feed/tools.pkg.nupkg"));
        Assert.Equal(0, await Run(root, "workspace", "list", "--json"));
        using (var list = JsonDocument.Parse(stdout))
        {
            Assert.Equal(2, list.RootElement.GetProperty("members").GetArrayLength());
            Assert.Equal("fixtures", list.RootElement.GetProperty("members")[0].GetProperty("alias").GetString());
        }

        Assert.Equal(0, await Run(root, "workspace", "unpack", "--all"));
        Assert.Equal(0, await Run(root, "workspace", "status", "--all", "--json"));
        using (var status = JsonDocument.Parse(stdout))
        {
            Assert.Equal("clean", status.RootElement.GetProperty("members")[0].GetProperty("state").GetString());
            Assert.Equal("clean", status.RootElement.GetProperty("members")[1].GetProperty("state").GetString());
        }
        var marker = await File.ReadAllBytesAsync(Path.Combine(root, "nuget-content.json"));
        await File.WriteAllTextAsync(Path.Combine(root, "content", "fixtures", "payload.txt"), "changed");
        Assert.Equal(0, await Run(root, "workspace", "status", "--alias", "fixtures", "--json"));
        using (var modified = JsonDocument.Parse(stdout))
        {
            Assert.Equal("modified", modified.RootElement.GetProperty("members")[0].GetProperty("state").GetString());
            Assert.Equal("payload.txt", modified.RootElement.GetProperty("members")[0].GetProperty("modified")[0].GetString());
        }
        var next = await Run(root, "workspace", "pack", "--alias", "fixtures", "--version", "1.1.0");
        Assert.Equal(0, next);
        var outputPackage = Path.Combine(root, "content", "fixtures.pkg.1.1.0.nupkg");
        Assert.True(File.Exists(outputPackage));
        Assert.Equal(marker, await File.ReadAllBytesAsync(Path.Combine(root, "nuget-content.json")));
        Assert.Contains("1.0.0", await File.ReadAllTextAsync(Path.Combine(root, "content", "fixtures", ".nuget-content", "manifest.json")));

        var beforeFailure = await File.ReadAllBytesAsync(Path.Combine(root, "nuget-content.json"));
        var oldWorkspaceContent = await File.ReadAllBytesAsync(Path.Combine(root, "content", "fixtures", "payload.txt"));
        var newPackageBytes = await File.ReadAllBytesAsync(outputPackage);
        var originalPackageBytes = await File.ReadAllBytesAsync(p1);
        var independentPackageBytes = await File.ReadAllBytesAsync(p2);
        Assert.Equal(1, await Run(root, "workspace", "set", "--alias", "fixtures", "--package", "content/fixtures.pkg.1.1.0.nupkg"));
        Assert.Equal(beforeFailure, await File.ReadAllBytesAsync(Path.Combine(root, "nuget-content.json")));
        Assert.Equal(oldWorkspaceContent, await File.ReadAllBytesAsync(Path.Combine(root, "content", "fixtures", "payload.txt")));
        Assert.Equal(newPackageBytes, await File.ReadAllBytesAsync(outputPackage));
        Assert.Equal(originalPackageBytes, await File.ReadAllBytesAsync(p1));
        Assert.Equal(independentPackageBytes, await File.ReadAllBytesAsync(p2));

        Assert.Equal(0, await Run(root, "workspace", "set", "--alias", "fixtures", "--package", "content/fixtures.pkg.1.1.0.nupkg", "--directory", "content/fixtures-1.1.0"));
        Assert.Equal(oldWorkspaceContent, await File.ReadAllBytesAsync(Path.Combine(root, "content", "fixtures", "payload.txt")));
        Assert.False(Directory.Exists(Path.Combine(root, "content", "fixtures-1.1.0")));
        Assert.Equal("fixtures", JsonDocument.Parse(await File.ReadAllTextAsync(Path.Combine(root, "nuget-content.json"))).RootElement.GetProperty("members")[0].GetProperty("alias").GetString());
        Assert.Equal(0, await Run(root, "workspace", "unpack", "--alias", "fixtures"));
        Assert.Equal("changed", await File.ReadAllTextAsync(Path.Combine(root, "content", "fixtures-1.1.0", "payload.txt")));
        Assert.Equal(0, await Run(root, "workspace", "status", "--alias", "fixtures", "--json"));
        using (var clean = JsonDocument.Parse(stdout)) Assert.Equal("clean", clean.RootElement.GetProperty("members")[0].GetProperty("state").GetString());
        Assert.Equal("tools", JsonDocument.Parse(await File.ReadAllTextAsync(Path.Combine(root, "nuget-content.json"))).RootElement.GetProperty("members")[1].GetProperty("alias").GetString());
    }

    [Fact]
    public async Task WorkspacePackRejectsMismatchedBaselineBeforeCreatingOutput()
    {
        await Package("sample.identity", "1.0.0", "identity");
        Assert.Equal(0, await Run(root, "workspace", "init"));
        Assert.Equal(0, await Run(root, "workspace", "add", "--alias", "identity", "--package", "feed/sample.identity.nupkg"));
        Assert.Equal(0, await Run(root, "workspace", "unpack", "--alias", "identity"));

        var marker = Path.Combine(root, "nuget-content.json");
        var original = await File.ReadAllTextAsync(marker);
        var baselinePath = Path.Combine(root, "content", "identity", ".nuget-content", "manifest.json");
        var baseline = await File.ReadAllBytesAsync(baselinePath);
        foreach (var (mismatchedPin, outputName) in new[]
        {
            (original.Replace("sample.identity", "sample.other", StringComparison.Ordinal), "wrong-id.nupkg"),
            (original.Replace("1.0.0", "1.1.0", StringComparison.Ordinal), "wrong-version.nupkg")
        })
        {
            await File.WriteAllTextAsync(marker, mismatchedPin);
            var output = Path.Combine(root, outputName);
            Assert.Equal(1, await Run(root, "workspace", "pack", "--alias", "identity", "--version", "1.2.0", "--output", output));
            Assert.False(File.Exists(output));
            Assert.Equal(baseline, await File.ReadAllBytesAsync(baselinePath));
            Assert.Equal("identity", await File.ReadAllTextAsync(Path.Combine(root, "content", "identity", "payload.txt")));
        }
        await File.WriteAllTextAsync(marker, original);
    }

    [Fact]
    public async Task WorkspaceRootValidationAndPartialUnpackNeverReplaceExistingContent()
    {
        using (var rootSchema = JsonDocument.Parse(await File.ReadAllTextAsync(Path.Combine(AppContext.BaseDirectory, "../../../../../docs/specs/M0005-project-workspace.schema.json"))))
        {
            Assert.Equal(new[] { "schemaVersion", "members" }, rootSchema.RootElement.GetProperty("required").EnumerateArray().Select(x => x.GetString()).ToArray());
            Assert.False(rootSchema.RootElement.GetProperty("additionalProperties").GetBoolean());
        }
        using (var outputSchema = JsonDocument.Parse(await File.ReadAllTextAsync(Path.Combine(AppContext.BaseDirectory, "../../../../../docs/specs/M0005-workspace-cli-json.schema.json"))))
            Assert.Equal(3, outputSchema.RootElement.GetProperty("oneOf").GetArrayLength());
        var package = await Package("sample.one", "1.0.0", "one");
        File.Copy(package, Path.Combine(root, "feed", "other.nupkg"));
        Assert.Equal(0, await Run(root, "workspace", "init"));
        Assert.Equal(0, await Run(root, "workspace", "add", "--alias", "one", "--package", "feed/sample.one.nupkg"));
        Assert.Equal(0, await Run(root, "workspace", "add", "--alias", "two", "--package", "feed/other.nupkg", "--directory", "content/two"));
        Directory.CreateDirectory(Path.Combine(root, "content", "two"));
        await File.WriteAllTextAsync(Path.Combine(root, "content", "two", "keep.txt"), "keep");
        Assert.Equal(1, await Run(root, "workspace", "unpack", "--all"));
        Assert.Contains("two: failed", stdout);
        Assert.Equal("keep", await File.ReadAllTextAsync(Path.Combine(root, "content", "two", "keep.txt")));
        Assert.True(Directory.Exists(Path.Combine(root, "content", "one")));

        var marker = Path.Combine(root, "nuget-content.json"); var old = await File.ReadAllBytesAsync(marker);
        await File.WriteAllTextAsync(marker, """{"schemaVersion":1,"members":[{"alias":"One","packageId":"sample.one","version":"1.0.0","packageFile":"feed/sample.one.nupkg","directory":"content/One"},{"alias":"one","packageId":"sample.one","version":"1.0.0","packageFile":"feed/other.nupkg","directory":"content/other"}]}""");
        Assert.Equal(1, await Run(root, "workspace", "list"));
        Assert.Empty(stdout);
        Assert.Contains("Duplicate workspace alias", stderr);
        await File.WriteAllBytesAsync(marker, old);
        Assert.Equal(1, await Run(root, "workspace", "add", "--alias", "nested", "--package", "feed/sample.one.nupkg", "--directory", "content/one/deep"));
        Assert.Equal(old, await File.ReadAllBytesAsync(marker));
        Assert.Equal(1, await Run(root, "workspace", "add", "--alias", "case", "--package", "feed/sample.one.nupkg", "--directory", "CONTENT/ONE"));
        Assert.Equal(old, await File.ReadAllBytesAsync(marker));
        Assert.Equal(1, await Run(root, "workspace", "add", "--alias", "absolute", "--package", "feed/sample.one.nupkg", "--directory", Path.Combine(root, "absolute")));
        Assert.Equal(old, await File.ReadAllBytesAsync(marker));
        var escapeExit = await Run(root, "workspace", "add", "--alias", "escape", "--package", "feed/sample.one.nupkg", "--directory", "../outside");
        Assert.True(escapeExit == 1, $"exit={escapeExit}; stdout={stdout}; stderr={stderr}");
        Assert.Equal(old, await File.ReadAllBytesAsync(marker));
        Assert.False(Directory.Exists(Path.Combine(Directory.GetParent(root)!.FullName, "outside")));
        Assert.True(File.Exists(package));
    }

    [Fact]
    public async Task WorkspaceStatusSeparatesMissingCorruptAndMismatchedBaselines()
    {
        await Package("sample.state", "1.0.0", "state");
        Assert.Equal(0, await Run(root, "workspace", "init"));
        Assert.Equal(0, await Run(root, "workspace", "add", "--alias", "state", "--package", "feed/sample.state.nupkg"));
        Assert.Equal(0, await Run(root, "workspace", "unpack", "--alias", "state"));
        var member = Path.Combine(root, "content", "state"); var saved = member + "-saved";
        Directory.Move(member, saved);
        Assert.Equal(0, await Run(root, "workspace", "status", "--json"));
        using (var missing = JsonDocument.Parse(stdout)) Assert.Equal("missing", missing.RootElement.GetProperty("members")[0].GetProperty("state").GetString());
        Directory.Move(saved, member);

        var baselinePath = Path.Combine(member, ".nuget-content", "manifest.json"); var baseline = await File.ReadAllBytesAsync(baselinePath);
        await File.WriteAllTextAsync(baselinePath, "{}");
        Assert.Equal(1, await Run(root, "workspace", "status", "--json"));
        using (var corrupt = JsonDocument.Parse(stdout)) Assert.Equal("corrupt", corrupt.RootElement.GetProperty("members")[0].GetProperty("state").GetString());
        await File.WriteAllBytesAsync(baselinePath, baseline);

        var markerPath = Path.Combine(root, "nuget-content.json"); var marker = await File.ReadAllTextAsync(markerPath);
        await File.WriteAllTextAsync(markerPath, marker.Replace("\"version\":\"1.0.0\"", "\"version\":\"1.1.0\"", StringComparison.Ordinal));
        Assert.Equal(1, await Run(root, "workspace", "status", "--json"));
        using (var mismatched = JsonDocument.Parse(stdout)) Assert.Equal("mismatched", mismatched.RootElement.GetProperty("members")[0].GetProperty("state").GetString());
        await File.WriteAllTextAsync(markerPath, marker);
    }

    [Fact]
    public async Task UsageFindsDirectCentralAndPriorAssetsWithoutTreatingCentralOnlyAsUse()
    {
        await Package("example.shared", "3.1.0", "shared");
        await Package("central.only", "1.2.0", "central");
        Assert.Equal(0, await Run(root, "workspace", "init"));
        Assert.Equal(0, await Run(root, "workspace", "add", "--alias", "shared", "--package", "feed/example.shared.nupkg"));
        Assert.Equal(0, await Run(root, "workspace", "add", "--alias", "central", "--package", "feed/central.only.nupkg"));
        await File.WriteAllTextAsync(Path.Combine(root, "Directory.Packages.props"), """
            <Project><ItemGroup><PackageVersion Include="example.shared" Version="3.1.0" /><PackageVersion Include="central.only" Version="1.2.0" /></ItemGroup></Project>
            """);
        var project = Path.Combine(root, "App.csproj");
        await File.WriteAllTextAsync(project, """
            <Project Sdk="Microsoft.NET.Sdk"><ItemGroup><PackageReference Include="example.shared" /><PackageReference Include="dynamic.pkg" Version="$(DynamicVersion)" /></ItemGroup></Project>
            """);
        var assets = Path.Combine(root, "obj", "project.assets.json"); Directory.CreateDirectory(Path.GetDirectoryName(assets)!);
        await File.WriteAllTextAsync(assets, """
            {"version":3,"libraries":{"example.shared/3.1.0":{"type":"package"},"other/1.0.0":{"type":"package"}}}
            """);
        Directory.CreateDirectory(Path.Combine(root, ".git")); await File.WriteAllTextAsync(Path.Combine(root, ".git", "Ignored.csproj"), "<Project><ItemGroup><PackageReference Include=\"example.shared\" /></ItemGroup></Project>");
        await File.WriteAllTextAsync(Path.Combine(root, "obj", "Ignored.csproj"), "<Project><ItemGroup><PackageReference Include=\"example.shared\" /></ItemGroup></Project>");
        Directory.CreateDirectory(Path.Combine(root, "content", "shared")); await File.WriteAllTextAsync(Path.Combine(root, "content", "shared", "Generated.csproj"), "<Project><ItemGroup><PackageReference Include=\"example.shared\" /></ItemGroup></Project>");

        var usageExit = await Run(root, "workspace", "usage", "--json");
        Assert.True(usageExit == 0, $"exit={usageExit}; stdout={stdout}; stderr={stderr}");
        using var json = JsonDocument.Parse(stdout);
        var member = Assert.Single(json.RootElement.GetProperty("members").EnumerateArray(), x => x.GetProperty("alias").GetString() == "shared");
        Assert.Equal("shared", member.GetProperty("alias").GetString());
        var use = Assert.Single(member.GetProperty("useSites").EnumerateArray());
        Assert.Equal("App.csproj", use.GetProperty("path").GetString());
        Assert.Equal("directPackageReferenceWithCentralVersion", use.GetProperty("classification").GetString());
        Assert.Equal("Directory.Packages.props", Assert.Single(member.GetProperty("centralVersionDeclarations").EnumerateArray()).GetProperty("path").GetString());
        var evidence = Assert.Single(member.GetProperty("previousAssetsEvidence").EnumerateArray());
        Assert.Equal("previousRestoreUnknownFreshness", evidence.GetProperty("state").GetString());
        Assert.Equal("3.1.0", evidence.GetProperty("version").GetString());
        var centralOnly = Assert.Single(json.RootElement.GetProperty("members").EnumerateArray(), x => x.GetProperty("alias").GetString() == "central");
        Assert.Equal("central", centralOnly.GetProperty("alias").GetString());
        Assert.Empty(centralOnly.GetProperty("useSites").EnumerateArray());
        Assert.Single(centralOnly.GetProperty("centralVersionDeclarations").EnumerateArray());
        Assert.Empty(centralOnly.GetProperty("previousAssetsEvidence").EnumerateArray());
    }

    [Fact]
    public async Task UsageScanBoundsDepthAndReportsPartialCoverage()
    {
        await Package("sample.deep", "1.0.0", "deep");
        Assert.Equal(0, await Run(root, "workspace", "init"));
        Assert.Equal(0, await Run(root, "workspace", "add", "--alias", "deep", "--package", "feed/sample.deep.nupkg"));
        var deep = root;
        for (var i = 0; i < 45; i++) { deep = Path.Combine(deep, "d"); Directory.CreateDirectory(deep); }
        var result = await Run(root, "workspace", "usage", "--json");
        Assert.Equal(1, result);
        using var json = JsonDocument.Parse(stdout);
        Assert.Contains(json.RootElement.GetProperty("diagnostics").EnumerateArray(), d => d.GetString()!.Contains("Traversal depth limit", StringComparison.Ordinal));
    }

    [Fact]
    public async Task LegacyCommandSelectionDoesNotChangeWhenRootMarkerExists()
    {
        var package = await Package("legacy.pkg", "1.0.0", "legacy");
        Assert.Equal(0, await Run(root, "workspace", "init"));
        Assert.Equal(0, await Run(root, "workspace", "add", "--alias", "legacy", "--package", "feed/legacy.pkg.nupkg"));
        Assert.Equal(0, await Run(root, "status", "--package", package, "--json"));
        using var json = JsonDocument.Parse(stdout);
        Assert.Equal("package", json.RootElement.GetProperty("kind").GetString());
        Assert.Equal(1, await Run(root, "workspace", "status", "--alias", "missing"));
    }

    private async Task<string> Package(string id, string version, string content)
    {
        var source = Path.Combine(root, "source-" + Guid.NewGuid().ToString("N")); Directory.CreateDirectory(source);
        await File.WriteAllTextAsync(Path.Combine(source, "payload.txt"), content);
        var feed = Path.Combine(root, "feed"); Directory.CreateDirectory(feed);
        var package = Path.Combine(feed, id + ".nupkg");
        await ContentPackages.PackInitialAsync(id, version, source, package); return package;
    }

    private static string stdout = "";
    private static string stderr = "";
    private static async Task<int> Run(string cwd, params string[] args)
    {
        var oldOut = Console.Out; var oldErr = Console.Error; var oldCwd = Environment.CurrentDirectory;
        using var output = new StringWriter(); using var error = new StringWriter();
        try
        {
            Console.SetOut(output); Console.SetError(error); Environment.CurrentDirectory = cwd;
            var exit = await Cli.RunAsync(args); stdout = output.ToString(); stderr = error.ToString(); return exit;
        }
        finally { Console.SetOut(oldOut); Console.SetError(oldErr); Environment.CurrentDirectory = oldCwd; }
    }
    public void Dispose() { if (Directory.Exists(root)) Directory.Delete(root, true); }
}
