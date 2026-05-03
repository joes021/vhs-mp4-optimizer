namespace VhsMp4Optimizer.Core.Tests;

public sealed class MainWindowMarkupTests
{
    [Fact]
    public void MainWindow_should_keep_quick_setup_fields_in_uniform_row()
    {
        var projectRoot = FindProjectRoot();
        var markupPath = Path.Combine(
            projectRoot,
            "next",
            "src",
            "VhsMp4Optimizer.App",
            "Views",
            "MainWindow.axaml");

        var markup = File.ReadAllText(markupPath);

        Assert.Contains("ColumnDefinitions=\"*,*,*,*,*\"", markup, StringComparison.Ordinal);
        Assert.Contains("ColumnSpacing=\"20\"", markup, StringComparison.Ordinal);
        Assert.Contains("ColumnDefinitions=\"168,168,168,168,168,168\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Open Converted File\"", markup, StringComparison.Ordinal);
        Assert.Contains("Content=\"Open Report\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Migracioni branch je aktivan", markup, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void MainWindow_should_keep_input_and_output_headers_separate_from_path_fields()
    {
        var projectRoot = FindProjectRoot();
        var markupPath = Path.Combine(
            projectRoot,
            "next",
            "src",
            "VhsMp4Optimizer.App",
            "Views",
            "MainWindow.axaml");

        var markup = File.ReadAllText(markupPath);

        Assert.Contains("RowDefinitions=\"Auto,Auto,Auto\"", markup, StringComparison.Ordinal);
        Assert.Contains("ColumnDefinitions=\"96,*,136,136\"", markup, StringComparison.Ordinal);
        Assert.Contains("ColumnDefinitions=\"96,*,136\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Margin=\"106,0,0,0\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void MainWindow_should_keep_batch_actions_in_single_horizontal_row()
    {
        var projectRoot = FindProjectRoot();
        var markupPath = Path.Combine(
            projectRoot,
            "next",
            "src",
            "VhsMp4Optimizer.App",
            "Views",
            "MainWindow.axaml");

        var markup = File.ReadAllText(markupPath);

        Assert.Contains("Text=\"Batch actions\"", markup, StringComparison.Ordinal);
        Assert.Contains("ColumnDefinitions=\"168,168,168,168,168,168\"", markup, StringComparison.Ordinal);
        Assert.Contains("Grid.Column=\"5\" Classes=\"batch-action\" Content=\"{Binding PauseResumeLabel}\"", markup, StringComparison.Ordinal);
    }

    [Fact]
    public void MainWindow_should_keep_split_output_controls_inside_the_same_card_row()
    {
        var projectRoot = FindProjectRoot();
        var markupPath = Path.Combine(
            projectRoot,
            "next",
            "src",
            "VhsMp4Optimizer.App",
            "Views",
            "MainWindow.axaml");

        var markup = File.ReadAllText(markupPath);

        Assert.Contains("Text=\"Split output\"", markup, StringComparison.Ordinal);
        Assert.Contains("ColumnDefinitions=\"Auto,18,Auto,110\"", markup, StringComparison.Ordinal);
        Assert.Contains("VerticalAlignment=\"Center\"", markup, StringComparison.Ordinal);
        Assert.DoesNotContain("Text=\"Max part GB\" />\r\n                            <NumericUpDown", markup, StringComparison.Ordinal);
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
