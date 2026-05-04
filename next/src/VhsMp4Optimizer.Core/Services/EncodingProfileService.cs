namespace VhsMp4Optimizer.Core.Services;

public static class EncodingProfileService
{
    public static EncodingProfile Resolve(string qualityMode)
    {
        return qualityMode switch
        {
            QualityModes.SmallMp4H264 or QualityModes.UsbSmallFile or QualityModes.Phone
                => new EncodingProfile("libx264", "H.264", false, 24, "slow", "128k", 3500),
            QualityModes.HighQualityMp4H264 or QualityModes.ArchiveBetterQuality or QualityModes.YoutubeUpload
                => new EncodingProfile("libx264", "H.264", false, 20, "slow", "192k", 9000),
            QualityModes.HevcH265Smaller or QualityModes.HevcForNewerDevices or QualityModes.Tablet
                => new EncodingProfile("libx265", "H.265", true, 26, "medium", "128k", 2800),
            QualityModes.OldTv
                => new EncodingProfile("libx264", "H.264", false, 22, "medium", "160k", 4500),
            QualityModes.LaptopPc
                => new EncodingProfile("libx264", "H.264", false, 22, "slow", "160k", 6000),
            QualityModes.TvSmart
                => new EncodingProfile("libx264", "H.264", false, 21, "slow", "160k", 6500),
            _ => new EncodingProfile("libx264", "H.264", false, 22, "slow", "160k", 5000)
        };
    }
}

public sealed record EncodingProfile(
    string VideoCodec,
    string CodecLabel,
    bool WantsHevc,
    int Crf,
    string Preset,
    string AudioBitrate,
    int VideoKbps);
