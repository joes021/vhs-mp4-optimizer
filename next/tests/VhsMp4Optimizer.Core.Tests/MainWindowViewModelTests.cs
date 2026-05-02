using VhsMp4Optimizer.App.ViewModels;
using VhsMp4Optimizer.Core.Models;
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
}
