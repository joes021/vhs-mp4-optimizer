namespace VhsMp4Optimizer.Core.Models;

public sealed class QueueItemSummary
{
    public required string SourceFile { get; init; }
    public required string OutputFile { get; init; }
    public required string Container { get; init; }
    public required string Resolution { get; init; }
    public required string Duration { get; init; }
    public required string Video { get; init; }
    public required string Audio { get; init; }
    public required string Status { get; init; }
}
