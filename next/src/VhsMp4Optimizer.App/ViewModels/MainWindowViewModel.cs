using System;
using System.Collections.ObjectModel;
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
    private readonly SourceScanService _sourceScanService = new();
    private readonly string? _ffmpegPath;

    public MainWindowViewModel()
    {
        _ffmpegPath = FfmpegLocator.Resolve();
        QueueItems = new ObservableCollection<QueueItemSummary>();
        ComparisonRows = new ObservableCollection<PropertyComparisonRow>(CoreServices.PropertyComparisonBuilder.Build(null));
        QualityModes = new ObservableCollection<string>(CoreServices.QualityModes.All);
        ScaleModes = new ObservableCollection<string>(CoreServices.ScaleModes.All);
        AspectModes = new ObservableCollection<string>(CoreServices.AspectModes.All);
        ScanFilesCommand = new AsyncRelayCommand(ScanFilesAsync);

        if (!string.IsNullOrWhiteSpace(_ffmpegPath))
        {
            StatusMessage = $"Faza 3: ffmpeg je pronadjen na {_ffmpegPath}. Sledeci korak je scan i planned output parity.";
        }
        else
        {
            StatusMessage = "Faza 3: ffmpeg jos nije pronadjen. Scan i media info cekaju lokalni ffmpeg/fprobe.";
        }
    }

    [ObservableProperty]
    private string _windowTitle = "VHS MP4 Optimizer Next";

    [ObservableProperty]
    private string _inputFolder = @"F:\Veliki avi";

    [ObservableProperty]
    private string _outputFolder = @"F:\Veliki avi\vhs-mp4-output";

    [ObservableProperty]
    private string _selectedPreset = "USB standard";

    [ObservableProperty]
    private string _qualityMode = CoreServices.QualityModes.TvSmart;

    [ObservableProperty]
    private string _scaleMode = CoreServices.ScaleModes.Pal576p;

    [ObservableProperty]
    private string _aspectMode = CoreServices.AspectModes.Auto;

    [ObservableProperty]
    private string _videoBitrate = "5000k";

    [ObservableProperty]
    private string _audioBitrate = "160k";

    [ObservableProperty]
    private string _statusMessage;

    [ObservableProperty]
    private string _progressMessage = "Nema aktivne obrade. Ovaj ekran sada prelazi iz shell-a u stvarni batch workspace.";

    [ObservableProperty]
    private string _logMessage = "Migracioni branch je aktivan. Avalonia verzija sada dobija pravo scan/planned output ponasanje.";

    [ObservableProperty]
    private QueueItemSummary? _selectedQueueItem;

    public ObservableCollection<QueueItemSummary> QueueItems { get; }

    public ObservableCollection<PropertyComparisonRow> ComparisonRows { get; }

    public ObservableCollection<string> QualityModes { get; }

    public ObservableCollection<string> ScaleModes { get; }

    public ObservableCollection<string> AspectModes { get; }

    public IAsyncRelayCommand ScanFilesCommand { get; }

    partial void OnSelectedQueueItemChanged(QueueItemSummary? value) => RefreshComparisonRows(value);

    partial void OnQualityModeChanged(string value) => RefreshPlannedOutput();

    partial void OnScaleModeChanged(string value) => RefreshPlannedOutput();

    partial void OnAspectModeChanged(string value) => RefreshPlannedOutput();

    partial void OnVideoBitrateChanged(string value) => RefreshPlannedOutput();

    partial void OnAudioBitrateChanged(string value) => RefreshPlannedOutput();

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
        var items = _sourceScanService.Scan(settings with { OutputDirectory = outputDirectory }, _ffmpegPath);

        foreach (var item in items)
        {
            QueueItems.Add(item);
        }

        SelectedQueueItem = QueueItems.FirstOrDefault();
        ProgressMessage = $"Scan zavrsen. Pronadjeno: {QueueItems.Count} fajlova.";
        LogMessage = $"ffmpeg: {_ffmpegPath}{Environment.NewLine}Output: {outputDirectory}";
        StatusMessage = QueueItems.Count == 0
            ? "Nema podrzanih video fajlova za scan u zadatom input putu."
            : $"Scan Files: pronadjeno {QueueItems.Count} | queued: {QueueItems.Count(i => i.Status == "queued")} | skipped: {QueueItems.Count(i => i.Status == "skipped")}";
        return Task.CompletedTask;
    }

    private void RefreshPlannedOutput()
    {
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
            var planned = item.MediaInfo is null ? null : CoreServices.OutputPlanner.Build(item.MediaInfo, settings);
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
                PlannedOutput = planned
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
    };

    public void ApplyTimelineProject(string sourcePath, TimelineProject timeline)
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

            OutputPlanSummary? planned = item.PlannedOutput;
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
                TimelineProject = timeline
            });
        }

        SelectedQueueItem = QueueItems.FirstOrDefault(item => string.Equals(item.SourcePath, sourcePath, StringComparison.OrdinalIgnoreCase));
        StatusMessage = "Timeline izmene su vracene u batch queue.";
    }
}
