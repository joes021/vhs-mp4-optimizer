using VhsMp4Optimizer.Infrastructure.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class SourceScanServiceTests : IDisposable
{
    private readonly string _rootPath;

    public SourceScanServiceTests()
    {
        _rootPath = Path.Combine(Path.GetTempPath(), $"vhs-next-scan-{Guid.NewGuid():N}");
        Directory.CreateDirectory(_rootPath);
    }

    [Fact]
    public void ResolveSourceFiles_should_honor_explicit_file_selection()
    {
        var keepPath = CreateFile("keep.mp4");
        _ = CreateFile("skip.avi");
        _ = CreateFile("ignore.txt");

        var resolved = SourceScanService.ResolveSourceFiles(_rootPath, [keepPath]);

        Assert.Single(resolved);
        Assert.Equal(Path.GetFullPath(keepPath), resolved[0]);
    }

    [Fact]
    public void ResolveSourceFiles_should_scan_supported_folder_contents_when_no_explicit_selection_exists()
    {
        _ = CreateFile("one.mp4");
        _ = CreateFile("two.mkv");
        _ = CreateFile("ignore.txt");

        var resolved = SourceScanService.ResolveSourceFiles(_rootPath);

        Assert.Equal(2, resolved.Count);
        Assert.All(resolved, path => Assert.DoesNotContain(".txt", path, StringComparison.OrdinalIgnoreCase));
    }

    public void Dispose()
    {
        if (Directory.Exists(_rootPath))
        {
            Directory.Delete(_rootPath, true);
        }
    }

    private string CreateFile(string fileName)
    {
        var fullPath = Path.Combine(_rootPath, fileName);
        File.WriteAllText(fullPath, "stub");
        return fullPath;
    }
}
