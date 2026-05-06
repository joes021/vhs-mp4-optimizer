using System;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using VhsMp4Optimizer.App.ViewModels;

namespace VhsMp4Optimizer.App.Views;

public partial class PlayerTrimWindow : Window
{
    private TimelineBlockItemViewModel? _activeTimelinePointerBlock;
    private Point _activeTimelinePointerStart;

    public PlayerTrimWindow()
    {
        InitializeComponent();
        Closing += OnClosing;
        KeyDown += OnKeyDown;
    }

    private async void PreviewSliderPointerReleased(object? sender, PointerReleasedEventArgs e)
    {
        if (DataContext is PlayerTrimWindowViewModel viewModel)
        {
            await viewModel.EndManualPreviewNavigationAsync();
        }
    }

    private void PreviewSliderPointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (DataContext is PlayerTrimWindowViewModel viewModel)
        {
            viewModel.BeginManualPreviewNavigation();
        }
    }

    private void TimelineBlockPointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (sender is not Control control
            || control.DataContext is not TimelineBlockItemViewModel block)
        {
            return;
        }

        _activeTimelinePointerBlock = block;
        _activeTimelinePointerStart = e.GetPosition(control);
        e.Pointer.Capture(control);
        e.Handled = true;
    }

    private async void TimelineBlockPointerReleased(object? sender, PointerReleasedEventArgs e)
    {
        if (DataContext is not PlayerTrimWindowViewModel viewModel
            || sender is not Control control
            || control.DataContext is not TimelineBlockItemViewModel block
            || _activeTimelinePointerBlock?.SegmentId != block.SegmentId)
        {
            return;
        }

        var position = e.GetPosition(control);
        var width = Math.Max(1d, control.Bounds.Width);
        var relativePosition = Math.Clamp(position.X / width, 0d, 1d);
        var deltaX = position.X - _activeTimelinePointerStart.X;
        _activeTimelinePointerBlock = null;
        e.Pointer.Capture(null);

        if (viewModel.IsSelectToolActive && Math.Abs(deltaX) >= 24d)
        {
            await viewModel.HandleTimelineBlockDragAsync(block, deltaX);
            e.Handled = true;
            return;
        }

        await viewModel.HandleTimelineBlockPointerAsync(block, relativePosition);
        e.Handled = true;
    }

    private void ClosePlayerTrimClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => Close();

    private void OnClosing(object? sender, WindowClosingEventArgs e)
    {
        PlaybackVideoView.MediaPlayer = null;
        if (DataContext is IDisposable disposable)
        {
            disposable.Dispose();
        }
    }

    private async void OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape)
        {
            Close();
            e.Handled = true;
            return;
        }

        if (DataContext is PlayerTrimWindowViewModel viewModel)
        {
            var controlModifier = e.KeyModifiers.HasFlag(KeyModifiers.Control);
            if (await viewModel.HandleEditorHotkeyAsync(e.Key, controlModifier))
            {
                e.Handled = true;
            }
        }
    }
}
