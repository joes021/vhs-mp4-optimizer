using System;
using System.IO;
using System.Text.Json;
using VhsMp4Optimizer.App.Models;

namespace VhsMp4Optimizer.App.Services;

public sealed class WorkspaceLayoutService
{
    private readonly string _layoutPath;

    public WorkspaceLayoutService(string? layoutPath = null)
    {
        _layoutPath = layoutPath ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "VhsMp4OptimizerNext",
            "layout-state.json");
    }

    public WorkspaceLayoutState LoadOrDefault()
    {
        try
        {
            if (!File.Exists(_layoutPath))
            {
                return CreateDefault();
            }

            var json = File.ReadAllText(_layoutPath);
            var state = JsonSerializer.Deserialize<WorkspaceLayoutState>(json);
            return Normalize(state);
        }
        catch
        {
            return CreateDefault();
        }
    }

    public void Save(WorkspaceLayoutState state)
    {
        var normalized = Normalize(state);
        Directory.CreateDirectory(Path.GetDirectoryName(_layoutPath)!);
        var json = JsonSerializer.Serialize(normalized, new JsonSerializerOptions
        {
            WriteIndented = true
        });
        File.WriteAllText(_layoutPath, json);
    }

    public WorkspaceLayoutState CreateDefault() => new();

    private static WorkspaceLayoutState Normalize(WorkspaceLayoutState? state)
    {
        state ??= new WorkspaceLayoutState();
        state.WindowWidth = Clamp(state.WindowWidth, 1200, 3200, 1440);
        state.WindowHeight = Clamp(state.WindowHeight, 780, 2200, 900);
        state.InputPanelHeight = Clamp(state.InputPanelHeight, 96, 260, 112);
        state.QuickSetupHeight = Clamp(state.QuickSetupHeight, 140, 320, 164);
        state.AdvancedPanelHeight = Clamp(state.AdvancedPanelHeight, 150, 340, 176);
        state.StatusPanelHeight = Clamp(state.StatusPanelHeight, 150, 420, 220);
        state.QueuePaneRatio = Clamp(state.QueuePaneRatio, 0.35, 0.75, 0.6);
        return state;
    }

    private static double Clamp(double value, double min, double max, double fallback)
    {
        if (double.IsNaN(value) || double.IsInfinity(value))
        {
            return fallback;
        }

        return Math.Min(max, Math.Max(min, value));
    }
}
