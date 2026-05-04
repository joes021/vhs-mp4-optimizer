using VhsMp4Optimizer.Core.Models;
using VhsMp4Optimizer.Infrastructure.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class OutputSettingsSnapshotServiceTests : IDisposable
{
    private readonly string _rootPath;

    public OutputSettingsSnapshotServiceTests()
    {
        _rootPath = Path.Combine(Path.GetTempPath(), $"vhs-next-output-settings-{Guid.NewGuid():N}");
        Directory.CreateDirectory(_rootPath);
    }

    [Fact]
    public async Task Save_and_load_should_roundtrip_output_settings_snapshot()
    {
        var service = new OutputSettingsSnapshotService();
        var settingsPath = Path.Combine(_rootPath, "output-settings.json");
        var snapshot = new OutputSettingsSnapshot
        {
            SelectedPreset = "Custom",
            QualityMode = "HEVC za novije uredjaje",
            ScaleMode = "PAL 576p",
            AspectMode = "Auto",
            DeinterlaceMode = "YADIF",
            DenoiseMode = "Medium",
            EncodeEngine = "Auto",
            VideoBitrate = "3500k",
            AudioBitrate = "128k",
            SplitOutput = true,
            MaxPartGb = 3.8,
            SampleStartText = "00:00:00",
            SampleDurationText = "00:02:00"
        };

        await service.SaveAsync(settingsPath, snapshot);
        var loaded = await service.LoadAsync(settingsPath);

        Assert.Equal(snapshot.SelectedPreset, loaded.SelectedPreset);
        Assert.Equal(snapshot.QualityMode, loaded.QualityMode);
        Assert.Equal(snapshot.SplitOutput, loaded.SplitOutput);
        Assert.Equal(snapshot.MaxPartGb, loaded.MaxPartGb);
        Assert.Equal(snapshot.SampleDurationText, loaded.SampleDurationText);
    }

    public void Dispose()
    {
        if (Directory.Exists(_rootPath))
        {
            Directory.Delete(_rootPath, true);
        }
    }
}
