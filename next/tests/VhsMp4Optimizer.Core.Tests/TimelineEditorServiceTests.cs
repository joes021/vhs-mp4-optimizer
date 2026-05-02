using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Core.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class TimelineEditorServiceTests
{
    [Fact]
    public void Cut_should_split_initial_segment_into_keep_cut_keep()
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
            DisplayAspectRatio = "4:3",
            SampleAspectRatio = "16:15",
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

        var timeline = TimelineEditorService.CreateInitial(mediaInfo);
        var cut = TimelineEditorService.CutSegment(timeline, 10, 20);

        Assert.Equal(3, cut.Segments.Count);
        Assert.Equal(TimelineSegmentKind.Keep, cut.Segments[0].Kind);
        Assert.Equal(TimelineSegmentKind.Cut, cut.Segments[1].Kind);
        Assert.Equal(TimelineSegmentKind.Keep, cut.Segments[2].Kind);
        Assert.Equal(90, TimelineEditorService.GetKeptDurationSeconds(cut));
    }

    [Fact]
    public void Ripple_delete_should_close_gap()
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
            DisplayAspectRatio = "4:3",
            SampleAspectRatio = "16:15",
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

        var timeline = TimelineEditorService.CreateInitial(mediaInfo);
        var cut = TimelineEditorService.CutSegment(timeline, 10, 20);
        var rippled = TimelineEditorService.RippleDeleteSegment(cut, cut.Segments[1].Id);

        Assert.Equal(2, rippled.Segments.Count);
        Assert.Equal(0, rippled.Segments[0].TimelineStartSeconds);
        Assert.Equal(10, rippled.Segments[1].TimelineStartSeconds);
        Assert.Equal(90, TimelineEditorService.GetKeptDurationSeconds(rippled));
    }
}
