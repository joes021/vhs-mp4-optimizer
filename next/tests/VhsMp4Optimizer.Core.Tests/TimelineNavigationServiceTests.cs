using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Core.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class TimelineNavigationServiceTests
{
    [Fact]
    public void Should_sum_only_keep_segments_for_virtual_duration()
    {
        var project = BuildProject();

        var duration = TimelineNavigationService.GetVirtualDuration(project, 100);

        Assert.Equal(90, duration);
    }

    [Theory]
    [InlineData(0, 0)]
    [InlineData(5, 5)]
    [InlineData(10, 20)]
    [InlineData(20, 30)]
    [InlineData(89.5, 99.5)]
    public void Should_map_virtual_preview_time_back_to_source_time(double virtualSeconds, double expectedSourceSeconds)
    {
        var project = BuildProject();

        var mapped = TimelineNavigationService.MapVirtualToSource(project, virtualSeconds, 100);

        Assert.Equal(expectedSourceSeconds, mapped, 3);
    }

    private static TimelineProject BuildProject()
    {
        return new TimelineProject
        {
            SourcePath = @"F:\test.avi",
            SourceName = "test.avi",
            SourceDurationSeconds = 100,
            Segments = new[]
            {
                new TimelineSegment { Id = Guid.NewGuid(), Kind = TimelineSegmentKind.Keep, TimelineStartSeconds = 0, SourceStartSeconds = 0, SourceEndSeconds = 10 },
                new TimelineSegment { Id = Guid.NewGuid(), Kind = TimelineSegmentKind.Cut, TimelineStartSeconds = 10, SourceStartSeconds = 10, SourceEndSeconds = 20 },
                new TimelineSegment { Id = Guid.NewGuid(), Kind = TimelineSegmentKind.Keep, TimelineStartSeconds = 20, SourceStartSeconds = 20, SourceEndSeconds = 100 }
            }
        };
    }
}
