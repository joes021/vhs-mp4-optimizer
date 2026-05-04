namespace VhsMp4Optimizer.Core.Models;

public sealed class OutputSettingsSnapshot
{
    public required string SelectedPreset { get; init; }
    public required string QualityMode { get; init; }
    public required string ScaleMode { get; init; }
    public required string AspectMode { get; init; }
    public required string DeinterlaceMode { get; init; }
    public required string DenoiseMode { get; init; }
    public required string EncodeEngine { get; init; }
    public required string VideoBitrate { get; init; }
    public required string AudioBitrate { get; init; }
    public required bool SplitOutput { get; init; }
    public required double MaxPartGb { get; init; }
    public required string SampleStartText { get; init; }
    public required string SampleDurationText { get; init; }
}
