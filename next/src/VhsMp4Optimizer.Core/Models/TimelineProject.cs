namespace VhsMp4Optimizer.Core.Models;

public sealed class TimelineProject
{
    public required string SourcePath { get; init; }
    public required string SourceName { get; init; }
    public required double SourceDurationSeconds { get; init; }
    public required IReadOnlyList<TimelineSegment> Segments { get; init; }
}
