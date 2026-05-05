using System.Reflection;
using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Infrastructure.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class PreviewFrameServiceTests
{
    [Theory]
    [InlineData("Potpisivanje Knjige - .avi", "Potpisivanje Knjige -")]
    [InlineData("test....avi", "test")]
    [InlineData("clip<>:\"/\\\\|?*.avi", "clip")]
    [InlineData("   .avi", "preview-source")]
    public void SanitizePreviewCacheComponent_should_remove_invalid_trailing_path_characters(string sourceName, string expected)
    {
        var method = typeof(PreviewFrameService).GetMethod(
            "SanitizePreviewCacheComponent",
            BindingFlags.Static | BindingFlags.NonPublic | BindingFlags.Public);

        Assert.NotNull(method);

        var actual = (string?)method!.Invoke(null, new object?[] { sourceName });

        Assert.Equal(expected, actual);
    }

    [Fact]
    public void BuildTransformCacheSuffix_should_change_when_crop_or_aspect_changes()
    {
        var method = typeof(PreviewFrameService).GetMethod(
            "BuildTransformCacheSuffix",
            BindingFlags.Static | BindingFlags.NonPublic | BindingFlags.Public);

        Assert.NotNull(method);

        var baseSuffix = (string?)method!.Invoke(null, [null]);
        var croppedSuffix = (string?)method.Invoke(null, [new ItemTransformSettings
        {
            AspectMode = "Force 4:3",
            Crop = new CropSettings
            {
                Left = 12,
                Top = 8,
                Right = 6,
                Bottom = 4
            }
        }]);

        Assert.Equal("base", baseSuffix);
        Assert.NotNull(croppedSuffix);
        Assert.Contains("crop-12-8-6-4", croppedSuffix!, StringComparison.Ordinal);
        Assert.Contains("aspect-Force 4_3", croppedSuffix, StringComparison.Ordinal);
    }

    [Fact]
    public void ShouldUsePreviewDeinterlace_should_enable_for_dv_avi_sources()
    {
        var method = typeof(PreviewFrameService).GetMethod(
            "ShouldUsePreviewDeinterlace",
            BindingFlags.Static | BindingFlags.NonPublic | BindingFlags.Public);

        Assert.NotNull(method);

        var mediaInfo = new MediaInfo
        {
            SourceName = "1991 - 5 - 6 - .avi",
            SourcePath = @"F:\Veliki avi\1991 - 5 - 6 - .avi",
            Container = "avi",
            DurationSeconds = 120,
            DurationText = "00:02:00",
            SizeBytes = 1_000_000,
            SizeText = "1 MB",
            OverallBitrateKbps = 1000,
            OverallBitrateText = "1000 kb/s",
            VideoCodec = "dvvideo",
            Width = 720,
            Height = 576,
            Resolution = "720x576",
            DisplayAspectRatio = "4:3",
            SampleAspectRatio = "16:15",
            FrameRate = 25,
            FrameRateText = "25 fps",
            FrameCount = 3000,
            VideoBitrateKbps = 25000,
            VideoBitrateText = "25000 kb/s",
            AudioCodec = "pcm_s16le",
            AudioChannels = 2,
            AudioSampleRateHz = 48000,
            AudioBitrateKbps = 1536,
            AudioBitrateText = "1536 kb/s",
            VideoSummary = "dvvideo | 720x576",
            AudioSummary = "pcm_s16le | stereo"
        };

        var actual = (bool?)method!.Invoke(null, [mediaInfo]);

        Assert.True(actual);
    }
}
