using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Core.Services;

public static class WorkflowPresetService
{
    public const string Custom = "Custom";
    public const string UsbStandard = "USB standard";
    public const string SmartTv = "Smart TV";
    public const string SmallFile = "Mali fajl";
    public const string Archive = "Arhiva kvalitet";
    public const string HevcDevices = "HEVC noviji uredjaji";

    private static readonly IReadOnlyDictionary<string, WorkflowPresetDefinition> Presets =
        new Dictionary<string, WorkflowPresetDefinition>(StringComparer.OrdinalIgnoreCase)
        {
            [UsbStandard] = new(
                UsbStandard,
                QualityModes.UsbSmallFile,
                ScaleModes.Pal576p,
                AspectModes.Auto,
                "3500k",
                "128k",
                true,
                3.8),
            [SmartTv] = new(
                SmartTv,
                QualityModes.TvSmart,
                ScaleModes.Original,
                AspectModes.Auto,
                "6500k",
                "160k",
                false,
                3.8),
            [SmallFile] = new(
                SmallFile,
                QualityModes.SmallMp4H264,
                ScaleModes.Pal576p,
                AspectModes.Auto,
                "3000k",
                "128k",
                false,
                3.8),
            [Archive] = new(
                Archive,
                QualityModes.ArchiveBetterQuality,
                ScaleModes.Original,
                AspectModes.KeepOriginal,
                "9000k",
                "192k",
                false,
                3.8),
            [HevcDevices] = new(
                HevcDevices,
                QualityModes.HevcForNewerDevices,
                ScaleModes.Original,
                AspectModes.Auto,
                "2800k",
                "128k",
                false,
                3.8)
        };

    public static IReadOnlyList<string> Names { get; } =
    [
        UsbStandard,
        SmartTv,
        SmallFile,
        Archive,
        HevcDevices,
        Custom
    ];

    public static WorkflowPresetDefinition? TryGet(string name)
        => Presets.TryGetValue(name, out var preset) ? preset : null;
}
