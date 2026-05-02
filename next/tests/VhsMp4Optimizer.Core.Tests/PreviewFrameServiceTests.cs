using System.Reflection;
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
}
