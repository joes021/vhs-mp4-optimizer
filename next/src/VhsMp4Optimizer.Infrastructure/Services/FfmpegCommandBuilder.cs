using System.Globalization;
using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Core.Services;

namespace VhsMp4Optimizer.Infrastructure.Services;

public static class FfmpegCommandBuilder
{
    public static IReadOnlyList<string> BuildArguments(ConversionRequest request)
    {
        var args = new List<string> { "-y", "-i", request.MediaInfo.SourcePath };
        var plan = OutputPlanner.Build(request.MediaInfo, request.Settings);
        var keepRanges = BuildEffectiveRanges(request);
        var hasAudio = !string.IsNullOrWhiteSpace(request.MediaInfo.AudioCodec) && request.MediaInfo.AudioCodec != "--";
        var useFilterComplex = keepRanges.Count != 1
            || keepRanges[0].StartSeconds > 0
            || keepRanges[0].EndSeconds < request.MediaInfo.DurationSeconds
            || plan.OutputWidth != request.MediaInfo.Width
            || plan.OutputHeight != request.MediaInfo.Height;

        var profile = ResolveProfile(request.Settings.QualityMode);

        if (useFilterComplex)
        {
            args.Add("-filter_complex");
            args.Add(BuildFilterComplex(keepRanges, hasAudio, plan.OutputWidth, plan.OutputHeight));
            args.Add("-map");
            args.Add("[vout]");
            if (hasAudio)
            {
                args.Add("-map");
                args.Add("[aout]");
            }
        }

        args.Add("-c:v");
        args.Add(profile.VideoCodec);

        if (!string.IsNullOrWhiteSpace(request.Settings.VideoBitrate))
        {
            args.Add("-b:v");
            args.Add(request.Settings.VideoBitrate);
        }
        else
        {
            args.Add("-crf");
            args.Add(profile.Crf.ToString(CultureInfo.InvariantCulture));
        }

        args.Add("-preset");
        args.Add(profile.Preset);
        args.Add("-c:a");
        args.Add("aac");
        args.Add("-b:a");
        args.Add(string.IsNullOrWhiteSpace(request.Settings.AudioBitrate) ? profile.AudioBitrate : request.Settings.AudioBitrate);
        args.Add("-movflags");
        args.Add("+faststart");
        args.Add(request.OutputPath);
        return args;
    }

    private static IReadOnlyList<TimeRange> BuildEffectiveRanges(ConversionRequest request)
    {
        var keepRanges = TimelineExportService.GetKeepRanges(request.TimelineProject, request.MediaInfo.DurationSeconds).ToList();
        if (!request.IsSample)
        {
            return keepRanges;
        }

        var sampleStart = Math.Max(0, request.SampleStartSeconds ?? 0);
        var sampleDuration = Math.Max(1, request.SampleDurationSeconds ?? 120);
        var sampleEnd = sampleStart + sampleDuration;
        var trimmed = new List<TimeRange>();
        foreach (var range in keepRanges)
        {
            var start = Math.Max(range.StartSeconds, sampleStart);
            var end = Math.Min(range.EndSeconds, sampleEnd);
            if (end > start)
            {
                trimmed.Add(new TimeRange { StartSeconds = start, EndSeconds = end });
            }
        }

        return trimmed.Count > 0 ? trimmed : keepRanges.Take(1).ToList();
    }

    private static string BuildFilterComplex(IReadOnlyList<TimeRange> keepRanges, bool hasAudio, int outputWidth, int outputHeight)
    {
        var parts = new List<string>();
        var videoLabels = new List<string>();
        var audioLabels = new List<string>();

        for (var i = 0; i < keepRanges.Count; i++)
        {
            var range = keepRanges[i];
            var vLabel = $"v{i}";
            var aLabel = $"a{i}";
            parts.Add($"[0:v]trim=start={FormatSeconds(range.StartSeconds)}:end={FormatSeconds(range.EndSeconds)},setpts=PTS-STARTPTS[{vLabel}]");
            videoLabels.Add($"[{vLabel}]");
            if (hasAudio)
            {
                parts.Add($"[0:a]atrim=start={FormatSeconds(range.StartSeconds)}:end={FormatSeconds(range.EndSeconds)},asetpts=PTS-STARTPTS[{aLabel}]");
                audioLabels.Add($"[{aLabel}]");
            }
        }

        if (hasAudio)
        {
            parts.Add($"{string.Concat(videoLabels)}{string.Concat(audioLabels)}concat=n={keepRanges.Count}:v=1:a=1[vcat][aout]");
        }
        else
        {
            parts.Add($"{string.Concat(videoLabels)}concat=n={keepRanges.Count}:v=1:a=0[vcat]");
        }

        parts.Add($"[vcat]scale={outputWidth}:{outputHeight}[vout]");
        return string.Join(";", parts);
    }

    private static string FormatSeconds(double seconds) => seconds.ToString("0.###", CultureInfo.InvariantCulture);

    private static (string VideoCodec, int Crf, string Preset, string AudioBitrate) ResolveProfile(string qualityMode)
    {
        return qualityMode switch
        {
            QualityModes.HevcH265Smaller or QualityModes.HevcForNewerDevices => ("libx265", 26, "medium", "128k"),
            QualityModes.SmallMp4H264 or QualityModes.UsbSmallFile or QualityModes.Phone => ("libx264", 24, "slow", "128k"),
            QualityModes.HighQualityMp4H264 or QualityModes.ArchiveBetterQuality or QualityModes.YoutubeUpload => ("libx264", 20, "slow", "192k"),
            _ => ("libx264", 22, "slow", "160k")
        };
    }
}
