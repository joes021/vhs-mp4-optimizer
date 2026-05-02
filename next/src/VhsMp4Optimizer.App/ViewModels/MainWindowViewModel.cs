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
using CoreServices = VhsMp4Optimizer.Core.Services;
using VhsMp4Optimizer.Infrastructure.Services;

namespace VhsMp4Optimizer.App.ViewModels;

public partial class MainWindowViewModel : ViewModelBase
{
    private readonly ISourceScanService _sourceScanService;
    private readonly FfmpegConversionService _conversionService = new();
    private readonly CopyOnlyMediaToolsService _copyOnlyMediaToolsService = new();
    private readonly QueueSnapshotService _queueSnapshotService = new();
    private readonly string? _ffmpegPath;
    private IReadOnlyList<string>? _explicitSourcePaths;
    private bool _suppressSelectionReset;
    private bool _applyingPreset;
    private bool _isConverting;
    private bool _pauseRequested;
    private bool _isBatchPaused;

    public MainWindowViewModel(ISourceScanService? sourceScanService = null, string? ffmpegPath = null)
    {
        _sourceScanService = sourceScanService ?? new SourceScanService();
        _ffmpegPath = ffmpegPath ?? FfmpegLocator.Resolve();
        QueueItems = new ObservableCollection<QueueItemSummary>();
        ComparisonRows = new ObservableCollection<PropertyComparisonRow>(CoreServices.PropertyComparisonBuilder.Build(null));
        WorkflowPresets = new ObservableCollection<string>(CoreServices.WorkflowPresetService.Names);
        QualityModes = new ObservableCollection<string>(CoreServices.QualityModes.All);
        ScaleModes = new ObservableCollection<string>(CoreServices.ScaleModes.All);
        AspectModes = new ObservableCollection<string>(CoreServices.AspectModes.All);
        ScanFilesCommand = new AsyncRelayCommand(ScanFilesAsync);
        StartConversionCommand = new AsyncRelayCommand(StartConversionAsync);
        TestSampleCommand = new AsyncRelayCommand(TestSampleAsync);
        OpenSampleCommand = new RelayCommand(OpenSample, CanOpenSample);
        OpenOutputCommand = new RelayCommand(OpenOutputFolder, CanOpenOutputFolder);
        SkipSelectedCommand = new RelayCommand(SkipSelected);
        RetryFailedCommand = new RelayCommand(RetryFailedItems);
        ClearCompletedCommand = new RelayCommand(ClearCompletedItems);
        SplitSelectedCopyCommand = new AsyncRelayCommand(SplitSelectedCopyAsync, CanSplitSelectedCopy);
        PauseResumeCommand = new AsyncRelayCommand(PauseResumeAsync, CanPauseOrResume);
        SaveQueueCommand = new AsyncRelayCommand<string>(SaveQueueAsync);
        LoadQueueCommand = new AsyncRelayCommand<string>(LoadQueueAsync);

        if (!string.IsNullOrWhiteSpace(_ffmpegPath))
        {
            StatusMessage = $"Faza 3: ffmpeg je pronadjen na {_ffmpegPath}. Sledeci korak je scan i planned output parity.";
        }
        else
        {
            StatusMessage = "Faza 3: ffmpeg jos nije pronadjen. Scan i media info cekaju lokalni ffmpeg/fprobe.";
        }

        ApplyPreset(SelectedPreset);
    }

    [ObservableProperty]
    private string _windowTitle = "VHS MP4 Optimizer Next";

    [ObservableProperty]
    private string _inputFolder = @"F:\Veliki avi";

    [ObservableProperty]
    private string _outputFolder = @"F:\Veliki avi\vhs-mp4-output";

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
    private bool _splitOutput;

    [ObservableProperty]
    private double _maxPartGb = 3.8;

    [ObservableProperty]
    private string _videoBitrate = "5000k";

    [ObservableProperty]
    private string _audioBitrate = "160k";

    [ObservableProperty]
    private string _sampleStartText = string.Empty;

    [ObservableProperty]
    private string _sampleDurationText = string.Empty;

    [ObservableProperty]
    private string _pauseResumeLabel = "Pause";

    [ObservableProperty]
    private string _statusMessage;

    [ObservableProperty]
    private string _progressMessage = "Nema aktivne obrade. Ovaj ekran sada prelazi iz shell-a u stvarni batch workspace.";

    [ObservableProperty]
    private string _logMessage = "Migracioni branch je aktivan. Avalonia verzija sada dobija pravo scan/planned output ponasanje.";

    [ObservableProperty]
    private QueueItemSummary? _selectedQueueItem;

    [ObservableProperty]
    private string? _lastSamplePath;

    public ObservableCollection<QueueItemSummary> QueueItems { get; }

    public ObservableCollection<PropertyComparisonRow> ComparisonRows { get; }

    public ObservableCollection<string> WorkflowPresets { get; }

    public ObservableCollection<string> QualityModes { get; }

    public ObservableCollection<string> ScaleModes { get; }

    public ObservableCollection<string> AspectModes { get; }

    public string? ResolvedFfmpegPath => _ffmpegPath;

    public IAsyncRelayCommand ScanFilesCommand { get; }

    public IAsyncRelayCommand StartConversionCommand { get; }

    public IAsyncRelayCommand TestSampleCommand { get; }

    public IRelayCommand OpenSampleCommand { get; }

    public IRelayCommand OpenOutputCommand { get; }

    public IRelayCommand SkipSelectedCommand { get; }

    public IRelayCommand RetryFailedCommand { get; }

    public IRelayCommand ClearCompletedCommand { get; }

    public IAsyncRelayCommand SplitSelectedCopyCommand { get; }

    public IAsyncRelayCommand PauseResumeCommand { get; }

    public IAsyncRelayCommand<string> SaveQueueCommand { get; }

    public IAsyncRelayCommand<string> LoadQueueCommand { get; }

    partial void OnSelectedQueueItemChanged(QueueItemSummary? value)
    {
        RefreshComparisonRows(value);
        OpenSampleCommand.NotifyCanExecuteChanged();
        SplitSelectedCopyCommand.NotifyCanExecuteChanged();
    }

    partial void OnInputFolderChanged(string value)
    {
        if (_suppressSelectionReset)
        {
            return;
        }

        _explicitSourcePaths = null;
        SelectionHint = "Rucno uneta putanja: scan ide nad ovim input putem.";
    }

    partial void OnOutputFolderChanged(string value) => OpenOutputCommand.NotifyCanExecuteChanged();

    partial void OnQualityModeChanged(string value) => RefreshPlannedOutput();

    partial void OnScaleModeChanged(string value) => RefreshPlannedOutput();

    partial void OnAspectModeChanged(string value) => RefreshPlannedOutput();

    partial void OnVideoBitrateChanged(string value) => RefreshPlannedOutput();

    partial void OnAudioBitrateChanged(string value) => RefreshPlannedOutput();

    partial void OnSplitOutputChanged(bool value) => RefreshPlannedOutput();

    partial void OnMaxPartGbChanged(double value) => RefreshPlannedOutput();

    partial void OnLastSamplePathChanged(string? value) => OpenSampleCommand.NotifyCanExecuteChanged();

    partial void OnSelectedPresetChanged(string value)
    {
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

        if (string.IsNullOrWhiteSpace(_ffmpegPath))
        {
            StatusMessage = "ffmpeg/ffprobe nisu pronadjeni. Novi sistem za sada trazi lokalni ffmpeg da bi skenirao media info.";
            return Task.CompletedTask;
        }

        var settings = BuildSettings();
        var outputDirectory = _sourceScanService.ResolveOutputDirectory(InputFolder, OutputFolder);
        OutputFolder = outputDirectory;
        var items = _sourceScanService.Scan(settings with { OutputDirectory = outputDirectory }, _ffmpegPath, _explicitSourcePaths);

        foreach (var item in items)
        {
            QueueItems.Add(item);
        }

        SelectedQueueItem = QueueItems.FirstOrDefault();
        var explicitCount = _explicitSourcePaths?.Count ?? 0;
        ProgressMessage = explicitCount > 0
            ? $"Scan zavrsen. Pronadjeno: {QueueItems.Count} fajlova | eksplicitno izabrano: {explicitCount}"
            : $"Scan zavrsen. Pronadjeno: {QueueItems.Count} fajlova.";
        LogMessage = $"ffmpeg: {_ffmpegPath}{Environment.NewLine}Output: {outputDirectory}";
        StatusMessage = QueueItems.Count == 0
            ? "Nema podrzanih video fajlova za scan u zadatom input putu."
            : $"Scan Files: pronadjeno {QueueItems.Count} | {CoreServices.QueueWorkflowService.BuildSummary(QueueItems)}";
        return Task.CompletedTask;
    }

    private async Task StartConversionAsync()
    {
        if (_isConverting)
        {
            StatusMessage = "Batch je vec u toku.";
            return;
        }

        if (string.IsNullOrWhiteSpace(_ffmpegPath))
        {
            StatusMessage = "ffmpeg nije dostupan za Start Conversion.";
            return;
        }

        if (QueueItems.Count == 0)
        {
            StatusMessage = "Nema queue stavki za obradu.";
            return;
        }

        var ffmpegPath = _ffmpegPath!;
        var settings = BuildSettings();
        var items = QueueItems.ToList();
        var converted = 0;
        var failed = false;
        _isConverting = true;
        _isBatchPaused = false;
        _pauseRequested = false;
        PauseResumeLabel = "Pause";
        PauseResumeCommand.NotifyCanExecuteChanged();

        try
        {
            foreach (var item in items)
            {
                if (!CoreServices.QueueWorkflowService.ShouldConvert(item))
                {
                    continue;
                }

                ReplaceItem(item.SourcePath, current => CloneItem(current, current.MediaInfo, current.PlannedOutput, "processing"));
                ProgressMessage = $"Obrada: {currentDisplayName(item)}";

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

                    await _conversionService.ConvertAsync(ffmpegPath, request);
                    converted++;
                    ReplaceItem(item.SourcePath, current => CloneItem(current, current.MediaInfo, current.PlannedOutput, "done"));
                }
                catch (Exception ex)
                {
                    failed = true;
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
                ProgressMessage = $"Konverzija zavrsena. Obradjeno: {converted}";
                StatusMessage = $"Start Conversion zavrsen. Done: {converted} | {CoreServices.QueueWorkflowService.BuildSummary(QueueItems)}";
                LogMessage = $"Output folder: {OutputFolder}";
                PauseResumeLabel = "Pause";
            }

            _isConverting = false;
            PauseResumeCommand.NotifyCanExecuteChanged();
        }
    }

    private async Task TestSampleAsync()
    {
        if (string.IsNullOrWhiteSpace(_ffmpegPath))
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

        var ffmpegPath = _ffmpegPath!;
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
                TimelineProject = item.TimelineProject,
                TransformSettings = item.TransformSettings
            });
        }

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

        SelectedQueueItem = QueueItems.FirstOrDefault(item => string.Equals(item.SourcePath, sourcePath, StringComparison.OrdinalIgnoreCase));
        StatusMessage = "Timeline izmene su vracene u batch queue.";
    }

    public async Task JoinFilesCopyAsync(IReadOnlyList<string> inputPaths, string outputPath)
    {
        if (string.IsNullOrWhiteSpace(_ffmpegPath))
        {
            StatusMessage = "ffmpeg nije dostupan za copy join.";
            return;
        }

        try
        {
            await _copyOnlyMediaToolsService.JoinAsync(_ffmpegPath, inputPaths, outputPath);
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
                TimelineProject = item.TimelineProject,
                TransformSettings = item.TransformSettings
            });
        }

        SelectedQueueItem = QueueItems.FirstOrDefault();
        SelectionHint = _explicitSourcePaths?.Count > 0
            ? $"Ucitan queue sa eksplicitnih fajlova: {_explicitSourcePaths.Count}"
            : "Ucitan queue iz sacuvanog batch stanja.";
        StatusMessage = $"Queue ucitan: {Path.GetFileName(inputPath)} | {CoreServices.QueueWorkflowService.BuildSummary(QueueItems)}";
        LogMessage = inputPath;
        RefreshComparisonRows(SelectedQueueItem);
    }

    private void SkipSelected()
    {
        if (SelectedQueueItem is null)
        {
            return;
        }

        ReplaceItem(SelectedQueueItem.SourcePath, current => CoreServices.QueueWorkflowService.MarkSkipped(current));
        StatusMessage = $"Selected item je oznacen kao skipped | {CoreServices.QueueWorkflowService.BuildSummary(QueueItems)}";
    }

    private void RetryFailedItems()
    {
        for (var index = 0; index < QueueItems.Count; index++)
        {
            QueueItems[index] = CoreServices.QueueWorkflowService.RetryFailed(QueueItems[index]);
        }

        StatusMessage = $"Failed stavke su vracene u queue | {CoreServices.QueueWorkflowService.BuildSummary(QueueItems)}";
    }

    private void ClearCompletedItems()
    {
        var survivors = QueueItems.Where(item => item.Status != "done").ToList();
        QueueItems.Clear();
        foreach (var survivor in survivors)
        {
            QueueItems.Add(survivor);
        }

        SelectedQueueItem = QueueItems.FirstOrDefault();
        StatusMessage = $"Done stavke su uklonjene iz queue liste | {CoreServices.QueueWorkflowService.BuildSummary(QueueItems)}";
    }

    private bool CanSplitSelectedCopy()
        => !string.IsNullOrWhiteSpace(_ffmpegPath) && SelectedQueueItem?.MediaInfo is not null;

    private bool CanPauseOrResume() => _isConverting || _isBatchPaused;

    private async Task SplitSelectedCopyAsync()
    {
        if (string.IsNullOrWhiteSpace(_ffmpegPath) || SelectedQueueItem?.MediaInfo is null)
        {
            return;
        }

        try
        {
            var createdFiles = await _copyOnlyMediaToolsService.SplitAsync(
                _ffmpegPath,
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

            return;
        }
    }

    private static QueueItemSummary CloneItem(QueueItemSummary source, MediaInfo? mediaInfo, OutputPlanSummary? plannedOutput, string status)
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

        Process.Start(new ProcessStartInfo
        {
            FileName = LastSamplePath!,
            UseShellExecute = true
        });
    }

    private bool CanOpenOutputFolder() => !string.IsNullOrWhiteSpace(OutputFolder);

    private void OpenOutputFolder()
    {
        if (string.IsNullOrWhiteSpace(OutputFolder))
        {
            return;
        }

        Directory.CreateDirectory(OutputFolder);
        Process.Start(new ProcessStartInfo
        {
            FileName = OutputFolder,
            UseShellExecute = true
        });
    }

    private static string currentDisplayName(QueueItemSummary item) => item.SourceFile;

    private async Task AutoScanAfterSelectionAsync()
    {
        if (string.IsNullOrWhiteSpace(_ffmpegPath))
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

        return sourceDurationSeconds > 150 ? 30 : 0;
    }

    private double ResolveSampleDurationSeconds(double sourceDurationSeconds, double startSeconds)
    {
        if (TryParseTimeText(SampleDurationText, out var explicitDuration))
        {
            var clamped = Math.Max(1, explicitDuration);
            return Math.Min(clamped, Math.Max(1, sourceDurationSeconds - startSeconds));
        }

        return Math.Min(120, Math.Max(10, sourceDurationSeconds - startSeconds));
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
}
