namespace VhsMp4Optimizer.Core.Services;

public static class QualityModes
{
    public const string UniversalMp4H264 = "Universal MP4 H.264";
    public const string SmallMp4H264 = "Small MP4 H.264";
    public const string HighQualityMp4H264 = "High Quality MP4 H.264";
    public const string HevcH265Smaller = "HEVC H.265 Smaller";
    public const string StandardVhs = "Standard VHS";
    public const string TvSmart = "TV / univerzalni Smart TV";
    public const string OldTv = "Stari TV / media player";
    public const string LaptopPc = "Laptop / PC";
    public const string Phone = "Telefon";
    public const string Tablet = "Tablet";
    public const string YoutubeUpload = "YouTube upload";
    public const string UsbSmallFile = "USB mali fajl";
    public const string ArchiveBetterQuality = "Arhiva / bolji kvalitet";
    public const string HevcForNewerDevices = "HEVC za novije uredjaje";

    public static IReadOnlyList<string> All { get; } = new[]
    {
        UniversalMp4H264,
        SmallMp4H264,
        HighQualityMp4H264,
        HevcH265Smaller,
        StandardVhs,
        "---",
        TvSmart,
        OldTv,
        LaptopPc,
        Phone,
        Tablet,
        YoutubeUpload,
        UsbSmallFile,
        ArchiveBetterQuality,
        HevcForNewerDevices
    };
}
