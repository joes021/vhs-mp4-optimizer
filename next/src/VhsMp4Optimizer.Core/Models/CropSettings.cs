namespace VhsMp4Optimizer.Core.Models;

public sealed class CropSettings
{
    public int Left { get; init; }
    public int Top { get; init; }
    public int Right { get; init; }
    public int Bottom { get; init; }

    public bool HasCrop => Left > 0 || Top > 0 || Right > 0 || Bottom > 0;
}
