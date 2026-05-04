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

    [Fact]
    public void Move_segment_before_should_reorder_segments_and_normalize_timeline_positions()
    {
        var project = new TimelineProject
        {
            SourcePath = @"F:\test.avi",
            SourceName = "test.avi",
            SourceDurationSeconds = 30,
            Segments =
            [
                new TimelineSegment
                {
                    Id = Guid.Parse("11111111-1111-1111-1111-111111111111"),
                    Kind = TimelineSegmentKind.Keep,
                    TimelineStartSeconds = 0,
                    SourceStartSeconds = 0,
                    SourceEndSeconds = 10
                },
                new TimelineSegment
                {
                    Id = Guid.Parse("22222222-2222-2222-2222-222222222222"),
                    Kind = TimelineSegmentKind.Cut,
                    TimelineStartSeconds = 10,
                    SourceStartSeconds = 10,
                    SourceEndSeconds = 20
                },
                new TimelineSegment
                {
                    Id = Guid.Parse("33333333-3333-3333-3333-333333333333"),
                    Kind = TimelineSegmentKind.Keep,
                    TimelineStartSeconds = 20,
                    SourceStartSeconds = 20,
                    SourceEndSeconds = 30
                }
            ]
        };

        var reordered = TimelineEditorService.MoveSegmentBefore(
            project,
            Guid.Parse("33333333-3333-3333-3333-333333333333"),
            Guid.Parse("22222222-2222-2222-2222-222222222222"));

        Assert.Collection(
            reordered.Segments,
            first =>
            {
                Assert.Equal(Guid.Parse("11111111-1111-1111-1111-111111111111"), first.Id);
                Assert.Equal(0, first.TimelineStartSeconds);
            },
            second =>
            {
                Assert.Equal(Guid.Parse("33333333-3333-3333-3333-333333333333"), second.Id);
                Assert.Equal(10, second.TimelineStartSeconds);
            },
            third =>
            {
                Assert.Equal(Guid.Parse("22222222-2222-2222-2222-222222222222"), third.Id);
                Assert.Equal(20, third.TimelineStartSeconds);
            });
    }

    [Fact]
    public void Split_at_playhead_should_split_keep_segment_into_two_keep_segments()
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
        var split = TimelineEditorService.SplitAtPlayhead(timeline, 40);

        Assert.Equal(2, split.Segments.Count);
        Assert.All(split.Segments, segment => Assert.Equal(TimelineSegmentKind.Keep, segment.Kind));
        Assert.Equal(0, split.Segments[0].TimelineStartSeconds);
        Assert.Equal(40, split.Segments[1].TimelineStartSeconds);
        Assert.Equal(40, split.Segments[0].SourceEndSeconds);
        Assert.Equal(40, split.Segments[1].SourceStartSeconds);
    }

    [Fact]
    public void Toggle_segment_kind_should_switch_between_keep_and_cut()
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

        var timeline = TimelineEditorService.SplitAtPlayhead(TimelineEditorService.CreateInitial(mediaInfo), 40);
        var toggledToCut = TimelineEditorService.ToggleSegmentKind(timeline, timeline.Segments[1].Id);
        var toggledBackToKeep = TimelineEditorService.ToggleSegmentKind(toggledToCut, toggledToCut.Segments[1].Id);

        Assert.Equal(TimelineSegmentKind.Cut, toggledToCut.Segments[1].Kind);
        Assert.Equal(TimelineSegmentKind.Keep, toggledBackToKeep.Segments[1].Kind);
    }

    [Fact]
    public void Trim_segment_to_range_should_shorten_selected_segment_and_close_timeline()
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

        var timeline = TimelineEditorService.SplitAtPlayhead(TimelineEditorService.CreateInitial(mediaInfo), 40);
        var trimmed = TimelineEditorService.TrimSegmentToRange(timeline, timeline.Segments[1].Id, 50, 80);

        Assert.Equal(2, trimmed.Segments.Count);
        Assert.Equal(0, trimmed.Segments[0].TimelineStartSeconds);
        Assert.Equal(40, trimmed.Segments[1].TimelineStartSeconds);
        Assert.Equal(50, trimmed.Segments[1].SourceStartSeconds);
        Assert.Equal(80, trimmed.Segments[1].SourceEndSeconds);
        Assert.Equal(70, TimelineEditorService.GetKeptDurationSeconds(trimmed));
    }
}
