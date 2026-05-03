namespace VhsMp4Optimizer.App.ViewModels;

public sealed class AboutWindowViewModel : ViewModelBase
{
    public required string AppName { get; init; }
    public required string Version { get; init; }
    public required string ReleaseTag { get; init; }
    public required string GitRef { get; init; }
    public required string InstallPath { get; init; }
    public required string GuidePath { get; init; }
    public required string BranchHint { get; init; }
}
