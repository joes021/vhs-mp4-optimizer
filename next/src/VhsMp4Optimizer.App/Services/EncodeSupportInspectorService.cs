using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using VhsMp4Optimizer.App.Models;
using VhsMp4Optimizer.Core.Services;

namespace VhsMp4Optimizer.App.Services;

public sealed class EncodeSupportInspectorService
{
    private readonly Func<string?, CancellationToken, Task<string?>> _readEncoderOutputAsync;
    private readonly Func<CancellationToken, Task<IReadOnlyList<string>>> _readGpuNamesAsync;

    public EncodeSupportInspectorService(
        Func<string?, CancellationToken, Task<string?>>? readEncoderOutputAsync = null,
        Func<CancellationToken, Task<IReadOnlyList<string>>>? readGpuNamesAsync = null)
    {
        _readEncoderOutputAsync = readEncoderOutputAsync ?? ReadEncoderOutputAsync;
        _readGpuNamesAsync = readGpuNamesAsync ?? ReadGpuNamesAsync;
    }

    public async Task<EncodeSupportReport> InspectAsync(string? ffmpegPath, CancellationToken cancellationToken = default)
    {
        var ffmpegReady = !string.IsNullOrWhiteSpace(ffmpegPath) && File.Exists(ffmpegPath);
        var encoderOutput = ffmpegReady
            ? await _readEncoderOutputAsync(ffmpegPath, cancellationToken)
            : null;

        var gpuNames = await _readGpuNamesAsync(cancellationToken);
        var hasNvidiaGpu = gpuNames.Any(name => name.Contains("NVIDIA", StringComparison.OrdinalIgnoreCase));
        var hasIntelGpu = gpuNames.Any(name => name.Contains("Intel", StringComparison.OrdinalIgnoreCase));
        var hasAmdGpu = gpuNames.Any(name => name.Contains("AMD", StringComparison.OrdinalIgnoreCase) || name.Contains("Radeon", StringComparison.OrdinalIgnoreCase));

        var hasNvencH264 = ContainsEncoder(encoderOutput, "h264_nvenc");
        var hasNvencHevc = ContainsEncoder(encoderOutput, "hevc_nvenc");
        var hasQsvH264 = ContainsEncoder(encoderOutput, "h264_qsv");
        var hasQsvHevc = ContainsEncoder(encoderOutput, "hevc_qsv");
        var hasAmfH264 = ContainsEncoder(encoderOutput, "h264_amf");
        var hasAmfHevc = ContainsEncoder(encoderOutput, "hevc_amf");

        var engines = new List<EncodeEngineSupportStatus>
        {
            BuildStatus(
                "CPU",
                ffmpegReady,
                ffmpegReady ? "ready" : "FFmpeg nije pronadjen",
                ffmpegReady ? "CPU encode je spreman cim postoji ffmpeg." : "Instaliraj ffmpeg da CPU encode proradi.",
                supportsH264: ffmpegReady,
                supportsHevc: ffmpegReady),
            BuildHardwareStatus("NVIDIA NVENC", hasNvidiaGpu, hasNvencH264, hasNvencHevc, "NVIDIA GPU nije detektovan", "NVIDIA GPU postoji, ali NVENC encode nije spreman"),
            BuildHardwareStatus("Intel QSV", hasIntelGpu, hasQsvH264, hasQsvHevc, "Intel GPU nije detektovan", "Intel GPU postoji, ali QSV encode nije spreman"),
            BuildHardwareStatus("AMD AMF", hasAmdGpu, hasAmfH264, hasAmfHevc, "AMD GPU nije detektovan", "AMD GPU postoji, ali AMF encode nije spreman")
        };

        var repairActions = new List<SupportRepairAction>();
        if (!ffmpegReady)
        {
            repairActions.Add(new SupportRepairAction
            {
                Label = "Install FFmpeg",
                Kind = SupportRepairActionKind.Command,
                Target = "winget install -e --id Gyan.FFmpeg --accept-source-agreements --accept-package-agreements",
                Details = "Potrebno za bilo koji encode engine."
            });
        }

        if (hasNvidiaGpu && !(hasNvencH264 || hasNvencHevc))
        {
            repairActions.Add(new SupportRepairAction
            {
                Label = "Install NVIDIA driver / FFmpeg NVENC support",
                Kind = SupportRepairActionKind.Url,
                Target = "https://www.nvidia.com/Download/index.aspx",
                Details = "NVIDIA GPU postoji, ali NVENC encoder nije dostupan u trenutnom okruzenju."
            });
        }

        if (hasIntelGpu && !(hasQsvH264 || hasQsvHevc))
        {
            repairActions.Add(new SupportRepairAction
            {
                Label = "Install Intel driver / QSV support",
                Kind = SupportRepairActionKind.Url,
                Target = "https://www.intel.com/content/www/us/en/support/detect.html",
                Details = "Intel GPU postoji, ali QSV encoder nije dostupan."
            });
        }

        if (hasAmdGpu && !(hasAmfH264 || hasAmfHevc))
        {
            repairActions.Add(new SupportRepairAction
            {
                Label = "Install AMD driver / AMF support",
                Kind = SupportRepairActionKind.Url,
                Target = "https://www.amd.com/en/support/download/drivers.html",
                Details = "AMD GPU postoji, ali AMF encoder nije dostupan."
            });
        }

        var details = new List<string>
        {
            $"FFmpeg: {(ffmpegReady ? ffmpegPath : "nije pronadjen")}",
            gpuNames.Count > 0 ? $"GPU adapteri: {string.Join(", ", gpuNames)}" : "GPU adapteri: nisu detektovani"
        };
        var preferredEngine = ResolvePreferredEngine(engines, wantsHevc: false);
        var preferredReason = BuildPreferredEngineReason(preferredEngine, engines, wantsHevc: false);
        details.AddRange(engines.Select(engine => $"{engine.EngineName}: {engine.Status}{(string.IsNullOrWhiteSpace(engine.Details) ? string.Empty : $" | {engine.Details}")}"));
        details.Add($"Recommended engine: {preferredEngine} | {preferredReason}");
        if (repairActions.Count > 0)
        {
            details.AddRange(repairActions.Select(action => $"Repair action: {action.Label} -> {action.Target}"));
        }

        var summaryPrefix = ffmpegReady ? "Encode support" : "FFmpeg nije pronadjen";
        var summary = summaryPrefix + ": " + string.Join(" | ", engines.Select(engine => $"{engine.EngineName} {engine.Status}")) + $" | preporuka: {preferredEngine}";
        return new EncodeSupportReport
        {
            Summary = summary,
            Details = details,
            Engines = engines,
            RepairActions = repairActions,
            PreferredEngine = preferredEngine,
            PreferredEngineReason = preferredReason
        };
    }

    public static string ResolvePreferredEngine(IReadOnlyList<EncodeEngineSupportStatus> engines, bool wantsHevc)
    {
        if (SupportsRequestedCodec(engines, "NVIDIA NVENC", wantsHevc))
        {
            return EncodeEngines.NvidiaNvenc;
        }

        if (SupportsRequestedCodec(engines, "Intel QSV", wantsHevc))
        {
            return EncodeEngines.IntelQsv;
        }

        if (SupportsRequestedCodec(engines, "AMD AMF", wantsHevc))
        {
            return EncodeEngines.AmdAmf;
        }

        return EncodeEngines.Cpu;
    }

    private static bool SupportsRequestedCodec(IReadOnlyList<EncodeEngineSupportStatus> engines, string engineName, bool wantsHevc)
        => engines.Any(engine =>
            string.Equals(engine.EngineName, engineName, StringComparison.OrdinalIgnoreCase)
            && engine.IsReady
            && (wantsHevc ? engine.SupportsHevc : engine.SupportsH264));

    private static string BuildPreferredEngineReason(string preferredEngine, IReadOnlyList<EncodeEngineSupportStatus> engines, bool wantsHevc)
    {
        var gpuReady = engines
            .Where(engine => !string.Equals(engine.EngineName, "CPU", StringComparison.OrdinalIgnoreCase) && engine.IsReady)
            .Select(engine => engine.EngineName)
            .ToList();
        var codecLabel = wantsHevc ? "H.265/HEVC" : "H.264";

        return preferredEngine switch
        {
            var value when string.Equals(value, EncodeEngines.NvidiaNvenc, StringComparison.OrdinalIgnoreCase)
                => $"NVIDIA GPU i NVENC encoder su spremni za {codecLabel}.",
            var value when string.Equals(value, EncodeEngines.IntelQsv, StringComparison.OrdinalIgnoreCase)
                => $"Intel GPU i QSV encoder su spremni za {codecLabel}.",
            var value when string.Equals(value, EncodeEngines.AmdAmf, StringComparison.OrdinalIgnoreCase)
                => $"AMD GPU i AMF encoder su spremni za {codecLabel}.",
            _ when gpuReady.Count > 0
                => $"GPU encode nije spreman za trazeni codec {codecLabel}. Koristi se CPU fallback.",
            _ => $"GPU encode nije dostupan ili ffmpeg nije spreman za {codecLabel}. Koristi se CPU encode."
        };
    }

    private static EncodeEngineSupportStatus BuildStatus(string engineName, bool isReady, string status, string details, bool supportsH264, bool supportsHevc)
        => new()
        {
            EngineName = engineName,
            IsReady = isReady,
            Status = status,
            Details = details,
            SupportsH264 = supportsH264,
            SupportsHevc = supportsHevc
        };

    private static EncodeEngineSupportStatus BuildHardwareStatus(string engineName, bool gpuDetected, bool supportsH264, bool supportsHevc, string missingGpuMessage, string missingEncoderMessage)
    {
        if (!gpuDetected)
        {
            return BuildStatus(engineName, false, "not available", missingGpuMessage, supportsH264: false, supportsHevc: false);
        }

        if (supportsH264 || supportsHevc)
        {
            var codecSupport = supportsH264 && supportsHevc
                ? "H.264 i H.265"
                : supportsHevc
                    ? "H.265"
                    : "H.264";
            return BuildStatus(engineName, true, "ready", $"GPU i ffmpeg encoder su dostupni ({codecSupport}).", supportsH264, supportsHevc);
        }

        return BuildStatus(engineName, false, "not ready", missingEncoderMessage, supportsH264: false, supportsHevc: false);
    }

    private static bool ContainsEncoder(string? encoderOutput, string encoderName)
        => !string.IsNullOrWhiteSpace(encoderOutput)
           && encoderOutput.Contains(encoderName, StringComparison.OrdinalIgnoreCase);

    private static async Task<string?> ReadEncoderOutputAsync(string? ffmpegPath, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath))
        {
            return null;
        }

        var startInfo = new ProcessStartInfo
        {
            FileName = ffmpegPath,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };
        startInfo.ArgumentList.Add("-hide_banner");
        startInfo.ArgumentList.Add("-encoders");

        using var process = Process.Start(startInfo);
        if (process is null)
        {
            return null;
        }

        var outputTask = process.StandardOutput.ReadToEndAsync(cancellationToken);
        var errorTask = process.StandardError.ReadToEndAsync(cancellationToken);
        await process.WaitForExitAsync(cancellationToken);
        var output = await outputTask;
        var error = await errorTask;
        return string.Join(Environment.NewLine, new[] { output, error }.Where(text => !string.IsNullOrWhiteSpace(text)));
    }

    private static async Task<IReadOnlyList<string>> ReadGpuNamesAsync(CancellationToken cancellationToken)
    {
        if (!OperatingSystem.IsWindows())
        {
            return [];
        }

        try
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = "powershell",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            startInfo.ArgumentList.Add("-NoProfile");
            startInfo.ArgumentList.Add("-Command");
            startInfo.ArgumentList.Add("(Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name) -join \"`n\"");

            using var process = Process.Start(startInfo);
            if (process is null)
            {
                return [];
            }

            var output = await process.StandardOutput.ReadToEndAsync(cancellationToken);
            await process.WaitForExitAsync(cancellationToken);
            return output
                .Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
        }
        catch
        {
            return [];
        }
    }
}
