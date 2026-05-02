using Avalonia.Controls;
using Avalonia.Input;
using VhsMp4Optimizer.App.ViewModels;

namespace VhsMp4Optimizer.App.Views;

public partial class PlayerTrimWindow : Window
{
    public PlayerTrimWindow()
    {
        InitializeComponent();
    }

    private async void PreviewSliderPointerReleased(object? sender, PointerReleasedEventArgs e)
    {
        if (DataContext is PlayerTrimWindowViewModel viewModel)
        {
            await viewModel.CommitPreviewSliderAsync();
        }
    }
}
