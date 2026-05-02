using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Core.Services;

public static class TimelineExportService
{
    public static IReadOnlyList<TimeRange> GetKeepRanges(TimelineProject? timelineProject, double sourceDurationSeconds)
    {
        if (timelineProject is null)
        {
            return new[]
            {
                new TimeRange
                {
                    StartSeconds = 0,
                    EndSeconds = Math.Max(0, sourceDurationSeconds)
                }
            };
        }

        return timelineProject.Segments
            .Where(segment => segment.Kind == TimelineSegmentKind.Keep && segment.DurationSeconds > 0)
            .OrderBy(segment => segment.SourceStartSeconds)
            .Select(segment => new TimeRange
            {
                StartSeconds = segment.SourceStartSeconds,
                EndSeconds = segment.SourceEndSeconds
            })
            .ToList();
    }

    public static double GetKeptDurationSeconds(TimelineProject? timelineProject, double sourceDurationSeconds)
    {
        return GetKeepRanges(timelineProject, sourceDurationSeconds).Sum(range => range.DurationSeconds);
    }
}
