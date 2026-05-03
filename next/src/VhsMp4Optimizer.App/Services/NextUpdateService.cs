using System;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace VhsMp4Optimizer.App.Services;

public sealed class NextUpdateService
{
    private const string LatestReleaseApiUrl = "https://api.github.com/repos/joes021/vhs-mp4-optimizer/releases/latest";

    public async Task<NextReleaseInfo?> GetLatestReleaseAsync(CancellationToken cancellationToken = default)
    {
        using var client = new HttpClient();
        client.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("VhsMp4OptimizerNext", "1.0"));
        client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/vnd.github+json"));

        using var response = await client.GetAsync(LatestReleaseApiUrl, cancellationToken);
        response.EnsureSuccessStatusCode();
        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
        var root = document.RootElement;

        var tag = root.TryGetProperty("tag_name", out var tagElement) ? tagElement.GetString() : null;
        var url = root.TryGetProperty("html_url", out var urlElement) ? urlElement.GetString() : null;
        if (string.IsNullOrWhiteSpace(tag) || string.IsNullOrWhiteSpace(url))
        {
            return null;
        }

        return new NextReleaseInfo
        {
            TagName = tag,
            ReleaseUrl = url
        };
    }

    public static bool IsNewerVersion(string currentVersion, string releaseTag)
    {
        if (string.IsNullOrWhiteSpace(currentVersion) || string.IsNullOrWhiteSpace(releaseTag))
        {
            return false;
        }

        var normalizedTag = releaseTag.Trim();
        const string prefix = "vhs-mp4-optimizer-next-";
        if (normalizedTag.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
        {
            normalizedTag = normalizedTag[prefix.Length..];
        }

        if (!Version.TryParse(NormalizeSemVer(currentVersion), out var current))
        {
            return false;
        }

        if (!Version.TryParse(NormalizeSemVer(normalizedTag), out var latest))
        {
            return false;
        }

        return latest > current;
    }

    private static string NormalizeSemVer(string value)
    {
        var core = value.Split('+', 2)[0].Trim();
        return core.Count(ch => ch == '.') switch
        {
            0 => core + ".0.0",
            1 => core + ".0",
            _ => core
        };
    }
}

public sealed class NextReleaseInfo
{
    public required string TagName { get; init; }
    public required string ReleaseUrl { get; init; }
}
