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
}
