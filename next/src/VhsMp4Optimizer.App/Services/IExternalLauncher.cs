using System.Diagnostics;

namespace VhsMp4Optimizer.App.Services;

public interface IExternalLauncher
{
    void OpenPath(string path);
}

public sealed class ExternalLauncher : IExternalLauncher
{
    public void OpenPath(string path)
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = path,
            UseShellExecute = true
        });
    }
}
