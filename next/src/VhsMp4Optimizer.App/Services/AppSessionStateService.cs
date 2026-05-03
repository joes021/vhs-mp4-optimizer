using System;
using System.IO;
using System.Text.Json;
using VhsMp4Optimizer.App.Models;

namespace VhsMp4Optimizer.App.Services;

public sealed class AppSessionStateService
{
    private readonly string _statePath;

    public AppSessionStateService(string? statePath = null)
    {
        _statePath = statePath ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "VhsMp4OptimizerNext",
            "app-session.json");
    }

    public AppSessionState LoadOrDefault()
    {
        try
        {
            if (!File.Exists(_statePath))
            {
                return new AppSessionState();
            }

            var json = File.ReadAllText(_statePath);
            var state = JsonSerializer.Deserialize<AppSessionState>(json);
            return Normalize(state);
        }
        catch
        {
            return new AppSessionState();
        }
    }

    public void Save(AppSessionState state)
    {
        var normalized = Normalize(state);
        Directory.CreateDirectory(Path.GetDirectoryName(_statePath)!);
        var json = JsonSerializer.Serialize(normalized, new JsonSerializerOptions
        {
            WriteIndented = true
        });
        File.WriteAllText(_statePath, json);
    }

    private static AppSessionState Normalize(AppSessionState? state)
    {
        state ??= new AppSessionState();
        state.InputFolder = string.IsNullOrWhiteSpace(state.InputFolder) ? string.Empty : state.InputFolder.Trim();
        state.OutputFolder = string.IsNullOrWhiteSpace(state.OutputFolder) ? string.Empty : state.OutputFolder.Trim();
        state.FfmpegPath = string.IsNullOrWhiteSpace(state.FfmpegPath) ? null : state.FfmpegPath.Trim();
        return state;
    }
}
