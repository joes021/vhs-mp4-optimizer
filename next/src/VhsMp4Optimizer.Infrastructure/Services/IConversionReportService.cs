using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Infrastructure.Services;

public interface IConversionReportService
{
    Task<string> WriteItemReportAsync(
        string outputDirectory,
        string presetName,
        ConversionRequest request,
        QueueItemSummary item,
        IReadOnlyList<string> ffmpegArguments,
        TimeSpan elapsed,
        CancellationToken cancellationToken = default);

    Task<string> WriteBatchReportAsync(
        string outputDirectory,
        string presetName,
        BatchSettings settings,
        IReadOnlyList<QueueItemSummary> processedItems,
        int convertedCount,
        int failedCount,
        CancellationToken cancellationToken = default);
}
