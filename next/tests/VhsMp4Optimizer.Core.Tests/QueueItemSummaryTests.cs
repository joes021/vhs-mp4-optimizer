using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class QueueItemSummaryTests
{
    [Fact]
    public void Should_keep_batch_fields_together()
    {
        var item = new QueueItemSummary
        {
            SourceFile = "source.avi",
            OutputFile = "source.mp4",
            Container = "avi",
            Resolution = "720x576",
            Duration = "00:43:22",
            Video = "DV / 4:3 / 25 fps",
            Audio = "pcm / stereo",
            Status = "Queued"
        };

        Assert.Equal("source.avi", item.SourceFile);
        Assert.Equal("source.mp4", item.OutputFile);
        Assert.Equal("Queued", item.Status);
    }
}
