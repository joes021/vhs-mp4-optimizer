using VhsMp4Optimizer.Infrastructure.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class CropDetectServiceTests
{
    [Fact]
    public void ParseCrop_should_extract_last_detected_crop_from_ffmpeg_output()
    {
        const string stderr = """
        [Parsed_cropdetect_0 @ 000001] x1:0 x2:719 y1:0 y2:575 w:720 h:576 x:0 y:0 pts:0 t:0 crop=720:576:0:0
        [Parsed_cropdetect_0 @ 000001] x1:8 x2:711 y1:10 y2:565 w:704 h:556 x:8 y:10 pts:0 t:1 crop=704:556:8:10
        """;

        var crop = CropDetectService.ParseCrop(stderr, 720, 576);

        Assert.NotNull(crop);
        Assert.Equal(8, crop!.Left);
        Assert.Equal(10, crop.Top);
        Assert.Equal(8, crop.Right);
        Assert.Equal(10, crop.Bottom);
    }
}
