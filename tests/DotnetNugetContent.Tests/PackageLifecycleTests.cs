using System.IO.Compression;
using System.Security.Cryptography;
using NuGet.Packaging;

namespace DotnetNugetContent.Tests;

public sealed class PackageLifecycleTests : IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), "dnc-tests-" + Guid.NewGuid().ToString("N"));

    public PackageLifecycleTests() => Directory.CreateDirectory(_root);

    [Fact]
    public async Task PackAndUnpackPreserveNestedTextAndBinaryBytes()
    {
        var source = Path.Combine(_root, "source");
        Directory.CreateDirectory(Path.Combine(source, "nested", "deeper"));
        var textBytes = System.Text.Encoding.UTF8.GetBytes("snowman ☃ and newline\r\n");
        var binaryBytes = new byte[] { 0, 255, 1, 128, 13, 10, 0, 42 };
        await File.WriteAllBytesAsync(Path.Combine(source, "nested", "deeper", "readme.txt"), textBytes);
        await File.WriteAllBytesAsync(Path.Combine(source, "nested", "payload.bin"), binaryBytes);
        var package = Path.Combine(_root, "feed", "sample.content.1.2.3.nupkg");
        var destination = Path.Combine(_root, "working");

        await ContentPackages.PackAsync("sample.content", "1.2.3", source, package);
        await ContentPackages.UnpackAsync(package, destination, null);

        Assert.Equal(textBytes, await File.ReadAllBytesAsync(Path.Combine(destination, "nested", "deeper", "readme.txt")));
        Assert.Equal(binaryBytes, await File.ReadAllBytesAsync(Path.Combine(destination, "nested", "payload.bin")));
        Assert.Equal(Convert.ToHexString(SHA256.HashData(textBytes)), await ContentPackages.Sha256Async(Path.Combine(destination, "nested", "deeper", "readme.txt")));
        using var reader = new PackageArchiveReader(package);
        using var nuspecStream = reader.GetNuspec();
        var nuspec = new NuspecReader(nuspecStream);
        var contentEntry = Assert.Single(nuspec.GetContentFiles());
        Assert.Equal("**/*", contentEntry.Include);
        Assert.Equal("None", contentEntry.BuildAction);
        Assert.True(contentEntry.CopyToOutput);
        Assert.False(contentEntry.Flatten);
    }

    [Fact]
    public async Task HashMismatchAndExistingDestinationAreRejectedWithoutMutation()
    {
        var package = await CreatePackageAsync();
        var actual = await ContentPackages.Sha256Async(package);
        Assert.Matches("^[0-9A-F]{64}$", actual);
        var existing = Path.Combine(_root, "existing");
        Directory.CreateDirectory(existing);
        await File.WriteAllTextAsync(Path.Combine(existing, "keep.txt"), "keep");

        await Assert.ThrowsAsync<CliException>(() => ContentPackages.UnpackAsync(package, Path.Combine(_root, "bad-hash"), new string('0', 64)));
        await Assert.ThrowsAsync<CliException>(() => ContentPackages.UnpackAsync(package, existing, null));
        Assert.Equal("keep", await File.ReadAllTextAsync(Path.Combine(existing, "keep.txt")));
        Assert.False(Directory.Exists(Path.Combine(_root, "bad-hash")));
    }

    [Fact]
    public async Task InvalidIdentityVersionAndMalformedPackageAreRejected()
    {
        var source = Path.Combine(_root, "source");
        Directory.CreateDirectory(source);
        await File.WriteAllTextAsync(Path.Combine(source, "file.txt"), "value");
        await Assert.ThrowsAsync<CliException>(() => ContentPackages.PackAsync("../bad", "1.0.0", source, Path.Combine(_root, "bad-id.nupkg")));
        await Assert.ThrowsAsync<CliException>(() => ContentPackages.PackAsync("valid", "1.*", source, Path.Combine(_root, "bad-version.nupkg")));

        var malformed = Path.Combine(_root, "malformed.nupkg");
        await File.WriteAllTextAsync(malformed, "not a ZIP package");
        var malformedOutput = Path.Combine(_root, "malformed-out");
        var malformedError = await Assert.ThrowsAsync<CliException>(() => ContentPackages.UnpackAsync(malformed, malformedOutput, null));
        Assert.Equal("Invalid NuGet package.", malformedError.Message);
        Assert.Equal(1, malformedError.ExitCode);
        Assert.False(Directory.Exists(malformedOutput));

        var invalidNuspec = Path.Combine(_root, "invalid-nuspec.nupkg");
        using (var stream = File.Create(invalidNuspec))
        using (var zip = new ZipArchive(stream, ZipArchiveMode.Create))
        {
            var nuspec = zip.CreateEntry("invalid.nuspec");
            await using var writer = new StreamWriter(nuspec.Open());
            await writer.WriteAsync("<package><metadata>");
        }
        var invalidNuspecOutput = Path.Combine(_root, "invalid-nuspec-out");
        var nuspecError = await Assert.ThrowsAsync<CliException>(() => ContentPackages.UnpackAsync(invalidNuspec, invalidNuspecOutput, null));
        Assert.Equal("Invalid NuGet package.", nuspecError.Message);
        Assert.Equal(1, nuspecError.ExitCode);
        Assert.False(Directory.Exists(invalidNuspecOutput));

        await Assert.ThrowsAsync<ArgumentNullException>(() => ContentPackages.UnpackAsync(null!, Path.Combine(_root, "unexpected-error-out"), null));
    }

    [Fact]
    public async Task ExistingPackageOutputAndDuplicateArchiveEntriesAreRejected()
    {
        var source = Path.Combine(_root, "source");
        Directory.CreateDirectory(source);
        await File.WriteAllTextAsync(Path.Combine(source, "file.txt"), "value");
        var existingPackage = Path.Combine(_root, "existing.nupkg");
        await File.WriteAllTextAsync(existingPackage, "keep");
        await Assert.ThrowsAsync<CliException>(() => ContentPackages.PackAsync("valid", "1.0.0", source, existingPackage));
        Assert.Equal("keep", await File.ReadAllTextAsync(existingPackage));

        var duplicate = Path.Combine(_root, "duplicate.nupkg");
        using (var stream = File.Create(duplicate))
        using (var zip = new ZipArchive(stream, ZipArchiveMode.Create))
        {
            foreach (var body in new[] { "first", "second" })
            {
                var entry = zip.CreateEntry("contentFiles/any/any/same.txt");
                await using var output = entry.Open();
                await output.WriteAsync(System.Text.Encoding.UTF8.GetBytes(body));
            }
            var nuspec = zip.CreateEntry("duplicate.nuspec");
            await using var writer = new StreamWriter(nuspec.Open());
            await writer.WriteAsync("""
                <?xml version="1.0"?><package xmlns="http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd"><metadata><id>duplicate</id><version>1.0.0</version><authors>test</authors><description>test</description></metadata></package>
                """);
        }
        var outputDirectory = Path.Combine(_root, "duplicate-out");
        var error = await Assert.ThrowsAsync<CliException>(() => ContentPackages.UnpackAsync(duplicate, outputDirectory, null));
        Assert.Equal("Package contains duplicate path 'contentFiles/any/any/same.txt'.", error.Message);
        Assert.Equal(1, error.ExitCode);
        Assert.False(Directory.Exists(outputDirectory));
        Assert.Empty(Directory.EnumerateDirectories(_root, ".duplicate-out.*.tmp"));
    }

    [Fact]
    public async Task TraversalPayloadIsRejectedAndDoesNotEscapeStaging()
    {
        var malicious = Path.Combine(_root, "malicious.nupkg");
        using (var stream = File.Create(malicious))
        using (var zip = new ZipArchive(stream, ZipArchiveMode.Create))
        {
            var nuspec = zip.CreateEntry("malicious.nuspec");
            await using (var writer = new StreamWriter(nuspec.Open()))
                await writer.WriteAsync("""
                    <?xml version="1.0"?><package xmlns="http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd"><metadata><id>malicious</id><version>1.0.0</version><authors>test</authors><description>test</description></metadata></package>
                    """);
            var payload = zip.CreateEntry("contentFiles/any/any/../../../../escaped.txt");
            await using var output = payload.Open();
            await output.WriteAsync(new byte[] { 65 });
        }
        var destination = Path.Combine(_root, "malicious-out");
        await Assert.ThrowsAsync<CliException>(() => ContentPackages.UnpackAsync(malicious, destination, null));
        Assert.False(File.Exists(Path.Combine(_root, "escaped.txt")));
        Assert.False(Directory.Exists(destination));
    }

    [Fact]
    public async Task CliHelpVersionAndExpectedHashHaveStableExitBehavior()
    {
        var stdout = Console.Out;
        var stderr = Console.Error;
        using var output = new StringWriter();
        using var error = new StringWriter();
        try
        {
            Console.SetOut(output);
            Console.SetError(error);
            Assert.Equal(0, await Cli.RunAsync(["--help"]));
            Assert.Contains("pack --id", output.ToString());
            output.GetStringBuilder().Clear();
            Assert.Equal(0, await Cli.RunAsync(["--version"]));
            Assert.Equal("0.1.0", output.ToString().Trim());

            output.GetStringBuilder().Clear();
            var file = Path.Combine(_root, "hash.txt");
            await File.WriteAllTextAsync(file, "content");
            Assert.Equal(1, await Cli.RunAsync(["hash", "--path", file, "--expect", new string('0', 64)]));
            Assert.Equal(string.Empty, output.ToString());
            Assert.Equal($"error: SHA-256 mismatch for '{file}'. Expected {new string('0', 64)}; actual {Convert.ToHexString(SHA256.HashData(await File.ReadAllBytesAsync(file)))}.{Environment.NewLine}", error.ToString());
            error.GetStringBuilder().Clear();
            Assert.Equal(2, await Cli.RunAsync(["hash", "--path", file, "--typo", "value"]));
            Assert.Contains("Unknown option '--typo'", error.ToString());
        }
        finally
        {
            Console.SetOut(stdout);
            Console.SetError(stderr);
        }
    }

    private async Task<string> CreatePackageAsync()
    {
        var source = Path.Combine(_root, "source-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(source);
        await File.WriteAllTextAsync(Path.Combine(source, "file.txt"), "content");
        var package = Path.Combine(_root, Guid.NewGuid().ToString("N") + ".nupkg");
        await ContentPackages.PackAsync("sample", "1.0.0", source, package);
        return package;
    }

    public void Dispose()
    {
        if (Directory.Exists(_root)) Directory.Delete(_root, recursive: true);
    }
}
