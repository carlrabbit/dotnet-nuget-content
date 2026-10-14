using System.IO.Compression;
using System.Text.Json;
using NuGet.Packaging;

namespace DotnetNugetContent.Tests;

public sealed class ManagedContentTests : IDisposable
{
    private readonly string root = Path.Combine(Path.GetTempPath(), "dnc-managed-" + Guid.NewGuid().ToString("N"));
    public ManagedContentTests() => Directory.CreateDirectory(root);

    [Fact]
    public async Task ManifestUnpackStatusRepackAndHistoryFollowLinearSnapshotContract()
    {
        var source = Path.Combine(root, "source"); Directory.CreateDirectory(Path.Combine(source, "nested"));
        await File.WriteAllTextAsync(Path.Combine(source, "nested", "one.txt"), "one"); await File.WriteAllBytesAsync(Path.Combine(source, "bin.dat"), [0, 255, 3]);
        var p1 = Path.Combine(root, "one.nupkg"); await ContentPackages.PackInitialAsync("sample.managed", "1.0.0", source, p1);
        using (var archive = ZipFile.OpenRead(p1))
        {
            var entry = Assert.Single(archive.Entries, e => e.FullName == ".nuget-content/manifest.json");
            using var reader = new StreamReader(entry.Open()); using var json = JsonDocument.Parse(await reader.ReadToEndAsync());
            Assert.Equal(1, json.RootElement.GetProperty("schemaVersion").GetInt32()); Assert.Equal("1.0.0", json.RootElement.GetProperty("package").GetProperty("version").GetString());
            Assert.Equal(2, json.RootElement.GetProperty("files").GetArrayLength()); Assert.Equal("nested/one.txt", json.RootElement.GetProperty("files")[1].GetProperty("path").GetString());
        }
        var workspace = Path.Combine(root, "workspace"); await ContentPackages.UnpackAsync(p1, workspace, null);
        Assert.Equal("Clean", await ContentPackages.StatusAsync(workspace, null));
        Assert.True(File.Exists(Path.Combine(workspace, ".nuget-content", "manifest.json")));
        await File.WriteAllTextAsync(Path.Combine(workspace, "nested", "one.txt"), "changed"); await File.WriteAllTextAsync(Path.Combine(workspace, "new.txt"), "new"); File.Delete(Path.Combine(workspace, "bin.dat"));
        var changed = await ContentPackages.StatusAsync(workspace, null); Assert.Contains("Added: new.txt", changed); Assert.Contains("Modified: nested/one.txt", changed); Assert.Contains("Deleted: bin.dat", changed);
        var marker = await File.ReadAllBytesAsync(Path.Combine(workspace, ".nuget-content", "manifest.json"));
        var p2 = await ContentPackages.PackManagedAsync(workspace, "1.1.0", Path.Combine(root, "two.nupkg"), "curated update"); Assert.Equal(Path.Combine(root, "two.nupkg"), p2);
        Assert.Equal(marker, await File.ReadAllBytesAsync(Path.Combine(workspace, ".nuget-content", "manifest.json")));
        var history = await ContentPackages.HistoryAsync("unused", p2); Assert.Contains("1.0.0", history); Assert.Contains("1.1.0", history); Assert.Contains("curated update", history);
        var workspace2 = Path.Combine(root, "workspace2"); await ContentPackages.UnpackAsync(p2, workspace2, null); await File.WriteAllTextAsync(Path.Combine(workspace2, "next.txt"), "next snapshot");
        var p3 = await ContentPackages.PackManagedAsync(workspace2, "1.2.0", Path.Combine(root, "three.nupkg"), null); Assert.True(File.Exists(p3));
        using (var archive = ZipFile.OpenRead(p3)) { using var reader = new StreamReader(Assert.Single(archive.Entries, e => e.FullName == ".nuget-content/manifest.json").Open()); using var json = JsonDocument.Parse(await reader.ReadToEndAsync()); Assert.False(json.RootElement.GetProperty("history")[2].TryGetProperty("message", out _)); }
        Assert.StartsWith("Package valid:", await ContentPackages.StatusAsync("unused", p3));
    }

    [Fact]
    public async Task ManagedPackGuardsNoOpVersionReservedPathsAndExplicitMarker()
    {
        var src = Path.Combine(root, "src"); Directory.CreateDirectory(src); await File.WriteAllTextAsync(Path.Combine(src, "data"), "x"); var pkg = Path.Combine(root, "base.nupkg"); await ContentPackages.PackInitialAsync("sample", "1.0.0", src, pkg); var ws = Path.Combine(root, "ws"); await ContentPackages.UnpackAsync(pkg, ws, null);
        var marker = Path.Combine(ws, ".nuget-content", "manifest.json"); var before = await File.ReadAllBytesAsync(marker);
        await Assert.ThrowsAsync<CliException>(() => ContentPackages.PackManagedAsync(ws, "1.1.0", null, null));
        await Assert.ThrowsAsync<CliException>(() => ContentPackages.PackManagedAsync(ws, "1.0.0", Path.Combine(root, "bad.nupkg"), null));
        await File.WriteAllTextAsync(Path.Combine(ws, "data"), "changed"); var existing = Path.Combine(root, "existing.nupkg"); await File.WriteAllTextAsync(existing, "keep");
        await Assert.ThrowsAsync<CliException>(() => ContentPackages.PackManagedAsync(ws, "1.1.0", existing, null)); Assert.Equal("keep", await File.ReadAllTextAsync(existing));
        Directory.CreateDirectory(Path.Combine(ws, ".nuget-content", "collision")); await File.WriteAllTextAsync(Path.Combine(ws, ".nuget-content", "collision", "x"), "x");
        await Assert.ThrowsAsync<CliException>(() => ContentPackages.PackManagedAsync(ws, "1.1.0", Path.Combine(root, "bad.nupkg"), null));
        Assert.Equal(before, await File.ReadAllBytesAsync(marker)); Assert.False(File.Exists(Path.Combine(root, "bad.nupkg")));
        await Assert.ThrowsAsync<CliException>(() => ContentPackages.StatusAsync(Path.Combine(ws, "nested"), null));
    }

    [Fact]
    public async Task PackageStatusRejectsMismatchAndUnsupportedManifest()
    {
        using (var schema = JsonDocument.Parse(await File.ReadAllTextAsync(Path.Combine(AppContext.BaseDirectory, "../../../../../docs/specs/manifest-v1.schema.json"))))
        {
            var top = schema.RootElement;
            Assert.Equal(1, top.GetProperty("properties").GetProperty("schemaVersion").GetProperty("const").GetInt32());
            Assert.Equal(new[] { "schemaVersion", "package", "files", "history" }, top.GetProperty("required").EnumerateArray().Select(x => x.GetString()).ToArray());
            Assert.False(top.GetProperty("additionalProperties").GetBoolean());
            Assert.Equal(new[] { "id", "version" }, top.GetProperty("properties").GetProperty("package").GetProperty("required").EnumerateArray().Select(x => x.GetString()).ToArray());
        }
        var src = Path.Combine(root, "src"); Directory.CreateDirectory(src); await File.WriteAllTextAsync(Path.Combine(src, "x"), "x"); var p = Path.Combine(root, "good.nupkg"); await ContentPackages.PackInitialAsync("sample", "1.0.0", src, p);
        Assert.StartsWith("Package valid:", await ContentPackages.StatusAsync("unused", p));
        var altered = Path.Combine(root, "altered.nupkg"); File.Copy(p, altered); using (var zip = ZipFile.Open(altered, ZipArchiveMode.Update)) { using var w = new StreamWriter(zip.GetEntry("contentFiles/any/any/x")!.Open()); w.Write("y"); }
        await Assert.ThrowsAsync<CliException>(() => ContentPackages.StatusAsync("unused", altered));
        var bad = Path.Combine(root, "bad.nupkg"); File.Copy(p, bad); using (var zip = ZipFile.Open(bad, ZipArchiveMode.Update)) { zip.GetEntry(".nuget-content/manifest.json")!.Delete(); var e = zip.CreateEntry(".nuget-content/manifest.json"); using var w = new StreamWriter(e.Open()); w.Write("{\"schemaVersion\":2}"); }
        await Assert.ThrowsAsync<CliException>(() => ContentPackages.StatusAsync("unused", bad));
        var malformedHistory = Path.Combine(root, "bad-history.nupkg"); File.Copy(p, malformedHistory); using (var zip = ZipFile.Open(malformedHistory, ZipArchiveMode.Update)) { zip.GetEntry(".nuget-content/manifest.json")!.Delete(); var e = zip.CreateEntry(".nuget-content/manifest.json"); using var w = new StreamWriter(e.Open()); w.Write("""{"schemaVersion":1,"package":{"id":"sample","version":"1.0.0"},"files":[{"path":"x","size":1,"sha256":"2D711642B726B04401627CA9FBAC32F5C8530FB1903CC4DB02258717921A4881"}],"history":[{"version":"1.0.0","previousVersion":"0.9.0","changes":{"added":["x"],"modified":[],"deleted":[]}}]}"""); }
        await Assert.ThrowsAsync<CliException>(() => ContentPackages.StatusAsync("unused", malformedHistory));
    }

    public void Dispose() { if (Directory.Exists(root)) Directory.Delete(root, true); }
}
