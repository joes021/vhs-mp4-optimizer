using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Core.Services;

public static class QueueWorkflowService
{
    public static bool ShouldConvert(QueueItemSummary item)
        => item.MediaInfo is not null && (item.Status == "queued" || item.Status == "timeline edited");

    public static QueueItemSummary MarkSkipped(QueueItemSummary item) => CloneWithStatus(item, "skipped");

    public static QueueItemSummary RetryFailed(QueueItemSummary item)
        => item.Status == "failed" ? CloneWithStatus(item, "queued") : item;

    public static string BuildSummary(IEnumerable<QueueItemSummary> items)
    {
        var materialized = items.ToList();
        return $"queued: {materialized.Count(i => i.Status == "queued" || i.Status == "timeline edited")} | done: {materialized.Count(i => i.Status == "done")} | failed: {materialized.Count(i => i.Status == "failed")} | skipped: {materialized.Count(i => i.Status == "skipped")}";
    }

    private static QueueItemSummary CloneWithStatus(QueueItemSummary item, string status)
    {
        return new QueueItemSummary
        {
            SourceFile = item.SourceFile,
            SourcePath = item.SourcePath,
            OutputFile = item.OutputFile,
            OutputPath = item.OutputPath,
            OutputPattern = item.OutputPattern,
            Container = item.Container,
            Resolution = item.Resolution,
            Duration = item.Duration,
            Video = item.Video,
            Audio = item.Audio,
            Status = status,
            MediaInfo = item.MediaInfo,
            PlannedOutput = item.PlannedOutput,
            TimelineProject = item.TimelineProject,
            TransformSettings = item.TransformSettings
        };
    }
}
