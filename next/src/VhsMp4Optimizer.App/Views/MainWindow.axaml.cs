using Avalonia.Controls;
using VhsMp4Optimizer.App.ViewModels;

namespace VhsMp4Optimizer.App.Views;

public partial class MainWindow : Window
{
    private PlayerTrimWindow? _playerTrimWindow;

    public MainWindow()
    {
        InitializeComponent();
    }

    private void OpenPlayerTrimClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (DataContext is not MainWindowViewModel viewModel || viewModel.SelectedQueueItem is null)
        {
            return;
        }

        var editorViewModel = new PlayerTrimWindowViewModel(viewModel.SelectedQueueItem, timeline =>
        {
            viewModel.ApplyTimelineProject(viewModel.SelectedQueueItem.SourcePath, timeline);
        });

        if (_playerTrimWindow is null || !_playerTrimWindow.IsVisible)
        {
            _playerTrimWindow = new PlayerTrimWindow();
        }

        _playerTrimWindow.DataContext = editorViewModel;
        _playerTrimWindow.Show();
        _playerTrimWindow.Activate();
    }
}
