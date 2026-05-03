using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using VhsMp4Optimizer.App.Models;

namespace VhsMp4Optimizer.App.Services;

public sealed class SystemResourceMonitorService : IDisposable
{
    private PerformanceCounter? _cpuCounter;
    private List<PerformanceCounter>? _gpuCounters;

    public SystemResourceSnapshot Capture(string? preferredStoragePath)
    {
        var isWindows = OperatingSystem.IsWindows();
        return new SystemResourceSnapshot
        {
            CpuPercent = isWindows ? ReadCpuPercent() : 0,
            GpuPercent = isWindows ? ReadGpuPercent() : null,
            RamPercent = isWindows ? ReadRamPercent() : 0,
            StoragePercent = ReadStoragePercent(preferredStoragePath, out var storageLabel),
            StorageLabel = storageLabel
        };
    }

    public void Dispose()
    {
        _cpuCounter?.Dispose();
        if (_gpuCounters is not null)
        {
            foreach (var counter in _gpuCounters)
            {
                counter.Dispose();
            }
        }
    }

    [SupportedOSPlatform("windows")]
    private double ReadCpuPercent()
    {
        if (!OperatingSystem.IsWindows())
        {
            return 0;
        }

        try
        {
            _cpuCounter ??= new PerformanceCounter("Processor", "% Processor Time", "_Total");
            return ClampPercent(_cpuCounter.NextValue());
        }
        catch
        {
            return 0;
        }
    }

    [SupportedOSPlatform("windows")]
    private double? ReadGpuPercent()
    {
        if (!OperatingSystem.IsWindows())
        {
            return null;
        }

        try
        {
            _gpuCounters ??= CreateGpuCounters();
            if (_gpuCounters.Count == 0)
            {
                return null;
            }

            var total = 0d;
            foreach (var counter in _gpuCounters)
            {
                total += counter.NextValue();
            }

            return ClampPercent(total);
        }
        catch
        {
            return null;
        }
    }

    [SupportedOSPlatform("windows")]
    private static List<PerformanceCounter> CreateGpuCounters()
    {
        var counters = new List<PerformanceCounter>();
        try
        {
            var category = new PerformanceCounterCategory("GPU Engine");
            foreach (var instanceName in category.GetInstanceNames())
            {
                if (!instanceName.Contains("engtype", StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                counters.Add(new PerformanceCounter("GPU Engine", "Utilization Percentage", instanceName));
            }
        }
        catch
        {
        }

        return counters;
    }

    [SupportedOSPlatform("windows")]
    private static double ReadRamPercent()
    {
        if (!OperatingSystem.IsWindows())
        {
            return 0;
        }

        try
        {
            var status = new MemoryStatusEx();
            if (!GlobalMemoryStatusEx(status))
            {
                return 0;
            }

            return ClampPercent(status.MemoryLoad);
        }
        catch
        {
            return 0;
        }
    }

    private static double ReadStoragePercent(string? preferredStoragePath, out string storageLabel)
    {
        try
        {
            var probePath = !string.IsNullOrWhiteSpace(preferredStoragePath)
                ? preferredStoragePath
                : AppContext.BaseDirectory;
            var root = Path.GetPathRoot(Path.GetFullPath(probePath)) ?? Path.GetPathRoot(AppContext.BaseDirectory) ?? string.Empty;
            var drive = new DriveInfo(root);
            storageLabel = drive.Name.TrimEnd(Path.DirectorySeparatorChar);
            var used = drive.TotalSize - drive.AvailableFreeSpace;
            if (drive.TotalSize <= 0)
            {
                return 0;
            }

            return ClampPercent((double)used / drive.TotalSize * 100d);
        }
        catch
        {
            storageLabel = "--";
            return 0;
        }
    }

    private static double ClampPercent(double value)
        => Math.Clamp(Math.Round(value, MidpointRounding.AwayFromZero), 0, 100);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GlobalMemoryStatusEx([In, Out] MemoryStatusEx lpBuffer);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    private sealed class MemoryStatusEx
    {
        public MemoryStatusEx()
        {
            Length = (uint)Marshal.SizeOf(typeof(MemoryStatusEx));
        }

        public uint Length;
        public uint MemoryLoad;
        public ulong TotalPhys;
        public ulong AvailPhys;
        public ulong TotalPageFile;
        public ulong AvailPageFile;
        public ulong TotalVirtual;
        public ulong AvailVirtual;
        public ulong AvailExtendedVirtual;
    }
}
