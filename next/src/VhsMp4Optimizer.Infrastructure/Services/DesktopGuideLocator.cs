namespace VhsMp4Optimizer.Infrastructure.Services;

public static class DesktopGuideLocator
{
    public static string? FindGuidePath(string baseDirectory)
    {
        if (string.IsNullOrWhiteSpace(baseDirectory))
        {
            return null;
        }

        var current = new DirectoryInfo(baseDirectory);
        while (current is not null)
        {
            var htmlPath = Path.Combine(current.FullName, "docs", "VHS_MP4_OPTIMIZER_UPUTSTVO.html");
            if (File.Exists(htmlPath))
            {
                return htmlPath;
            }

            var markdownPath = Path.Combine(current.FullName, "docs", "VHS_MP4_OPTIMIZER_UPUTSTVO.md");
            if (File.Exists(markdownPath))
            {
                return markdownPath;
            }

            current = current.Parent;
        }

        return null;
    }
}
