namespace VhsMp4Optimizer.Core.Tests;

public sealed class AboutWindowMarkupTests
{
    [Fact]
    public void AboutWindow_should_use_light_workspace_surface()
    {
        var projectRoot = FindProjectRoot();
        var aboutWindowPath = Path.Combine(
            projectRoot,
            "next",
            "src",
            "VhsMp4Optimizer.App",
            "Views",
            "AboutWindow.axaml");

        var markup = File.ReadAllText(aboutWindowPath);

        Assert.Contains("Background=\"#F6F8FC\"", markup, StringComparison.Ordinal);
        Assert.Contains("BorderBrush=\"#D8E0EF\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Release tag\"", markup, StringComparison.Ordinal);
        Assert.Contains("Text=\"Git ref\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Background=\"#141A24\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Foreground=\"#EAF1FB\"", markup, StringComparison.Ordinal);
    }

    private static string FindProjectRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);
        while (current is not null)
        {
            if (Directory.Exists(Path.Combine(current.FullName, "next", "src", "VhsMp4Optimizer.App")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new DirectoryNotFoundException("Project root for Avalonia app nije pronadjen.");
    }
}
