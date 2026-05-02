using System.Diagnostics;
using System.Globalization;
using System.Text.Json;
using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Infrastructure.Services;

public sealed class FfprobeMediaProbeService
{
    public MediaInfo Probe(string sourcePath, string ffmpegPath)
    {
        var ffprobePath = FfmpegLocator.ResolveFfprobeFromFfmpeg(ffmpegPath)
            ?? throw new InvalidOperationException("ffprobe nije pronadjen pored ffmpeg.exe niti na PATH-u.");

        var startInfo = new ProcessStartInfo
        {
            FileName = ffprobePath,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        startInfo.ArgumentList.Add("-v");
        startInfo.ArgumentList.Add("error");
        startInfo.ArgumentList.Add("-show_format");
        startInfo.ArgumentList.Add("-show_streams");
        startInfo.ArgumentList.Add("-of");
        startInfo.ArgumentList.Add("json");
        startInfo.ArgumentList.Add(sourcePath);

        using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("ffprobe proces nije pokrenut.");
        var stdout = process.StandardOutput.ReadToEnd();
        var stderr = process.StandardError.ReadToEnd();
        process.WaitForExit();

        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException($"ffprobe nije uspeo: {stderr}");
        }

        using var json = JsonDocument.Parse(stdout);
        var root = json.RootElement;
        var format = root.GetProperty("format");
        var streams = root.GetProperty("streams").EnumerateArray().ToList();
        var video = streams.FirstOrDefault(s => GetString(s, "codec_type") == "video");
        var audio = streams.FirstOrDefault(s => GetString(s, "codec_type") == "audio");

        var width = GetInt(video, "width");
        var height = GetInt(video, "height");
        var resolution = width > 0 && height > 0 ? $"{width}x{height}" : "--";
        var displayAspectRatio = GetString(video, "display_aspect_ratio");
        if (string.IsNullOrWhiteSpace(displayAspectRatio) && width > 0 && height > 0)
        {
            displayAspectRatio = GuessDisplayAspect(width, height);
        }

        var sampleAspectRatio = GetString(video, "sample_aspect_ratio");
        var frameRate = ParseRational(GetString(video, "avg_frame_rate"));
        if (frameRate <= 0)
        {
            frameRate = ParseRational(GetString(video, "r_frame_rate"));
        }

        var durationSeconds = GetDouble(format, "duration");
        var sizeBytes = GetLong(format, "size");
        var overallBitrateKbps = BitsPerSecondToKbps(GetLong(format, "bit_rate"));
        var videoBitrateKbps = BitsPerSecondToKbps(GetLong(video, "bit_rate"));
        var audioBitrateKbps = BitsPerSecondToKbps(GetLong(audio, "bit_rate"));
        var audioChannels = GetInt(audio, "channels");
        var audioSampleRate = GetInt(audio, "sample_rate");
        var videoCodec = GetString(video, "codec_name");
        var audioCodec = GetString(audio, "codec_name");
        var frameCount = GetLong(video, "nb_frames");

        return new MediaInfo
        {
            SourceName = Path.GetFileName(sourcePath),
            SourcePath = Path.GetFullPath(sourcePath),
            Container = GetString(format, "format_name"),
            DurationSeconds = durationSeconds,
            DurationText = FormatDuration(durationSeconds),
            SizeBytes = sizeBytes,
            SizeText = FormatBytes(sizeBytes),
            OverallBitrateKbps = overallBitrateKbps,
            OverallBitrateText = FormatKbps(overallBitrateKbps),
            VideoCodec = string.IsNullOrWhiteSpace(videoCodec) ? "--" : videoCodec,
            Width = width,
            Height = height,
            Resolution = resolution,
            DisplayAspectRatio = string.IsNullOrWhiteSpace(displayAspectRatio) ? "--" : displayAspectRatio,
            SampleAspectRatio = string.IsNullOrWhiteSpace(sampleAspectRatio) ? "--" : sampleAspectRatio,
            FrameRate = frameRate,
            FrameRateText = frameRate > 0 ? $"{frameRate:0.##} fps" : "--",
            FrameCount = frameCount,
            VideoBitrateKbps = videoBitrateKbps,
            VideoBitrateText = FormatKbps(videoBitrateKbps),
            AudioCodec = string.IsNullOrWhiteSpace(audioCodec) ? "--" : audioCodec,
            AudioChannels = audioChannels,
            AudioSampleRateHz = audioSampleRate,
            AudioBitrateKbps = audioBitrateKbps,
            AudioBitrateText = FormatKbps(audioBitrateKbps),
            VideoSummary = $"{videoCodec} | {resolution} | {displayAspectRatio} | {(frameRate > 0 ? $"{frameRate:0.##} fps" : "--")}",
            AudioSummary = $"{audioCodec} | {audioChannels} ch | {audioSampleRate} Hz | {FormatKbps(audioBitrateKbps)}"
        };
    }

    private static string FormatBytes(long bytes)
    {
        if (bytes <= 0)
        {
            return "--";
        }

        var gb = bytes / Math.Pow(1024d, 3d);
        if (gb >= 1d)
        {
            return $"{gb:F2} GB";
        }

        var mb = bytes / Math.Pow(1024d, 2d);
        return $"{mb:F0} MB";
    }

    private static string FormatDuration(double seconds)
    {
        if (seconds <= 0)
        {
            return "--";
        }

        return TimeSpan.FromSeconds(seconds).ToString(@"hh\:mm\:ss", CultureInfo.InvariantCulture);
    }

    private static string FormatKbps(int kbps) => kbps > 0 ? $"{kbps} kbps" : "--";

    private static int BitsPerSecondToKbps(long bitsPerSecond)
        => bitsPerSecond > 0 ? (int)Math.Round(bitsPerSecond / 1000d) : 0;

    private static string GuessDisplayAspect(int width, int height)
    {
        var ratio = width / (double)height;
        return ratio >= 1.6 ? "16:9" : ratio >= 1.2 ? "4:3" : $"{width}:{height}";
    }

    private static double ParseRational(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return 0;
        }

        if (!text.Contains('/'))
        {
            return double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out var single)
                ? single
                : 0;
        }

        var parts = text.Split('/');
        if (parts.Length != 2)
        {
            return 0;
        }

        if (!double.TryParse(parts[0], NumberStyles.Float, CultureInfo.InvariantCulture, out var numerator))
        {
            return 0;
        }

        if (!double.TryParse(parts[1], NumberStyles.Float, CultureInfo.InvariantCulture, out var denominator) || denominator == 0)
        {
            return 0;
        }

        return numerator / denominator;
    }

    private static string GetString(JsonElement element, string propertyName)
    {
        if (element.ValueKind == JsonValueKind.Undefined || !element.TryGetProperty(propertyName, out var property))
        {
            return string.Empty;
        }

        return property.ValueKind == JsonValueKind.String
            ? property.GetString() ?? string.Empty
            : property.ToString();
    }

    private static int GetInt(JsonElement element, string propertyName)
    {
        if (element.ValueKind == JsonValueKind.Undefined || !element.TryGetProperty(propertyName, out var property))
        {
            return 0;
        }

        if (property.ValueKind == JsonValueKind.Number && property.TryGetInt32(out var intValue))
        {
            return intValue;
        }

        return int.TryParse(property.ToString(), NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed)
            ? parsed
            : 0;
    }

    private static long GetLong(JsonElement element, string propertyName)
    {
        if (element.ValueKind == JsonValueKind.Undefined || !element.TryGetProperty(propertyName, out var property))
        {
            return 0;
        }

        if (property.ValueKind == JsonValueKind.Number && property.TryGetInt64(out var value))
        {
            return value;
        }

        return long.TryParse(property.ToString(), NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed)
            ? parsed
            : 0;
    }

    private static double GetDouble(JsonElement element, string propertyName)
    {
        if (element.ValueKind == JsonValueKind.Undefined || !element.TryGetProperty(propertyName, out var property))
        {
            return 0;
        }

        if (property.ValueKind == JsonValueKind.Number && property.TryGetDouble(out var value))
        {
            return value;
        }

        return double.TryParse(property.ToString(), NumberStyles.Float, CultureInfo.InvariantCulture, out var parsed)
            ? parsed
            : 0;
    }
}
