using VhsMp4Optimizer.App.Models;
using VhsMp4Optimizer.App.Services;

namespace VhsMp4Optimizer.Core.Tests;

public sealed class AppSessionStateServiceTests : IDisposable
{
    private readonly string _rootPath;

    public AppSessionStateServiceTests()
    {
        _rootPath = Path.Combine(Path.GetTempPath(), $"vhs-next-session-{Guid.NewGuid():N}");
        Directory.CreateDirectory(_rootPath);
    }

    [Fact]
    public void Save_and_load_should_roundtrip_basic_paths()
    {
        var statePath = Path.Combine(_rootPath, "app-session.json");
        var service = new AppSessionStateService(statePath);

        service.Save(new AppSessionState
        {
            InputFolder = @"F:\Ulaz",
            OutputFolder = @"F:\Izlaz",
            FfmpegPath = @"C:\ffmpeg\bin\ffmpeg.exe"
        });

        var loaded = service.LoadOrDefault();

        Assert.Equal(@"F:\Ulaz", loaded.InputFolder);
        Assert.Equal(@"F:\Izlaz", loaded.OutputFolder);
        Assert.Equal(@"C:\ffmpeg\bin\ffmpeg.exe", loaded.FfmpegPath);
    }

    public void Dispose()
    {
        if (Directory.Exists(_rootPath))
        {
            Directory.Delete(_rootPath, true);
        }
    }
}
