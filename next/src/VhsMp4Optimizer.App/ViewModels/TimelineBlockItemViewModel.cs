using System;
using Avalonia;
using Avalonia.Media;
using CommunityToolkit.Mvvm.ComponentModel;
using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.App.ViewModels;

public partial class TimelineBlockItemViewModel : ObservableObject
{
    public required Guid SegmentId { get; init; }
    public required TimelineSegmentKind Kind { get; init; }
    public required double TimelineStartSeconds { get; init; }
    public required double DurationSeconds { get; init; }
    public required double WidthPixels { get; init; }
    public required string Label { get; init; }
    public required string Summary { get; init; }

    [ObservableProperty]
    private bool _isSelected;

    public IBrush BackgroundBrush => Kind switch
    {
        TimelineSegmentKind.Keep => Brush.Parse("#1D4ED8"),
        TimelineSegmentKind.Cut => Brush.Parse("#B91C1C"),
        TimelineSegmentKind.Gap => Brush.Parse("#4B5563"),
        _ => Brush.Parse("#1F2937")
    };

    public IBrush ForegroundBrush => Brush.Parse("#F8FAFC");

    public IBrush BorderBrush => IsSelected
        ? Brush.Parse("#FBBF24")
        : Brush.Parse("#0F172A");

    public IBrush AccentBrush => IsSelected
        ? Brush.Parse("#F59E0B")
        : Brush.Parse("#64748B");

    public IBrush TitleBarBackgroundBrush => IsSelected
        ? Brush.Parse("#C2410C")
        : Brush.Parse("#1E293B");

    public IBrush TitleBarBorderBrush => IsSelected
        ? Brush.Parse("#FDBA74")
        : Brush.Parse("#475569");

    public Thickness BorderThickness => IsSelected
        ? new Thickness(3)
        : new Thickness(1);

    public string SelectionBadgeText => IsSelected ? "SELECTED" : "CLIP";

    public string SelectedTitleText => IsSelected ? "ACTIVE CLIP" : "CLIP FOCUS";

    partial void OnIsSelectedChanged(bool value)
    {
        OnPropertyChanged(nameof(BorderBrush));
        OnPropertyChanged(nameof(AccentBrush));
        OnPropertyChanged(nameof(TitleBarBackgroundBrush));
        OnPropertyChanged(nameof(TitleBarBorderBrush));
        OnPropertyChanged(nameof(BorderThickness));
        OnPropertyChanged(nameof(SelectionBadgeText));
        OnPropertyChanged(nameof(SelectedTitleText));
    }
}
