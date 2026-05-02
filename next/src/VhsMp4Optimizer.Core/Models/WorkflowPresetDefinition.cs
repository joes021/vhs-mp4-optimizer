namespace VhsMp4Optimizer.Core.Models;

public sealed record WorkflowPresetDefinition(
    string Name,
    string QualityMode,
    string ScaleMode,
    string AspectMode,
    string VideoBitrate,
    string AudioBitrate,
    bool SplitOutput,
    double MaxPartGb);
