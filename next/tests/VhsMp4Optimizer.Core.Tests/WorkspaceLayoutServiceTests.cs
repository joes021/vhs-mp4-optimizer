using VhsMp4Optimizer.App.Models;
using VhsMp4Optimizer.App.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class WorkspaceLayoutServiceTests : IDisposable
{
    private readonly string _rootPath;
    private readonly string _layoutPath;

    public WorkspaceLayoutServiceTests()
    {
        _rootPath = Path.Combine(Path.GetTempPath(), $"vhs-next-layout-{Guid.NewGuid():N}");
        Directory.CreateDirectory(_rootPath);
        _layoutPath = Path.Combine(_rootPath, "layout-state.json");
    }

    [Fact]
    public void LoadOrDefault_should_return_defaults_when_file_is_missing()
    {
        var service = new WorkspaceLayoutService(_layoutPath);

        var state = service.LoadOrDefault();

        Assert.Equal(1440, state.WindowWidth);
        Assert.Equal(900, state.WindowHeight);
        Assert.Equal(0.6, state.QueuePaneRatio);
    }

    [Fact]
    public void Save_and_load_should_roundtrip_layout_state()
    {
        var service = new WorkspaceLayoutService(_layoutPath);
        var expected = new WorkspaceLayoutState
        {
            WindowWidth = 1600,
            WindowHeight = 1000,
            InputPanelHeight = 140,
            QuickSetupHeight = 190,
            AdvancedPanelHeight = 210,
            StatusPanelHeight = 280,
            QueuePaneRatio = 0.67
        };

        service.Save(expected);
        var actual = service.LoadOrDefault();

        Assert.Equal(1600, actual.WindowWidth);
        Assert.Equal(1000, actual.WindowHeight);
        Assert.Equal(140, actual.InputPanelHeight);
        Assert.Equal(190, actual.QuickSetupHeight);
        Assert.Equal(210, actual.AdvancedPanelHeight);
        Assert.Equal(280, actual.StatusPanelHeight);
        Assert.Equal(0.67, actual.QueuePaneRatio, 2);
    }

    public void Dispose()
    {
        if (Directory.Exists(_rootPath))
        {
            Directory.Delete(_rootPath, true);
        }
    }
}
