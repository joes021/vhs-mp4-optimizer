using VhsMp4Optimizer.App.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class NextUpdateServiceTests
{
    [Theory]
    [InlineData("1.1.8", "vhs-mp4-optimizer-next-1.1.9", true)]
    [InlineData("1.1.8", "vhs-mp4-optimizer-next-1.1.8", false)]
    [InlineData("1.1.8", "vhs-mp4-optimizer-next-1.1.7", false)]
    [InlineData("1.1.8+5842d78", "vhs-mp4-optimizer-next-1.1.9", true)]
    public void IsNewerVersion_should_compare_next_release_tags(string currentVersion, string releaseTag, bool expected)
    {
        var result = NextUpdateService.IsNewerVersion(currentVersion, releaseTag);

        Assert.Equal(expected, result);
    }
}
