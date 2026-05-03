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

    private async Task<string> CreateRealVideoAsync(string fileName, string ffmpegPath)
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
