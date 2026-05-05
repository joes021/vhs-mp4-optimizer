using System;
using Avalonia.Controls;
using Avalonia.Input;
using VhsMp4Optimizer.App.ViewModels;

namespace VhsMp4Optimizer.App.Views;

public partial class PlayerTrimWindow : Window
{
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
            await viewModel.CommitPreviewSliderAsync();
        }
    }

    private void PreviewSliderPointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (DataContext is PlayerTrimWindowViewModel viewModel)
        {
            viewModel.BeginManualPreviewNavigation();
        }
    }

    private async void TimelineBlockPointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (DataContext is not PlayerTrimWindowViewModel viewModel
            || sender is not Control control
            || control.DataContext is not TimelineBlockItemViewModel block)
        {
            return;
        }

        var position = e.GetPosition(control);
        var width = Math.Max(1d, control.Bounds.Width);
        var relativePosition = Math.Clamp(position.X / width, 0d, 1d);
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
