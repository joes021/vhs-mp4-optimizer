namespace VhsMp4Optimizer.Core.Services;

public static class DeinterlaceModes
{
    public const string Off = "Off";
    public const string Yadif = "YADIF";
    public const string YadifBob = "YADIF Bob";

    public static IReadOnlyList<string> All { get; } =
    [
        Off,
        Yadif,
        YadifBob
    ];
}
