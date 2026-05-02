using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Core.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class TimelineStripServiceTests
{
    [Fact]
    public void BuildBlocks_should_preserve_segment_order_and_kind_labels()
    {
        var project = new TimelineProject
        {
            SourcePath = @"F:\test.avi",
            SourceName = "test.avi",
            SourceDurationSeconds = 100,
            Segments =
            [
                new TimelineSegment
                {
                    Id = Guid.NewGuid(),
                    Kind = TimelineSegmentKind.Keep,
                    TimelineStartSeconds = 0,
                    SourceStartSeconds = 0,
                    SourceEndSeconds = 10
                },
                new TimelineSegment
                {
                    Id = Guid.NewGuid(),
                    Kind = TimelineSegmentKind.Cut,
                    TimelineStartSeconds = 10,
                    SourceStartSeconds = 10,
                    SourceEndSeconds = 20
                },
                new TimelineSegment
                {
                    Id = Guid.NewGuid(),
                    Kind = TimelineSegmentKind.Gap,
                    TimelineStartSeconds = 20,
                    SourceStartSeconds = 20,
                    SourceEndSeconds = 35
                }
            ]
        };

        var blocks = TimelineStripService.BuildBlocks(project, preferredWidth: 900, minimumWidth: 0);

        Assert.Collection(
            blocks,
            first =>
            {
                Assert.Equal(TimelineSegmentKind.Keep, first.Kind);
                Assert.Equal("KEEP", first.Label);
                Assert.Equal(0, first.TimelineStartSeconds);
            },
            second =>
            {
                Assert.Equal(TimelineSegmentKind.Cut, second.Kind);
                Assert.Equal("CUT", second.Label);
                Assert.Equal(10, second.TimelineStartSeconds);
            },
            third =>
            {
                Assert.Equal(TimelineSegmentKind.Gap, third.Kind);
                Assert.Equal("GAP", third.Label);
                Assert.Equal(20, third.TimelineStartSeconds);
            });
    }

    [Fact]
    public void BuildBlocks_should_scale_widths_proportionally_when_minimum_is_zero()
    {
        var project = new TimelineProject
        {
            SourcePath = @"F:\test.avi",
            SourceName = "test.avi",
            SourceDurationSeconds = 100,
            Segments =
            [
                new TimelineSegment
                {
                    Id = Guid.NewGuid(),
                    Kind = TimelineSegmentKind.Keep,
                    TimelineStartSeconds = 0,
                    SourceStartSeconds = 0,
                    SourceEndSeconds = 25
                },
                new TimelineSegment
                {
                    Id = Guid.NewGuid(),
                    Kind = TimelineSegmentKind.Keep,
                    TimelineStartSeconds = 25,
                    SourceStartSeconds = 25,
                    SourceEndSeconds = 100
                }
            ]
        };

        var blocks = TimelineStripService.BuildBlocks(project, preferredWidth: 1000, minimumWidth: 0);

        Assert.Equal(250, blocks[0].WidthPixels, 4);
        Assert.Equal(750, blocks[1].WidthPixels, 4);
    }

    [Fact]
    public void BuildBlocks_should_enforce_minimum_width_for_tiny_segments()
    {
        var project = new TimelineProject
        {
            SourcePath = @"F:\test.avi",
            SourceName = "test.avi",
            SourceDurationSeconds = 100,
            Segments =
            [
                new TimelineSegment
                {
                    Id = Guid.NewGuid(),
                    Kind = TimelineSegmentKind.Cut,
                    TimelineStartSeconds = 0,
                    SourceStartSeconds = 0,
                    SourceEndSeconds = 1
                },
                new TimelineSegment
                {
                    Id = Guid.NewGuid(),
                    Kind = TimelineSegmentKind.Keep,
                    TimelineStartSeconds = 1,
                    SourceStartSeconds = 1,
                    SourceEndSeconds = 100
                }
            ]
        };

        var blocks = TimelineStripService.BuildBlocks(project, preferredWidth: 300, minimumWidth: 80);

        Assert.True(blocks[0].WidthPixels >= 80);
        Assert.True(blocks[1].WidthPixels > blocks[0].WidthPixels);
    }
}
