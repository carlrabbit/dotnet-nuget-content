using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Xml;
using System.Xml.Linq;

internal sealed class ProjectWorkspaceManifest
{
    public int SchemaVersion { get; set; } = 1;
    public List<ProjectWorkspaceMember> Members { get; set; } = [];
}

internal sealed class ProjectWorkspaceMember
{
    public string Alias { get; set; } = "";
    public string PackageId { get; set; } = "";
    public string Version { get; set; } = "";
    public string PackageFile { get; set; } = "";
    public string Directory { get; set; } = "";
}

internal sealed class WorkspaceListMemberResult
{
    public string Alias { get; set; } = "";
    public string PackageId { get; set; } = "";
    public string Version { get; set; } = "";
    public string PackageFile { get; set; } = "";
    public string Directory { get; set; } = "";
    public bool DirectoryPresent { get; set; }
}

internal sealed class WorkspaceListResult
{
    public int SchemaVersion { get; set; } = 1;
    public string Kind { get; set; } = "workspaceList";
    public List<WorkspaceListMemberResult> Members { get; set; } = [];
}

internal sealed class WorkspaceStatusMemberResult
{
    public string Alias { get; set; } = "";
    public string PackageId { get; set; } = "";
    public string Version { get; set; } = "";
    public string State { get; set; } = "";
    public List<string> Added { get; set; } = [];
    public List<string> Modified { get; set; } = [];
    public List<string> Deleted { get; set; } = [];
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] public string? Error { get; set; }
}

internal sealed class ProjectWorkspaceStatusResult
{
    public int SchemaVersion { get; set; } = 1;
    public string Kind { get; set; } = "workspaceStatus";
    public List<WorkspaceStatusMemberResult> Members { get; set; } = [];
}

internal sealed class WorkspaceUsageResult
{
    public int SchemaVersion { get; set; } = 1;
    public string Kind { get; set; } = "workspaceUsage";
    public List<WorkspaceUsageMemberResult> Members { get; set; } = [];
    public List<string> Diagnostics { get; set; } = [];
}

internal sealed class WorkspaceUsageMemberResult
{
    public string Alias { get; set; } = "";
    public string PackageId { get; set; } = "";
    public List<WorkspaceUsageSite> UseSites { get; set; } = [];
    public List<WorkspaceUsageSite> CentralVersionDeclarations { get; set; } = [];
    public List<WorkspaceAssetEvidence> PreviousAssetsEvidence { get; set; } = [];
}

internal sealed class WorkspaceUsageSite
{
    public string Path { get; set; } = "";
    public string Classification { get; set; } = "";
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] public string? CentralVersion { get; set; }
}

internal sealed class WorkspaceAssetEvidence
{
    public string Project { get; set; } = "";
    public string AssetsFile { get; set; } = "";
    public string State { get; set; } = "previousRestoreUnknownFreshness";
    public string Version { get; set; } = "";
}

[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase, WriteIndented = false, UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow)]
[JsonSerializable(typeof(ProjectWorkspaceManifest))]
[JsonSerializable(typeof(WorkspaceListResult))]
[JsonSerializable(typeof(ProjectWorkspaceStatusResult))]
[JsonSerializable(typeof(WorkspaceUsageResult))]
internal partial class ProjectWorkspaceJsonContext : JsonSerializerContext { }

internal static class ProjectWorkspace
{
    private const string Marker = "nuget-content.json";
    private const int MaxProjectFiles = 10000;
    private const int MaxScanEntries = 250000;
    private static readonly HashSet<string> ProjectExtensions = new(StringComparer.OrdinalIgnoreCase) { ".csproj", ".fsproj", ".vbproj", ".esproj", ".njsproj", ".vcxproj", ".sqlproj", ".shproj", ".dbproj", ".wixproj", ".dcproj", ".proj" };

    public static async Task<int> RunAsync(string[] args)
    {
        if (args.Length == 0 || args[0] is "--help" or "-h") { Console.Out.WriteLine(Help); return 0; }
        var command = args[0];
        var options = Parse(args[1..]);
        switch (command)
        {
            case "init":
                Ensure(options, "workspace");
                var initRoot = ResolveRoot(options.GetValueOrDefault("workspace"));
                var marker = Path.Combine(initRoot, Marker);
                if (File.Exists(marker)) throw new CliException($"Project workspace marker already exists: {marker}", 1);
                await WriteNewAsync(marker, new ProjectWorkspaceManifest());
                Console.WriteLine($"Initialized project workspace: {marker}"); return 0;
            case "add": return await AddAsync(options);
            case "list": return await ListAsync(options);
            case "unpack": return await UnpackAsync(options);
            case "status": return await StatusAsync(options);
            case "pack": return await PackAsync(options);
            case "set": return await SetAsync(options);
            case "usage": return await UsageAsync(options);
            default: throw new CliException($"Unknown workspace command '{command}'. Run 'dotnet-nuget-content workspace --help'.");
        }
    }

    private static async Task<int> AddAsync(Dictionary<string, string> options)
    {
        Ensure(options, "alias", "package", "directory", "workspace");
        var root = ResolveRoot(options.GetValueOrDefault("workspace")); var (path, manifest) = await ReadRootAsync(root);
        var alias = Required(options, "alias"); ValidateAlias(alias);
        if (manifest.Members.Any(m => string.Equals(m.Alias, alias, StringComparison.OrdinalIgnoreCase))) throw new CliException($"Workspace alias already exists: {alias}", 1);
        var packagePath = ResolveInput(root, Required(options, "package"));
        if (!File.Exists(packagePath)) throw new CliException($"Package not found: {packagePath}", 1);
        var package = await ContentPackages.ReadPackageForWorkspaceAsync(packagePath);
        var packageRel = RelativeFromRoot(root, packagePath);
        if (!packageRel.EndsWith(".nupkg", StringComparison.OrdinalIgnoreCase)) throw new CliException("Workspace packageFile must refer to a local .nupkg file.", 1);
        var dir = NormalizeRelative(options.GetValueOrDefault("directory") ?? $"content/{alias}", "directory");
        var member = new ProjectWorkspaceMember { Alias = alias, PackageId = package.Package.Id, Version = package.Package.Version, PackageFile = packageRel, Directory = dir };
        var candidate = manifest.Members.Append(member).ToList(); ValidateMembers(candidate, root);
        manifest.Members = candidate;
        await WriteAtomicAsync(path, manifest);
        Console.WriteLine($"Added {alias}: {package.Package.Id} {package.Package.Version} ({packageRel})"); return 0;
    }

    private static async Task<int> ListAsync(Dictionary<string, string> options)
    {
        Ensure(options, "workspace", "json"); var root = ResolveRoot(options.GetValueOrDefault("workspace")); var (_, manifest) = await ReadRootAsync(root);
        var members = manifest.Members.OrderBy(m => m.Alias, StringComparer.OrdinalIgnoreCase).ThenBy(m => m.Alias, StringComparer.Ordinal)
            .Select(m => new WorkspaceListMemberResult { Alias = m.Alias, PackageId = m.PackageId, Version = m.Version, PackageFile = m.PackageFile, Directory = m.Directory, DirectoryPresent = Directory.Exists(ResolvePath(root, m.Directory)) }).ToList();
        if (options.ContainsKey("json")) Console.WriteLine(JsonSerializer.Serialize(new WorkspaceListResult { Members = members }, ProjectWorkspaceJsonContext.Default.WorkspaceListResult));
        else if (members.Count == 0) Console.WriteLine("No workspace members.");
        else foreach (var m in members) Console.WriteLine($"{m.Alias}: {m.PackageId} {m.Version} | {m.PackageFile} | {m.Directory} | {(m.DirectoryPresent ? "present" : "not unpacked")}");
        return 0;
    }

    private static async Task<int> UnpackAsync(Dictionary<string, string> options)
    {
        Ensure(options, "alias", "all", "workspace"); EnsureExclusive(options, "alias", "all");
        if (!options.ContainsKey("alias") && !options.ContainsKey("all")) throw new CliException("Specify '--alias NAME' or '--all'.");
        var root = ResolveRoot(options.GetValueOrDefault("workspace")); var (_, manifest) = await ReadRootAsync(root); var selected = Select(manifest, options);
        var outcomes = new List<(string Alias, bool Ok, string Text)>();
        foreach (var m in selected)
        {
            var dest = ResolvePath(root, m.Directory); var package = ResolvePath(root, m.PackageFile);
            try
            {
                var embedded = await ContentPackages.ReadPackageForWorkspaceAsync(package);
                VerifyPin(m, embedded);
                await ContentPackages.UnpackAsync(package, dest, null);
                outcomes.Add((m.Alias, true, "unpacked"));
            }
            catch (Exception ex) when (ex is CliException or IOException or UnauthorizedAccessException)
            { outcomes.Add((m.Alias, false, ex.Message)); }
        }
        foreach (var item in outcomes) Console.WriteLine($"{item.Alias}: {(item.Ok ? item.Text : "failed: " + item.Text)}");
        return outcomes.All(x => x.Ok) ? 0 : 1;
    }

    private static async Task<int> StatusAsync(Dictionary<string, string> options)
    {
        Ensure(options, "alias", "all", "workspace", "json"); EnsureExclusive(options, "alias", "all");
        var root = ResolveRoot(options.GetValueOrDefault("workspace")); var (_, manifest) = await ReadRootAsync(root);
        var selected = options.ContainsKey("alias") || options.ContainsKey("all") ? Select(manifest, options) : manifest.Members.OrderBy(m => m.Alias, StringComparer.OrdinalIgnoreCase).ToList();
        var results = new List<WorkspaceStatusMemberResult>();
        foreach (var m in selected)
        {
            var dir = ResolvePath(root, m.Directory); var r = new WorkspaceStatusMemberResult { Alias = m.Alias, PackageId = m.PackageId, Version = m.Version };
            if (!Directory.Exists(dir)) { r.State = "missing"; results.Add(r); continue; }
            try
            {
                var baseline = await ContentPackages.ReadWorkspaceBaselineForWorkspaceAsync(dir);
                if (!string.Equals(baseline.Package.Id, m.PackageId, StringComparison.OrdinalIgnoreCase) || baseline.Package.Version != m.Version)
                    throw new CliException($"Managed baseline is {baseline.Package.Id} {baseline.Package.Version}, but pin is {m.PackageId} {m.Version}.", 1);
                var json = await ContentPackages.StatusJsonAsync(dir, null); using var doc = JsonDocument.Parse(json); var changes = doc.RootElement.GetProperty("changes");
                r.Added = ReadPaths(changes.GetProperty("added")); r.Modified = ReadPaths(changes.GetProperty("modified")); r.Deleted = ReadPaths(changes.GetProperty("deleted"));
                r.State = doc.RootElement.GetProperty("clean").GetBoolean() ? "clean" : "modified";
            }
            catch (Exception ex) when (ex is CliException or IOException or JsonException)
            { r.State = ex.Message.Contains("but pin is", StringComparison.Ordinal) ? "mismatched" : "corrupt"; r.Error = ex.Message; }
            results.Add(r);
        }
        if (options.ContainsKey("json")) Console.WriteLine(JsonSerializer.Serialize(new ProjectWorkspaceStatusResult { Members = results }, ProjectWorkspaceJsonContext.Default.ProjectWorkspaceStatusResult));
        else foreach (var r in results) Console.WriteLine($"{r.Alias}: {r.State}" + (r.Error is null ? "" : $" ({r.Error})") + (r.Added.Count + r.Modified.Count + r.Deleted.Count == 0 ? "" : $" | +[{string.Join(",", r.Added)}] ~[{string.Join(",", r.Modified)}] -[{string.Join(",", r.Deleted)}]"));
        return results.Any(r => r.State is "corrupt" or "mismatched") ? 1 : 0;
    }

    private static async Task<int> PackAsync(Dictionary<string, string> options)
    {
        Ensure(options, "alias", "version", "output", "message", "workspace"); var root = ResolveRoot(options.GetValueOrDefault("workspace")); var (_, manifest) = await ReadRootAsync(root);
        var m = FindMember(manifest, Required(options, "alias")); var dir = ResolvePath(root, m.Directory);
        if (!Directory.Exists(dir)) throw new CliException($"Workspace member directory is missing: {m.Directory}", 1);
        var output = options.TryGetValue("output", out var specified) ? ResolveInput(root, specified) : null;
        if (output is not null) EnsurePackageOutputOutsideMembers(root, output, manifest.Members);
        else
        {
            // Legacy managed-pack output is the member directory's parent; keep it outside every member root.
            var candidate = Path.Combine(Directory.GetParent(dir)?.FullName ?? root, $"{m.PackageId}.{Required(options, "version")}.nupkg");
            EnsurePackageOutputOutsideMembers(root, candidate, manifest.Members);
        }
        var created = await ContentPackages.PackManagedAsync(dir, Required(options, "version"), output, options.GetValueOrDefault("message"));
        Console.WriteLine($"Created {created}"); Console.WriteLine($"Workspace pin remains {m.PackageId} {m.Version}; use 'workspace set --alias {m.Alias} --package <new-package>' to advance it."); return 0;
    }

    private static async Task<int> SetAsync(Dictionary<string, string> options)
    {
        Ensure(options, "alias", "package", "workspace"); var root = ResolveRoot(options.GetValueOrDefault("workspace")); var (path, manifest) = await ReadRootAsync(root); var m = FindMember(manifest, Required(options, "alias"));
        var packagePath = ResolveInput(root, Required(options, "package")); if (!File.Exists(packagePath)) throw new CliException($"Package not found: {packagePath}", 1);
        var next = await ContentPackages.ReadPackageForWorkspaceAsync(packagePath);
        if (!string.Equals(next.Package.Id, m.PackageId, StringComparison.OrdinalIgnoreCase)) throw new CliException($"Package ID must remain '{m.PackageId}'.", 1);
        if (NuGet.Versioning.NuGetVersion.Parse(next.Package.Version) <= NuGet.Versioning.NuGetVersion.Parse(m.Version)) throw new CliException("Workspace pin version must increase.", 1);
        var dir = ResolvePath(root, m.Directory);
        if (Directory.Exists(dir))
        {
            var baseline = await ContentPackages.ReadWorkspaceBaselineForWorkspaceAsync(dir);
            if (!string.Equals(baseline.Package.Id, next.Package.Id, StringComparison.OrdinalIgnoreCase) || baseline.Package.Version != next.Package.Version || !await ContentPackages.IsWorkspaceCleanForWorkspaceAsync(dir))
                throw new CliException("Cannot advance the pin while the current working directory has a different or modified baseline; unpack the new package into a new directory before changing the member directory.", 1);
        }
        var rel = RelativeFromRoot(root, packagePath); if (!rel.EndsWith(".nupkg", StringComparison.OrdinalIgnoreCase)) throw new CliException("Workspace packageFile must refer to a local .nupkg file.", 1);
        var old = m.PackageFile; m.PackageFile = rel; m.Version = next.Package.Version; ValidateMembers(manifest.Members, root); await WriteAtomicAsync(path, manifest);
        Console.WriteLine($"Updated {m.Alias}: {m.PackageId} {m.Version} ({old} -> {rel})"); return 0;
    }

    private static async Task<int> UsageAsync(Dictionary<string, string> options)
    {
        Ensure(options, "alias", "all", "workspace", "json"); EnsureExclusive(options, "alias", "all");
        var root = ResolveRoot(options.GetValueOrDefault("workspace")); var (_, manifest) = await ReadRootAsync(root);
        var selected = options.ContainsKey("alias") || options.ContainsKey("all") ? Select(manifest, options) : manifest.Members.OrderBy(m => m.Alias, StringComparer.OrdinalIgnoreCase).ToList();
        var output = await DiscoverUsageAsync(root, manifest, selected);
        if (options.ContainsKey("json")) Console.WriteLine(JsonSerializer.Serialize(output, ProjectWorkspaceJsonContext.Default.WorkspaceUsageResult));
        else
        {
            foreach (var m in output.Members)
            {
                Console.WriteLine($"{m.Alias} ({m.PackageId}):");
                foreach (var s in m.UseSites) Console.WriteLine($"  use {s.Path}: {s.Classification}" + (s.CentralVersion is null ? "" : $" ({s.CentralVersion})"));
                foreach (var s in m.CentralVersionDeclarations) Console.WriteLine($"  central version only {s.Path}: {s.Classification}");
                foreach (var a in m.PreviousAssetsEvidence) Console.WriteLine($"  previous assets evidence {a.AssetsFile}: {a.Version} (freshness unknown)");
            }
            foreach (var d in output.Diagnostics) Console.Error.WriteLine($"diagnostic: {d}");
        }
        return output.Diagnostics.Count == 0 ? 0 : 1;
    }

    private static async Task<WorkspaceUsageResult> DiscoverUsageAsync(string root, ProjectWorkspaceManifest manifest, List<ProjectWorkspaceMember> selected)
    {
        var result = new WorkspaceUsageResult();
        var selectedIds = selected.Select(m => m.PackageId).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
        var aggregate = selectedIds.ToDictionary(x => x, _ => new List<WorkspaceUsageSite>(), StringComparer.OrdinalIgnoreCase);
        var assetsFound = new List<(string Id, string Project, string Assets, string Version)>();
        var diagnostics = result.Diagnostics;
        var exclude = manifest.Members.Select(m => ResolvePath(root, m.Directory)).ToArray();
        var projectFiles = new List<string>(); var dirs = new Stack<(string Path, int Depth)>(); dirs.Push((root, 0));
        var scannedEntries = 0;
        while (dirs.Count > 0)
        {
            var (dir, depth) = dirs.Pop();
            if (depth > 40) { diagnostics.Add($"Traversal depth limit reached at {Relative(root, dir)}."); continue; }
            IEnumerable<string> entries;
            try { entries = Directory.EnumerateFileSystemEntries(dir); }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException) { diagnostics.Add($"Cannot scan {Relative(root, dir)}: {e.Message}"); continue; }
            try
            {
                foreach (var entry in entries)
                {
                    if (++scannedEntries > MaxScanEntries) { diagnostics.Add($"Usage scan stopped after {MaxScanEntries} filesystem entries; narrow the selected project root."); dirs.Clear(); break; }
                    var name = Path.GetFileName(entry);
                    FileAttributes attributes;
                    try { attributes = File.GetAttributes(entry); }
                    catch (Exception e) when (e is IOException or UnauthorizedAccessException) { diagnostics.Add($"Cannot inspect {Relative(root, entry)}: {e.Message}"); continue; }
                    if ((attributes & FileAttributes.ReparsePoint) != 0) continue;
                    if ((attributes & FileAttributes.Directory) != 0)
                    {
                        if (name.Equals(".git", StringComparison.OrdinalIgnoreCase) || name.Equals(".vs", StringComparison.OrdinalIgnoreCase) || name.Equals(".idea", StringComparison.OrdinalIgnoreCase) || name.Equals("bin", StringComparison.OrdinalIgnoreCase) || name.Equals("obj", StringComparison.OrdinalIgnoreCase) || name.Equals("node_modules", StringComparison.OrdinalIgnoreCase) || name.Equals("packages", StringComparison.OrdinalIgnoreCase) || name.Equals("TestResults", StringComparison.OrdinalIgnoreCase) || name.Equals("artifacts", StringComparison.OrdinalIgnoreCase) || name.Equals("dist", StringComparison.OrdinalIgnoreCase) || name.Equals("target", StringComparison.OrdinalIgnoreCase) || exclude.Any(x => IsWithin(x, entry))) continue;
                        dirs.Push((entry, depth + 1));
                    }
                    else if (ProjectExtensions.Contains(Path.GetExtension(entry)) || name.Equals("Directory.Packages.props", StringComparison.OrdinalIgnoreCase))
                    {
                        projectFiles.Add(entry);
                        if (projectFiles.Count > MaxProjectFiles) throw new CliException($"Usage scan stopped after {MaxProjectFiles} project/configuration files; narrow the selected project root.", 1);
                    }
                }
            }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException) { diagnostics.Add($"Cannot finish scanning {Relative(root, dir)}: {e.Message}"); }
        }
        var centralFiles = new Dictionary<string, Dictionary<string, string>>(StringComparer.OrdinalIgnoreCase);
        var centralDeclarations = selectedIds.ToDictionary(x => x, _ => new List<(string Version, string Path)>(), StringComparer.OrdinalIgnoreCase);
        foreach (var file in projectFiles.Where(p => Path.GetFileName(p).Equals("Directory.Packages.props", StringComparison.OrdinalIgnoreCase)).OrderBy(p => Relative(root, p), StringComparer.Ordinal))
        {
            try
            {
                var xml = await LoadXmlAsync(file);
                var fileVersions = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                foreach (var node in xml.Descendants().Where(e => e.Name.LocalName == "PackageVersion"))
                {
                    var id = (string?)node.Attribute("Include") ?? (string?)node.Attribute("Update"); if (id is null) continue;
                    var version = (string?)node.Attribute("Version") ?? node.Elements().FirstOrDefault(e => e.Name.LocalName == "Version")?.Value ?? "";
                    if (selectedIds.Contains(id, StringComparer.OrdinalIgnoreCase))
                    {
                        fileVersions[id] = version;
                        centralDeclarations[id].Add((version, Relative(root, file)));
                    }
                }
                centralFiles[Path.GetFullPath(file)] = fileVersions;
            }
            catch (Exception e) when (e is XmlException or IOException or UnauthorizedAccessException) { diagnostics.Add($"Malformed project configuration {Relative(root, file)}: {e.Message}"); }
        }
        var projects = projectFiles.Where(p => ProjectExtensions.Contains(Path.GetExtension(p))).OrderBy(p => Relative(root, p), StringComparer.Ordinal).ToList();
        foreach (var file in projects)
        {
            try
            {
                var xml = await LoadXmlAsync(file); var rel = Relative(root, file); var nearestCentral = FindCentralVersions(root, Path.GetDirectoryName(file)!, centralFiles);
                foreach (var node in xml.Descendants().Where(e => e.Name.LocalName == "PackageReference"))
                {
                    var id = (string?)node.Attribute("Include") ?? (string?)node.Attribute("Update"); if (id is null) continue;
                    if (id.Contains("$", StringComparison.Ordinal) || id.Contains("%", StringComparison.Ordinal))
                    {
                        diagnostics.Add($"Unresolved dynamic PackageReference identity in {rel}: {id}");
                        continue;
                    }
                    if (!aggregate.TryGetValue(id, out var sites)) continue;
                    var raw = (string?)node.Attribute("Version") ?? node.Elements().FirstOrDefault(e => e.Name.LocalName == "Version")?.Value;
                    if (raw is null)
                    {
                        if (nearestCentral.TryGetValue(id, out var centralVersion)) sites.Add(new() { Path = rel, Classification = "directPackageReferenceWithCentralVersion", CentralVersion = centralVersion });
                        else sites.Add(new() { Path = rel, Classification = "directPackageReferenceUnresolvedVersion" });
                    }
                    else if (raw.Contains('$') || raw.Contains("*", StringComparison.Ordinal)) sites.Add(new() { Path = rel, Classification = "directPackageReferenceDynamicVersion" });
                    else sites.Add(new() { Path = rel, Classification = "directPackageReference" });
                }
            }
            catch (Exception e) when (e is XmlException or IOException or UnauthorizedAccessException) { diagnostics.Add($"Malformed project file {Relative(root, file)}: {e.Message}"); }
            var assets = Path.Combine(Path.GetDirectoryName(file)!, "obj", "project.assets.json");
            if (File.Exists(assets))
            {
                try
                {
                    var fi = new FileInfo(assets); if (fi.Length > 32 * 1024 * 1024) throw new IOException("assets file exceeds 32 MiB inspection limit");
                    using var doc = JsonDocument.Parse(await File.ReadAllBytesAsync(assets));
                    if (doc.RootElement.TryGetProperty("libraries", out var libs) && libs.ValueKind == JsonValueKind.Object)
                    foreach (var lib in libs.EnumerateObject())
                    {
                        var split = lib.Name.LastIndexOf('/'); if (split <= 0) continue; var id = lib.Name[..split]; var ver = lib.Name[(split + 1)..];
                        if (selectedIds.Contains(id, StringComparer.OrdinalIgnoreCase))
                            assetsFound.Add((id, Relative(root, file), Relative(root, assets), ver));
                    }
                }
                catch (Exception e) when (e is JsonException or IOException or UnauthorizedAccessException) { diagnostics.Add($"Cannot inspect previous assets {Relative(root, assets)}: {e.Message}"); }
            }
        }
        foreach (var m in selected)
        {
            var usage = new WorkspaceUsageMemberResult { Alias = m.Alias, PackageId = m.PackageId };
            if (aggregate.TryGetValue(m.PackageId, out var sites)) usage.UseSites = sites.OrderBy(s => s.Path, StringComparer.Ordinal).ToList();
            if (centralDeclarations.TryGetValue(m.PackageId, out var declarations))
                usage.CentralVersionDeclarations = declarations.Distinct().OrderBy(x => x.Path, StringComparer.Ordinal).Select(x => new WorkspaceUsageSite { Path = x.Path, Classification = "centralVersionDeclarationNotUseByItself", CentralVersion = x.Version }).ToList();
            usage.PreviousAssetsEvidence = assetsFound.Where(a => a.Id.Equals(m.PackageId, StringComparison.OrdinalIgnoreCase)).Select(a => new WorkspaceAssetEvidence { Project = a.Project, AssetsFile = a.Assets, Version = a.Version }).OrderBy(a => a.Project, StringComparer.Ordinal).ThenBy(a => a.Version, StringComparer.Ordinal).ToList();
            result.Members.Add(usage);
        }
        result.Diagnostics = diagnostics.Distinct(StringComparer.Ordinal).OrderBy(x => x, StringComparer.Ordinal).ToList();
        return result;
    }

    private static Dictionary<string, string> FindCentralVersions(string root, string projectDirectory, Dictionary<string, Dictionary<string, string>> centralFiles)
    {
        var current = projectDirectory;
        while (IsWithin(root, current))
        {
            var config = Path.Combine(current, "Directory.Packages.props");
            if (File.Exists(config)) return centralFiles.TryGetValue(config, out var versions) ? versions : new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            if (string.Equals(current, root, StringComparison.OrdinalIgnoreCase)) break;
            current = Directory.GetParent(current)?.FullName ?? root;
        }
        return new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
    }

    private static async Task<XDocument> LoadXmlAsync(string path)
    {
        var settings = new XmlReaderSettings { Async = true, DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null, MaxCharactersInDocument = 8 * 1024 * 1024 };
        await using var stream = File.OpenRead(path); using var reader = XmlReader.Create(stream, settings); return await XDocument.LoadAsync(reader, LoadOptions.None, CancellationToken.None);
    }

    private static List<ProjectWorkspaceMember> Select(ProjectWorkspaceManifest manifest, Dictionary<string, string> options)
    {
        if (options.ContainsKey("all")) return manifest.Members.OrderBy(m => m.Alias, StringComparer.OrdinalIgnoreCase).ToList();
        return [FindMember(manifest, Required(options, "alias"))];
    }
    private static ProjectWorkspaceMember FindMember(ProjectWorkspaceManifest manifest, string alias) => manifest.Members.SingleOrDefault(m => string.Equals(m.Alias, alias, StringComparison.OrdinalIgnoreCase)) ?? throw new CliException($"Workspace alias not found: {alias}", 1);
    private static void VerifyPin(ProjectWorkspaceMember m, Manifest package)
    { if (!string.Equals(m.PackageId, package.Package.Id, StringComparison.OrdinalIgnoreCase) || m.Version != package.Package.Version) throw new CliException($"Pinned package mismatch for '{m.Alias}': expected {m.PackageId} {m.Version}, found {package.Package.Id} {package.Package.Version}.", 1); }

    private static async Task<(string Path, ProjectWorkspaceManifest Manifest)> ReadRootAsync(string root)
    {
        var path = Path.Combine(root, Marker); if (!File.Exists(path)) throw new CliException($"Project workspace marker not found: {path}", 1);
        try
        {
            if ((File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0) throw new CliException($"Project workspace marker cannot be a reparse point: {path}", 1);
            var bytes = await File.ReadAllBytesAsync(path); using var json = JsonDocument.Parse(bytes); ValidateRootJson(json.RootElement);
            var manifest = JsonSerializer.Deserialize(bytes, ProjectWorkspaceJsonContext.Default.ProjectWorkspaceManifest) ?? throw new JsonException("Empty root manifest.");
            ValidateMembers(manifest.Members, root); return (path, manifest);
        }
        catch (CliException) { throw; }
        catch (Exception e) when (e is JsonException or IOException) { throw new CliException($"Invalid project workspace marker '{path}': {e.Message}", 1); }
    }
    private static void ValidateRootJson(JsonElement root)
    {
        CheckObject(root, "root", ["schemaVersion", "members"]);
        var version = root.GetProperty("schemaVersion");
        if (version.ValueKind != JsonValueKind.Number || !version.TryGetInt32(out var n) || n != 1) throw new CliException("Project workspace schemaVersion must be integer 1.", 1);
        var members = root.GetProperty("members"); if (members.ValueKind != JsonValueKind.Array) throw new CliException("Project workspace members must be an array.", 1);
        foreach (var member in members.EnumerateArray())
        {
            CheckObject(member, "members[]", ["alias", "packageId", "version", "packageFile", "directory"]);
            foreach (var p in new[] { "alias", "packageId", "version", "packageFile", "directory" }) if (member.GetProperty(p).ValueKind != JsonValueKind.String || string.IsNullOrWhiteSpace(member.GetProperty(p).GetString())) throw new CliException($"Project workspace members[].{p} must be a non-empty string.", 1);
        }
    }
    private static void CheckObject(JsonElement value, string label, string[] required)
    {
        if (value.ValueKind != JsonValueKind.Object) throw new CliException($"Project workspace {label} must be an object.", 1);
        var seen = new HashSet<string>(StringComparer.Ordinal); foreach (var p in value.EnumerateObject()) if (!seen.Add(p.Name) || !required.Contains(p.Name, StringComparer.Ordinal)) throw new CliException($"Project workspace {label} has duplicate or unknown property '{p.Name}'.", 1);
        foreach (var r in required) if (!seen.Contains(r)) throw new CliException($"Project workspace {label} is missing required property '{r}'.", 1);
    }
    private static void ValidateMembers(List<ProjectWorkspaceMember> members, string root)
    {
        var aliases = new HashSet<string>(StringComparer.OrdinalIgnoreCase); var dirs = new List<string>(); var files = new List<string>();
        foreach (var m in members)
        {
            ValidateAlias(m.Alias); if (!aliases.Add(m.Alias)) throw new CliException($"Duplicate workspace alias '{m.Alias}'.", 1);
            if (!System.Text.RegularExpressions.Regex.IsMatch(m.PackageId, "^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$", System.Text.RegularExpressions.RegexOptions.CultureInvariant)) throw new CliException($"Invalid package ID '{m.PackageId}'.", 1);
            if (!NuGet.Versioning.NuGetVersion.TryParse(m.Version, out var v) || v.ToNormalizedString() != m.Version) throw new CliException($"Invalid normalized package version '{m.Version}'.", 1);
            m.Directory = NormalizeRelative(m.Directory, "directory"); m.PackageFile = NormalizeRelative(m.PackageFile, "packageFile");
            if (!m.PackageFile.EndsWith(".nupkg", StringComparison.OrdinalIgnoreCase)) throw new CliException($"Package file must end in .nupkg: {m.PackageFile}", 1);
            dirs.Add(m.Directory); files.Add(m.PackageFile);
        }
        for (int i = 0; i < dirs.Count; i++) for (int j = i + 1; j < dirs.Count; j++)
            if (PathRelated(dirs[i], dirs[j])) throw new CliException($"Workspace member directories overlap: '{dirs[i]}' and '{dirs[j]}'.", 1);
        for (int i = 0; i < files.Count; i++) for (int j = i + 1; j < files.Count; j++) if (string.Equals(files[i], files[j], StringComparison.OrdinalIgnoreCase)) throw new CliException($"Workspace package file path collision: '{files[i]}'.", 1);
        foreach (var f in files) if (dirs.Any(d => PathRelated(d, f))) throw new CliException($"Workspace package file '{f}' conflicts with a member directory.", 1);
    }
    private static string NormalizeRelative(string path, string label)
    {
        if (string.IsNullOrWhiteSpace(path) || path.Contains('\\') || path.StartsWith('/') || Path.IsPathRooted(path) || path.Contains(':')) throw new CliException($"Workspace {label} must be a normalized root-relative path using '/'.", 1);
        var parts = path.Split('/'); if (parts.Any(p => p.Length == 0 || p is "." or "..") || parts[0].Equals(".nuget-content", StringComparison.OrdinalIgnoreCase) || parts[0].Equals(Marker, StringComparison.OrdinalIgnoreCase)) throw new CliException($"Workspace {label} is unsafe or reserved: '{path}'.", 1);
        return string.Join('/', parts);
    }
    private static void ValidateAlias(string alias)
    { if (string.IsNullOrWhiteSpace(alias) || alias is "." or ".." || alias.Any(c => !(char.IsAsciiLetterOrDigit(c) || c is '-' or '_' or '.')) || alias.Contains("..", StringComparison.Ordinal)) throw new CliException($"Invalid workspace alias '{alias}'."); }
    private static string ResolveRoot(string? explicitRoot)
    {
        var root = Path.GetFullPath(explicitRoot ?? Environment.CurrentDirectory); if (!Directory.Exists(root)) throw new CliException($"Project root not found: {root}", 1);
        if ((File.GetAttributes(root) & FileAttributes.ReparsePoint) != 0) throw new CliException("Project root cannot be a reparse point.", 1);
        return root;
    }
    private static string ResolveInput(string root, string path) => Path.GetFullPath(Path.IsPathRooted(path) ? path : Path.Combine(root, path));
    private static string ResolvePath(string root, string relative)
    {
        var full = Path.GetFullPath(Path.Combine(root, relative.Replace('/', Path.DirectorySeparatorChar)));
        if (!IsWithin(root, full)) throw new CliException($"Workspace path escapes project root: {relative}", 1);
        var current = root;
        foreach (var part in relative.Split('/'))
        {
            current = Path.Combine(current, part);
            if (File.Exists(current) || Directory.Exists(current))
                try { if ((File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0) throw new CliException($"Workspace path contains a reparse point: {relative}", 1); }
                catch (FileNotFoundException) { }
        }
        return full;
    }
    private static string RelativeFromRoot(string root, string path)
    {
        var rel = Path.GetRelativePath(root, Path.GetFullPath(path)); if (Path.IsPathRooted(rel) || rel == ".." || rel.StartsWith(".." + Path.DirectorySeparatorChar, StringComparison.Ordinal)) throw new CliException("Workspace package file must be located under the project root.", 1);
        return rel.Replace('\\', '/');
    }
    private static string Relative(string root, string path) => Path.GetRelativePath(root, path).Replace('\\', '/');
    private static bool IsWithin(string root, string candidate) { var rel = Path.GetRelativePath(root, candidate); return rel == "." || (!Path.IsPathRooted(rel) && rel != ".." && !rel.StartsWith(".." + Path.DirectorySeparatorChar, StringComparison.Ordinal)); }
    private static bool IsRelativeWithin(string root, string candidate) => string.Equals(root, candidate, StringComparison.OrdinalIgnoreCase) || candidate.StartsWith(root.TrimEnd('/') + "/", StringComparison.OrdinalIgnoreCase);
    private static bool PathRelated(string a, string b) => IsRelativeWithin(a, b) || IsRelativeWithin(b, a);
    private static void EnsurePackageOutputOutsideMembers(string root, string output, List<ProjectWorkspaceMember> members)
    {
        var full = Path.GetFullPath(output); if (string.Equals(full, Path.Combine(root, Marker), StringComparison.OrdinalIgnoreCase)) throw new CliException("Package output conflicts with the project workspace marker.", 1);
        if (members.Any(m => IsWithin(ResolvePath(root, m.Directory), full))) throw new CliException("Workspace package output cannot be inside a managed member directory.", 1);
    }
    private static async Task WriteNewAsync(string path, ProjectWorkspaceManifest manifest)
    {
        var bytes = JsonSerializer.SerializeToUtf8Bytes(manifest, ProjectWorkspaceJsonContext.Default.ProjectWorkspaceManifest); var temp = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            await using (var stream = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None)) await stream.WriteAsync(bytes);
            File.Move(temp, path);
        }
        catch (IOException) { throw new CliException($"Project workspace marker already exists or could not be created: {path}", 1); }
        finally { if (File.Exists(temp)) File.Delete(temp); }
    }
    private static async Task WriteAtomicAsync(string path, ProjectWorkspaceManifest manifest)
    {
        var bytes = JsonSerializer.SerializeToUtf8Bytes(manifest, ProjectWorkspaceJsonContext.Default.ProjectWorkspaceManifest); var temp = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            await using (var stream = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None)) await stream.WriteAsync(bytes);
            if (File.Exists(path)) File.Replace(temp, path, null); else File.Move(temp, path);
        }
        finally { if (File.Exists(temp)) File.Delete(temp); }
    }
    private static Dictionary<string, string> Parse(string[] args)
    {
        var d = new Dictionary<string, string>(StringComparer.Ordinal);
        for (int i = 0; i < args.Length; i++)
        {
            if (!args[i].StartsWith("--", StringComparison.Ordinal)) throw new CliException($"Expected an option and value, got '{args[i]}'.");
            var key = args[i][2..]; var value = key == "json" || key == "all" ? "true" : i + 1 < args.Length && !args[i + 1].StartsWith("--", StringComparison.Ordinal) ? args[++i] : throw new CliException($"Expected an option and value, got '{args[i]}'.");
            if (!d.TryAdd(key, value)) throw new CliException($"Option '--{key}' was supplied more than once.");
        }
        return d;
    }
    private static string Required(Dictionary<string, string> d, string key) => d.TryGetValue(key, out var v) && !string.IsNullOrWhiteSpace(v) ? v : throw new CliException($"Missing required option '--{key}'.");
    private static void Ensure(Dictionary<string, string> d, params string[] allowed) { var bad = d.Keys.FirstOrDefault(k => !allowed.Contains(k, StringComparer.Ordinal)); if (bad is not null) throw new CliException($"Unknown option '--{bad}'."); }
    private static void EnsureExclusive(Dictionary<string, string> d, string a, string b) { if (d.ContainsKey(a) && d.ContainsKey(b)) throw new CliException($"Options '--{a}' and '--{b}' cannot be used together."); }
    private static List<string> ReadPaths(JsonElement a) => a.EnumerateArray().Select(x => x.GetString()!).ToList();
    private const string Help = """
        Project-integrated package workspace commands:
          workspace init [--workspace ROOT]
          workspace add --alias NAME --package FILE [--directory REL] [--workspace ROOT]
          workspace list [--workspace ROOT] [--json]
          workspace unpack (--alias NAME | --all) [--workspace ROOT]
          workspace status [--alias NAME | --all] [--workspace ROOT] [--json]
          workspace pack --alias NAME --version VERSION [--output FILE] [--message TEXT] [--workspace ROOT]
          workspace set --alias NAME --package FILE [--workspace ROOT]
          workspace usage [--alias NAME | --all] [--workspace ROOT] [--json]

        Workspace paths are local to the selected project root. Pin updates are explicit.
        Usage checks local project files and prior restore evidence without restoring.
        """;
}
