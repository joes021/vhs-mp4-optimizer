using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Infrastructure.Services;

public interface ISourceScanService
{
    IReadOnlyList<QueueItemSummary> Scan(BatchSettings settings, string ffmpegPath, IReadOnlyList<string>? explicitSourcePaths = null);
    string ResolveOutputDirectory(string inputPath, string outputDirectory);
}
