using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Core.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class OutputPlanningTests
{
    [Fact]
    public void Should_plan_pal_16x9_to_1024x576()
    {
        var mediaInfo = new MediaInfo
        {
            SourceName = "test.avi",
            SourcePath = @"F:\test.avi",
            Container = "avi",
            DurationSeconds = 2602,
            DurationText = "00:43:22",
            SizeBytes = 2_900_000_000,
            SizeText = "2.70 GB",
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
            FrameCount = 65055,
            VideoBitrateKbps = 8864,
            VideoBitrateText = "8864 kbps",
            AudioCodec = "pcm_s16le",
            AudioChannels = 2,
            AudioSampleRateHz = 48000,
            AudioBitrateKbps = 1536,
            AudioBitrateText = "1536 kbps",
            VideoSummary = "dvvideo | 720x576 | 16:9 | 25 fps",
            AudioSummary = "pcm_s16le | 2 ch | 48000 Hz | 1536 kbps"
        };

        var settings = new BatchSettings
        {
            QualityMode = QualityModes.StandardVhs,
            ScaleMode = ScaleModes.Pal576p,
            AudioBitrate = "160k"
        };

        var plan = OutputPlanner.Build(mediaInfo, settings);

        Assert.Equal("1024x576", plan.Resolution);
        Assert.Equal("H.264", plan.VideoCodecLabel);
        Assert.Contains("FAT32", plan.UsbNoteText);
    }
}
