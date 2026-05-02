using VhsMp4Optimizer.Infrastructure.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class DesktopGuideLocatorTests
{
    [Fact]
    public void FindGuidePath_should_walk_up_to_docs_folder()
    {
        var root = Path.Combine(Path.GetTempPath(), "avalonia-guide-" + Guid.NewGuid().ToString("N"));
        var deep = Path.Combine(root, "next", "src", "VhsMp4Optimizer.App", "bin", "Debug");
        Directory.CreateDirectory(Path.Combine(root, "docs"));
        Directory.CreateDirectory(deep);
        var guidePath = Path.Combine(root, "docs", "VHS_MP4_OPTIMIZER_UPUTSTVO.html");
        File.WriteAllText(guidePath, "<html></html>");

        try
        {
            var resolved = DesktopGuideLocator.FindGuidePath(deep);
            Assert.Equal(guidePath, resolved);
        }
        finally
        {
            Directory.Delete(root, true);
        }
    }
}
