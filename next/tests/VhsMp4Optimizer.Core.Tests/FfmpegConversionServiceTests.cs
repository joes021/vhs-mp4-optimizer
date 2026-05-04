using System.Diagnostics;
using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Infrastructure.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class FfmpegConversionServiceTests : IDisposable
{
    private readonly string _rootPath;

    public FfmpegConversionServiceTests()
    {
        _rootPath = Path.Combine(Path.GetTempPath(), $"vhs-next-convert-{Guid.NewGuid():N}");
        Directory.CreateDirectory(_rootPath);
    }

    [Fact]
    public async Task ConvertAsync_should_finish_for_small_real_file_when_ffmpeg_is_available()
    {
        var ffmpegPath = FfmpegLocator.Resolve();
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath))
        {
            return;
        }

        var inputPath = await CreateRealVideoAsync("convert-source.avi", ffmpegPath);
        var outputPath = Path.Combine(_rootPath, "convert-source.mp4");
        var service = new FfmpegConversionService();
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(30));

        await service.ConvertAsync(ffmpegPath, new ConversionRequest
        {
            MediaInfo = new MediaInfo
            {
                SourceName = Path.GetFileName(inputPath),
                SourcePath = inputPath,
                Container = "avi",
                DurationSeconds = 2,
                DurationText = "00:00:02",
                SizeBytes = new FileInfo(inputPath).Length,
                SizeText = "--",
                OverallBitrateKbps = 0,
                OverallBitrateText = "--",
                VideoCodec = "mpeg4",
                Width = 320,
                Height = 240,
                Resolution = "320x240",
                DisplayAspectRatio = "4:3",
                SampleAspectRatio = "1:1",
                FrameRate = 25,
                FrameRateText = "25 fps",
                FrameCount = 50,
                VideoBitrateKbps = 0,
                VideoBitrateText = "--",
                AudioCodec = "mp3",
                AudioChannels = 2,
                AudioSampleRateHz = 48000,
                AudioBitrateKbps = 0,
                AudioBitrateText = "--",
                VideoSummary = "mpeg4 | 320x240 | 25 fps",
                AudioSummary = "mp3 | 2 ch"
            },
            Settings = new BatchSettings
            {
                InputPath = inputPath,
                OutputDirectory = _rootPath,
                QualityMode = VhsMp4Optimizer.Core.Services.QualityModes.SmallMp4H264,
                ScaleMode = VhsMp4Optimizer.Core.Services.ScaleModes.Original,
                AspectMode = VhsMp4Optimizer.Core.Services.AspectModes.Auto,
                VideoBitrate = "1200k",
                AudioBitrate = "128k"
            },
            OutputPath = outputPath
        }, null, timeout.Token);

        Assert.True(File.Exists(outputPath));
        Assert.True(new FileInfo(outputPath).Length > 0);
    }

    [Fact]
    public async Task ConvertAsync_should_create_multiple_parts_when_split_output_is_enabled()
    {
        var ffmpegPath = FfmpegLocator.Resolve();
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath))
        {
            return;
        }

        var inputPath = await CreateRealVideoAsync("split-source.avi", ffmpegPath, durationSeconds: 6);
        var outputPattern = Path.Combine(_rootPath, "split-source-part%03d.mp4");
        var service = new FfmpegConversionService();
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(45));

        await service.ConvertAsync(ffmpegPath, new ConversionRequest
        {
            MediaInfo = new MediaInfo
            {
                SourceName = Path.GetFileName(inputPath),
                SourcePath = inputPath,
                Container = "avi",
                DurationSeconds = 6,
                DurationText = "00:00:06",
                SizeBytes = new FileInfo(inputPath).Length,
                SizeText = "--",
                OverallBitrateKbps = 0,
                OverallBitrateText = "--",
                VideoCodec = "mpeg4",
                Width = 320,
                Height = 240,
                Resolution = "320x240",
                DisplayAspectRatio = "4:3",
                SampleAspectRatio = "1:1",
                FrameRate = 25,
                FrameRateText = "25 fps",
                FrameCount = 150,
                VideoBitrateKbps = 0,
                VideoBitrateText = "--",
                AudioCodec = "mp3",
                AudioChannels = 2,
                AudioSampleRateHz = 48000,
                AudioBitrateKbps = 0,
                AudioBitrateText = "--",
                VideoSummary = "mpeg4 | 320x240 | 25 fps",
                AudioSummary = "mp3 | 2 ch"
            },
            Settings = new BatchSettings
            {
                InputPath = inputPath,
                OutputDirectory = _rootPath,
                QualityMode = VhsMp4Optimizer.Core.Services.QualityModes.SmallMp4H264,
                ScaleMode = VhsMp4Optimizer.Core.Services.ScaleModes.Original,
                AspectMode = VhsMp4Optimizer.Core.Services.AspectModes.Auto,
                VideoBitrate = "1200k",
                AudioBitrate = "128k",
                SplitOutput = true,
                MaxPartGb = 0.00005
            },
            OutputPath = Path.Combine(_rootPath, "split-source-part001.mp4"),
            OutputPattern = outputPattern
        }, null, timeout.Token);

        var outputs = Directory.GetFiles(_rootPath, "split-source-part*.mp4", SearchOption.TopDirectoryOnly);
        Assert.True(outputs.Length >= 2, $"Ocekivana su najmanje 2 split fajla, a pronadjeno je {outputs.Length}.");
    }

    private async Task<string> CreateRealVideoAsync(string fileName, string ffmpegPath, int durationSeconds = 2)
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
                     "-t", durationSeconds.ToString(),
                     "-c:v", "mpeg4",
                     "-c:a", "mp3",
                     fullPath
                 })
        {
            startInfo.ArgumentList.Add(argument);
        }

        using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("ffmpeg test source proces nije pokrenut.");
        await process.WaitForExitAsync();
        var errorText = await process.StandardError.ReadToEndAsync();
        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException($"ffmpeg nije uspeo da napravi test video: {errorText}");
        }

        return fullPath;
    }

    public void Dispose()
    {
        if (Directory.Exists(_rootPath))
        {
            Directory.Delete(_rootPath, true);
        }
    }
}
