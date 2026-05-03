namespace VhsMp4Optimizer.Core.Models;

public sealed class QueueItemSummary
{
    public const string PrimaryRowBackground = "#FBFCFE";
    public const string AlternateRowBackground = "#F3F7FD";

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
    public string? ReportPath { get; init; }
    public TimelineProject? TimelineProject { get; init; }
    public ItemTransformSettings? TransformSettings { get; init; }
    public bool IsAlternate { get; set; }
    public string RowBackground => IsAlternate ? AlternateRowBackground : PrimaryRowBackground;
}
