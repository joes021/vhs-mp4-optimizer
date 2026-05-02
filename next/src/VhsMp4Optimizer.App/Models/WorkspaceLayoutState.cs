namespace VhsMp4Optimizer.App.Models;

public sealed class WorkspaceLayoutState
{
    public double WindowWidth { get; set; } = 1440;

    public double WindowHeight { get; set; } = 900;

    public double InputPanelHeight { get; set; } = 112;

    public double QuickSetupHeight { get; set; } = 164;

    public double AdvancedPanelHeight { get; set; } = 176;

    public double StatusPanelHeight { get; set; } = 220;

    public double QueuePaneRatio { get; set; } = 0.6;
}
