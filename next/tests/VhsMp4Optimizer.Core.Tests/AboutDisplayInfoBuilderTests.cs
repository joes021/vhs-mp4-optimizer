using VhsMp4Optimizer.App.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class AboutDisplayInfoBuilderTests
{
    [Fact]
    public void Build_should_extract_semantic_version_git_ref_and_release_tag_from_informational_version()
    {
        var info = AboutDisplayInfoBuilder.Build(
            informationalVersion: "1.1.13+1178936d22aa3fdf1047aa365d6abb91ae6a",
            fallbackVersion: "1.1.13.0",
            installPath: @"C:\Apps\VhsNext",
            guidePath: @"C:\Apps\VhsNext\docs\guide.html",
            branchHint: "codex/avalonia-migration");

        Assert.Equal("1.1.13", info.Version);
        Assert.Equal("1178936", info.GitRef);
        Assert.Equal("vhs-mp4-optimizer-next-1.1.13", info.ReleaseTag);
        Assert.Equal(@"C:\Apps\VhsNext", info.InstallPath);
    }

    [Fact]
    public void Build_should_fallback_to_numeric_version_when_informational_version_is_missing()
    {
        var info = AboutDisplayInfoBuilder.Build(
            informationalVersion: null,
            fallbackVersion: "1.1.13.0",
            installPath: @"C:\Apps\VhsNext",
            guidePath: @"C:\Apps\VhsNext\docs\guide.html",
            branchHint: "codex/avalonia-migration");

        Assert.Equal("1.1.13", info.Version);
        Assert.Equal("nije dostupan", info.GitRef);
        Assert.Equal("vhs-mp4-optimizer-next-1.1.13", info.ReleaseTag);
    }
}
