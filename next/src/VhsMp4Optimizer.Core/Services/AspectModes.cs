namespace VhsMp4Optimizer.Core.Services;

public static class AspectModes
{
    public const string Auto = "Auto";
    public const string KeepOriginal = "Keep Original";
    public const string Force4x3 = "Force 4:3";
    public const string Force16x9 = "Force 16:9";

    public static IReadOnlyList<string> All { get; } = new[]
    {
        Auto,
        KeepOriginal,
        Force4x3,
        Force16x9
    };
}
