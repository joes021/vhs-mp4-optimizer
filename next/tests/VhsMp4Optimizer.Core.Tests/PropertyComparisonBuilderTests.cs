using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Core.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class PropertyComparisonBuilderTests
{
    [Fact]
    public void Build_should_mark_rows_with_alternating_zebra_state()
    {
        var item = new QueueItemSummary
        {
            SourceFile = "clip.avi",
            SourcePath = @"F:\clip.avi",
            OutputFile = "clip.mp4",
            OutputPath = @"F:\out\clip.mp4",
            OutputPattern = @"F:\out\clip.mp4",
            Container = "avi",
            Resolution = "720x576",
            Duration = "00:10:00",
            Video = "h264 | 720x576 | 25 fps",
            Audio = "aac | 2 ch | 192k",
            Status = "queued",
            MediaInfo = new MediaInfo
            {
                SourceName = "clip.avi",
                SourcePath = @"F:\clip.avi",
                Container = "avi",
                DurationSeconds = 600,
                DurationText = "00:10:00",
                SizeBytes = 104857600,
                SizeText = "100 MB",
                OverallBitrateKbps = 5000,
                OverallBitrateText = "5000 kbps",
                VideoCodec = "h264",
                Width = 720,
                Height = 576,
                Resolution = "720x576",
                DisplayAspectRatio = "4:3",
                SampleAspectRatio = "16:15",
                FrameRate = 25,
                FrameRateText = "25 fps",
                FrameCount = 15000,
                VideoBitrateKbps = 4200,
                VideoBitrateText = "4200 kbps",
                AudioCodec = "aac",
                AudioChannels = 2,
                AudioSampleRateHz = 48000,
                AudioBitrateKbps = 192,
                AudioBitrateText = "192 kbps",
                VideoSummary = "h264 | 720x576 | 25 fps",
                AudioSummary = "aac | 2 ch | 192 kbps"
            },
            PlannedOutput = new OutputPlanSummary
            {
                DisplayOutputName = "clip.mp4",
                Container = "mp4",
                Resolution = "768x576",
                DurationText = "00:10:00",
                VideoCodecLabel = "h264",
                VideoBitrateComparisonText = "3500k",
                AudioCodecText = "aac",
                AudioBitrateText = "192k",
                BitrateText = "3692 kbps",
                EncodeEngineText = "CPU",
                EstimatedSizeText = "275 MB",
                UsbNoteText = "FAT32 OK",
                SplitModeText = "No split",
                CropText = "--",
                AspectText = "4:3",
                OutputWidth = 768,
                OutputHeight = 576
            },
            TransformSettings = null
        };

        var rows = PropertyComparisonBuilder.Build(item);

        Assert.False(rows[0].IsAlternate);
        Assert.True(rows[1].IsAlternate);
        Assert.False(rows[2].IsAlternate);
        Assert.True(rows[3].IsAlternate);
    }
}
