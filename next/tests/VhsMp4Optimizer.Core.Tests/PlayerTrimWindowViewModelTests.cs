using VhsMp4Optimizer.App.ViewModels;
using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Infrastructure.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class PlayerTrimWindowViewModelTests : IDisposable
{
    private readonly string _rootPath;
    public PlayerTrimWindowViewModelTests()
    {
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

    public void Dispose()
    {
        if (Directory.Exists(_rootPath))
        {
            Directory.Delete(_rootPath, true);
        }
    }

    private static QueueItemSummary BuildQueueItem()
    {
        var mediaInfo = new MediaInfo
        {
            SourceName = "clip.avi",
            SourcePath = @"C:\video\clip.avi",
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
