using System;
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
    private readonly SourceScanService _sourceScanService = new();
    private readonly FfmpegConversionService _conversionService = new();
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
        StartConversionCommand = new AsyncRelayCommand(StartConversionAsync);
        TestSampleCommand = new AsyncRelayCommand(TestSampleAsync);
        OpenSampleCommand = new RelayCommand(OpenSample, CanOpenSample);

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

    [ObservableProperty]
    private string? _lastSamplePath;

    public ObservableCollection<QueueItemSummary> QueueItems { get; }

    public ObservableCollection<PropertyComparisonRow> ComparisonRows { get; }

    public ObservableCollection<string> QualityModes { get; }

    public ObservableCollection<string> ScaleModes { get; }

    public ObservableCollection<string> AspectModes { get; }

    public IAsyncRelayCommand ScanFilesCommand { get; }

    public IAsyncRelayCommand StartConversionCommand { get; }

    public IAsyncRelayCommand TestSampleCommand { get; }

    public IRelayCommand OpenSampleCommand { get; }

    partial void OnSelectedQueueItemChanged(QueueItemSummary? value)
    {
        RefreshComparisonRows(value);
        OpenSampleCommand.NotifyCanExecuteChanged();
    }

    partial void OnQualityModeChanged(string value) => RefreshPlannedOutput();

    partial void OnScaleModeChanged(string value) => RefreshPlannedOutput();

    partial void OnAspectModeChanged(string value) => RefreshPlannedOutput();

    partial void OnVideoBitrateChanged(string value) => RefreshPlannedOutput();

    partial void OnAudioBitrateChanged(string value) => RefreshPlannedOutput();

    partial void OnLastSamplePathChanged(string? value) => OpenSampleCommand.NotifyCanExecuteChanged();

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

    private async Task StartConversionAsync()
    {
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

        var settings = BuildSettings();
        var items = QueueItems.ToList();
        var converted = 0;

        foreach (var item in items)
        {
            if (item.MediaInfo is null)
            {
                continue;
            }

            ReplaceItem(item.SourcePath, current => CloneItem(current, current.MediaInfo, current.PlannedOutput, "processing"));
            ProgressMessage = $"Obrada: {currentDisplayName(item)}";

            try
            {
                var request = new ConversionRequest
                {
                    MediaInfo = item.MediaInfo,
                    Settings = settings,
                    OutputPath = item.OutputPath,
                    TimelineProject = item.TimelineProject
                };

                await _conversionService.ConvertAsync(_ffmpegPath, request);
                converted++;
                ReplaceItem(item.SourcePath, current => CloneItem(current, current.MediaInfo, current.PlannedOutput, "done"));
            }
            catch (Exception ex)
            {
                ReplaceItem(item.SourcePath, current => CloneItem(current, current.MediaInfo, current.PlannedOutput, "failed"));
                StatusMessage = $"Greska pri obradi {item.SourceFile}: {ex.Message}";
                LogMessage = ex.ToString();
                return;
            }
        }

        ProgressMessage = $"Konverzija zavrsena. Obradjeno: {converted}";
        StatusMessage = $"Start Conversion zavrsen. Done: {converted}";
        LogMessage = $"Output folder: {OutputFolder}";
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
        var start = SelectedQueueItem.MediaInfo.DurationSeconds > 150 ? 30 : 0;
        var duration = Math.Min(120, Math.Max(10, SelectedQueueItem.MediaInfo.DurationSeconds - start));
        var settings = BuildSettings();

        try
        {
            await _conversionService.ConvertAsync(_ffmpegPath, new ConversionRequest
            {
                MediaInfo = SelectedQueueItem.MediaInfo,
                Settings = settings,
                OutputPath = samplePath,
                TimelineProject = SelectedQueueItem.TimelineProject,
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
                PlannedOutput = planned,
                TimelineProject = item.TimelineProject
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
            TimelineProject = source.TimelineProject
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

    private static string currentDisplayName(QueueItemSummary item) => item.SourceFile;
}
