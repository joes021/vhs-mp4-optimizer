using System.Diagnostics;
using System.Globalization;
using System.Text;
using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Infrastructure.Services;

public sealed class CopyOnlyMediaToolsService
{
    public IReadOnlyList<CopySplitPart> PlanSplit(MediaInfo mediaInfo, string outputDirectory, double maxPartGb)
    {
        ArgumentNullException.ThrowIfNull(mediaInfo);

        var safeMaxPartGb = maxPartGb > 0 ? maxPartGb : 3.8;
        var maxPartBytes = safeMaxPartGb * 1024d * 1024d * 1024d;
        var estimatedPartCount = maxPartBytes <= 0
            ? 2
            : (int)Math.Ceiling(mediaInfo.SizeBytes / maxPartBytes);
        var partCount = Math.Max(2, estimatedPartCount);
        var extension = Path.GetExtension(mediaInfo.SourcePath);
        var baseName = Path.GetFileNameWithoutExtension(mediaInfo.SourceName);
        var segmentDuration = mediaInfo.DurationSeconds / partCount;
        var planned = new List<CopySplitPart>(partCount);

        for (var index = 0; index < partCount; index++)
        {
            var start = segmentDuration * index;
            var end = index == partCount - 1
                ? mediaInfo.DurationSeconds
                : Math.Min(mediaInfo.DurationSeconds, segmentDuration * (index + 1));

            planned.Add(new CopySplitPart(
                index + 1,
                start,
                Math.Max(0.01, end - start),
                Path.Combine(outputDirectory, $"{baseName}-part{index + 1:000}{extension}")));
        }

        return planned;
    }

    public async Task<IReadOnlyList<string>> SplitAsync(
        string ffmpegPath,
        MediaInfo mediaInfo,
        string outputDirectory,
        double maxPartGb,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(ffmpegPath);
        ArgumentNullException.ThrowIfNull(mediaInfo);

        Directory.CreateDirectory(outputDirectory);
        var parts = PlanSplit(mediaInfo, outputDirectory, maxPartGb);
        var outputPattern = BuildSplitOutputPattern(mediaInfo, outputDirectory);
        var plannedSegmentSeconds = parts[0].DurationSeconds;

        try
        {
            var segmentOutputs = await SplitWithSegmentMuxerAsync(
                ffmpegPath,
                mediaInfo.SourcePath,
                outputPattern,
                plannedSegmentSeconds,
                cancellationToken);

            if (segmentOutputs.Count >= 2)
            {
                return segmentOutputs;
            }

            CleanupOutputs(segmentOutputs);
        }
        catch (Exception) when (!cancellationToken.IsCancellationRequested)
        {
            CleanupOutputs(ResolveSplitOutputs(outputPattern));
        }

        var createdFiles = new List<string>(parts.Count);

        foreach (var part in parts)
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = ffmpegPath,
                RedirectStandardError = true,
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            foreach (var argument in BuildSplitArguments(mediaInfo.SourcePath, part))
            {
                startInfo.ArgumentList.Add(argument);
            }

            using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("FFmpeg split proces nije pokrenut.");
            var (_, errorText) = await WaitForProcessAsync(process, cancellationToken);

            if (process.ExitCode != 0)
            {
                throw new InvalidOperationException($"Copy split nije uspeo: {errorText}");
            }

            EnsureOutputExists(part.OutputPath);
            createdFiles.Add(part.OutputPath);
        }

        return createdFiles;
    }

    public async Task JoinAsync(
        string ffmpegPath,
        IReadOnlyList<string> inputPaths,
        string outputPath,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(ffmpegPath);
        ArgumentNullException.ThrowIfNull(inputPaths);
        ArgumentException.ThrowIfNullOrWhiteSpace(outputPath);

        if (inputPaths.Count < 2)
        {
            throw new InvalidOperationException("Za join su potrebna najmanje 2 ulazna fajla.");
        }

        var outputDirectory = Path.GetDirectoryName(outputPath);
        if (!string.IsNullOrWhiteSpace(outputDirectory))
        {
            Directory.CreateDirectory(outputDirectory);
        }

        var concatListPath = Path.Combine(Path.GetTempPath(), $"vhs-mp4-join-{Guid.NewGuid():N}.txt");
        await File.WriteAllTextAsync(concatListPath, BuildConcatListContent(inputPaths), Encoding.UTF8, cancellationToken);

        try
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = ffmpegPath,
                RedirectStandardError = true,
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            foreach (var argument in BuildJoinArguments(concatListPath, outputPath))
            {
                startInfo.ArgumentList.Add(argument);
            }

            using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("FFmpeg join proces nije pokrenut.");
            var (_, errorText) = await WaitForProcessAsync(process, cancellationToken);

            if (process.ExitCode != 0)
            {
                throw new InvalidOperationException($"Copy join nije uspeo: {errorText}");
            }
        }
        finally
        {
            if (File.Exists(concatListPath))
            {
                File.Delete(concatListPath);
            }
        }
    }

    public static IReadOnlyList<string> BuildSplitArguments(string sourcePath, CopySplitPart part)
    {
        return
        [
            "-y",
            "-i", sourcePath,
            "-ss", part.StartSeconds.ToString("0.###", CultureInfo.InvariantCulture),
            "-t", part.DurationSeconds.ToString("0.###", CultureInfo.InvariantCulture),
            "-c", "copy",
            part.OutputPath
        ];
    }

    public static IReadOnlyList<string> BuildSegmentSplitArguments(
        string sourcePath,
        string outputPattern,
        double segmentSeconds)
    {
        var arguments = new List<string>
        {
            "-y",
            "-i", sourcePath,
            "-map", "0",
            "-c", "copy",
            "-f", "segment",
            "-segment_time", segmentSeconds.ToString("0.###", CultureInfo.InvariantCulture),
            "-segment_start_number", "1",
            "-reset_timestamps", "1"
        };

        var extension = Path.GetExtension(outputPattern);
        var formatName = ResolveSegmentFormat(extension);
        if (!string.IsNullOrWhiteSpace(formatName))
        {
            arguments.Add("-segment_format");
            arguments.Add(formatName);

            if (string.Equals(formatName, "mp4", StringComparison.OrdinalIgnoreCase))
            {
                arguments.Add("-segment_format_options");
                arguments.Add("movflags=+faststart");
            }
        }

        arguments.Add(outputPattern);
        return arguments;
    }

    public static IReadOnlyList<string> BuildJoinArguments(string concatListPath, string outputPath)
    {
        return
        [
            "-y",
            "-f", "concat",
            "-safe", "0",
            "-i", concatListPath,
            "-c", "copy",
            outputPath
        ];
    }

    public static string BuildConcatListContent(IReadOnlyList<string> inputPaths)
    {
        var builder = new StringBuilder();
        foreach (var inputPath in inputPaths)
        {
            builder.Append("file '")
                .Append(inputPath.Replace("'", "'\\''", StringComparison.Ordinal))
                .AppendLine("'");
        }

        return builder.ToString();
    }

    private static async Task<IReadOnlyList<string>> SplitWithSegmentMuxerAsync(
        string ffmpegPath,
        string sourcePath,
        string outputPattern,
        double segmentSeconds,
        CancellationToken cancellationToken)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = ffmpegPath,
            RedirectStandardError = true,
            RedirectStandardOutput = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        foreach (var argument in BuildSegmentSplitArguments(sourcePath, outputPattern, segmentSeconds))
        {
            startInfo.ArgumentList.Add(argument);
        }

        using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("FFmpeg segment split proces nije pokrenut.");
        var (_, errorText) = await WaitForProcessAsync(process, cancellationToken);

        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException($"Copy split nije uspeo: {errorText}");
        }

        var outputs = ResolveSplitOutputs(outputPattern);
        foreach (var output in outputs)
        {
            EnsureOutputExists(output);
        }

        return outputs;
    }

    private static string BuildSplitOutputPattern(MediaInfo mediaInfo, string outputDirectory)
    {
        var extension = Path.GetExtension(mediaInfo.SourcePath);
        var baseName = Path.GetFileNameWithoutExtension(mediaInfo.SourceName);
        return Path.Combine(outputDirectory, $"{baseName}-part%03d{extension}");
    }

    private static IReadOnlyList<string> ResolveSplitOutputs(string outputPattern)
    {
        var directory = Path.GetDirectoryName(outputPattern);
        if (string.IsNullOrWhiteSpace(directory) || !Directory.Exists(directory))
        {
            return [];
        }

        var searchPattern = Path.GetFileName(outputPattern)
            .Replace("%03d", "*", StringComparison.OrdinalIgnoreCase)
            .Replace("%3d", "*", StringComparison.OrdinalIgnoreCase)
            .Replace("%d", "*", StringComparison.OrdinalIgnoreCase);

        return Directory.GetFiles(directory, searchPattern, SearchOption.TopDirectoryOnly)
            .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static void CleanupOutputs(IReadOnlyList<string> outputs)
    {
        foreach (var output in outputs)
        {
            if (!File.Exists(output))
            {
                continue;
            }

            File.Delete(output);
        }
    }

    private static void EnsureOutputExists(string outputPath)
    {
        if (!File.Exists(outputPath))
        {
            throw new InvalidOperationException($"Ocekivani split deo nije napravljen: {outputPath}");
        }

        var fileInfo = new FileInfo(outputPath);
        if (fileInfo.Length <= 0)
        {
            throw new InvalidOperationException($"Split deo je prazan: {outputPath}");
        }
    }

    private static string? ResolveSegmentFormat(string extension)
    {
        return extension.ToLowerInvariant() switch
        {
            ".mp4" => "mp4",
            ".m4v" => "mp4",
            ".mov" => "mov",
            ".avi" => "avi",
            ".mkv" => "matroska",
            _ => null
        };
    }

    private static async Task<(string StandardOutput, string StandardError)> WaitForProcessAsync(
        Process process,
        CancellationToken cancellationToken)
    {
        var outputTask = process.StandardOutput.ReadToEndAsync(cancellationToken);
        var errorTask = process.StandardError.ReadToEndAsync(cancellationToken);

        await process.WaitForExitAsync(cancellationToken);

        return (await outputTask, await errorTask);
    }
}

public sealed record CopySplitPart(int PartNumber, double StartSeconds, double DurationSeconds, string OutputPath);
