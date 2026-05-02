using System.Diagnostics;
using System.Globalization;
using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Infrastructure.Services;

public sealed class PreviewFrameService
{
    public async Task<string?> RenderPreviewAsync(string ffmpegPath, MediaInfo mediaInfo, double sourceSeconds, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath))
        {
            return null;
        }

        var previewDirectory = Path.Combine(
            Path.GetTempPath(),
            "VhsMp4OptimizerNext",
            "preview-cache",
            Path.GetFileNameWithoutExtension(mediaInfo.SourceName));
        Directory.CreateDirectory(previewDirectory);

        var safeSeconds = Math.Max(0, Math.Min(mediaInfo.DurationSeconds, sourceSeconds));
        var previewPath = Path.Combine(previewDirectory, $"frame-{safeSeconds.ToString("0000000.000", CultureInfo.InvariantCulture).Replace('.', '_')}.png");
        if (File.Exists(previewPath))
        {
            return previewPath;
        }

        var args = new[]
        {
            "-y",
            "-ss", safeSeconds.ToString("0.###", CultureInfo.InvariantCulture),
            "-i", mediaInfo.SourcePath,
            "-frames:v", "1",
            "-vf", "scale=960:-2",
            previewPath
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
        await process.WaitForExitAsync(cancellationToken);
        return process.ExitCode == 0 && File.Exists(previewPath) ? previewPath : null;
    }
}
