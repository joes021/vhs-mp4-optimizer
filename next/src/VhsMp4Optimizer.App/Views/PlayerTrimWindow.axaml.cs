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

    private void ClosePlayerTrimClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => Close();

    private void OnClosing(object? sender, WindowClosingEventArgs e)
    {
        PlaybackVideoView.MediaPlayer = null;
        if (DataContext is IDisposable disposable)
        {
            disposable.Dispose();
        }
    }

    private void OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape)
        {
            Close();
            e.Handled = true;
        }
    }
}
