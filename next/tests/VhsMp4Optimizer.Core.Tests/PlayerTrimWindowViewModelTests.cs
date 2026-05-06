using VhsMp4Optimizer.App.ViewModels;
using Avalonia;
using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Infrastructure.Services;
using System.Diagnostics;
using System.Reflection;
using System.Threading;
using VhsMp4Optimizer.App;
using Avalonia.Input;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class PlayerTrimWindowViewModelTests : IDisposable
{
    private static int _avaloniaInitialized;
    private readonly string _rootPath;
    public PlayerTrimWindowViewModelTests()
    {
        EnsureAvaloniaInitialized();
        _rootPath = Path.Combine(Path.GetTempPath(), $"vhs-next-trim-{Guid.NewGuid():N}");
        Directory.CreateDirectory(_rootPath);
    }

    [Fact]
    public async Task RefreshPreviewCommand_should_report_that_ffmpeg_preview_is_disabled_for_display()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe",
            (_, _) => { },
            new FakePreviewFrameService((_, _, _, _, _) => throw new InvalidOperationException("preview fail")),
            autoLoadPreview: false);
        DisablePlaybackEngine(viewModel);

        await viewModel.RefreshPreviewCommand.ExecuteAsync(null);

        Assert.Contains("FFmpeg preview je ugasen", viewModel.EditorHint, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task GoToEndCommand_should_move_preview_to_virtual_end()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        await viewModel.GoToEndCommand.ExecuteAsync(null);

        Assert.Equal(viewModel.PreviewVirtualMaximum, viewModel.PreviewVirtualSeconds, 3);
        Assert.Equal("00:05:00.00", viewModel.PreviewSourceTimeText);
    }

    [Fact]
    public void Changing_preview_virtual_position_while_paused_should_not_request_ffmpeg_until_commit()
    {
        var queueItem = BuildQueueItem();
        var requestedSeconds = new List<double>();
        var previewPath = CreateTinyPng("preview.png");
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe",
            (_, _) => { },
            new FakePreviewFrameService((_, _, sourceSeconds, _, _) =>
            {
                requestedSeconds.Add(sourceSeconds);
                return previewPath;
            }),
            autoLoadPreview: false);
        DisablePlaybackEngine(viewModel);

        viewModel.PreviewVirtualSeconds = 12;

        Assert.Empty(requestedSeconds);
    }

    [Fact]
    public async Task CommitPreviewSliderAsync_should_not_request_ffmpeg_when_playback_engine_is_unavailable()
    {
        var queueItem = BuildQueueItem();
        var requestedSeconds = new List<double>();
        var previewPath = CreateTinyPng("commit-preview.png");
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe",
            (_, _) => { },
            new FakePreviewFrameService((_, _, sourceSeconds, _, _) =>
            {
                requestedSeconds.Add(sourceSeconds);
                return previewPath;
            }),
            autoLoadPreview: false);
        DisablePlaybackEngine(viewModel);

        viewModel.PreviewVirtualSeconds = 18d;
        await viewModel.CommitPreviewSliderAsync();

        Assert.Empty(requestedSeconds);
        Assert.Contains("FFmpeg preview je ugasen", viewModel.EditorHint, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task PrepareForDisplayAsync_should_not_render_ffmpeg_preview_before_window_shows()
    {
        var queueItem = BuildQueueItem();
        var previewPath = CreateTinyPng("initial-preview.png");
        var previewRequests = 0;
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe",
            (_, _) => { },
            new FakePreviewFrameService((_, _, _, _, _) =>
            {
                previewRequests++;
                return previewPath;
            }),
            autoLoadPreview: false);
        DisablePlaybackEngine(viewModel);

        await viewModel.PrepareForDisplayAsync();

        Assert.Equal(0, previewRequests);
        Assert.Contains("FFmpeg preview je ugasen", viewModel.EditorHint, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void ChromeSelectionCommands_should_update_active_editor_states_and_hint()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.SelectModeCommand.Execute("Edit");
        viewModel.SelectWorkspaceDockCommand.Execute("Mixer");
        viewModel.SelectMonitorTabCommand.Execute("Source");
        viewModel.SelectInspectorTabCommand.Execute("Audio");
        viewModel.SelectToolCommand.Execute("Blade");

        Assert.True(viewModel.IsEditModeActive);
        Assert.True(viewModel.IsMixerActive);
        Assert.True(viewModel.IsSourceMonitorActive);
        Assert.True(viewModel.IsAudioInspectorActive);
        Assert.True(viewModel.IsBladeToolActive);
        Assert.Contains("Blade", viewModel.EditorHint, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void TrackHeaderToggleCommands_should_toggle_lane_states()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.ToggleTrackLockCommand.Execute(null);
        viewModel.ToggleTrackMuteCommand.Execute(null);
        viewModel.ToggleTrackSoloCommand.Execute(null);

        Assert.True(viewModel.IsTrackLockActive);
        Assert.True(viewModel.IsTrackMuteActive);
        Assert.True(viewModel.IsTrackSoloActive);
    }

    [Fact]
    public void SelectZoomPresetCommand_should_update_active_zoom_state_and_hint()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.SelectZoomPresetCommand.Execute("10s");

        Assert.True(viewModel.IsZoom10sActive);
        Assert.False(viewModel.IsZoomFullActive);
        Assert.Contains("10s", viewModel.EditorHint, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void SelectBottomDockCommand_should_update_active_bottom_dock_state_and_hint()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.SelectBottomDockCommand.Execute("Scopes");

        Assert.True(viewModel.IsScopesBottomDockActive);
        Assert.False(viewModel.IsTimelineBottomDockActive);
        Assert.Contains("Scopes", viewModel.EditorHint, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void SelectLaneTargetCommand_should_update_active_lane_target_state_and_hint()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.SelectLaneTargetCommand.Execute("A2");

        Assert.True(viewModel.IsA2LaneTargetActive);
        Assert.False(viewModel.IsV1LaneTargetActive);
        Assert.Contains("A2", viewModel.EditorHint, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void ToggleLinkedSelectionCommand_should_update_linked_selection_state_and_hint()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.ToggleLinkedSelectionCommand.Execute(null);

        Assert.False(viewModel.IsLinkedSelectionEnabled);
        Assert.Contains("linked", viewModel.EditorHint, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void ToggleLoopPlaybackCommand_should_update_loop_playback_state_and_hint()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.ToggleLoopPlaybackCommand.Execute(null);

        Assert.True(viewModel.IsLoopPlaybackEnabled);
        Assert.Contains("loop", viewModel.EditorHint, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void SelectZoomPresetCommand_should_rebuild_timeline_block_widths()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        var initialWidth = viewModel.TimelineBlocks[0].WidthPixels;

        viewModel.SelectZoomPresetCommand.Execute("1s");
        var zoomedInWidth = viewModel.TimelineBlocks[0].WidthPixels;

        viewModel.SelectZoomPresetCommand.Execute("10s");
        var zoomedMidWidth = viewModel.TimelineBlocks[0].WidthPixels;

        Assert.True(zoomedInWidth > initialWidth);
        Assert.True(zoomedMidWidth < zoomedInWidth);
    }

    [Fact]
    public void SelectZoomPresetCommand_should_update_timeline_ruler_labels_and_zoom_summary()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.SelectZoomPresetCommand.Execute("1s");
        var zoom1Center = viewModel.TimelineRulerCenterLabel;
        var zoom1Right = viewModel.TimelineRulerRightLabel;

        viewModel.SelectZoomPresetCommand.Execute("10s");
        var zoom10Center = viewModel.TimelineRulerCenterLabel;
        var zoom10Right = viewModel.TimelineRulerRightLabel;

        viewModel.SelectZoomPresetCommand.Execute("Full");

        Assert.Equal("00:00:00.00", viewModel.TimelineRulerLeftLabel);
        Assert.NotEqual(zoom1Center, zoom10Center);
        Assert.NotEqual(zoom1Right, zoom10Right);
        Assert.Contains("View span", viewModel.TimelineZoomSummary, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("05:00", viewModel.TimelineRulerRightLabel, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void ToggleSnapCommand_should_update_snap_state_and_hint()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.ToggleSnapCommand.Execute(null);

        Assert.False(viewModel.IsSnapEnabled);
        Assert.Contains("snap", viewModel.EditorHint, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void PlayCommand_should_keep_media_instance_alive_for_real_playback()
    {
        var ffmpegPath = FfmpegLocator.Resolve();
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath))
        {
            return;
        }

        var sourcePath = CreateRealVideo("playback-source.avi", ffmpegPath);
        var queueItem = BuildQueueItem(sourcePath);
        using var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath,
            (_, _) => { },
            autoLoadPreview: false,
            enablePlaybackEngine: true);

        viewModel.PlayCommand.Execute(null);

        var playbackMediaField = typeof(PlayerTrimWindowViewModel).GetField("_playbackMedia", BindingFlags.Instance | BindingFlags.NonPublic);
        Assert.NotNull(playbackMediaField);
        Assert.NotNull(playbackMediaField!.GetValue(viewModel));
    }

    [Fact]
    public void PlayCommand_should_reuse_existing_media_for_same_source()
    {
        var ffmpegPath = FfmpegLocator.Resolve();
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath))
        {
            return;
        }

        var sourcePath = CreateRealVideo("playback-source-reuse.avi", ffmpegPath);
        var queueItem = BuildQueueItem(sourcePath);
        using var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath,
            (_, _) => { },
            autoLoadPreview: false,
            enablePlaybackEngine: true);

        viewModel.PlayCommand.Execute(null);
        viewModel.PauseCommand.Execute(null);

        var playbackMediaField = typeof(PlayerTrimWindowViewModel).GetField("_playbackMedia", BindingFlags.Instance | BindingFlags.NonPublic);
        Assert.NotNull(playbackMediaField);
        var firstMedia = playbackMediaField!.GetValue(viewModel);

        viewModel.PlayCommand.Execute(null);
        var secondMedia = playbackMediaField.GetValue(viewModel);

        Assert.Same(firstMedia, secondMedia);
    }

    [Fact]
    public void PlayCommand_should_keep_preview_image_visible_until_first_video_frame_arrives()
    {
        var ffmpegPath = FfmpegLocator.Resolve();
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath))
        {
            return;
        }

        var sourcePath = CreateRealVideo("playback-source-first-frame.avi", ffmpegPath);
        var queueItem = BuildQueueItem(sourcePath);
        using var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath,
            (_, _) => { },
            autoLoadPreview: false,
            enablePlaybackEngine: true);

        viewModel.PlayCommand.Execute(null);

        Assert.True(viewModel.IsPlaying);
        Assert.True(viewModel.IsPreviewImageVisible);
    }

    [Fact]
    public void PlaybackSurfaceBinding_should_stay_attached_while_paused_in_same_monitor()
    {
        var ffmpegPath = FfmpegLocator.Resolve();
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath))
        {
            return;
        }

        var sourcePath = CreateRealVideo("playback-surface-binding.avi", ffmpegPath);
        var queueItem = BuildQueueItem(sourcePath);
        using var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath,
            (_, _) => { },
            autoLoadPreview: false,
            enablePlaybackEngine: true);

        Assert.Null(viewModel.PlaybackMediaPlayerBinding);

        viewModel.PlayCommand.Execute(null);
        Assert.NotNull(viewModel.PlaybackMediaPlayerBinding);

        viewModel.PauseCommand.Execute(null);
        Assert.NotNull(viewModel.PlaybackMediaPlayerBinding);
    }

    [Fact]
    public void BeginManualPreviewNavigation_should_leave_playback_mode_without_forcing_new_preview()
    {
        var queueItem = BuildQueueItem();
        using var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe",
            (_, _) => { },
            autoLoadPreview: false);

        DisablePlaybackEngine(viewModel);
        viewModel.IsPlaying = true;
        viewModel.IsVideoPlaybackVisible = true;
        viewModel.BeginManualPreviewNavigation();

        Assert.False(viewModel.IsPlaying);
    }

    [Fact]
    public async Task BeginManualPreviewNavigation_should_wait_for_slider_release_before_requesting_preview()
    {
        var queueItem = BuildQueueItem();
        using var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        DisablePlaybackEngine(viewModel);
        viewModel.IsPlaying = true;
        viewModel.IsVideoPlaybackVisible = true;
        viewModel.BeginManualPreviewNavigation();
        viewModel.PreviewVirtualSeconds = 0.5d;

        await viewModel.EndManualPreviewNavigationAsync();
    }

    [Fact]
    public async Task BeginManualPreviewNavigation_should_not_request_ffmpeg_preview_after_slider_release()
    {
        var queueItem = BuildQueueItem();
        var requestedSeconds = new List<double>();
        var previewPath = CreateTinyPng("manual-navigation-preview.png");
        using var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe",
            (_, _) => { },
            new FakePreviewFrameService((_, _, sourceSeconds, _, _) =>
            {
                requestedSeconds.Add(sourceSeconds);
                return previewPath;
            }),
            autoLoadPreview: false);
        DisablePlaybackEngine(viewModel);

        viewModel.BeginManualPreviewNavigation();
        viewModel.PreviewVirtualSeconds = 36d;

        Assert.Empty(requestedSeconds);

        await viewModel.EndManualPreviewNavigationAsync();

        Assert.Empty(requestedSeconds);
    }

    [Fact]
    public void CommitPreviewSliderAsync_should_not_fallback_to_ffmpeg_when_playback_engine_is_unavailable()
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
        var methodIndex = source.IndexOf("public async Task CommitPreviewSliderAsync()", StringComparison.Ordinal);
        var playbackFirstIndex = source.IndexOf("if (TryStartPlaybackPreview(resumePlaybackAfterSeek: IsPlaying))", methodIndex, StringComparison.Ordinal);
        var ffmpegFallbackIndex = source.IndexOf("await LoadPreviewAsync();", methodIndex, StringComparison.Ordinal);

        Assert.True(methodIndex >= 0);
        Assert.True(playbackFirstIndex >= methodIndex);
        Assert.True(ffmpegFallbackIndex == -1 || ffmpegFallbackIndex < methodIndex);
    }

    [Fact]
    public void PausePlayback_should_not_request_ffmpeg_preview_immediately()
    {
        var queueItem = BuildQueueItem();
        using var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        DisablePlaybackEngine(viewModel);
        viewModel.IsPlaying = true;
        viewModel.IsVideoPlaybackVisible = true;
        viewModel.PauseCommand.Execute(null);

        Assert.False(viewModel.IsPlaying);
        Assert.True(viewModel.IsVideoPlaybackVisible);
    }

    [Fact]
    public void TimelinePlayheadMargin_should_follow_preview_virtual_position()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.SelectZoomPresetCommand.Execute("Full");
        viewModel.PreviewVirtualSeconds = 75d;

        var expectedLeft = viewModel.TimelinePreferredWidth * (75d / viewModel.PreviewVirtualMaximum);

        Assert.Equal(expectedLeft, viewModel.TimelinePlayheadMargin.Left, 3);
    }

    [Fact]
    public async Task SplitAtPlayheadCommand_should_split_current_keep_segment_at_preview_position()
    {
        var queueItem = BuildQueueItem();
        TimelineProject? savedTimeline = null;
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (timeline, _) => savedTimeline = timeline,
            autoLoadPreview: false);

        viewModel.PreviewVirtualSeconds = 120d;
        await viewModel.SplitAtPlayheadCommand.ExecuteAsync(null);
        viewModel.SaveToQueueCommand.Execute(null);

        Assert.NotNull(savedTimeline);
        Assert.Equal(2, savedTimeline!.Segments.Count);
        Assert.All(savedTimeline.Segments, segment => Assert.Equal(TimelineSegmentKind.Keep, segment.Kind));
        Assert.Equal(120d, savedTimeline.Segments[1].TimelineStartSeconds, 3);
    }

    [Fact]
    public async Task TimelineBlockActionCommand_should_split_clip_at_playhead_when_razor_tool_is_active()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        var firstBlock = viewModel.TimelineBlocks[0];
        viewModel.SelectToolCommand.Execute("Blade");
        viewModel.PreviewVirtualSeconds = 120d;

        await viewModel.TimelineBlockActionCommand.ExecuteAsync(firstBlock);

        Assert.Equal(2, viewModel.Timeline.Segments.Count);
        Assert.Equal(120d, viewModel.Timeline.Segments[1].TimelineStartSeconds, 3);
    }

    [Fact]
    public async Task HandleTimelineBlockPointerAsync_should_scrub_to_clicked_position_and_split_when_razor_is_active()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        var firstBlock = viewModel.TimelineBlocks[0];
        viewModel.SelectToolCommand.Execute("Blade");

        await viewModel.HandleTimelineBlockPointerAsync(firstBlock, 0.5d);

        Assert.Equal(2, viewModel.Timeline.Segments.Count);
        Assert.Equal(150d, viewModel.PreviewVirtualSeconds, 3);
        Assert.Equal(150d, viewModel.Timeline.Segments[1].TimelineStartSeconds, 3);
    }

    [Fact]
    public async Task HandleTimelineBlockPointerAsync_should_scrub_without_split_when_select_tool_is_active()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        var firstBlock = viewModel.TimelineBlocks[0];
        viewModel.SelectToolCommand.Execute("Select");

        await viewModel.HandleTimelineBlockPointerAsync(firstBlock, 0.5d);

        Assert.Single(viewModel.Timeline.Segments);
        Assert.Equal(150d, viewModel.PreviewVirtualSeconds, 3);
    }

    [Fact]
    public async Task HandleTimelineBlockDragAsync_should_move_selected_segment_left_when_dragging_left()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.PreviewVirtualSeconds = 150d;
        await viewModel.SplitAtPlayheadCommand.ExecuteAsync(null);
        var secondBlock = viewModel.TimelineBlocks[1];

        await viewModel.HandleTimelineBlockDragAsync(secondBlock, -60d);

        Assert.Equal(0d, viewModel.Timeline.Segments[0].TimelineStartSeconds, 3);
        Assert.Equal(150d, viewModel.Timeline.Segments[1].TimelineStartSeconds, 3);
        Assert.Equal(secondBlock.SegmentId, viewModel.Timeline.Segments[1].Id);
    }

    [Fact]
    public async Task HandleTimelineBlockDragAsync_should_move_selected_segment_later_on_timeline_when_dragging_right()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.PreviewVirtualSeconds = 150d;
        await viewModel.SplitAtPlayheadCommand.ExecuteAsync(null);
        var secondBlock = viewModel.TimelineBlocks[1];

        await viewModel.HandleTimelineBlockDragAsync(secondBlock, 160d);

        Assert.Equal(2, viewModel.Timeline.Segments.Count);
        Assert.Equal(secondBlock.SegmentId, viewModel.Timeline.Segments[1].Id);
        Assert.True(viewModel.Timeline.Segments[1].TimelineStartSeconds > 150d);
    }

    [Fact]
    public async Task HandleEditorHotkeyAsync_should_switch_tools_and_update_in_out_points()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.PreviewVirtualSeconds = 42;
        await viewModel.HandleEditorHotkeyAsync(Key.B);
        Assert.True(viewModel.IsBladeToolActive);
        await viewModel.HandleEditorHotkeyAsync(Key.I);
        viewModel.PreviewVirtualSeconds = 84;
        await viewModel.HandleEditorHotkeyAsync(Key.V);
        await viewModel.HandleEditorHotkeyAsync(Key.O);

        Assert.True(viewModel.IsSelectToolActive);
        Assert.False(viewModel.IsBladeToolActive);
        Assert.Equal("00:00:42.00", viewModel.InPointText);
        Assert.Equal("00:01:24.00", viewModel.OutPointText);
    }

    [Fact]
    public async Task HandleEditorHotkeyAsync_should_support_undo_and_redo()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.PreviewVirtualSeconds = 150;
        await viewModel.SplitAtPlayheadCommand.ExecuteAsync(null);
        Assert.Equal(2, viewModel.Timeline.Segments.Count);

        await viewModel.HandleEditorHotkeyAsync(Key.Z, controlModifier: true);
        Assert.Single(viewModel.Timeline.Segments);

        await viewModel.HandleEditorHotkeyAsync(Key.Y, controlModifier: true);
        Assert.Equal(2, viewModel.Timeline.Segments.Count);
    }

    [Fact]
    public async Task PreviousCutCommand_and_NextCutCommand_should_jump_between_timeline_boundaries()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.PreviewVirtualSeconds = 120d;
        await viewModel.SplitAtPlayheadCommand.ExecuteAsync(null);
        viewModel.PreviewVirtualSeconds = 240d;
        await viewModel.SplitAtPlayheadCommand.ExecuteAsync(null);
        viewModel.PreviewVirtualSeconds = 200d;

        await viewModel.PreviousCutCommand.ExecuteAsync(null);
        Assert.Equal(120d, viewModel.PreviewVirtualSeconds, 3);

        await viewModel.NextCutCommand.ExecuteAsync(null);
        Assert.Equal(240d, viewModel.PreviewVirtualSeconds, 3);
    }

    [Fact]
    public async Task HandleEditorHotkeyAsync_should_support_previous_and_next_cut_navigation()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.PreviewVirtualSeconds = 120d;
        await viewModel.SplitAtPlayheadCommand.ExecuteAsync(null);
        viewModel.PreviewVirtualSeconds = 240d;
        await viewModel.SplitAtPlayheadCommand.ExecuteAsync(null);
        viewModel.PreviewVirtualSeconds = 200d;

        await viewModel.HandleEditorHotkeyAsync(Key.Q);
        Assert.Equal(120d, viewModel.PreviewVirtualSeconds, 3);

        await viewModel.HandleEditorHotkeyAsync(Key.W);
        Assert.Equal(240d, viewModel.PreviewVirtualSeconds, 3);
    }

    [Fact]
    public async Task HandleEditorHotkeyAsync_should_support_home_and_end_navigation()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.PreviewVirtualSeconds = 90d;

        await viewModel.HandleEditorHotkeyAsync(Key.Home);
        Assert.Equal(0d, viewModel.PreviewVirtualSeconds, 3);

        await viewModel.HandleEditorHotkeyAsync(Key.End);
        Assert.Equal(viewModel.PreviewVirtualMaximum, viewModel.PreviewVirtualSeconds, 3);
    }

    [Fact]
    public async Task HandleEditorHotkeyAsync_should_support_jkl_transport_navigation()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.PreviewVirtualSeconds = 100d;

        await viewModel.HandleEditorHotkeyAsync(Key.J);
        Assert.Equal(99d, viewModel.PreviewVirtualSeconds, 3);

        await viewModel.HandleEditorHotkeyAsync(Key.L);
        Assert.Equal(100d, viewModel.PreviewVirtualSeconds, 3);
    }

    [Fact]
    public async Task HandleEditorHotkeyAsync_should_toggle_playback_with_spacebar()
    {
        var ffmpegPath = FfmpegLocator.Resolve();
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath))
        {
            return;
        }

        var sourcePath = CreateRealVideo("playback-space-hotkey.avi", ffmpegPath);
        var queueItem = BuildQueueItem(sourcePath);
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath,
            (_, _) => { },
            autoLoadPreview: false,
            enablePlaybackEngine: true);

        await viewModel.HandleEditorHotkeyAsync(Key.Space);
        Assert.True(viewModel.IsPlaying);

        await viewModel.HandleEditorHotkeyAsync(Key.Space);
        Assert.False(viewModel.IsPlaying);
    }

    [Fact]
    public async Task ToggleKeepCutCommand_should_switch_selected_segment_to_cut()
    {
        var queueItem = BuildQueueItem();
        TimelineProject? savedTimeline = null;
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (timeline, _) => savedTimeline = timeline,
            autoLoadPreview: false);

        viewModel.PreviewVirtualSeconds = 120d;
        await viewModel.SplitAtPlayheadCommand.ExecuteAsync(null);
        viewModel.SelectedSegment = viewModel.Segments[1];
        await viewModel.ToggleKeepCutCommand.ExecuteAsync(null);
        viewModel.SaveToQueueCommand.Execute(null);

        Assert.NotNull(savedTimeline);
        Assert.Equal(TimelineSegmentKind.Cut, savedTimeline!.Segments[1].Kind);
    }

    [Fact]
    public async Task TrimSelectedToInOutCommand_should_trim_selected_segment_to_source_range()
    {
        var queueItem = BuildQueueItem();
        TimelineProject? savedTimeline = null;
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (timeline, _) => savedTimeline = timeline,
            autoLoadPreview: false);

        viewModel.PreviewVirtualSeconds = 120d;
        await viewModel.SplitAtPlayheadCommand.ExecuteAsync(null);
        viewModel.SelectedSegment = viewModel.Segments[1];
        viewModel.InPointText = "00:03:00.00";
        viewModel.OutPointText = "00:04:00.00";
        await viewModel.TrimSelectedToInOutCommand.ExecuteAsync(null);
        viewModel.SaveToQueueCommand.Execute(null);

        Assert.NotNull(savedTimeline);
        Assert.Equal(180d, savedTimeline!.Segments[1].SourceStartSeconds, 3);
        Assert.Equal(240d, savedTimeline.Segments[1].SourceEndSeconds, 3);
    }

    [Fact]
    public async Task DuplicateSelectedCommand_should_clone_selected_segment_after_itself()
    {
        var queueItem = BuildQueueItem();
        TimelineProject? savedTimeline = null;
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (timeline, _) => savedTimeline = timeline,
            autoLoadPreview: false);

        viewModel.PreviewVirtualSeconds = 120d;
        await viewModel.SplitAtPlayheadCommand.ExecuteAsync(null);
        viewModel.SelectedSegment = viewModel.Segments[1];
        await viewModel.DuplicateSelectedCommand.ExecuteAsync(null);
        viewModel.SaveToQueueCommand.Execute(null);

        Assert.NotNull(savedTimeline);
        Assert.Equal(3, savedTimeline!.Segments.Count);
        Assert.Equal(120d, savedTimeline.Segments[1].TimelineStartSeconds, 3);
        Assert.Equal(300d, savedTimeline.Segments[2].TimelineStartSeconds, 3);
        Assert.Equal(savedTimeline.Segments[1].SourceStartSeconds, savedTimeline.Segments[2].SourceStartSeconds, 3);
        Assert.Equal(savedTimeline.Segments[1].SourceEndSeconds, savedTimeline.Segments[2].SourceEndSeconds, 3);
    }

    [Fact]
    public async Task CloseAllGapsCommand_should_remove_gap_segments_and_pack_timeline()
    {
        var queueItem = BuildQueueItem();
        TimelineProject? savedTimeline = null;
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (timeline, _) => savedTimeline = timeline,
            autoLoadPreview: false);

        viewModel.PreviewVirtualSeconds = 120d;
        await viewModel.SplitAtPlayheadCommand.ExecuteAsync(null);
        viewModel.PreviewVirtualSeconds = 180d;
        await viewModel.SplitAtPlayheadCommand.ExecuteAsync(null);
        viewModel.SelectedSegment = viewModel.Segments[1];
        await viewModel.DeleteSegmentCommand.ExecuteAsync(null);
        await viewModel.CloseAllGapsCommand.ExecuteAsync(null);
        viewModel.SaveToQueueCommand.Execute(null);

        Assert.NotNull(savedTimeline);
        Assert.Equal(2, savedTimeline!.Segments.Count);
        Assert.DoesNotContain(savedTimeline.Segments, segment => segment.Kind == TimelineSegmentKind.Gap);
        Assert.Equal(180d, savedTimeline.Segments[1].SourceStartSeconds, 3);
        Assert.Equal(120d, savedTimeline.Segments[1].TimelineStartSeconds, 3);
    }

    [Fact]
    public async Task MergeWithNextCommand_should_join_selected_segment_with_following_compatible_segment()
    {
        var queueItem = BuildQueueItem();
        TimelineProject? savedTimeline = null;
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (timeline, _) => savedTimeline = timeline,
            autoLoadPreview: false);

        viewModel.PreviewVirtualSeconds = 120d;
        await viewModel.SplitAtPlayheadCommand.ExecuteAsync(null);
        viewModel.SelectedSegment = viewModel.Segments[0];
        await viewModel.MergeWithNextCommand.ExecuteAsync(null);
        viewModel.SaveToQueueCommand.Execute(null);

        Assert.NotNull(savedTimeline);
        Assert.Single(savedTimeline!.Segments);
        Assert.Equal(0d, savedTimeline.Segments[0].SourceStartSeconds, 3);
        Assert.Equal(300d, savedTimeline.Segments[0].SourceEndSeconds, 3);
    }

    [Fact]
    public async Task SlipRightCommand_should_shift_selected_segment_source_window_by_one_frame()
    {
        var queueItem = BuildQueueItem();
        TimelineProject? savedTimeline = null;
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (timeline, _) => savedTimeline = timeline,
            autoLoadPreview: false);

        viewModel.PreviewVirtualSeconds = 60d;
        await viewModel.SplitAtPlayheadCommand.ExecuteAsync(null);
        viewModel.PreviewVirtualSeconds = 180d;
        await viewModel.SplitAtPlayheadCommand.ExecuteAsync(null);
        viewModel.SelectedSegment = viewModel.Segments[1];
        await viewModel.SlipRightCommand.ExecuteAsync(null);
        viewModel.SaveToQueueCommand.Execute(null);

        Assert.NotNull(savedTimeline);
        Assert.Equal(60d, savedTimeline!.Segments[1].TimelineStartSeconds, 3);
        Assert.Equal(60.04d, savedTimeline.Segments[1].SourceStartSeconds, 2);
        Assert.Equal(180.04d, savedTimeline.Segments[1].SourceEndSeconds, 2);
    }

    [Fact]
    public async Task ExtractSelectedToInOutCommand_should_split_selected_segment_around_in_out_range()
    {
        var queueItem = BuildQueueItem();
        TimelineProject? savedTimeline = null;
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (timeline, _) => savedTimeline = timeline,
            autoLoadPreview: false);

        viewModel.SelectedSegment = viewModel.Segments[0];
        viewModel.InPointText = "00:00:10.00";
        viewModel.OutPointText = "00:00:30.00";
        await viewModel.ExtractSelectedToInOutCommand.ExecuteAsync(null);
        viewModel.SaveToQueueCommand.Execute(null);

        Assert.NotNull(savedTimeline);
        Assert.Equal(3, savedTimeline!.Segments.Count);
        Assert.Equal(10d, savedTimeline.Segments[1].TimelineStartSeconds, 3);
        Assert.Equal(10d, savedTimeline.Segments[1].SourceStartSeconds, 3);
        Assert.Equal(30d, savedTimeline.Segments[1].SourceEndSeconds, 3);
    }

    [Fact]
    public async Task RollRightCommand_should_move_boundary_between_selected_segment_and_next_by_one_frame()
    {
        var queueItem = BuildQueueItem();
        TimelineProject? savedTimeline = null;
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (timeline, _) => savedTimeline = timeline,
            autoLoadPreview: false);

        viewModel.PreviewVirtualSeconds = 120d;
        await viewModel.SplitAtPlayheadCommand.ExecuteAsync(null);
        viewModel.SelectedSegment = viewModel.Segments[0];
        await viewModel.RollRightCommand.ExecuteAsync(null);
        viewModel.SaveToQueueCommand.Execute(null);

        Assert.NotNull(savedTimeline);
        Assert.Equal(2, savedTimeline!.Segments.Count);
        Assert.Equal(120.04d, savedTimeline.Segments[0].SourceEndSeconds, 2);
        Assert.Equal(120.04d, savedTimeline.Segments[1].TimelineStartSeconds, 2);
        Assert.Equal(120.04d, savedTimeline.Segments[1].SourceStartSeconds, 2);
    }

    [Fact]
    public async Task InsertGapAtPlayheadCommand_should_add_one_second_gap_at_current_position()
    {
        var queueItem = BuildQueueItem();
        TimelineProject? savedTimeline = null;
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (timeline, _) => savedTimeline = timeline,
            autoLoadPreview: false);

        viewModel.PreviewVirtualSeconds = 120d;
        await viewModel.InsertGapAtPlayheadCommand.ExecuteAsync(null);
        viewModel.SaveToQueueCommand.Execute(null);

        Assert.NotNull(savedTimeline);
        Assert.Equal(3, savedTimeline!.Segments.Count);
        Assert.Equal(TimelineSegmentKind.Gap, savedTimeline.Segments[1].Kind);
        Assert.Equal(120d, savedTimeline.Segments[1].TimelineStartSeconds, 3);
        Assert.Equal(121d, savedTimeline.Segments[2].TimelineStartSeconds, 3);
    }

    [Fact]
    public async Task UndoRedoCommands_should_restore_previous_and_next_timeline_states()
    {
        var queueItem = BuildQueueItem();
        TimelineProject? savedTimeline = null;
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: null,
            (timeline, _) => savedTimeline = timeline,
            autoLoadPreview: false);

        viewModel.PreviewVirtualSeconds = 120d;
        await viewModel.SplitAtPlayheadCommand.ExecuteAsync(null);
        Assert.Equal(2, viewModel.Segments.Count);

        await viewModel.UndoCommand.ExecuteAsync(null);
        Assert.Single(viewModel.Segments);

        await viewModel.RedoCommand.ExecuteAsync(null);
        viewModel.SaveToQueueCommand.Execute(null);

        Assert.NotNull(savedTimeline);
        Assert.Equal(2, savedTimeline!.Segments.Count);
    }

    [Fact]
    public void PrepareForDisplayAsync_should_route_startup_preview_through_commit_pipeline()
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
        var methodIndex = source.IndexOf("public async Task PrepareForDisplayAsync()", StringComparison.Ordinal);
        var commitIndex = source.IndexOf("await CommitPreviewSliderAsync();", methodIndex, StringComparison.Ordinal);
        var directFfmpegIndex = source.IndexOf("await LoadPreviewAsync();", methodIndex, StringComparison.Ordinal);

        Assert.True(methodIndex >= 0);
        Assert.True(commitIndex > methodIndex);
        Assert.True(directFfmpegIndex == -1 || directFfmpegIndex > commitIndex);
    }

    [Fact]
    public void OnPreviewVirtualSecondsChanged_should_drive_playback_preview_during_manual_navigation()
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

        Assert.Contains("private bool _isManualPreviewNavigation;", source, StringComparison.Ordinal);
        Assert.Contains("if (_isManualPreviewNavigation && !IsPlaying)", source, StringComparison.Ordinal);
        Assert.Contains("TryStartPlaybackPreview(resumePlaybackAfterSeek: false)", source, StringComparison.Ordinal);
    }

    public void Dispose()
    {
        if (Directory.Exists(_rootPath))
        {
            Directory.Delete(_rootPath, true);
        }
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

    private static void EnsureAvaloniaInitialized()
    {
        if (Interlocked.CompareExchange(ref _avaloniaInitialized, 1, 0) != 0)
        {
            return;
        }

        AppBuilder.Configure<VhsMp4Optimizer.App.App>()
            .UsePlatformDetect()
            .WithInterFont()
            .SetupWithoutStarting();
    }

    private string CreateRealVideo(string fileName, string ffmpegPath)
    {
        var fullPath = Path.Combine(_rootPath, fileName);
        var startInfo = new ProcessStartInfo
        {
            FileName = ffmpegPath,
            RedirectStandardError = true,
            RedirectStandardOutput = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        foreach (var argument in new[]
                 {
                     "-y",
                     "-f", "lavfi",
                     "-i", "testsrc=size=320x240:rate=25",
                     "-f", "lavfi",
                     "-i", "sine=frequency=1000:sample_rate=48000",
                     "-t", "2",
                     "-c:v", "mpeg4",
                     "-c:a", "mp3",
                     fullPath
                 })
        {
            startInfo.ArgumentList.Add(argument);
        }

        using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("ffmpeg test source proces nije pokrenut.");
        process.WaitForExit();
        var errorText = process.StandardError.ReadToEnd();
        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException($"ffmpeg nije uspeo da napravi playback test video: {errorText}");
        }

        return fullPath;
    }

    private string CreateTinyPng(string fileName)
    {
        var fullPath = Path.Combine(_rootPath, fileName);
        var bytes = Convert.FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO5yR0YAAAAASUVORK5CYII=");
        File.WriteAllBytes(fullPath, bytes);
        return fullPath;
    }

    private static QueueItemSummary BuildQueueItem(string sourcePath = @"C:\video\clip.avi")
    {
        var mediaInfo = new MediaInfo
        {
            SourceName = "clip.avi",
            SourcePath = sourcePath,
            Container = "avi",
            DurationSeconds = 300,
            DurationText = "00:05:00",
            SizeBytes = 10485760,
            SizeText = "10 MB",
            OverallBitrateKbps = 4500,
            OverallBitrateText = "4500 kbps",
            VideoCodec = "mpeg4",
            Width = 720,
            Height = 576,
            Resolution = "720x576",
            DisplayAspectRatio = "4:3",
            SampleAspectRatio = "16:15",
            FrameRate = 25,
            FrameRateText = "25 fps",
            FrameCount = 7500,
            VideoBitrateKbps = 4000,
            VideoBitrateText = "4000 kbps",
            AudioCodec = "mp3",
            AudioChannels = 2,
            AudioSampleRateHz = 48000,
            AudioBitrateKbps = 192,
            AudioBitrateText = "192 kbps",
            VideoSummary = "mpeg4 | 720x576 | 25 fps",
            AudioSummary = "mp3 | 2 ch | 192 kbps"
        };

        return new QueueItemSummary
        {
            SourceFile = "clip.avi",
            SourcePath = mediaInfo.SourcePath,
            OutputFile = "clip.mp4",
            OutputPath = @"C:\video\clip.mp4",
            OutputPattern = @"C:\video\clip.mp4",
            Container = mediaInfo.Container,
            Resolution = mediaInfo.Resolution,
            Duration = mediaInfo.DurationText,
            Video = mediaInfo.VideoSummary,
            Audio = mediaInfo.AudioSummary,
            Status = "queued",
            MediaInfo = mediaInfo,
            PlannedOutput = new OutputPlanSummary
            {
                DisplayOutputName = "clip.mp4",
                Container = "mp4",
                Resolution = "768x576",
                DurationText = mediaInfo.DurationText,
                VideoCodecLabel = "h264",
                VideoBitrateComparisonText = "3500k",
                AudioCodecText = "aac",
                AudioBitrateText = "128k",
                BitrateText = "3628 kbps",
                EncodeEngineText = "CPU",
                EstimatedSizeText = "120 MB",
                UsbNoteText = "FAT32 OK",
                SplitModeText = "No split",
                CropText = "--",
                AspectText = "4:3",
                OutputWidth = 768,
                OutputHeight = 576
            },
            TimelineProject = null,
            TransformSettings = null
        };
    }

    private static void DisablePlaybackEngine(PlayerTrimWindowViewModel viewModel)
    {
        var type = typeof(PlayerTrimWindowViewModel);
        (type.GetField("_playbackMediaPlayer", BindingFlags.Instance | BindingFlags.NonPublic)?.GetValue(viewModel) as IDisposable)?.Dispose();
        (type.GetField("_playbackMedia", BindingFlags.Instance | BindingFlags.NonPublic)?.GetValue(viewModel) as IDisposable)?.Dispose();
        (type.GetField("_libVlc", BindingFlags.Instance | BindingFlags.NonPublic)?.GetValue(viewModel) as IDisposable)?.Dispose();
        type.GetField("_playbackMediaPlayer", BindingFlags.Instance | BindingFlags.NonPublic)?.SetValue(viewModel, null);
        type.GetField("_playbackMedia", BindingFlags.Instance | BindingFlags.NonPublic)?.SetValue(viewModel, null);
        type.GetField("_libVlc", BindingFlags.Instance | BindingFlags.NonPublic)?.SetValue(viewModel, null);
        viewModel.PlaybackMediaPlayerBinding = null;
    }

    private sealed class FakePreviewFrameService : IPreviewFrameService
    {
        private readonly Func<string, MediaInfo, double, ItemTransformSettings?, CancellationToken, string?> _handler;

        public FakePreviewFrameService(Func<string, MediaInfo, double, ItemTransformSettings?, CancellationToken, string?> handler)
        {
            _handler = handler;
        }

        public Task<string?> RenderPreviewAsync(string ffmpegPath, MediaInfo mediaInfo, double sourceSeconds, ItemTransformSettings? transformSettings = null, CancellationToken cancellationToken = default)
        {
            return Task.FromResult(_handler(ffmpegPath, mediaInfo, sourceSeconds, transformSettings, cancellationToken));
        }
    }
}
