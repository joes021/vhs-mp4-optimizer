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
        Assert.Contains("IsVisible=\"{Binding IsVideoPlaybackVisible}\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("<vlc:VideoView", markup, StringComparison.Ordinal);
        Assert.Contains("Background=\"#14181F\"", markup, StringComparison.Ordinal);
        Assert.Contains("Selector=\"Button.transport:pressed\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Inspector\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Video\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Audio\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Effects\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Timeline\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Tool Rail\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Project\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Sequence 01\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Media Pool\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Effects Library\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Edit Index\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Mixer\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"25 fps\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Snap On\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Linked Selection\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Cut\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Edit\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Color\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Deliver\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Source\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Program\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Fit\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"100%\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Safe\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Proxy Off\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Monitor HUD\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"TC\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"SRC IN\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"SRC OUT\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Select\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Blade\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Slip\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Roll\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Navigate\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Playback\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Marks\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"V1\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"A1\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Waveform\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Lock\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Mute\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Solo\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Time Ruler\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"00:00\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"00:30\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"01:00\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"TimelinePlayheadIndicator\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"TimelinePlayheadBadge\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"{Binding PreviewVirtualTimeText}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"DUR\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"{Binding SelectionBadgeText}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Selected Clip\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Marker Rail\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Mark In\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Mark Out\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Prev Cut\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Next Cut\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Transform\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Timeline Info\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Metadata\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Timeline Controls\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Magnet\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Link\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Zoom -\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Zoom +\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"1s\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"5s\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"10s\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Full\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding SelectZoomPresetCommand}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Selection\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Playhead\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Mode\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Markers\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Scopes\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding SelectBottomDockCommand}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Edit Tools\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding SelectModeCommand}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding SelectWorkspaceDockCommand}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding SelectToolCommand}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding SelectMonitorTabCommand}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding SelectInspectorTabCommand}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding ToggleTrackLockCommand}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding ToggleTrackMuteCommand}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding ToggleTrackSoloCommand}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Back to Queue\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Split at Playhead\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Toggle Keep/Cut\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Trim Selected\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Duplicate Selected\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Close All Gaps\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Merge With Next\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Roll &lt;\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Roll &gt;\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Insert 1s Gap\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Undo\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Redo\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Slip &lt;\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Slip &gt;\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Extract Selected\"", markup, StringComparison.Ordinal);
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
        Assert.DoesNotContain("Ucitavam preview", markup, StringComparison.Ordinal);
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
        Assert.True(source.IndexOf("await editorViewModel.PrepareForDisplayAsync();", StringComparison.Ordinal) <
                    source.LastIndexOf("_playerTrimWindow.Show(this);", StringComparison.Ordinal));
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

    [Fact]
    public void PlayerTrimWindowViewModel_should_open_vlc_media_from_source_path()
    {
        var projectRoot = FindProjectRoot();
        var sourcePath = Path.Combine(
            projectRoot,
            "next",
            "src",
            "VhsMp4Optimizer.App",
            "ViewModels",
            "PlayerTrimWindowViewModel.cs");

        var source = File.ReadAllText(sourcePath);

        Assert.Contains("new Media(_libVlc, Item.MediaInfo.SourcePath, FromType.FromPath)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("new Media(_libVlc, new Uri(Item.MediaInfo.SourcePath))", source, StringComparison.Ordinal);
        Assert.Contains("media.AddOption(\":demux=avformat\")", source, StringComparison.Ordinal);
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
