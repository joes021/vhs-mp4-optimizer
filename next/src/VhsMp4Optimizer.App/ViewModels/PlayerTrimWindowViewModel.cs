using System;
using System.Collections.ObjectModel;
using System.Linq;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Core.Services;

namespace VhsMp4Optimizer.App.ViewModels;

public partial class PlayerTrimWindowViewModel : ViewModelBase
{
    private readonly Action<TimelineProject> _saveAction;

    public PlayerTrimWindowViewModel(QueueItemSummary item, Action<TimelineProject> saveAction)
    {
        ArgumentNullException.ThrowIfNull(item.MediaInfo);

        _saveAction = saveAction;
        Item = item;
        Timeline = item.TimelineProject ?? TimelineEditorService.CreateInitial(item.MediaInfo);
        Segments = new ObservableCollection<TimelineSegment>(Timeline.Segments);

        WindowTitle = $"Player / Trim - {item.SourceFile}";
        FileSummary = $"{item.SourceFile} | {item.Container} | {item.Resolution} | {item.Duration}";
        InPointText = "00:00:00.00";
        OutPointText = TimelineEditorService.FormatSeconds(item.MediaInfo.DurationSeconds);

        CutSegmentCommand = new RelayCommand(ApplyCutSegment);
        DeleteSegmentCommand = new RelayCommand(DeleteSegment, CanModifySelectedSegment);
        RippleDeleteCommand = new RelayCommand(RippleDeleteSegment, CanModifySelectedSegment);
        MoveLeftCommand = new RelayCommand(MoveLeft, CanModifySelectedSegment);
        MoveRightCommand = new RelayCommand(MoveRight, CanModifySelectedSegment);
        SaveToQueueCommand = new RelayCommand(SaveToQueue);

        RefreshState();
    }

    public QueueItemSummary Item { get; }

    public ObservableCollection<TimelineSegment> Segments { get; }

    public IRelayCommand CutSegmentCommand { get; }

    public IRelayCommand DeleteSegmentCommand { get; }

    public IRelayCommand RippleDeleteCommand { get; }

    public IRelayCommand MoveLeftCommand { get; }

    public IRelayCommand MoveRightCommand { get; }

    public IRelayCommand SaveToQueueCommand { get; }

    [ObservableProperty]
    private string _windowTitle = string.Empty;

    [ObservableProperty]
    private string _fileSummary = string.Empty;

    [ObservableProperty]
    private TimelineProject _timeline;

    [ObservableProperty]
    private TimelineSegment? _selectedSegment;

    [ObservableProperty]
    private string _inPointText = string.Empty;

    [ObservableProperty]
    private string _outPointText = string.Empty;

    [ObservableProperty]
    private string _timelineSummary = string.Empty;

    [ObservableProperty]
    private string _editorHint = "Iseceni segment ostaje na liniji kao CUT dok ga ne obrises ili ripple-delete-ujes.";

    partial void OnSelectedSegmentChanged(TimelineSegment? value)
    {
        DeleteSegmentCommand.NotifyCanExecuteChanged();
        RippleDeleteCommand.NotifyCanExecuteChanged();
        MoveLeftCommand.NotifyCanExecuteChanged();
        MoveRightCommand.NotifyCanExecuteChanged();
    }

    private void ApplyCutSegment()
    {
        if (!TryParseTime(InPointText, out var inSeconds) || !TryParseTime(OutPointText, out var outSeconds))
        {
            EditorHint = "IN/OUT vreme nije u dobrom formatu. Koristi npr. 00:10:05.25";
            return;
        }

        Timeline = TimelineEditorService.CutSegment(Timeline, inSeconds, outSeconds);
        RefreshState();
    }

    private void DeleteSegment()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        Timeline = TimelineEditorService.DeleteSegment(Timeline, SelectedSegment.Id);
        RefreshState();
    }

    private void RippleDeleteSegment()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        Timeline = TimelineEditorService.RippleDeleteSegment(Timeline, SelectedSegment.Id);
        RefreshState();
    }

    private void MoveLeft()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        Timeline = TimelineEditorService.MoveSegmentLeft(Timeline, SelectedSegment.Id);
        RefreshState();
    }

    private void MoveRight()
    {
        if (SelectedSegment is null)
        {
            return;
        }

        Timeline = TimelineEditorService.MoveSegmentRight(Timeline, SelectedSegment.Id);
        RefreshState();
    }

    private void SaveToQueue() => _saveAction(Timeline);

    private bool CanModifySelectedSegment() => SelectedSegment is not null;

    private void RefreshState()
    {
        var selectedId = SelectedSegment?.Id;
        Segments.Clear();
        foreach (var segment in Timeline.Segments)
        {
            Segments.Add(segment);
        }

        SelectedSegment = Segments.FirstOrDefault(segment => segment.Id == selectedId) ?? Segments.FirstOrDefault();
        var keepDuration = TimelineEditorService.GetKeptDurationSeconds(Timeline);
        TimelineSummary = $"Keep duration: {TimelineEditorService.FormatSeconds(keepDuration)} | Segments: {Timeline.Segments.Count}";
    }

    private static bool TryParseTime(string text, out double seconds)
    {
        if (TimeSpan.TryParse(text, out var value))
        {
            seconds = value.TotalSeconds;
            return true;
        }

        seconds = 0;
        return false;
    }
}
