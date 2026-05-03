using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Infrastructure.Services;

public interface IConversionService
{
    Task ConvertAsync(
        string ffmpegPath,
        ConversionRequest request,
        IProgress<ConversionProgressInfo>? progress = null,
        CancellationToken cancellationToken = default);
}
