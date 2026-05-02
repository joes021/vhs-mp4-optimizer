using System.Globalization;
using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Core.Services;

public static class TimelineStripService
{
    public static IReadOnlyList<TimelineVisualBlock> BuildBlocks(
        TimelineProject? project,
        double preferredWidth = 960,
        double minimumWidth = 56)
    {
        if (project is null || project.Segments.Count == 0)
        {
            return [];
        }

        var ordered = project.Segments
            .Where(segment => segment.DurationSeconds > 0)
            .OrderBy(segment => segment.TimelineStartSeconds)
            .ToList();

        if (ordered.Count == 0)
        {
            return [];
        }

        var totalDuration = ordered.Max(segment => segment.TimelineStartSeconds + segment.DurationSeconds);
        if (totalDuration <= 0)
        {
            return [];
        }

        var safePreferredWidth = Math.Max(1, preferredWidth);
        var safeMinimumWidth = Math.Max(0, minimumWidth);

        return ordered.Select(segment =>
        {
            var proportionalWidth = (segment.DurationSeconds / totalDuration) * safePreferredWidth;
            var widthPixels = Math.Max(safeMinimumWidth, proportionalWidth);
            return new TimelineVisualBlock
            {
                SegmentId = segment.Id,
                Kind = segment.Kind,
                TimelineStartSeconds = segment.TimelineStartSeconds,
                SourceStartSeconds = segment.SourceStartSeconds,
                SourceEndSeconds = segment.SourceEndSeconds,
                DurationSeconds = segment.DurationSeconds,
                WidthPixels = widthPixels,
                Label = segment.Kind.ToString().ToUpperInvariant(),
                Summary = BuildSummary(segment)
            };
        }).ToList();
    }

    private static string BuildSummary(TimelineSegment segment)
    {
        return string.Create(
            CultureInfo.InvariantCulture,
            $"{TimelineEditorService.FormatSeconds(segment.SourceStartSeconds)} -> {TimelineEditorService.FormatSeconds(segment.SourceEndSeconds)}");
    }
}
