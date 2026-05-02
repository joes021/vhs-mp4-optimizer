namespace VhsMp4Optimizer.Core.Models;

public sealed class QueueItemSummary
{
    public required string SourceFile { get; init; }
    public required string SourcePath { get; init; }
    public required string OutputFile { get; init; }
    public required string OutputPath { get; init; }
    public required string OutputPattern { get; init; }
    public required string Container { get; init; }
    public required string Resolution { get; init; }
    public required string Duration { get; init; }
    public required string Video { get; init; }
    public required string Audio { get; init; }
    public required string Status { get; init; }
    public required MediaInfo? MediaInfo { get; init; }
    public required OutputPlanSummary? PlannedOutput { get; init; }
    public TimelineProject? TimelineProject { get; init; }
    public ItemTransformSettings? TransformSettings { get; init; }
}
