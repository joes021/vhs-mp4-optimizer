namespace VhsMp4Optimizer.Core.Models;

public sealed class TimeRange
{
    public required double StartSeconds { get; init; }
    public required double EndSeconds { get; init; }
    public double DurationSeconds => Math.Max(0, EndSeconds - StartSeconds);
}
