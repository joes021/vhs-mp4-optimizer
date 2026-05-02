using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Infrastructure.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class QueueSnapshotServiceTests : IDisposable
{
    private readonly string _rootPath;

    public QueueSnapshotServiceTests()
    {
        _rootPath = Path.Combine(Path.GetTempPath(), $"vhs-next-queue-{Guid.NewGuid():N}");
        Directory.CreateDirectory(_rootPath);
    }

    [Fact]
    public async Task Save_and_load_should_roundtrip_queue_snapshot()
    {
        var service = new QueueSnapshotService();
        var queuePath = Path.Combine(_rootPath, "queue.json");
        var snapshot = new QueueSessionSnapshot
        {
            InputFolder = @"F:\input",
            OutputFolder = @"F:\out",
            SelectedPreset = "USB standard",
            QualityMode = "Standard VHS",
            ScaleMode = "PAL 576p",
            AspectMode = "Auto",
            DeinterlaceMode = "YADIF",
            DenoiseMode = "Light",
            EncodeEngine = "NVIDIA NVENC",
            VideoBitrate = "5000k",
            AudioBitrate = "160k",
            SplitOutput = true,
            MaxPartGb = 3.8,
            ExplicitSourcePaths = [@"F:\input\a.mp4"],
            QueueItems =
            [
                new QueueItemSummary
                {
                    SourceFile = "a.mp4",
                    SourcePath = @"F:\input\a.mp4",
                    OutputFile = "a.mp4",
                    OutputPath = @"F:\out\a.mp4",
                    OutputPattern = @"F:\out\a.mp4",
                    Container = "mp4",
                    Resolution = "1920x1080",
                    Duration = "00:10:00",
                    Video = "h264",
                    Audio = "aac",
                    Status = "queued",
                    MediaInfo = null,
                    PlannedOutput = null,
                    TimelineProject = new TimelineProject
                    {
                        SourcePath = @"F:\input\a.mp4",
                        SourceName = "a.mp4",
                        SourceDurationSeconds = 600,
                        Segments =
                        [
                            new TimelineSegment
                            {
                                Id = Guid.NewGuid(),
                                Kind = TimelineSegmentKind.Keep,
                                TimelineStartSeconds = 0,
                                SourceStartSeconds = 0,
                                SourceEndSeconds = 600
                            }
                        ]
                    },
                    TransformSettings = new ItemTransformSettings
                    {
                        AspectMode = "Auto",
                        Crop = new CropSettings { Left = 4, Top = 2, Right = 4, Bottom = 2 }
                    }
                }
            ]
        };

        await service.SaveAsync(queuePath, snapshot);
        var loaded = await service.LoadAsync(queuePath);

        Assert.Equal(snapshot.InputFolder, loaded.InputFolder);
        Assert.Equal(snapshot.OutputFolder, loaded.OutputFolder);
        Assert.Equal(snapshot.SelectedPreset, loaded.SelectedPreset);
        Assert.Single(loaded.QueueItems);
        Assert.Equal(4, loaded.QueueItems[0].TransformSettings?.Crop.Left);
        Assert.NotNull(loaded.QueueItems[0].TimelineProject);
        Assert.Single(loaded.QueueItems[0].TimelineProject!.Segments);
    }

    public void Dispose()
    {
        if (Directory.Exists(_rootPath))
        {
            Directory.Delete(_rootPath, true);
        }
    }
}
