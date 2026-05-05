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
            SanitizePreviewCacheComponent(mediaInfo.SourceName));
        Directory.CreateDirectory(previewDirectory);

        var safeSeconds = Math.Max(0, Math.Min(mediaInfo.DurationSeconds, sourceSeconds));
        var previewPath = Path.Combine(
            previewDirectory,
            $"frame-{safeSeconds.ToString("0000000.000", CultureInfo.InvariantCulture).Replace('.', '_')}-{BuildTransformCacheSuffix(transformSettings, mediaInfo)}.png");
        if (File.Exists(previewPath))
        {
            return previewPath;
        }

        var filters = new List<string>();
        if (transformSettings?.Crop is { HasCrop: true } crop)
        {
            filters.Add($"crop=in_w-{crop.Left + crop.Right}:in_h-{crop.Top + crop.Bottom}:{crop.Left}:{crop.Top}");
        }

        if (ShouldUsePreviewDeinterlace(mediaInfo))
        {
            filters.Add("yadif=0:-1:0");
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

    internal static string SanitizePreviewCacheComponent(string? sourceName)
    {
        var baseName = sourceName ?? string.Empty;
        var extensionIndex = baseName.LastIndexOf('.');
        if (extensionIndex > 0)
        {
            baseName = baseName[..extensionIndex];
        }

        var invalidFileNameChars = Path.GetInvalidFileNameChars();
        var sanitizedChars = baseName
            .Select(ch => invalidFileNameChars.Contains(ch) ? '_' : ch)
            .ToArray();

        var sanitized = new string(sanitizedChars)
            .Trim()
            .TrimEnd('.', ' ');

        while (sanitized.Contains("__", StringComparison.Ordinal))
        {
            sanitized = sanitized.Replace("__", "_", StringComparison.Ordinal);
        }

        sanitized = sanitized.Trim('_', '.', ' ');
        return string.IsNullOrWhiteSpace(sanitized) ? "preview-source" : sanitized;
    }

    internal static string BuildTransformCacheSuffix(ItemTransformSettings? transformSettings, MediaInfo? mediaInfo)
    {
        var previewProfile = mediaInfo is not null && ShouldUsePreviewDeinterlace(mediaInfo)
            ? "preview-dv-yadif"
            : "preview-base";

        if (transformSettings is null)
        {
            return $"{previewProfile}-base";
        }

        var crop = transformSettings.Crop;
        var cropSuffix = crop.HasCrop
            ? $"crop-{crop.Left}-{crop.Top}-{crop.Right}-{crop.Bottom}"
            : "nocrop";
        var aspectSuffix = string.IsNullOrWhiteSpace(transformSettings.AspectMode)
            ? "aspect-auto"
            : "aspect-" + SanitizePreviewCacheComponent(transformSettings.AspectMode);
        return $"{previewProfile}-{cropSuffix}-{aspectSuffix}";
    }

    internal static bool ShouldUsePreviewDeinterlace(MediaInfo mediaInfo)
    {
        if (string.Equals(mediaInfo.VideoCodec, "dvvideo", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        return string.Equals(mediaInfo.Container, "avi", StringComparison.OrdinalIgnoreCase);
    }
}
