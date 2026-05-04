using System.Collections.Generic;

namespace VhsMp4Optimizer.App.Models;

public sealed class EncodeSupportReport
{
    public string Summary { get; init; } = string.Empty;
    public IReadOnlyList<string> Details { get; init; } = [];
    public IReadOnlyList<EncodeEngineSupportStatus> Engines { get; init; } = [];
    public IReadOnlyList<SupportRepairAction> RepairActions { get; init; } = [];
    public string PreferredEngine { get; init; } = string.Empty;
    public string PreferredEngineReason { get; init; } = string.Empty;
}

public sealed class EncodeEngineSupportStatus
{
    public required string EngineName { get; init; }
    public required bool IsReady { get; init; }
    public required string Status { get; init; }
    public string? Details { get; init; }
    public bool SupportsH264 { get; init; }
    public bool SupportsHevc { get; init; }
}

public sealed class SupportRepairAction
{
    public required string Label { get; init; }
    public required SupportRepairActionKind Kind { get; init; }
    public required string Target { get; init; }
    public string? Details { get; init; }
}

public enum SupportRepairActionKind
{
    Command,
    Url
}
