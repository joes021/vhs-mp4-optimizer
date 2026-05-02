using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Core.Services;

public static class PropertyComparisonBuilder
{
    public static IReadOnlyList<PropertyComparisonRow> Build(QueueItemSummary? item)
    {
        if (item is null || item.MediaInfo is null || item.PlannedOutput is null)
        {
            return new[]
            {
                new PropertyComparisonRow
                {
                    Label = "Info",
                    InputValue = "Izaberi fajl iz queue liste",
                    OutputValue = "Ovde poredimo ulaz i planirani izlaz"
                }
            };
        }

        var input = item.MediaInfo;
        var output = item.PlannedOutput;

        return new[]
        {
            new PropertyComparisonRow { Label = "File", InputValue = item.SourceFile, OutputValue = output.DisplayOutputName },
            new PropertyComparisonRow { Label = "Container", InputValue = input.Container, OutputValue = output.Container },
            new PropertyComparisonRow { Label = "Resolution", InputValue = input.Resolution, OutputValue = output.Resolution },
            new PropertyComparisonRow { Label = "Duration", InputValue = input.DurationText, OutputValue = output.DurationText },
            new PropertyComparisonRow { Label = "FPS", InputValue = input.FrameRateText, OutputValue = input.FrameRateText },
            new PropertyComparisonRow { Label = "Aspect", InputValue = input.DisplayAspectRatio, OutputValue = output.AspectText },
            new PropertyComparisonRow { Label = "Video codec", InputValue = input.VideoCodec, OutputValue = output.VideoCodecLabel },
            new PropertyComparisonRow { Label = "Video bitrate", InputValue = input.VideoBitrateText, OutputValue = output.VideoBitrateComparisonText },
            new PropertyComparisonRow { Label = "Audio codec", InputValue = input.AudioCodec, OutputValue = output.AudioCodecText },
            new PropertyComparisonRow { Label = "Audio bitrate", InputValue = input.AudioBitrateText, OutputValue = output.AudioBitrateText },
            new PropertyComparisonRow { Label = "Total bitrate", InputValue = input.OverallBitrateText, OutputValue = output.BitrateText },
            new PropertyComparisonRow { Label = "Encode engine", InputValue = "--", OutputValue = output.EncodeEngineText },
            new PropertyComparisonRow { Label = "Input size / estimate", InputValue = input.SizeText, OutputValue = output.EstimatedSizeText },
            new PropertyComparisonRow { Label = "USB note", InputValue = "--", OutputValue = output.UsbNoteText }
        };
    }
}
