namespace VhsMp4Optimizer.Core.Services;

public static class DenoiseModes
{
    public const string Off = "Off";
    public const string Light = "Light";
    public const string Medium = "Medium";

    public static IReadOnlyList<string> All { get; } =
    [
        Off,
        Light,
        Medium
    ];
}
