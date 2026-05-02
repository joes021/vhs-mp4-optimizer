using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Infrastructure.Services;

public interface IPreviewFrameService
{
    Task<string?> RenderPreviewAsync(
        string ffmpegPath,
        MediaInfo mediaInfo,
        double sourceSeconds,
        ItemTransformSettings? transformSettings = null,
        CancellationToken cancellationToken = default);
}
