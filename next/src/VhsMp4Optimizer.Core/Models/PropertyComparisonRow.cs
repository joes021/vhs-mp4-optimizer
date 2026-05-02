namespace VhsMp4Optimizer.Core.Models;

public sealed class PropertyComparisonRow
{
    public const string PrimaryRowBackground = "#FBFCFE";
    public const string AlternateRowBackground = "#F3F7FD";

    public required string Label { get; init; }
    public required string InputValue { get; init; }
    public required string OutputValue { get; init; }
    public bool IsAlternate { get; init; }
    public string RowBackground => IsAlternate ? AlternateRowBackground : PrimaryRowBackground;
}
