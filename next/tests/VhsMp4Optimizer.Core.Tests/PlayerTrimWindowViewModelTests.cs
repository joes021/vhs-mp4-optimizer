using VhsMp4Optimizer.App.ViewModels;
using Avalonia;
using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Infrastructure.Services;
using System.Diagnostics;
using System.Reflection;
using System.Threading;
using VhsMp4Optimizer.App;

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
    public async Task RefreshPreviewCommand_should_surface_preview_errors()
    {
        var queueItem = BuildQueueItem();
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe",
            (_, _) => { },
            new FakePreviewFrameService((_, _, _, _, _) => throw new InvalidOperationException("preview fail")),
            autoLoadPreview: false);

        await viewModel.RefreshPreviewCommand.ExecuteAsync(null);

        Assert.Contains("preview fail", viewModel.EditorHint, StringComparison.OrdinalIgnoreCase);
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
    public async Task Changing_preview_virtual_position_while_paused_should_request_new_preview_frame()
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

        viewModel.PreviewVirtualSeconds = 12;
        await Task.Delay(250);

        Assert.Contains(requestedSeconds, value => Math.Abs(value - 12d) < 0.01d);
    }

    [Fact]
    public async Task PrepareForDisplayAsync_should_render_initial_preview_before_window_shows()
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

        await viewModel.PrepareForDisplayAsync();

        Assert.Equal(1, previewRequests);
        Assert.DoesNotContain("nije dostupan", viewModel.EditorHint, StringComparison.OrdinalIgnoreCase);
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
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath,
            (_, _) => { },
            autoLoadPreview: false);

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
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath,
            (_, _) => { },
            autoLoadPreview: false);

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
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.PlayCommand.Execute(null);

        Assert.True(viewModel.IsPlaying);
        Assert.True(viewModel.IsPreviewImageVisible);
    }

    [Fact]
    public void PlaybackSurfaceBinding_should_attach_only_during_playback_and_detach_on_pause()
    {
        var ffmpegPath = FfmpegLocator.Resolve();
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath))
        {
            return;
        }

        var sourcePath = CreateRealVideo("playback-surface-binding.avi", ffmpegPath);
        var queueItem = BuildQueueItem(sourcePath);
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath,
            (_, _) => { },
            autoLoadPreview: false);

        Assert.Null(viewModel.PlaybackMediaPlayerBinding);

        viewModel.PlayCommand.Execute(null);
        Assert.NotNull(viewModel.PlaybackMediaPlayerBinding);

        viewModel.PauseCommand.Execute(null);
        Assert.Null(viewModel.PlaybackMediaPlayerBinding);
    }

    [Fact]
    public void BeginManualPreviewNavigation_should_leave_playback_mode_and_return_to_trim_preview()
    {
        var ffmpegPath = FfmpegLocator.Resolve();
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath))
        {
            return;
        }

        var sourcePath = CreateRealVideo("playback-source-manual-nav.avi", ffmpegPath);
        var queueItem = BuildQueueItem(sourcePath);
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.PlayCommand.Execute(null);
        viewModel.BeginManualPreviewNavigation();

        Assert.False(viewModel.IsPlaying);
        Assert.False(viewModel.IsVideoPlaybackVisible);
        Assert.True(viewModel.IsPreviewImageVisible);
    }

    [Fact]
    public async Task BeginManualPreviewNavigation_should_request_fresh_preview_for_precise_trim()
    {
        var ffmpegPath = FfmpegLocator.Resolve();
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath))
        {
            return;
        }

        var sourcePath = CreateRealVideo("playback-source-manual-refresh.avi", ffmpegPath);
        var queueItem = BuildQueueItem(sourcePath);
        var requestedSeconds = new List<double>();
        var previewPath = CreateTinyPng("manual-refresh-preview.png");
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath,
            (_, _) => { },
            new FakePreviewFrameService((_, _, sourceSeconds, _, _) =>
            {
                requestedSeconds.Add(sourceSeconds);
                return previewPath;
            }),
            autoLoadPreview: false);

        viewModel.PlayCommand.Execute(null);
        viewModel.BeginManualPreviewNavigation();
        await Task.Delay(250);

        Assert.Contains(requestedSeconds, value => value >= 0d);
    }

    [Fact]
    public async Task CommitPreviewSliderAsync_should_render_exact_preview_frame_after_playback_navigation()
    {
        var ffmpegPath = FfmpegLocator.Resolve();
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath))
        {
            return;
        }

        var sourcePath = CreateRealVideo("playback-source-preview-frame.avi", ffmpegPath);
        var queueItem = BuildQueueItem(sourcePath);
        var requestedSeconds = new List<double>();
        var previewPath = CreateTinyPng("post-playback-preview.png");
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath,
            (_, _) => { },
            new FakePreviewFrameService((_, _, sourceSeconds, _, _) =>
            {
                requestedSeconds.Add(sourceSeconds);
                return previewPath;
            }),
            autoLoadPreview: false);

        viewModel.PlayCommand.Execute(null);
        viewModel.BeginManualPreviewNavigation();
        viewModel.PreviewVirtualSeconds = 1.0d;
        await viewModel.CommitPreviewSliderAsync();

        Assert.False(viewModel.IsPlaying);
        Assert.False(viewModel.IsVideoPlaybackVisible);
        Assert.True(viewModel.IsPreviewImageVisible);
        Assert.Contains(requestedSeconds, value => Math.Abs(value - 1.0d) < 0.05d);
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
    public async Task PrepareForDisplayAsync_should_render_preview_for_large_dv_avi_when_file_is_available()
    {
        const string sourcePath = @"F:\Veliki avi\1996 -1 -6 - .avi";
        var ffmpegPath = FfmpegLocator.Resolve();
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath) || !File.Exists(sourcePath))
        {
            return;
        }

        var queueItem = new QueueItemSummary
        {
            SourceFile = Path.GetFileName(sourcePath),
            SourcePath = sourcePath,
            OutputFile = "1996 -1 -6 - .mp4",
            OutputPath = Path.Combine(_rootPath, "1996 -1 -6 - .mp4"),
            OutputPattern = Path.Combine(_rootPath, "1996 -1 -6 - .mp4"),
            Container = "avi",
            Resolution = "720x576",
            Duration = "01:49:23",
            Video = "dvvideo | 720x576 | 25 fps",
            Audio = "pcm_s16le | 2 ch",
            Status = "queued",
            PlannedOutput = new OutputPlanSummary
            {
                DisplayOutputName = "1996 -1 -6 - .mp4",
                Container = "mp4",
                Resolution = "768x576",
                DurationText = "01:49:23",
                VideoCodecLabel = "h264",
                VideoBitrateComparisonText = "5000k",
                AudioCodecText = "aac",
                AudioBitrateText = "160k",
                BitrateText = "5160 kbps",
                EncodeEngineText = "CPU",
                EstimatedSizeText = "4.0 GB",
                UsbNoteText = "split 2 dela",
                SplitModeText = "split",
                CropText = "--",
                AspectText = "4:3",
                OutputWidth = 768,
                OutputHeight = 576
            },
            MediaInfo = new MediaInfo
            {
                SourceName = Path.GetFileName(sourcePath),
                SourcePath = sourcePath,
                Container = "avi",
                DurationSeconds = 6563.16,
                DurationText = "01:49:23",
                SizeBytes = 24955441664,
                SizeText = "24 GB",
                OverallBitrateKbps = 30419,
                OverallBitrateText = "30419 kbps",
                VideoCodec = "dvvideo",
                Width = 720,
                Height = 576,
                Resolution = "720x576",
                DisplayAspectRatio = "4:3",
                SampleAspectRatio = "16:15",
                FrameRate = 25,
                FrameRateText = "25 fps",
                FrameCount = 164079,
                VideoBitrateKbps = 28800,
                VideoBitrateText = "28800 kbps",
                AudioCodec = "pcm_s16le",
                AudioChannels = 2,
                AudioSampleRateHz = 48000,
                AudioBitrateKbps = 1536,
                AudioBitrateText = "1536 kbps",
                VideoSummary = "dvvideo | 720x576 | 25 fps",
                AudioSummary = "pcm_s16le | 2 ch"
            }
        };

        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath,
            (_, _) => { },
            autoLoadPreview: false);

        await viewModel.PrepareForDisplayAsync();

        Assert.NotNull(viewModel.PreviewBitmap);
        Assert.DoesNotContain("Preview nije uspeo", viewModel.EditorHint, StringComparison.OrdinalIgnoreCase);
    }

    public void Dispose()
    {
        if (Directory.Exists(_rootPath))
        {
            Directory.Delete(_rootPath, true);
        }
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
