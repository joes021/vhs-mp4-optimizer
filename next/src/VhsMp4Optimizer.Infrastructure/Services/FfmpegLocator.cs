using System.Diagnostics;

namespace VhsMp4Optimizer.Infrastructure.Services;

public static class FfmpegLocator
{
    public static string? Resolve()
    {
        var fromPath = FindOnPath("ffmpeg.exe");
        if (!string.IsNullOrWhiteSpace(fromPath))
        {
            return fromPath;
        }

        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var wingetPackages = Path.Combine(localAppData, "Microsoft", "WinGet", "Packages");
        if (Directory.Exists(wingetPackages))
        {
            var candidates = Directory.EnumerateFiles(wingetPackages, "ffmpeg.exe", SearchOption.AllDirectories)
                .Where(path => path.Contains("ffmpeg", StringComparison.OrdinalIgnoreCase))
                .OrderByDescending(File.GetLastWriteTimeUtc)
                .ToList();
            if (candidates.Count > 0)
            {
                return candidates[0];
            }
        }

        return null;
    }

    public static string? ResolveFfprobeFromFfmpeg(string? ffmpegPath)
    {
        if (string.IsNullOrWhiteSpace(ffmpegPath))
        {
            return FindOnPath("ffprobe.exe");
        }

        var directory = Path.GetDirectoryName(ffmpegPath);
        if (string.IsNullOrWhiteSpace(directory))
        {
            return null;
        }

        var ffprobePath = Path.Combine(directory, "ffprobe.exe");
        if (File.Exists(ffprobePath))
        {
            return ffprobePath;
        }

        return FindOnPath("ffprobe.exe");
    }

    private static string? FindOnPath(string executableName)
    {
        var path = Environment.GetEnvironmentVariable("PATH");
        if (string.IsNullOrWhiteSpace(path))
        {
            return null;
        }

        foreach (var segment in path.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            try
            {
                var candidate = Path.Combine(segment, executableName);
                if (File.Exists(candidate))
                {
                    return candidate;
                }
            }
            catch
            {
            }
        }

        return null;
    }
}
