namespace VhsMp4Optimizer.App.Models;

public sealed class AppSessionState
{
    public string InputFolder { get; set; } = @"F:\Veliki avi";
    public string OutputFolder { get; set; } = @"F:\Veliki avi\vhs-mp4-output";
    public string? FfmpegPath { get; set; }
}
