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

        var timelineDuration = project.Segments
            .Where(segment => segment.Kind != TimelineSegmentKind.Gap)
            .Select(segment => segment.TimelineStartSeconds + segment.DurationSeconds)
            .DefaultIfEmpty(0d)
            .Max();

        return Math.Max(0, timelineDuration);
    }

    public static double MapVirtualToSource(TimelineProject? project, double virtualSeconds, double sourceDurationSeconds)
    {
        if (project is null)
        {
            return Clamp(virtualSeconds, 0, sourceDurationSeconds);
        }

        var timelineSegments = project.Segments
            .Where(segment => segment.Kind != TimelineSegmentKind.Gap)
            .OrderBy(segment => segment.TimelineStartSeconds)
            .ToList();

        if (timelineSegments.Count == 0)
        {
            return 0;
        }

        var clampedVirtual = Clamp(virtualSeconds, 0, GetVirtualDuration(project, sourceDurationSeconds));
        for (var index = 0; index < timelineSegments.Count; index++)
        {
            var segment = timelineSegments[index];
            var segmentStart = segment.TimelineStartSeconds;
            var segmentEnd = segment.TimelineStartSeconds + segment.DurationSeconds;
            if (clampedVirtual < segmentStart)
            {
                return Clamp(segment.SourceStartSeconds, 0, sourceDurationSeconds);
            }

            var isLast = index == timelineSegments.Count - 1;
            if (clampedVirtual <= segmentEnd || isLast)
            {
                var offset = Math.Min(segment.DurationSeconds, Math.Max(0, clampedVirtual - segmentStart));
                return Clamp(segment.SourceStartSeconds + offset, 0, sourceDurationSeconds);
            }
        }

        return Clamp(timelineSegments[^1].SourceEndSeconds, 0, sourceDurationSeconds);
    }

    public static bool TryMapSourceToVirtual(TimelineProject? project, double sourceSeconds, double sourceDurationSeconds, out double virtualSeconds)
    {
        if (project is null)
        {
            virtualSeconds = Clamp(sourceSeconds, 0, sourceDurationSeconds);
            return true;
        }

        var timelineSegments = project.Segments
            .Where(segment => segment.Kind != TimelineSegmentKind.Gap)
            .OrderBy(segment => segment.TimelineStartSeconds)
            .ToList();

        var clampedSource = Clamp(sourceSeconds, 0, sourceDurationSeconds);
        foreach (var segment in timelineSegments)
        {
            if (clampedSource >= segment.SourceStartSeconds && clampedSource <= segment.SourceEndSeconds)
            {
                virtualSeconds = segment.TimelineStartSeconds + Math.Max(0, clampedSource - segment.SourceStartSeconds);
                return true;
            }
        }

        virtualSeconds = 0;
        return false;
    }

    public static double? GetNextKeepSourceStart(TimelineProject? project, double sourceSeconds, double sourceDurationSeconds)
    {
        if (project is null)
        {
            return Clamp(sourceSeconds, 0, sourceDurationSeconds);
        }

        var clampedSource = Clamp(sourceSeconds, 0, sourceDurationSeconds);
        var keepSegments = project.Segments
            .Where(segment => segment.Kind != TimelineSegmentKind.Gap)
            .OrderBy(segment => segment.TimelineStartSeconds)
            .ToList();

        foreach (var segment in keepSegments)
        {
            if (clampedSource <= segment.SourceEndSeconds)
            {
                return Math.Max(segment.SourceStartSeconds, clampedSource);
            }
        }

        return keepSegments.Count > 0 ? keepSegments[^1].SourceEndSeconds : null;
    }

    private static double Clamp(double value, double min, double max)
        => Math.Min(max, Math.Max(min, value));
}
