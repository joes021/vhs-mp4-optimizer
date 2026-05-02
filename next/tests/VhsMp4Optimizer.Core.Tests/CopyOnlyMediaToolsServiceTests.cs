using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Infrastructure.Services;

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

    private static MediaInfo CreateMediaInfo(long sizeBytes, double durationSeconds)
    {
        return new MediaInfo
        {
            SourceName = "source.mp4",
            SourcePath = @"F:\source.mp4",
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
}
