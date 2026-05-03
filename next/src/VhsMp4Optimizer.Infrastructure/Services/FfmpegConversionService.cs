using System.Diagnostics;
using System.Globalization;
using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Core.Services;

namespace VhsMp4Optimizer.Infrastructure.Services;

public sealed class FfmpegConversionService : IConversionService
{
    public async Task ConvertAsync(
        string ffmpegPath,
        ConversionRequest request,
        IProgress<ConversionProgressInfo>? progress = null,
        CancellationToken cancellationToken = default)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(request.OutputPath)!);

        var startInfo = new ProcessStartInfo
        {
            FileName = ffmpegPath,
            RedirectStandardError = true,
            RedirectStandardOutput = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        foreach (var argument in FfmpegCommandBuilder.BuildArguments(request))
        {
            startInfo.ArgumentList.Add(argument);
        }

        using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("FFmpeg proces nije pokrenut.");
        var stderrTask = process.StandardError.ReadToEndAsync(cancellationToken);
        var progressTask = ConsumeProgressAsync(process.StandardOutput, request, progress, cancellationToken);

        try
        {
            await process.WaitForExitAsync(cancellationToken);
            await progressTask;
        }
        catch (OperationCanceledException)
        {
            TryKillProcess(process);
            throw;
        }

        var errorText = await stderrTask;

        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException($"FFmpeg nije uspeo: {errorText}");
        }
    }

    private static void TryKillProcess(Process process)
    {
        try
        {
            if (!process.HasExited)
            {
                process.Kill(entireProcessTree: true);
            }
        }
        catch
        {
        }
    }

    private static async Task ConsumeProgressAsync(
        StreamReader stdout,
        ConversionRequest request,
        IProgress<ConversionProgressInfo>? progress,
        CancellationToken cancellationToken)
    {
        if (progress is null)
        {
            _ = await stdout.ReadToEndAsync(cancellationToken);
            return;
        }

        var expectedDuration = ResolveExpectedDuration(request);
        var stopwatch = Stopwatch.StartNew();
        var processedSeconds = 0d;
        var speedText = "--";

        while (true)
        {
            var line = await stdout.ReadLineAsync(cancellationToken);
            if (line is null)
            {
                break;
            }

            if (string.IsNullOrWhiteSpace(line))
            {
                continue;
            }

            var separatorIndex = line.IndexOf('=');
            if (separatorIndex <= 0)
            {
                continue;
            }

            var key = line[..separatorIndex];
            var value = line[(separatorIndex + 1)..];
            switch (key)
            {
                case "out_time_ms":
                case "out_time_us":
                    processedSeconds = ParseFfmpegTimeValue(value);
                    break;
                case "out_time":
                    processedSeconds = ParseFfmpegTimestamp(value);
                    break;
                case "speed":
                    speedText = string.IsNullOrWhiteSpace(value) ? "--" : value;
                    break;
                case "progress":
                    var fraction = expectedDuration <= 0
                        ? 0
                        : Math.Clamp(processedSeconds / expectedDuration, 0, 1);
                    TimeSpan? eta = null;
                    if (fraction > 0.001 && fraction < 0.999)
                    {
                        eta = TimeSpan.FromMilliseconds(stopwatch.Elapsed.TotalMilliseconds * ((1 - fraction) / fraction));
                    }

                    progress.Report(new ConversionProgressInfo(
                        fraction,
                        TimeSpan.FromSeconds(processedSeconds),
                        eta,
                        speedText,
                        TimeSpan.FromSeconds(expectedDuration)));
                    break;
            }
        }
    }

    private static double ResolveExpectedDuration(ConversionRequest request)
    {
        var keepRanges = TimelineExportService.GetKeepRanges(request.TimelineProject, request.MediaInfo.DurationSeconds).ToList();
        if (keepRanges.Count == 0)
        {
            keepRanges.Add(new TimeRange { StartSeconds = 0, EndSeconds = request.MediaInfo.DurationSeconds });
        }

        if (request.IsSample)
        {
            var sampleStart = Math.Max(0, request.SampleStartSeconds ?? 0);
            var sampleDuration = Math.Max(1, request.SampleDurationSeconds ?? 120);
            var sampleEnd = sampleStart + sampleDuration;
            keepRanges = keepRanges
                .Select(range => new TimeRange
                {
                    StartSeconds = Math.Max(range.StartSeconds, sampleStart),
                    EndSeconds = Math.Min(range.EndSeconds, sampleEnd)
                })
                .Where(range => range.EndSeconds > range.StartSeconds)
                .ToList();
        }

        var total = keepRanges.Sum(range => Math.Max(0, range.EndSeconds - range.StartSeconds));
        return total > 0 ? total : Math.Max(1, request.MediaInfo.DurationSeconds);
    }

    private static double ParseFfmpegTimeValue(string value)
    {
        if (!double.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out var rawValue))
        {
            return 0;
        }

        return rawValue / 1_000_000d;
    }

    private static double ParseFfmpegTimestamp(string value)
    {
        return TimeSpan.TryParse(value, CultureInfo.InvariantCulture, out var parsed)
            ? parsed.TotalSeconds
            : 0;
    }
}
