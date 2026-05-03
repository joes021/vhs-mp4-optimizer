using System;

namespace VhsMp4Optimizer.App.Services;

public static class AboutDisplayInfoBuilder
{
    public static AboutDisplayInfo Build(
        string? informationalVersion,
        string? fallbackVersion,
        string installPath,
        string guidePath,
        string branchHint)
    {
        var semanticVersion = ExtractSemanticVersion(informationalVersion);
        if (string.IsNullOrWhiteSpace(semanticVersion))
        {
            semanticVersion = NormalizeFallbackVersion(fallbackVersion);
        }

        if (string.IsNullOrWhiteSpace(semanticVersion))
        {
            semanticVersion = "dev";
        }

        var gitRef = ExtractGitRef(informationalVersion);
        var releaseTag = $"vhs-mp4-optimizer-next-{semanticVersion}";

        return new AboutDisplayInfo(
            AppName: "VHS MP4 Optimizer Next",
            Version: semanticVersion,
            ReleaseTag: releaseTag,
            GitRef: gitRef,
            InstallPath: installPath,
            GuidePath: guidePath,
            BranchHint: branchHint);
    }

    private static string? ExtractSemanticVersion(string? informationalVersion)
    {
        if (string.IsNullOrWhiteSpace(informationalVersion))
        {
            return null;
        }

        var parts = informationalVersion.Split('+', 2, StringSplitOptions.TrimEntries);
        return NormalizeFallbackVersion(parts[0]);
    }

    private static string ExtractGitRef(string? informationalVersion)
    {
        if (string.IsNullOrWhiteSpace(informationalVersion))
        {
            return "nije dostupan";
        }

        var parts = informationalVersion.Split('+', 2, StringSplitOptions.TrimEntries);
        if (parts.Length < 2 || string.IsNullOrWhiteSpace(parts[1]))
        {
            return "nije dostupan";
        }

        var gitRef = parts[1].Trim();
        return gitRef.Length > 7 ? gitRef[..7] : gitRef;
    }

    private static string? NormalizeFallbackVersion(string? version)
    {
        if (string.IsNullOrWhiteSpace(version))
        {
            return null;
        }

        var trimmed = version.Trim();
        if (Version.TryParse(trimmed, out var parsed))
        {
            return $"{parsed.Major}.{Math.Max(0, parsed.Minor)}.{Math.Max(0, parsed.Build)}";
        }

        return trimmed;
    }
}

public sealed record AboutDisplayInfo(
    string AppName,
    string Version,
    string ReleaseTag,
    string GitRef,
    string InstallPath,
    string GuidePath,
    string BranchHint);
