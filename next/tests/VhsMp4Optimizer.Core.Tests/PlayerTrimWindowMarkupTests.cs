namespace VhsMp4Optimizer.Core.Tests;

public sealed class PlayerTrimWindowMarkupTests
{
    [Fact]
    public void PlayerTrimWindow_should_keep_embedded_videoview_realized()
    {
        var projectRoot = FindProjectRoot();
        var markupPath = Path.Combine(
            projectRoot,
            "next",
            "src",
            "VhsMp4Optimizer.App",
            "Views",
            "PlayerTrimWindow.axaml");

        var markup = File.ReadAllText(markupPath);

        Assert.Contains("<vlc:VideoView", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("IsVisible=\"{Binding IsVideoPlaybackVisible}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Back to Queue\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void MainWindow_should_reset_trim_window_reference_when_editor_closes()
    {
        var projectRoot = FindProjectRoot();
        var sourcePath = Path.Combine(
            projectRoot,
            "next",
            "src",
            "VhsMp4Optimizer.App",
            "Views",
            "MainWindow.axaml.cs");

        var source = File.ReadAllText(sourcePath);

        Assert.Contains("_playerTrimWindow.Closed +=", source, StringComparison.Ordinal);
        Assert.Contains("_playerTrimWindow = null;", source, StringComparison.Ordinal);
    }

    private static string FindProjectRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);
        while (current is not null)
        {
            if (Directory.Exists(Path.Combine(current.FullName, "next", "src", "VhsMp4Optimizer.App")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new DirectoryNotFoundException("Project root for Avalonia app nije pronadjen.");
    }
}
