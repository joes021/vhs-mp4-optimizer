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

    [Fact]
    public void Should_include_split_summary_when_split_output_is_enabled()
    {
        var mediaInfo = new MediaInfo
        {
            SourceName = "test.avi",
            SourcePath = @"F:\test.avi",
            Container = "avi",
            DurationSeconds = 7200,
            DurationText = "02:00:00",
            SizeBytes = 5_900_000_000,
            SizeText = "5.49 GB",
            OverallBitrateKbps = 9000,
            OverallBitrateText = "9000 kbps",
            VideoCodec = "dvvideo",
            Width = 720,
            Height = 576,
            Resolution = "720x576",
            DisplayAspectRatio = "4:3",
            SampleAspectRatio = "16:15",
            FrameRate = 25,
            FrameRateText = "25 fps",
            FrameCount = 180000,
            VideoBitrateKbps = 8864,
            VideoBitrateText = "8864 kbps",
            AudioCodec = "pcm_s16le",
            AudioChannels = 2,
            AudioSampleRateHz = 48000,
            AudioBitrateKbps = 1536,
            AudioBitrateText = "1536 kbps",
            VideoSummary = "dvvideo | 720x576 | 4:3 | 25 fps",
            AudioSummary = "pcm_s16le | 2 ch | 48000 Hz | 1536 kbps"
        };

        var settings = new BatchSettings
        {
            QualityMode = QualityModes.StandardVhs,
            ScaleMode = ScaleModes.Pal576p,
            AudioBitrate = "160k",
            SplitOutput = true,
            MaxPartGb = 3.8
        };

        var plan = OutputPlanner.Build(mediaInfo, settings);

        Assert.Contains("Split ON", plan.SplitModeText);
        Assert.Contains("delova", plan.SplitModeText);
        Assert.Contains("USB note", plan.UsbNoteText);
    }

    [Fact]
    public void Should_apply_manual_crop_before_scaled_output_resolution()
    {
        var mediaInfo = new MediaInfo
        {
            SourceName = "crop-test.mp4",
            SourcePath = @"F:\crop-test.mp4",
            Container = "mov",
            DurationSeconds = 120,
            DurationText = "00:02:00",
            SizeBytes = 2_000_000_000,
            SizeText = "1.86 GB",
            OverallBitrateKbps = 9000,
            OverallBitrateText = "9000 kbps",
            VideoCodec = "h264",
            Width = 1920,
            Height = 1080,
            Resolution = "1920x1080",
            DisplayAspectRatio = "16:9",
            SampleAspectRatio = "1:1",
            FrameRate = 25,
            FrameRateText = "25 fps",
            FrameCount = 3000,
            VideoBitrateKbps = 8000,
            VideoBitrateText = "8000 kbps",
            AudioCodec = "aac",
            AudioChannels = 2,
            AudioSampleRateHz = 48000,
            AudioBitrateKbps = 160,
            AudioBitrateText = "160 kbps",
            VideoSummary = "h264 | 1920x1080 | 16:9 | 25 fps",
            AudioSummary = "aac | 2 ch | 48000 Hz | 160 kbps"
        };

        var settings = new BatchSettings
        {
            QualityMode = QualityModes.TvSmart,
            ScaleMode = ScaleModes.P720,
            AspectMode = AspectModes.Auto,
            AudioBitrate = "160k"
        };

        var transform = new ItemTransformSettings
        {
            AspectMode = AspectModes.Force4x3,
            Crop = new CropSettings { Left = 100, Right = 100, Top = 10, Bottom = 10 }
        };

        var plan = OutputPlanner.Build(mediaInfo, settings, transform);

        Assert.Equal("960x720", plan.Resolution);
        Assert.Equal("4:3", plan.AspectText);
        Assert.Contains("L100", plan.CropText);
    }
}
