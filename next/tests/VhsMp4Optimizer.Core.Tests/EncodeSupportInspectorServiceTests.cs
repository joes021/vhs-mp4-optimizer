using VhsMp4Optimizer.App.Models;
using VhsMp4Optimizer.App.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class EncodeSupportInspectorServiceTests
{
    [Fact]
    public async Task InspectAsync_should_mark_nvidia_ready_when_gpu_and_nvenc_encoder_exist()
    {
        var ffmpegPath = CreateStubExecutable("ffmpeg-nvidia.exe");
        var service = new EncodeSupportInspectorService(
            readEncoderOutputAsync: (_, _) => Task.FromResult(" V..... h264_nvenc\n V..... hevc_nvenc\n")!,
            readGpuNamesAsync: _ => Task.FromResult<IReadOnlyList<string>>(["NVIDIA GeForce RTX 4060"]));

        var report = await service.InspectAsync(ffmpegPath);

        var nvidia = Assert.Single(report.Engines.Where(engine => engine.EngineName == "NVIDIA NVENC"));
        Assert.True(nvidia.IsReady, report.Summary + Environment.NewLine + string.Join(Environment.NewLine, report.Details));
        Assert.Equal("ready", nvidia.Status);
        Assert.DoesNotContain(report.RepairActions, action => action.Label.Contains("NVIDIA", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public async Task InspectAsync_should_offer_driver_or_ffmpeg_repair_when_intel_gpu_exists_without_qsv_encoder()
    {
        var ffmpegPath = CreateStubExecutable("ffmpeg-intel.exe");
        var service = new EncodeSupportInspectorService(
            readEncoderOutputAsync: (_, _) => Task.FromResult(" V..... libx264\n")!,
            readGpuNamesAsync: _ => Task.FromResult<IReadOnlyList<string>>(["Intel(R) UHD Graphics"]));

        var report = await service.InspectAsync(ffmpegPath);

        var intel = Assert.Single(report.Engines.Where(engine => engine.EngineName == "Intel QSV"));
        Assert.False(intel.IsReady);
        Assert.Contains("not ready", intel.Status, StringComparison.OrdinalIgnoreCase);
        Assert.Contains(report.RepairActions, action => action.Label.Contains("Intel", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public async Task InspectAsync_should_offer_ffmpeg_install_when_binary_is_missing()
    {
        var service = new EncodeSupportInspectorService(
            readEncoderOutputAsync: (_, _) => Task.FromResult<string?>(null),
            readGpuNamesAsync: _ => Task.FromResult<IReadOnlyList<string>>([]));

        var report = await service.InspectAsync(null);

        Assert.Contains("FFmpeg nije pronadjen", report.Summary, StringComparison.OrdinalIgnoreCase);
        Assert.Contains(report.RepairActions, action => action.Kind == SupportRepairActionKind.Command && action.Target.Contains("winget install", StringComparison.OrdinalIgnoreCase));
    }

    private static string CreateStubExecutable(string fileName)
    {
        var path = Path.Combine(Path.GetTempPath(), $"vhs-next-encode-support-{Guid.NewGuid():N}", fileName);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, "stub");
        return path;
    }
}
