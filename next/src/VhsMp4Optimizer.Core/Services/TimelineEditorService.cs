using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Core.Services;

public static class TimelineEditorService
{
    public static TimelineProject CreateInitial(MediaInfo mediaInfo)
    {
        return new TimelineProject
        {
            SourcePath = mediaInfo.SourcePath,
            SourceName = mediaInfo.SourceName,
            SourceDurationSeconds = mediaInfo.DurationSeconds,
            Segments = new[]
            {
                new TimelineSegment
                {
                    Id = Guid.NewGuid(),
                    Kind = TimelineSegmentKind.Keep,
                    TimelineStartSeconds = 0,
                    SourceStartSeconds = 0,
                    SourceEndSeconds = mediaInfo.DurationSeconds
                }
            }
        };
    }

    public static TimelineProject CutSegment(TimelineProject project, double inPointSeconds, double outPointSeconds)
    {
        var start = Math.Max(0, Math.Min(inPointSeconds, outPointSeconds));
        var end = Math.Min(project.SourceDurationSeconds, Math.Max(inPointSeconds, outPointSeconds));
        if (end <= start)
        {
            return project;
        }

        var rebuilt = new List<TimelineSegment>();
        foreach (var segment in project.Segments.OrderBy(s => s.TimelineStartSeconds))
        {
            var segmentStart = segment.TimelineStartSeconds;
            var segmentEnd = segment.TimelineStartSeconds + segment.DurationSeconds;

            if (segmentEnd <= start || segmentStart >= end)
            {
                rebuilt.Add(segment);
                continue;
            }

            var overlapStart = Math.Max(segmentStart, start);
            var overlapEnd = Math.Min(segmentEnd, end);

            if (overlapStart > segmentStart)
            {
                rebuilt.Add(CloneSegment(segment, segmentStart, segment.SourceStartSeconds, segment.SourceStartSeconds + (overlapStart - segmentStart), segment.Kind));
            }

            rebuilt.Add(CloneSegment(
                segment,
                overlapStart,
                segment.SourceStartSeconds + (overlapStart - segmentStart),
                segment.SourceStartSeconds + (overlapEnd - segmentStart),
                segment.Kind == TimelineSegmentKind.Keep ? TimelineSegmentKind.Cut : segment.Kind));

            if (overlapEnd < segmentEnd)
            {
                rebuilt.Add(CloneSegment(
                    segment,
                    overlapEnd,
                    segment.SourceStartSeconds + (overlapEnd - segmentStart),
                    segment.SourceEndSeconds,
                    segment.Kind));
            }
        }

        return Normalize(project, rebuilt);
    }

    public static TimelineProject DeleteSegment(TimelineProject project, Guid segmentId)
    {
        var rebuilt = new List<TimelineSegment>();
        foreach (var segment in project.Segments.OrderBy(s => s.TimelineStartSeconds))
        {
            if (segment.Id == segmentId)
            {
                rebuilt.Add(new TimelineSegment
                {
                    Id = Guid.NewGuid(),
                    Kind = TimelineSegmentKind.Gap,
                    TimelineStartSeconds = segment.TimelineStartSeconds,
                    SourceStartSeconds = segment.SourceStartSeconds,
                    SourceEndSeconds = segment.SourceEndSeconds
                });
            }
            else
            {
                rebuilt.Add(segment);
            }
        }

        return Normalize(project, rebuilt, preserveGaps: true);
    }

    public static TimelineProject RippleDeleteSegment(TimelineProject project, Guid segmentId)
    {
        var rebuilt = project.Segments
            .Where(segment => segment.Id != segmentId)
            .OrderBy(segment => segment.TimelineStartSeconds)
            .ToList();

        return Normalize(project, rebuilt);
    }

    public static TimelineProject MoveSegmentLeft(TimelineProject project, Guid segmentId)
        => SwapWithNeighbor(project, segmentId, -1);

    public static TimelineProject MoveSegmentRight(TimelineProject project, Guid segmentId)
        => SwapWithNeighbor(project, segmentId, 1);

    public static TimelineProject SplitAtPlayhead(TimelineProject project, double virtualSeconds)
    {
        var targetSeconds = Math.Clamp(virtualSeconds, 0, project.SourceDurationSeconds);
        var rebuilt = new List<TimelineSegment>();
        var splitApplied = false;

        foreach (var segment in project.Segments.OrderBy(s => s.TimelineStartSeconds))
        {
            var segmentStart = segment.TimelineStartSeconds;
            var segmentEnd = segment.TimelineStartSeconds + segment.DurationSeconds;

            if (splitApplied
                || targetSeconds <= segmentStart + 0.0001d
                || targetSeconds >= segmentEnd - 0.0001d
                || segment.Kind != TimelineSegmentKind.Keep)
            {
                rebuilt.Add(segment);
                continue;
            }

            var sourceSplitPoint = segment.SourceStartSeconds + (targetSeconds - segmentStart);
            rebuilt.Add(CloneSegment(segment, segmentStart, segment.SourceStartSeconds, sourceSplitPoint, segment.Kind));
            rebuilt.Add(CloneSegment(segment, targetSeconds, sourceSplitPoint, segment.SourceEndSeconds, segment.Kind));
            splitApplied = true;
        }

        return splitApplied ? Normalize(project, rebuilt, preserveSequence: true) : project;
    }

    public static TimelineProject MoveSegmentBefore(TimelineProject project, Guid movingSegmentId, Guid targetSegmentId)
    {
        if (movingSegmentId == targetSegmentId)
        {
            return project;
        }

        var ordered = project.Segments.OrderBy(segment => segment.TimelineStartSeconds).ToList();
        var movingIndex = ordered.FindIndex(segment => segment.Id == movingSegmentId);
        var targetIndex = ordered.FindIndex(segment => segment.Id == targetSegmentId);
        if (movingIndex < 0 || targetIndex < 0)
        {
            return project;
        }

        var moving = ordered[movingIndex];
        ordered.RemoveAt(movingIndex);

        if (movingIndex < targetIndex)
        {
            targetIndex--;
        }

        ordered.Insert(targetIndex, moving);
        return Normalize(project, ordered, preserveSequence: true);
    }

    public static TimelineProject ToggleSegmentKind(TimelineProject project, Guid segmentId)
    {
        var rebuilt = project.Segments
            .Select(segment =>
            {
                if (segment.Id != segmentId)
                {
                    return segment;
                }

                var toggledKind = segment.Kind switch
                {
                    TimelineSegmentKind.Keep => TimelineSegmentKind.Cut,
                    TimelineSegmentKind.Cut => TimelineSegmentKind.Keep,
                    _ => segment.Kind
                };

                return new TimelineSegment
                {
                    Id = segment.Id,
                    Kind = toggledKind,
                    TimelineStartSeconds = segment.TimelineStartSeconds,
                    SourceStartSeconds = segment.SourceStartSeconds,
                    SourceEndSeconds = segment.SourceEndSeconds
                };
            })
            .ToList();

        return Normalize(project, rebuilt, preserveSequence: true);
    }

    public static double GetKeptDurationSeconds(TimelineProject project)
        => project.Segments.Where(segment => segment.Kind == TimelineSegmentKind.Keep).Sum(segment => segment.DurationSeconds);

    public static string FormatSeconds(double seconds)
        => TimeSpan.FromSeconds(Math.Max(0, seconds)).ToString(@"hh\:mm\:ss\.ff");

    private static TimelineProject SwapWithNeighbor(TimelineProject project, Guid segmentId, int delta)
    {
        var ordered = project.Segments.OrderBy(segment => segment.TimelineStartSeconds).ToList();
        var index = ordered.FindIndex(segment => segment.Id == segmentId);
        if (index < 0)
        {
            return project;
        }

        var target = index + delta;
        if (target < 0 || target >= ordered.Count)
        {
            return project;
        }

        (ordered[index], ordered[target]) = (ordered[target], ordered[index]);
        return Normalize(project, ordered, preserveSequence: true);
    }

    private static TimelineSegment CloneSegment(TimelineSegment source, double timelineStart, double sourceStart, double sourceEnd, TimelineSegmentKind kind)
    {
        return new TimelineSegment
        {
            Id = Guid.NewGuid(),
            Kind = kind,
            TimelineStartSeconds = timelineStart,
            SourceStartSeconds = sourceStart,
            SourceEndSeconds = sourceEnd
        };
    }

    private static TimelineProject Normalize(
        TimelineProject project,
        IEnumerable<TimelineSegment> segments,
        bool preserveGaps = false,
        bool preserveSequence = false)
    {
        var normalized = new List<TimelineSegment>();
        double cursor = 0;

        var filteredSegments = segments.Where(segment => segment.DurationSeconds > 0);
        var sequence = preserveSequence
            ? filteredSegments
            : filteredSegments.OrderBy(segment => segment.TimelineStartSeconds);

        foreach (var segment in sequence)
        {
            var timelineStart = preserveGaps ? Math.Max(cursor, segment.TimelineStartSeconds) : cursor;
            normalized.Add(new TimelineSegment
            {
                Id = segment.Id,
                Kind = segment.Kind,
                TimelineStartSeconds = timelineStart,
                SourceStartSeconds = segment.SourceStartSeconds,
                SourceEndSeconds = segment.SourceEndSeconds
            });

            cursor = timelineStart + segment.DurationSeconds;
        }

        return new TimelineProject
        {
            SourcePath = project.SourcePath,
            SourceName = project.SourceName,
            SourceDurationSeconds = project.SourceDurationSeconds,
            Segments = normalized
        };
    }
}
