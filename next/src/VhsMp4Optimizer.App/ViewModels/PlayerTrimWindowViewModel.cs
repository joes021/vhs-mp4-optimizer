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
        DeleteSegmentCommand = new AsyncRelayCommand(DeleteSegmentAsync, CanModifySelectedSegment);
        RippleDeleteCommand = new AsyncRelayCommand(RippleDeleteSegmentAsync, CanModifySelectedSegment);
        MoveLeftCommand = new AsyncRelayCommand(MoveLeftAsync, CanModifySelectedSegment);
        MoveRightCommand = new AsyncRelayCommand(MoveRightAsync, CanModifySelectedSegment);
        SaveToQueueCommand = new RelayCommand(SaveToQueue);
        SelectTimelineBlockCommand = new RelayCommand<TimelineBlockItemViewModel?>(SelectTimelineBlock);

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

    public IAsyncRelayCommand DeleteSegmentCommand { get; }

    public IAsyncRelayCommand RippleDeleteCommand { get; }

    public IAsyncRelayCommand MoveLeftCommand { get; }

    public IAsyncRelayCommand MoveRightCommand { get; }

    public IRelayCommand SaveToQueueCommand { get; }

    public IRelayCommand<TimelineBlockItemViewModel?> SelectTimelineBlockCommand { get; }

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

    [ObservableProperty]
    private MediaPlayer? _playbackMediaPlayerBinding;

    [ObservableProperty]
    private string _windowTitle = string.Empty;

    [ObservableProperty]
    private string _fileSummary = string.Empty;

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

    partial void OnSelectedSegmentChanged(TimelineSegment? value)
    {
        DeleteSegmentCommand.NotifyCanExecuteChanged();
        RippleDeleteCommand.NotifyCanExecuteChanged();
        MoveLeftCommand.NotifyCanExecuteChanged();
        MoveRightCommand.NotifyCanExecuteChanged();
        ToggleKeepCutCommand.NotifyCanExecuteChanged();
        TrimSelectedToInOutCommand.NotifyCanExecuteChanged();
        SyncSelectedTimelineBlock();
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

    private async Task ApplyCutSegmentAsync()
    {
        if (!TryParseTime(InPointText, out var inSeconds) || !TryParseTime(OutPointText, out var outSeconds))
        {
            EditorHint = "IN/OUT vreme nije u dobrom formatu. Koristi npr. 00:10:05.25";
            return;
        }

        Timeline = TimelineEditorService.CutSegment(Timeline, inSeconds, outSeconds);
        await RefreshStateAndPreviewAsync();
    }

    private async Task SplitAtPlayheadAsync()
    {
        Timeline = TimelineEditorService.SplitAtPlayhead(Timeline, PreviewVirtualSeconds);
        await RefreshStateAndPreviewAsync();
        EditorHint = $"Segment je podeljen na playhead-u | virtual {PreviewVirtualTimeText} | source {PreviewSourceTimeText}";
    }

    private async Task ToggleKeepCutAsync()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        Timeline = TimelineEditorService.ToggleSegmentKind(Timeline, SelectedSegment.Id);
        await RefreshStateAndPreviewAsync();
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

        Timeline = TimelineEditorService.TrimSegmentToRange(Timeline, SelectedSegment.Id, inSeconds, outSeconds);
        await RefreshStateAndPreviewAsync();
        EditorHint = $"Izabrani segment je skracen na {InPointText} -> {OutPointText}";
    }

    private async Task DeleteSegmentAsync()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        Timeline = TimelineEditorService.DeleteSegment(Timeline, SelectedSegment.Id);
        await RefreshStateAndPreviewAsync();
    }

    private async Task RippleDeleteSegmentAsync()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        Timeline = TimelineEditorService.RippleDeleteSegment(Timeline, SelectedSegment.Id);
        await RefreshStateAndPreviewAsync();
    }

    private async Task MoveLeftAsync()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        Timeline = TimelineEditorService.MoveSegmentLeft(Timeline, SelectedSegment.Id);
        await RefreshStateAndPreviewAsync();
    }

    private async Task MoveRightAsync()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        Timeline = TimelineEditorService.MoveSegmentRight(Timeline, SelectedSegment.Id);
        await RefreshStateAndPreviewAsync();
    }

    private void SaveToQueue() => _saveAction(Timeline, BuildTransformSettings());

    private bool CanModifySelectedSegment() => SelectedSegment is not null;

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
        foreach (var block in TimelineStripService.BuildBlocks(Timeline))
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
        UpdatePreviewTimeTexts();
    }

    private void SelectTimelineBlock(TimelineBlockItemViewModel? block)
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
        SetPreviewVirtualSecondsSilently(Math.Clamp(segment.TimelineStartSeconds, 0, PreviewVirtualMaximum));
        EditorHint = $"{block.Label} segment selektovan | {block.Summary}";
        _ = CommitPreviewSliderAsync();
    }

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
            PlaybackMediaPlayerBinding = _playbackMediaPlayer;
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
        _playbackMediaPlayer?.Stop();
        _playbackMedia?.Dispose();
        _playbackMediaPlayer?.Dispose();
        _libVlc?.Dispose();
        PreviewBitmap?.Dispose();
    }
}
