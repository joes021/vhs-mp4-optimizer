namespace VhsMp4Optimizer.Core.Tests;

public sealed class AboutWindowMarkupTests
{
    [Fact]
    public void AboutWindow_should_define_light_foreground_for_dark_surface()
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

        Assert.Contains("Background=\"#141A24\"", markup, StringComparison.Ordinal);
        Assert.Contains("Foreground=\"#EAF1FB\"", markup, StringComparison.Ordinal);
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
