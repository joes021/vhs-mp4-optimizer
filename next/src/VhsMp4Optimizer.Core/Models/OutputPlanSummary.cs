namespace VhsMp4Optimizer.Core.Models;

public sealed class OutputPlanSummary
{
    public required string DisplayOutputName { get; init; }
    public required string Container { get; init; }
    public required string Resolution { get; init; }
    public required string DurationText { get; init; }
    public required string VideoCodecLabel { get; init; }
    public required string VideoBitrateComparisonText { get; init; }
    public required string AudioCodecText { get; init; }
    public required string AudioBitrateText { get; init; }
    public required string BitrateText { get; init; }
    public required string EncodeEngineText { get; init; }
    public required string EstimatedSizeText { get; init; }
    public required string UsbNoteText { get; init; }
    public required string SplitModeText { get; init; }
    public required string AspectText { get; init; }
    public required int OutputWidth { get; init; }
    public required int OutputHeight { get; init; }
}
