using System.Diagnostics;
using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Infrastructure.Services;

public sealed class FfmpegConversionService
{
    public async Task ConvertAsync(string ffmpegPath, ConversionRequest request, CancellationToken cancellationToken = default)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(request.OutputPath)!);

        var startInfo = new ProcessStartInfo
        {
            FileName = ffmpegPath,
            RedirectStandardError = true,
            RedirectStandardOutput = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        foreach (var argument in FfmpegCommandBuilder.BuildArguments(request))
        {
            startInfo.ArgumentList.Add(argument);
        }

        using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("FFmpeg proces nije pokrenut.");
        await process.WaitForExitAsync(cancellationToken);
        var errorText = await process.StandardError.ReadToEndAsync(cancellationToken);

        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException($"FFmpeg nije uspeo: {errorText}");
        }
    }
}
