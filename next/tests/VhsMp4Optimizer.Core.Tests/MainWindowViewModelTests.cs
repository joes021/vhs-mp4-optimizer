using VhsMp4Optimizer.App.ViewModels;
using VhsMp4Optimizer.App.Services;
using VhsMp4Optimizer.App.Models;
using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Core.Services;
using VhsMp4Optimizer.Infrastructure.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class MainWindowViewModelTests : IDisposable
{
    private readonly string _rootPath;

    public MainWindowViewModelTests()
    {
        _rootPath = Path.Combine(Path.GetTempPath(), $"vhs-next-mainvm-{Guid.NewGuid():N}");
        Directory.CreateDirectory(_rootPath);
    }

    [Fact]
    public async Task UseSelectedFilesAsync_should_auto_scan_and_fill_queue_and_planned_output()
    {
        var filePath = CreateFile("sample.avi");
        var scanner = new FakeSourceScanService(BuildQueueItem(filePath), BuildQueueItem(CreateFile("sample-2.avi")));
        var viewModel = new MainWindowViewModel(scanner, ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe");

        await viewModel.UseSelectedFilesAsync([filePath]);

        Assert.Equal(2, viewModel.QueueItems.Count);
        Assert.NotNull(viewModel.SelectedQueueItem);
        Assert.Equal(Path.GetFileName(filePath), viewModel.SelectedQueueItem!.SourceFile);
        Assert.Contains("pronadjeno 2", viewModel.StatusMessage, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("sample.avi", viewModel.SelectionHint, StringComparison.OrdinalIgnoreCase);
        Assert.Contains(viewModel.ComparisonRows, row => row.Label == "File" && row.InputValue == "sample.avi");
        Assert.False(viewModel.QueueItems[0].IsAlternate);
        Assert.True(viewModel.QueueItems[1].IsAlternate);
        Assert.Single(scanner.ScanCalls);
        Assert.Equal(filePath, scanner.ScanCalls[0].ExplicitPaths!.Single());
    }

    [Fact]
    public async Task UseDroppedPathsAsync_should_accept_folder_and_auto_scan_it()
    {
        var folderPath = Path.Combine(_rootPath, "folder-drop");
        Directory.CreateDirectory(folderPath);
        var scanner = new FakeSourceScanService(BuildQueueItem(Path.Combine(folderPath, "clip.mp4")));
        var viewModel = new MainWindowViewModel(scanner, ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe");

        await viewModel.UseDroppedPathsAsync([folderPath]);

        Assert.Single(viewModel.QueueItems);
        Assert.Equal(Path.GetFullPath(folderPath), viewModel.InputFolder);
        Assert.Contains("ceo folder", viewModel.SelectionHint, StringComparison.OrdinalIgnoreCase);
        Assert.Single(scanner.ScanCalls);
        Assert.Null(scanner.ScanCalls[0].ExplicitPaths);
        Assert.Equal(Path.GetFullPath(folderPath), scanner.ScanCalls[0].Settings.InputPath);
    }

    [Fact]
    public async Task StartConversionCommand_should_convert_queued_items_and_mark_them_done()
    {
        var filePath = CreateFile("convert-me.avi");
        var scanner = new FakeSourceScanService(BuildQueueItem(filePath));
        var conversionService = new FakeConversionService { CreateOutputFile = true };
        var viewModel = new MainWindowViewModel(
            scanner,
            conversionService,
            ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe");

        await viewModel.UseSelectedFilesAsync([filePath]);
        await viewModel.StartConversionCommand.ExecuteAsync(null);

        Assert.Single(conversionService.Requests);
        Assert.Equal(filePath, conversionService.Requests[0].MediaInfo.SourcePath);
        Assert.Equal("done", viewModel.QueueItems.Single().Status);
        Assert.Contains("Done: 1", viewModel.StatusMessage, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task StartConversionCommand_should_resolve_auto_encode_engine_to_best_ready_hardware()
    {
        var filePath = CreateFile("convert-auto-engine.avi");
        var scanner = new FakeSourceScanService(BuildQueueItem(filePath));
        var conversionService = new FakeConversionService { CreateOutputFile = true };
        var viewModel = new MainWindowViewModel(
            scanner,
            conversionService,
            ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe",
            inspectEncodeSupportAsync: _ => Task.FromResult(new EncodeSupportReport
            {
                Summary = "Encode support: preporuka NVIDIA NVENC",
                PreferredEngine = EncodeEngines.NvidiaNvenc,
                PreferredEngineReason = "NVIDIA GPU i NVENC encoder su spremni."
            }));

        await viewModel.UseSelectedFilesAsync([filePath]);
        viewModel.EncodeEngine = EncodeEngines.Auto;
        await viewModel.StartConversionCommand.ExecuteAsync(null);

        Assert.Single(conversionService.Requests);
        Assert.Equal(EncodeEngines.NvidiaNvenc, conversionService.Requests[0].Settings.EncodeEngine);
    }

    [Fact]
    public async Task StartConversionCommand_should_choose_hevc_capable_auto_engine_for_hevc_quality_mode()
    {
        var filePath = CreateFile("convert-auto-hevc.avi");
        var scanner = new FakeSourceScanService(BuildQueueItem(filePath));
        var conversionService = new FakeConversionService { CreateOutputFile = true };
        var viewModel = new MainWindowViewModel(
            scanner,
            conversionService,
            ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe",
            inspectEncodeSupportAsync: _ => Task.FromResult(new EncodeSupportReport
            {
                Summary = "Encode support: NVIDIA H.264, Intel HEVC",
                PreferredEngine = EncodeEngines.NvidiaNvenc,
                PreferredEngineReason = "Generic preferred engine",
                Engines =
                [
                    new EncodeEngineSupportStatus
                    {
                        EngineName = "NVIDIA NVENC",
                        IsReady = true,
                        Status = "ready",
                        SupportsH264 = true,
                        SupportsHevc = false
                    },
                    new EncodeEngineSupportStatus
                    {
                        EngineName = "Intel QSV",
                        IsReady = true,
                        Status = "ready",
                        SupportsH264 = true,
                        SupportsHevc = true
                    }
                ]
            }));

        await viewModel.UseSelectedFilesAsync([filePath]);
        viewModel.QualityMode = QualityModes.HevcH265Smaller;
        viewModel.EncodeEngine = EncodeEngines.Auto;
        await viewModel.StartConversionCommand.ExecuteAsync(null);

        Assert.Single(conversionService.Requests);
        Assert.Equal(EncodeEngines.IntelQsv, conversionService.Requests[0].Settings.EncodeEngine);
        Assert.Contains("H.265/HEVC", viewModel.EncodeEngineHint, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void ApplySessionState_should_not_restore_input_and_output_paths_on_startup()
    {
        var viewModel = new MainWindowViewModel(ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe");

        viewModel.ApplySessionState(new AppSessionState
        {
            InputFolder = @"F:\Ulaz",
            OutputFolder = @"F:\Izlaz",
            FfmpegPath = @"C:\tools\ffmpeg\bin\ffmpeg.exe"
        });

        Assert.Equal(string.Empty, viewModel.InputFolder);
        Assert.Equal(string.Empty, viewModel.OutputFolder);
        Assert.Equal(@"C:\tools\ffmpeg\bin\ffmpeg.exe", viewModel.ResolvedFfmpegPath);
    }

    [Fact]
    public void Selecting_workflow_preset_should_not_reset_deinterlace_mode()
    {
        var viewModel = new MainWindowViewModel(ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe");

        viewModel.DeinterlaceMode = DeinterlaceModes.Yadif;
        viewModel.SelectedPreset = WorkflowPresetService.Archive;

        Assert.Equal(DeinterlaceModes.Yadif, viewModel.DeinterlaceMode);
    }

    [Fact]
    public void MainWindowViewModel_should_start_with_default_sample_clip_values()
    {
        var viewModel = new MainWindowViewModel(ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe");

        Assert.Equal("00:00:00", viewModel.SampleStartText);
        Assert.Equal("00:02:00", viewModel.SampleDurationText);
    }

    [Fact]
    public async Task StartConversionCommand_should_write_report_and_surface_output_and_report_paths_in_log()
    {
        var filePath = CreateFile("convert-report.avi");
        var scanner = new FakeSourceScanService(BuildQueueItem(filePath));
        var conversionService = new FakeConversionService { CreateOutputFile = true };
        var reportService = new FakeConversionReportService(_rootPath);
        var viewModel = new MainWindowViewModel(
            scanner,
            conversionService,
            ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe",
            launcher: null,
            reportService: reportService);

        await viewModel.UseSelectedFilesAsync([filePath]);
        await viewModel.StartConversionCommand.ExecuteAsync(null);

        var converted = viewModel.QueueItems.Single();
        Assert.NotNull(converted.ReportPath);
        Assert.True(File.Exists(converted.ReportPath!));
        Assert.Contains(converted.OutputPath, viewModel.LogMessage, StringComparison.OrdinalIgnoreCase);
        Assert.Contains(converted.ReportPath!, viewModel.LogMessage, StringComparison.OrdinalIgnoreCase);
        Assert.Single(reportService.ItemReportCalls);
        Assert.Single(reportService.BatchReportCalls);
    }

    [Fact]
    public async Task StartConversionCommand_should_surface_progress_percent_and_eta()
    {
        var filePath = CreateFile("progress.avi");
        var scanner = new FakeSourceScanService(BuildQueueItem(filePath));
        var conversionService = new FakeConversionService
        {
            ProgressToReport =
            [
                new ConversionProgressInfo(0.25, TimeSpan.FromSeconds(15), TimeSpan.FromSeconds(45), "1.0x"),
                new ConversionProgressInfo(0.75, TimeSpan.FromSeconds(45), TimeSpan.FromSeconds(15), "1.1x"),
                new ConversionProgressInfo(1.0, TimeSpan.FromSeconds(60), TimeSpan.Zero, "1.0x")
            ]
        };
        var viewModel = new MainWindowViewModel(
            scanner,
            conversionService,
            ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe");

        await viewModel.UseSelectedFilesAsync([filePath]);
        await viewModel.StartConversionCommand.ExecuteAsync(null);

        Assert.Equal(100, viewModel.ConversionProgressPercent, 3);
        Assert.Contains("ETA", viewModel.ProgressMessage, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("progress.avi", viewModel.CurrentConversionItemText, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task StartConversionCommand_should_create_real_output_file_when_ffmpeg_is_available()
    {
        var ffmpegPath = FfmpegLocator.Resolve();
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath))
        {
            return;
        }

        var filePath = await CreateRealVideoAsync("real-convert-source.avi", ffmpegPath);
        var viewModel = new MainWindowViewModel(ffmpegPath: ffmpegPath);

        await viewModel.UseSelectedFilesAsync([filePath]);
        viewModel.SetOutputFolderPath(_rootPath);
        await viewModel.StartConversionCommand.ExecuteAsync(null);

        var converted = viewModel.QueueItems.Single();
        Assert.Equal("done", converted.Status);
        Assert.True(File.Exists(converted.OutputPath));
    }

    [Fact]
    public void StartConversionCommand_should_be_disabled_without_queued_items()
    {
        var viewModel = new MainWindowViewModel(ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe");

        Assert.False(viewModel.StartConversionCommand.CanExecute(null));
    }

    [Fact]
    public async Task TestSampleCommand_should_be_enabled_after_scan_selects_queue_item()
    {
        var filePath = CreateFile("sample-enabled.avi");
        var scanner = new FakeSourceScanService(BuildQueueItem(filePath));
        var viewModel = new MainWindowViewModel(scanner, ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe");

        Assert.False(viewModel.TestSampleCommand.CanExecute(null));

        await viewModel.UseSelectedFilesAsync([filePath]);

        Assert.True(viewModel.TestSampleCommand.CanExecute(null));
        Assert.True(viewModel.StartConversionCommand.CanExecute(null));
    }

    [Fact]
    public async Task TestSampleCommand_should_use_default_sample_start_and_duration_immediately()
    {
        var filePath = CreateFile("sample-defaults.avi");
        var scanner = new FakeSourceScanService(BuildQueueItem(filePath));
        var conversionService = new FakeConversionService { CreateOutputFile = true };
        var viewModel = new MainWindowViewModel(
            scanner,
            conversionService,
            ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe");

        await viewModel.UseSelectedFilesAsync([filePath]);
        await viewModel.TestSampleCommand.ExecuteAsync(null);

        Assert.Single(conversionService.Requests);
        var request = conversionService.Requests[0];
        Assert.True(request.IsSample);
        Assert.Equal(0, request.SampleStartSeconds);
        Assert.Equal(120, request.SampleDurationSeconds);
    }

    [Fact]
    public async Task Save_and_load_output_settings_should_roundtrip_current_output_configuration()
    {
        var viewModel = new MainWindowViewModel(ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe");
        var settingsPath = Path.Combine(_rootPath, "output-settings.json");

        viewModel.SelectedPreset = WorkflowPresetService.Custom;
        viewModel.QualityMode = QualityModes.HevcForNewerDevices;
        viewModel.ScaleMode = ScaleModes.Pal576p;
        viewModel.AspectMode = AspectModes.KeepOriginal;
        viewModel.DeinterlaceMode = DeinterlaceModes.Yadif;
        viewModel.DenoiseMode = DenoiseModes.Medium;
        viewModel.EncodeEngine = EncodeEngines.Auto;
        viewModel.VideoBitrate = "4200k";
        viewModel.AudioBitrate = "128k";
        viewModel.SplitOutput = true;
        viewModel.MaxPartGb = 2.9;
        viewModel.SampleStartText = "00:00:10";
        viewModel.SampleDurationText = "00:01:00";

        await viewModel.SaveOutputSettingsAsync(settingsPath);

        viewModel.QualityMode = QualityModes.StandardVhs;
        viewModel.ScaleMode = ScaleModes.Original;
        viewModel.AspectMode = AspectModes.Auto;
        viewModel.DeinterlaceMode = DeinterlaceModes.Off;
        viewModel.DenoiseMode = DenoiseModes.Off;
        viewModel.VideoBitrate = "5000k";
        viewModel.AudioBitrate = "160k";
        viewModel.SplitOutput = false;
        viewModel.MaxPartGb = 3.8;
        viewModel.SampleStartText = "00:00:00";
        viewModel.SampleDurationText = "00:02:00";

        await viewModel.LoadOutputSettingsAsync(settingsPath);

        Assert.Equal(QualityModes.HevcForNewerDevices, viewModel.QualityMode);
        Assert.Equal(ScaleModes.Pal576p, viewModel.ScaleMode);
        Assert.Equal(AspectModes.KeepOriginal, viewModel.AspectMode);
        Assert.Equal(DeinterlaceModes.Yadif, viewModel.DeinterlaceMode);
        Assert.Equal(DenoiseModes.Medium, viewModel.DenoiseMode);
        Assert.Equal("4200k", viewModel.VideoBitrate);
        Assert.Equal("128k", viewModel.AudioBitrate);
        Assert.True(viewModel.SplitOutput);
        Assert.Equal(2.9, viewModel.MaxPartGb);
        Assert.Equal("00:00:10", viewModel.SampleStartText);
        Assert.Equal("00:01:00", viewModel.SampleDurationText);
    }

    [Fact]
    public async Task OpenConvertedFileCommand_should_open_selected_done_output_file()
    {
        var filePath = CreateFile("open-output.avi");
        var scanner = new FakeSourceScanService(BuildQueueItem(filePath));
        var conversionService = new FakeConversionService { CreateOutputFile = true };
        var launcher = new FakeExternalLauncher();
        var reportService = new FakeConversionReportService(_rootPath);
        var viewModel = new MainWindowViewModel(
            scanner,
            conversionService,
            ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe",
            launcher: launcher,
            reportService: reportService);

        await viewModel.UseSelectedFilesAsync([filePath]);
        await viewModel.StartConversionCommand.ExecuteAsync(null);

        viewModel.OpenConvertedFileCommand.Execute(null);

        Assert.Single(launcher.OpenedPaths);
        Assert.Equal(viewModel.QueueItems.Single().OutputPath, launcher.OpenedPaths[0]);
    }

    [Fact]
    public async Task OpenReportCommand_should_open_selected_report_file()
    {
        var filePath = CreateFile("open-report.avi");
        var scanner = new FakeSourceScanService(BuildQueueItem(filePath));
        var conversionService = new FakeConversionService { CreateOutputFile = true };
        var launcher = new FakeExternalLauncher();
        var reportService = new FakeConversionReportService(_rootPath);
        var viewModel = new MainWindowViewModel(
            scanner,
            conversionService,
            ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe",
            launcher: launcher,
            reportService: reportService);

        await viewModel.UseSelectedFilesAsync([filePath]);
        await viewModel.StartConversionCommand.ExecuteAsync(null);

        viewModel.OpenReportCommand.Execute(null);

        Assert.Single(launcher.OpenedPaths);
        Assert.Equal(viewModel.QueueItems.Single().ReportPath, launcher.OpenedPaths[0]);
    }

    [Fact]
    public void ApplySystemResourceSnapshot_should_update_usage_labels()
    {
        var viewModel = new MainWindowViewModel(ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe");

        viewModel.ApplySystemResourceSnapshot(new SystemResourceSnapshot
        {
            CpuPercent = 37.4,
            GpuPercent = 18.2,
            RamPercent = 62.8,
            StoragePercent = 54.5,
            StorageLabel = "F:"
        });

        Assert.Equal("CPU 37%", viewModel.CpuUsageText);
        Assert.Equal("GPU 18%", viewModel.GpuUsageText);
        Assert.Equal("RAM 63%", viewModel.RamUsageText);
        Assert.Equal("Storage F: 55%", viewModel.StorageUsageText);
    }

    [Fact]
    public void ApplyEncodeSupportReport_should_surface_summary_and_detailed_log()
    {
        var viewModel = new MainWindowViewModel(ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe");
        var report = new EncodeSupportReport
        {
            Summary = "Encode support: CPU ready | NVIDIA NVENC ready | Intel QSV driver missing",
            PreferredEngine = EncodeEngines.NvidiaNvenc,
            PreferredEngineReason = "NVIDIA GPU i NVENC encoder su spremni.",
            Details =
            [
                "CPU: ready",
                "NVIDIA NVENC: ready",
                "Intel QSV: install Intel graphics driver"
            ],
            RepairActions =
            [
                new SupportRepairAction
                {
                    Label = "Install Intel driver",
                    Kind = SupportRepairActionKind.Url,
                    Target = "https://www.intel.com/content/www/us/en/support/detect.html"
                }
            ]
        };

        viewModel.ApplyEncodeSupportReport(report);

        Assert.Contains("Encode support:", viewModel.StatusMessage, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("NVIDIA NVENC", viewModel.EncodeEngineHint, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("NVIDIA NVENC: ready", viewModel.LogMessage, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("Install Intel driver", viewModel.LogMessage, StringComparison.OrdinalIgnoreCase);
    }

    public void Dispose()
    {
        if (Directory.Exists(_rootPath))
        {
            Directory.Delete(_rootPath, true);
        }
    }

    private string CreateFile(string fileName)
    {
        var fullPath = Path.Combine(_rootPath, fileName);
        File.WriteAllText(fullPath, "stub");
        return fullPath;
    }

    private async Task<string> CreateRealVideoAsync(string fileName, string ffmpegPath)
    {
        var fullPath = Path.Combine(_rootPath, fileName);
        var startInfo = new System.Diagnostics.ProcessStartInfo
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

        using var process = System.Diagnostics.Process.Start(startInfo) ?? throw new InvalidOperationException("ffmpeg test source proces nije pokrenut.");
        await process.WaitForExitAsync();
        var errorText = await process.StandardError.ReadToEndAsync();
        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException($"ffmpeg nije uspeo da napravi test video: {errorText}");
        }

        return fullPath;
    }

    private static QueueItemSummary BuildQueueItem(string sourcePath)
    {
        var sourceFile = Path.GetFileName(sourcePath);
        return new QueueItemSummary
        {
            SourceFile = sourceFile,
            SourcePath = sourcePath,
            OutputFile = Path.GetFileNameWithoutExtension(sourceFile) + ".mp4",
            OutputPath = Path.Combine(Path.GetDirectoryName(sourcePath)!, Path.GetFileNameWithoutExtension(sourceFile) + ".mp4"),
            OutputPattern = Path.Combine(Path.GetDirectoryName(sourcePath)!, Path.GetFileNameWithoutExtension(sourceFile) + ".mp4"),
            Container = "avi",
            Resolution = "720x576",
            Duration = "00:10:00",
            Video = "h264 | 720x576 | 25 fps",
            Audio = "aac | 2 ch | 192k",
            Status = "queued",
            MediaInfo = new MediaInfo
            {
                SourceName = sourceFile,
                SourcePath = sourcePath,
                Container = "avi",
                DurationSeconds = 600,
                DurationText = "00:10:00",
                SizeBytes = 104857600,
                SizeText = "100 MB",
                OverallBitrateKbps = 5000,
                OverallBitrateText = "5000 kbps",
                VideoCodec = "h264",
                Width = 720,
                Height = 576,
                Resolution = "720x576",
                DisplayAspectRatio = "4:3",
                SampleAspectRatio = "16:15",
                FrameRate = 25,
                FrameRateText = "25 fps",
                FrameCount = 15000,
                VideoBitrateKbps = 4200,
                VideoBitrateText = "4200 kbps",
                AudioCodec = "aac",
                AudioChannels = 2,
                AudioSampleRateHz = 48000,
                AudioBitrateKbps = 192,
                AudioBitrateText = "192 kbps",
                VideoSummary = "h264 | 720x576 | 25 fps",
                AudioSummary = "aac | 2 ch | 192 kbps"
            },
            PlannedOutput = new OutputPlanSummary
            {
                DisplayOutputName = Path.GetFileNameWithoutExtension(sourceFile) + ".mp4",
                Container = "mp4",
                Resolution = "768x576",
                DurationText = "00:10:00",
                VideoCodecLabel = "h264",
                VideoBitrateComparisonText = "3500k",
                AudioCodecText = "aac",
                AudioBitrateText = "192k",
                BitrateText = "3692 kbps",
                EncodeEngineText = "CPU",
                EstimatedSizeText = "275 MB",
                UsbNoteText = "FAT32 OK",
                SplitModeText = "No split",
                CropText = "--",
                AspectText = "4:3",
                OutputWidth = 768,
                OutputHeight = 576
            }
        };
    }

    private sealed class FakeSourceScanService : ISourceScanService
    {
        private readonly IReadOnlyList<QueueItemSummary> _items;

        public FakeSourceScanService(params QueueItemSummary[] items)
        {
            _items = items;
        }

        public List<(BatchSettings Settings, IReadOnlyList<string>? ExplicitPaths)> ScanCalls { get; } = [];

        public IReadOnlyList<QueueItemSummary> Scan(BatchSettings settings, string ffmpegPath, IReadOnlyList<string>? explicitSourcePaths = null)
        {
            ScanCalls.Add((settings, explicitSourcePaths));
            return _items;
        }

        public string ResolveOutputDirectory(string inputPath, string outputDirectory)
        {
            if (!string.IsNullOrWhiteSpace(outputDirectory))
            {
                return Path.GetFullPath(outputDirectory);
            }

            if (Directory.Exists(inputPath))
            {
                return Path.Combine(Path.GetFullPath(inputPath), "vhs-mp4-output");
            }

            return Path.Combine(Path.GetDirectoryName(Path.GetFullPath(inputPath))!, "vhs-mp4-output");
        }
    }

    private sealed class FakeConversionService : IConversionService
    {
        public List<ConversionRequest> Requests { get; } = [];
        public IReadOnlyList<ConversionProgressInfo> ProgressToReport { get; init; } = [];
        public bool CreateOutputFile { get; init; }

        public Task ConvertAsync(string ffmpegPath, ConversionRequest request, IProgress<ConversionProgressInfo>? progress = null, CancellationToken cancellationToken = default)
        {
            Requests.Add(request);
            foreach (var update in ProgressToReport)
            {
                progress?.Report(update);
            }

            if (CreateOutputFile)
            {
                Directory.CreateDirectory(Path.GetDirectoryName(request.OutputPath)!);
                File.WriteAllText(request.OutputPath, "converted");
            }

            return Task.CompletedTask;
        }
    }

    private sealed class FakeExternalLauncher : IExternalLauncher
    {
        public List<string> OpenedPaths { get; } = [];

        public void OpenPath(string path)
        {
            OpenedPaths.Add(path);
        }
    }

    private sealed class FakeConversionReportService : IConversionReportService
    {
        private readonly string _rootPath;

        public FakeConversionReportService(string rootPath)
        {
            _rootPath = rootPath;
        }

        public List<string> ItemReportCalls { get; } = [];

        public List<string> BatchReportCalls { get; } = [];

        public Task<string> WriteItemReportAsync(string outputDirectory, string presetName, ConversionRequest request, QueueItemSummary item, IReadOnlyList<string> ffmpegArguments, TimeSpan elapsed, CancellationToken cancellationToken = default)
        {
            var path = Path.Combine(_rootPath, $"{Path.GetFileNameWithoutExtension(item.SourceFile)}-report.txt");
            File.WriteAllText(path, string.Join(Environment.NewLine, ffmpegArguments));
            ItemReportCalls.Add(path);
            return Task.FromResult(path);
        }

        public Task<string> WriteBatchReportAsync(string outputDirectory, string presetName, BatchSettings settings, IReadOnlyList<QueueItemSummary> processedItems, int convertedCount, int failedCount, CancellationToken cancellationToken = default)
        {
            var path = Path.Combine(_rootPath, "batch-report.txt");
            File.WriteAllText(path, $"converted={convertedCount};failed={failedCount}");
            BatchReportCalls.Add(path);
            return Task.FromResult(path);
        }
    }
}
