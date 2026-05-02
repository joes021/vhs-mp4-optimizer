using System.Diagnostics;
using System.Globalization;
using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Infrastructure.Services;

public sealed class PreviewFrameService : IPreviewFrameService
{
    public async Task<string?> RenderPreviewAsync(string ffmpegPath, MediaInfo mediaInfo, double sourceSeconds, ItemTransformSettings? transformSettings = null, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath))
        {
            throw new InvalidOperationException("ffmpeg.exe nije pronadjen za preview.");
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

        var filters = new List<string>();
        if (transformSettings?.Crop is { HasCrop: true } crop)
        {
            filters.Add($"crop=in_w-{crop.Left + crop.Right}:in_h-{crop.Top + crop.Bottom}:{crop.Left}:{crop.Top}");
        }

        filters.Add("scale=960:-2");
        var args = new List<string>
        {
            "-y",
            "-hide_banner",
            "-loglevel", "error",
            "-ss", safeSeconds.ToString("0.###", CultureInfo.InvariantCulture),
            "-i", mediaInfo.SourcePath,
            "-frames:v", "1",
            "-an",
            "-sn",
            "-vf", string.Join(",", filters),
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
        var errorText = await process.StandardError.ReadToEndAsync(cancellationToken);
        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException($"FFmpeg preview nije uspeo: {errorText}");
        }

        if (!File.Exists(previewPath))
        {
            throw new InvalidOperationException("FFmpeg preview nije napravio PNG frame.");
        }

        return previewPath;
    }
}
