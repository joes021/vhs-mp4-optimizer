using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Core.Services;
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

    [Fact]
    public void Scan_should_queue_explicit_file_even_when_output_file_already_exists()
    {
        var inputPath = CreateFile("queued-even-if-output-exists.avi");
        var outputDirectory = Path.Combine(_rootPath, "output");
        Directory.CreateDirectory(outputDirectory);
        var outputPath = Path.Combine(outputDirectory, "queued-even-if-output-exists.mp4");
        File.WriteAllText(outputPath, "existing output");

        var service = new SourceScanService((sourcePath, _) => BuildMediaInfo(sourcePath));
        var settings = new BatchSettings
        {
            InputPath = inputPath,
            OutputDirectory = outputDirectory,
            QualityMode = QualityModes.StandardVhs,
            ScaleMode = ScaleModes.Pal576p,
            AudioBitrate = "160k"
        };

        var items = service.Scan(settings, @"C:\ffmpeg\bin\ffmpeg.exe");

        var item = Assert.Single(items);
        Assert.Equal("queued", item.Status);
        Assert.Equal(Path.GetFullPath(inputPath), item.SourcePath);
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

    private static MediaInfo BuildMediaInfo(string sourcePath)
    {
        return new MediaInfo
        {
            SourceName = Path.GetFileName(sourcePath),
            SourcePath = sourcePath,
            Container = "avi",
            DurationSeconds = 120,
            DurationText = "00:02:00",
            SizeBytes = 1000,
            SizeText = "1000 B",
            OverallBitrateKbps = 8000,
            OverallBitrateText = "8000 kbps",
            VideoCodec = "dvvideo",
            Width = 720,
            Height = 576,
            Resolution = "720x576",
            DisplayAspectRatio = "4:3",
            SampleAspectRatio = "16:15",
            FrameRate = 25,
            FrameRateText = "25 fps",
            FrameCount = 3000,
            VideoBitrateKbps = 7200,
            VideoBitrateText = "7200 kbps",
            AudioCodec = "pcm",
            AudioChannels = 2,
            AudioSampleRateHz = 48000,
            AudioBitrateKbps = 1536,
            AudioBitrateText = "1536 kbps",
            VideoSummary = "dvvideo | 720x576 | 25 fps",
            AudioSummary = "pcm | 2 ch | 1536 kbps"
        };
    }
}
