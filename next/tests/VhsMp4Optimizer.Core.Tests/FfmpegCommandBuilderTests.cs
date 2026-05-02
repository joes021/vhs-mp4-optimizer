using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Core.Services;
using VhsMp4Optimizer.Infrastructure.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class FfmpegCommandBuilderTests
{
    [Fact]
    public void Should_build_filter_complex_for_multi_segment_export()
    {
        var mediaInfo = new MediaInfo
        {
            SourceName = "test.avi",
            SourcePath = @"F:\test.avi",
            Container = "avi",
            DurationSeconds = 100,
            DurationText = "00:01:40",
            SizeBytes = 1000,
            SizeText = "1000 B",
            OverallBitrateKbps = 9000,
            OverallBitrateText = "9000 kbps",
            VideoCodec = "dvvideo",
            Width = 720,
            Height = 576,
            Resolution = "720x576",
            DisplayAspectRatio = "16:9",
            SampleAspectRatio = "64:45",
            FrameRate = 25,
            FrameRateText = "25 fps",
            FrameCount = 2500,
            VideoBitrateKbps = 8000,
            VideoBitrateText = "8000 kbps",
            AudioCodec = "pcm",
            AudioChannels = 2,
            AudioSampleRateHz = 48000,
            AudioBitrateKbps = 1536,
            AudioBitrateText = "1536 kbps",
            VideoSummary = "dvvideo",
            AudioSummary = "pcm"
        };

        var project = new TimelineProject
        {
            SourcePath = mediaInfo.SourcePath,
            SourceName = mediaInfo.SourceName,
            SourceDurationSeconds = mediaInfo.DurationSeconds,
            Segments = new[]
            {
                new TimelineSegment { Id = Guid.NewGuid(), Kind = TimelineSegmentKind.Keep, TimelineStartSeconds = 0, SourceStartSeconds = 0, SourceEndSeconds = 10 },
                new TimelineSegment { Id = Guid.NewGuid(), Kind = TimelineSegmentKind.Cut, TimelineStartSeconds = 10, SourceStartSeconds = 10, SourceEndSeconds = 20 },
                new TimelineSegment { Id = Guid.NewGuid(), Kind = TimelineSegmentKind.Keep, TimelineStartSeconds = 20, SourceStartSeconds = 20, SourceEndSeconds = 100 }
            }
        };

        var settings = new BatchSettings
        {
            InputPath = mediaInfo.SourcePath,
            OutputDirectory = @"F:\out",
            QualityMode = QualityModes.StandardVhs,
            ScaleMode = ScaleModes.Pal576p,
            AspectMode = AspectModes.Auto,
            AudioBitrate = "160k"
        };

        var request = new ConversionRequest
        {
            MediaInfo = mediaInfo,
            Settings = settings,
            OutputPath = @"F:\out\test.mp4",
            TimelineProject = project
        };

        var args = FfmpegCommandBuilder.BuildArguments(request);
        var joined = string.Join(" ", args);

        Assert.Contains("filter_complex", joined);
        Assert.Contains("trim=start=0", joined);
        Assert.Contains("trim=start=20", joined);
        Assert.Contains("concat=n=2:v=1:a=1", joined);
        Assert.Contains("scale=1024:576", joined);
    }
}
