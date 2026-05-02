using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Core.Services;

public static class TimelineNavigationService
{
    public static double GetVirtualDuration(TimelineProject? project, double sourceDurationSeconds)
    {
        if (project is null)
        {
            return Math.Max(0, sourceDurationSeconds);
        }

        var keepDuration = project.Segments
            .Where(segment => segment.Kind == TimelineSegmentKind.Keep)
            .Sum(segment => segment.DurationSeconds);

        return Math.Max(0, keepDuration);
    }

    public static double MapVirtualToSource(TimelineProject? project, double virtualSeconds, double sourceDurationSeconds)
    {
        if (project is null)
        {
            return Clamp(virtualSeconds, 0, sourceDurationSeconds);
        }

        var keepSegments = project.Segments
            .Where(segment => segment.Kind == TimelineSegmentKind.Keep)
            .OrderBy(segment => segment.TimelineStartSeconds)
            .ToList();

        if (keepSegments.Count == 0)
        {
            return 0;
        }

        var clampedVirtual = Clamp(virtualSeconds, 0, GetVirtualDuration(project, sourceDurationSeconds));
        double cursor = 0;

        foreach (var segment in keepSegments)
        {
            var duration = segment.DurationSeconds;
            if (clampedVirtual <= cursor + duration)
            {
                return Clamp(segment.SourceStartSeconds + (clampedVirtual - cursor), 0, sourceDurationSeconds);
            }

            cursor += duration;
        }

        return Clamp(keepSegments[^1].SourceEndSeconds, 0, sourceDurationSeconds);
    }

    private static double Clamp(double value, double min, double max)
        => Math.Min(max, Math.Max(min, value));
}
