using System;
using System.Linq;
using System.IO;
using System.Reflection;
using System.Diagnostics;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Platform.Storage;
using Avalonia.VisualTree;
using VhsMp4Optimizer.App.ViewModels;
using VhsMp4Optimizer.App.Models;
using VhsMp4Optimizer.App.Services;
using VhsMp4Optimizer.Infrastructure.Services;

namespace VhsMp4Optimizer.App.Views;

public partial class MainWindow : Window
{
    private PlayerTrimWindow? _playerTrimWindow;
    private readonly WorkspaceLayoutService _layoutService = new();
    private readonly AppSessionStateService _sessionStateService = new();
    private readonly NextUpdateService _updateService = new();

    public MainWindow()
    {
        InitializeComponent();
        AddHandler(DragDrop.DragOverEvent, DragOverWindow);
        AddHandler(DragDrop.DropEvent, DropWindow);
        DragDrop.SetAllowDrop(this, true);
        Opened += OnOpened;
        Closing += OnClosing;
    }

    private async void OpenPlayerTrimClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (DataContext is not MainWindowViewModel viewModel || viewModel.SelectedQueueItem is null)
        {
            return;
        }

        var selectedItem = viewModel.SelectedQueueItem;

        var editorViewModel = new PlayerTrimWindowViewModel(selectedItem, viewModel.ResolvedFfmpegPath, (timeline, transformSettings) =>
        {
            viewModel.ApplyEditorState(selectedItem.SourcePath, timeline, transformSettings);
        });

        if (_playerTrimWindow is { IsVisible: true })
        {
            if (!ReferenceEquals(_playerTrimWindow.DataContext, editorViewModel) && _playerTrimWindow.DataContext is IDisposable disposable)
            {
                disposable.Dispose();
            }
            _playerTrimWindow.DataContext = editorViewModel;
            await editorViewModel.PrepareForDisplayAsync();
            _playerTrimWindow.Activate();
            return;
        }

        _playerTrimWindow = new PlayerTrimWindow();
        _playerTrimWindow.Closed += (_, _) => _playerTrimWindow = null;
        _playerTrimWindow.DataContext = editorViewModel;
        await editorViewModel.PrepareForDisplayAsync();
        _playerTrimWindow.Show();
        _playerTrimWindow.Activate();
    }

    private void QueueListDoubleTapped(object? sender, TappedEventArgs e)
    {
        if (DataContext is not MainWindowViewModel viewModel)
        {
            return;
        }

        if (sender is not Control control)
        {
            return;
        }

        var sourceControl = e.Source as Control;
        if (sourceControl?.FindAncestorOfType<ListBoxItem>() is not null && viewModel.SelectedQueueItem is not null)
        {
            OpenPlayerTrimClick(sender, new RoutedEventArgs());
            e.Handled = true;
        }
    }

    private async void BrowseFfmpegClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (DataContext is not MainWindowViewModel viewModel)
        {
            return;
        }

        var files = await StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            Title = "Izaberi ffmpeg.exe",
            AllowMultiple = false,
            FileTypeFilter =
            [
                new FilePickerFileType("FFmpeg executable")
                {
                    Patterns = ["ffmpeg.exe", "*.exe"]
                }
            ]
        });

        var selectedPath = files.FirstOrDefault()?.TryGetLocalPath();
        if (!string.IsNullOrWhiteSpace(selectedPath))
        {
            viewModel.SetFfmpegPath(selectedPath);
        }
    }

    private void AutoDetectFfmpegClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (DataContext is MainWindowViewModel viewModel)
        {
            viewModel.AutoDetectFfmpeg();
        }
    }

    private void InstallFfmpegClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (DataContext is MainWindowViewModel viewModel)
        {
            viewModel.StatusMessage = "Pokrecem winget instalaciju za FFmpeg. Posle toga uradi Auto detect FFmpeg ili Browse FFmpeg.";
        }

        Process.Start(new ProcessStartInfo
        {
            FileName = "winget",
            Arguments = "install -e --id Gyan.FFmpeg --accept-source-agreements --accept-package-agreements",
            UseShellExecute = true
        });
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
            await viewModel.UseSelectedFilesAsync(localPaths);
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
            await viewModel.UseSelectedFolderAsync(folderPath);
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

    private async void CheckForUpdatesClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (DataContext is not MainWindowViewModel viewModel)
        {
            return;
        }

        try
        {
            viewModel.StatusMessage = "Proveravam da li postoji novija Next verzija...";
            var assembly = typeof(MainWindow).Assembly;
            var currentVersion = assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion?.Split('+', 2)[0]
                ?? assembly.GetName().Version?.ToString()
                ?? "0.0.0";

            var latest = await _updateService.GetLatestReleaseAsync();
            if (latest is null)
            {
                viewModel.StatusMessage = "Nisam uspeo da procitam GitHub release informacije.";
                return;
            }

            if (NextUpdateService.IsNewerVersion(currentVersion, latest.TagName))
            {
                viewModel.StatusMessage = $"Pronadjena je novija verzija ({latest.TagName}). Otvaram release stranicu.";
                Process.Start(new ProcessStartInfo
                {
                    FileName = latest.ReleaseUrl,
                    UseShellExecute = true
                });
                return;
            }

            viewModel.StatusMessage = $"Vec koristis aktuelnu Next verziju ({currentVersion}).";
        }
        catch (Exception ex)
        {
            viewModel.StatusMessage = $"Provera update-a nije uspela: {ex.Message}";
        }
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

    private void SaveLayoutClick(object? sender, RoutedEventArgs e)
    {
        _layoutService.Save(CaptureLayoutState());
        if (DataContext is MainWindowViewModel viewModel)
        {
            viewModel.StatusMessage = "Layout je sacuvan.";
        }
    }

    private void RestoreDefaultLayoutClick(object? sender, RoutedEventArgs e)
    {
        var state = _layoutService.CreateDefault();
        ApplyLayoutState(state);
        _layoutService.Save(state);
        if (DataContext is MainWindowViewModel viewModel)
        {
            viewModel.StatusMessage = "Vracen je podrazumevani layout.";
        }
    }

    private void DragOverWindow(object? sender, DragEventArgs e)
    {
        if (e.DataTransfer.TryGetFiles() is { Length: > 0 })
        {
            e.DragEffects = DragDropEffects.Copy;
        }
        else
        {
            e.DragEffects = DragDropEffects.None;
        }

        e.Handled = true;
    }

    private async void DropWindow(object? sender, DragEventArgs e)
    {
        if (DataContext is not MainWindowViewModel viewModel)
        {
            return;
        }

        var droppedPaths = e.DataTransfer
            .TryGetFiles()?
            .Select(file => file.TryGetLocalPath())
            .Where(path => !string.IsNullOrWhiteSpace(path))
            .Cast<string>()
            .ToList();

        if (droppedPaths is not { Count: > 0 })
        {
            return;
        }

        await viewModel.UseDroppedPathsAsync(droppedPaths);
        e.Handled = true;
    }

    private void OnOpened(object? sender, EventArgs e)
    {
        ApplyLayoutState(_layoutService.LoadOrDefault());
        if (DataContext is MainWindowViewModel viewModel)
        {
            viewModel.ApplySessionState(_sessionStateService.LoadOrDefault());
        }
    }

    private void OnClosing(object? sender, WindowClosingEventArgs e)
    {
        _layoutService.Save(CaptureLayoutState());
        if (DataContext is MainWindowViewModel viewModel)
        {
            _sessionStateService.Save(viewModel.CaptureSessionState());
        }
    }

    private void ApplyLayoutState(WorkspaceLayoutState state)
    {
        Width = state.WindowWidth;
        Height = state.WindowHeight;

        if (MainLayoutGrid.RowDefinitions.Count >= 10)
        {
            MainLayoutGrid.RowDefinitions[1].Height = new GridLength(state.InputPanelHeight);
            MainLayoutGrid.RowDefinitions[3].Height = new GridLength(state.QuickSetupHeight);
            MainLayoutGrid.RowDefinitions[5].Height = new GridLength(state.AdvancedPanelHeight);
            MainLayoutGrid.RowDefinitions[9].Height = new GridLength(state.StatusPanelHeight);
        }

        if (WorkspaceGrid.ColumnDefinitions.Count >= 3)
        {
            var clampedRatio = Math.Clamp(state.QueuePaneRatio, 0.35, 0.75);
            WorkspaceGrid.ColumnDefinitions[0].Width = new GridLength(clampedRatio, GridUnitType.Star);
            WorkspaceGrid.ColumnDefinitions[2].Width = new GridLength(1 - clampedRatio, GridUnitType.Star);
        }
    }

    private WorkspaceLayoutState CaptureLayoutState()
    {
        var rowDefinitions = MainLayoutGrid.RowDefinitions;
        var columnDefinitions = WorkspaceGrid.ColumnDefinitions;
        var totalWidth = Math.Max(1, columnDefinitions[0].ActualWidth + columnDefinitions[2].ActualWidth);
        var queueRatio = columnDefinitions[0].ActualWidth / totalWidth;

        return new WorkspaceLayoutState
        {
            WindowWidth = Bounds.Width,
            WindowHeight = Bounds.Height,
            InputPanelHeight = rowDefinitions[1].ActualHeight,
            QuickSetupHeight = rowDefinitions[3].ActualHeight,
            AdvancedPanelHeight = rowDefinitions[5].ActualHeight,
            StatusPanelHeight = rowDefinitions[9].ActualHeight,
            QueuePaneRatio = queueRatio
        };
    }
}
