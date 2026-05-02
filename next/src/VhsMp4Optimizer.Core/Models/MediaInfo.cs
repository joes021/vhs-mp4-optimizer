namespace VhsMp4Optimizer.Core.Models;

public sealed class MediaInfo
{
    public required string SourceName { get; init; }
    public required string SourcePath { get; init; }
    public required string Container { get; init; }
    public required double DurationSeconds { get; init; }
    public required string DurationText { get; init; }
    public required long SizeBytes { get; init; }
    public required string SizeText { get; init; }
    public required int OverallBitrateKbps { get; init; }
    public required string OverallBitrateText { get; init; }
    public required string VideoCodec { get; init; }
    public required int Width { get; init; }
    public required int Height { get; init; }
    public required string Resolution { get; init; }
    public required string DisplayAspectRatio { get; init; }
    public required string SampleAspectRatio { get; init; }
    public required double FrameRate { get; init; }
    public required string FrameRateText { get; init; }
    public required long FrameCount { get; init; }
    public required int VideoBitrateKbps { get; init; }
    public required string VideoBitrateText { get; init; }
    public required string AudioCodec { get; init; }
    public required int AudioChannels { get; init; }
    public required int AudioSampleRateHz { get; init; }
    public required int AudioBitrateKbps { get; init; }
    public required string AudioBitrateText { get; init; }
    public required string VideoSummary { get; init; }
    public required string AudioSummary { get; init; }
}
