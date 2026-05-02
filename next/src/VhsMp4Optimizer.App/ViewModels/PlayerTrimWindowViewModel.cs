using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Avalonia.Media.Imaging;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Core.Services;
using VhsMp4Optimizer.Infrastructure.Services;
using CoreServices = VhsMp4Optimizer.Core.Services;

namespace VhsMp4Optimizer.App.ViewModels;

public partial class PlayerTrimWindowViewModel : ViewModelBase
{
    private readonly Action<TimelineProject, ItemTransformSettings?> _saveAction;
    private readonly PreviewFrameService _previewFrameService = new();
    private readonly CropDetectService _cropDetectService = new();
    private readonly string? _ffmpegPath;
    private CancellationTokenSource? _previewCts;

    public PlayerTrimWindowViewModel(QueueItemSummary item, string? ffmpegPath, Action<TimelineProject, ItemTransformSettings?> saveAction)
    {
        ArgumentNullException.ThrowIfNull(item.MediaInfo);

        _saveAction = saveAction;
        _ffmpegPath = ffmpegPath;
        Item = item;
        Timeline = item.TimelineProject ?? TimelineEditorService.CreateInitial(item.MediaInfo);
        Segments = new ObservableCollection<TimelineSegment>(Timeline.Segments);
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
        DeleteSegmentCommand = new AsyncRelayCommand(DeleteSegmentAsync, CanModifySelectedSegment);
        RippleDeleteCommand = new AsyncRelayCommand(RippleDeleteSegmentAsync, CanModifySelectedSegment);
        MoveLeftCommand = new AsyncRelayCommand(MoveLeftAsync, CanModifySelectedSegment);
        MoveRightCommand = new AsyncRelayCommand(MoveRightAsync, CanModifySelectedSegment);
        SaveToQueueCommand = new RelayCommand(SaveToQueue);

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

        RefreshState();
        _ = LoadPreviewAsync();
    }

    public QueueItemSummary Item { get; }

    public ObservableCollection<TimelineSegment> Segments { get; }

    public ObservableCollection<string> AspectModes { get; }

    public IAsyncRelayCommand CutSegmentCommand { get; }

    public IAsyncRelayCommand DeleteSegmentCommand { get; }

    public IAsyncRelayCommand RippleDeleteCommand { get; }

    public IAsyncRelayCommand MoveLeftCommand { get; }

    public IAsyncRelayCommand MoveRightCommand { get; }

    public IRelayCommand SaveToQueueCommand { get; }

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

    partial void OnSelectedSegmentChanged(TimelineSegment? value)
    {
        DeleteSegmentCommand.NotifyCanExecuteChanged();
        RippleDeleteCommand.NotifyCanExecuteChanged();
        MoveLeftCommand.NotifyCanExecuteChanged();
        MoveRightCommand.NotifyCanExecuteChanged();
    }

    partial void OnPreviewVirtualSecondsChanged(double value) => UpdatePreviewTimeTexts();

    public Task CommitPreviewSliderAsync() => LoadPreviewAsync();

    private async Task ApplyCutSegmentAsync()
    {
        if (!TryParseTime(InPointText, out var inSeconds) || !TryParseTime(OutPointText, out var outSeconds))
        {
            EditorHint = "IN/OUT vreme nije u dobrom formatu. Koristi npr. 00:10:05.25";
            return;
        }

        Timeline = TimelineEditorService.CutSegment(Timeline, inSeconds, outSeconds);
        await RefreshStateAndPreviewAsync().ConfigureAwait(false);
    }

    private async Task DeleteSegmentAsync()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        Timeline = TimelineEditorService.DeleteSegment(Timeline, SelectedSegment.Id);
        await RefreshStateAndPreviewAsync().ConfigureAwait(false);
    }

    private async Task RippleDeleteSegmentAsync()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        Timeline = TimelineEditorService.RippleDeleteSegment(Timeline, SelectedSegment.Id);
        await RefreshStateAndPreviewAsync().ConfigureAwait(false);
    }

    private async Task MoveLeftAsync()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        Timeline = TimelineEditorService.MoveSegmentLeft(Timeline, SelectedSegment.Id);
        await RefreshStateAndPreviewAsync().ConfigureAwait(false);
    }

    private async Task MoveRightAsync()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        Timeline = TimelineEditorService.MoveSegmentRight(Timeline, SelectedSegment.Id);
        await RefreshStateAndPreviewAsync().ConfigureAwait(false);
    }

    private void SaveToQueue() => _saveAction(Timeline, BuildTransformSettings());

    private bool CanModifySelectedSegment() => SelectedSegment is not null;

    private async Task GoToStartAsync()
    {
        PreviewVirtualSeconds = 0;
        await LoadPreviewAsync().ConfigureAwait(false);
    }

    private async Task GoToEndAsync()
    {
        PreviewVirtualSeconds = PreviewVirtualMaximum;
        await LoadPreviewAsync().ConfigureAwait(false);
    }

    private async Task StepFramesAsync(int frameDelta)
    {
        var frameRate = Math.Max(1d, Item.MediaInfo?.FrameRate ?? 25d);
        var stepSeconds = frameDelta / frameRate;
        PreviewVirtualSeconds = Math.Clamp(PreviewVirtualSeconds + stepSeconds, 0, PreviewVirtualMaximum);
        await LoadPreviewAsync().ConfigureAwait(false);
    }

    private void SetInPointFromCurrent() => InPointText = PreviewSourceTimeText;

    private void SetOutPointFromCurrent() => OutPointText = PreviewSourceTimeText;

    private async Task RefreshStateAndPreviewAsync()
    {
        RefreshState();
        PreviewVirtualSeconds = Math.Clamp(PreviewVirtualSeconds, 0, PreviewVirtualMaximum);
        await LoadPreviewAsync().ConfigureAwait(false);
    }

    private void RefreshState()
    {
        var selectedId = SelectedSegment?.Id;
        Segments.Clear();
        foreach (var segment in Timeline.Segments)
        {
            Segments.Add(segment);
        }

        SelectedSegment = Segments.FirstOrDefault(segment => segment.Id == selectedId) ?? Segments.FirstOrDefault();
        var keepDuration = TimelineEditorService.GetKeptDurationSeconds(Timeline);
        PreviewVirtualMaximum = Math.Max(0, TimelineNavigationService.GetVirtualDuration(Timeline, Item.MediaInfo?.DurationSeconds ?? 0));
        TimelineSummary = $"Keep duration: {TimelineEditorService.FormatSeconds(keepDuration)} | Segments: {Timeline.Segments.Count}";
        UpdatePreviewTimeTexts();
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

        _previewCts?.Cancel();
        _previewCts = new CancellationTokenSource();
        var token = _previewCts.Token;
        var sourceSeconds = TimelineNavigationService.MapVirtualToSource(Timeline, PreviewVirtualSeconds, Item.MediaInfo.DurationSeconds);

        try
        {
            EditorHint = $"Preview: virtual {PreviewVirtualTimeText} | source {PreviewSourceTimeText}";
            var previewPath = await _previewFrameService.RenderPreviewAsync(_ffmpegPath, Item.MediaInfo, sourceSeconds, BuildTransformSettings(), token).ConfigureAwait(false);
            if (token.IsCancellationRequested || string.IsNullOrWhiteSpace(previewPath) || !File.Exists(previewPath))
            {
                return;
            }

            await using var stream = File.OpenRead(previewPath);
            var bitmap = new Bitmap(stream);
            var previous = PreviewBitmap;
            PreviewBitmap = bitmap;
            previous?.Dispose();
            EditorHint = $"Preview spreman | virtual {PreviewVirtualTimeText} | source {PreviewSourceTimeText}";
        }
        catch (OperationCanceledException)
        {
        }
        catch (Exception ex)
        {
            EditorHint = $"Preview nije uspeo: {ex.Message}";
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
            var detected = await _cropDetectService.DetectAsync(_ffmpegPath, Item.MediaInfo).ConfigureAwait(false);
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
            await LoadPreviewAsync().ConfigureAwait(false);
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
        await LoadPreviewAsync().ConfigureAwait(false);
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
}
