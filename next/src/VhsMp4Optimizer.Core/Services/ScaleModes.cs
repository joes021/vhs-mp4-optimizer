namespace VhsMp4Optimizer.Core.Services;

public static class ScaleModes
{
    public const string Original = "Original";
    public const string Pal576p = "PAL 576p";
    public const string P720 = "720p";
    public const string P1080 = "1080p";

    public static IReadOnlyList<string> All { get; } = new[]
    {
        Original,
        Pal576p,
        P720,
        P1080
    };
}
