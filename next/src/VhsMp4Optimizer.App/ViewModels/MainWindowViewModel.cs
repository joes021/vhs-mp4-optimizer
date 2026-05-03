using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.App.Services;
using CoreServices = VhsMp4Optimizer.Core.Services;
using VhsMp4Optimizer.Infrastructure.Services;
using VhsMp4Optimizer.App.Models;

namespace VhsMp4Optimizer.App.ViewModels;

public partial class MainWindowViewModel : ViewModelBase
{
    private readonly ISourceScanService _sourceScanService;
    private readonly IConversionService _conversionService;
    private readonly IConversionReportService _conversionReportService;
    private readonly IExternalLauncher _externalLauncher;
    private readonly CopyOnlyMediaToolsService _copyOnlyMediaToolsService = new();
    private readonly QueueSnapshotService _queueSnapshotService = new();
    private IReadOnlyList<string>? _explicitSourcePaths;
    private bool _suppressSelectionReset;
    private bool _applyingPreset;
    private bool _isConverting;
    private bool _pauseRequested;
    private bool _isBatchPaused;
    private bool _isInitializing = true;
    private string? _lastConvertedOutputPath;
    private string? _lastBatchReportPath;

    public MainWindowViewModel(
        ISourceScanService? sourceScanService = null,
        IConversionService? conversionService = null,
        string? ffmpegPath = null,
        IExternalLauncher? launcher = null,
        IConversionReportService? reportService = null)
    {
        _sourceScanService = sourceScanService ?? new SourceScanService();
        _conversionService = conversionService ?? new FfmpegConversionService();
        _conversionReportService = reportService ?? new ConversionReportService();
        _externalLauncher = launcher ?? new ExternalLauncher();
        QueueItems = new ObservableCollection<QueueItemSummary>();
        ComparisonRows = new ObservableCollection<PropertyComparisonRow>(CoreServices.PropertyComparisonBuilder.Build(null));
        WorkflowPresets = new ObservableCollection<string>(CoreServices.WorkflowPresetService.Names);
        QualityModes = new ObservableCollection<string>(CoreServices.QualityModes.All);
        ScaleModes = new ObservableCollection<string>(CoreServices.ScaleModes.All);
        AspectModes = new ObservableCollection<string>(CoreServices.AspectModes.All);
        DeinterlaceModes = new ObservableCollection<string>(CoreServices.DeinterlaceModes.All);
        DenoiseModes = new ObservableCollection<string>(CoreServices.DenoiseModes.All);
        EncodeEngines = new ObservableCollection<string>(CoreServices.EncodeEngines.All);
        ScanFilesCommand = new AsyncRelayCommand(ScanFilesAsync, CanScanFiles);
        StartConversionCommand = new AsyncRelayCommand(StartConversionAsync, CanStartConversion);
        TestSampleCommand = new AsyncRelayCommand(TestSampleAsync, CanTestSample);
        OpenSampleCommand = new RelayCommand(OpenSample, CanOpenSample);
        OpenOutputCommand = new RelayCommand(OpenOutputFolder, CanOpenOutputFolder);
        OpenConvertedFileCommand = new RelayCommand(OpenConvertedFile, CanOpenConvertedFile);
        OpenReportCommand = new RelayCommand(OpenReport, CanOpenReport);
        SkipSelectedCommand = new RelayCommand(SkipSelected);
        RetryFailedCommand = new RelayCommand(RetryFailedItems);
        ClearCompletedCommand = new RelayCommand(ClearCompletedItems);
        SplitSelectedCopyCommand = new AsyncRelayCommand(SplitSelectedCopyAsync, CanSplitSelectedCopy);
        PauseResumeCommand = new AsyncRelayCommand(PauseResumeAsync, CanPauseOrResume);
        SaveQueueCommand = new AsyncRelayCommand<string>(SaveQueueAsync);
        LoadQueueCommand = new AsyncRelayCommand<string>(LoadQueueAsync);
        ResolvedFfmpegPath = ffmpegPath ?? FfmpegLocator.Resolve();

        if (!string.IsNullOrWhiteSpace(ResolvedFfmpegPath))
        {
            StatusMessage = $"FFmpeg je spreman: {ResolvedFfmpegPath}";
        }
        else
        {
            StatusMessage = "FFmpeg jos nije pronadjen. Izaberi ga iz Tools menija ili ga instaliraj.";
        }

        ApplyPreset(SelectedPreset);
        _isInitializing = false;
        RefreshCommandStates();
    }

    [ObservableProperty]
    private string _windowTitle = "VHS MP4 Optimizer Next";

    [ObservableProperty]
    private string _inputFolder = string.Empty;

    [ObservableProperty]
    private string _outputFolder = string.Empty;

    [ObservableProperty]
    private string _selectionHint = "Unesi putanju ili izaberi jedan fajl, vise fajlova ili ceo folder.";

    [ObservableProperty]
    private string _selectedPreset = "USB standard";

    [ObservableProperty]
    private string _qualityMode = CoreServices.QualityModes.TvSmart;

    [ObservableProperty]
    private string _scaleMode = CoreServices.ScaleModes.Pal576p;

    [ObservableProperty]
    private string _aspectMode = CoreServices.AspectModes.Auto;

    [ObservableProperty]
    private string _deinterlaceMode = CoreServices.DeinterlaceModes.Off;

    [ObservableProperty]
    private string _denoiseMode = CoreServices.DenoiseModes.Off;

    [ObservableProperty]
    private string _encodeEngine = CoreServices.EncodeEngines.Auto;

    [ObservableProperty]
    private bool _splitOutput;

    [ObservableProperty]
    private double _maxPartGb = 3.8;

    [ObservableProperty]
    private string _videoBitrate = "5000k";

    [ObservableProperty]
    private string _audioBitrate = "160k";

    [ObservableProperty]
    private string _sampleStartText = "00:00:00";

    [ObservableProperty]
    private string _sampleDurationText = "00:02:00";

    [ObservableProperty]
    private string _pauseResumeLabel = "Pause";

    [ObservableProperty]
    private string _statusMessage;

    [ObservableProperty]
    private string _progressMessage = "Nema aktivne obrade.";

    [ObservableProperty]
    private string _logMessage = "Spreman za scan, trim, sample i batch konverziju.";

    [ObservableProperty]
    private double _conversionProgressPercent;

    [ObservableProperty]
    private bool _isConversionProgressIndeterminate;

    [ObservableProperty]
    private string _currentConversionItemText = "Nema aktivne obrade.";

    [ObservableProperty]
    private string _conversionEtaText = "ETA: --";

    [ObservableProperty]
    private int _selectedBottomTabIndex;

    [ObservableProperty]
    private QueueItemSummary? _selectedQueueItem;

    [ObservableProperty]
    private string? _lastSamplePath;

    [ObservableProperty]
    private string? _resolvedFfmpegPath;

    public ObservableCollection<QueueItemSummary> QueueItems { get; }

    public ObservableCollection<PropertyComparisonRow> ComparisonRows { get; }

    public ObservableCollection<string> WorkflowPresets { get; }

    public ObservableCollection<string> QualityModes { get; }

    public ObservableCollection<string> ScaleModes { get; }

    public ObservableCollection<string> AspectModes { get; }

    public ObservableCollection<string> DeinterlaceModes { get; }

    public ObservableCollection<string> DenoiseModes { get; }

    public ObservableCollection<string> EncodeEngines { get; }

    public IAsyncRelayCommand ScanFilesCommand { get; }

    public IAsyncRelayCommand StartConversionCommand { get; }

    public IAsyncRelayCommand TestSampleCommand { get; }

    public IRelayCommand OpenSampleCommand { get; }

    public IRelayCommand OpenOutputCommand { get; }

    public IRelayCommand OpenConvertedFileCommand { get; }

    public IRelayCommand OpenReportCommand { get; }

    public IRelayCommand SkipSelectedCommand { get; }

    public IRelayCommand RetryFailedCommand { get; }

    public IRelayCommand ClearCompletedCommand { get; }

    public IAsyncRelayCommand SplitSelectedCopyCommand { get; }

    public IAsyncRelayCommand PauseResumeCommand { get; }

    public IAsyncRelayCommand<string> SaveQueueCommand { get; }

    public IAsyncRelayCommand<string> LoadQueueCommand { get; }

    partial void OnSelectedQueueItemChanged(QueueItemSummary? value)
    {
        if (_isInitializing)
        {
            return;
        }

        RefreshComparisonRows(value);
        OpenSampleCommand.NotifyCanExecuteChanged();
        SplitSelectedCopyCommand.NotifyCanExecuteChanged();
        TestSampleCommand.NotifyCanExecuteChanged();
        StartConversionCommand.NotifyCanExecuteChanged();
        OpenConvertedFileCommand.NotifyCanExecuteChanged();
        OpenReportCommand.NotifyCanExecuteChanged();
    }

    partial void OnInputFolderChanged(string value)
    {
        if (_isInitializing)
        {
            return;
        }

        if (_suppressSelectionReset)
        {
            return;
        }

        _explicitSourcePaths = null;
        SelectionHint = "Rucno uneta putanja: scan ide nad ovim input putem.";
        RefreshCommandStates();
    }

    partial void OnOutputFolderChanged(string value)
    {
        if (_isInitializing)
        {
            return;
        }

        OpenOutputCommand.NotifyCanExecuteChanged();
        RefreshCommandStates();
    }

    partial void OnQualityModeChanged(string value)
    {
        if (_isInitializing)
        {
            return;
        }

        RefreshPlannedOutput();
    }

    partial void OnScaleModeChanged(string value)
    {
        if (_isInitializing)
        {
            return;
        }

        RefreshPlannedOutput();
    }

    partial void OnAspectModeChanged(string value)
    {
        if (_isInitializing)
        {
            return;
        }

        RefreshPlannedOutput();
    }

    partial void OnDeinterlaceModeChanged(string value)
    {
        if (_isInitializing)
        {
            return;
        }

        RefreshPlannedOutput();
    }

    partial void OnDenoiseModeChanged(string value)
    {
        if (_isInitializing)
        {
            return;
        }

        RefreshPlannedOutput();
    }

    partial void OnEncodeEngineChanged(string value)
    {
        if (_isInitializing)
        {
            return;
        }

        RefreshPlannedOutput();
    }

    partial void OnVideoBitrateChanged(string value)
    {
        if (_isInitializing)
        {
            return;
        }

        RefreshPlannedOutput();
    }

    partial void OnAudioBitrateChanged(string value)
    {
        if (_isInitializing)
        {
            return;
        }

        RefreshPlannedOutput();
    }

    partial void OnSplitOutputChanged(bool value)
    {
        if (_isInitializing)
        {
            return;
        }

        RefreshPlannedOutput();
    }

    partial void OnMaxPartGbChanged(double value)
    {
        if (_isInitializing)
        {
            return;
        }

        RefreshPlannedOutput();
    }

    partial void OnLastSamplePathChanged(string? value)
    {
        if (_isInitializing)
        {
            return;
        }

        OpenSampleCommand.NotifyCanExecuteChanged();
    }

    partial void OnResolvedFfmpegPathChanged(string? value)
    {
        if (_isInitializing)
        {
            return;
        }

        RefreshCommandStates();
    }

    partial void OnSelectedPresetChanged(string value)
    {
        if (_isInitializing)
        {
            return;
        }

        if (_applyingPreset)
        {
            return;
        }

        ApplyPreset(value);
    }

    private Task ScanFilesAsync()
    {
        QueueItems.Clear();
        ComparisonRows.Clear();

        if (string.IsNullOrWhiteSpace(InputFolder))
        {
            StatusMessage = "Izaberi input folder ili jedan konkretan video fajl pa klikni Scan Files.";
            return Task.CompletedTask;
        }

        if (string.IsNullOrWhiteSpace(ResolvedFfmpegPath))
        {
            StatusMessage = "ffmpeg/ffprobe nisu pronadjeni. Novi sistem za sada trazi lokalni ffmpeg da bi skenirao media info.";
            return Task.CompletedTask;
        }

        var settings = BuildSettings();
        var outputDirectory = _sourceScanService.ResolveOutputDirectory(InputFolder, OutputFolder);
        OutputFolder = outputDirectory;
        var items = _sourceScanService.Scan(settings with { OutputDirectory = outputDirectory }, ResolvedFfmpegPath, _explicitSourcePaths);

        foreach (var item in items)
        {
            QueueItems.Add(item);
        }

        ApplyQueueZebra();

        SelectedQueueItem = QueueItems.FirstOrDefault();
        var explicitCount = _explicitSourcePaths?.Count ?? 0;
        ProgressMessage = explicitCount > 0
            ? $"Scan zavrsen. Pronadjeno: {QueueItems.Count} fajlova | eksplicitno izabrano: {explicitCount}"
            : $"Scan zavrsen. Pronadjeno: {QueueItems.Count} fajlova.";
        LogMessage = $"ffmpeg: {ResolvedFfmpegPath}{Environment.NewLine}Output: {outputDirectory}";
        StatusMessage = QueueItems.Count == 0
            ? "Nema podrzanih video fajlova za scan u zadatom input putu."
            : $"Scan Files: pronadjeno {QueueItems.Count} | {CoreServices.QueueWorkflowService.BuildSummary(QueueItems)}";
        RefreshCommandStates();
        return Task.CompletedTask;
    }

    private async Task StartConversionAsync()
    {
        if (_isConverting)
        {
            StatusMessage = "Batch je vec u toku.";
            return;
        }

        if (string.IsNullOrWhiteSpace(ResolvedFfmpegPath))
        {
            StatusMessage = "ffmpeg nije dostupan za Start Conversion.";
            return;
        }

        if (QueueItems.Count == 0)
        {
            StatusMessage = "Nema queue stavki za obradu.";
            return;
        }

        var ffmpegPath = ResolvedFfmpegPath!;
        var settings = BuildSettings();
        var items = QueueItems.ToList();
        var queuedItems = items.Where(CoreServices.QueueWorkflowService.ShouldConvert).ToList();
        if (queuedItems.Count == 0)
        {
            StatusMessage = "Nema queued stavki za obradu.";
            return;
        }

        var converted = 0;
        var failed = false;
        var failedCount = 0;
        var processedItems = new List<QueueItemSummary>();
        _isConverting = true;
        _isBatchPaused = false;
        _pauseRequested = false;
        PauseResumeLabel = "Pause";
        IsConversionProgressIndeterminate = true;
        ConversionProgressPercent = 0;
        CurrentConversionItemText = "Pripremam batch...";
        ConversionEtaText = "ETA: --";
        SelectedBottomTabIndex = 1;
        PauseResumeCommand.NotifyCanExecuteChanged();

        try
        {
            foreach (var item in queuedItems)
            {
                ReplaceItem(item.SourcePath, current => CloneItem(current, current.MediaInfo, current.PlannedOutput, "processing"));
                ProgressMessage = $"Obrada: {currentDisplayName(item)}";
                CurrentConversionItemText = item.SourceFile;

                try
                {
                    var mediaInfo = item.MediaInfo!;
                    var request = new ConversionRequest
                    {
                        MediaInfo = mediaInfo,
                        Settings = settings,
                        OutputPath = item.OutputPath,
                        TimelineProject = item.TimelineProject,
                        TransformSettings = item.TransformSettings
                    };
                    var ffmpegArguments = FfmpegCommandBuilder.BuildArguments(request).ToArray();
                    var itemStopwatch = Stopwatch.StartNew();

                    var completedBeforeCurrentItem = converted;
                    var progress = new Progress<ConversionProgressInfo>(update =>
                    {
                        IsConversionProgressIndeterminate = false;
                        var overallFraction = Math.Clamp((completedBeforeCurrentItem + update.Fraction) / queuedItems.Count, 0, 1);
                        ConversionProgressPercent = overallFraction * 100d;
                        CurrentConversionItemText = $"{item.SourceFile} | {FormatTimeSpan(update.ProcessedDuration)} / {FormatTimeSpan(update.ExpectedDuration)}";
                        ConversionEtaText = update.EstimatedRemaining is { } eta
                            ? $"ETA: {FormatTimeSpan(eta)} | brzina {update.SpeedText}"
                            : $"Brzina: {update.SpeedText}";
                        ProgressMessage = $"Obrada: {item.SourceFile} | {overallFraction:P0} | {CurrentConversionItemText} | {ConversionEtaText}";
                    });

                    await _conversionService.ConvertAsync(ffmpegPath, request, progress);
                    itemStopwatch.Stop();
                    var reportPath = await _conversionReportService.WriteItemReportAsync(
                        OutputFolder,
                        SelectedPreset,
                        request,
                        item,
                        ffmpegArguments,
                        itemStopwatch.Elapsed);
                    converted++;
                    ConversionProgressPercent = Math.Clamp((double)converted / queuedItems.Count, 0, 1) * 100d;
                    ReplaceItem(item.SourcePath, current => CloneItem(current, current.MediaInfo, current.PlannedOutput, "done", reportPath));
                    var processedItem = QueueItems.First(queueItem => string.Equals(queueItem.SourcePath, item.SourcePath, StringComparison.OrdinalIgnoreCase));
                    processedItems.Add(processedItem);
                    _lastConvertedOutputPath = processedItem.OutputPath;
                    _lastBatchReportPath = reportPath;
                    AppendLog(
                        $"DONE | {processedItem.SourceFile} -> {processedItem.OutputFile}{Environment.NewLine}" +
                        $"Output: {processedItem.OutputPath}{Environment.NewLine}" +
                        $"Report: {reportPath}{Environment.NewLine}" +
                        $"Deinterlace: {request.Settings.DeinterlaceMode} | Denoise: {request.Settings.DenoiseMode} | Scale: {request.Settings.ScaleMode}");
                }
                catch (Exception ex)
                {
                    failed = true;
                    failedCount++;
                    ReplaceItem(item.SourcePath, current => CloneItem(current, current.MediaInfo, current.PlannedOutput, "failed"));
                    StatusMessage = $"Greska pri obradi {item.SourceFile}: {ex.Message}";
                    LogMessage = ex.ToString();
                    return;
                }

                if (!_pauseRequested)
                {
                    continue;
                }

                _pauseRequested = false;
                _isBatchPaused = true;
                PauseResumeLabel = "Resume";
                StatusMessage = $"Batch je pauziran posle trenutnog fajla | {CoreServices.QueueWorkflowService.BuildSummary(QueueItems)}";
                ProgressMessage = $"Pauza aktivna | do sada gotovo: {converted}";
                return;
            }
        }
        finally
        {
            if (!_isBatchPaused && !failed)
            {
                if (processedItems.Count > 0)
                {
                    var batchReportPath = await _conversionReportService.WriteBatchReportAsync(
                        OutputFolder,
                        SelectedPreset,
                        settings,
                        processedItems,
                        converted,
                        failedCount);
                    _lastBatchReportPath = batchReportPath;
                    AppendLog($"Batch report: {batchReportPath}");
                }

                IsConversionProgressIndeterminate = false;
                ConversionProgressPercent = 100d;
                CurrentConversionItemText = converted == 0
                    ? "Nema obradjenih stavki."
                    : $"{queuedItems.Last().SourceFile} | batch zavrsen ({converted} stavki)";
                ConversionEtaText = "ETA: 00:00:00";
                ProgressMessage = $"Konverzija zavrsena. Obradjeno: {converted} | {ConversionEtaText}";
                StatusMessage = $"Start Conversion zavrsen. Done: {converted} | {CoreServices.QueueWorkflowService.BuildSummary(QueueItems)}"
                    + (_lastBatchReportPath is null ? string.Empty : $" | Report: {Path.GetFileName(_lastBatchReportPath)}");
                AppendLog($"Output folder: {OutputFolder}");
                PauseResumeLabel = "Pause";
            }

            _isConverting = false;
            PauseResumeCommand.NotifyCanExecuteChanged();
            RefreshCommandStates();
        }
    }

    private async Task TestSampleAsync()
    {
        if (string.IsNullOrWhiteSpace(ResolvedFfmpegPath))
        {
            StatusMessage = "ffmpeg nije dostupan za Test Sample.";
            return;
        }

        if (SelectedQueueItem?.MediaInfo is null)
        {
            StatusMessage = "Izaberi fajl iz queue liste za Test Sample.";
            return;
        }

        var sampleDirectory = Path.Combine(OutputFolder, "samples");
        Directory.CreateDirectory(sampleDirectory);
        var samplePath = Path.Combine(sampleDirectory, $"{Path.GetFileNameWithoutExtension(SelectedQueueItem.SourceFile)}-sample.mp4");
        var start = ResolveSampleStartSeconds(SelectedQueueItem.MediaInfo.DurationSeconds);
        var duration = ResolveSampleDurationSeconds(SelectedQueueItem.MediaInfo.DurationSeconds, start);
        var settings = BuildSettings();

        var ffmpegPath = ResolvedFfmpegPath!;
        try
        {
            await _conversionService.ConvertAsync(ffmpegPath, new ConversionRequest
            {
                MediaInfo = SelectedQueueItem.MediaInfo,
                Settings = settings,
                OutputPath = samplePath,
                TimelineProject = SelectedQueueItem.TimelineProject,
                TransformSettings = SelectedQueueItem.TransformSettings,
                IsSample = true,
                SampleStartSeconds = start,
                SampleDurationSeconds = duration
            });

            LastSamplePath = samplePath;
            StatusMessage = $"Test Sample napravljen: {Path.GetFileName(samplePath)}";
            ProgressMessage = $"Sample start: {start:0}s | duration: {duration:0}s";
            LogMessage = samplePath;
        }
        catch (Exception ex)
        {
            StatusMessage = $"Test Sample nije uspeo: {ex.Message}";
            LogMessage = ex.ToString();
        }
    }

    private void RefreshPlannedOutput()
    {
        if (!_applyingPreset && !string.Equals(SelectedPreset, CoreServices.WorkflowPresetService.Custom, StringComparison.Ordinal))
        {
            _applyingPreset = true;
            SelectedPreset = CoreServices.WorkflowPresetService.Custom;
            _applyingPreset = false;
        }

        if (QueueItems.Count == 0)
        {
            RefreshComparisonRows(null);
            return;
        }

        var settings = BuildSettings();
        var existingItems = QueueItems.ToList();
        QueueItems.Clear();
        foreach (var item in existingItems)
        {
            var planned = item.MediaInfo is null ? null : CoreServices.OutputPlanner.Build(item.MediaInfo, settings, item.TransformSettings);
            QueueItems.Add(new QueueItemSummary
            {
                SourceFile = item.SourceFile,
                SourcePath = item.SourcePath,
                OutputFile = item.OutputFile,
                OutputPath = item.OutputPath,
                OutputPattern = item.OutputPattern,
                Container = item.Container,
                Resolution = item.Resolution,
                Duration = item.Duration,
                Video = item.Video,
                Audio = item.Audio,
                Status = item.Status,
                MediaInfo = item.MediaInfo,
                PlannedOutput = planned,
                ReportPath = item.ReportPath,
                TimelineProject = item.TimelineProject,
                TransformSettings = item.TransformSettings
            });
        }

        ApplyQueueZebra();

        var selected = QueueItems.FirstOrDefault(i => i.SourcePath == SelectedQueueItem?.SourcePath) ?? QueueItems.FirstOrDefault();
        SelectedQueueItem = selected;
        RefreshComparisonRows(selected);
    }

    private void RefreshComparisonRows(QueueItemSummary? item)
    {
        ComparisonRows.Clear();
        foreach (var row in CoreServices.PropertyComparisonBuilder.Build(item))
        {
            ComparisonRows.Add(row);
        }
    }

    private BatchSettings BuildSettings() => new()
    {
        InputPath = InputFolder,
        OutputDirectory = OutputFolder,
        QualityMode = QualityMode,
        ScaleMode = ScaleMode,
        AspectMode = AspectMode,
        VideoBitrate = VideoBitrate,
        AudioBitrate = AudioBitrate
        ,
        DeinterlaceMode = DeinterlaceMode,
        DenoiseMode = DenoiseMode,
        EncodeEngine = EncodeEngine,
        SplitOutput = SplitOutput,
        MaxPartGb = MaxPartGb
    };

    private void ApplyPreset(string presetName)
    {
        var preset = CoreServices.WorkflowPresetService.TryGet(presetName);
        if (preset is null)
        {
            return;
        }

        _applyingPreset = true;
        try
        {
            QualityMode = preset.QualityMode;
            ScaleMode = preset.ScaleMode;
            AspectMode = preset.AspectMode;
            VideoBitrate = preset.VideoBitrate;
            AudioBitrate = preset.AudioBitrate;
            SplitOutput = preset.SplitOutput;
            MaxPartGb = preset.MaxPartGb;
            RefreshPlannedOutput();
        }
        finally
        {
            _applyingPreset = false;
        }

        StatusMessage = $"Preset aktivan: {preset.Name}";
        RefreshCommandStates();
    }

    public async Task UseSelectedFilesAsync(IReadOnlyList<string> filePaths)
    {
        var normalized = filePaths
            .Where(path => !string.IsNullOrWhiteSpace(path))
            .Select(Path.GetFullPath)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        if (normalized.Count == 0)
        {
            return;
        }

        _explicitSourcePaths = normalized;
        _suppressSelectionReset = true;
        try
        {
            InputFolder = normalized[0];
        }
        finally
        {
            _suppressSelectionReset = false;
        }

        var parentFolder = Path.GetDirectoryName(normalized[0]);
        if (string.IsNullOrWhiteSpace(OutputFolder) && !string.IsNullOrWhiteSpace(parentFolder))
        {
            OutputFolder = Path.Combine(parentFolder, "vhs-mp4-output");
        }

        SelectionHint = normalized.Count == 1
            ? $"Izabran je 1 fajl: {Path.GetFileName(normalized[0])}"
            : $"Izabrano je {normalized.Count} fajlova. Scan ce raditi samo nad tom listom.";

        await AutoScanAfterSelectionAsync();
    }

    public async Task UseSelectedFolderAsync(string folderPath)
    {
        if (string.IsNullOrWhiteSpace(folderPath))
        {
            return;
        }

        _explicitSourcePaths = null;
        _suppressSelectionReset = true;
        try
        {
            InputFolder = Path.GetFullPath(folderPath);
        }
        finally
        {
            _suppressSelectionReset = false;
        }

        if (string.IsNullOrWhiteSpace(OutputFolder))
        {
            OutputFolder = Path.Combine(InputFolder, "vhs-mp4-output");
        }

        SelectionHint = "Izabran je ceo folder. Scan ide kroz podrzane video fajlove u folderu i podfolderima.";

        await AutoScanAfterSelectionAsync();
    }

    public void SetOutputFolderPath(string folderPath)
    {
        if (!string.IsNullOrWhiteSpace(folderPath))
        {
            OutputFolder = Path.GetFullPath(folderPath);
        }

        RefreshCommandStates();
    }

    public AppSessionState CaptureSessionState() => new()
    {
        InputFolder = InputFolder,
        OutputFolder = OutputFolder,
        FfmpegPath = ResolvedFfmpegPath
    };

    public void ApplySessionState(AppSessionState? state)
    {
        if (state is null)
        {
            return;
        }
        if (!string.IsNullOrWhiteSpace(state.FfmpegPath))
        {
            ResolvedFfmpegPath = state.FfmpegPath;
            StatusMessage = $"FFmpeg putanja je vracena iz poslednje sesije: {ResolvedFfmpegPath}";
        }
    }

    public async Task UseDroppedPathsAsync(IReadOnlyList<string> droppedPaths)
    {
        var normalized = droppedPaths
            .Where(path => !string.IsNullOrWhiteSpace(path))
            .Select(Path.GetFullPath)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        if (normalized.Count == 0)
        {
            return;
        }

        var files = normalized.Where(File.Exists).ToList();
        if (files.Count > 0)
        {
            await UseSelectedFilesAsync(files);
            return;
        }

        var folder = normalized.FirstOrDefault(Directory.Exists);
        if (!string.IsNullOrWhiteSpace(folder))
        {
            await UseSelectedFolderAsync(folder);
        }
    }

    public void ApplyEditorState(string sourcePath, TimelineProject timeline, ItemTransformSettings? transformSettings)
    {
        var existingItems = QueueItems.ToList();
        QueueItems.Clear();

        foreach (var item in existingItems)
        {
            if (!string.Equals(item.SourcePath, sourcePath, StringComparison.OrdinalIgnoreCase))
            {
                QueueItems.Add(item);
                continue;
            }

            var effectiveTransform = transformSettings ?? item.TransformSettings;
            var planned = item.MediaInfo is null ? null : CoreServices.OutputPlanner.Build(item.MediaInfo, BuildSettings(), effectiveTransform);
            if (planned is not null)
            {
                planned = new OutputPlanSummary
                {
                    DisplayOutputName = planned.DisplayOutputName,
                    Container = planned.Container,
                    Resolution = planned.Resolution,
                    DurationText = CoreServices.TimelineEditorService.FormatSeconds(CoreServices.TimelineEditorService.GetKeptDurationSeconds(timeline)),
                    VideoCodecLabel = planned.VideoCodecLabel,
                    VideoBitrateComparisonText = planned.VideoBitrateComparisonText,
                    AudioCodecText = planned.AudioCodecText,
                    AudioBitrateText = planned.AudioBitrateText,
                    BitrateText = planned.BitrateText,
                    EncodeEngineText = planned.EncodeEngineText,
                    EstimatedSizeText = planned.EstimatedSizeText,
                    UsbNoteText = planned.UsbNoteText,
                    SplitModeText = planned.SplitModeText,
                    CropText = planned.CropText,
                    AspectText = planned.AspectText,
                    OutputWidth = planned.OutputWidth,
                    OutputHeight = planned.OutputHeight
                };
            }

            QueueItems.Add(new QueueItemSummary
            {
                SourceFile = item.SourceFile,
                SourcePath = item.SourcePath,
                OutputFile = item.OutputFile,
                OutputPath = item.OutputPath,
                OutputPattern = item.OutputPattern,
                Container = item.Container,
                Resolution = item.Resolution,
                Duration = item.Duration,
                Video = item.Video,
                Audio = item.Audio,
                Status = "timeline edited",
                MediaInfo = item.MediaInfo,
                PlannedOutput = planned,
                TimelineProject = timeline,
                TransformSettings = effectiveTransform
            });
        }

        ApplyQueueZebra();

        SelectedQueueItem = QueueItems.FirstOrDefault(item => string.Equals(item.SourcePath, sourcePath, StringComparison.OrdinalIgnoreCase));
        StatusMessage = "Timeline izmene su vracene u batch queue.";
        RefreshCommandStates();
    }

    public async Task JoinFilesCopyAsync(IReadOnlyList<string> inputPaths, string outputPath)
    {
        if (string.IsNullOrWhiteSpace(ResolvedFfmpegPath))
        {
            StatusMessage = "ffmpeg nije dostupan za copy join.";
            return;
        }

        try
        {
            await _copyOnlyMediaToolsService.JoinAsync(ResolvedFfmpegPath, inputPaths, outputPath);
            StatusMessage = $"Copy join zavrsen: {Path.GetFileName(outputPath)}";
            ProgressMessage = $"Join fajlova: {inputPaths.Count} -> {outputPath}";
            LogMessage = outputPath;
        }
        catch (Exception ex)
        {
            StatusMessage = $"Copy join nije uspeo: {ex.Message}";
            LogMessage = ex.ToString();
        }
    }

    public async Task SaveQueueAsync(string? outputPath)
    {
        if (string.IsNullOrWhiteSpace(outputPath))
        {
            StatusMessage = "Izaberi putanju za queue fajl.";
            return;
        }

        var snapshot = new QueueSessionSnapshot
        {
            InputFolder = InputFolder,
            OutputFolder = OutputFolder,
            SelectedPreset = SelectedPreset,
            QualityMode = QualityMode,
            ScaleMode = ScaleMode,
            AspectMode = AspectMode,
            DeinterlaceMode = DeinterlaceMode,
            DenoiseMode = DenoiseMode,
            EncodeEngine = EncodeEngine,
            VideoBitrate = VideoBitrate,
            AudioBitrate = AudioBitrate,
            SplitOutput = SplitOutput,
            MaxPartGb = MaxPartGb,
            ExplicitSourcePaths = _explicitSourcePaths,
            QueueItems = QueueItems.ToList()
        };

        await _queueSnapshotService.SaveAsync(outputPath, snapshot);
        StatusMessage = $"Queue sacuvan: {Path.GetFileName(outputPath)}";
        LogMessage = outputPath;
    }

    public async Task LoadQueueAsync(string? inputPath)
    {
        if (string.IsNullOrWhiteSpace(inputPath))
        {
            StatusMessage = "Izaberi queue fajl za ucitavanje.";
            return;
        }

        var snapshot = await _queueSnapshotService.LoadAsync(inputPath);
        _explicitSourcePaths = snapshot.ExplicitSourcePaths?.ToList();

        _applyingPreset = true;
        try
        {
            InputFolder = snapshot.InputFolder;
            OutputFolder = snapshot.OutputFolder;
            SelectedPreset = snapshot.SelectedPreset;
            QualityMode = snapshot.QualityMode;
            ScaleMode = snapshot.ScaleMode;
            AspectMode = snapshot.AspectMode;
            DeinterlaceMode = snapshot.DeinterlaceMode;
            DenoiseMode = snapshot.DenoiseMode;
            EncodeEngine = snapshot.EncodeEngine;
            VideoBitrate = snapshot.VideoBitrate;
            AudioBitrate = snapshot.AudioBitrate;
            SplitOutput = snapshot.SplitOutput;
            MaxPartGb = snapshot.MaxPartGb;
        }
        finally
        {
            _applyingPreset = false;
        }

        QueueItems.Clear();
        foreach (var item in snapshot.QueueItems)
        {
            var planned = item.MediaInfo is null ? null : CoreServices.OutputPlanner.Build(item.MediaInfo, BuildSettings(), item.TransformSettings);
            QueueItems.Add(new QueueItemSummary
            {
                SourceFile = item.SourceFile,
                SourcePath = item.SourcePath,
                OutputFile = item.OutputFile,
                OutputPath = item.OutputPath,
                OutputPattern = item.OutputPattern,
                Container = item.Container,
                Resolution = item.Resolution,
                Duration = item.Duration,
                Video = item.Video,
                Audio = item.Audio,
                Status = item.Status,
                MediaInfo = item.MediaInfo,
                PlannedOutput = planned,
                ReportPath = item.ReportPath,
                TimelineProject = item.TimelineProject,
                TransformSettings = item.TransformSettings
            });
        }

        ApplyQueueZebra();

        SelectedQueueItem = QueueItems.FirstOrDefault();
        SelectionHint = _explicitSourcePaths?.Count > 0
            ? $"Ucitan queue sa eksplicitnih fajlova: {_explicitSourcePaths.Count}"
            : "Ucitan queue iz sacuvanog batch stanja.";
        StatusMessage = $"Queue ucitan: {Path.GetFileName(inputPath)} | {CoreServices.QueueWorkflowService.BuildSummary(QueueItems)}";
        LogMessage = inputPath;
        RefreshComparisonRows(SelectedQueueItem);
        RefreshCommandStates();
    }

    private void SkipSelected()
    {
        if (SelectedQueueItem is null)
        {
            return;
        }

        ReplaceItem(SelectedQueueItem.SourcePath, current => CoreServices.QueueWorkflowService.MarkSkipped(current));
        StatusMessage = $"Selected item je oznacen kao skipped | {CoreServices.QueueWorkflowService.BuildSummary(QueueItems)}";
        RefreshCommandStates();
    }

    private void RetryFailedItems()
    {
        for (var index = 0; index < QueueItems.Count; index++)
        {
            QueueItems[index] = CoreServices.QueueWorkflowService.RetryFailed(QueueItems[index]);
        }

        ApplyQueueZebra();

        StatusMessage = $"Failed stavke su vracene u queue | {CoreServices.QueueWorkflowService.BuildSummary(QueueItems)}";
        RefreshCommandStates();
    }

    private void ClearCompletedItems()
    {
        var survivors = QueueItems.Where(item => item.Status != "done").ToList();
        QueueItems.Clear();
        foreach (var survivor in survivors)
        {
            QueueItems.Add(survivor);
        }

        ApplyQueueZebra();

        SelectedQueueItem = QueueItems.FirstOrDefault();
        StatusMessage = $"Done stavke su uklonjene iz queue liste | {CoreServices.QueueWorkflowService.BuildSummary(QueueItems)}";
        RefreshCommandStates();
    }

    private bool CanSplitSelectedCopy()
        => !string.IsNullOrWhiteSpace(ResolvedFfmpegPath) && SelectedQueueItem?.MediaInfo is not null;

    private bool CanPauseOrResume() => _isConverting || _isBatchPaused;

    private async Task SplitSelectedCopyAsync()
    {
        if (string.IsNullOrWhiteSpace(ResolvedFfmpegPath) || SelectedQueueItem?.MediaInfo is null)
        {
            return;
        }

        try
        {
            var createdFiles = await _copyOnlyMediaToolsService.SplitAsync(
                ResolvedFfmpegPath,
                SelectedQueueItem.MediaInfo,
                OutputFolder,
                MaxPartGb);

            StatusMessage = $"Copy split zavrsen: {createdFiles.Count} delova za {SelectedQueueItem.SourceFile}";
            ProgressMessage = string.Join(Environment.NewLine, createdFiles.Select(Path.GetFileName));
            LogMessage = string.Join(Environment.NewLine, createdFiles);
        }
        catch (Exception ex)
        {
            StatusMessage = $"Copy split nije uspeo: {ex.Message}";
            LogMessage = ex.ToString();
        }
    }

    private async Task PauseResumeAsync()
    {
        if (_isBatchPaused)
        {
            StatusMessage = "Batch nastavlja od sledece queued stavke.";
            await StartConversionAsync();
            return;
        }

        if (!_isConverting)
        {
            StatusMessage = "Nema aktivne obrade za pauzu.";
            return;
        }

        _pauseRequested = true;
        PauseResumeLabel = "Resume";
        StatusMessage = "Pause je zakazan posle trenutnog fajla.";
        PauseResumeCommand.NotifyCanExecuteChanged();
    }

    private void ReplaceItem(string sourcePath, Func<QueueItemSummary, QueueItemSummary> updater)
    {
        for (var index = 0; index < QueueItems.Count; index++)
        {
            var item = QueueItems[index];
            if (!string.Equals(item.SourcePath, sourcePath, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var updated = updater(item);
            QueueItems[index] = updated;
            if (SelectedQueueItem?.SourcePath == sourcePath)
            {
                SelectedQueueItem = updated;
            }

            ApplyQueueZebra();
            RefreshCommandStates();

            return;
        }
    }

    private bool CanScanFiles()
        => !_isConverting && !string.IsNullOrWhiteSpace(InputFolder) && !string.IsNullOrWhiteSpace(ResolvedFfmpegPath);

    private bool CanStartConversion()
        => !_isConverting
           && !string.IsNullOrWhiteSpace(ResolvedFfmpegPath)
           && QueueItems.Any(CoreServices.QueueWorkflowService.ShouldConvert);

    private bool CanTestSample()
        => !_isConverting
           && !string.IsNullOrWhiteSpace(ResolvedFfmpegPath)
           && SelectedQueueItem?.MediaInfo is not null;

    private void RefreshCommandStates()
    {
        ScanFilesCommand?.NotifyCanExecuteChanged();
        StartConversionCommand?.NotifyCanExecuteChanged();
        TestSampleCommand?.NotifyCanExecuteChanged();
        SplitSelectedCopyCommand?.NotifyCanExecuteChanged();
        PauseResumeCommand?.NotifyCanExecuteChanged();
        OpenSampleCommand?.NotifyCanExecuteChanged();
        OpenOutputCommand?.NotifyCanExecuteChanged();
        OpenConvertedFileCommand?.NotifyCanExecuteChanged();
        OpenReportCommand?.NotifyCanExecuteChanged();
    }

    private void ApplyQueueZebra()
    {
        for (var index = 0; index < QueueItems.Count; index++)
        {
            QueueItems[index].IsAlternate = index % 2 == 1;
        }
    }

    private static QueueItemSummary CloneItem(QueueItemSummary source, MediaInfo? mediaInfo, OutputPlanSummary? plannedOutput, string status, string? reportPath = null)
    {
        return new QueueItemSummary
        {
            SourceFile = source.SourceFile,
            SourcePath = source.SourcePath,
            OutputFile = source.OutputFile,
            OutputPath = source.OutputPath,
            OutputPattern = source.OutputPattern,
            Container = source.Container,
            Resolution = source.Resolution,
            Duration = source.Duration,
            Video = source.Video,
            Audio = source.Audio,
            Status = status,
            MediaInfo = mediaInfo,
            PlannedOutput = plannedOutput,
            ReportPath = reportPath ?? source.ReportPath,
            TimelineProject = source.TimelineProject,
            TransformSettings = source.TransformSettings
        };
    }

    private bool CanOpenSample()
        => !string.IsNullOrWhiteSpace(LastSamplePath) && File.Exists(LastSamplePath);

    private void OpenSample()
    {
        if (!CanOpenSample())
        {
            return;
        }

        _externalLauncher.OpenPath(LastSamplePath!);
    }

    private bool CanOpenOutputFolder() => !string.IsNullOrWhiteSpace(OutputFolder);

    private void OpenOutputFolder()
    {
        if (string.IsNullOrWhiteSpace(OutputFolder))
        {
            return;
        }

        Directory.CreateDirectory(OutputFolder);
        _externalLauncher.OpenPath(OutputFolder);
    }

    private static string currentDisplayName(QueueItemSummary item) => item.SourceFile;

    private bool CanOpenConvertedFile()
    {
        var path = ResolveOpenConvertedFilePath();
        return !string.IsNullOrWhiteSpace(path) && File.Exists(path);
    }

    private void OpenConvertedFile()
    {
        var path = ResolveOpenConvertedFilePath();
        if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
        {
            return;
        }

        _externalLauncher.OpenPath(path);
    }

    private bool CanOpenReport()
    {
        var path = ResolveOpenReportPath();
        return !string.IsNullOrWhiteSpace(path) && File.Exists(path);
    }

    private void OpenReport()
    {
        var path = ResolveOpenReportPath();
        if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
        {
            return;
        }

        _externalLauncher.OpenPath(path);
    }

    private string? ResolveOpenConvertedFilePath()
        => SelectedQueueItem is { OutputPath: not null } selected && File.Exists(selected.OutputPath)
            ? selected.OutputPath
            : _lastConvertedOutputPath;

    private string? ResolveOpenReportPath()
        => SelectedQueueItem is { ReportPath: not null } selected && File.Exists(selected.ReportPath)
            ? selected.ReportPath
            : _lastBatchReportPath;

    private void AppendLog(string message)
    {
        if (string.IsNullOrWhiteSpace(message))
        {
            return;
        }

        LogMessage = string.IsNullOrWhiteSpace(LogMessage)
            ? message
            : LogMessage + Environment.NewLine + message;
    }

    private async Task AutoScanAfterSelectionAsync()
    {
        if (string.IsNullOrWhiteSpace(ResolvedFfmpegPath))
        {
            StatusMessage = "Izbor je prihvacen, ali ffmpeg/ffprobe jos nisu dostupni za automatski scan.";
            return;
        }

        await ScanFilesAsync();
    }

    private double ResolveSampleStartSeconds(double sourceDurationSeconds)
    {
        if (TryParseTimeText(SampleStartText, out var explicitStart))
        {
            return Math.Max(0, Math.Min(sourceDurationSeconds, explicitStart));
        }

        return 0;
    }

    private double ResolveSampleDurationSeconds(double sourceDurationSeconds, double startSeconds)
    {
        if (TryParseTimeText(SampleDurationText, out var explicitDuration))
        {
            var clamped = Math.Max(1, explicitDuration);
            return Math.Min(clamped, Math.Max(1, sourceDurationSeconds - startSeconds));
        }

        return Math.Min(120, Math.Max(1, sourceDurationSeconds - startSeconds));
    }

    private static bool TryParseTimeText(string value, out double seconds)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            seconds = 0;
            return false;
        }

        if (TimeSpan.TryParse(value, out var parsedTime))
        {
            seconds = parsedTime.TotalSeconds;
            return true;
        }

        if (double.TryParse(value, out var parsedSeconds))
        {
            seconds = parsedSeconds;
            return true;
        }

        seconds = 0;
        return false;
    }

    public void SetFfmpegPath(string? ffmpegPath)
    {
        if (string.IsNullOrWhiteSpace(ffmpegPath))
        {
            return;
        }

        ResolvedFfmpegPath = Path.GetFullPath(ffmpegPath);
        StatusMessage = $"ffmpeg putanja je postavljena: {ResolvedFfmpegPath}";
        LogMessage = $"FFmpeg: {ResolvedFfmpegPath}";
        SplitSelectedCopyCommand.NotifyCanExecuteChanged();
        if (QueueItems.Count == 0 && !string.IsNullOrWhiteSpace(InputFolder))
        {
            _ = AutoScanAfterSelectionAsync();
        }
    }

    public void AutoDetectFfmpeg()
    {
        var detected = FfmpegLocator.Resolve();
        if (string.IsNullOrWhiteSpace(detected))
        {
            StatusMessage = "ffmpeg nije automatski pronadjen. Izaberi ga rucno ili ga instaliraj iz Tools menija.";
            return;
        }

        SetFfmpegPath(detected);
    }

    private static string FormatTimeSpan(TimeSpan? value)
        => value is null ? "--" : value.Value.ToString(@"hh\:mm\:ss");
}
