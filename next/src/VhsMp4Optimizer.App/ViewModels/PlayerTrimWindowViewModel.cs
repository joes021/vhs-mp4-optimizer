using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Media.Imaging;
using Avalonia.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using LibVLCSharp.Shared;
using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Core.Services;
using VhsMp4Optimizer.Infrastructure.Services;
using CoreServices = VhsMp4Optimizer.Core.Services;

namespace VhsMp4Optimizer.App.ViewModels;

public partial class PlayerTrimWindowViewModel : ViewModelBase, IDisposable
{
    private readonly Action<TimelineProject, ItemTransformSettings?> _saveAction;
    private readonly IPreviewFrameService _previewFrameService;
    private readonly CropDetectService _cropDetectService = new();
    private readonly string? _ffmpegPath;
    private CancellationTokenSource? _previewCts;
    private CancellationTokenSource? _previewDebounceCts;
    private readonly DispatcherTimer _playbackTimer;
    private LibVLC? _libVlc;
    private MediaPlayer? _playbackMediaPlayer;
    private Media? _playbackMedia;
    private long? _pendingPlaybackSeekMilliseconds;
    private bool _previewBusy;
    private bool _suppressPreviewAutoRefresh;
    private bool _awaitingPlaybackFrame;
    private bool _disposed;
    private bool _previewRefreshQueued;
    private bool _unmuteWhenPlaybackFrameArrives;
    private double _lastRequestedSourceSeconds;
    private readonly Stack<TimelineProject> _undoStack = new();
    private readonly Stack<TimelineProject> _redoStack = new();

    public PlayerTrimWindowViewModel(
        QueueItemSummary item,
        string? ffmpegPath,
        Action<TimelineProject, ItemTransformSettings?> saveAction,
        IPreviewFrameService? previewFrameService = null,
        bool autoLoadPreview = true)
    {
        ArgumentNullException.ThrowIfNull(item.MediaInfo);

        _previewFrameService = previewFrameService ?? new PreviewFrameService();
        _saveAction = saveAction;
        _ffmpegPath = ffmpegPath;
        Item = item;
        Timeline = item.TimelineProject ?? TimelineEditorService.CreateInitial(item.MediaInfo);
        Segments = new ObservableCollection<TimelineSegment>(Timeline.Segments);
        TimelineBlocks = new ObservableCollection<TimelineBlockItemViewModel>();
        AspectModes = new ObservableCollection<string>(AspectModesService());

        var transformSettings = item.TransformSettings ?? new ItemTransformSettings();
        SelectedAspectMode = transformSettings.AspectMode;
        CropLeft = transformSettings.Crop.Left;
        CropTop = transformSettings.Crop.Top;
        CropRight = transformSettings.Crop.Right;
        CropBottom = transformSettings.Crop.Bottom;

        WindowTitle = $"Player / Trim - {item.SourceFile}";
        FileSummary = $"{item.SourceFile} | {item.Container} | {item.Resolution} | {item.Duration}";
        InPointText = "00:00:00.00";
        OutPointText = TimelineEditorService.FormatSeconds(item.MediaInfo.DurationSeconds);

        CutSegmentCommand = new AsyncRelayCommand(ApplyCutSegmentAsync);
        SplitAtPlayheadCommand = new AsyncRelayCommand(SplitAtPlayheadAsync);
        ToggleKeepCutCommand = new AsyncRelayCommand(ToggleKeepCutAsync, CanModifySelectedSegment);
        TrimSelectedToInOutCommand = new AsyncRelayCommand(TrimSelectedToInOutAsync, CanModifySelectedSegment);
        ExtractSelectedToInOutCommand = new AsyncRelayCommand(ExtractSelectedToInOutAsync, CanModifySelectedSegment);
        DuplicateSelectedCommand = new AsyncRelayCommand(DuplicateSelectedAsync, CanModifySelectedSegment);
        CloseAllGapsCommand = new AsyncRelayCommand(CloseAllGapsAsync, HasGapSegments);
        MergeWithNextCommand = new AsyncRelayCommand(MergeWithNextAsync, CanMergeSelectedWithNext);
        RollLeftCommand = new AsyncRelayCommand(() => RollSelectedAsync(-1), CanRollSelectedWithNext);
        RollRightCommand = new AsyncRelayCommand(() => RollSelectedAsync(1), CanRollSelectedWithNext);
        InsertGapAtPlayheadCommand = new AsyncRelayCommand(InsertGapAtPlayheadAsync);
        SlipLeftCommand = new AsyncRelayCommand(() => SlipSelectedAsync(-1), CanSlipSelected);
        SlipRightCommand = new AsyncRelayCommand(() => SlipSelectedAsync(1), CanSlipSelected);
        UndoCommand = new AsyncRelayCommand(UndoAsync, CanUndo);
        RedoCommand = new AsyncRelayCommand(RedoAsync, CanRedo);
        DeleteSegmentCommand = new AsyncRelayCommand(DeleteSegmentAsync, CanModifySelectedSegment);
        RippleDeleteCommand = new AsyncRelayCommand(RippleDeleteSegmentAsync, CanModifySelectedSegment);
        MoveLeftCommand = new AsyncRelayCommand(MoveLeftAsync, CanModifySelectedSegment);
        MoveRightCommand = new AsyncRelayCommand(MoveRightAsync, CanModifySelectedSegment);
        SaveToQueueCommand = new RelayCommand(SaveToQueue);
        SelectTimelineBlockCommand = new RelayCommand<TimelineBlockItemViewModel?>(block => SelectTimelineBlock(block));
        TimelineBlockActionCommand = new AsyncRelayCommand<TimelineBlockItemViewModel?>(HandleTimelineBlockActionAsync);

        GoToStartCommand = new AsyncRelayCommand(GoToStartAsync);
        GoToEndCommand = new AsyncRelayCommand(GoToEndAsync);
        BackFrameCommand = new AsyncRelayCommand(() => StepFramesAsync(-1));
        ForwardFrameCommand = new AsyncRelayCommand(() => StepFramesAsync(1));
        Back25FramesCommand = new AsyncRelayCommand(() => StepFramesAsync(-25));
        Forward25FramesCommand = new AsyncRelayCommand(() => StepFramesAsync(25));
        Back250FramesCommand = new AsyncRelayCommand(() => StepFramesAsync(-250));
        Forward250FramesCommand = new AsyncRelayCommand(() => StepFramesAsync(250));
        RefreshPreviewCommand = new AsyncRelayCommand(LoadPreviewAsync);
        DetectCropCommand = new AsyncRelayCommand(DetectCropAsync);
        AutoCropCommand = new AsyncRelayCommand(DetectCropAsync);
        ClearCropCommand = new AsyncRelayCommand(ClearCropAsync);
        SetInPointCommand = new RelayCommand(SetInPointFromCurrent);
        SetOutPointCommand = new RelayCommand(SetOutPointFromCurrent);
        PlayCommand = new RelayCommand(StartPlayback, CanStartPlayback);
        PauseCommand = new RelayCommand(PausePlayback, CanPausePlayback);
        SelectModeCommand = new RelayCommand<string?>(SelectMode);
        SelectWorkspaceDockCommand = new RelayCommand<string?>(SelectWorkspaceDock);
        SelectMonitorTabCommand = new RelayCommand<string?>(SelectMonitorTab);
        SelectInspectorTabCommand = new RelayCommand<string?>(SelectInspectorTab);
        SelectToolCommand = new RelayCommand<string?>(SelectTool);
        SelectZoomPresetCommand = new RelayCommand<string?>(SelectZoomPreset);
        SelectBottomDockCommand = new RelayCommand<string?>(SelectBottomDock);
        SelectLaneTargetCommand = new RelayCommand<string?>(SelectLaneTarget);
        ToggleSnapCommand = new RelayCommand(ToggleSnap);
        ToggleLinkedSelectionCommand = new RelayCommand(ToggleLinkedSelection);
        ToggleLoopPlaybackCommand = new RelayCommand(ToggleLoopPlayback);
        ToggleTrackLockCommand = new RelayCommand(ToggleTrackLock);
        ToggleTrackMuteCommand = new RelayCommand(ToggleTrackMute);
        ToggleTrackSoloCommand = new RelayCommand(ToggleTrackSolo);

        _playbackTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(40)
        };
        _playbackTimer.Tick += PlaybackTimerOnTick;

        InitializePlaybackEngine();
        RefreshState();
        if (autoLoadPreview)
        {
            _ = LoadPreviewAsync();
        }
    }

    public QueueItemSummary Item { get; }

    public ObservableCollection<TimelineSegment> Segments { get; }

    public ObservableCollection<TimelineBlockItemViewModel> TimelineBlocks { get; }

    public ObservableCollection<string> AspectModes { get; }

    public IAsyncRelayCommand CutSegmentCommand { get; }

    public IAsyncRelayCommand SplitAtPlayheadCommand { get; }

    public IAsyncRelayCommand ToggleKeepCutCommand { get; }

    public IAsyncRelayCommand TrimSelectedToInOutCommand { get; }

    public IAsyncRelayCommand ExtractSelectedToInOutCommand { get; }

    public IAsyncRelayCommand DuplicateSelectedCommand { get; }

    public IAsyncRelayCommand CloseAllGapsCommand { get; }

    public IAsyncRelayCommand MergeWithNextCommand { get; }

    public IAsyncRelayCommand RollLeftCommand { get; }

    public IAsyncRelayCommand RollRightCommand { get; }

    public IAsyncRelayCommand InsertGapAtPlayheadCommand { get; }

    public IAsyncRelayCommand SlipLeftCommand { get; }

    public IAsyncRelayCommand SlipRightCommand { get; }

    public IAsyncRelayCommand UndoCommand { get; }

    public IAsyncRelayCommand RedoCommand { get; }

    public IAsyncRelayCommand DeleteSegmentCommand { get; }

    public IAsyncRelayCommand RippleDeleteCommand { get; }

    public IAsyncRelayCommand MoveLeftCommand { get; }

    public IAsyncRelayCommand MoveRightCommand { get; }

    public IRelayCommand SaveToQueueCommand { get; }

    public IRelayCommand<TimelineBlockItemViewModel?> SelectTimelineBlockCommand { get; }

    public IAsyncRelayCommand<TimelineBlockItemViewModel?> TimelineBlockActionCommand { get; }

    public IAsyncRelayCommand GoToStartCommand { get; }

    public IAsyncRelayCommand GoToEndCommand { get; }

    public IAsyncRelayCommand BackFrameCommand { get; }

    public IAsyncRelayCommand ForwardFrameCommand { get; }

    public IAsyncRelayCommand Back25FramesCommand { get; }

    public IAsyncRelayCommand Forward25FramesCommand { get; }

    public IAsyncRelayCommand Back250FramesCommand { get; }

    public IAsyncRelayCommand Forward250FramesCommand { get; }

    public IAsyncRelayCommand RefreshPreviewCommand { get; }

    public IAsyncRelayCommand DetectCropCommand { get; }

    public IAsyncRelayCommand AutoCropCommand { get; }

    public IAsyncRelayCommand ClearCropCommand { get; }

    public IRelayCommand SetInPointCommand { get; }

    public IRelayCommand SetOutPointCommand { get; }

    public IRelayCommand PlayCommand { get; }

    public IRelayCommand PauseCommand { get; }

    public IRelayCommand<string?> SelectModeCommand { get; }

    public IRelayCommand<string?> SelectWorkspaceDockCommand { get; }

    public IRelayCommand<string?> SelectMonitorTabCommand { get; }

    public IRelayCommand<string?> SelectInspectorTabCommand { get; }

    public IRelayCommand<string?> SelectToolCommand { get; }

    public IRelayCommand<string?> SelectZoomPresetCommand { get; }

    public IRelayCommand<string?> SelectBottomDockCommand { get; }

    public IRelayCommand<string?> SelectLaneTargetCommand { get; }

    public IRelayCommand ToggleSnapCommand { get; }

    public IRelayCommand ToggleLinkedSelectionCommand { get; }

    public IRelayCommand ToggleLoopPlaybackCommand { get; }

    public IRelayCommand ToggleTrackLockCommand { get; }

    public IRelayCommand ToggleTrackMuteCommand { get; }

    public IRelayCommand ToggleTrackSoloCommand { get; }

    [ObservableProperty]
    private MediaPlayer? _playbackMediaPlayerBinding;

    [ObservableProperty]
    private string _windowTitle = string.Empty;

    [ObservableProperty]
    private string _fileSummary = string.Empty;

    [ObservableProperty]
    private string _selectedClipSummary = "Nijedan segment nije selektovan.";

    [ObservableProperty]
    private TimelineProject _timeline;

    [ObservableProperty]
    private TimelineSegment? _selectedSegment;

    [ObservableProperty]
    private string _inPointText = string.Empty;

    [ObservableProperty]
    private string _outPointText = string.Empty;

    [ObservableProperty]
    private string _selectedAspectMode = CoreServices.AspectModes.Auto;

    [ObservableProperty]
    private int _cropLeft;

    [ObservableProperty]
    private int _cropTop;

    [ObservableProperty]
    private int _cropRight;

    [ObservableProperty]
    private int _cropBottom;

    [ObservableProperty]
    private string _timelineSummary = string.Empty;

    [ObservableProperty]
    private string _editorHint = "Iseceni segment ostaje na liniji kao CUT dok ga ne obrises ili ripple-delete-ujes.";

    [ObservableProperty]
    private double _previewVirtualSeconds;

    [ObservableProperty]
    private double _previewVirtualMaximum;

    [ObservableProperty]
    private string _previewVirtualTimeText = "00:00:00.00";

    [ObservableProperty]
    private string _previewSourceTimeText = "00:00:00.00";

    [ObservableProperty]
    private Bitmap? _previewBitmap;

    [ObservableProperty]
    private bool _isPreviewLoading;

    [ObservableProperty]
    private bool _isPlaying;

    [ObservableProperty]
    private bool _isVideoPlaybackVisible;

    [ObservableProperty]
    private bool _isPreviewImageVisible = true;

    [ObservableProperty]
    private string _activeMode = "Cut";

    [ObservableProperty]
    private string _activeWorkspaceDock = "Media Pool";

    [ObservableProperty]
    private string _activeMonitorTab = "Program";

    [ObservableProperty]
    private string _activeInspectorTab = "Video";

    [ObservableProperty]
    private string _activeTool = "Select";

    [ObservableProperty]
    private string _activeZoomPreset = "Full";

    [ObservableProperty]
    private string _activeBottomDock = "Timeline";

    [ObservableProperty]
    private string _activeLaneTarget = "V1";

    [ObservableProperty]
    private bool _isSnapEnabled = true;

    [ObservableProperty]
    private bool _isLinkedSelectionEnabled = true;

    [ObservableProperty]
    private bool _isLoopPlaybackEnabled;

    [ObservableProperty]
    private bool _isTrackLocked;

    [ObservableProperty]
    private bool _isTrackMuted;

    [ObservableProperty]
    private bool _isTrackSolo;

    public bool IsCutModeActive => string.Equals(ActiveMode, "Cut", StringComparison.Ordinal);
    public bool IsEditModeActive => string.Equals(ActiveMode, "Edit", StringComparison.Ordinal);
    public bool IsColorModeActive => string.Equals(ActiveMode, "Color", StringComparison.Ordinal);
    public bool IsDeliverModeActive => string.Equals(ActiveMode, "Deliver", StringComparison.Ordinal);
    public bool IsMediaPoolActive => string.Equals(ActiveWorkspaceDock, "Media Pool", StringComparison.Ordinal);
    public bool IsEffectsLibraryActive => string.Equals(ActiveWorkspaceDock, "Effects Library", StringComparison.Ordinal);
    public bool IsEditIndexActive => string.Equals(ActiveWorkspaceDock, "Edit Index", StringComparison.Ordinal);
    public bool IsMixerActive => string.Equals(ActiveWorkspaceDock, "Mixer", StringComparison.Ordinal);
    public bool IsSourceMonitorActive => string.Equals(ActiveMonitorTab, "Source", StringComparison.Ordinal);
    public bool IsProgramMonitorActive => string.Equals(ActiveMonitorTab, "Program", StringComparison.Ordinal);
    public bool IsVideoInspectorActive => string.Equals(ActiveInspectorTab, "Video", StringComparison.Ordinal);
    public bool IsAudioInspectorActive => string.Equals(ActiveInspectorTab, "Audio", StringComparison.Ordinal);
    public bool IsEffectsInspectorActive => string.Equals(ActiveInspectorTab, "Effects", StringComparison.Ordinal);
    public bool IsSelectToolActive => string.Equals(ActiveTool, "Select", StringComparison.Ordinal);
    public bool IsBladeToolActive => string.Equals(ActiveTool, "Blade", StringComparison.Ordinal);
    public bool IsSlipToolActive => string.Equals(ActiveTool, "Slip", StringComparison.Ordinal);
    public bool IsRollToolActive => string.Equals(ActiveTool, "Roll", StringComparison.Ordinal);
    public bool IsZoom1sActive => string.Equals(ActiveZoomPreset, "1s", StringComparison.Ordinal);
    public bool IsZoom5sActive => string.Equals(ActiveZoomPreset, "5s", StringComparison.Ordinal);
    public bool IsZoom10sActive => string.Equals(ActiveZoomPreset, "10s", StringComparison.Ordinal);
    public bool IsZoomFullActive => string.Equals(ActiveZoomPreset, "Full", StringComparison.Ordinal);
    public bool IsTimelineBottomDockActive => string.Equals(ActiveBottomDock, "Timeline", StringComparison.Ordinal);
    public bool IsMixerBottomDockActive => string.Equals(ActiveBottomDock, "Mixer", StringComparison.Ordinal);
    public bool IsMetadataBottomDockActive => string.Equals(ActiveBottomDock, "Metadata", StringComparison.Ordinal);
    public bool IsMarkersBottomDockActive => string.Equals(ActiveBottomDock, "Markers", StringComparison.Ordinal);
    public bool IsScopesBottomDockActive => string.Equals(ActiveBottomDock, "Scopes", StringComparison.Ordinal);
    public bool IsV1LaneTargetActive => string.Equals(ActiveLaneTarget, "V1", StringComparison.Ordinal);
    public bool IsV2LaneTargetActive => string.Equals(ActiveLaneTarget, "V2", StringComparison.Ordinal);
    public bool IsA1LaneTargetActive => string.Equals(ActiveLaneTarget, "A1", StringComparison.Ordinal);
    public bool IsA2LaneTargetActive => string.Equals(ActiveLaneTarget, "A2", StringComparison.Ordinal);
    public string SnapStatusText => IsSnapEnabled ? "Snap On" : "Snap Off";
    public bool IsTrackLockActive => IsTrackLocked;
    public bool IsTrackMuteActive => IsTrackMuted;
    public bool IsTrackSoloActive => IsTrackSolo;
    public string TimelineRulerLeftLabel => FormatTimelineRulerSeconds(0);
    public string TimelineRulerCenterLabel => FormatTimelineRulerSeconds(GetTimelineRulerCenterSeconds());
    public string TimelineRulerRightLabel => FormatTimelineRulerSeconds(GetTimelineRulerRightSeconds());
    public string TimelineZoomSummary => $"View span {TimelineRulerLeftLabel} -> {TimelineRulerRightLabel}";
    public string PreviewDurationText => TimelineEditorService.FormatSeconds(Math.Max(0d, PreviewVirtualMaximum));
    public double TimelinePreferredWidth => ActiveZoomPreset switch
    {
        "1s" => 2200,
        "5s" => 1600,
        "10s" => 1200,
        _ => 960
    };

    partial void OnSelectedSegmentChanged(TimelineSegment? value)
    {
        DeleteSegmentCommand.NotifyCanExecuteChanged();
        RippleDeleteCommand.NotifyCanExecuteChanged();
        MoveLeftCommand.NotifyCanExecuteChanged();
        MoveRightCommand.NotifyCanExecuteChanged();
        ToggleKeepCutCommand.NotifyCanExecuteChanged();
        TrimSelectedToInOutCommand.NotifyCanExecuteChanged();
        ExtractSelectedToInOutCommand.NotifyCanExecuteChanged();
        DuplicateSelectedCommand.NotifyCanExecuteChanged();
        CloseAllGapsCommand.NotifyCanExecuteChanged();
        MergeWithNextCommand.NotifyCanExecuteChanged();
        RollLeftCommand.NotifyCanExecuteChanged();
        RollRightCommand.NotifyCanExecuteChanged();
        SlipLeftCommand.NotifyCanExecuteChanged();
        SlipRightCommand.NotifyCanExecuteChanged();
        UndoCommand.NotifyCanExecuteChanged();
        RedoCommand.NotifyCanExecuteChanged();
        SyncSelectedTimelineBlock();
        UpdateSelectedClipSummary();
    }

    partial void OnPreviewVirtualSecondsChanged(double value)
    {
        UpdatePreviewTimeTexts();
        if (_suppressPreviewAutoRefresh || IsPlaying || _disposed)
        {
            return;
        }

        SchedulePreviewRefresh();
    }

    partial void OnIsPlayingChanged(bool value)
    {
        PlayCommand.NotifyCanExecuteChanged();
        PauseCommand.NotifyCanExecuteChanged();
    }

    partial void OnActiveModeChanged(string value) => NotifyEditorChromeStateChanged();

    partial void OnActiveWorkspaceDockChanged(string value) => NotifyEditorChromeStateChanged();

    partial void OnActiveMonitorTabChanged(string value) => NotifyEditorChromeStateChanged();

    partial void OnActiveInspectorTabChanged(string value) => NotifyEditorChromeStateChanged();

    partial void OnActiveToolChanged(string value) => NotifyEditorChromeStateChanged();

    partial void OnActiveZoomPresetChanged(string value) => NotifyEditorChromeStateChanged();

    partial void OnActiveBottomDockChanged(string value) => NotifyEditorChromeStateChanged();

    partial void OnActiveLaneTargetChanged(string value) => NotifyEditorChromeStateChanged();

    partial void OnIsSnapEnabledChanged(bool value) => NotifyEditorChromeStateChanged();

    partial void OnIsLinkedSelectionEnabledChanged(bool value) => NotifyEditorChromeStateChanged();

    partial void OnIsLoopPlaybackEnabledChanged(bool value) => NotifyEditorChromeStateChanged();

    partial void OnIsTrackLockedChanged(bool value) => NotifyEditorChromeStateChanged();

    partial void OnIsTrackMutedChanged(bool value) => NotifyEditorChromeStateChanged();

    partial void OnIsTrackSoloChanged(bool value) => NotifyEditorChromeStateChanged();

    private async Task ApplyCutSegmentAsync()
    {
        if (!TryParseTime(InPointText, out var inSeconds) || !TryParseTime(OutPointText, out var outSeconds))
        {
            EditorHint = "IN/OUT vreme nije u dobrom formatu. Koristi npr. 00:10:05.25";
            return;
        }

        await ApplyTimelineMutationAsync(
            timeline => TimelineEditorService.CutSegment(timeline, inSeconds, outSeconds),
            refreshHint: null);
    }

    private async Task SplitAtPlayheadAsync()
    {
        await ApplyTimelineMutationAsync(
            timeline => TimelineEditorService.SplitAtPlayhead(timeline, PreviewVirtualSeconds),
            refreshHint: null);
        EditorHint = $"Segment je podeljen na playhead-u | virtual {PreviewVirtualTimeText} | source {PreviewSourceTimeText}";
    }

    private async Task ToggleKeepCutAsync()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        await ApplyTimelineMutationAsync(
            timeline => TimelineEditorService.ToggleSegmentKind(timeline, SelectedSegment.Id),
            refreshHint: null);
        EditorHint = $"Segment je prebacen na {SelectedSegment?.Kind}";
    }

    private async Task TrimSelectedToInOutAsync()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        if (!TryParseTime(InPointText, out var inSeconds) || !TryParseTime(OutPointText, out var outSeconds))
        {
            EditorHint = "IN/OUT vreme nije u dobrom formatu za trim selected.";
            return;
        }

        await ApplyTimelineMutationAsync(
            timeline => TimelineEditorService.TrimSegmentToRange(timeline, SelectedSegment.Id, inSeconds, outSeconds),
            refreshHint: null);
        EditorHint = $"Izabrani segment je skracen na {InPointText} -> {OutPointText}";
    }

    private async Task ExtractSelectedToInOutAsync()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        if (!TryParseTime(InPointText, out var inSeconds) || !TryParseTime(OutPointText, out var outSeconds))
        {
            EditorHint = "IN/OUT vreme nije u dobrom formatu za extract selected.";
            return;
        }

        await ApplyTimelineMutationAsync(
            timeline => TimelineEditorService.ExtractSegmentToRange(timeline, SelectedSegment.Id, inSeconds, outSeconds),
            refreshHint: null);
        EditorHint = $"Izabrani segment je izdvojen na {InPointText} -> {OutPointText}";
    }

    private async Task DuplicateSelectedAsync()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        await ApplyTimelineMutationAsync(
            timeline => TimelineEditorService.DuplicateSegment(timeline, SelectedSegment.Id),
            refreshHint: null);
        EditorHint = "Izabrani segment je dupliran odmah iza originala.";
    }

    private async Task CloseAllGapsAsync()
    {
        await ApplyTimelineMutationAsync(
            TimelineEditorService.CloseAllGaps,
            refreshHint: null);
        EditorHint = "Sve rupe na timeline-u su zatvorene.";
    }

    private async Task MergeWithNextAsync()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        await ApplyTimelineMutationAsync(
            timeline => TimelineEditorService.MergeSegmentWithNext(timeline, SelectedSegment.Id),
            refreshHint: null);
        EditorHint = "Izabrani segment je spojen sa narednim.";
    }

    private async Task RollSelectedAsync(int frameDelta)
    {
        if (SelectedSegment is null || Item.MediaInfo is null)
        {
            return;
        }

        var frameRate = Math.Max(1d, Item.MediaInfo.FrameRate);
        await ApplyTimelineMutationAsync(
            timeline => TimelineEditorService.RollBoundaryWithNext(timeline, SelectedSegment.Id, frameDelta / frameRate),
            refreshHint: null);
        EditorHint = $"Granica izmedju izabranog i sledeceg segmenta je pomerena za {frameDelta} frejm.";
    }

    private async Task InsertGapAtPlayheadAsync()
    {
        await ApplyTimelineMutationAsync(
            timeline => TimelineEditorService.InsertGapAtPlayhead(timeline, PreviewVirtualSeconds, 1d),
            refreshHint: null);
        EditorHint = $"Ubacena je rupa od 1s na {PreviewVirtualTimeText}.";
    }

    private async Task SlipSelectedAsync(int frameDelta)
    {
        if (SelectedSegment is null || Item.MediaInfo is null)
        {
            return;
        }

        var frameRate = Math.Max(1d, Item.MediaInfo.FrameRate);
        await ApplyTimelineMutationAsync(
            timeline => TimelineEditorService.SlipSegment(timeline, SelectedSegment.Id, frameDelta / frameRate, Item.MediaInfo.DurationSeconds),
            refreshHint: null);
        EditorHint = $"Izabrani segment je slipovan za {frameDelta} frejm.";
    }

    private async Task DeleteSegmentAsync()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        await ApplyTimelineMutationAsync(
            timeline => TimelineEditorService.DeleteSegment(timeline, SelectedSegment.Id),
            refreshHint: null);
    }

    private async Task RippleDeleteSegmentAsync()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        await ApplyTimelineMutationAsync(
            timeline => TimelineEditorService.RippleDeleteSegment(timeline, SelectedSegment.Id),
            refreshHint: null);
    }

    private async Task MoveLeftAsync()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        await ApplyTimelineMutationAsync(
            timeline => TimelineEditorService.MoveSegmentLeft(timeline, SelectedSegment.Id),
            refreshHint: null);
    }

    private async Task MoveRightAsync()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        await ApplyTimelineMutationAsync(
            timeline => TimelineEditorService.MoveSegmentRight(timeline, SelectedSegment.Id),
            refreshHint: null);
    }

    private void SaveToQueue() => _saveAction(Timeline, BuildTransformSettings());

    private bool CanModifySelectedSegment() => SelectedSegment is not null;

    private bool HasGapSegments() => Timeline.Segments.Any(segment => segment.Kind == TimelineSegmentKind.Gap);

    private bool CanMergeSelectedWithNext()
    {
        if (SelectedSegment is null)
        {
            return false;
        }

        var ordered = Timeline.Segments.OrderBy(segment => segment.TimelineStartSeconds).ToList();
        var index = ordered.FindIndex(segment => segment.Id == SelectedSegment.Id);
        if (index < 0 || index >= ordered.Count - 1)
        {
            return false;
        }

        var next = ordered[index + 1];
        return SelectedSegment.Kind == next.Kind
            && Math.Abs(SelectedSegment.SourceEndSeconds - next.SourceStartSeconds) <= 0.0001d;
    }

    private bool CanSlipSelected() => SelectedSegment is not null && SelectedSegment.Kind != TimelineSegmentKind.Gap;

    private bool CanUndo() => _undoStack.Count > 0;

    private bool CanRedo() => _redoStack.Count > 0;

    private async Task UndoAsync()
    {
        if (_undoStack.Count == 0)
        {
            return;
        }

        _redoStack.Push(Timeline);
        Timeline = _undoStack.Pop();
        await RefreshStateAndPreviewAsync();
        EditorHint = "Vracena je prethodna izmena timeline-a.";
    }

    private async Task RedoAsync()
    {
        if (_redoStack.Count == 0)
        {
            return;
        }

        _undoStack.Push(Timeline);
        Timeline = _redoStack.Pop();
        await RefreshStateAndPreviewAsync();
        EditorHint = "Vracena je sledeca izmena timeline-a.";
    }

    private bool CanRollSelectedWithNext()
    {
        if (SelectedSegment is null || SelectedSegment.Kind == TimelineSegmentKind.Gap)
        {
            return false;
        }

        var ordered = Timeline.Segments.OrderBy(segment => segment.TimelineStartSeconds).ToList();
        var index = ordered.FindIndex(segment => segment.Id == SelectedSegment.Id);
        if (index < 0 || index >= ordered.Count - 1)
        {
            return false;
        }

        return ordered[index + 1].Kind != TimelineSegmentKind.Gap;
    }

    private async Task GoToStartAsync()
    {
        SetPreviewVirtualSecondsSilently(0);
        await CommitPreviewSliderAsync();
    }

    private async Task GoToEndAsync()
    {
        SetPreviewVirtualSecondsSilently(PreviewVirtualMaximum);
        await CommitPreviewSliderAsync();
    }

    private async Task StepFramesAsync(int frameDelta)
    {
        var frameRate = Math.Max(1d, Item.MediaInfo?.FrameRate ?? 25d);
        var stepSeconds = frameDelta / frameRate;
        SetPreviewVirtualSecondsSilently(Math.Clamp(PreviewVirtualSeconds + stepSeconds, 0, PreviewVirtualMaximum));
        await CommitPreviewSliderAsync();
    }

    private bool CanStartPlayback() => !IsPlaying && PreviewVirtualMaximum > 0 && !_previewBusy;

    private bool CanPausePlayback() => IsPlaying;

    private void SelectMode(string? mode)
    {
        if (string.IsNullOrWhiteSpace(mode))
        {
            return;
        }

        ActiveMode = mode;
        EditorHint = $"Editor mode aktivan: {mode}.";
    }

    private void SelectWorkspaceDock(string? dock)
    {
        if (string.IsNullOrWhiteSpace(dock))
        {
            return;
        }

        ActiveWorkspaceDock = dock;
        EditorHint = $"Workspace panel aktivan: {dock}.";
    }

    private void SelectMonitorTab(string? tab)
    {
        if (string.IsNullOrWhiteSpace(tab))
        {
            return;
        }

        ActiveMonitorTab = tab;
        EditorHint = $"{tab} monitor je aktivan.";
    }

    private void SelectInspectorTab(string? tab)
    {
        if (string.IsNullOrWhiteSpace(tab))
        {
            return;
        }

        ActiveInspectorTab = tab;
        EditorHint = $"Inspector tab aktivan: {tab}.";
    }

    private void SelectTool(string? tool)
    {
        if (string.IsNullOrWhiteSpace(tool))
        {
            return;
        }

        ActiveTool = tool;
        EditorHint = $"Aktivna alatka: {tool}.";
    }

    private void SelectZoomPreset(string? preset)
    {
        if (string.IsNullOrWhiteSpace(preset))
        {
            return;
        }

        ActiveZoomPreset = preset;
        RefreshState();
        EditorHint = $"Timeline zoom preset aktivan: {preset}.";
    }

    private void SelectBottomDock(string? dock)
    {
        if (string.IsNullOrWhiteSpace(dock))
        {
            return;
        }

        ActiveBottomDock = dock;
        EditorHint = $"Donji dock aktivan: {dock}.";
    }

    private void SelectLaneTarget(string? lane)
    {
        if (string.IsNullOrWhiteSpace(lane))
        {
            return;
        }

        ActiveLaneTarget = lane;
        EditorHint = $"Lane target aktivan: {lane}.";
    }

    private void ToggleSnap()
    {
        IsSnapEnabled = !IsSnapEnabled;
        EditorHint = IsSnapEnabled
            ? "Timeline snap je ukljucen."
            : "Timeline snap je iskljucen.";
    }

    private void ToggleLinkedSelection()
    {
        IsLinkedSelectionEnabled = !IsLinkedSelectionEnabled;
        EditorHint = IsLinkedSelectionEnabled
            ? "Linked selection je ukljucen."
            : "Linked selection je iskljucen.";
    }

    private void ToggleLoopPlayback()
    {
        IsLoopPlaybackEnabled = !IsLoopPlaybackEnabled;
        EditorHint = IsLoopPlaybackEnabled
            ? "Loop playback je ukljucen."
            : "Loop playback je iskljucen.";
    }

    private void ToggleTrackLock()
    {
        IsTrackLocked = !IsTrackLocked;
        EditorHint = IsTrackLocked ? "V1 track je zakljucan." : "V1 track je otkljucan.";
    }

    private void ToggleTrackMute()
    {
        IsTrackMuted = !IsTrackMuted;
        EditorHint = IsTrackMuted ? "V1 track je mutiran." : "V1 track je vracen sa mute.";
    }

    private void ToggleTrackSolo()
    {
        IsTrackSolo = !IsTrackSolo;
        EditorHint = IsTrackSolo ? "V1 track je u solo rezimu." : "V1 track je izasao iz solo rezima.";
    }

    private void StartPlayback()
    {
        if (IsPlaying || _previewBusy || !EnsurePlaybackReady())
        {
            return;
        }

        if (Item.MediaInfo is null || !File.Exists(Item.MediaInfo.SourcePath))
        {
            EditorHint = "Ulazni fajl nije dostupan za playback.";
            return;
        }

        EnsurePlaybackMediaLoaded();
        if (_playbackMediaPlayer?.Media is null)
        {
            EditorHint = "Playback media nije pripremljen.";
            return;
        }

        AttachPlaybackSurface();
        var sourceSeconds = TimelineNavigationService.MapVirtualToSource(Timeline, PreviewVirtualSeconds, Item.MediaInfo.DurationSeconds);
        _lastRequestedSourceSeconds = sourceSeconds;
        _pendingPlaybackSeekMilliseconds = (long)Math.Round(sourceSeconds * 1000d);
        _awaitingPlaybackFrame = true;
        _unmuteWhenPlaybackFrameArrives = true;
        _playbackMediaPlayer.Mute = true;
        _playbackMediaPlayer.Play();
        if (_pendingPlaybackSeekMilliseconds is { } playbackStartMs)
        {
            _playbackMediaPlayer.Time = playbackStartMs;
            _pendingPlaybackSeekMilliseconds = null;
        }

        IsPlaying = true;
        IsVideoPlaybackVisible = false;
        IsPreviewImageVisible = true;
        _playbackTimer.Start();
        EditorHint = "Pokrecem reprodukciju iz trenutno izabranog mesta...";
    }

    private void PausePlayback()
    {
        PausePlaybackCore(loadPreviewAfterPause: true, $"Playback pauziran | virtual {PreviewVirtualTimeText} | source {PreviewSourceTimeText}");
    }

    public void BeginManualPreviewNavigation()
    {
        PausePlaybackCore(loadPreviewAfterPause: true, "Pomeraj timeline za precizan trim frame.");
    }

    private void SetInPointFromCurrent() => InPointText = PreviewSourceTimeText;

    private void SetOutPointFromCurrent() => OutPointText = PreviewSourceTimeText;

    private async Task RefreshStateAndPreviewAsync()
    {
        if (IsPlaying)
        {
            PausePlaybackCore(loadPreviewAfterPause: false, "Prelazim na preview posle izmene timeline/crop stanja.");
        }

        RefreshState();
        SetPreviewVirtualSecondsSilently(Math.Clamp(PreviewVirtualSeconds, 0, PreviewVirtualMaximum));
        await LoadPreviewAsync();
    }

    private async Task ApplyTimelineMutationAsync(Func<TimelineProject, TimelineProject> mutation, string? refreshHint)
    {
        var previous = Timeline;
        var updated = mutation(previous);
        if (ReferenceEquals(previous, updated) || AreTimelineProjectsEquivalent(previous, updated))
        {
            return;
        }

        _undoStack.Push(previous);
        _redoStack.Clear();
        Timeline = updated;
        await RefreshStateAndPreviewAsync();
        if (!string.IsNullOrWhiteSpace(refreshHint))
        {
            EditorHint = refreshHint;
        }
    }

    private static bool AreTimelineProjectsEquivalent(TimelineProject left, TimelineProject right)
    {
        if (!string.Equals(left.SourcePath, right.SourcePath, StringComparison.OrdinalIgnoreCase)
            || left.Segments.Count != right.Segments.Count)
        {
            return false;
        }

        for (var i = 0; i < left.Segments.Count; i++)
        {
            var a = left.Segments[i];
            var b = right.Segments[i];
            if (a.Id != b.Id
                || a.Kind != b.Kind
                || Math.Abs(a.TimelineStartSeconds - b.TimelineStartSeconds) > 0.0001d
                || Math.Abs(a.SourceStartSeconds - b.SourceStartSeconds) > 0.0001d
                || Math.Abs(a.SourceEndSeconds - b.SourceEndSeconds) > 0.0001d)
            {
                return false;
            }
        }

        return true;
    }

    public async Task PrepareForDisplayAsync()
    {
        if (_disposed || IsPlaying || PreviewBitmap is not null)
        {
            return;
        }

        await LoadPreviewAsync();
    }

    private void RefreshState()
    {
        var selectedId = SelectedSegment?.Id;
        Segments.Clear();
        foreach (var segment in Timeline.Segments)
        {
            Segments.Add(segment);
        }

        var selectedBlockId = TimelineBlocks.FirstOrDefault(block => block.IsSelected)?.SegmentId ?? selectedId;
        TimelineBlocks.Clear();
        foreach (var block in TimelineStripService.BuildBlocks(Timeline, TimelinePreferredWidth))
        {
            TimelineBlocks.Add(new TimelineBlockItemViewModel
            {
                SegmentId = block.SegmentId,
                Kind = block.Kind,
                TimelineStartSeconds = block.TimelineStartSeconds,
                WidthPixels = block.WidthPixels,
                Label = block.Label,
                Summary = block.Summary,
                IsSelected = block.SegmentId == selectedBlockId
            });
        }

        SelectedSegment = Segments.FirstOrDefault(segment => segment.Id == selectedId) ?? Segments.FirstOrDefault();
        var keepDuration = TimelineEditorService.GetKeptDurationSeconds(Timeline);
        PreviewVirtualMaximum = Math.Max(0, TimelineNavigationService.GetVirtualDuration(Timeline, Item.MediaInfo?.DurationSeconds ?? 0));
        TimelineSummary = $"Keep duration: {TimelineEditorService.FormatSeconds(keepDuration)} | Segments: {Timeline.Segments.Count}";
        OnPropertyChanged(nameof(PreviewDurationText));
        UpdatePreviewTimeTexts();
        UpdateSelectedClipSummary();
    }

    private void NotifyEditorChromeStateChanged()
    {
        OnPropertyChanged(nameof(IsCutModeActive));
        OnPropertyChanged(nameof(IsEditModeActive));
        OnPropertyChanged(nameof(IsColorModeActive));
        OnPropertyChanged(nameof(IsDeliverModeActive));
        OnPropertyChanged(nameof(IsMediaPoolActive));
        OnPropertyChanged(nameof(IsEffectsLibraryActive));
        OnPropertyChanged(nameof(IsEditIndexActive));
        OnPropertyChanged(nameof(IsMixerActive));
        OnPropertyChanged(nameof(IsSourceMonitorActive));
        OnPropertyChanged(nameof(IsProgramMonitorActive));
        OnPropertyChanged(nameof(IsVideoInspectorActive));
        OnPropertyChanged(nameof(IsAudioInspectorActive));
        OnPropertyChanged(nameof(IsEffectsInspectorActive));
        OnPropertyChanged(nameof(IsSelectToolActive));
        OnPropertyChanged(nameof(IsBladeToolActive));
        OnPropertyChanged(nameof(IsSlipToolActive));
        OnPropertyChanged(nameof(IsRollToolActive));
        OnPropertyChanged(nameof(IsZoom1sActive));
        OnPropertyChanged(nameof(IsZoom5sActive));
        OnPropertyChanged(nameof(IsZoom10sActive));
        OnPropertyChanged(nameof(IsZoomFullActive));
        OnPropertyChanged(nameof(IsTimelineBottomDockActive));
        OnPropertyChanged(nameof(IsMixerBottomDockActive));
        OnPropertyChanged(nameof(IsMetadataBottomDockActive));
        OnPropertyChanged(nameof(IsMarkersBottomDockActive));
        OnPropertyChanged(nameof(IsScopesBottomDockActive));
        OnPropertyChanged(nameof(IsV1LaneTargetActive));
        OnPropertyChanged(nameof(IsV2LaneTargetActive));
        OnPropertyChanged(nameof(IsA1LaneTargetActive));
        OnPropertyChanged(nameof(IsA2LaneTargetActive));
        OnPropertyChanged(nameof(SnapStatusText));
        OnPropertyChanged(nameof(IsTrackLockActive));
        OnPropertyChanged(nameof(IsTrackMuteActive));
        OnPropertyChanged(nameof(IsTrackSoloActive));
        OnPropertyChanged(nameof(TimelineRulerLeftLabel));
        OnPropertyChanged(nameof(TimelineRulerCenterLabel));
        OnPropertyChanged(nameof(TimelineRulerRightLabel));
        OnPropertyChanged(nameof(TimelineZoomSummary));
    }

    private void SelectTimelineBlock(TimelineBlockItemViewModel? block, bool syncPlayhead = true)
    {
        if (block is null)
        {
            return;
        }

        var segment = Segments.FirstOrDefault(candidate => candidate.Id == block.SegmentId);
        if (segment is null)
        {
            return;
        }

        SelectedSegment = segment;
        EditorHint = $"{block.Label} segment selektovan | {block.Summary}";

        if (!syncPlayhead)
        {
            return;
        }

        SetPreviewVirtualSecondsSilently(Math.Clamp(segment.TimelineStartSeconds, 0, PreviewVirtualMaximum));
        _ = CommitPreviewSliderAsync();
    }

    private async Task HandleTimelineBlockActionAsync(TimelineBlockItemViewModel? block)
    {
        if (block is null)
        {
            return;
        }

        if (string.Equals(ActiveTool, "Blade", StringComparison.Ordinal))
        {
            SelectTimelineBlock(block, syncPlayhead: false);
            await SplitAtPlayheadAsync();
            return;
        }

        SelectTimelineBlock(block);
    }

    private double GetTimelineRulerCenterSeconds() => ActiveZoomPreset switch
    {
        "1s" => 1d,
        "5s" => 5d,
        "10s" => 10d,
        _ => Math.Max(0d, (Item.MediaInfo?.DurationSeconds ?? 0d) / 2d)
    };

    private double GetTimelineRulerRightSeconds() => ActiveZoomPreset switch
    {
        "1s" => 2d,
        "5s" => 10d,
        "10s" => 20d,
        _ => Math.Max(0d, Item.MediaInfo?.DurationSeconds ?? 0d)
    };

    private static string FormatTimelineRulerSeconds(double seconds) => TimelineEditorService.FormatSeconds(Math.Max(0d, seconds));

    private async Task LoadPreviewAsync()
    {
        if (Item.MediaInfo is null)
        {
            EditorHint = "Media info nije dostupan za preview.";
            return;
        }

        if (string.IsNullOrWhiteSpace(_ffmpegPath))
        {
            EditorHint = "ffmpeg nije dostupan, pa preview frame jos ne moze da se renderuje.";
            return;
        }

        if (_previewBusy)
        {
            _previewRefreshQueued = true;
            return;
        }

        _previewCts?.Cancel();
        _previewCts = new CancellationTokenSource();
        var token = _previewCts.Token;
        var sourceSeconds = TimelineNavigationService.MapVirtualToSource(Timeline, PreviewVirtualSeconds, Item.MediaInfo.DurationSeconds);

        try
        {
            _previewBusy = true;
            IsPreviewLoading = true;
            IsPreviewImageVisible = true;
            IsVideoPlaybackVisible = false;
            PlayCommand.NotifyCanExecuteChanged();
            var previewPath = await _previewFrameService.RenderPreviewAsync(_ffmpegPath, Item.MediaInfo, sourceSeconds, BuildTransformSettings(), token);
            if (token.IsCancellationRequested)
            {
                return;
            }

            if (string.IsNullOrWhiteSpace(previewPath) || !File.Exists(previewPath))
            {
                await RunOnUiThreadAsync(() =>
                {
                    var previous = PreviewBitmap;
                    PreviewBitmap = null;
                    previous?.Dispose();
                });
                EditorHint = "Preview frame nije renderovan. Proveri ffmpeg putanju i da li je ulazni fajl citljiv.";
                return;
            }

            await using var stream = File.OpenRead(previewPath);
            var bitmap = new Bitmap(stream);
            await RunOnUiThreadAsync(() =>
            {
                var previous = PreviewBitmap;
                PreviewBitmap = bitmap;
                previous?.Dispose();
            });
        }
        catch (OperationCanceledException)
        {
        }
        catch (Exception ex)
        {
            await RunOnUiThreadAsync(() =>
            {
                var previous = PreviewBitmap;
                PreviewBitmap = null;
                previous?.Dispose();
            });
            EditorHint = $"Preview nije uspeo: {ex.Message}";
        }
        finally
        {
            _previewBusy = false;
            IsPreviewLoading = false;
            PlayCommand.NotifyCanExecuteChanged();
            var rerunPreview = _previewRefreshQueued && !_disposed && !IsPlaying;
            _previewRefreshQueued = false;
            if (rerunPreview)
            {
                _ = LoadPreviewAsync();
            }
        }
    }

    private async Task DetectCropAsync()
    {
        if (Item.MediaInfo is null || string.IsNullOrWhiteSpace(_ffmpegPath))
        {
            EditorHint = "Crop detect trazi media info i ffmpeg.";
            return;
        }

        try
        {
            EditorHint = "Crop detect radi...";
            var detected = await _cropDetectService.DetectAsync(_ffmpegPath, Item.MediaInfo);
            if (detected is null)
            {
                EditorHint = "Crop detect nije nasao pouzdan crop za ovaj fajl.";
                return;
            }

            CropLeft = detected.Left;
            CropTop = detected.Top;
            CropRight = detected.Right;
            CropBottom = detected.Bottom;
            EditorHint = $"Crop detect: L{CropLeft} T{CropTop} R{CropRight} B{CropBottom}";
            await LoadPreviewAsync();
        }
        catch (Exception ex)
        {
            EditorHint = $"Crop detect nije uspeo: {ex.Message}";
        }
    }

    private async Task ClearCropAsync()
    {
        CropLeft = 0;
        CropTop = 0;
        CropRight = 0;
        CropBottom = 0;
        EditorHint = "Crop je ociscen.";
        await LoadPreviewAsync();
    }

    private void UpdatePreviewTimeTexts()
    {
        if (Item.MediaInfo is null)
        {
            PreviewVirtualTimeText = "00:00:00.00";
            PreviewSourceTimeText = "00:00:00.00";
            return;
        }

        PreviewVirtualTimeText = TimelineEditorService.FormatSeconds(PreviewVirtualSeconds);
        var sourceSeconds = TimelineNavigationService.MapVirtualToSource(Timeline, PreviewVirtualSeconds, Item.MediaInfo.DurationSeconds);
        PreviewSourceTimeText = TimelineEditorService.FormatSeconds(sourceSeconds);
    }

    public async Task CommitPreviewSliderAsync()
    {
        if (IsPlaying && _playbackMediaPlayer is not null && Item.MediaInfo is not null)
        {
            var sourceSeconds = TimelineNavigationService.MapVirtualToSource(Timeline, PreviewVirtualSeconds, Item.MediaInfo.DurationSeconds);
            _lastRequestedSourceSeconds = sourceSeconds;
            _pendingPlaybackSeekMilliseconds = (long)Math.Round(sourceSeconds * 1000d);
            _awaitingPlaybackFrame = true;
            _playbackMediaPlayer.Time = _pendingPlaybackSeekMilliseconds.Value;
            _pendingPlaybackSeekMilliseconds = null;
            UpdatePreviewTimeTexts();
            return;
        }

        await LoadPreviewAsync();
    }

    private void PlaybackTimerOnTick(object? sender, EventArgs e)
    {
        if (!IsPlaying || _playbackMediaPlayer is null || Item.MediaInfo is null)
        {
            return;
        }

        if (_pendingPlaybackSeekMilliseconds is { } pendingSeek)
        {
            _playbackMediaPlayer.Time = pendingSeek;
            _pendingPlaybackSeekMilliseconds = null;
            return;
        }

        var sourceSeconds = Math.Max(0, _playbackMediaPlayer.Time / 1000d);
        if (_awaitingPlaybackFrame)
        {
            var acceptableDrift = _lastRequestedSourceSeconds <= 0.01d ? 0.15d : 0.35d;
            if (Math.Abs(sourceSeconds - _lastRequestedSourceSeconds) > acceptableDrift)
            {
                return;
            }

            _awaitingPlaybackFrame = false;
            IsVideoPlaybackVisible = true;
            IsPreviewImageVisible = false;
            if (_unmuteWhenPlaybackFrameArrives)
            {
                _playbackMediaPlayer.Mute = false;
                _unmuteWhenPlaybackFrameArrives = false;
            }
        }

        if (!TimelineNavigationService.TryMapSourceToVirtual(Timeline, sourceSeconds, Item.MediaInfo.DurationSeconds, out var virtualSeconds))
        {
            var nextSource = TimelineNavigationService.GetNextKeepSourceStart(Timeline, sourceSeconds, Item.MediaInfo.DurationSeconds);
            if (nextSource is null || nextSource.Value >= Item.MediaInfo.DurationSeconds)
            {
                PausePlayback();
                return;
            }

            _playbackMediaPlayer.Time = (long)Math.Round(nextSource.Value * 1000d);
            if (TimelineNavigationService.TryMapSourceToVirtual(Timeline, nextSource.Value, Item.MediaInfo.DurationSeconds, out var nextVirtual))
            {
                PreviewVirtualSeconds = Math.Clamp(nextVirtual, 0, PreviewVirtualMaximum);
            }

            return;
        }

        PreviewVirtualSeconds = Math.Clamp(virtualSeconds, 0, PreviewVirtualMaximum);
        if (PreviewVirtualSeconds >= PreviewVirtualMaximum)
        {
            PausePlayback();
        }
    }

    private void InitializePlaybackEngine()
    {
        try
        {
            LibVLCSharp.Shared.Core.Initialize();
            _libVlc = new LibVLC("--quiet");
            _playbackMediaPlayer = new MediaPlayer(_libVlc)
            {
                EnableHardwareDecoding = true
            };
            EnsurePlaybackMediaLoaded();
        }
        catch (Exception ex)
        {
            _libVlc?.Dispose();
            _playbackMediaPlayer?.Dispose();
            _libVlc = null;
            _playbackMediaPlayer = null;
            PlaybackMediaPlayerBinding = null;
            EditorHint = $"Playback engine nije dostupan: {ex.Message}";
        }
    }

    private bool EnsurePlaybackReady()
    {
        if (_playbackMediaPlayer is not null && _libVlc is not null)
        {
            return true;
        }

        InitializePlaybackEngine();
        return _playbackMediaPlayer is not null && _libVlc is not null;
    }

    private void EnsurePlaybackMediaLoaded()
    {
        if (_playbackMedia is not null || _playbackMediaPlayer is null || _libVlc is null || Item.MediaInfo is null)
        {
            return;
        }

        if (!File.Exists(Item.MediaInfo.SourcePath))
        {
            return;
        }

        var media = new Media(_libVlc, Item.MediaInfo.SourcePath, FromType.FromPath);
        if (ShouldForceAvformatDemux(Item.MediaInfo))
        {
            media.AddOption(":demux=avformat");
        }

        _playbackMedia = media;
        _playbackMediaPlayer.Media = _playbackMedia;
    }

    private static bool ShouldForceAvformatDemux(MediaInfo mediaInfo)
    {
        if (string.Equals(mediaInfo.Container, "avi", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        return string.Equals(mediaInfo.VideoCodec, "dvvideo", StringComparison.OrdinalIgnoreCase);
    }

    private void SchedulePreviewRefresh()
    {
        _previewDebounceCts?.Cancel();
        _previewDebounceCts?.Dispose();
        _previewDebounceCts = new CancellationTokenSource();
        var token = _previewDebounceCts.Token;
        _ = DebouncedPreviewRefreshAsync(token);
    }

    private async Task DebouncedPreviewRefreshAsync(CancellationToken cancellationToken)
    {
        try
        {
            await Task.Delay(60, cancellationToken);
            if (cancellationToken.IsCancellationRequested || IsPlaying || _disposed)
            {
                return;
            }

            await LoadPreviewAsync();
        }
        catch (OperationCanceledException)
        {
        }
    }

    private ItemTransformSettings BuildTransformSettings()
    {
        return new ItemTransformSettings
        {
            AspectMode = SelectedAspectMode,
            Crop = new CropSettings
            {
                Left = Math.Max(0, CropLeft),
                Top = Math.Max(0, CropTop),
                Right = Math.Max(0, CropRight),
                Bottom = Math.Max(0, CropBottom)
            }
        };
    }

    private static bool TryParseTime(string text, out double seconds)
    {
        if (TimeSpan.TryParse(text, out var value))
        {
            seconds = value.TotalSeconds;
            return true;
        }

        seconds = 0;
        return false;
    }

    private static IReadOnlyList<string> AspectModesService() => CoreServices.AspectModes.All;

    private static Task RunOnUiThreadAsync(Action action)
    {
        if (Application.Current is null || Dispatcher.UIThread.CheckAccess())
        {
            action();
            return Task.CompletedTask;
        }

        return Dispatcher.UIThread.InvokeAsync(action).GetTask();
    }

    private void SyncSelectedTimelineBlock()
    {
        var selectedId = SelectedSegment?.Id;
        foreach (var block in TimelineBlocks)
        {
            block.IsSelected = block.SegmentId == selectedId;
        }
    }

    private void UpdateSelectedClipSummary()
    {
        if (SelectedSegment is null)
        {
            SelectedClipSummary = "Nijedan segment nije selektovan.";
            return;
        }

        SelectedClipSummary =
            $"{SelectedSegment.Kind.ToString().ToUpperInvariant()} | " +
            $"{TimelineEditorService.FormatSeconds(SelectedSegment.SourceStartSeconds)} -> " +
            $"{TimelineEditorService.FormatSeconds(SelectedSegment.SourceEndSeconds)}";
    }

    private void SetPreviewVirtualSecondsSilently(double value)
    {
        _suppressPreviewAutoRefresh = true;
        try
        {
            PreviewVirtualSeconds = value;
        }
        finally
        {
            _suppressPreviewAutoRefresh = false;
        }
    }

    private void PausePlaybackCore(bool loadPreviewAfterPause, string hint)
    {
        if (!IsPlaying && !IsVideoPlaybackVisible)
        {
            EditorHint = hint;
            return;
        }

        _playbackTimer.Stop();
        _playbackMediaPlayer?.Pause();
        IsPlaying = false;
        IsVideoPlaybackVisible = false;
        IsPreviewImageVisible = true;
        DetachPlaybackSurface();
        _awaitingPlaybackFrame = false;
        _unmuteWhenPlaybackFrameArrives = false;
        _pendingPlaybackSeekMilliseconds = null;
        if (_playbackMediaPlayer is not null)
        {
            _playbackMediaPlayer.Mute = false;
        }

        EditorHint = hint;
        if (loadPreviewAfterPause)
        {
            _ = LoadPreviewAsync();
        }
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        _previewCts?.Cancel();
        _previewCts?.Dispose();
        _previewDebounceCts?.Cancel();
        _previewDebounceCts?.Dispose();
        _playbackTimer.Stop();
        _playbackTimer.Tick -= PlaybackTimerOnTick;
        DetachPlaybackSurface();
        _playbackMediaPlayer?.Stop();
        _playbackMedia?.Dispose();
        _playbackMediaPlayer?.Dispose();
        _libVlc?.Dispose();
        PreviewBitmap?.Dispose();
    }

    private void AttachPlaybackSurface()
    {
        if (_playbackMediaPlayer is not null && !ReferenceEquals(PlaybackMediaPlayerBinding, _playbackMediaPlayer))
        {
            PlaybackMediaPlayerBinding = _playbackMediaPlayer;
        }
    }

    private void DetachPlaybackSurface()
    {
        if (PlaybackMediaPlayerBinding is not null)
        {
            PlaybackMediaPlayerBinding = null;
        }
    }
}
