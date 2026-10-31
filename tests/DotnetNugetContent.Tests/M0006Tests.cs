using System.Text.Json;
using DotnetNugetContent.Tests;

public sealed class M0006Tests : IDisposable
{
    private readonly string root = Path.Combine(Path.GetTempPath(), "dnc-m0006-" + Guid.NewGuid().ToString("N"));
    private string stdout = "";
    private string stderr = "";

    public M0006Tests() => Directory.CreateDirectory(root);

    [Fact]
    public void VersionSelectionCalculatesNormalizedStableIncrementsAndRejectsAmbiguity()
    {
        Assert.Equal("1.0.0", new PackageVersionSelection(null, "major").Resolve("0.9.8").ToNormalizedString());
        Assert.Equal("2.0.0", new PackageVersionSelection(null, "major").Resolve("1.9.8").ToNormalizedString());
        Assert.Equal("1.10.0", new PackageVersionSelection(null, "minor").Resolve("1.9.8").ToNormalizedString());
        Assert.Equal("1.9.9", new PackageVersionSelection(null, "patch").Resolve("1.9.8").ToNormalizedString());
        Assert.Equal("1.3.0", new PackageVersionSelection("1.3", null).Resolve("1.2.0").ToNormalizedString());
        Assert.Throws<CliException>(() => new PackageVersionSelection(null, "patch").Resolve("1.2.3-preview.1"));
        Assert.Throws<CliException>(() => new PackageVersionSelection(null, "patch").Resolve("1.2.3+build.1"));
        Assert.Throws<CliException>(() => new PackageVersionSelection(null, "patch").Resolve("1.2"));
        Assert.Throws<CliException>(() => new PackageVersionSelection(null, "patch").Resolve("1.2.2147483647"));
        Assert.Throws<CliException>(() => PackageVersionSelection.FromOptions(new Dictionary<string, string> { ["version"] = "1.1.0", ["patch"] = "true" }));
    }

    [Fact]
    public async Task ManagedPackIncrementCreatesConsistentPackageWithoutChangingBaseline()
    {
        var package = await MakePackage("sample.increment", "0.9.8", "old");
        var workspace = Path.Combine(root, "workspace"); await ContentPackages.UnpackAsync(package, workspace, null);
        await File.WriteAllTextAsync(Path.Combine(workspace, "payload.txt"), "new");
        var baseline = await File.ReadAllBytesAsync(Path.Combine(workspace, ".nuget-content", "manifest.json"));
        var output = Path.Combine(root, "sample.increment.1.0.0.nupkg");
        Assert.Equal(0, await Run("pack", "--source", workspace, "--major"));
        Assert.Equal(baseline, await File.ReadAllBytesAsync(Path.Combine(workspace, ".nuget-content", "manifest.json")));
        var manifest = await ContentPackages.ReadPackageForWorkspaceAsync(output);
        Assert.Equal("1.0.0", manifest.Package.Version);
        using var archive = System.IO.Compression.ZipFile.OpenRead(output);
        Assert.Contains(archive.Entries, e => e.FullName == "contentFiles/any/any/payload.txt");
        Assert.Equal(2, manifest.History.Count);
        Assert.Equal("1.0.0", manifest.History[^1].Version);
        Assert.Equal("0.9.8", manifest.History[^1].PreviousVersion);
        Assert.False(File.Exists(Path.Combine(root, "conflict.nupkg")));
        Assert.Equal(2, await Run("pack", "--source", workspace, "--version", "1.1.0", "--patch", "--output", Path.Combine(root, "conflict.nupkg")));
        Assert.False(File.Exists(Path.Combine(root, "conflict.nupkg")));
    }

    [Fact]
    public async Task ReferenceUpdatePreviewsThenAppliesDirectAndCentralDeclarationsOnly()
    {
        var pinned = await MakePackage("sample.refs", "1.0.0", "old");
        var next = await MakePackage("sample.refs", "1.1.0", "next");
        Assert.Equal(0, await Run("workspace", "init"));
        Assert.Equal(0, await Run("workspace", "add", "--alias", "refs", "--package", Path.GetRelativePath(root, pinned).Replace('\\', '/')));
        var props = Path.Combine(root, "Directory.Packages.props");
        var projectA = Path.Combine(root, "a.csproj"); var projectB = Path.Combine(root, "b.fsproj"); var projectC = Path.Combine(root, "c.csproj");
        await File.WriteAllTextAsync(props, "<Project>\r\n  <ItemGroup>\r\n    <PackageVersion Include=\"sample.refs\" Version=\"1.0.0\" />\r\n    <PackageVersion Include=\"unused.package\" Version=\"3.0.0\" />\r\n  </ItemGroup>\r\n</Project>\r\n");
        var unusedProps = Path.Combine(root, "unused"); Directory.CreateDirectory(unusedProps);
        var unusedCentral = Path.Combine(unusedProps, "Directory.Packages.props");
        await File.WriteAllTextAsync(unusedCentral, "<Project><ItemGroup><PackageVersion Include=\"sample.refs\" Version=\"9.0.0\" /></ItemGroup></Project>");
        await File.WriteAllTextAsync(projectA, "<Project><ItemGroup><PackageReference Include=\"sample.refs\" /></ItemGroup></Project>");
        await File.WriteAllTextAsync(projectB, "<Project><ItemGroup><PackageReference Include=\"sample.refs\"><Version>1.0.0</Version></PackageReference></ItemGroup></Project>");
        await File.WriteAllTextAsync(projectC, "<Project><ItemGroup><PackageReference Include=\"other.package\" Version=\"8.0.0\" /></ItemGroup></Project>");
        await File.WriteAllTextAsync(Path.Combine(unusedProps, "unused.csproj"), "<Project><ItemGroup><PackageReference Include=\"other.package\" Version=\"1.0.0\" /></ItemGroup></Project>");
        var beforeProps = await File.ReadAllBytesAsync(props); var beforeA = await File.ReadAllBytesAsync(projectA); var beforeB = await File.ReadAllBytesAsync(projectB);

        Assert.Equal(0, await Run("workspace", "references", "update", "--alias", "refs", "--json"));
        using (var pinnedPreview = JsonDocument.Parse(stdout))
        {
            Assert.Equal("1.0.0", pinnedPreview.RootElement.GetProperty("targetVersion").GetString());
            Assert.All(pinnedPreview.RootElement.GetProperty("changes").EnumerateArray(), item => Assert.Equal("noOp", item.GetProperty("classification").GetString()));
        }
        Assert.Equal(1, await Run("workspace", "references", "update", "--alias", "refs", "--version", "1.1.0", "--json"));
        using (var unregistered = JsonDocument.Parse(stdout)) Assert.Contains(unregistered.RootElement.GetProperty("blockers").EnumerateArray(), x => x.GetProperty("code").GetString() == "packageVerification");
        Assert.Equal(0, await Run("workspace", "add", "--alias", "refs-next", "--package", Path.GetRelativePath(root, next).Replace('\\', '/'), "--directory", "content/refs-next"));
        Assert.Equal(0, await Run("workspace", "references", "update", "--alias", "refs", "--version", "1.1.0", "--json"));
        using (var preview = JsonDocument.Parse(stdout))
        {
            var json = preview.RootElement;
            Assert.Equal(1, json.GetProperty("schemaVersion").GetInt32());
            Assert.Equal("workspaceReferenceUpdate", json.GetProperty("kind").GetString());
            Assert.Equal("1.1.0", json.GetProperty("targetVersion").GetString());
            Assert.True(json.GetProperty("canApply").GetBoolean());
            Assert.Equal(2, json.GetProperty("changes").GetArrayLength());
        }
        Assert.Equal(beforeProps, await File.ReadAllBytesAsync(props));
        Assert.Equal(beforeA, await File.ReadAllBytesAsync(projectA));
        Assert.Equal(beforeB, await File.ReadAllBytesAsync(projectB));
        var referenceSchemaPath = Path.Combine(AppContext.BaseDirectory, "../../../../../docs/specs/M0006-reference-update.schema.json");
        using (var schema = JsonDocument.Parse(await File.ReadAllTextAsync(referenceSchemaPath)))
        {
            Assert.Equal(1, schema.RootElement.GetProperty("properties").GetProperty("schemaVersion").GetProperty("const").GetInt32());
            Assert.Equal("workspaceReferenceUpdate", schema.RootElement.GetProperty("properties").GetProperty("kind").GetProperty("const").GetString());
            Assert.False(schema.RootElement.GetProperty("additionalProperties").GetBoolean());
        }

        var appliedExit = await Run("workspace", "references", "update", "--alias", "refs", "--version", "1.1.0", "--apply", "--json");
        Assert.True(appliedExit == 0, $"{stderr} {stdout}");
        using (var applied = JsonDocument.Parse(stdout)) Assert.True(applied.RootElement.GetProperty("applied").GetBoolean());
        Assert.Contains("Version=\"1.1.0\"", await File.ReadAllTextAsync(props));
        Assert.Contains("<Version>1.1.0</Version>", await File.ReadAllTextAsync(projectB));
        Assert.Contains("Version=\"8.0.0\"", await File.ReadAllTextAsync(projectC));
        Assert.Contains("Version=\"9.0.0\"", await File.ReadAllTextAsync(unusedCentral));
        var duplicatePackage = Path.Combine(root, "feed", "duplicate-target.nupkg"); File.Copy(next, duplicatePackage);
        Assert.Equal(0, await Run("workspace", "add", "--alias", "refs-next-copy", "--package", Path.GetRelativePath(root, duplicatePackage).Replace('\\', '/'), "--directory", "content/refs-next-copy"));
        Assert.Equal(1, await Run("workspace", "references", "update", "--alias", "refs", "--version", "1.1.0", "--json"));
        using (var ambiguous = JsonDocument.Parse(stdout)) Assert.Contains(ambiguous.RootElement.GetProperty("blockers").EnumerateArray(), x => x.GetProperty("code").GetString() == "packageVerification");
        Assert.Equal("1.0.0", JsonDocument.Parse(await File.ReadAllTextAsync(Path.Combine(root, "nuget-content.json"))).RootElement.GetProperty("members")[0].GetProperty("version").GetString());
        Assert.Equal("1.1.0", (await ContentPackages.ReadPackageForWorkspaceAsync(next)).Package.Version);
    }

    [Fact]
    public async Task ReferenceUpdateExcludesEveryRegisteredManagedMemberTree()
    {
        var selectedOld = await MakePackage("sample.selected", "1.0.0", "old selected");
        await MakePackage("sample.selected", "1.1.0", "new selected");
        var otherPackage = await MakePackage("sample.other", "2.0.0", "other member");
        Assert.Equal(0, await Run("workspace", "init"));
        Assert.Equal(0, await Run("workspace", "add", "--alias", "selected", "--package", Path.GetRelativePath(root, selectedOld).Replace('\\', '/'), "--directory", "managed/selected"));
        Assert.Equal(0, await Run("workspace", "add", "--alias", "other", "--package", Path.GetRelativePath(root, otherPackage).Replace('\\', '/'), "--directory", "managed/other"));
        var setExit = await Run("workspace", "set", "--alias", "selected", "--package", "feed/sample.selected.1.1.0.nupkg");
        Assert.True(setExit == 0, $"exit={setExit}; stdout={stdout}; stderr={stderr}");
        Assert.Equal(0, await Run("workspace", "unpack", "--all"));

        var externalProject = Path.Combine(root, "Consumer.csproj");
        var otherProject = Path.Combine(root, "managed", "other", "Member.csproj");
        var nestedProject = Path.Combine(root, "managed", "other", "nested", "Nested.csproj");
        const string projectXml = "<Project><ItemGroup><PackageReference Include=\"sample.selected\" Version=\"1.0.0\" /></ItemGroup></Project>";
        await File.WriteAllTextAsync(externalProject, projectXml);
        await File.WriteAllTextAsync(otherProject, projectXml);
        Directory.CreateDirectory(Path.GetDirectoryName(nestedProject)!);
        await File.WriteAllTextAsync(nestedProject, projectXml);

        var otherBaselinePath = Path.Combine(root, "managed", "other", ".nuget-content", "manifest.json");
        var otherBaseline = await File.ReadAllBytesAsync(otherBaselinePath);
        var otherPackageBytes = await File.ReadAllBytesAsync(otherPackage);
        var otherProjectBytes = await File.ReadAllBytesAsync(otherProject);
        var nestedProjectBytes = await File.ReadAllBytesAsync(nestedProject);
        var workspaceMarker = await File.ReadAllBytesAsync(Path.Combine(root, "nuget-content.json"));
        Assert.Equal(0, await Run("workspace", "status", "--all", "--json"));
        using var beforeStatus = JsonDocument.Parse(stdout);
        var otherStatus = Assert.Single(beforeStatus.RootElement.GetProperty("members").EnumerateArray(), x => x.GetProperty("alias").GetString() == "other").GetRawText();

        Assert.Equal(0, await Run("workspace", "references", "update", "--alias", "selected", "--json"));
        using (var preview = JsonDocument.Parse(stdout))
        {
            var changes = preview.RootElement.GetProperty("changes").EnumerateArray().ToArray();
            var change = Assert.Single(changes);
            Assert.Equal("Consumer.csproj", change.GetProperty("path").GetString());
            Assert.Equal("1.0.0", change.GetProperty("oldVersion").GetString());
            Assert.Equal("1.1.0", change.GetProperty("newVersion").GetString());
        }
        Assert.Equal(projectXml, await File.ReadAllTextAsync(externalProject));
        Assert.Equal(otherProjectBytes, await File.ReadAllBytesAsync(otherProject));
        Assert.Equal(nestedProjectBytes, await File.ReadAllBytesAsync(nestedProject));

        Assert.Equal(0, await Run("workspace", "references", "update", "--alias", "selected", "--apply", "--json"));
        using (var applied = JsonDocument.Parse(stdout)) Assert.True(applied.RootElement.GetProperty("applied").GetBoolean());
        Assert.Contains("Version=\"1.1.0\"", await File.ReadAllTextAsync(externalProject));
        Assert.Equal(otherProjectBytes, await File.ReadAllBytesAsync(otherProject));
        Assert.Equal(nestedProjectBytes, await File.ReadAllBytesAsync(nestedProject));
        Assert.Equal(otherBaseline, await File.ReadAllBytesAsync(otherBaselinePath));
        Assert.Equal(otherPackageBytes, await File.ReadAllBytesAsync(otherPackage));
        Assert.Equal(workspaceMarker, await File.ReadAllBytesAsync(Path.Combine(root, "nuget-content.json")));
        Assert.Equal(0, await Run("workspace", "status", "--all", "--json"));
        using var afterStatus = JsonDocument.Parse(stdout);
        Assert.Equal(otherStatus, Assert.Single(afterStatus.RootElement.GetProperty("members").EnumerateArray(), x => x.GetProperty("alias").GetString() == "other").GetRawText());
    }

    [Fact]
    public async Task ReferenceUpdateBlocksDynamicAndConditionalSourcesWithoutPartialWrites()
    {
        var pinned = await MakePackage("sample.blocked", "1.0.0", "old");
        await MakePackage("sample.blocked", "1.1.0", "new");
        Assert.Equal(0, await Run("workspace", "init"));
        Assert.Equal(0, await Run("workspace", "add", "--alias", "blocked", "--package", Path.GetRelativePath(root, pinned).Replace('\\', '/')));
        var good = Path.Combine(root, "good.csproj"); var conditional = Path.Combine(root, "conditional.csproj");
        await File.WriteAllTextAsync(good, "<Project><ItemGroup><PackageReference Include=\"sample.blocked\" Version=\"1.0.0\" /></ItemGroup></Project>");
        await File.WriteAllTextAsync(conditional, "<Project><ItemGroup Condition=\"'$(Configuration)' == 'Debug'\"><PackageReference Include=\"sample.blocked\" Version=\"1.0.0\" /></ItemGroup></Project>");
        await File.WriteAllTextAsync(Path.Combine(root, "dynamic.csproj"), "<Project><ItemGroup><PackageReference Include=\"sample.blocked\" Version=\"$(PackageVersion)\" /></ItemGroup></Project>");
        await File.WriteAllTextAsync(Path.Combine(root, "imported.csproj"), "<Project><Import Project=\"Directory.Build.props\" /><ItemGroup><PackageReference Include=\"sample.blocked\" Version=\"1.0.0\" /></ItemGroup></Project>");
        await File.WriteAllTextAsync(Path.Combine(root, "duplicate.csproj"), "<Project><ItemGroup><PackageReference Include=\"sample.blocked\" Version=\"1.0.0\" /><PackageReference Include=\"sample.blocked\" Version=\"1.0.0\" /></ItemGroup></Project>");
        await File.WriteAllTextAsync(Path.Combine(root, "malformed.csproj"), "<Project><ItemGroup><PackageReference Include=\"sample.blocked\" Version=\"1.0.0\"></ItemGroup>");
        var before = await File.ReadAllBytesAsync(good);
        Assert.Equal(1, await Run("workspace", "references", "update", "--alias", "blocked", "--version", "1.1.0", "--apply", "--json"));
        using (var blocked = JsonDocument.Parse(stdout))
        {
            var codes = blocked.RootElement.GetProperty("blockers").EnumerateArray().Select(x => x.GetProperty("code").GetString()).ToHashSet();
            Assert.Contains("conditionalReference", codes);
            Assert.Contains("dynamicReferenceVersion", codes);
            Assert.Contains("importedProjectDeclarations", codes);
            Assert.Contains("duplicateDeclaration", codes);
            Assert.Contains("malformedProjectFile", codes);
        }
        Assert.Equal(before, await File.ReadAllBytesAsync(good));
    }

    [Fact]
    public async Task ReferenceUpdateRechecksSourceAndRollsBackHandledCrossFileFailure()
    {
        var pinned = await MakePackage("sample.recheck", "1.0.0", "old");
        var next = await MakePackage("sample.recheck", "1.1.0", "next");
        var first = Path.Combine(root, "a.csproj"); var second = Path.Combine(root, "b.csproj");
        const string xml = "<Project><ItemGroup><PackageReference Include=\"sample.recheck\" Version=\"1.0.0\" /></ItemGroup></Project>";
        await File.WriteAllTextAsync(first, xml); await File.WriteAllTextAsync(second, xml);
        var member = new ProjectWorkspaceMember { Alias = "recheck", PackageId = "sample.recheck", Version = "1.0.0", PackageFile = Path.GetRelativePath(root, pinned).Replace('\\', '/'), Directory = "content/recheck" };
        var nextMember = new ProjectWorkspaceMember { Alias = "recheck-next", PackageId = "sample.recheck", Version = "1.1.0", PackageFile = Path.GetRelativePath(root, next).Replace('\\', '/'), Directory = "content/recheck-next" };
        IReadOnlyList<ProjectWorkspaceMember> registered = [member, nextMember];

        var changed = await ConsumerReferenceUpdater.CreatePlanAsync(root, member, registered, "1.1.0", true, async () => await File.AppendAllTextAsync(first, "<!-- external edit -->"));
        Assert.False(changed.CanApply);
        Assert.Contains(changed.Blockers, b => b.Code == "writeFailure" && b.Message.Contains("Source changed", StringComparison.Ordinal));
        Assert.Contains("external edit", await File.ReadAllTextAsync(first));
        Assert.Contains("Version=\"1.0.0\"", await File.ReadAllTextAsync(first));
        Assert.Contains("Version=\"1.0.0\"", await File.ReadAllTextAsync(second));

        await File.WriteAllTextAsync(first, xml); await File.WriteAllTextAsync(second, xml);
        var failedWrite = await ConsumerReferenceUpdater.CreatePlanAsync(root, member, registered, "1.1.0", true, afterFileCommit: count => { if (count == 1) throw new IOException("simulated handled replacement failure"); });
        Assert.False(failedWrite.CanApply);
        Assert.Contains(failedWrite.Blockers, b => b.Code == "writeFailure");
        Assert.Contains("restored", failedWrite.PartialState, StringComparison.OrdinalIgnoreCase);
        Assert.Equal(xml, await File.ReadAllTextAsync(first));
        Assert.Equal(xml, await File.ReadAllTextAsync(second));
        Assert.Empty(Directory.EnumerateFiles(root, "*.tmp", SearchOption.AllDirectories));
    }

    private async Task<string> MakePackage(string id, string version, string content)
    {
        var source = Path.Combine(root, "source-" + Guid.NewGuid().ToString("N")); Directory.CreateDirectory(source);
        await File.WriteAllTextAsync(Path.Combine(source, "payload.txt"), content);
        var feed = Path.Combine(root, "feed"); Directory.CreateDirectory(feed);
        var package = Path.Combine(feed, id + "." + version + ".nupkg");
        await ContentPackages.PackInitialAsync(id, version, source, package); return package;
    }

    private async Task<int> Run(params string[] args)
    {
        var oldOut = Console.Out; var oldError = Console.Error; var oldDirectory = Environment.CurrentDirectory;
        using var output = new StringWriter(); using var error = new StringWriter();
        try { Console.SetOut(output); Console.SetError(error); Environment.CurrentDirectory = root; var exit = await Cli.RunAsync(args); stdout = output.ToString(); stderr = error.ToString(); return exit; }
        finally { Console.SetOut(oldOut); Console.SetError(oldError); Environment.CurrentDirectory = oldDirectory; }
    }

    public void Dispose() { if (Directory.Exists(root)) Directory.Delete(root, true); }
}
