using VhsMp4Optimizer.Core.Services;

namespace VhsMp4Optimizer.Core.Models;

public sealed class ItemTransformSettings
{
    public string AspectMode { get; init; } = AspectModes.Auto;
    public CropSettings Crop { get; init; } = new();
}
