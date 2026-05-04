namespace VhsMp4Optimizer.Core.Models;

public sealed class ConversionRequest
{
    public required MediaInfo MediaInfo { get; init; }
    public required BatchSettings Settings { get; init; }
    public required string OutputPath { get; init; }
    public string? OutputPattern { get; init; }
    public TimelineProject? TimelineProject { get; init; }
    public ItemTransformSettings? TransformSettings { get; init; }
    public bool IsSample { get; init; }
    public double? SampleStartSeconds { get; init; }
    public double? SampleDurationSeconds { get; init; }
}
