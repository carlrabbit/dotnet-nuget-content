using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Xml;
using System.Xml.Linq;
using NuGet.Versioning;

internal sealed class ReferenceUpdatePlan
{
    public int SchemaVersion { get; set; } = 1;
    public string Kind { get; set; } = "workspaceReferenceUpdate";
    public string Alias { get; set; } = "";
    public string PackageId { get; set; } = "";
    public string TargetVersion { get; set; } = "";
    public bool Applied { get; set; }
    public bool CanApply { get; set; } = true;
    public List<ReferenceUpdateChange> Changes { get; set; } = [];
    public List<ReferenceUpdateBlocker> Blockers { get; set; } = [];
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] public string? PartialState { get; set; }
}

internal sealed class ReferenceUpdateChange
{
    public string Path { get; set; } = "";
    public string PackageId { get; set; } = "";
    public string SourceKind { get; set; } = "";
    public string OldVersion { get; set; } = "";
    public string NewVersion { get; set; } = "";
    public string Classification { get; set; } = "";
}

internal sealed class ReferenceUpdateBlocker
{
    public string Path { get; set; } = "";
    public string Code { get; set; } = "";
    public string Message { get; set; } = "";
}

[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase, WriteIndented = false)]
[JsonSerializable(typeof(ReferenceUpdatePlan))]
internal partial class ReferenceUpdateJsonContext : JsonSerializerContext { }

internal static class ConsumerReferenceUpdater
{
    private const int MaxEntries = 250000;
    private const int MaxFiles = 10000;
    private static readonly HashSet<string> ProjectExtensions = new(StringComparer.OrdinalIgnoreCase) { ".csproj", ".fsproj", ".vbproj", ".esproj", ".njsproj", ".vcxproj", ".sqlproj", ".shproj", ".dbproj", ".wixproj", ".dcproj", ".proj" };
    private static readonly HashSet<string> ExcludedDirectories = new(StringComparer.OrdinalIgnoreCase) { ".git", ".vs", ".idea", ".nuget-content", "bin", "obj", "node_modules", "packages", "TestResults", "artifacts", "dist", "target" };

    private sealed record SourceChange(string FullPath, string RelativePath, string PackageId, string SourceKind, string OldVersion, string NewVersion, bool IsAttribute, byte[] OriginalBytes, string Fingerprint);

    internal static async Task<ReferenceUpdatePlan> CreatePlanAsync(string root, ProjectWorkspaceMember member, IReadOnlyList<ProjectWorkspaceMember> registeredMembers, string? explicitVersion, bool apply, Func<Task>? beforeSourceRecheck = null, Action<int>? afterFileCommit = null)
    {
        var plan = new ReferenceUpdatePlan { Alias = member.Alias, PackageId = member.PackageId, TargetVersion = explicitVersion ?? member.Version };
        var packageCandidates = await FindPackagesAsync(root, member, registeredMembers, explicitVersion);
        if (packageCandidates.Error is not null) AddBlocker(plan, packageCandidates.ErrorPath ?? "", "packageVerification", packageCandidates.Error);
        plan.TargetVersion = packageCandidates.Version ?? plan.TargetVersion;

        var excluded = registeredMembers.Select(m => ProjectWorkspace.ResolvePath(root, m.Directory)).ToArray();
        var files = ScanProjectFiles(root, excluded, plan);
        var changes = new List<SourceChange>();
        var centralDeclarations = new Dictionary<string, List<(string Path, XDocument Xml, byte[] Bytes, string Hash, XElement Node, XElement? Version, bool Conditional)>>(StringComparer.OrdinalIgnoreCase);
        var centralCandidates = new Dictionary<string, (string Path, XDocument Xml, byte[] Bytes, string Hash, XElement Node, string OldVersion)>(StringComparer.OrdinalIgnoreCase);
        var centralConsumers = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var file in files.Where(p => Path.GetFileName(p).Equals("Directory.Packages.props", StringComparison.OrdinalIgnoreCase)).OrderBy(p => Relative(root, p), StringComparer.Ordinal))
        {
            try
            {
                var loaded = await LoadXmlAsync(file);
                var declarations = new List<(string Id, XElement Node, XElement? Version, bool Conditional)>();
                foreach (var node in loaded.Xml.Descendants().Where(e => e.Name.LocalName == "PackageVersion"))
                {
                    var id = (string?)node.Attribute("Include") ?? (string?)node.Attribute("Update");
                    if (string.IsNullOrWhiteSpace(id)) continue;
                    if (id.Contains('$') || id.Contains('%')) { AddBlocker(plan, Relative(root, file), "dynamicPackageIdentity", "Dynamic central PackageVersion identity prevents a safe complete update plan."); continue; }
                    declarations.Add((id, node, GetVersionElement(node), HasCondition(node)));
                }
                foreach (var d in declarations.Where(x => x.Id.Equals(member.PackageId, StringComparison.OrdinalIgnoreCase)))
                {
                    var key = file + "|" + member.PackageId;
                    if (!centralDeclarations.TryGetValue(key, out var list)) centralDeclarations[key] = list = [];
                    list.Add((file, loaded.Xml, loaded.Bytes, loaded.Hash, d.Node, d.Version, d.Conditional));
                }
            }
            catch (Exception e) when (e is XmlException or IOException or UnauthorizedAccessException)
            { AddBlocker(plan, Relative(root, file), "malformedProjectFile", $"Cannot safely inspect project configuration: {e.Message}"); }
        }

        foreach (var file in files.Where(p => ProjectExtensions.Contains(Path.GetExtension(p))).OrderBy(p => Relative(root, p), StringComparer.Ordinal))
        {
            try
            {
                var loaded = await LoadXmlAsync(file); var rel = Relative(root, file);
                var projectDirectory = Path.GetDirectoryName(file)!;
                var centralPath = FindNearestCentral(root, projectDirectory);
                foreach (var node in loaded.Xml.Descendants().Where(e => e.Name.LocalName == "PackageReference" || e.Name.LocalName == "PackageVersion"))
                {
                    var isReference = node.Name.LocalName == "PackageReference";
                    var include = (string?)node.Attribute("Include"); var update = (string?)node.Attribute("Update");
                    var identity = include ?? update;
                    if (identity is null) continue;
                    if (isReference && (identity.Contains('$') || identity.Contains('%') || identity.Contains('@'))) { AddBlocker(plan, rel, "dynamicPackageIdentity", "Dynamic PackageReference identity prevents a safe complete update plan."); continue; }
                    if (isReference && update is not null && update.Equals(member.PackageId, StringComparison.OrdinalIgnoreCase))
                    { AddBlocker(plan, rel, "unsupportedUpdateReference", "PackageReference Update declarations are not rewritten because their effective meaning is ambiguous."); continue; }
                    if (!identity.Equals(member.PackageId, StringComparison.OrdinalIgnoreCase)) continue;
                    if (!isReference) continue;
                    if (HasCondition(node)) { AddBlocker(plan, rel, "conditionalReference", "Conditional PackageReference cannot be updated safely."); continue; }
                    if (loaded.Xml.Descendants().Any(e => e.Name.LocalName == "Import")) { AddBlocker(plan, rel, "importedProjectDeclarations", "Project imports are present; imported reference declarations cannot be safely excluded without MSBuild evaluation."); continue; }
                    if (node.Attribute("VersionOverride") is not null) { AddBlocker(plan, rel, "versionOverride", "PackageReference VersionOverride takes precedence and is unsupported."); continue; }
                    var versionElements = GetVersionElements(node);
                    if (versionElements.Count > 1) { AddBlocker(plan, rel, "duplicateReferenceVersion", "PackageReference has multiple Version declarations."); continue; }
                    if (versionElements.Count == 1)
                    {
                        var element = versionElements[0]; var old = element.Value.Trim();
                        if (IsDynamic(old) || !NuGetVersion.TryParse(old, out _)) { AddBlocker(plan, rel, "dynamicReferenceVersion", "PackageReference must have a supported literal NuGet version."); continue; }
                        changes.Add(MakeChange(root, file, loaded.Xml, loaded.Bytes, loaded.Hash, member.PackageId, "packageReference", old, plan.TargetVersion, node, node.Attribute("Version") is not null));
                    }
                    else if (centralPath is not null)
                    {
                        var key = centralPath + "|" + member.PackageId;
                        if (!centralDeclarations.TryGetValue(key, out var declarationsForConsumer) || declarationsForConsumer.Count == 0) { AddBlocker(plan, rel, "unresolvedCentralVersion", "The consuming project uses central version management but has no unambiguous local PackageVersion declaration."); continue; }
                        if (declarationsForConsumer.Count > 1) { AddBlocker(plan, Relative(root, centralPath), "duplicateCentralVersion", "Multiple central PackageVersion declarations make the selected version ambiguous."); continue; }
                        var declaration = declarationsForConsumer[0];
                        if (declaration.Version is null) { AddBlocker(plan, Relative(root, centralPath), "missingCentralVersion", "PackageVersion declaration has no literal Version attribute or child element."); continue; }
                        if (declaration.Conditional) { AddBlocker(plan, Relative(root, centralPath), "conditionalCentralVersion", "Conditional central version cannot be updated safely."); continue; }
                        var oldCentral = declaration.Version.Value.Trim();
                        if (IsDynamic(oldCentral) || !NuGetVersion.TryParse(oldCentral, out _)) { AddBlocker(plan, Relative(root, centralPath), "dynamicCentralVersion", "Central PackageVersion must be a supported literal NuGet version."); continue; }
                        centralCandidates[key] = (declaration.Path, declaration.Xml, declaration.Bytes, declaration.Hash, declaration.Node, oldCentral);
                        centralConsumers.Add(key);
                    }
                    else AddBlocker(plan, rel, "unresolvedReferenceVersion", "PackageReference has no supported literal version declaration.");
                }
            }
            catch (Exception e) when (e is XmlException or IOException or UnauthorizedAccessException)
            { AddBlocker(plan, Relative(root, file), "malformedProjectFile", $"Cannot safely inspect project declarations: {e.Message}"); }
        }

        foreach (var pair in centralCandidates.Values.Where(x => centralConsumers.Contains(x.Path + "|" + member.PackageId)).OrderBy(x => Relative(root, x.Path), StringComparer.Ordinal))
        {
            changes.Add(MakeChange(root, pair.Path, pair.Xml, pair.Bytes, pair.Hash, member.PackageId, "centralPackageVersion", pair.OldVersion, plan.TargetVersion, pair.Node, pair.Node.Attribute("Version") is not null));
        }

        foreach (var duplicate in changes.GroupBy(c => c.FullPath + "|" + c.SourceKind, StringComparer.OrdinalIgnoreCase).Where(g => g.Count() > 1))
            AddBlocker(plan, duplicate.First().RelativePath, "duplicateDeclaration", "Multiple selected declarations in the same project file are ambiguous.");

        plan.Changes = changes.OrderBy(c => c.RelativePath, StringComparer.Ordinal).ThenBy(c => c.SourceKind, StringComparer.Ordinal)
            .Select(c => new ReferenceUpdateChange { Path = c.RelativePath, PackageId = c.PackageId, SourceKind = c.SourceKind, OldVersion = c.OldVersion, NewVersion = c.NewVersion, Classification = c.OldVersion == c.NewVersion ? "noOp" : "supported" }).ToList();
        plan.Blockers = plan.Blockers.OrderBy(b => b.Path, StringComparer.Ordinal).ThenBy(b => b.Code, StringComparer.Ordinal).ToList();
        plan.CanApply = plan.Blockers.Count == 0;
        if (apply && plan.CanApply && changes.Any(c => c.OldVersion != c.NewVersion))
        {
            try
            {
                if (beforeSourceRecheck is not null) await beforeSourceRecheck();
                foreach (var source in changes.Where(c => c.OldVersion != c.NewVersion))
                    if (!CryptographicOperations.FixedTimeEquals(SHA256.HashData(await File.ReadAllBytesAsync(source.FullPath)), Convert.FromHexString(source.Fingerprint)))
                        throw new IOException($"Source changed after plan creation: {source.RelativePath}");
                await ApplyAsync(changes.Where(c => c.OldVersion != c.NewVersion).ToList(), afterFileCommit);
                plan.Applied = true;
            }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException)
            {
                AddBlocker(plan, "", "writeFailure", e.Message);
                plan.CanApply = false;
                if (e.Data["partialState"] is string partial) plan.PartialState = partial;
            }
        }
        return plan;
    }

    private sealed record PackageSearch(string? Version, string? Error, string? ErrorPath);
    private static async Task<PackageSearch> FindPackagesAsync(string root, ProjectWorkspaceMember member, IReadOnlyList<ProjectWorkspaceMember> registeredMembers, string? requested)
    {
        var target = requested ?? member.Version;
        if (!NuGetVersion.TryParse(target, out var requestedVersion)) return new(null, "Requested version is not a valid NuGet version.", "");
        var candidates = new List<(string Path, string Version)>();
        var pinnedFile = Path.GetFullPath(Path.Combine(root, member.PackageFile.Replace('/', Path.DirectorySeparatorChar)));
        if (requested is null && File.Exists(pinnedFile))
        {
            try { var m = await ContentPackages.ReadPackageForWorkspaceAsync(pinnedFile); if (m.Package.Id.Equals(member.PackageId, StringComparison.OrdinalIgnoreCase) && m.Package.Version == member.Version) candidates.Add((pinnedFile, m.Package.Version)); }
            catch (Exception e) when (e is IOException or CliException) { return new(null, $"Pinned package is invalid: {e.Message}", member.PackageFile); }
        }
        else
        {
            foreach (var registered in registeredMembers.Where(x => x.PackageId.Equals(member.PackageId, StringComparison.OrdinalIgnoreCase)))
            {
                var path = Path.GetFullPath(Path.Combine(root, registered.PackageFile.Replace('/', Path.DirectorySeparatorChar)));
                if (!IsWithin(root, path) || !File.Exists(path)) continue;
                try
                {
                    var m = await ContentPackages.ReadPackageForWorkspaceAsync(path);
                    if (m.Package.Id.Equals(member.PackageId, StringComparison.OrdinalIgnoreCase) && m.Package.Version == requestedVersion.ToNormalizedString()) candidates.Add((path, m.Package.Version));
                }
                catch (Exception e) when (e is not OutOfMemoryException and not StackOverflowException) { }
            }
        }
        if (candidates.Count == 0) return new(null, $"No locally available valid managed package for {member.PackageId} {requestedVersion.ToNormalizedString()} was found within the project root.", requested ?? member.PackageFile);
        if (candidates.Count > 1) return new(null, $"Multiple local packages match {member.PackageId} {requestedVersion.ToNormalizedString()}; target is ambiguous.", "");
        return new(candidates[0].Version, null, null);
    }

    private static List<string> ScanProjectFiles(string root, string[] excluded, ReferenceUpdatePlan plan)
    {
        var files = new List<string>(); var pending = new Stack<(string Path, int Depth)>(); pending.Push((root, 0)); var entries = 0;
        while (pending.Count > 0)
        {
            var (current, depth) = pending.Pop();
            if (depth > 40) { AddBlocker(plan, Relative(root, current), "scanLimit", "Project scan exceeded maximum traversal depth."); continue; }
            IEnumerable<string> children; try { children = Directory.EnumerateFileSystemEntries(current); } catch (Exception e) when (e is IOException or UnauthorizedAccessException) { AddBlocker(plan, Relative(root, current), "scanFailure", e.Message); continue; }
            foreach (var child in children)
            {
                if (++entries > MaxEntries) { AddBlocker(plan, Relative(root, current), "scanLimit", $"Project scan stopped after {MaxEntries} entries."); return files; }
                FileAttributes attr; try { attr = File.GetAttributes(child); } catch (Exception e) when (e is IOException or UnauthorizedAccessException) { AddBlocker(plan, Relative(root, child), "scanFailure", e.Message); continue; }
                if ((attr & FileAttributes.ReparsePoint) != 0) continue;
                if ((attr & FileAttributes.Directory) != 0)
                {
                    if (!ExcludedDirectories.Contains(Path.GetFileName(child)) && !excluded.Any(x => IsWithin(x, child))) pending.Push((child, depth + 1));
                }
                else if (ProjectExtensions.Contains(Path.GetExtension(child)) || Path.GetFileName(child).Equals("Directory.Packages.props", StringComparison.OrdinalIgnoreCase))
                {
                    files.Add(child); if (files.Count > MaxFiles) { AddBlocker(plan, Relative(root, child), "scanLimit", $"Project scan stopped after {MaxFiles} files."); return files; }
                }
            }
        }
        return files;
    }

    private static async Task<(XDocument Xml, byte[] Bytes, string Hash)> LoadXmlAsync(string path)
    {
        var bytes = await File.ReadAllBytesAsync(path); var settings = new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null, MaxCharactersInDocument = 8 * 1024 * 1024 };
        using var stream = new MemoryStream(bytes, false); using var reader = XmlReader.Create(stream, settings); var xml = XDocument.Load(reader, LoadOptions.PreserveWhitespace);
        return (xml, bytes, Convert.ToHexString(SHA256.HashData(bytes)));
    }

    private static XElement? GetVersionElement(XElement node) => node.Attribute("Version") is { } attr ? AttributeValueElement(attr) : node.Elements().FirstOrDefault(e => e.Name.LocalName == "Version");
    private static List<XElement> GetVersionElements(XElement node)
    {
        var result = node.Elements().Where(e => e.Name.LocalName == "Version").ToList();
        if (node.Attribute("Version") is { } attr) result.Add(AttributeValueElement(attr));
        return result;
    }
    private static bool HasCondition(XElement node) => node.AncestorsAndSelf().Any(e => e.Attribute("Condition") is not null);
    private static bool IsDynamic(string value) => value.Length == 0 || value.Contains('$') || value.Contains('@') || value.Contains('%') || value.Contains('*') || value.Contains('[') || value.Contains(']');
    private static string? FindNearestCentral(string root, string directory)
    {
        var current = directory;
        while (IsWithin(root, current))
        {
            var candidate = Path.Combine(current, "Directory.Packages.props"); if (File.Exists(candidate)) return candidate;
            if (string.Equals(current, root, StringComparison.OrdinalIgnoreCase)) break;
            current = Directory.GetParent(current)?.FullName ?? root;
        }
        return null;
    }
    private static SourceChange MakeChange(string root, string path, XDocument xml, byte[] bytes, string hash, string id, string kind, string old, string next, XElement target, bool isAttribute)
    {
        return new(Path.GetFullPath(path), Relative(root, path), id, kind, old, next, isAttribute, bytes, hash);
    }
    private static async Task ApplyAsync(List<SourceChange> changes, Action<int>? afterFileCommit)
    {
        var staged = new List<(SourceChange Change, string Temp, byte[] Updated)>(); var committed = new List<SourceChange>();
        try
        {
            foreach (var group in changes.GroupBy(c => c.FullPath, StringComparer.OrdinalIgnoreCase))
            {
                var source = group.First();
                var loaded = await LoadXmlAsync(source.FullPath);
                foreach (var change in group)
                {
                    var node = FindDeclaration(loaded.Xml, change);
                    if (node is null) throw new IOException($"Could not re-identify planned declaration in {change.RelativePath}.");
                    if (change.IsAttribute && node.Attribute("Version") is { } attribute) attribute.Value = change.NewVersion;
                    else if (!change.IsAttribute && node.Elements().FirstOrDefault(e => e.Name.LocalName == "Version") is { } element) element.Value = change.NewVersion;
                    else throw new IOException($"Could not re-identify the planned Version value in {change.RelativePath}.");
                }
                var updated = SerializeXml(loaded.Xml, source.OriginalBytes);
                var temp = source.FullPath + "." + Guid.NewGuid().ToString("N") + ".tmp";
                await File.WriteAllBytesAsync(temp, updated); staged.Add((source, temp, updated));
            }
            foreach (var item in staged)
            {
                if (!CryptographicOperations.FixedTimeEquals(SHA256.HashData(await File.ReadAllBytesAsync(item.Change.FullPath)), Convert.FromHexString(item.Change.Fingerprint)))
                    throw new IOException($"Source changed before apply: {item.Change.RelativePath}");
            }
            foreach (var item in staged) { File.Move(item.Temp, item.Change.FullPath, true); committed.Add(item.Change); afterFileCommit?.Invoke(committed.Count); }
        }
        catch (Exception failure) when (failure is IOException or UnauthorizedAccessException or XmlException)
        {
            var rollbackErrors = new List<string>();
            foreach (var item in staged.Where(s => committed.Contains(s.Change)).Reverse())
            {
                try { await File.WriteAllBytesAsync(item.Change.FullPath, item.Change.OriginalBytes); }
                catch (Exception rollback) when (rollback is IOException or UnauthorizedAccessException) { rollbackErrors.Add(item.Change.RelativePath + ": " + rollback.Message); }
            }
            failure.Data["partialState"] = rollbackErrors.Count == 0
                ? $"No updates were retained; {committed.Count} committed file(s) were restored after a handled write failure."
                : $"Rollback incomplete; some files may contain updated versions. Failed recovery: {string.Join("; ", rollbackErrors)}";
            throw;
        }
        finally { foreach (var item in staged) if (File.Exists(item.Temp)) try { File.Delete(item.Temp); } catch { } }
    }

    private static XElement? FindDeclaration(XDocument document, SourceChange change)
    {
        var expectedName = change.SourceKind == "centralPackageVersion" ? "PackageVersion" : "PackageReference";
        return document.Descendants().Where(e => e.Name.LocalName == expectedName)
            .FirstOrDefault(e => ((string?)e.Attribute("Include"))?.Equals(change.PackageId, StringComparison.OrdinalIgnoreCase) == true &&
                (change.IsAttribute ? ((string?)e.Attribute("Version")) == change.OldVersion : e.Elements().FirstOrDefault(v => v.Name.LocalName == "Version")?.Value.Trim() == change.OldVersion));
    }
    private static byte[] SerializeXml(XDocument document, byte[] original)
    {
        System.Text.Encoding encoding;
        if (original.Length >= 4 && original[0] == 0x00 && original[1] == 0x00 && original[2] == 0xFE && original[3] == 0xFF) encoding = new System.Text.UTF32Encoding(true, true);
        else if (original.Length >= 4 && original[0] == 0xFF && original[1] == 0xFE && original[2] == 0x00 && original[3] == 0x00) encoding = new System.Text.UTF32Encoding(false, true);
        else if (original.Length >= 2 && original[0] == 0xFE && original[1] == 0xFF) encoding = new System.Text.UnicodeEncoding(true, true);
        else if (original.Length >= 2 && original[0] == 0xFF && original[1] == 0xFE) encoding = new System.Text.UnicodeEncoding(false, true);
        else if (original.Length >= 3 && original[0] == 0xEF && original[1] == 0xBB && original[2] == 0xBF) encoding = new System.Text.UTF8Encoding(true);
        else if (!string.IsNullOrWhiteSpace(document.Declaration?.Encoding))
        {
            try { encoding = System.Text.Encoding.GetEncoding(document.Declaration.Encoding); }
            catch (ArgumentException) { encoding = new System.Text.UTF8Encoding(false); }
        }
        else encoding = new System.Text.UTF8Encoding(false);
        using var stream = new MemoryStream(); using (var writer = XmlWriter.Create(stream, new XmlWriterSettings { Encoding = encoding, Indent = false, NewLineChars = original.Contains((byte)'\r') ? "\r\n" : "\n", OmitXmlDeclaration = document.Declaration is null })) document.Save(writer);
        return stream.ToArray();
    }
    private static XElement AttributeValueElement(XAttribute attribute)
    {
        var element = new XElement("_VersionAttribute", attribute.Value); element.AddAnnotation(attribute); return element;
    }
    private static void AddBlocker(ReferenceUpdatePlan plan, string path, string code, string message)
    { if (!plan.Blockers.Any(b => b.Path == path && b.Code == code && b.Message == message)) plan.Blockers.Add(new() { Path = path.Replace('\\', '/'), Code = code, Message = message }); }
    private static string Relative(string root, string path) => Path.GetRelativePath(root, path).Replace('\\', '/');
    private static bool IsWithin(string root, string child)
    { var rel = Path.GetRelativePath(root, child); return rel == "." || (!Path.IsPathRooted(rel) && rel != ".." && !rel.StartsWith(".." + Path.DirectorySeparatorChar, StringComparison.Ordinal)); }
}
