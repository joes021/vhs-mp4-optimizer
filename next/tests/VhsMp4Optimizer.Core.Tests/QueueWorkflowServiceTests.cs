using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Core.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class QueueWorkflowServiceTests
{
    [Fact]
    public void Should_only_convert_queue_ready_items()
    {
        Assert.True(QueueWorkflowService.ShouldConvert(CreateItem("queued")));
        Assert.True(QueueWorkflowService.ShouldConvert(CreateItem("timeline edited")));
        Assert.False(QueueWorkflowService.ShouldConvert(CreateItem("done")));
        Assert.False(QueueWorkflowService.ShouldConvert(CreateItem("failed")));
        Assert.False(QueueWorkflowService.ShouldConvert(CreateItem("skipped")));
    }

    [Fact]
    public void RetryFailed_should_return_failed_item_to_queue()
    {
        var retried = QueueWorkflowService.RetryFailed(CreateItem("failed"));

        Assert.Equal("queued", retried.Status);
    }

    [Fact]
    public void BuildSummary_should_include_main_status_counts()
    {
        var summary = QueueWorkflowService.BuildSummary(
        [
            CreateItem("queued"),
            CreateItem("timeline edited"),
            CreateItem("done"),
            CreateItem("failed"),
            CreateItem("skipped")
        ]);

        Assert.Contains("queued: 2", summary);
        Assert.Contains("done: 1", summary);
        Assert.Contains("failed: 1", summary);
        Assert.Contains("skipped: 1", summary);
    }

    private static QueueItemSummary CreateItem(string status)
    {
        return new QueueItemSummary
        {
            SourceFile = "source.avi",
            SourcePath = @"F:\source.avi",
            OutputFile = "source.mp4",
            OutputPath = @"F:\out\source.mp4",
            OutputPattern = @"F:\out\source.mp4",
            Container = "avi",
            Resolution = "720x576",
            Duration = "00:43:22",
            Video = "DV / 4:3 / 25 fps",
            Audio = "pcm / stereo",
            Status = status,
            MediaInfo = new MediaInfo
            {
                SourceName = "source.avi",
                SourcePath = @"F:\source.avi",
                Container = "avi",
                DurationSeconds = 2602,
                DurationText = "00:43:22",
                SizeBytes = 1000,
                SizeText = "1000 B",
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
                FrameCount = 65055,
                VideoBitrateKbps = 8864,
                VideoBitrateText = "8864 kbps",
                AudioCodec = "pcm_s16le",
                AudioChannels = 2,
                AudioSampleRateHz = 48000,
                AudioBitrateKbps = 1536,
                AudioBitrateText = "1536 kbps",
                VideoSummary = "dvvideo | 720x576 | 4:3 | 25 fps",
                AudioSummary = "pcm_s16le | 2 ch | 48000 Hz | 1536 kbps"
            },
            PlannedOutput = null,
            TransformSettings = null
        };
    }
}
