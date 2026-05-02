using System.Diagnostics;
using System.Globalization;
using System.Text.RegularExpressions;
using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Infrastructure.Services;

public sealed class CropDetectService
{
    private static readonly Regex CropRegex = new(@"crop=(\d+):(\d+):(\d+):(\d+)", RegexOptions.Compiled);

    public async Task<CropSettings?> DetectAsync(string ffmpegPath, MediaInfo mediaInfo, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath))
        {
            return null;
        }

        var start = mediaInfo.DurationSeconds > 150 ? 30 : 0;
        var duration = Math.Min(8, Math.Max(3, mediaInfo.DurationSeconds - start));
        var args = new[]
        {
            "-hide_banner",
            "-ss", start.ToString("0.###", CultureInfo.InvariantCulture),
            "-t", duration.ToString("0.###", CultureInfo.InvariantCulture),
            "-i", mediaInfo.SourcePath,
            "-vf", "cropdetect=24:16:0",
            "-an",
            "-sn",
            "-f", "null",
            "-"
        };

        using var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = ffmpegPath,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardError = true,
                RedirectStandardOutput = true
            }
        };

        foreach (var arg in args)
        {
            process.StartInfo.ArgumentList.Add(arg);
        }

        process.Start();
        var stderr = await process.StandardError.ReadToEndAsync(cancellationToken);
        await process.WaitForExitAsync(cancellationToken);
        if (process.ExitCode != 0)
        {
            return null;
        }

        var crop = ParseCrop(stderr, mediaInfo.Width, mediaInfo.Height);
        return crop is { HasCrop: true } ? crop : null;
    }

    public static CropSettings? ParseCrop(string stderr, int sourceWidth, int sourceHeight)
    {
        var matches = CropRegex.Matches(stderr);
        if (matches.Count == 0)
        {
            return null;
        }

        var best = matches[^1];
        var detectedWidth = int.Parse(best.Groups[1].Value, CultureInfo.InvariantCulture);
        var detectedHeight = int.Parse(best.Groups[2].Value, CultureInfo.InvariantCulture);
        var left = int.Parse(best.Groups[3].Value, CultureInfo.InvariantCulture);
        var top = int.Parse(best.Groups[4].Value, CultureInfo.InvariantCulture);
        var right = Math.Max(0, sourceWidth - detectedWidth - left);
        var bottom = Math.Max(0, sourceHeight - detectedHeight - top);

        return new CropSettings
        {
            Left = left,
            Top = top,
            Right = right,
            Bottom = bottom
        };
    }
}
