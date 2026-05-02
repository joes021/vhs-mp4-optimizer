using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Core.Services;

namespace VhsMp4Optimizer.Infrastructure.Services;

public sealed class SourceScanService : ISourceScanService
{
    private static readonly HashSet<string> SupportedExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".mp4", ".avi", ".mpg", ".mpeg", ".mov", ".mkv", ".m4v", ".wmv", ".ts", ".m2ts", ".vob"
    };

    private readonly Func<string, string, MediaInfo> _probeMediaInfo;

    public SourceScanService(Func<string, string, MediaInfo>? probeMediaInfo = null)
    {
        var probeService = new FfprobeMediaProbeService();
        _probeMediaInfo = probeMediaInfo ?? ((sourcePath, ffmpegPath) => probeService.Probe(sourcePath, ffmpegPath));
    }

    public IReadOnlyList<QueueItemSummary> Scan(BatchSettings settings, string ffmpegPath, IReadOnlyList<string>? explicitSourcePaths = null)
    {
        var inputPath = settings.InputPath;
        if (string.IsNullOrWhiteSpace(inputPath))
        {
            return Array.Empty<QueueItemSummary>();
        }

        var sourceFiles = ResolveSourceFiles(inputPath, explicitSourcePaths);
        var outputDirectory = ResolveOutputDirectory(inputPath, settings.OutputDirectory);

        return sourceFiles
            .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
            .Select(path => BuildItem(path, outputDirectory, settings, ffmpegPath))
            .ToList();
    }

    public string ResolveOutputDirectory(string inputPath, string outputDirectory)
    {
        if (!string.IsNullOrWhiteSpace(outputDirectory))
        {
            return Path.GetFullPath(outputDirectory);
        }

        if (Directory.Exists(inputPath))
        {
            return Path.Combine(Path.GetFullPath(inputPath), "vhs-mp4-output");
        }

        var parent = Path.GetDirectoryName(Path.GetFullPath(inputPath)) ?? Path.GetFullPath(inputPath);
        return Path.Combine(parent, "vhs-mp4-output");
    }

    private QueueItemSummary BuildItem(string sourcePath, string outputDirectory, BatchSettings settings, string ffmpegPath)
    {
        var sourceName = Path.GetFileName(sourcePath);
        var outputPath = Path.Combine(outputDirectory, Path.GetFileNameWithoutExtension(sourceName) + ".mp4");
        var outputPattern = settings.SplitOutput
            ? Path.Combine(outputDirectory, Path.GetFileNameWithoutExtension(sourceName) + "-part%03d.mp4")
            : outputPath;
        var mediaInfo = _probeMediaInfo(sourcePath, ffmpegPath);
        var plannedOutput = OutputPlanner.Build(mediaInfo, settings);

        return new QueueItemSummary
        {
            SourceFile = sourceName,
            SourcePath = sourcePath,
            OutputFile = Path.GetFileName(outputPath),
            OutputPath = outputPath,
            OutputPattern = outputPattern,
            Container = mediaInfo.Container,
            Resolution = mediaInfo.Resolution,
            Duration = mediaInfo.DurationText,
            Video = mediaInfo.VideoSummary,
            Audio = mediaInfo.AudioSummary,
            Status = "queued",
            MediaInfo = mediaInfo,
            PlannedOutput = plannedOutput,
            TransformSettings = null
        };
    }

    public static IReadOnlyList<string> ResolveSourceFiles(string inputPath, IReadOnlyList<string>? explicitSourcePaths = null)
    {
        if (explicitSourcePaths is { Count: > 0 })
        {
            return explicitSourcePaths
                .Where(File.Exists)
                .Select(Path.GetFullPath)
                .Where(path => SupportedExtensions.Contains(Path.GetExtension(path)))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
        }

        if (File.Exists(inputPath))
        {
            return SupportedExtensions.Contains(Path.GetExtension(inputPath))
                ? new[] { Path.GetFullPath(inputPath) }
                : Array.Empty<string>();
        }

        if (!Directory.Exists(inputPath))
        {
            return Array.Empty<string>();
        }

        return Directory
            .EnumerateFiles(inputPath, "*.*", SearchOption.AllDirectories)
            .Where(path => SupportedExtensions.Contains(Path.GetExtension(path)))
            .ToList();
    }
}
