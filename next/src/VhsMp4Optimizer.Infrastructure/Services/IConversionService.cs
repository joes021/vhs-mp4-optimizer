using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Infrastructure.Services;

public interface IConversionService
{
    Task ConvertAsync(string ffmpegPath, ConversionRequest request, CancellationToken cancellationToken = default);
}
