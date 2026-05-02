namespace VhsMp4Optimizer.Core.Services;

public static class EncodeEngines
{
    public const string Auto = "Auto";
    public const string Cpu = "CPU (libx264/libx265)";
    public const string NvidiaNvenc = "NVIDIA NVENC";
    public const string IntelQsv = "Intel QSV";
    public const string AmdAmf = "AMD AMF";

    public static IReadOnlyList<string> All { get; } =
    [
        Auto,
        Cpu,
        NvidiaNvenc,
        IntelQsv,
        AmdAmf
    ];
}
