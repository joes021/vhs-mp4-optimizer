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
        Assert.Contains("Text=\"Bins\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Clips\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Master\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Timeline 01\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"25 fps\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"{Binding SnapStatusText}\"", markup, StringComparison.Ordinal);
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
        Assert.Contains("x:Name=\"PreviewScrubBar\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"{Binding PreviewVirtualTimeText}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Select\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Razor\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Slip\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Roll\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Navigate\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Playback\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Marks\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"V1\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"V2\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"A1\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"A2\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Video Lane\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Overlay Lane\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Audio Lane\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Audio Lane 2\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"TrackLaneSeparator\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Waveform\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Lock\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Mute\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Solo\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Time Ruler\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"{Binding TimelineRulerLeftLabel}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"{Binding TimelineRulerCenterLabel}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"{Binding TimelineRulerRightLabel}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"{Binding TimelineZoomSummary}\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"TimelinePlayheadIndicator\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"TimelinePlayheadBadge\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"TimelineMasterPlayheadGuide\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"SnapGuideLeft\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"SnapGuideRight\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"{Binding PreviewVirtualTimeText}\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Text=\"{Binding PreviewSourceTimeText}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"DUR\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"ClipHandleGripLeft\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"ClipHandleGripRight\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"SRC\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"{Binding SelectionBadgeText}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Selected Clip\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Marker Rail\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Mark In\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Mark Out\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Prev Cut\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Next Cut\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Transform\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Cropping\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Composite\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Retime &amp; Scaling\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Zoom X\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Position X\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Timeline Info\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Metadata\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Timeline Controls\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Magnet\"", markup, StringComparison.Ordinal);
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
        Assert.Contains("Command=\"{Binding ToggleSnapCommand}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Back to Queue\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Razor at Playhead\"", markup, StringComparison.Ordinal);
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
    public void PlayerTrimWindow_should_render_clip_thumbnail_strip_chrome()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("x:Name=\"ClipThumbnailStrip\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"THUMBNAILS\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_stronger_selected_clip_title_bar()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("x:Name=\"SelectedClipTitleBar\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"{Binding SelectedTitleText}\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_lane_targeting_chrome()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Content=\"V1 Target\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"V2 Target\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"A1 Target\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"A2 Target\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding SelectLaneTargetCommand}\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_timeline_mini_toolbar()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Text=\"Timeline Mini Toolbar\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Selection\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Linked\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding ToggleLinkedSelectionCommand}\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_bottom_left_timecode_status_cluster()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Text=\"Duration\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Lane Target\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Playhead\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"{Binding ActiveLaneTarget}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"{Binding PreviewDurationText}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"{Binding PreviewVirtualTimeText}\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_clip_filmstrip_ticks()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("x:Name=\"ClipFilmstripTicks\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"00:00\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"00:05\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"00:10\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_monitor_transport_strip()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Text=\"Monitor Transport\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Shuttle -\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Stop\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Loop\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding ToggleLoopPlaybackCommand}\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_timeline_navigator_chrome()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Text=\"Timeline Navigator\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"TimelineNavigatorThumb\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Full Timeline\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_inspector_keyframe_and_reset_chrome()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Text=\"Reset\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Keyframe\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Transform Reset\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_media_pool_toolbar_chips()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Text=\"Bins\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Sort\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"View\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Metadata\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_resolve_like_top_menu_bar()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Text=\"DaVinci-like Menu\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"File\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Edit\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Trim\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Timeline\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Clip\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Mark\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"View\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Playback\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Workspace\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Help\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_stronger_media_pool_browser_chrome()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Text=\"Browser\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Clips\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Timelines\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Smart Bins\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Filter\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Scene\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Reel\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_inspector_toolbar_chrome()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Text=\"Inspector Stack\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Bypass\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Reset All\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Copy\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Paste\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_bottom_page_switcher()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Text=\"Page Switcher\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Media\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Cut\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Edit\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Color\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Content=\"Fusion\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Content=\"Fairlight\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"FooterDeliverButton\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding SaveToQueueCommand}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Click=\"ClosePlayerTrimClick\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_give_program_monitor_large_central_layout()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("RowDefinitions=\"Auto,*,360,Auto\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"EditorMainContentGrid\"", markup, StringComparison.Ordinal);
        Assert.Contains("ColumnDefinitions=\"240,*,320\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"PrimaryProgramMonitor\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"ProgramMonitorViewport\"", markup, StringComparison.Ordinal);
        Assert.Contains("Height=\"216\"", markup, StringComparison.Ordinal);
        Assert.Contains("Height=\"184\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Text=\"Monitor Timecode\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_define_subtle_transport_hover_and_pressed_states()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Selector=\"Button.transport:pointerover\"", markup, StringComparison.Ordinal);
        Assert.Contains("Value=\"#1E3326\"", markup, StringComparison.Ordinal);
        Assert.Contains("Value=\"#6CB987\"", markup, StringComparison.Ordinal);
        Assert.Contains("Selector=\"Button.transport:pressed\"", markup, StringComparison.Ordinal);
        Assert.Contains("Value=\"#16271D\"", markup, StringComparison.Ordinal);
        Assert.Contains("Value=\"#95E0AF\"", markup, StringComparison.Ordinal);
        Assert.Contains("Selector=\"Button.transport.functional\"", markup, StringComparison.Ordinal);
        Assert.Contains("Value=\"#1D6B36\"", markup, StringComparison.Ordinal);
        Assert.Contains("Value=\"#7EE49D\"", markup, StringComparison.Ordinal);
        Assert.Contains("Selector=\"Button.transport.functional:disabled\"", markup, StringComparison.Ordinal);
        Assert.Contains("Value=\"#365445\"", markup, StringComparison.Ordinal);
        Assert.Contains("Value=\"#F3FFF6\"", markup, StringComparison.Ordinal);
        Assert.Contains("Selector=\"Button.transport:disabled /template/ ContentPresenter\"", markup, StringComparison.Ordinal);
        Assert.Contains("Selector=\"Button.transport.functional:disabled /template/ ContentPresenter\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_mark_wired_buttons_with_functional_class()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Classes=\"transport functional\"", markup, StringComparison.Ordinal);
        Assert.Contains("Classes.active-chip=\"{Binding IsCutModeActive}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding PlayCommand}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding SaveToQueueCommand}\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_use_focus_timeline_layout_without_secondary_lane_overlap()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("x:Name=\"CompactTimeRuler\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"A1LaneRow\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"V2LaneRow\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"A2LaneRow\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"TimelineBottomDockRow\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"TimelineNavigatorRow\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"ClipThumbnailStrip\"", markup, StringComparison.Ordinal);
        Assert.Contains("Height=\"84\"", markup, StringComparison.Ordinal);
        Assert.Contains("IsVisible=\"False\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"PreviewScrubBar\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"MonitorTransportBand\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_wire_marker_in_and_out_actions()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Content=\"Mark In\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding SetInPointCommand}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Mark Out\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding SetOutPointCommand}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Prev Cut\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding PreviousCutCommand}\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Next Cut\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding NextCutCommand}\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_surface_razor_action_for_v1_cutting()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Text=\"Razor\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Razor at Playhead\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"V1 Quick Edit\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Delete Clip\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Ripple\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"&lt;-\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"-&gt;\"", markup, StringComparison.Ordinal);
        Assert.Contains("Command=\"{Binding SplitAtPlayheadCommand}\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_editor_hotkey_help_strip()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Text=\"Hotkeys\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"V Select\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"B Razor\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"I Mark In\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"O Mark Out\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Ctrl+Z Undo\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Ctrl+Y Redo\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Margin=\"0,64,0,0\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_use_single_orange_playhead_accent()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("x:Name=\"TimelinePlayheadBadge\"", markup, StringComparison.Ordinal);
        Assert.Contains("Background=\"#F97316\"", markup, StringComparison.Ordinal);
        Assert.Contains("BorderBrush=\"#FDBA74\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Background=\"#22D3EE\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Background=\"#4DD0E1\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_wrap_media_pool_browser_actions_inside_panel()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("<WrapPanel", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("ItemWidth=\"60\"", markup, StringComparison.Ordinal);
        Assert.Contains("ItemWidth=\"64\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Smart Bins\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_not_duplicate_footer_playhead_readout()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Equal(4, CountOccurrences(markup, "Text=\"{Binding PreviewVirtualTimeText}\""));
    }

    [Fact]
    public void PlayerTrimWindow_should_render_compact_tool_rail_grid_with_all_primary_tools_visible()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("RowDefinitions=\"*,Auto\"", markup, StringComparison.Ordinal);
        Assert.Contains("x:Name=\"ToolRailGrid\"", markup, StringComparison.Ordinal);
        Assert.Contains("RowDefinitions=\"Auto,Auto,Auto,Auto\"", markup, StringComparison.Ordinal);
        Assert.Contains("CommandParameter=\"Select\"", markup, StringComparison.Ordinal);
        Assert.Contains("CommandParameter=\"Blade\"", markup, StringComparison.Ordinal);
        Assert.Contains("CommandParameter=\"Slip\"", markup, StringComparison.Ordinal);
        Assert.Contains("CommandParameter=\"Roll\"", markup, StringComparison.Ordinal);
        Assert.Contains("MinHeight=\"56\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_allow_direct_v1_pointer_interaction_for_scrub_and_razor()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("PointerPressed=\"TimelineBlockPointerPressed\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_timeline_options_bar()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Text=\"Timeline Options\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Track Height\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Clip Color\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Retime\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Selection Follows Playhead\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_editor_title_status_strip()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Text=\"Session Status\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Edited\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Auto Save\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Timeline 01\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Record Monitor\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_top_timeline_view_toolbar()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Text=\"Timeline View\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Single Viewer\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Dual Viewer\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Inspector Right\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Mixer Right\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_monitor_status_chrome_without_embedded_overlay()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.DoesNotContain("Text=\"Monitor Timecode\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Program Monitor\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Playback i precizan trim kadar\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Monitor HUD\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Proxy Off\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_media_pool_clip_info_footer()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Text=\"Clip Info\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Date Shot\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Reel Name\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Camera\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_inspector_section_status_chrome()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Text=\"Section Status\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Open\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Keyframed\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Bypassed\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_bottom_utility_status_bar()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Text=\"Utility Status\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Render Cache\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Proxy\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Snapping\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Linked Select\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void PlayerTrimWindow_should_render_timeline_patch_panel()
    {
        var markup = ReadPlayerTrimMarkup();

        Assert.Contains("Text=\"Patch Panel\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Src V1\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Src A1\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Dst V1\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Dst A1\"", markup, StringComparison.Ordinal);
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
