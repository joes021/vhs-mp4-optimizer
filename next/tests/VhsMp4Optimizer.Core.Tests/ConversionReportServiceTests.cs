using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Core.Services;
using VhsMp4Optimizer.Infrastructure.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class ConversionReportServiceTests : IDisposable
{
    private readonly string _rootPath;

    public ConversionReportServiceTests()
    {
        _rootPath = Path.Combine(Path.GetTempPath(), $"vhs-next-report-{Guid.NewGuid():N}");
        Directory.CreateDirectory(_rootPath);
    }

    [Fact]
    public async Task WriteItemReportAsync_should_include_deinterlace_and_ffmpeg_arguments()
    {
        var mediaInfo = new MediaInfo
        {
            SourceName = "report-source.avi",
            SourcePath = Path.Combine(_rootPath, "report-source.avi"),
            Container = "avi",
            DurationSeconds = 120,
            DurationText = "00:02:00",
            SizeBytes = 1000,
            SizeText = "1000 B",
            OverallBitrateKbps = 4000,
            OverallBitrateText = "4000 kbps",
            VideoCodec = "mpeg4",
            Width = 720,
            Height = 576,
            Resolution = "720x576",
            DisplayAspectRatio = "4:3",
            SampleAspectRatio = "16:15",
            FrameRate = 25,
            FrameRateText = "25 fps",
            FrameCount = 3000,
            VideoBitrateKbps = 3500,
            VideoBitrateText = "3500 kbps",
            AudioCodec = "mp3",
            AudioChannels = 2,
            AudioSampleRateHz = 48000,
            AudioBitrateKbps = 160,
            AudioBitrateText = "160 kbps",
            VideoSummary = "mpeg4 | 720x576 | 25 fps",
            AudioSummary = "mp3 | 2 ch | 160 kbps"
        };

        var request = new ConversionRequest
        {
            MediaInfo = mediaInfo,
            Settings = new BatchSettings
            {
                InputPath = mediaInfo.SourcePath,
                OutputDirectory = _rootPath,
                QualityMode = QualityModes.StandardVhs,
                ScaleMode = ScaleModes.Pal576p,
                DeinterlaceMode = DeinterlaceModes.Yadif,
                DenoiseMode = DenoiseModes.Light,
                AspectMode = AspectModes.Auto,
                EncodeEngine = EncodeEngines.Auto,
                VideoBitrate = "3500k",
                AudioBitrate = "128k"
            },
            OutputPath = Path.Combine(_rootPath, "report-source.mp4")
        };

        var item = new QueueItemSummary
        {
            SourceFile = "report-source.avi",
            SourcePath = mediaInfo.SourcePath,
            OutputFile = "report-source.mp4",
            OutputPath = request.OutputPath,
            OutputPattern = request.OutputPath,
            Container = "avi",
            Resolution = "720x576",
            Duration = "00:02:00",
            Video = mediaInfo.VideoSummary,
            Audio = mediaInfo.AudioSummary,
            Status = "done",
            MediaInfo = mediaInfo,
            PlannedOutput = OutputPlanner.Build(mediaInfo, request.Settings, null)
        };

        var args = FfmpegCommandBuilder.BuildArguments(request);
        var service = new ConversionReportService();

        var reportPath = await service.WriteItemReportAsync(_rootPath, "USB standard", request, item, args, TimeSpan.FromSeconds(30));

        var reportText = await File.ReadAllTextAsync(reportPath);
        Assert.Contains("Deinterlace: YADIF", reportText);
        Assert.Contains("Denoise: Light", reportText);
        Assert.Contains("FFmpeg arguments:", reportText);
        Assert.Contains("yadif=0:-1:0", reportText);
    }

    public void Dispose()
    {
        if (Directory.Exists(_rootPath))
        {
            Directory.Delete(_rootPath, true);
        }
    }
}
