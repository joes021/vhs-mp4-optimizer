using VhsMp4Optimizer.Core.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class WorkflowPresetServiceTests
{
    [Fact]
    public void UsbStandard_should_enable_split_and_pal_scale()
    {
        var preset = WorkflowPresetService.TryGet(WorkflowPresetService.UsbStandard);

        Assert.NotNull(preset);
        Assert.Equal(QualityModes.UsbSmallFile, preset!.QualityMode);
        Assert.Equal(ScaleModes.Pal576p, preset.ScaleMode);
        Assert.True(preset.SplitOutput);
        Assert.Equal("3500k", preset.VideoBitrate);
    }

    [Fact]
    public void Names_should_end_with_custom()
    {
        Assert.Equal(WorkflowPresetService.Custom, WorkflowPresetService.Names[^1]);
    }
}
