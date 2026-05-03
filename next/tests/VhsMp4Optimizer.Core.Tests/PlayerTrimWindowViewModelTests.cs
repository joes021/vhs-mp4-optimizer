using VhsMp4Optimizer.App.ViewModels;
using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Infrastructure.Services;
using System.Diagnostics;
using System.Reflection;

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

    [Fact]
    public async Task Changing_preview_virtual_position_while_paused_should_request_new_preview_frame()
    {
        var queueItem = BuildQueueItem();
        var requestedSeconds = new List<double>();
        var previewPath = CreateTinyPng("preview.png");
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe",
            (_, _) => { },
            new FakePreviewFrameService((_, _, sourceSeconds, _, _) =>
            {
                requestedSeconds.Add(sourceSeconds);
                return previewPath;
            }),
            autoLoadPreview: false);

        viewModel.PreviewVirtualSeconds = 12;
        await Task.Delay(250);

        Assert.Contains(requestedSeconds, value => Math.Abs(value - 12d) < 0.01d);
    }

    [Fact]
    public async Task PrepareForDisplayAsync_should_render_initial_preview_before_window_shows()
    {
        var queueItem = BuildQueueItem();
        var previewPath = CreateTinyPng("initial-preview.png");
        var previewRequests = 0;
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath: @"C:\ffmpeg\bin\ffmpeg.exe",
            (_, _) => { },
            new FakePreviewFrameService((_, _, _, _, _) =>
            {
                previewRequests++;
                return previewPath;
            }),
            autoLoadPreview: false);

        await viewModel.PrepareForDisplayAsync();

        Assert.Equal(1, previewRequests);
        Assert.DoesNotContain("nije dostupan", viewModel.EditorHint, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void PlayCommand_should_keep_media_instance_alive_for_real_playback()
    {
        var ffmpegPath = FfmpegLocator.Resolve();
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath))
        {
            return;
        }

        var sourcePath = CreateRealVideo("playback-source.avi", ffmpegPath);
        var queueItem = BuildQueueItem(sourcePath);
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.PlayCommand.Execute(null);

        var playbackMediaField = typeof(PlayerTrimWindowViewModel).GetField("_playbackMedia", BindingFlags.Instance | BindingFlags.NonPublic);
        Assert.NotNull(playbackMediaField);
        Assert.NotNull(playbackMediaField!.GetValue(viewModel));
    }

    [Fact]
    public void PlayCommand_should_reuse_existing_media_for_same_source()
    {
        var ffmpegPath = FfmpegLocator.Resolve();
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath))
        {
            return;
        }

        var sourcePath = CreateRealVideo("playback-source-reuse.avi", ffmpegPath);
        var queueItem = BuildQueueItem(sourcePath);
        var viewModel = new PlayerTrimWindowViewModel(
            queueItem,
            ffmpegPath,
            (_, _) => { },
            autoLoadPreview: false);

        viewModel.PlayCommand.Execute(null);
        viewModel.PauseCommand.Execute(null);

        var playbackMediaField = typeof(PlayerTrimWindowViewModel).GetField("_playbackMedia", BindingFlags.Instance | BindingFlags.NonPublic);
        Assert.NotNull(playbackMediaField);
        var firstMedia = playbackMediaField!.GetValue(viewModel);

        viewModel.PlayCommand.Execute(null);
        var secondMedia = playbackMediaField.GetValue(viewModel);

        Assert.Same(firstMedia, secondMedia);
    }

    public void Dispose()
    {
        if (Directory.Exists(_rootPath))
        {
            Directory.Delete(_rootPath, true);
        }
    }

    private string CreateRealVideo(string fileName, string ffmpegPath)
    {
        var fullPath = Path.Combine(_rootPath, fileName);
        var startInfo = new ProcessStartInfo
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

        using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("ffmpeg test source proces nije pokrenut.");
        process.WaitForExit();
        var errorText = process.StandardError.ReadToEnd();
        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException($"ffmpeg nije uspeo da napravi playback test video: {errorText}");
        }

        return fullPath;
    }

    private string CreateTinyPng(string fileName)
    {
        var fullPath = Path.Combine(_rootPath, fileName);
        var bytes = Convert.FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO5yR0YAAAAASUVORK5CYII=");
        File.WriteAllBytes(fullPath, bytes);
        return fullPath;
    }

    private static QueueItemSummary BuildQueueItem(string sourcePath = @"C:\video\clip.avi")
    {
        var mediaInfo = new MediaInfo
        {
            SourceName = "clip.avi",
            SourcePath = sourcePath,
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
