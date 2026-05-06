namespace VhsMp4Optimizer.Core.Models;

public sealed class TimelineVisualBlock
{
    public required Guid SegmentId { get; init; }
    public required TimelineSegmentKind Kind { get; init; }
    public required double TimelineStartSeconds { get; init; }
    public required double SourceStartSeconds { get; init; }
    public required double SourceEndSeconds { get; init; }
    public required double DurationSeconds { get; init; }
    public required double LeftPixels { get; init; }
    public required double WidthPixels { get; init; }
    public required string Label { get; init; }
    public required string Summary { get; init; }
}
