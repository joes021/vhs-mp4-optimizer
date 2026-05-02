namespace VhsMp4Optimizer.Core.Models;

public sealed record BatchSettings
{
    public string InputPath { get; init; } = string.Empty;
    public string OutputDirectory { get; init; } = string.Empty;
    public string QualityMode { get; init; } = Services.QualityModes.StandardVhs;
    public string ScaleMode { get; init; } = Services.ScaleModes.Original;
    public string AspectMode { get; init; } = Services.AspectModes.Auto;
    public string VideoBitrate { get; init; } = string.Empty;
    public string AudioBitrate { get; init; } = "160k";
    public bool SplitOutput { get; init; }
    public double MaxPartGb { get; init; } = 3.8;
}
