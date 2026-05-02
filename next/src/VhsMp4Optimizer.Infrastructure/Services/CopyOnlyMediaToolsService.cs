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
            await process.WaitForExitAsync(cancellationToken);
            var errorText = await process.StandardError.ReadToEndAsync(cancellationToken);

            if (process.ExitCode != 0)
            {
                throw new InvalidOperationException($"Copy split nije uspeo: {errorText}");
            }

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
            await process.WaitForExitAsync(cancellationToken);
            var errorText = await process.StandardError.ReadToEndAsync(cancellationToken);

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
}

public sealed record CopySplitPart(int PartNumber, double StartSeconds, double DurationSeconds, string OutputPath);
