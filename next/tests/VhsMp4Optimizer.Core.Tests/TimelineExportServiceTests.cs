using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Core.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class TimelineExportServiceTests
{
    [Fact]
    public void Should_return_full_source_when_timeline_missing()
    {
        var ranges = TimelineExportService.GetKeepRanges(null, 42);

        Assert.Single(ranges);
        Assert.Equal(0, ranges[0].StartSeconds);
        Assert.Equal(42, ranges[0].EndSeconds);
    }

    [Fact]
    public void Should_return_only_keep_segments()
    {
        var project = new TimelineProject
        {
            SourcePath = @"F:\test.avi",
            SourceName = "test.avi",
            SourceDurationSeconds = 100,
            Segments = new[]
            {
                new TimelineSegment { Id = Guid.NewGuid(), Kind = TimelineSegmentKind.Keep, TimelineStartSeconds = 0, SourceStartSeconds = 0, SourceEndSeconds = 10 },
                new TimelineSegment { Id = Guid.NewGuid(), Kind = TimelineSegmentKind.Cut, TimelineStartSeconds = 10, SourceStartSeconds = 10, SourceEndSeconds = 20 },
                new TimelineSegment { Id = Guid.NewGuid(), Kind = TimelineSegmentKind.Keep, TimelineStartSeconds = 20, SourceStartSeconds = 20, SourceEndSeconds = 90 }
            }
        };

        var ranges = TimelineExportService.GetKeepRanges(project, 100);

        Assert.Equal(2, ranges.Count);
        Assert.Equal(0, ranges[0].StartSeconds);
        Assert.Equal(10, ranges[0].EndSeconds);
        Assert.Equal(20, ranges[1].StartSeconds);
        Assert.Equal(90, ranges[1].EndSeconds);
    }
}
