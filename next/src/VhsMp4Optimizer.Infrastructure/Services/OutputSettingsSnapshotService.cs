using System.Text.Json;
using VhsMp4Optimizer.Core.Models;

namespace VhsMp4Optimizer.Infrastructure.Services;

public sealed class OutputSettingsSnapshotService
{
    private static readonly JsonSerializerOptions SerializerOptions = new()
    {
        WriteIndented = true
    };

    public async Task SaveAsync(string path, OutputSettingsSnapshot snapshot, CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(path);
        ArgumentNullException.ThrowIfNull(snapshot);

        var directory = Path.GetDirectoryName(path);
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }

        await using var stream = File.Create(path);
        await JsonSerializer.SerializeAsync(stream, snapshot, SerializerOptions, cancellationToken);
    }

    public async Task<OutputSettingsSnapshot> LoadAsync(string path, CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(path);
        await using var stream = File.OpenRead(path);
        var snapshot = await JsonSerializer.DeserializeAsync<OutputSettingsSnapshot>(stream, SerializerOptions, cancellationToken);
        return snapshot ?? throw new InvalidOperationException("Output settings snapshot je prazan ili neispravan.");
    }
}
