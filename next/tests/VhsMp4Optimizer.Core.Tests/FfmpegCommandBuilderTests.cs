using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Core.Services;
using VhsMp4Optimizer.Infrastructure.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class FfmpegCommandBuilderTests
{
    [Fact]
    public void Should_build_filter_complex_for_multi_segment_export()
    {
        var mediaInfo = new MediaInfo
        {
            SourceName = "test.avi",
            SourcePath = @"F:\test.avi",
            Container = "avi",
            DurationSeconds = 100,
            DurationText = "00:01:40",
            SizeBytes = 1000,
            SizeText = "1000 B",
            OverallBitrateKbps = 9000,
            OverallBitrateText = "9000 kbps",
            VideoCodec = "dvvideo",
            Width = 720,
            Height = 576,
            Resolution = "720x576",
            DisplayAspectRatio = "16:9",
            SampleAspectRatio = "64:45",
            FrameRate = 25,
            FrameRateText = "25 fps",
            FrameCount = 2500,
            VideoBitrateKbps = 8000,
            VideoBitrateText = "8000 kbps",
            AudioCodec = "pcm",
            AudioChannels = 2,
            AudioSampleRateHz = 48000,
            AudioBitrateKbps = 1536,
            AudioBitrateText = "1536 kbps",
            VideoSummary = "dvvideo",
            AudioSummary = "pcm"
        };

        var project = new TimelineProject
        {
            SourcePath = mediaInfo.SourcePath,
            SourceName = mediaInfo.SourceName,
            SourceDurationSeconds = mediaInfo.DurationSeconds,
            Segments = new[]
            {
                new TimelineSegment { Id = Guid.NewGuid(), Kind = TimelineSegmentKind.Keep, TimelineStartSeconds = 0, SourceStartSeconds = 0, SourceEndSeconds = 10 },
                new TimelineSegment { Id = Guid.NewGuid(), Kind = TimelineSegmentKind.Cut, TimelineStartSeconds = 10, SourceStartSeconds = 10, SourceEndSeconds = 20 },
                new TimelineSegment { Id = Guid.NewGuid(), Kind = TimelineSegmentKind.Keep, TimelineStartSeconds = 20, SourceStartSeconds = 20, SourceEndSeconds = 100 }
            }
        };

        var settings = new BatchSettings
        {
            InputPath = mediaInfo.SourcePath,
            OutputDirectory = @"F:\out",
            QualityMode = QualityModes.StandardVhs,
            ScaleMode = ScaleModes.Pal576p,
            AspectMode = AspectModes.Auto,
            AudioBitrate = "160k"
        };

        var request = new ConversionRequest
        {
            MediaInfo = mediaInfo,
            Settings = settings,
            OutputPath = @"F:\out\test.mp4",
            TimelineProject = project
        };

        var args = FfmpegCommandBuilder.BuildArguments(request);
        var joined = string.Join(" ", args);

        Assert.Contains("filter_complex", joined);
        Assert.Contains("trim=start=0", joined);
        Assert.Contains("trim=start=20", joined);
        Assert.Contains("concat=n=2:v=1:a=1", joined);
        Assert.Contains("scale=1024:576", joined);
    }

    [Fact]
    public void Should_clip_sample_to_requested_window()
    {
        var mediaInfo = new MediaInfo
        {
            SourceName = "test.avi",
            SourcePath = @"F:\test.avi",
            Container = "avi",
            DurationSeconds = 100,
            DurationText = "00:01:40",
            SizeBytes = 1000,
            SizeText = "1000 B",
            OverallBitrateKbps = 9000,
            OverallBitrateText = "9000 kbps",
            VideoCodec = "dvvideo",
            Width = 720,
            Height = 576,
            Resolution = "720x576",
            DisplayAspectRatio = "4:3",
            SampleAspectRatio = "16:15",
            FrameRate = 25,
            FrameRateText = "25 fps",
            FrameCount = 2500,
            VideoBitrateKbps = 8000,
            VideoBitrateText = "8000 kbps",
            AudioCodec = "pcm",
            AudioChannels = 2,
            AudioSampleRateHz = 48000,
            AudioBitrateKbps = 1536,
            AudioBitrateText = "1536 kbps",
            VideoSummary = "dvvideo",
            AudioSummary = "pcm"
        };

        var request = new ConversionRequest
        {
            MediaInfo = mediaInfo,
            Settings = new BatchSettings
            {
                InputPath = mediaInfo.SourcePath,
                OutputDirectory = @"F:\out",
                QualityMode = QualityModes.StandardVhs,
                ScaleMode = ScaleModes.Pal576p,
                AspectMode = AspectModes.Auto,
                AudioBitrate = "160k"
            },
            OutputPath = @"F:\out\test-sample.mp4",
            IsSample = true,
            SampleStartSeconds = 30,
            SampleDurationSeconds = 12
        };

        var joined = string.Join(" ", FfmpegCommandBuilder.BuildArguments(request));

        Assert.Contains("trim=start=30", joined);
        Assert.Contains("end=42", joined);
    }

    [Fact]
    public void Should_include_crop_filter_when_item_transform_has_crop()
    {
        var mediaInfo = new MediaInfo
        {
            SourceName = "crop.avi",
            SourcePath = @"F:\crop.avi",
            Container = "avi",
            DurationSeconds = 60,
            DurationText = "00:01:00",
            SizeBytes = 1000,
            SizeText = "1000 B",
            OverallBitrateKbps = 9000,
            OverallBitrateText = "9000 kbps",
            VideoCodec = "dvvideo",
            Width = 720,
            Height = 576,
            Resolution = "720x576",
            DisplayAspectRatio = "4:3",
            SampleAspectRatio = "16:15",
            FrameRate = 25,
            FrameRateText = "25 fps",
            FrameCount = 1500,
            VideoBitrateKbps = 8000,
            VideoBitrateText = "8000 kbps",
            AudioCodec = "pcm",
            AudioChannels = 2,
            AudioSampleRateHz = 48000,
            AudioBitrateKbps = 1536,
            AudioBitrateText = "1536 kbps",
            VideoSummary = "dvvideo",
            AudioSummary = "pcm"
        };

        var request = new ConversionRequest
        {
            MediaInfo = mediaInfo,
            Settings = new BatchSettings
            {
                InputPath = mediaInfo.SourcePath,
                OutputDirectory = @"F:\out",
                QualityMode = QualityModes.StandardVhs,
                ScaleMode = ScaleModes.Pal576p,
                AspectMode = AspectModes.Auto,
                AudioBitrate = "160k"
            },
            OutputPath = @"F:\out\crop.mp4",
            TransformSettings = new ItemTransformSettings
            {
                Crop = new CropSettings { Left = 8, Right = 8, Top = 4, Bottom = 4 }
            }
        };

        var joined = string.Join(" ", FfmpegCommandBuilder.BuildArguments(request));

        Assert.Contains("crop=in_w-16:in_h-8:8:4", joined);
    }

    [Fact]
    public void Should_include_deinterlace_and_denoise_filters_when_requested()
    {
        var mediaInfo = CreateMediaInfo(@"F:\filters.avi");
        var request = new ConversionRequest
        {
            MediaInfo = mediaInfo,
            Settings = new BatchSettings
            {
                InputPath = mediaInfo.SourcePath,
                OutputDirectory = @"F:\out",
                QualityMode = QualityModes.StandardVhs,
                ScaleMode = ScaleModes.Pal576p,
                DeinterlaceMode = DeinterlaceModes.Yadif,
                DenoiseMode = DenoiseModes.Light,
                AudioBitrate = "160k"
            },
            OutputPath = @"F:\out\filters.mp4"
        };

        var joined = string.Join(" ", FfmpegCommandBuilder.BuildArguments(request));

        Assert.Contains("yadif=0:-1:0", joined);
        Assert.Contains("hqdn3d=1.5:1.5:6:6", joined);
    }

    [Fact]
    public void Should_switch_video_encoder_when_encode_engine_is_selected()
    {
        var mediaInfo = CreateMediaInfo(@"F:\engine.avi");
        var request = new ConversionRequest
        {
            MediaInfo = mediaInfo,
            Settings = new BatchSettings
            {
                InputPath = mediaInfo.SourcePath,
                OutputDirectory = @"F:\out",
                QualityMode = QualityModes.HighQualityMp4H264,
                ScaleMode = ScaleModes.Original,
                EncodeEngine = EncodeEngines.NvidiaNvenc,
                AudioBitrate = "192k"
            },
            OutputPath = @"F:\out\engine.mp4"
        };

        var args = FfmpegCommandBuilder.BuildArguments(request);

        Assert.Contains("h264_nvenc", args);
        Assert.DoesNotContain("libx264", args);
    }

    [Fact]
    public void Should_build_segment_output_when_split_output_is_enabled()
    {
        var mediaInfo = CreateMediaInfo(@"F:\split.avi");
        var request = new ConversionRequest
        {
            MediaInfo = mediaInfo,
            Settings = new BatchSettings
            {
                InputPath = mediaInfo.SourcePath,
                OutputDirectory = @"F:\out",
                QualityMode = QualityModes.StandardVhs,
                ScaleMode = ScaleModes.Pal576p,
                SplitOutput = true,
                MaxPartGb = 0.5,
                AudioBitrate = "160k"
            },
            OutputPath = @"F:\out\split-part001.mp4",
            OutputPattern = @"F:\out\split-part%03d.mp4"
        };

        var joined = string.Join(" ", FfmpegCommandBuilder.BuildArguments(request));

        Assert.Contains("-f segment", joined);
        Assert.Contains("-segment_time", joined);
        Assert.Contains("-segment_start_number 1", joined);
        Assert.Contains("-segment_format mp4", joined);
        Assert.Contains("split-part%03d.mp4", joined);
        Assert.Contains("-force_key_frames", joined);
    }

    private static MediaInfo CreateMediaInfo(string sourcePath)
    {
        return new MediaInfo
        {
            SourceName = Path.GetFileName(sourcePath),
            SourcePath = sourcePath,
            Container = "avi",
            DurationSeconds = 60,
            DurationText = "00:01:00",
            SizeBytes = 1000,
            SizeText = "1000 B",
            OverallBitrateKbps = 9000,
            OverallBitrateText = "9000 kbps",
            VideoCodec = "dvvideo",
            Width = 720,
            Height = 576,
            Resolution = "720x576",
            DisplayAspectRatio = "4:3",
            SampleAspectRatio = "16:15",
            FrameRate = 25,
            FrameRateText = "25 fps",
            FrameCount = 1500,
            VideoBitrateKbps = 8000,
            VideoBitrateText = "8000 kbps",
            AudioCodec = "pcm",
            AudioChannels = 2,
            AudioSampleRateHz = 48000,
            AudioBitrateKbps = 1536,
            AudioBitrateText = "1536 kbps",
            VideoSummary = "dvvideo",
            AudioSummary = "pcm"
        };
    }
}
