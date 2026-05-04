using System.Globalization;
using System.Linq;
using System.Text;
using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Infrastructure.Services;

public sealed class ConversionReportService : IConversionReportService
{
    public async Task<string> WriteItemReportAsync(
        string outputDirectory,
        string presetName,
        ConversionRequest request,
        QueueItemSummary item,
        IReadOnlyList<string> ffmpegArguments,
        TimeSpan elapsed,
        CancellationToken cancellationToken = default)
    {
        var reportsDirectory = EnsureReportsDirectory(outputDirectory);
        var reportPath = Path.Combine(reportsDirectory, $"{SanitizeFileName(Path.GetFileNameWithoutExtension(item.SourceFile))}-report.txt");
        var builder = new StringBuilder();
        var planned = item.PlannedOutput;

        builder.AppendLine("VHS MP4 Optimizer Next - Item report");
        builder.AppendLine($"Generated: {DateTimeOffset.Now:yyyy-MM-dd HH:mm:ss zzz}");
        builder.AppendLine();
        builder.AppendLine($"Source file: {item.SourceFile}");
        builder.AppendLine($"Source path: {item.SourcePath}");
        builder.AppendLine($"Output file: {item.OutputFile}");
        builder.AppendLine($"Output path: {item.OutputPath}");
        if (request.Settings.SplitOutput && !string.IsNullOrWhiteSpace(item.OutputPattern))
        {
            builder.AppendLine($"Output pattern: {item.OutputPattern}");
        }
        builder.AppendLine($"Workflow preset: {presetName}");
        builder.AppendLine($"Elapsed: {FormatTimeSpan(elapsed)}");
        builder.AppendLine();
        builder.AppendLine("Requested settings:");
        builder.AppendLine($"  Quality mode: {request.Settings.QualityMode}");
        builder.AppendLine($"  Scale: {request.Settings.ScaleMode}");
        builder.AppendLine($"  Aspect mode: {request.Settings.AspectMode}");
        builder.AppendLine($"  Video bitrate: {request.Settings.VideoBitrate}");
        builder.AppendLine($"  Audio bitrate: {request.Settings.AudioBitrate}");
        builder.AppendLine($"  Deinterlace: {request.Settings.DeinterlaceMode}");
        builder.AppendLine($"  Denoise: {request.Settings.DenoiseMode}");
        builder.AppendLine($"  Encode engine: {request.Settings.EncodeEngine}");
        builder.AppendLine($"  Split output: {(request.Settings.SplitOutput ? "Yes" : "No")}");
        builder.AppendLine($"  Max part GB: {request.Settings.MaxPartGb.ToString("0.0", CultureInfo.InvariantCulture)}");
        if (request.TransformSettings is not null)
        {
            builder.AppendLine($"  Crop: {request.TransformSettings.Crop.Left},{request.TransformSettings.Crop.Top},{request.TransformSettings.Crop.Right},{request.TransformSettings.Crop.Bottom}");
        }

        if (planned is not null)
        {
            builder.AppendLine();
            builder.AppendLine("Planned output:");
            builder.AppendLine($"  Container: {planned.Container}");
            builder.AppendLine($"  Resolution: {planned.Resolution}");
            builder.AppendLine($"  Duration: {planned.DurationText}");
            builder.AppendLine($"  Video codec: {planned.VideoCodecLabel}");
            builder.AppendLine($"  Video bitrate: {planned.VideoBitrateComparisonText}");
            builder.AppendLine($"  Audio codec: {planned.AudioCodecText}");
            builder.AppendLine($"  Audio bitrate: {planned.AudioBitrateText}");
            builder.AppendLine($"  Combined bitrate: {planned.BitrateText}");
            builder.AppendLine($"  Encode engine: {planned.EncodeEngineText}");
            builder.AppendLine($"  Estimated size: {planned.EstimatedSizeText}");
            builder.AppendLine($"  USB note: {planned.UsbNoteText}");
            builder.AppendLine($"  Split mode: {planned.SplitModeText}");
            builder.AppendLine($"  Crop: {planned.CropText}");
            builder.AppendLine($"  Aspect: {planned.AspectText}");
        }

        builder.AppendLine();
        builder.AppendLine("FFmpeg arguments:");
        builder.AppendLine("  " + string.Join(" ", ffmpegArguments.Select(QuoteArgument)));

        await File.WriteAllTextAsync(reportPath, builder.ToString(), Encoding.UTF8, cancellationToken);
        return reportPath;
    }

    public async Task<string> WriteBatchReportAsync(
        string outputDirectory,
        string presetName,
        BatchSettings settings,
        IReadOnlyList<QueueItemSummary> processedItems,
        int convertedCount,
        int failedCount,
        CancellationToken cancellationToken = default)
    {
        var reportsDirectory = EnsureReportsDirectory(outputDirectory);
        var reportPath = Path.Combine(reportsDirectory, $"batch-report-{DateTime.Now:yyyyMMdd-HHmmss}.txt");
        var builder = new StringBuilder();

        builder.AppendLine("VHS MP4 Optimizer Next - Batch report");
        builder.AppendLine($"Generated: {DateTimeOffset.Now:yyyy-MM-dd HH:mm:ss zzz}");
        builder.AppendLine($"Workflow preset: {presetName}");
        builder.AppendLine($"Converted: {convertedCount}");
        builder.AppendLine($"Failed: {failedCount}");
        builder.AppendLine();
        builder.AppendLine("Batch settings:");
        builder.AppendLine($"  Quality mode: {settings.QualityMode}");
        builder.AppendLine($"  Scale: {settings.ScaleMode}");
        builder.AppendLine($"  Aspect mode: {settings.AspectMode}");
        builder.AppendLine($"  Video bitrate: {settings.VideoBitrate}");
        builder.AppendLine($"  Audio bitrate: {settings.AudioBitrate}");
        builder.AppendLine($"  Deinterlace: {settings.DeinterlaceMode}");
        builder.AppendLine($"  Denoise: {settings.DenoiseMode}");
        builder.AppendLine($"  Encode engine: {settings.EncodeEngine}");
        builder.AppendLine($"  Split output: {(settings.SplitOutput ? "Yes" : "No")}");
        builder.AppendLine($"  Max part GB: {settings.MaxPartGb.ToString("0.0", CultureInfo.InvariantCulture)}");
        builder.AppendLine();
        builder.AppendLine("Processed files:");

        foreach (var item in processedItems)
        {
            builder.AppendLine($"- {item.SourceFile} -> {item.OutputFile} | status: {item.Status}");
            builder.AppendLine($"  Output path: {item.OutputPath}");
            if (!string.IsNullOrWhiteSpace(item.OutputPattern) && !string.Equals(item.OutputPattern, item.OutputPath, StringComparison.OrdinalIgnoreCase))
            {
                builder.AppendLine($"  Output pattern: {item.OutputPattern}");
            }
            if (!string.IsNullOrWhiteSpace(item.ReportPath))
            {
                builder.AppendLine($"  Item report: {item.ReportPath}");
            }
        }

        await File.WriteAllTextAsync(reportPath, builder.ToString(), Encoding.UTF8, cancellationToken);
        return reportPath;
    }

    private static string EnsureReportsDirectory(string outputDirectory)
    {
        var reportsDirectory = Path.Combine(outputDirectory, "reports");
        Directory.CreateDirectory(reportsDirectory);
        return reportsDirectory;
    }

    private static string SanitizeFileName(string value)
    {
        var invalid = Path.GetInvalidFileNameChars();
        return new string(value.Select(ch => invalid.Contains(ch) ? '_' : ch).ToArray()).Trim();
    }

    private static string QuoteArgument(string argument)
    {
        if (argument.Contains(' ') || argument.Contains('"'))
        {
            return "\"" + argument.Replace("\"", "\\\"") + "\"";
        }

        return argument;
    }

    private static string FormatTimeSpan(TimeSpan value)
        => value.ToString(@"hh\:mm\:ss", CultureInfo.InvariantCulture);
}
