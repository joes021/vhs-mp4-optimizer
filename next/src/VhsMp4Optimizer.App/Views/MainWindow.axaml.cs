using System;
using System.Linq;
using System.IO;
using System.Reflection;
using System.Diagnostics;
using Avalonia.Controls;
using Avalonia.Platform.Storage;
using VhsMp4Optimizer.App.ViewModels;
using VhsMp4Optimizer.Infrastructure.Services;

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

        var editorViewModel = new PlayerTrimWindowViewModel(viewModel.SelectedQueueItem, viewModel.ResolvedFfmpegPath, (timeline, transformSettings) =>
        {
            viewModel.ApplyEditorState(viewModel.SelectedQueueItem.SourcePath, timeline, transformSettings);
        });

        if (_playerTrimWindow is null || !_playerTrimWindow.IsVisible)
        {
            _playerTrimWindow = new PlayerTrimWindow();
        }

        _playerTrimWindow.DataContext = editorViewModel;
        _playerTrimWindow.Show();
        _playerTrimWindow.Activate();
    }

    private async void BrowseInputFilesClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (DataContext is not MainWindowViewModel viewModel)
        {
            return;
        }

        var files = await StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            Title = "Izaberi video fajlove",
            AllowMultiple = true,
            FileTypeFilter =
            [
                new FilePickerFileType("Video files")
                {
                    Patterns = ["*.mp4", "*.avi", "*.mpg", "*.mpeg", "*.mov", "*.mkv", "*.m4v", "*.wmv", "*.ts", "*.m2ts", "*.vob"]
                }
            ]
        });

        var localPaths = files
            .Select(file => file.TryGetLocalPath())
            .Where(path => !string.IsNullOrWhiteSpace(path))
            .Cast<string>()
            .ToList();

        if (localPaths.Count > 0)
        {
            viewModel.UseSelectedFiles(localPaths);
        }
    }

    private async void BrowseInputFolderClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (DataContext is not MainWindowViewModel viewModel)
        {
            return;
        }

        var folders = await StorageProvider.OpenFolderPickerAsync(new FolderPickerOpenOptions
        {
            Title = "Izaberi ulazni folder",
            AllowMultiple = false
        });

        var folderPath = folders.FirstOrDefault()?.TryGetLocalPath();
        if (!string.IsNullOrWhiteSpace(folderPath))
        {
            viewModel.UseSelectedFolder(folderPath);
        }
    }

    private async void BrowseOutputFolderClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (DataContext is not MainWindowViewModel viewModel)
        {
            return;
        }

        var folders = await StorageProvider.OpenFolderPickerAsync(new FolderPickerOpenOptions
        {
            Title = "Izaberi izlazni folder",
            AllowMultiple = false
        });

        var folderPath = folders.FirstOrDefault()?.TryGetLocalPath();
        if (!string.IsNullOrWhiteSpace(folderPath))
        {
            viewModel.SetOutputFolderPath(folderPath);
        }
    }

    private async void JoinFilesCopyClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (DataContext is not MainWindowViewModel viewModel)
        {
            return;
        }

        var files = await StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            Title = "Izaberi fajlove za copy join",
            AllowMultiple = true,
            FileTypeFilter =
            [
                new FilePickerFileType("Video files")
                {
                    Patterns = ["*.mp4", "*.avi", "*.mpg", "*.mpeg", "*.mov", "*.mkv", "*.m4v", "*.wmv", "*.ts", "*.m2ts", "*.vob"]
                }
            ]
        });

        var localPaths = files
            .Select(file => file.TryGetLocalPath())
            .Where(path => !string.IsNullOrWhiteSpace(path))
            .Cast<string>()
            .ToList();

        if (localPaths.Count < 2)
        {
            return;
        }

        var suggestedName = $"{Path.GetFileNameWithoutExtension(localPaths[0])}-joined{Path.GetExtension(localPaths[0])}";
        var target = await StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions
        {
            Title = "Snimi spojeni fajl",
            SuggestedFileName = suggestedName,
            DefaultExtension = Path.GetExtension(localPaths[0]),
            FileTypeChoices =
            [
                new FilePickerFileType("Video files")
                {
                    Patterns = ["*" + Path.GetExtension(localPaths[0])]
                }
            ]
        });

        var outputPath = target?.TryGetLocalPath();
        if (!string.IsNullOrWhiteSpace(outputPath))
        {
            await viewModel.JoinFilesCopyAsync(localPaths, outputPath);
        }
    }

    private void OpenUserGuideClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (DataContext is not MainWindowViewModel viewModel)
        {
            return;
        }

        var guidePath = DesktopGuideLocator.FindGuidePath(AppContext.BaseDirectory);
        if (string.IsNullOrWhiteSpace(guidePath) || !File.Exists(guidePath))
        {
            viewModel.StatusMessage = "User guide nije pronadjen uz novu Avalonia aplikaciju.";
            return;
        }

        Process.Start(new ProcessStartInfo
        {
            FileName = guidePath,
            UseShellExecute = true
        });
    }

    private async void SaveQueueClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (DataContext is not MainWindowViewModel viewModel)
        {
            return;
        }

        var target = await StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions
        {
            Title = "Sacuvaj queue stanje",
            SuggestedFileName = "vhs-queue.json",
            DefaultExtension = ".json",
            FileTypeChoices =
            [
                new FilePickerFileType("JSON")
                {
                    Patterns = ["*.json"]
                }
            ]
        });

        var outputPath = target?.TryGetLocalPath();
        if (!string.IsNullOrWhiteSpace(outputPath))
        {
            await viewModel.SaveQueueAsync(outputPath);
        }
    }

    private async void LoadQueueClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (DataContext is not MainWindowViewModel viewModel)
        {
            return;
        }

        var files = await StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            Title = "Ucitaj queue stanje",
            AllowMultiple = false,
            FileTypeFilter =
            [
                new FilePickerFileType("JSON")
                {
                    Patterns = ["*.json"]
                }
            ]
        });

        var inputPath = files.FirstOrDefault()?.TryGetLocalPath();
        if (!string.IsNullOrWhiteSpace(inputPath))
        {
            await viewModel.LoadQueueAsync(inputPath);
        }
    }

    private void OpenAboutClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var assembly = typeof(MainWindow).Assembly;
        var version = assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
            ?? assembly.GetName().Version?.ToString()
            ?? "dev";
        var guidePath = DesktopGuideLocator.FindGuidePath(AppContext.BaseDirectory) ?? "Guide nije pronadjen";

        var window = new AboutWindow
        {
            DataContext = new AboutWindowViewModel
            {
                AppName = "VHS MP4 Optimizer Next",
                Version = version,
                InstallPath = AppContext.BaseDirectory,
                GuidePath = guidePath,
                BranchHint = "codex/avalonia-migration"
            }
        };

        window.ShowDialog(this);
    }
}
