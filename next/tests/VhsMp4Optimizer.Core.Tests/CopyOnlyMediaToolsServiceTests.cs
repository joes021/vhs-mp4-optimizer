using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Infrastructure.Services;
using System.Diagnostics;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class CopyOnlyMediaToolsServiceTests
{
    [Fact]
    public void PlanSplit_should_create_at_least_two_parts()
    {
        var service = new CopyOnlyMediaToolsService();
        var mediaInfo = CreateMediaInfo(sizeBytes: 8L * 1024 * 1024 * 1024, durationSeconds: 4000);

        var parts = service.PlanSplit(mediaInfo, @"F:\out", 3.8);

        Assert.True(parts.Count >= 2);
        Assert.Equal(0, parts[0].StartSeconds);
        Assert.True(parts.Sum(part => part.DurationSeconds) >= 3999.9);
        Assert.All(parts, part => Assert.Contains("-part", part.OutputPath));
    }

    [Fact]
    public void BuildConcatListContent_should_escape_single_quotes()
    {
        var content = CopyOnlyMediaToolsService.BuildConcatListContent(
        [
            @"F:\Video 1.mp4",
            @"F:\Azdaha's tape.mp4"
        ]);

        Assert.Contains("file 'F:\\Video 1.mp4'", content);
        Assert.Contains("file 'F:\\Azdaha'\\''s tape.mp4'", content);
    }

    [Fact]
    public void BuildJoinArguments_should_use_concat_copy_mode()
    {
        var args = CopyOnlyMediaToolsService.BuildJoinArguments(@"F:\join-list.txt", @"F:\out\joined.mp4");

        Assert.Contains("-f", args);
        Assert.Contains("concat", args);
        Assert.Contains("-c", args);
        Assert.Contains("copy", args);
    }

    [Fact]
    public async Task SplitAsync_should_create_multiple_real_parts_when_ffmpeg_is_available()
    {
        var ffmpegPath = FfmpegLocator.Resolve();
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath))
        {
            return;
        }

        var rootPath = Path.Combine(Path.GetTempPath(), $"vhs-next-copy-split-{Guid.NewGuid():N}");
        Directory.CreateDirectory(rootPath);

        try
        {
            var inputPath = await CreateRealDvAviAsync(rootPath, ffmpegPath);
            var mediaInfo = CreateMediaInfo(
                sizeBytes: new FileInfo(inputPath).Length,
                durationSeconds: 12,
                sourcePath: inputPath,
                sourceName: Path.GetFileName(inputPath));
            var service = new CopyOnlyMediaToolsService();

            var outputs = await service.SplitAsync(ffmpegPath, mediaInfo, rootPath, 0.02);

            Assert.True(outputs.Count >= 2, $"Ocekivana su najmanje 2 dela, a pronadjeno je {outputs.Count}.");
            Assert.All(outputs, output =>
            {
                Assert.True(File.Exists(output), $"Split izlaz ne postoji: {output}");
                Assert.True(new FileInfo(output).Length > 0, $"Split izlaz je prazan: {output}");
            });
        }
        finally
        {
            if (Directory.Exists(rootPath))
            {
                Directory.Delete(rootPath, true);
            }
        }
    }

    private static MediaInfo CreateMediaInfo(long sizeBytes, double durationSeconds, string sourcePath = @"F:\source.mp4", string sourceName = "source.mp4")
    {
        return new MediaInfo
        {
            SourceName = sourceName,
            SourcePath = sourcePath,
            Container = "mov,mp4,m4a,3gp,3g2,mj2",
            DurationSeconds = durationSeconds,
            DurationText = "01:06:40",
            SizeBytes = sizeBytes,
            SizeText = "8.0 GB",
            OverallBitrateKbps = 16000,
            OverallBitrateText = "16000 kbps",
            VideoCodec = "h264",
            Width = 1920,
            Height = 1080,
            Resolution = "1920x1080",
            DisplayAspectRatio = "16:9",
            SampleAspectRatio = "1:1",
            FrameRate = 25,
            FrameRateText = "25 fps",
            FrameCount = 100000,
            VideoBitrateKbps = 14000,
            VideoBitrateText = "14000 kbps",
            AudioCodec = "aac",
            AudioChannels = 2,
            AudioSampleRateHz = 48000,
            AudioBitrateKbps = 192,
            AudioBitrateText = "192 kbps",
            VideoSummary = "h264 | 1920x1080 | 16:9 | 25 fps",
            AudioSummary = "aac | 2 ch | 48000 Hz | 192 kbps"
        };
    }

    private static async Task<string> CreateRealDvAviAsync(string rootPath, string ffmpegPath)
    {
        var fullPath = Path.Combine(rootPath, "copy-split-source.avi");
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
                     "-i", "testsrc=size=720x576:rate=25",
                     "-f", "lavfi",
                     "-i", "sine=frequency=1000:sample_rate=48000",
                     "-t", "12",
                     "-c:v", "dvvideo",
                     "-pix_fmt", "yuv420p",
                     "-c:a", "pcm_s16le",
                     fullPath
                 })
        {
            startInfo.ArgumentList.Add(argument);
        }

        using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("ffmpeg nije pokrenut za copy split test source.");
        var outputTask = process.StandardOutput.ReadToEndAsync();
        var errorTask = process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();
        _ = await outputTask;
        var errorText = await errorTask;

        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException($"ffmpeg nije uspeo da napravi DV AVI test source: {errorText}");
        }

        return fullPath;
    }
}
