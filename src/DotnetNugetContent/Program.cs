using System.Buffers;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using NuGet.Packaging;
using NuGet.Packaging.Core;
using NuGet.Frameworks;
using NuGet.Versioning;

return await Cli.RunAsync(args);

internal static class Cli
{
    public static async Task<int> RunAsync(string[] args)
    {
        try
        {
            if (args.Length == 0 || args is ["--help"] or ["-h"] or ["help"]) { Console.Out.WriteLine(HelpText); return 0; }
            if (args is ["--version"] or ["version"]) { Console.Out.WriteLine(typeof(Cli).Assembly.GetName().Version?.ToString(3) ?? "1.0.0"); return 0; }
            var options = ParseOptions(args[1..]);
            switch (args[0])
            {
                case "pack":
                    EnsureOptions(options, "id", "version", "source", "output", "message");
                    var managed = !options.ContainsKey("id");
                    if (!managed) { await ContentPackages.PackInitialAsync(Required(options, "id"), Required(options, "version"), Required(options, "source"), Required(options, "output")); Console.Out.WriteLine($"Created {Path.GetFullPath(options["output"])}"); }
                    else { var output = await ContentPackages.PackManagedAsync(options.GetValueOrDefault("source") ?? Environment.CurrentDirectory, Required(options, "version"), options.GetValueOrDefault("output"), options.GetValueOrDefault("message")); Console.Out.WriteLine($"Created {output}"); }
                    return 0;
                case "unpack":
                    EnsureOptions(options, "package", "destination", "sha256");
                    await ContentPackages.UnpackAsync(Required(options, "package"), Required(options, "destination"), options.GetValueOrDefault("sha256"));
                    Console.Out.WriteLine($"Extracted to {Path.GetFullPath(options["destination"])}"); return 0;
                case "status":
                    EnsureOptions(options, "source", "package", "json");
                    EnsureExclusive(options, "source", "package");
                    if (options.ContainsKey("json"))
                    {
                        var result = await ContentPackages.StatusJsonAsync(options.GetValueOrDefault("source") ?? Environment.CurrentDirectory, options.GetValueOrDefault("package"));
                        Console.Out.WriteLine(result);
                    }
                    else
                    {
                        var status = await ContentPackages.StatusAsync(options.GetValueOrDefault("source") ?? Environment.CurrentDirectory, options.GetValueOrDefault("package"));
                        Console.Out.WriteLine(status);
                    }
                    return 0;
                case "history":
                    EnsureOptions(options, "source", "package", "json");
                    EnsureExclusive(options, "source", "package");
                    Console.Out.WriteLine(options.ContainsKey("json")
                        ? await ContentPackages.HistoryJsonAsync(options.GetValueOrDefault("source") ?? Environment.CurrentDirectory, options.GetValueOrDefault("package"))
                        : await ContentPackages.HistoryAsync(options.GetValueOrDefault("source") ?? Environment.CurrentDirectory, options.GetValueOrDefault("package")));
                    return 0;
                case "hash":
                    EnsureOptions(options, "path", "expect"); var path = Path.GetFullPath(Required(options, "path"));
                    if (!File.Exists(path)) throw new CliException($"File not found: {path}", 1);
                    var hash = await ContentPackages.Sha256Async(path);
                    if (options.TryGetValue("expect", out var expected) && !ContentPackages.HashEquals(hash, expected)) throw new CliException($"SHA-256 mismatch for '{path}'. Expected {expected}; actual {hash}.", 1);
                    Console.Out.WriteLine(hash); return 0;
                default: throw new CliException($"Unknown command '{args[0]}'. Run 'dotnet-nuget-content --help'.");
            }
        }
        catch (CliException ex) { Console.Error.WriteLine($"error: {ex.Message}"); return ex.ExitCode; }
        catch (Exception ex) { Console.Error.WriteLine($"error: {ex.Message}"); return 1; }
    }
    private static Dictionary<string, string> ParseOptions(string[] args) { var d = new Dictionary<string, string>(StringComparer.Ordinal); for (int i = 0; i < args.Length; i++) { if (!args[i].StartsWith("--")) throw new CliException($"Expected an option and value, got '{args[i]}'."); var key = args[i][2..]; var value = key == "json" ? "true" : i + 1 < args.Length && !args[i + 1].StartsWith("--") ? args[++i] : throw new CliException($"Expected an option and value, got '{args[i]}'."); if (!d.TryAdd(key, value)) throw new CliException($"Option '{args[i]}' was supplied more than once."); } return d; }
    private static string Required(Dictionary<string, string> d, string k) => d.TryGetValue(k, out var v) && !string.IsNullOrWhiteSpace(v) ? v : throw new CliException($"Missing required option '--{k}'.");
    private static void EnsureOptions(Dictionary<string, string> d, params string[] allowed) { var bad = d.Keys.FirstOrDefault(k => !allowed.Contains(k, StringComparer.Ordinal)); if (bad is not null) throw new CliException($"Unknown option '--{bad}'."); }
    private static void EnsureExclusive(Dictionary<string, string> d, string first, string second) { if (d.ContainsKey(first) && d.ContainsKey(second)) throw new CliException($"Options '--{first}' and '--{second}' cannot be used together."); }
    private const string HelpText = """
        dotnet-nuget-content — immutable NuGet packages for arbitrary files

        Usage:
          dotnet-nuget-content --help
          dotnet-nuget-content --version
          dotnet-nuget-content pack --id <id> --version <version> --source <dir> --output <file.nupkg>
          dotnet-nuget-content pack --version <version> [--source <workspace>] [--output <file.nupkg>] [--message <text>]
          dotnet-nuget-content unpack --package <file.nupkg> --destination <dir> [--sha256 <hash>]
          dotnet-nuget-content status [--source <workspace> | --package <file.nupkg>] [--json]
          dotnet-nuget-content history [--source <workspace> | --package <file.nupkg>] [--json]
          dotnet-nuget-content hash --path <file> [--expect <hash>]

        Workflow:
          First package: pack --id ... --version ... --source ... --output ...
          Update: unpack, edit workspace files, status, pack --version ...
          Inspect: status and history; add --json for structured output.

        Managed status, history and pack use the current directory by default; they
        never search parent directories. Managed pack needs changes and a higher
        version. Without --output it writes beside the workspace, leaving its
        baseline unchanged. Existing output files and extraction destinations are
        not replaced.

        Exit codes: 0 success, 1 operation/integrity error, 2 usage error.
        Errors are written to stderr.
        """;
}

internal sealed class CliException(string message, int exitCode = 2) : Exception(message) { public int ExitCode { get; } = exitCode; }

internal sealed class Manifest
{
    public int SchemaVersion { get; set; } = 1;
    public PackageIdentity Package { get; set; } = new();
    public List<ManifestFile> Files { get; set; } = [];
    public List<HistoryRecord> History { get; set; } = [];
}
internal sealed class PackageIdentity { public string Id { get; set; } = ""; public string Version { get; set; } = ""; }
internal sealed class ManifestFile { public string Path { get; set; } = ""; public long Size { get; set; } public string Sha256 { get; set; } = ""; }
internal sealed class HistoryRecord { public string Version { get; set; } = ""; public string? PreviousVersion { get; set; } public ChangeSet Changes { get; set; } = new(); [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] public string? Message { get; set; } }
internal sealed class ChangeSet { public List<string> Added { get; set; } = []; public List<string> Modified { get; set; } = []; public List<string> Deleted { get; set; } = []; }
internal sealed class JsonPackageIdentity { public string Id { get; set; } = ""; public string Version { get; set; } = ""; }
internal sealed class JsonChanges { public List<string> Added { get; set; } = []; public List<string> Modified { get; set; } = []; public List<string> Deleted { get; set; } = []; }
internal sealed class JsonHistoryRecord { public string Version { get; set; } = ""; public string? PreviousVersion { get; set; } [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] public string? Message { get; set; } public JsonChanges Changes { get; set; } = new(); }
internal sealed class WorkspaceStatusResult { public int SchemaVersion { get; set; } = 1; public string Kind { get; set; } = "workspace"; public JsonPackageIdentity Package { get; set; } = new(); public bool Clean { get; set; } public JsonChanges Changes { get; set; } = new(); }
internal sealed class PackageStatusResult { public int SchemaVersion { get; set; } = 1; public string Kind { get; set; } = "package"; public JsonPackageIdentity Package { get; set; } = new(); public bool Valid { get; set; } = true; public int FileCount { get; set; } }
internal sealed class HistoryResult { public int SchemaVersion { get; set; } = 1; public JsonPackageIdentity Package { get; set; } = new(); public List<JsonHistoryRecord> History { get; set; } = []; }
[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase, WriteIndented = false, UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow)]
[JsonSerializable(typeof(Manifest))]
[JsonSerializable(typeof(WorkspaceStatusResult))]
[JsonSerializable(typeof(PackageStatusResult))]
[JsonSerializable(typeof(HistoryResult))]
internal partial class ManifestJsonContext : JsonSerializerContext { }

internal static class ContentPackages
{
    private const string Prefix = "contentFiles/any/any/"; private const string ManifestPath = ".nuget-content/manifest.json";
    private static readonly Regex IdPattern = new("^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$", RegexOptions.CultureInvariant | RegexOptions.NonBacktracking);
    public static Task PackAsync(string id, string version, string source, string output) => PackInitialAsync(id, version, source, output);

    public static async Task PackInitialAsync(string id, string versionText, string sourcePath, string outputPath)
    {
        var version = ParseVersion(versionText); ValidateIdentity(id); var source = Path.GetFullPath(sourcePath); if (!Directory.Exists(source)) throw new CliException($"Source directory not found: {source}", 1);
        RejectReparsePoints(source); var files = await InventoryAsync(source); if (files.Count == 0) throw new CliException("Source directory must contain at least one file.", 1);
        var manifest = new Manifest { Package = new() { Id = id, Version = version.ToNormalizedString() }, Files = files }; manifest.History.Add(new() { Version = version.ToNormalizedString(), Changes = new() { Added = files.Select(f => f.Path).ToList() } });
        await CreatePackageAsync(manifest, source, outputPath);
    }
    public static async Task<string> PackManagedAsync(string sourcePath, string versionText, string? outputPath, string? message)
    {
        var root = ResolveWorkspace(sourcePath); var baseline = await ReadManifestFileAsync(Path.Combine(root, ManifestPath)); var version = ParseVersion(versionText);
        if (version <= ParseVersion(baseline.Package.Version)) throw new CliException("New version must be greater than the managed workspace baseline version.", 1);
        if (message is not null && string.IsNullOrWhiteSpace(message)) throw new CliException("--message must contain non-whitespace text.");
        RejectReparsePoints(root); var files = await InventoryAsync(root); if (files.Count == 0) throw new CliException("Workspace must contain at least one content file.", 1);
        var changes = Diff(baseline.Files, files); if (changes.Added.Count + changes.Modified.Count + changes.Deleted.Count == 0) throw new CliException("Workspace content is unchanged; no new package version was created.", 1);
        var manifest = new Manifest { Package = new() { Id = baseline.Package.Id, Version = version.ToNormalizedString() }, Files = files, History = baseline.History.ToList() };
        manifest.History.Add(new() { Version = version.ToNormalizedString(), PreviousVersion = baseline.Package.Version, Changes = changes, Message = message });
        var workspaceParent = Directory.GetParent(root)?.FullName ?? root;
        var output = Path.GetFullPath(outputPath ?? Path.Combine(workspaceParent, $"{manifest.Package.Id}.{version.ToNormalizedString()}.nupkg"));
        if (IsPathWithin(root, output)) throw new CliException("Managed package output cannot be inside the workspace.", 1);
        await CreatePackageAsync(manifest, root, output); return output;
    }
    public static async Task UnpackAsync(string packagePath, string destinationPath, string? expectedHash)
    {
        var package = Path.GetFullPath(packagePath); if (!File.Exists(package)) throw new CliException($"Package not found: {package}", 1);
        if (expectedHash is not null) { var h = await Sha256Async(package); if (!HashEquals(h, expectedHash)) throw new CliException($"SHA-256 mismatch. Expected {expectedHash}; actual {h}.", 1); }
        var destination = Path.GetFullPath(destinationPath); if (File.Exists(destination) || Directory.Exists(destination)) throw new CliException($"Destination already exists: {destination}", 1);
        var parent = Path.GetDirectoryName(destination)!; Directory.CreateDirectory(parent); var staging = Path.Combine(parent, "." + Path.GetFileName(destination) + "." + Guid.NewGuid().ToString("N") + ".tmp"); Directory.CreateDirectory(staging);
        try
        {
            var (manifest, inventory) = await ReadPackageManifestAsync(package, true);
            using var reader = new PackageArchiveReader(package);
            foreach (var file in inventory)
            {
                var target = SafeTarget(staging, file.Path);
                Directory.CreateDirectory(Path.GetDirectoryName(target)!);
                await using var stream = File.Create(target);
                await using var input = await reader.GetStreamAsync(Prefix + file.Path, CancellationToken.None);
                await input.CopyToAsync(stream);
            }
            var metadata = Path.Combine(staging, ManifestPath);
            Directory.CreateDirectory(Path.GetDirectoryName(metadata)!);
            await File.WriteAllBytesAsync(metadata, JsonSerializer.SerializeToUtf8Bytes(manifest, ManifestJsonContext.Default.Manifest));
            Directory.Move(staging, destination);
        }
        catch (Exception ex) when (ex is InvalidDataException or PackagingException or System.Xml.XmlException or JsonException or IOException) { throw new CliException("Invalid NuGet package.", 1); }
        finally { if (Directory.Exists(staging)) Directory.Delete(staging, true); }
    }
    public static async Task<string> StatusAsync(string root, string? package)
    {
        if (package is not null) { var (_, files) = await ReadPackageManifestAsync(Path.GetFullPath(package), true); return $"Package valid: {files.Count} files"; }
        root = ResolveWorkspace(root); var baseline = await ReadManifestFileAsync(Path.Combine(root, ManifestPath)); var actual = await InventoryAsync(root); var diff = Diff(baseline.Files, actual);
        return diff.Added.Count + diff.Modified.Count + diff.Deleted.Count == 0 ? "Clean" : $"Added: {string.Join(", ", diff.Added)}\nModified: {string.Join(", ", diff.Modified)}\nDeleted: {string.Join(", ", diff.Deleted)}";
    }
    public static async Task<string> StatusJsonAsync(string root, string? package)
    {
        if (package is not null)
        {
            var (manifest, files) = await ReadPackageManifestAsync(Path.GetFullPath(package), true);
            return JsonSerializer.Serialize(new PackageStatusResult { Package = new() { Id = manifest.Package.Id, Version = manifest.Package.Version }, FileCount = files.Count }, ManifestJsonContext.Default.PackageStatusResult);
        }
        root = ResolveWorkspace(root);
        var baseline = await ReadManifestFileAsync(Path.Combine(root, ManifestPath));
        var diff = Diff(baseline.Files, await InventoryAsync(root));
        var changes = ToJsonChanges(diff);
        return JsonSerializer.Serialize(new WorkspaceStatusResult
        {
            Package = new() { Id = baseline.Package.Id, Version = baseline.Package.Version },
            Clean = changes.Added.Count + changes.Modified.Count + changes.Deleted.Count == 0,
            Changes = changes
        }, ManifestJsonContext.Default.WorkspaceStatusResult);
    }
    public static async Task<string> HistoryAsync(string root, string? package)
    { var manifest = package is null ? await ReadManifestFileAsync(Path.Combine(ResolveWorkspace(root), ManifestPath)) : (await ReadPackageManifestAsync(Path.GetFullPath(package), true)).Manifest; return string.Join(Environment.NewLine, manifest.History.Select(h => $"{h.Version} <- {h.PreviousVersion ?? "(initial)"} | +[{string.Join(",", h.Changes.Added)}] ~[{string.Join(",", h.Changes.Modified)}] -[{string.Join(",", h.Changes.Deleted)}]" + (h.Message is null ? "" : $" | {h.Message}"))); }
    public static async Task<string> HistoryJsonAsync(string root, string? package)
    {
        var manifest = package is null
            ? await ReadManifestFileAsync(Path.Combine(ResolveWorkspace(root), ManifestPath))
            : (await ReadPackageManifestAsync(Path.GetFullPath(package), true)).Manifest;
        var result = new HistoryResult
        {
            Package = new() { Id = manifest.Package.Id, Version = manifest.Package.Version },
            History = manifest.History.Select(h => new JsonHistoryRecord
            {
                Version = h.Version,
                PreviousVersion = h.PreviousVersion,
                Message = h.Message,
                Changes = ToJsonChanges(h.Changes)
            }).ToList()
        };
        return JsonSerializer.Serialize(result, ManifestJsonContext.Default.HistoryResult);
    }
    private static JsonChanges ToJsonChanges(ChangeSet changes) => new() { Added = changes.Added.ToList(), Modified = changes.Modified.ToList(), Deleted = changes.Deleted.ToList() };
    public static async Task<string> Sha256Async(string path) { await using var stream = File.OpenRead(path); return Convert.ToHexString(await SHA256.HashDataAsync(stream)); }
    public static bool HashEquals(string actual, string expected) => Regex.IsMatch(expected, "^[0-9a-fA-F]{64}$") && CryptographicOperations.FixedTimeEquals(Convert.FromHexString(actual), Convert.FromHexString(expected));

    private static async Task CreatePackageAsync(Manifest manifest, string source, string outputPath)
    {
        var output = Path.GetFullPath(outputPath); if (!output.EndsWith(".nupkg", StringComparison.OrdinalIgnoreCase)) throw new CliException("Output path must end in .nupkg.", 1); if (File.Exists(output) || Directory.Exists(output)) throw new CliException($"Output already exists: {output}", 1);
        Directory.CreateDirectory(Path.GetDirectoryName(output)!); var builder = new PackageBuilder { Id = manifest.Package.Id, Version = ParseVersion(manifest.Package.Version), Description = "Immutable arbitrary content snapshot.", Authors = { "dotnet-nuget-content" } };
        builder.ContentFiles.Add(new ManifestContentFiles { Include = "**/*", BuildAction = "None", CopyToOutput = "true", Flatten = "false" });
        foreach (var f in manifest.Files) builder.Files.Add(new PhysicalPackageFile { SourcePath = Path.Combine(source, f.Path.Replace('/', Path.DirectorySeparatorChar)), TargetPath = Prefix + f.Path });
        builder.Files.Add(new BytePackageFile(JsonSerializer.SerializeToUtf8Bytes(manifest, ManifestJsonContext.Default.Manifest), ManifestPath)); var temp = output + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try { await using (var stream = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None)) builder.Save(stream); File.Move(temp, output); } finally { if (File.Exists(temp)) File.Delete(temp); }
    }
    private static async Task<(Manifest Manifest, List<ManifestFile> Files)> ReadPackageManifestAsync(string path, bool verify)
    {
        if (!File.Exists(path)) throw new CliException($"Package not found: {path}", 1);
        try
        {
            using var reader = new PackageArchiveReader(path); var entries = reader.GetFiles().ToArray(); var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase); foreach (var e in entries) { var n = e.Replace('\\', '/'); ValidateArchivePath(n); if (!names.Add(n)) throw new CliException($"Package contains duplicate path '{n}'.", 1); }
            var meta = entries.SingleOrDefault(e => e.Replace('\\', '/') == ManifestPath) ?? throw new CliException("Package is missing .nuget-content/manifest.json.", 1);
            await using var ms = new MemoryStream(); await using (var input = await reader.GetStreamAsync(meta, CancellationToken.None)) await input.CopyToAsync(ms);
            using (var json = JsonDocument.Parse(ms.ToArray())) ValidateManifestJson(json.RootElement);
            var manifestBytes = ms.ToArray();
            var m = JsonSerializer.Deserialize(manifestBytes, ManifestJsonContext.Default.Manifest) ?? throw new CliException("Manifest is empty.", 1); ValidateManifest(m);
            using var ns = reader.GetNuspec(); var nuspec = new NuspecReader(ns); if (!string.Equals(m.Package.Id, nuspec.GetId(), StringComparison.OrdinalIgnoreCase) || ParseVersion(m.Package.Version) != nuspec.GetVersion()) throw new CliException("Manifest package identity/version does not match nuspec.", 1);
            var payload = entries.Select(e => e.Replace('\\', '/')).Where(e => e.StartsWith(Prefix, StringComparison.Ordinal)).Select(e => e[Prefix.Length..]).OrderBy(x => x, StringComparer.Ordinal).ToList(); var inv = new List<ManifestFile>(); foreach (var rel in payload) { await using var content = await reader.GetStreamAsync(Prefix + rel, CancellationToken.None); var (size, hash) = await HashAndSizeAsync(content); inv.Add(new() { Path = rel, Size = size, Sha256 = hash }); }
            if (verify && !InventoryEqual(m.Files, inv)) throw new CliException("Manifest inventory does not match the package contentFiles payload.", 1); return (m, inv);
        }
        catch (CliException) { throw; }
        catch (Exception ex) when (ex is InvalidDataException or PackagingException or System.Xml.XmlException or JsonException or InvalidOperationException or IOException) { throw new CliException("Invalid NuGet package.", 1); }
    }
    private static async Task<(long Size, string Sha256)> HashAndSizeAsync(Stream stream)
    {
        using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        var buffer = ArrayPool<byte>.Shared.Rent(81920);
        long size = 0;
        try
        {
            int read;
            while ((read = await stream.ReadAsync(buffer.AsMemory(0, buffer.Length))) != 0)
            {
                hash.AppendData(buffer, 0, read);
                size += read;
            }
            return (size, Convert.ToHexString(hash.GetHashAndReset()));
        }
        finally { ArrayPool<byte>.Shared.Return(buffer); }
    }
    private static async Task<List<ManifestFile>> InventoryAsync(string root)
    {
        var files = new List<ManifestFile>(); var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var file in Directory.EnumerateFiles(root, "*", SearchOption.AllDirectories)) { var rel = Path.GetRelativePath(root, file).Replace('\\', '/'); if (rel.Equals(ManifestPath, StringComparison.OrdinalIgnoreCase)) continue; if (rel.StartsWith(".nuget-content/", StringComparison.OrdinalIgnoreCase)) throw new CliException($"Reserved content path collision: '{rel}'.", 1); ValidateRelative(rel); if (!seen.Add(rel)) throw new CliException($"Conflicting content path '{rel}'.", 1); files.Add(new() { Path = rel, Size = new FileInfo(file).Length, Sha256 = await Sha256Async(file) }); }
        files.Sort((a, b) => StringComparer.Ordinal.Compare(a.Path, b.Path)); return files;
    }
    private static ChangeSet Diff(List<ManifestFile> old, List<ManifestFile> now) { var a = old.ToDictionary(f => f.Path, StringComparer.Ordinal); var b = now.ToDictionary(f => f.Path, StringComparer.Ordinal); var c = new ChangeSet(); foreach (var f in now) { if (!a.TryGetValue(f.Path, out var prior)) c.Added.Add(f.Path); else if (prior.Sha256 != f.Sha256) c.Modified.Add(f.Path); } foreach (var f in old) if (!b.ContainsKey(f.Path)) c.Deleted.Add(f.Path); c.Added.Sort(StringComparer.Ordinal); c.Modified.Sort(StringComparer.Ordinal); c.Deleted.Sort(StringComparer.Ordinal); return c; }
    private static bool IsPathWithin(string root, string candidate)
    {
        var relative = Path.GetRelativePath(root, candidate);
        return relative == "." || (!Path.IsPathRooted(relative) && relative != ".." && !relative.StartsWith(".." + Path.DirectorySeparatorChar, StringComparison.Ordinal));
    }
    private static bool InventoryEqual(List<ManifestFile> a, List<ManifestFile> b) => a.Count == b.Count && a.Zip(b).All(x => x.First.Path == x.Second.Path && x.First.Size == x.Second.Size && x.First.Sha256 == x.Second.Sha256);
    internal static void ValidateManifestJson(JsonElement root)
    {
        ValidateObject(root, "manifest", ["schemaVersion", "package", "files", "history"]);
        var schemaVersion = root.GetProperty("schemaVersion");
        if (schemaVersion.ValueKind != JsonValueKind.Number || !schemaVersion.TryGetInt32(out var number) || number != 1)
            throw new CliException("Manifest schemaVersion must be the integer 1.", 1);

        var package = root.GetProperty("package");
        ValidateObject(package, "package", ["id", "version"]);
        RequireString(package.GetProperty("id"), "package.id");
        RequireString(package.GetProperty("version"), "package.version");

        var files = root.GetProperty("files");
        RequireArray(files, "files");
        foreach (var file in files.EnumerateArray())
        {
            ValidateObject(file, "files[]", ["path", "size", "sha256"]);
            RequireString(file.GetProperty("path"), "files[].path");
            var size = file.GetProperty("size");
            if (size.ValueKind != JsonValueKind.Number || !size.TryGetInt64(out var fileSize) || fileSize < 0)
                throw new CliException("Manifest files[].size must be a non-negative integer.", 1);
            var sha = RequireString(file.GetProperty("sha256"), "files[].sha256");
            if (!Regex.IsMatch(sha, "^[0-9A-F]{64}$", RegexOptions.CultureInvariant))
                throw new CliException("Manifest files[].sha256 must be 64 uppercase hexadecimal characters.", 1);
        }

        var history = root.GetProperty("history");
        RequireArray(history, "history");
        if (history.GetArrayLength() == 0) throw new CliException("Manifest history must contain at least one entry.", 1);
        foreach (var record in history.EnumerateArray())
        {
            ValidateObject(record, "history[]", ["version", "previousVersion", "changes"], ["message"]);
            RequireString(record.GetProperty("version"), "history[].version");
            var previous = record.GetProperty("previousVersion");
            if (previous.ValueKind is not (JsonValueKind.Null or JsonValueKind.String))
                throw new CliException("Manifest history[].previousVersion must be a string or null.", 1);
            if (previous.ValueKind == JsonValueKind.String) RequireString(previous, "history[].previousVersion");
            if (record.TryGetProperty("message", out var message)) RequireString(message, "history[].message");

            var changes = record.GetProperty("changes");
            ValidateObject(changes, "history[].changes", ["added", "modified", "deleted"]);
            foreach (var name in new[] { "added", "modified", "deleted" })
            {
                var paths = changes.GetProperty(name);
                RequireArray(paths, $"history[].changes.{name}");
                var unique = new HashSet<string>(StringComparer.Ordinal);
                foreach (var path in paths.EnumerateArray())
                    if (!unique.Add(RequireString(path, $"history[].changes.{name}[]")))
                        throw new CliException($"Manifest history[].changes.{name} contains a duplicate path.", 1);
            }
        }
    }

    private static void ValidateObject(JsonElement value, string label, string[] required, string[]? optional = null)
    {
        if (value.ValueKind != JsonValueKind.Object) throw new CliException($"Manifest {label} must be an object.", 1);
        var allowed = required.Concat(optional ?? []).ToHashSet(StringComparer.Ordinal);
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var property in value.EnumerateObject())
        {
            if (!seen.Add(property.Name)) throw new CliException($"Manifest contains duplicate property '{property.Name}'.", 1);
            if (!allowed.Contains(property.Name)) throw new CliException($"Manifest {label} contains unknown property '{property.Name}'.", 1);
        }
        foreach (var name in required)
            if (!seen.Contains(name)) throw new CliException($"Manifest {label} is missing required property '{name}'.", 1);
    }

    private static void RequireArray(JsonElement value, string label)
    {
        if (value.ValueKind != JsonValueKind.Array) throw new CliException($"Manifest {label} must be an array.", 1);
    }

    private static string RequireString(JsonElement value, string label)
    {
        if (value.ValueKind != JsonValueKind.String || string.IsNullOrEmpty(value.GetString()))
            throw new CliException($"Manifest {label} must be a non-empty string.", 1);
        return value.GetString()!;
    }

    internal static void ValidateManifest(Manifest m)
    {
        if (m.SchemaVersion != 1) throw new CliException($"Unsupported manifest schemaVersion '{m.SchemaVersion}'.", 1);
        ValidateIdentity(m.Package.Id);
        if (ParseVersion(m.Package.Version).ToNormalizedString() != m.Package.Version) throw new CliException("Manifest package.version must be normalized.", 1);
        var versions = new List<NuGetVersion>();
        foreach (var h in m.History)
        {
            var hv = ParseVersion(h.Version);
            if (hv.ToNormalizedString() != h.Version) throw new CliException("Manifest history versions must be normalized.", 1);
            versions.Add(hv);
            if (h.Message is not null && string.IsNullOrWhiteSpace(h.Message)) throw new CliException("Manifest history message must not be blank.", 1);
        }
        if (versions.Count == 0 || m.History[^1].Version != m.Package.Version) throw new CliException("Manifest history must end at package.version.", 1);
        for (int i = 0; i < versions.Count; i++)
        {
            if (i > 0 && (versions[i] <= versions[i - 1] || m.History[i].PreviousVersion != m.History[i - 1].Version))
                throw new CliException("Manifest history versions or previousVersion links are inconsistent.", 1);
            if (i == 0 && m.History[i].PreviousVersion is not null) throw new CliException("Initial history previousVersion must be null.", 1);
        }
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        string? prev = null;
        foreach (var f in m.Files)
        {
            ValidateRelative(f.Path);
            if (!seen.Add(f.Path)) throw new CliException($"Duplicate manifest path '{f.Path}'.", 1);
            if (!Regex.IsMatch(f.Sha256, "^[0-9A-F]{64}$")) throw new CliException($"Invalid SHA-256 for '{f.Path}'.", 1);
            if (prev is not null && StringComparer.Ordinal.Compare(prev, f.Path) >= 0) throw new CliException("Manifest files must be in ordinal path order.", 1);
            prev = f.Path;
        }
        foreach (var h in m.History)
        {
            var all = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var list in new[] { h.Changes.Added, h.Changes.Modified, h.Changes.Deleted })
            {
                string? p = null;
                foreach (var x in list)
                {
                    ValidateRelative(x);
                    if (!all.Add(x) || p is not null && StringComparer.Ordinal.Compare(p, x) >= 0) throw new CliException("History change paths must be distinct and ordinally sorted.", 1);
                    p = x;
                }
            }
        }
        var initial = m.History[0];
        if (initial.PreviousVersion is not null || initial.Changes.Added.Count == 0 || initial.Changes.Modified.Count != 0 || initial.Changes.Deleted.Count != 0)
            throw new CliException("Initial history must have a null predecessor and empty modified/deleted lists.", 1);
        if (m.History.Count == 1 && !initial.Changes.Added.SequenceEqual(m.Files.Select(f => f.Path), StringComparer.Ordinal))
            throw new CliException("Initial history added paths must match the manifest file inventory.", 1);
    }

    private static async Task<Manifest> ReadManifestFileAsync(string path)
    {
        if (!File.Exists(path)) throw new CliException($"Managed workspace marker not found: {path}", 1);
        try
        {
            var bytes = await File.ReadAllBytesAsync(path);
            using (var json = JsonDocument.Parse(bytes)) ValidateManifestJson(json.RootElement);
            var manifest = JsonSerializer.Deserialize(bytes, ManifestJsonContext.Default.Manifest) ?? throw new JsonException();
            ValidateManifest(manifest);
            return manifest;
        }
        catch (CliException) { throw; }
        catch (Exception e) when (e is JsonException or IOException) { throw new CliException($"Invalid managed workspace marker '{path}': {e.Message}", 1); }
    }
    private static string ResolveWorkspace(string root) { var p = Path.GetFullPath(root); if (!Directory.Exists(p)) throw new CliException($"Workspace directory not found: {p}", 1); RejectReparsePoints(p); return p; }
    private static NuGetVersion ParseVersion(string s) => s.Contains('*') || !NuGetVersion.TryParse(s, out var v) ? throw new CliException($"Invalid exact NuGet version '{s}'.") : v;
    private static void ValidateIdentity(string id) { if (!IdPattern.IsMatch(id)) throw new CliException($"Invalid NuGet package ID '{id}'."); }
    private static string SafeTarget(string root, string rel) { var target = Path.GetFullPath(Path.Combine(root, rel.Replace('/', Path.DirectorySeparatorChar))); if (!target.StartsWith(root.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)) throw new CliException($"Unsafe content path '{rel}'.", 1); return target; }
    private static void RejectReparsePoints(string root) { foreach (var e in Directory.EnumerateFileSystemEntries(root, "*", SearchOption.AllDirectories).Prepend(root)) if ((File.GetAttributes(e) & FileAttributes.ReparsePoint) != 0) throw new CliException($"Symbolic links and reparse points are not allowed: {e}", 1); }
    private static void ValidateArchivePath(string p) { if (string.IsNullOrWhiteSpace(p) || p.StartsWith('/') || p.Contains(':') || p.Split('/').Any(x => x is ".." or "." || x.Length == 0)) throw new CliException($"Unsafe package path '{p}'.", 1); }
    private static void ValidateRelative(string p) { if (string.IsNullOrWhiteSpace(p) || p.StartsWith('/') || p.Contains(':') || p.Split('/').Any(x => x is ".." or "." || x.Length == 0) || p.Split('/')[0].Equals(".nuget-content", StringComparison.OrdinalIgnoreCase)) throw new CliException($"Unsafe or reserved content path '{p}'.", 1); }
}
internal sealed class BytePackageFile(byte[] bytes, string target) : IPackageFile
{ public string Path => target; public string EffectivePath => target; public System.Runtime.Versioning.FrameworkName TargetFramework => new("Any,Version=v0.0"); public NuGetFramework NuGetFramework => NuGetFramework.AnyFramework; public DateTimeOffset LastWriteTime => DateTimeOffset.UnixEpoch; public IEnumerable<FrameworkSpecificGroup> SupportedFrameworks => []; public Stream GetStream() => new MemoryStream(bytes, false); }
