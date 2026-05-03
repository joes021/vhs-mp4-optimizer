namespace VhsMp4Optimizer.Infrastructure.Services;

public readonly record struct ConversionProgressInfo(
    double Fraction,
    TimeSpan ProcessedDuration,
    TimeSpan? EstimatedRemaining,
    string SpeedText,
    TimeSpan? ExpectedDuration = null);
