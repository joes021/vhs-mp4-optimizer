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

        var hasNvenc = ContainsEncoder(encoderOutput, "h264_nvenc") || ContainsEncoder(encoderOutput, "hevc_nvenc");
        var hasQsv = ContainsEncoder(encoderOutput, "h264_qsv") || ContainsEncoder(encoderOutput, "hevc_qsv");
        var hasAmf = ContainsEncoder(encoderOutput, "h264_amf") || ContainsEncoder(encoderOutput, "hevc_amf");

        var engines = new List<EncodeEngineSupportStatus>
        {
            BuildStatus("CPU", ffmpegReady, ffmpegReady ? "ready" : "FFmpeg nije pronadjen", ffmpegReady ? "CPU encode je spreman cim postoji ffmpeg." : "Instaliraj ffmpeg da CPU encode proradi."),
            BuildHardwareStatus("NVIDIA NVENC", hasNvidiaGpu, hasNvenc, "NVIDIA GPU nije detektovan", "NVIDIA GPU postoji, ali NVENC encode nije spreman"),
            BuildHardwareStatus("Intel QSV", hasIntelGpu, hasQsv, "Intel GPU nije detektovan", "Intel GPU postoji, ali QSV encode nije spreman"),
            BuildHardwareStatus("AMD AMF", hasAmdGpu, hasAmf, "AMD GPU nije detektovan", "AMD GPU postoji, ali AMF encode nije spreman")
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

        if (hasNvidiaGpu && !hasNvenc)
        {
            repairActions.Add(new SupportRepairAction
            {
                Label = "Install NVIDIA driver / FFmpeg NVENC support",
                Kind = SupportRepairActionKind.Url,
                Target = "https://www.nvidia.com/Download/index.aspx",
                Details = "NVIDIA GPU postoji, ali NVENC encoder nije dostupan u trenutnom okruzenju."
            });
        }

        if (hasIntelGpu && !hasQsv)
        {
            repairActions.Add(new SupportRepairAction
            {
                Label = "Install Intel driver / QSV support",
                Kind = SupportRepairActionKind.Url,
                Target = "https://www.intel.com/content/www/us/en/support/detect.html",
                Details = "Intel GPU postoji, ali QSV encoder nije dostupan."
            });
        }

        if (hasAmdGpu && !hasAmf)
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
        var preferredEngine = ResolvePreferredEngine(engines);
        var preferredReason = BuildPreferredEngineReason(preferredEngine, engines);
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

    public static string ResolvePreferredEngine(IReadOnlyList<EncodeEngineSupportStatus> engines)
    {
        if (IsReady(engines, "NVIDIA NVENC"))
        {
            return EncodeEngines.NvidiaNvenc;
        }

        if (IsReady(engines, "Intel QSV"))
        {
            return EncodeEngines.IntelQsv;
        }

        if (IsReady(engines, "AMD AMF"))
        {
            return EncodeEngines.AmdAmf;
        }

        return EncodeEngines.Cpu;
    }

    private static bool IsReady(IReadOnlyList<EncodeEngineSupportStatus> engines, string engineName)
        => engines.Any(engine =>
            string.Equals(engine.EngineName, engineName, StringComparison.OrdinalIgnoreCase)
            && engine.IsReady);

    private static string BuildPreferredEngineReason(string preferredEngine, IReadOnlyList<EncodeEngineSupportStatus> engines)
    {
        var gpuReady = engines
            .Where(engine => !string.Equals(engine.EngineName, "CPU", StringComparison.OrdinalIgnoreCase) && engine.IsReady)
            .Select(engine => engine.EngineName)
            .ToList();

        return preferredEngine switch
        {
            var value when string.Equals(value, EncodeEngines.NvidiaNvenc, StringComparison.OrdinalIgnoreCase)
                => "NVIDIA GPU i NVENC encoder su spremni.",
            var value when string.Equals(value, EncodeEngines.IntelQsv, StringComparison.OrdinalIgnoreCase)
                => "Intel GPU i QSV encoder su spremni.",
            var value when string.Equals(value, EncodeEngines.AmdAmf, StringComparison.OrdinalIgnoreCase)
                => "AMD GPU i AMF encoder su spremni.",
            _ when gpuReady.Count > 0
                => $"GPU encode nije stabilno spreman za: {string.Join(", ", gpuReady)}. Koristi se CPU fallback.",
            _ => "GPU encode nije dostupan ili ffmpeg nije spreman. Koristi se CPU encode."
        };
    }

    private static EncodeEngineSupportStatus BuildStatus(string engineName, bool isReady, string status, string details)
        => new()
        {
            EngineName = engineName,
            IsReady = isReady,
            Status = status,
            Details = details
        };

    private static EncodeEngineSupportStatus BuildHardwareStatus(string engineName, bool gpuDetected, bool encoderReady, string missingGpuMessage, string missingEncoderMessage)
    {
        if (!gpuDetected)
        {
            return BuildStatus(engineName, false, "not available", missingGpuMessage);
        }

        if (encoderReady)
        {
            return BuildStatus(engineName, true, "ready", "GPU i ffmpeg encoder su dostupni.");
        }

        return BuildStatus(engineName, false, "not ready", missingEncoderMessage);
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
