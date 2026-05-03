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

        Assert.Contains("<controls:EmbeddedVideoView", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("<vlc:VideoView", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Back to Queue\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Content=\"Preview Frame\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"In\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Out\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"&gt;&gt;&gt;\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"&lt;&lt;&lt;\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"&gt;&gt;\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"&lt;&lt;\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"&gt;\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"&lt;\"", markup, StringComparison.Ordinal);
        Assert.Equal(1, CountOccurrences(markup, "Text=\"{Binding EditorHint}\""));
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
        Assert.Contains("_playerTrimWindow.Show(this);", source, StringComparison.Ordinal);
        Assert.True(source.IndexOf("_playerTrimWindow.Show(this);", StringComparison.Ordinal) <
                    source.LastIndexOf("await editorViewModel.PrepareForDisplayAsync();", StringComparison.Ordinal));
    }

    [Fact]
    public void PlayerTrimWindow_codebehind_should_pause_playback_for_manual_slider_seek()
    {
        var projectRoot = FindProjectRoot();
        var sourcePath = Path.Combine(
            projectRoot,
            "next",
            "src",
            "VhsMp4Optimizer.App",
            "Views",
            "PlayerTrimWindow.axaml.cs");

        var source = File.ReadAllText(sourcePath);

        Assert.Contains("PreviewSliderPointerPressed", source, StringComparison.Ordinal);
        Assert.Contains("BeginManualPreviewNavigation", source, StringComparison.Ordinal);
    }

    private static int CountOccurrences(string text, string value)
    {
        var count = 0;
        var index = 0;
        while ((index = text.IndexOf(value, index, StringComparison.Ordinal)) >= 0)
        {
            count++;
            index += value.Length;
        }

        return count;
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
