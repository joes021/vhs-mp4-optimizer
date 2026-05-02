using System.Globalization;
using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Core.Services;

public static class OutputPlanner
{
    public static OutputPlanSummary Build(MediaInfo mediaInfo, BatchSettings settings)
    {
        var profile = ResolveProfile(settings);
        var aspectLabel = ResolveAspectLabel(mediaInfo, settings.AspectMode);
        var (displayWidth, displayHeight) = GetDisplayGeometry(mediaInfo.Width, mediaInfo.Height, aspectLabel);
        var (outputWidth, outputHeight) = ApplyScale(displayWidth, displayHeight, settings.ScaleMode);
        var videoBitrateKbps = ResolveVideoKbps(profile, settings.VideoBitrate);
        var audioBitrateKbps = ParseKbps(profile.AudioBitrate);
        var totalBitrateKbps = Math.Max(1, videoBitrateKbps + audioBitrateKbps);
        var estimatedBytes = Math.Ceiling((mediaInfo.DurationSeconds * totalBitrateKbps * 1000d) / 8d);
        var estimatedGb = estimatedBytes / Math.Pow(1024d, 3d);
        var partCount = settings.SplitOutput
            ? Math.Max(1, (int)Math.Ceiling(estimatedGb / settings.MaxPartGb))
            : 1;
        var usbNote = settings.SplitOutput
            ? $"FAT32 OK, procena: {partCount} delova; exFAT OK"
            : estimatedGb >= 3.95
                ? "FAT32 rizik: ukljuci Split output ili koristi exFAT"
                : "FAT32 OK; exFAT OK";

        var rateControlText = string.IsNullOrWhiteSpace(settings.VideoBitrate)
            ? $"CRF {profile.Crf} | preset {profile.Preset}"
            : $"Target {settings.VideoBitrate}";

        return new OutputPlanSummary
        {
            DisplayOutputName = Path.GetFileNameWithoutExtension(mediaInfo.SourceName) + ".mp4",
            Container = "MP4",
            Resolution = $"{outputWidth}x{outputHeight}",
            DurationText = mediaInfo.DurationText,
            VideoCodecLabel = profile.CodecLabel,
            VideoBitrateComparisonText = $"{FormatKbps(videoBitrateKbps)} | {rateControlText}",
            AudioCodecText = "AAC",
            AudioBitrateText = FormatKbps(audioBitrateKbps),
            BitrateText = $"{FormatKbps(totalBitrateKbps)} est.",
            EncodeEngineText = "CPU / libx264",
            EstimatedSizeText = $"Estimate: {estimatedGb:F2} GB",
            UsbNoteText = $"USB note: {usbNote}",
            AspectText = aspectLabel,
            OutputWidth = outputWidth,
            OutputHeight = outputHeight
        };
    }

    private static (int Width, int Height) ApplyScale(int width, int height, string scaleMode)
    {
        if (width <= 0 || height <= 0)
        {
            return (0, 0);
        }

        return scaleMode switch
        {
            ScaleModes.Pal576p => (Even(width * 576 / (double)height), 576),
            ScaleModes.P720 => (Even(width * 720 / (double)height), 720),
            ScaleModes.P1080 => (Even(width * 1080 / (double)height), 1080),
            _ => (Even(width), Even(height))
        };
    }

    private static (int Width, int Height) GetDisplayGeometry(int sourceWidth, int sourceHeight, string aspectLabel)
    {
        if (sourceWidth <= 0 || sourceHeight <= 0)
        {
            return (0, 0);
        }

        if (string.Equals(aspectLabel, "16:9", StringComparison.OrdinalIgnoreCase) && sourceHeight > 0)
        {
            return (Even(sourceHeight * 16d / 9d), Even(sourceHeight));
        }

        if (string.Equals(aspectLabel, "4:3", StringComparison.OrdinalIgnoreCase) && sourceHeight > 0)
        {
            return (Even(sourceHeight * 4d / 3d), Even(sourceHeight));
        }

        return (Even(sourceWidth), Even(sourceHeight));
    }

    private static string ResolveAspectLabel(MediaInfo mediaInfo, string aspectMode)
    {
        if (string.Equals(aspectMode, AspectModes.Force16x9, StringComparison.OrdinalIgnoreCase))
        {
            return "16:9";
        }

        if (string.Equals(aspectMode, AspectModes.Force4x3, StringComparison.OrdinalIgnoreCase))
        {
            return "4:3";
        }

        if (!string.IsNullOrWhiteSpace(mediaInfo.DisplayAspectRatio) &&
            (mediaInfo.DisplayAspectRatio.Contains("16:9", StringComparison.OrdinalIgnoreCase) ||
             mediaInfo.DisplayAspectRatio.Contains("4:3", StringComparison.OrdinalIgnoreCase)))
        {
            return mediaInfo.DisplayAspectRatio;
        }

        if (!string.IsNullOrWhiteSpace(mediaInfo.SampleAspectRatio) &&
            mediaInfo.Width == 720 && mediaInfo.Height == 576)
        {
            return mediaInfo.SampleAspectRatio switch
            {
                "16:15" => "4:3",
                "64:45" => "16:9",
                _ => GuessAspectFromGeometry(mediaInfo.Width, mediaInfo.Height)
            };
        }

        return GuessAspectFromGeometry(mediaInfo.Width, mediaInfo.Height);
    }

    private static string GuessAspectFromGeometry(int width, int height)
    {
        if (width <= 0 || height <= 0)
        {
            return "--";
        }

        var ratio = width / (double)height;
        if (ratio >= 1.6)
        {
            return "16:9";
        }

        if (ratio >= 1.2)
        {
            return "4:3";
        }

        return $"{width}:{height}";
    }

    private static QualityProfile ResolveProfile(BatchSettings settings)
    {
        return settings.QualityMode switch
        {
            QualityModes.SmallMp4H264 or QualityModes.UsbSmallFile or QualityModes.Phone => new QualityProfile("H.264", 24, "slow", "128k", 3500),
            QualityModes.HighQualityMp4H264 or QualityModes.ArchiveBetterQuality or QualityModes.YoutubeUpload => new QualityProfile("H.264", 20, "slow", "192k", 9000),
            QualityModes.HevcH265Smaller or QualityModes.HevcForNewerDevices or QualityModes.Tablet => new QualityProfile("H.265", 26, "medium", "128k", 2800),
            QualityModes.OldTv => new QualityProfile("H.264", 22, "medium", "160k", 4500),
            QualityModes.LaptopPc => new QualityProfile("H.264", 22, "slow", "160k", 6000),
            QualityModes.TvSmart => new QualityProfile("H.264", 21, "slow", "160k", 6500),
            _ => new QualityProfile("H.264", 22, "slow", "160k", 5000)
        };
    }

    private static int ResolveVideoKbps(QualityProfile profile, string overrideBitrate)
    {
        var parsed = ParseKbps(overrideBitrate);
        return parsed > 0 ? parsed : profile.VideoKbps;
    }

    private static int ParseKbps(string bitrateText)
    {
        if (string.IsNullOrWhiteSpace(bitrateText))
        {
            return 0;
        }

        var trimmed = bitrateText.Trim().TrimEnd('k', 'K');
        return int.TryParse(trimmed, NumberStyles.Integer, CultureInfo.InvariantCulture, out var value)
            ? value
            : 0;
    }

    private static string FormatKbps(int kbps) => kbps > 0 ? $"{kbps} kbps" : "--";

    private static int Even(double value)
    {
        var rounded = Math.Max(2, (int)Math.Round(value));
        return rounded % 2 == 0 ? rounded : rounded + 1;
    }

    private sealed record QualityProfile(string CodecLabel, int Crf, string Preset, string AudioBitrate, int VideoKbps);
}
