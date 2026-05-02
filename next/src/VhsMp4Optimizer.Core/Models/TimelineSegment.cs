namespace VhsMp4Optimizer.Core.Models;

public sealed class TimelineSegment
{
    public required Guid Id { get; init; }
    public required TimelineSegmentKind Kind { get; init; }
    public required double TimelineStartSeconds { get; init; }
    public required double SourceStartSeconds { get; init; }
    public required double SourceEndSeconds { get; init; }
    public double DurationSeconds => Math.Max(0, SourceEndSeconds - SourceStartSeconds);
}
