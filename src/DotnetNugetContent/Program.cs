using System.Security.Cryptography;
using System.Text.RegularExpressions;
using NuGet.Packaging;
using NuGet.Packaging.Core;
using NuGet.Versioning;

return await Cli.RunAsync(args);

internal static class Cli
{
    public static async Task<int> RunAsync(string[] args)
    {
        try
        {
            if (args.Length == 0 || args is ["--help"] or ["-h"] or ["help"])
            {
                Console.Out.WriteLine(HelpText);
                return 0;
            }

            if (args is ["--version"] or ["version"])
            {
                Console.Out.WriteLine(typeof(Cli).Assembly.GetName().Version?.ToString(3) ?? "0.1.0");
                return 0;
            }

            var options = ParseOptions(args[1..]);
            switch (args[0])
            {
                case "pack":
                    EnsureOptions(options, "id", "version", "source", "output");
                    await ContentPackages.PackAsync(Required(options, "id"), Required(options, "version"), Required(options, "source"), Required(options, "output"));
                    Console.Out.WriteLine($"Created {Path.GetFullPath(options["output"])}");
                    return 0;
                case "unpack":
                    EnsureOptions(options, "package", "destination", "sha256");
                    await ContentPackages.UnpackAsync(Required(options, "package"), Required(options, "destination"), options.GetValueOrDefault("sha256"));
                    Console.Out.WriteLine($"Extracted to {Path.GetFullPath(options["destination"])}");
                    return 0;
                case "hash":
                    EnsureOptions(options, "path", "expect");
                    var path = Path.GetFullPath(Required(options, "path"));
                    if (!File.Exists(path)) throw new CliException($"File not found: {path}", 1);
                    var hash = await ContentPackages.Sha256Async(path);
                    if (options.TryGetValue("expect", out var expected) && !ContentPackages.HashEquals(hash, expected))
                        throw new CliException($"SHA-256 mismatch for '{path}'. Expected {expected}; actual {hash}.", 1);
                    Console.Out.WriteLine(hash);
                    return 0;
                default:
                    throw new CliException($"Unknown command '{args[0]}'. Run 'dotnet-nuget-content --help'.");
            }
        }
        catch (CliException ex)
        {
            Console.Error.WriteLine($"error: {ex.Message}");
            return ex.ExitCode;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"error: {ex.Message}");
            return 1;
        }
    }

    private static Dictionary<string, string> ParseOptions(string[] args)
    {
        var result = new Dictionary<string, string>(StringComparer.Ordinal);
        for (var i = 0; i < args.Length; i++)
        {
            var arg = args[i];
            if (!arg.StartsWith("--", StringComparison.Ordinal) || i + 1 >= args.Length || args[i + 1].StartsWith("--", StringComparison.Ordinal))
                throw new CliException($"Expected an option and value, got '{arg}'.");
            if (!result.TryAdd(arg[2..], args[++i])) throw new CliException($"Option '{arg}' was supplied more than once.");
        }
        return result;
    }

    private static string Required(Dictionary<string, string> options, string name) =>
        options.TryGetValue(name, out var value) && !string.IsNullOrWhiteSpace(value)
            ? value
            : throw new CliException($"Missing required option '--{name}'.");

    private static void EnsureOptions(Dictionary<string, string> options, params string[] allowed)
    {
        var unexpected = options.Keys.FirstOrDefault(key => !allowed.Contains(key, StringComparer.Ordinal));
        if (unexpected is not null) throw new CliException($"Unknown option '--{unexpected}'.");
    }

    private const string HelpText = """
        dotnet-nuget-content — manage immutable NuGet content snapshots

        Usage:
          dotnet-nuget-content --help
          dotnet-nuget-content --version
          dotnet-nuget-content pack --id <id> --version <version> --source <directory> --output <file.nupkg>
          dotnet-nuget-content unpack --package <file.nupkg> --destination <directory> [--sha256 <hex>]
          dotnet-nuget-content hash --path <file> [--expect <sha256>]

        Pack creates a new immutable package. Unpack refuses an existing destination.
        Hash prints a file SHA-256; --expect returns an error on mismatch.
        """;
}

internal sealed class CliException(string message, int exitCode = 2) : Exception(message)
{
    public int ExitCode { get; } = exitCode;
}

internal static class ContentPackages
{
    private static readonly Regex PackageIdPattern = new("^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$", RegexOptions.CultureInvariant | RegexOptions.NonBacktracking);
    private const string ContentPrefix = "contentFiles/any/any/";

    public static async Task PackAsync(string id, string versionText, string sourcePath, string outputPath)
    {
        if (!PackageIdPattern.IsMatch(id)) throw new CliException($"Invalid NuGet package ID '{id}'.");
        if (versionText.Contains('*') || !NuGetVersion.TryParse(versionText, out var version))
            throw new CliException($"Invalid exact NuGet version '{versionText}'.");

        var source = Path.GetFullPath(sourcePath);
        if (!Directory.Exists(source)) throw new CliException($"Source directory not found: {source}", 1);
        RejectReparsePoints(source);
        var output = Path.GetFullPath(outputPath);
        if (!output.EndsWith(".nupkg", StringComparison.OrdinalIgnoreCase)) throw new CliException("Output path must end in .nupkg.", 1);
        if (File.Exists(output) || Directory.Exists(output)) throw new CliException($"Output already exists: {output}", 1);
        Directory.CreateDirectory(Path.GetDirectoryName(output)!);

        var files = Directory.EnumerateFiles(source, "*", SearchOption.AllDirectories).OrderBy(p => p, StringComparer.Ordinal).ToArray();
        if (files.Length == 0) throw new CliException("Source directory must contain at least one file.", 1);
        var builder = new PackageBuilder
        {
            Id = id,
            Version = version,
            Description = "Immutable arbitrary content snapshot.",
            Authors = { "dotnet-nuget-content" }
        };
        builder.ContentFiles.Add(new ManifestContentFiles
        {
            Include = "**/*",
            BuildAction = "None",
            CopyToOutput = "true",
            Flatten = "false"
        });
        foreach (var file in files)
        {
            var relative = Path.GetRelativePath(source, file).Replace('\\', '/');
            ValidateRelativePath(relative);
            builder.Files.Add(new PhysicalPackageFile
            {
                SourcePath = file,
                TargetPath = ContentPrefix + relative
            });
        }

        var temp = output + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            await using (var stream = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None)) builder.Save(stream);
            File.Move(temp, output);
        }
        finally
        {
            if (File.Exists(temp)) File.Delete(temp);
        }
    }

    public static async Task UnpackAsync(string packagePath, string destinationPath, string? expectedHash)
    {
        var package = Path.GetFullPath(packagePath);
        if (!File.Exists(package)) throw new CliException($"Package not found: {package}", 1);
        if (expectedHash is not null)
        {
            var actualHash = await Sha256Async(package);
            if (!HashEquals(actualHash, expectedHash)) throw new CliException($"SHA-256 mismatch. Expected {expectedHash}; actual {actualHash}.", 1);
        }

        var destination = Path.GetFullPath(destinationPath);
        if (File.Exists(destination) || Directory.Exists(destination)) throw new CliException($"Destination already exists: {destination}", 1);
        var parent = Path.GetDirectoryName(destination)!;
        Directory.CreateDirectory(parent);
        var staging = Path.Combine(parent, "." + Path.GetFileName(destination) + "." + Guid.NewGuid().ToString("N") + ".tmp");
        Directory.CreateDirectory(staging);
        try
        {
            using var archive = new PackageArchiveReader(package);
            using var nuspecStream = archive.GetNuspec();
            var nuspec = new NuspecReader(nuspecStream);
            if (string.IsNullOrWhiteSpace(nuspec.GetId()) || !NuGetVersion.TryParse(nuspec.GetVersion().ToString(), out _))
                throw new CliException("Package has invalid NuGet identity metadata.", 1);

            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var archivePath in archive.GetFiles())
            {
                var normalized = archivePath.Replace('\\', '/');
                ValidateArchivePath(normalized);
                if (!seen.Add(normalized)) throw new CliException($"Package contains duplicate path '{normalized}'.", 1);
                if (!normalized.StartsWith(ContentPrefix, StringComparison.Ordinal)) continue;
                var relative = normalized[ContentPrefix.Length..];
                ValidateRelativePath(relative);
                var target = Path.GetFullPath(Path.Combine(staging, relative.Replace('/', Path.DirectorySeparatorChar)));
                if (!target.StartsWith(staging.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
                    throw new CliException($"Unsafe package path '{normalized}'.", 1);
                Directory.CreateDirectory(Path.GetDirectoryName(target)!);
                await using var input = await archive.GetStreamAsync(archivePath, CancellationToken.None);
                await using var output = new FileStream(target, FileMode.CreateNew, FileAccess.Write, FileShare.None);
                await input.CopyToAsync(output);
            }
            if (!Directory.EnumerateFiles(staging, "*", SearchOption.AllDirectories).Any())
                throw new CliException("Package contains no contentFiles/any/any payload.", 1);
            Directory.Move(staging, destination);
        }
        catch (Exception ex) when (ex is InvalidDataException or NuGet.Packaging.Core.PackagingException or System.Xml.XmlException)
        {
            throw new CliException("Invalid NuGet package.", 1);
        }
        finally
        {
            if (Directory.Exists(staging)) Directory.Delete(staging, recursive: true);
        }
    }

    public static async Task<string> Sha256Async(string path)
    {
        await using var stream = File.OpenRead(path);
        return Convert.ToHexString(await SHA256.HashDataAsync(stream));
    }

    public static bool HashEquals(string actual, string expected) =>
        Regex.IsMatch(expected, "^[0-9a-fA-F]{64}$", RegexOptions.CultureInvariant) &&
        CryptographicOperations.FixedTimeEquals(Convert.FromHexString(actual), Convert.FromHexString(expected));

    private static void RejectReparsePoints(string root)
    {
        foreach (var entry in Directory.EnumerateFileSystemEntries(root, "*", SearchOption.AllDirectories).Prepend(root))
            if ((File.GetAttributes(entry) & FileAttributes.ReparsePoint) != 0)
                throw new CliException($"Symbolic links and reparse points are not allowed in the source: {entry}", 1);
    }

    private static void ValidateArchivePath(string path)
    {
        if (string.IsNullOrWhiteSpace(path) || path.StartsWith('/', StringComparison.Ordinal) || path.Contains(':') ||
            path.Split('/').Any(part => part is ".." or "." || part.Length == 0))
            throw new CliException($"Unsafe package path '{path}'.", 1);
    }

    private static void ValidateRelativePath(string path)
    {
        if (string.IsNullOrWhiteSpace(path) || Path.IsPathRooted(path) || path.Contains(':') ||
            path.Replace('\\', '/').Split('/').Any(part => part is ".." or "." || part.Length == 0))
            throw new CliException($"Unsafe content path '{path}'.", 1);
    }
}
