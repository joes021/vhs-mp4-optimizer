namespace VhsMp4Optimizer.App.Models;

public sealed class AppSessionState
{
    public string InputFolder { get; set; } = string.Empty;
    public string OutputFolder { get; set; } = string.Empty;
    public string? FfmpegPath { get; set; }
}
