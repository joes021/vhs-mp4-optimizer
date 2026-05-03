namespace VhsMp4Optimizer.App.Models;

public sealed class SystemResourceSnapshot
{
    public double CpuPercent { get; init; }
    public double? GpuPercent { get; init; }
    public double RamPercent { get; init; }
    public double StoragePercent { get; init; }
    public string StorageLabel { get; init; } = "--";
}
