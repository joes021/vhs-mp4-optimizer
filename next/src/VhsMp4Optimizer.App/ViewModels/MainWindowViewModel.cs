using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.App.ViewModels;

public partial class MainWindowViewModel : ViewModelBase
{
    public MainWindowViewModel()
    {
        QueueItems = new ObservableCollection<QueueItemSummary>
        {
            new()
            {
                SourceFile = "Potpisivanje Knjige.avi",
                OutputFile = "Potpisivanje Knjige.mp4",
                Container = "avi",
                Resolution = "720x576",
                Duration = "00:43:22",
                Video = "DV / 4:3 / 25 fps",
                Audio = "pcm / stereo",
                Status = "Spremno za migraciju"
            }
        };

        ComparisonRows = new ObservableCollection<PropertyComparisonRow>
        {
            new() { Label = "File", InputValue = "Potpisivanje Knjige.avi", OutputValue = "Potpisivanje Knjige.mp4" },
            new() { Label = "Container", InputValue = "avi", OutputValue = "mp4" },
            new() { Label = "Resolution", InputValue = "720x576", OutputValue = "768x576" },
            new() { Label = "Duration", InputValue = "00:43:22", OutputValue = "00:43:22" },
            new() { Label = "Video codec", InputValue = "DV", OutputValue = "H.264" },
            new() { Label = "Audio codec", InputValue = "PCM", OutputValue = "AAC 160k" },
            new() { Label = "Estimate", InputValue = "2.9 GB", OutputValue = "1.6 GB" },
            new() { Label = "USB note", InputValue = "--", OutputValue = "FAT32 OK / 1 deo" }
        };
    }

    [ObservableProperty]
    private string _windowTitle = "VHS MP4 Optimizer Next";

    [ObservableProperty]
    private string _inputFolder = @"F:\Veliki avi";

    [ObservableProperty]
    private string _outputFolder = @"F:\Veliki avi\vhs-mp4-output";

    [ObservableProperty]
    private string _selectedPreset = "USB standard";

    [ObservableProperty]
    private bool _advancedVisible = true;

    [ObservableProperty]
    private string _qualityMode = "TV / univerzalni Smart TV";

    [ObservableProperty]
    private string _scaleMode = "PAL 576p";

    [ObservableProperty]
    private string _videoBitrate = "5000k";

    [ObservableProperty]
    private string _audioBitrate = "160k";

    [ObservableProperty]
    private string _statusMessage = "Faza 2: nova Avalonia osnova je podignuta i spremna za batch migraciju.";

    [ObservableProperty]
    private string _progressMessage = "Nema aktivne obrade. Sledece prenosimo scan, queue i planned output logiku.";

    [ObservableProperty]
    private string _logMessage = "Migracioni branch je aktivan. Ovaj ekran je nova desktop osnova koja menja stari PowerShell GUI.";

    public ObservableCollection<QueueItemSummary> QueueItems { get; }

    public ObservableCollection<PropertyComparisonRow> ComparisonRows { get; }
}
