namespace VhsMp4Optimizer.Core.Tests;

public sealed class PlayerTrimWindowMarkupTests
{
    [Fact]
    public void PlayerTrimWindow_should_keep_embedded_videoview_realized()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("<controls:EmbeddedVideoView", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"PlaybackVideoView\"", markup, StringComparison.Ordinal);
        Assert.Contains("IsVisible=\"{Binding IsVideoPlaybackVisible}\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("<vlc:VideoView", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_follow_mockup_based_primary_layout()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Text=\"FILE MENU\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"MEDIA FILES\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"VIDEO\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"TOOLS ZA POJEDINACNE VIDEO KLIPOVE\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"TOOLS ZA VIDEO TRACKS\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"VIDEO &amp; AUDIO TRACKS\"", markup, StringComparison.Ordinal);
        Assert.Contains("ColumnDefinitions=\"250,*,320\"", markup, StringComparison.Ordinal);
        Assert.Contains("RowDefinitions=\"Auto,Auto,*\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_keep_large_central_preview_without_overlay_hud()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("x:Name=\"PrimaryProgramMonitor\"", markup, StringComparison.Ordinal);
        Assert.Contains("Height=\"360\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"ProgramMonitorViewport\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Text=\"Monitor HUD\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Text=\"Program Monitor\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Text=\"Workspace chrome / dock status\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_place_compact_preview_scrub_and_transport_bands_below_video()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("x:Name=\"PreviewScrubBar\"", markup, StringComparison.Ordinal);
        Assert.Contains("PointerPressed=\"PreviewSliderPointerPressed\"", markup, StringComparison.Ordinal);
        Assert.Contains("PointerReleased=\"PreviewSliderPointerReleased\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"MonitorTransportBand\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Play\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Pause\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"START\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"END\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Mark In\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Mark Out\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Text=\"PLAYBACK KONTROLE\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Text=\"Navigate\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Text=\"Playback\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Text=\"Marks\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Text=\"IN Point\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Text=\"OUT Point\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Text=\"{Binding InPointText}\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Text=\"{Binding OutPointText}\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Content=\"Shuttle -\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Content=\"Shuttle +\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_horizontal_track_tools_with_working_core_actions()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("x:Name=\"TrackToolsBar\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Select\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Razor\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Slip\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Roll\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Move &lt;\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Move &gt;\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Razor at Playhead\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding SelectToolCommand}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding SplitAtPlayheadCommand}\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_v1_and_a1_tracks_without_secondary_chrome_noise()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("x:Name=\"V1LaneRow\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"V1\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Video Lane\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"A1LaneRow\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"A1\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Audio Lane\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"TimelinePlayheadIndicator\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Text=\"V2\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Text=\"A2\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Timeline Mini Toolbar", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Patch Panel", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Page Switcher", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_allow_direct_v1_pointer_interaction_for_scrub_and_razor()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("PointerPressed=\"TimelineBlockPointerPressed\"", markup, StringComparison.Ordinal);
        Assert.Contains("PointerReleased=\"TimelineBlockPointerReleased\"", markup, StringComparison.Ordinal);
        Assert.Contains("ToolTip.Tip=\"Select: klik za preview. Razor: klik za rez na V1.\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_define_contrasting_transport_states()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Selector=\"Button.transport:pointerover\"", markup, StringComparison.Ordinal);
        Assert.Contains("Value=\"#25543A\"", markup, StringComparison.Ordinal);
        Assert.Contains("Selector=\"Button.transport:pressed\"", markup, StringComparison.Ordinal);
        Assert.Contains("Value=\"#1A412C\"", markup, StringComparison.Ordinal);
        Assert.Contains("Selector=\"Button.transport.functional:disabled /template/ ContentPresenter\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Opacity\" Value=\"0.4", markup, StringComparison.Ordinal);
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
        Assert.Contains("TimelineBlockPointerReleased", source, StringComparison.Ordinal);
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

    private static string ReadPlayerTrimMarkup()
    {
        var projectRoot = FindProjectRoot();
        var markupPath = Path.Combine(
            projectRoot,
            "next",
            "src",
            "VhsMp4Optimizer.App",
            "Views",
            "PlayerTrimWindow.axaml");

        return File.ReadAllText(markupPath);
    }
}
