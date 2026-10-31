using NuGet.Versioning;

internal sealed record PackageVersionSelection(string? ExplicitVersion, string? Increment)
{
    public static PackageVersionSelection FromOptions(Dictionary<string, string> options)
    {
        var supplied = new[] { "version", "major", "minor", "patch" }.Where(options.ContainsKey).ToArray();
        if (supplied.Length != 1) throw new CliException("Specify exactly one of --version, --major, --minor, or --patch.");
        var option = supplied[0];
        if (option == "version") return new(options[option], null);
        if (!string.Equals(options[option], "true", StringComparison.Ordinal)) throw new CliException($"Option '--{option}' does not take a value.");
        return new(null, option);
    }

    public NuGetVersion Resolve(string baselineText)
    {
        if (ExplicitVersion is not null) return ContentPackages.ParseVersion(ExplicitVersion);
        var baseline = ContentPackages.ParseVersion(baselineText);
        var original = baseline.OriginalVersion ?? baseline.ToNormalizedString();
        var stablePart = original.Split('+', 2)[0];
        if (!string.IsNullOrEmpty(baseline.Release) || !string.IsNullOrEmpty(baseline.Metadata) || stablePart.Split('-', 2)[0].Split('.').Length != 3 ||
            stablePart.Any(c => !(char.IsAsciiDigit(c) || c == '.' || c == '-')))
            throw new CliException("Relative version increments require a stable three-component numeric baseline without prerelease or build metadata.");
        var numeric = baseline.Version ?? throw new CliException("Relative version increment baseline is not numeric.");
        try
        {
            var major = numeric.Major;
            var minor = numeric.Minor;
            var patch = numeric.Build;
            switch (Increment)
            {
                case "major": return new NuGetVersion(checked(major + 1), 0, 0);
                case "minor": return new NuGetVersion(major, checked(minor + 1), 0);
                case "patch": return new NuGetVersion(major, minor, checked(patch + 1));
                default: throw new CliException("A version selection is required.");
            }
        }
        catch (OverflowException) { throw new CliException("Version component overflowed its supported numeric range."); }
    }
}
