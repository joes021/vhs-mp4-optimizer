from pathlib import Path
import json
import os
import subprocess


ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "scripts" / "optimize-vhs-mp4-core.psm1"


def test_core_parses_trim_window_time_formats_and_rejects_invalid_range() -> None:
    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$a = Convert-VhsMp4TimeTextToSeconds -Value '01:02:03'
$b = Convert-VhsMp4TimeTextToSeconds -Value '12:34'
$c = Convert-VhsMp4TimeTextToSeconds -Value '90.5'
$comma = Convert-VhsMp4TimeTextToSeconds -Value '90,5'
$window = Get-VhsMp4TrimWindow -TrimStart '00:01:00' -TrimEnd '00:03:30'
$endOnly = Get-VhsMp4TrimWindow -TrimStart '' -TrimEnd '00:40:00'
$blank = Get-VhsMp4TrimWindow -TrimStart '' -TrimEnd ''
$bad = $false
try {{ Get-VhsMp4TrimWindow -TrimStart '00:03:30' -TrimEnd '00:01:00' | Out-Null }} catch {{ $bad = $true }}
[pscustomobject]@{{
  A = $a
  B = $b
  C = $c
  Comma = $comma
  Duration = $window.DurationSeconds
  Summary = $window.Summary
  EndOnlySummary = $endOnly.Summary
  EndOnlyDuration = $endOnly.DurationSeconds
  BlankSummary = $blank.Summary
  BadRejected = $bad
}} | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["A"] == 3723
    assert payload["B"] == 754
    assert payload["C"] == 90.5
    assert payload["Comma"] == 90.5
    assert payload["Duration"] == 150
    assert payload["Summary"] == "00:01:00 - 00:03:30"
    assert payload["EndOnlySummary"] == "00:00:00 - 00:40:00"
    assert payload["EndOnlyDuration"] == 2400
    assert payload["BlankSummary"] == ""
    assert payload["BadRejected"] is True


def test_core_normalizes_multi_trim_segments_and_rejects_overlap() -> None:
    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$segments = @(
  [pscustomobject]@{{ StartText = '00:02:00'; EndText = '00:02:30' }},
  [pscustomobject]@{{ TrimStart = '00:00:10'; TrimEnd = '00:00:20' }}
)
$overlapRejected = $false
try {{
  Get-VhsMp4TrimSegments -TrimSegments @(
    [pscustomobject]@{{ StartText = '00:00:10'; EndText = '00:00:20' }},
    [pscustomobject]@{{ StartText = '00:00:15'; EndText = '00:00:25' }}
  ) | Out-Null
}}
catch {{
  $overlapRejected = $true
}}
$result = Get-VhsMp4TrimSegments -TrimSegments $segments
[pscustomobject]@{{
  Count = $result.Count
  Summary = $result.Summary
  TotalDurationSeconds = $result.TotalDurationSeconds
  FirstSummary = $result.Segments[0].Summary
  SecondSummary = $result.Segments[1].Summary
  OverlapRejected = $overlapRejected
}} | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["Count"] == 2
    assert payload["FirstSummary"] == "00:00:10 - 00:00:20"
    assert payload["SecondSummary"] == "00:02:00 - 00:02:30"
    assert payload["Summary"] == "2 seg | 00:00:10 - 00:00:20 ; 00:02:00 - 00:02:30"
    assert payload["TotalDurationSeconds"] == 40
    assert payload["OverlapRejected"] is True


def test_core_time_formatters_reject_nan_and_infinity_values() -> None:
    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$nanTime = Format-VhsMp4FfmpegTime -Seconds ([double]::NaN)
$infTime = Format-VhsMp4FfmpegTime -Seconds ([double]::PositiveInfinity)
[pscustomobject]@{{
  NanTime = $nanTime
  InfTime = $infTime
}} | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["NanTime"] == ""
    assert payload["InfTime"] == ""


def test_core_supports_copy_only_split_and_join_tools(tmp_path: Path) -> None:
    source_dir = tmp_path / "source"
    source_dir.mkdir()

    split_source = source_dir / "snimak.mp4"
    join_source_a = source_dir / "video1.mp4"
    join_source_b = source_dir / "video2.mp4"
    split_source.write_text("split-source", encoding="utf-8")
    join_source_a.write_text("join-a", encoding="utf-8")
    join_source_b.write_text("join-b", encoding="utf-8")

    fake_ffmpeg = tmp_path / "fake_ffmpeg_tools.ps1"
    fake_ffmpeg.write_text(
        """
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$logPath = $env:FAKE_FFMPEG_LOG
if ($logPath) {
  Add-Content -LiteralPath $logPath -Value ($Args -join "`n") -Encoding UTF8
  Add-Content -LiteralPath $logPath -Value "`n---" -Encoding UTF8
}

$outputPath = $Args[-1]
if ($Args -contains 'segment') {
  $segmentTimesIndex = [Array]::IndexOf($Args, '-segment_times')
  $segmentTimes = if ($segmentTimesIndex -ge 0 -and ($segmentTimesIndex + 1) -lt $Args.Count) { $Args[$segmentTimesIndex + 1] } else { '' }
  $partCount = 1
  if (-not [string]::IsNullOrWhiteSpace($segmentTimes)) {
    $partCount = ($segmentTimes -split ',').Count + 1
  }

  for ($index = 1; $index -le $partCount; $index++) {
    $candidate = if ($outputPath -match '%03d') {
      $outputPath -replace '%03d', ('{0:D3}' -f $index)
    }
    else {
      [string]::Format($outputPath, $index)
    }
    Set-Content -LiteralPath $candidate -Value ('split-part-' + $index) -Encoding UTF8
  }
}
else {
  Set-Content -LiteralPath $outputPath -Value 'joined-output' -Encoding UTF8
}
""".strip(),
        encoding="utf-8",
    )

    fake_ffmpeg_log = tmp_path / "fake-ffmpeg-tools.log"
    env = os.environ.copy()
    env["FAKE_FFMPEG_LOG"] = str(fake_ffmpeg_log)

    split_pattern = tmp_path / "snimak-part{0:D3}.mp4"
    join_output = tmp_path / "video1plus2.mp4"

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$split = Invoke-VhsMp4CopySplit -SourcePath '{split_source}' -OutputPattern '{split_pattern}' -PartCount 3 -DurationSeconds 90 -FfmpegPath '{fake_ffmpeg}'
$join = Invoke-VhsMp4CopyJoin -SourcePaths @('{join_source_a}', '{join_source_b}') -OutputPath '{join_output}' -FfmpegPath '{fake_ffmpeg}'
[pscustomobject]@{{
  SplitSuccess = $split.Success
  SplitExitCode = $split.ExitCode
  SplitPartCount = $split.PartCount
  SplitOutputs = @($split.OutputPaths)
  SplitTimes = @($split.SegmentTimes)
  JoinSuccess = $join.Success
  JoinExitCode = $join.ExitCode
  JoinOutputPath = $join.OutputPath
}} | ConvertTo-Json -Depth 6 -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["SplitSuccess"] is True
    assert payload["SplitExitCode"] == 0
    assert payload["SplitPartCount"] == 3
    assert len(payload["SplitOutputs"]) == 3
    assert payload["SplitOutputs"][0].endswith("snimak-part001.mp4")
    assert payload["SplitOutputs"][1].endswith("snimak-part002.mp4")
    assert payload["SplitOutputs"][2].endswith("snimak-part003.mp4")
    assert payload["SplitTimes"] == ["00:00:30", "00:01:00"]
    assert split_pattern.with_name("snimak-part001.mp4").exists()
    assert split_pattern.with_name("snimak-part002.mp4").exists()
    assert split_pattern.with_name("snimak-part003.mp4").exists()

    assert payload["JoinSuccess"] is True
    assert payload["JoinExitCode"] == 0
    assert payload["JoinOutputPath"].endswith("video1plus2.mp4")
    assert join_output.exists()

    fake_invocation = fake_ffmpeg_log.read_text(encoding="utf-8")
    assert "-segment_times" in fake_invocation
    assert "00:00:30,00:01:00" in fake_invocation
    assert "-c" in fake_invocation
    assert "copy" in fake_invocation
    assert "-f" in fake_invocation
    assert "concat" in fake_invocation
    assert str(join_output) in fake_invocation


def test_core_scans_mp4_avi_and_mpeg_files_applies_quality_modes_and_runs_batch(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    skipped_source = input_dir / "alpha.mp4"
    processed_source = input_dir / "beta.mp4"
    avi_source = input_dir / "msdv_capture.avi"
    mpg_source = input_dir / "dvd_capture.mpg"
    mpeg_source = input_dir / "tape_export.mpeg"
    ignored_source = input_dir / "notes.txt"
    skipped_source.write_text("alpha-source", encoding="utf-8")
    processed_source.write_text("beta-source", encoding="utf-8")
    avi_source.write_text("avi-source", encoding="utf-8")
    mpg_source.write_text("mpg-source", encoding="utf-8")
    mpeg_source.write_text("mpeg-source", encoding="utf-8")
    ignored_source.write_text("ignore", encoding="utf-8")

    existing_output = output_dir / "alpha.mp4"
    existing_output.write_text("keep-existing", encoding="utf-8")

    fake_ffmpeg = tmp_path / "fake_ffmpeg.ps1"
    fake_ffmpeg.write_text(
        """
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$logPath = $env:FAKE_FFMPEG_LOG
if ($logPath) {
  Add-Content -LiteralPath $logPath -Value ($Args -join "`n") -Encoding UTF8
  Add-Content -LiteralPath $logPath -Value "`n---" -Encoding UTF8
}

$outputPath = $Args[-1]
Set-Content -LiteralPath $outputPath -Value "optimized" -Encoding UTF8
""".strip(),
        encoding="utf-8",
    )

    fake_ffmpeg_log = tmp_path / "fake-ffmpeg.log"
    env = os.environ.copy()
    env["FAKE_FFMPEG_LOG"] = str(fake_ffmpeg_log)

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$plan = Get-VhsMp4Plan -InputDir '{input_dir}' -OutputDir '{output_dir}'
$standard = Get-VhsMp4FfmpegArguments -SourcePath '{processed_source}' -OutputPath '{output_dir / "standard.mp4"}' -QualityMode 'Standard VHS'
$smaller = Get-VhsMp4FfmpegArguments -SourcePath '{processed_source}' -OutputPath '{output_dir / "smaller.mp4"}' -QualityMode 'Smaller File'
$better = Get-VhsMp4FfmpegArguments -SourcePath '{processed_source}' -OutputPath '{output_dir / "better.mp4"}' -QualityMode 'Better Quality'
$withProgress = Get-VhsMp4FfmpegArguments -SourcePath '{avi_source}' -OutputPath '{output_dir / "progress.mp4"}' -QualityMode 'Standard VHS' -ProgressPath '{output_dir / "progress.txt"}'
$summary = Invoke-VhsMp4Batch -InputDir '{input_dir}' -OutputDir '{output_dir}' -QualityMode 'Standard VHS' -FfmpegPath '{fake_ffmpeg}'
[pscustomobject]@{{
  plan = @($plan | Select-Object SourceName, Status, OutputPath)
  standard = $standard
  smaller = $smaller
  better = $better
  withProgress = $withProgress
  processed = $summary.ProcessedCount
  skipped = $summary.SkippedCount
  failed = $summary.FailedCount
  log = $summary.LogPath
}} | ConvertTo-Json -Depth 6
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)
    statuses = {item["SourceName"]: item["Status"] for item in payload["plan"]}

    assert statuses == {
        "alpha.mp4": "skipped",
        "beta.mp4": "queued",
        "dvd_capture.mpg": "queued",
        "msdv_capture.avi": "queued",
        "tape_export.mpeg": "queued",
    }
    assert payload["processed"] == 4
    assert payload["skipped"] == 1
    assert payload["failed"] == 0
    assert existing_output.read_text(encoding="utf-8") == "keep-existing"
    assert processed_source.read_text(encoding="utf-8") == "beta-source"
    assert avi_source.read_text(encoding="utf-8") == "avi-source"
    assert mpg_source.read_text(encoding="utf-8") == "mpg-source"
    assert mpeg_source.read_text(encoding="utf-8") == "mpeg-source"
    assert (output_dir / "beta.mp4").read_text(encoding="utf-8").lstrip("\ufeff").strip() == "optimized"
    assert (output_dir / "msdv_capture.mp4").read_text(encoding="utf-8").lstrip("\ufeff").strip() == "optimized"
    assert (output_dir / "dvd_capture.mp4").read_text(encoding="utf-8").lstrip("\ufeff").strip() == "optimized"
    assert (output_dir / "tape_export.mp4").read_text(encoding="utf-8").lstrip("\ufeff").strip() == "optimized"
    assert Path(payload["log"]).exists()

    assert payload["standard"][payload["standard"].index("-crf") + 1] == "22"
    assert payload["standard"][payload["standard"].index("-b:a") + 1] == "160k"
    assert payload["smaller"][payload["smaller"].index("-crf") + 1] == "24"
    assert payload["smaller"][payload["smaller"].index("-b:a") + 1] == "128k"
    assert payload["better"][payload["better"].index("-crf") + 1] == "20"
    assert payload["better"][payload["better"].index("-b:a") + 1] == "192k"
    assert payload["withProgress"][payload["withProgress"].index("-progress") + 1].endswith("progress.txt")
    assert "-nostats" in payload["withProgress"]

    fake_invocation = fake_ffmpeg_log.read_text(encoding="utf-8")
    assert str(processed_source) in fake_invocation
    assert str(avi_source) in fake_invocation
    assert str(mpg_source) in fake_invocation
    assert str(mpeg_source) in fake_invocation
    assert str(skipped_source) not in fake_invocation


def test_core_supports_general_video_formats_and_profiles(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    for name in [
        "phone.mov",
        "archive.mkv",
        "tablet.m4v",
        "windows.wmv",
        "camera.ts",
        "bluray.m2ts",
        "dvd.vob",
        "notes.txt",
    ]:
        (input_dir / name).write_text("source", encoding="utf-8")

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$plan = Get-VhsMp4Plan -InputDir '{input_dir}' -OutputDir '{output_dir}'
$universal = Get-VhsMp4FfmpegArguments -SourcePath '{input_dir / "phone.mov"}' -OutputPath '{output_dir / "universal.mp4"}' -QualityMode 'Universal MP4 H.264'
$small = Get-VhsMp4FfmpegArguments -SourcePath '{input_dir / "archive.mkv"}' -OutputPath '{output_dir / "small.mp4"}' -QualityMode 'Small MP4 H.264'
$high = Get-VhsMp4FfmpegArguments -SourcePath '{input_dir / "tablet.m4v"}' -OutputPath '{output_dir / "high.mp4"}' -QualityMode 'High Quality MP4 H.264'
$hevc = Get-VhsMp4FfmpegArguments -SourcePath '{input_dir / "camera.ts"}' -OutputPath '{output_dir / "hevc.mp4"}' -QualityMode 'HEVC H.265 Smaller'
[pscustomobject]@{{
  plan = @($plan | Select-Object SourceName, Status, OutputPath)
  universal = $universal
  small = $small
  high = $high
  hevc = $hevc
}} | ConvertTo-Json -Depth 6
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)
    planned_names = {item["SourceName"] for item in payload["plan"]}

    assert planned_names == {
        "archive.mkv",
        "bluray.m2ts",
        "camera.ts",
        "dvd.vob",
        "phone.mov",
        "tablet.m4v",
        "windows.wmv",
    }

    assert payload["universal"][payload["universal"].index("-c:v") + 1] == "libx264"
    assert payload["universal"][payload["universal"].index("-crf") + 1] == "22"
    assert payload["universal"][payload["universal"].index("-b:a") + 1] == "160k"

    assert payload["small"][payload["small"].index("-c:v") + 1] == "libx264"
    assert payload["small"][payload["small"].index("-crf") + 1] == "24"
    assert payload["small"][payload["small"].index("-b:a") + 1] == "128k"

    assert payload["high"][payload["high"].index("-c:v") + 1] == "libx264"
    assert payload["high"][payload["high"].index("-crf") + 1] == "20"
    assert payload["high"][payload["high"].index("-b:a") + 1] == "192k"

    assert payload["hevc"][payload["hevc"].index("-c:v") + 1] == "libx265"
    assert payload["hevc"][payload["hevc"].index("-crf") + 1] == "26"
    assert payload["hevc"][payload["hevc"].index("-b:a") + 1] == "128k"
    assert payload["hevc"][payload["hevc"].index("-tag:v") + 1] == "hvc1"


def test_core_recursively_scans_input_subfolders_and_ignores_output_folder(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = input_dir / "vhs-mp4-output"
    nested_dir = input_dir / "Kaseta 01"
    nested_dir.mkdir(parents=True)
    output_dir.mkdir()

    direct_source = input_dir / "root_video.mp4"
    nested_mp4 = nested_dir / "porodica.mp4"
    nested_avi = nested_dir / "rodjendan.avi"
    previous_output = output_dir / "old_result.mp4"
    ignored_text = nested_dir / "notes.txt"

    for path in [direct_source, nested_mp4, nested_avi, previous_output, ignored_text]:
        path.write_text("source", encoding="utf-8")

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$plan = Get-VhsMp4Plan -InputDir '{input_dir}' -OutputDir '{output_dir}'
[pscustomobject]@{{
  plan = @($plan | Select-Object SourceName, SourcePath, OutputPath, DisplayOutputName, Status)
}} | ConvertTo-Json -Depth 6
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)
    plan = {item["SourceName"]: item for item in payload["plan"]}

    assert set(plan) == {"root_video.mp4", "Kaseta 01\\porodica.mp4", "Kaseta 01\\rodjendan.avi"}
    assert plan["root_video.mp4"]["OutputPath"].endswith("vhs-mp4-output\\root_video.mp4")
    assert plan["Kaseta 01\\porodica.mp4"]["OutputPath"].endswith("vhs-mp4-output\\Kaseta 01\\porodica.mp4")
    assert plan["Kaseta 01\\rodjendan.avi"]["OutputPath"].endswith("vhs-mp4-output\\Kaseta 01\\rodjendan.mp4")
    assert plan["Kaseta 01\\porodica.mp4"]["DisplayOutputName"] == "Kaseta 01\\porodica.mp4"
    assert all(item["Status"] == "queued" for item in payload["plan"])


def test_core_builds_plan_from_explicit_source_paths_and_expands_directories(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = input_dir / "vhs-mp4-output"
    nested_dir = input_dir / "Kaseta 01"
    nested_dir.mkdir(parents=True)
    output_dir.mkdir()

    direct_source = input_dir / "root_video.mp4"
    nested_source = nested_dir / "rodjendan.avi"
    ignored_text = nested_dir / "notes.txt"
    previous_output = output_dir / "old_result.mp4"

    for path in [direct_source, nested_source, ignored_text, previous_output]:
        path.write_text("source", encoding="utf-8")

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$plan = Get-VhsMp4PlanFromPaths -SourcePaths @('{direct_source}', '{nested_dir}') -InputDir '{input_dir}' -OutputDir '{output_dir}'
[pscustomobject]@{{
  plan = @($plan | Select-Object SourceName, SourcePath, OutputPath, DisplayOutputName, Status)
}} | ConvertTo-Json -Depth 6
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)
    plan = {item["SourceName"]: item for item in payload["plan"]}

    assert set(plan) == {"root_video.mp4", "Kaseta 01\\rodjendan.avi"}
    assert plan["root_video.mp4"]["OutputPath"].endswith("vhs-mp4-output\\root_video.mp4")
    assert plan["Kaseta 01\\rodjendan.avi"]["OutputPath"].endswith("vhs-mp4-output\\Kaseta 01\\rodjendan.mp4")
    assert plan["Kaseta 01\\rodjendan.avi"]["DisplayOutputName"] == "Kaseta 01\\rodjendan.mp4"
    assert all(item["Status"] == "queued" for item in payload["plan"])


def test_core_reads_video_media_info_from_ffprobe_json(tmp_path: Path) -> None:
    source = tmp_path / "family_archive.mkv"
    source.write_text("source", encoding="utf-8")

    tool_dir = tmp_path / "ffmpeg" / "bin"
    tool_dir.mkdir(parents=True)
    fake_ffmpeg = tool_dir / "ffmpeg.ps1"
    fake_ffprobe = tool_dir / "ffprobe.ps1"
    fake_ffmpeg.write_text("param()", encoding="utf-8")
    fake_ffprobe.write_text(
        r"""
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

if ($Args -contains "-show_entries") {
  "3661.5"
  exit 0
}

@'
{
  "streams": [
    {
      "index": 0,
      "codec_type": "video",
      "codec_name": "h264",
      "codec_long_name": "H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10",
      "width": 1440,
      "height": 1080,
      "sample_aspect_ratio": "1:1",
      "display_aspect_ratio": "4:3",
      "r_frame_rate": "30000/1001",
      "avg_frame_rate": "30000/1001",
      "time_base": "1/90000",
      "bit_rate": "7000000",
      "nb_frames": "109735"
    },
    {
      "index": 1,
      "codec_type": "audio",
      "codec_name": "aac",
      "channels": 2,
      "channel_layout": "stereo",
      "sample_rate": "48000",
      "bit_rate": "192000"
    }
  ],
  "format": {
    "filename": "family_archive.mkv",
    "nb_streams": 2,
    "format_name": "matroska,webm",
    "format_long_name": "Matroska / WebM",
    "duration": "3661.5",
    "size": "3435973836",
    "bit_rate": "7500000"
  }
}
'@
""".strip(),
        encoding="utf-8",
    )

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$info = Get-VhsMp4MediaInfo -SourcePath '{source}' -FfmpegPath '{fake_ffmpeg}'
$duration = Get-VhsMp4MediaDurationSeconds -SourcePath '{source}' -FfmpegPath '{fake_ffmpeg}'
[pscustomobject]@{{
  ffprobe = Resolve-VhsMp4FfprobePath -FfmpegPath '{fake_ffmpeg}'
  duration = $duration
  info = $info
}} | ConvertTo-Json -Depth 8
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)
    info = payload["info"]

    assert payload["ffprobe"] == str(fake_ffprobe)
    assert payload["duration"] == 3661.5
    assert info["SourceName"] == "family_archive.mkv"
    assert info["Container"] == "matroska,webm"
    assert info["ContainerLongName"] == "Matroska / WebM"
    assert info["DurationSeconds"] == 3661.5
    assert info["DurationText"] == "01:01:02"
    assert info["SizeBytes"] == 3435973836
    assert info["SizeText"] == "3.20 GB"
    assert info["OverallBitrateKbps"] == 7500
    assert info["VideoCodec"] == "h264"
    assert info["Resolution"] == "1440x1080"
    assert info["DisplayAspectRatio"] == "4:3"
    assert info["FrameRate"] == 29.97
    assert info["FrameRateText"] == "29.97 fps"
    assert info["FrameCount"] == 109735
    assert info["VideoBitrateKbps"] == 7000
    assert info["AudioCodec"] == "aac"
    assert info["AudioChannels"] == 2
    assert info["AudioSampleRateHz"] == 48000
    assert info["AudioBitrateKbps"] == 192
    assert "h264" in info["VideoSummary"]
    assert "aac" in info["AudioSummary"]


def test_core_media_info_keeps_aspect_scan_fields_from_ffprobe(tmp_path: Path) -> None:
    source = tmp_path / "family_archive.mkv"
    source.write_text("source", encoding="utf-8")

    tool_dir = tmp_path / "ffmpeg" / "bin"
    tool_dir.mkdir(parents=True)
    fake_ffmpeg = tool_dir / "ffmpeg.ps1"
    fake_ffprobe = tool_dir / "ffprobe.ps1"
    fake_ffmpeg.write_text("param()", encoding="utf-8")
    fake_ffprobe.write_text(
        r"""
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

if ($Args -contains "-show_entries") {
  "61.0"
  exit 0
}

@'
{
  "streams": [
    {
      "index": 0,
      "codec_type": "video",
      "codec_name": "dvvideo",
      "codec_long_name": "DV (Digital Video)",
      "width": 720,
      "height": 576,
      "sample_aspect_ratio": "64:45",
      "display_aspect_ratio": "16:9",
      "r_frame_rate": "25/1",
      "avg_frame_rate": "25/1",
      "bit_rate": "25000000",
      "nb_frames": "1525"
    }
  ],
  "format": {
    "filename": "family_archive.mkv",
    "nb_streams": 1,
    "format_name": "matroska",
    "format_long_name": "Matroska",
    "duration": "61.0",
    "size": "1048576",
    "bit_rate": "25000000"
  }
}
'@
""".strip(),
        encoding="utf-8",
    )

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$info = Get-VhsMp4MediaInfo -SourcePath '{source}' -FfmpegPath '{fake_ffmpeg}'
[pscustomobject]@{{
  DisplayAspectRatio = $info.DisplayAspectRatio
  SampleAspectRatio = $info.SampleAspectRatio
  DetectedAspectMode = $info.DetectedAspectMode
  AspectSummary = $info.AspectSummary
  OutputAspectWidth = $info.OutputAspectWidth
  OutputAspectHeight = $info.OutputAspectHeight
}} | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["DisplayAspectRatio"] == "16:9"
    assert payload["SampleAspectRatio"] == "64:45"
    assert payload["DetectedAspectMode"] == "Force16x9"
    assert "DAR=16:9" in payload["AspectSummary"]
    assert payload["OutputAspectWidth"] == 1024
    assert payload["OutputAspectHeight"] == 576


def test_core_normalizes_aspect_modes_for_detection_helpers() -> None:
    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
[pscustomobject]@{{
  Auto = Get-VhsMp4NormalizedAspectMode -AspectMode 'Auto'
  KeepOriginal = Get-VhsMp4NormalizedAspectMode -AspectMode 'Keep Original'
  KeepOriginalCanonical = Get-VhsMp4NormalizedAspectMode -AspectMode 'KeepOriginal'
  Force4x3Canonical = Get-VhsMp4NormalizedAspectMode -AspectMode 'Force4x3'
  Force4x3 = Get-VhsMp4NormalizedAspectMode -AspectMode 'Force 4:3'
  Force16x9Canonical = Get-VhsMp4NormalizedAspectMode -AspectMode 'Force16x9'
  Force16x9 = Get-VhsMp4NormalizedAspectMode -AspectMode 'Force 16:9'
}} | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["Auto"] == "Auto"
    assert payload["KeepOriginal"] == "KeepOriginal"
    assert payload["KeepOriginalCanonical"] == "KeepOriginal"
    assert payload["Force4x3Canonical"] == "Force4x3"
    assert payload["Force4x3"] == "Force4x3"
    assert payload["Force16x9Canonical"] == "Force16x9"
    assert payload["Force16x9"] == "Force16x9"


def test_core_detects_aspect_from_dar_and_sar_metadata() -> None:
    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$wide = Get-VhsMp4DetectedAspect -InputObject ([pscustomobject]@{{
  width = 720
  height = 576
  display_aspect_ratio = '16:9'
  sample_aspect_ratio = '64:45'
}})
$tall = Get-VhsMp4DetectedAspect -InputObject ([pscustomobject]@{{
  width = 720
  height = 576
  display_aspect_ratio = '4:3'
  sample_aspect_ratio = '16:15'
}})
[pscustomobject]@{{
  WideMode = $wide.DetectedAspectMode
  WideConfidence = $wide.DetectedAspectConfidence
  WideDar = $wide.DisplayAspectRatio
  WideSar = $wide.SampleAspectRatio
  TallMode = $tall.DetectedAspectMode
  TallConfidence = $tall.DetectedAspectConfidence
  TallDar = $tall.DisplayAspectRatio
  TallSar = $tall.SampleAspectRatio
}} | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["WideMode"] == "Force16x9"
    assert payload["WideConfidence"] == "High"
    assert payload["WideDar"] == "16:9"
    assert payload["WideSar"] == "64:45"
    assert payload["TallMode"] == "Force4x3"
    assert payload["TallConfidence"] == "High"
    assert payload["TallDar"] == "4:3"
    assert payload["TallSar"] == "16:15"


def test_core_detects_aspect_from_fractional_and_decimal_dar_metadata() -> None:
    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$fraction = Get-VhsMp4DetectedAspect -InputObject ([pscustomobject]@{{
  display_aspect_ratio = '16/9'
}})
$decimalWide = Get-VhsMp4DetectedAspect -InputObject ([pscustomobject]@{{
  display_aspect_ratio = '1.78'
}})
$decimalTall = Get-VhsMp4DetectedAspect -InputObject ([pscustomobject]@{{
  display_aspect_ratio = '1.33'
}})
[pscustomobject]@{{
  FractionMode = $fraction.DetectedAspectMode
  FractionConfidence = $fraction.DetectedAspectConfidence
  FractionDar = $fraction.DisplayAspectRatio
  DecimalWideMode = $decimalWide.DetectedAspectMode
  DecimalWideConfidence = $decimalWide.DetectedAspectConfidence
  DecimalWideDar = $decimalWide.DisplayAspectRatio
  DecimalTallMode = $decimalTall.DetectedAspectMode
  DecimalTallConfidence = $decimalTall.DetectedAspectConfidence
  DecimalTallDar = $decimalTall.DisplayAspectRatio
}} | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["FractionMode"] == "Force16x9"
    assert payload["FractionConfidence"] == "High"
    assert payload["FractionDar"] == "16/9"
    assert payload["DecimalWideMode"] == "Force16x9"
    assert payload["DecimalWideConfidence"] == "High"
    assert payload["DecimalWideDar"] == "1.78"
    assert payload["DecimalTallMode"] == "Force4x3"
    assert payload["DecimalTallConfidence"] == "High"
    assert payload["DecimalTallDar"] == "1.33"


def test_core_maps_aspect_confidence_levels() -> None:
    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
[pscustomobject]@{{
  High = Get-VhsMp4AspectConfidence -Confidence 'High'
  Medium = Get-VhsMp4AspectConfidence -Confidence 'Medium'
  Low = Get-VhsMp4AspectConfidence -Confidence 'Low'
  Unknown = Get-VhsMp4AspectConfidence -Confidence 'Unknown'
}} | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["High"] == "High"
    assert payload["Medium"] == "Medium"
    assert payload["Low"] == "Low"
    assert payload["Unknown"] == "Unknown"


def test_core_treats_unknown_and_blank_as_unknown_aspect_confidence() -> None:
    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
[pscustomobject]@{{
  Blank = Get-VhsMp4AspectConfidence -Confidence ''
  Null = Get-VhsMp4AspectConfidence -Confidence $null
}} | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["Blank"] == "Unknown"
    assert payload["Null"] == "Unknown"


def test_core_builds_hardware_encode_arguments_and_falls_back_to_cpu_when_needed() -> None:
    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$inventory = Get-VhsMp4EncoderInventoryFromText -EncodersText @'
 V....D libx264              libx264 H.264 / AVC
 V....D libx265              libx265 H.265 / HEVC
 V....D h264_nvenc           NVIDIA NVENC H.264 encoder
 V....D hevc_nvenc           NVIDIA NVENC HEVC encoder
 V..... h264_qsv             Intel Quick Sync H.264 encoder
 V..... hevc_qsv             Intel Quick Sync HEVC encoder
'@
$nvenc = Get-VhsMp4FfmpegArguments -SourcePath 'input.avi' -OutputPath 'out.mp4' -QualityMode 'Universal MP4 H.264' -EncoderMode 'NVIDIA NVENC' -EncoderInventory $inventory
$qsv = Get-VhsMp4FfmpegArguments -SourcePath 'input.avi' -OutputPath 'out.mp4' -QualityMode 'Universal MP4 H.264' -EncoderMode 'Intel QSV' -EncoderInventory $inventory
$hevcNvenc = Get-VhsMp4FfmpegArguments -SourcePath 'input.avi' -OutputPath 'out.mp4' -QualityMode 'HEVC H.265 Smaller' -EncoderMode 'NVIDIA NVENC' -EncoderInventory $inventory
$fallback = Get-VhsMp4FfmpegArguments -SourcePath 'input.avi' -OutputPath 'out.mp4' -QualityMode 'Universal MP4 H.264' -EncoderMode 'AMD AMF' -EncoderInventory $inventory
[pscustomobject]@{{
  NvencCodec = $nvenc[$nvenc.IndexOf('-c:v') + 1]
  NvencPreset = $nvenc[$nvenc.IndexOf('-preset') + 1]
  NvencRc = $nvenc[$nvenc.IndexOf('-rc') + 1]
  NvencCq = $nvenc[$nvenc.IndexOf('-cq') + 1]
  QsvCodec = $qsv[$qsv.IndexOf('-c:v') + 1]
  QsvPreset = $qsv[$qsv.IndexOf('-preset') + 1]
  QsvGlobalQuality = $qsv[$qsv.IndexOf('-global_quality') + 1]
  HevcNvencCodec = $hevcNvenc[$hevcNvenc.IndexOf('-c:v') + 1]
  HevcNvencTag = $hevcNvenc[$hevcNvenc.IndexOf('-tag:v') + 1]
  FallbackCodec = $fallback[$fallback.IndexOf('-c:v') + 1]
  FallbackCrf = $fallback[$fallback.IndexOf('-crf') + 1]
  FallbackHasCq = ($fallback -contains '-cq')
}} | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["NvencCodec"] == "h264_nvenc"
    assert payload["NvencPreset"] == "p5"
    assert payload["NvencRc"] == "vbr"
    assert payload["NvencCq"] == "22"
    assert payload["QsvCodec"] == "h264_qsv"
    assert payload["QsvPreset"] == "slow"
    assert payload["QsvGlobalQuality"] == "22"
    assert payload["HevcNvencCodec"] == "hevc_nvenc"
    assert payload["HevcNvencTag"] == "hvc1"
    assert payload["FallbackCodec"] == "libx264"
    assert payload["FallbackCrf"] == "22"
    assert payload["FallbackHasCq"] is False


def test_core_detects_runtime_ready_hardware_encoders_from_ffmpeg_outputs(tmp_path: Path) -> None:
    fake_ffmpeg = tmp_path / "fake-ffmpeg.ps1"
    fake_ffmpeg.write_text(
        r"""
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

if ($Args -contains '-encoders') {
@'
 V....D libx264              libx264 H.264 / AVC
 V....D libx265              libx265 H.265 / HEVC
 V....D h264_nvenc           NVIDIA NVENC H.264 encoder
 V....D hevc_nvenc           NVIDIA NVENC HEVC encoder
 V..... h264_qsv             Intel Quick Sync H.264 encoder
 V..... hevc_qsv             Intel Quick Sync HEVC encoder
 V....D h264_amf             AMD AMF H.264 encoder
 V....D hevc_amf             AMD AMF HEVC encoder
'@
  exit 0
}

$argumentLine = $Args -join ' '
if ($argumentLine -match 'h264_nvenc') {
  exit 0
}
if ($argumentLine -match 'h264_qsv') {
  exit 0
}
if ($argumentLine -match 'h264_amf') {
  Write-Error 'DLL amfrt64.dll failed to open'
  exit 1
}
exit 0
""".strip(),
        encoding="utf-8",
    )

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$inventory = Get-VhsMp4EncoderInventory -FfmpegPath '{fake_ffmpeg}'
[pscustomobject]@{{
  AvailableModes = @($inventory.AvailableModes)
  RuntimeReadyModes = @($inventory.RuntimeReadyModes)
  HasAmfAdvertised = [bool]$inventory.AdvertisedModeMap['AMD AMF']
  HasAmfRuntimeReady = [bool]$inventory.RuntimeReadyModeMap['AMD AMF']
  Summary = [string]$inventory.Summary
}} | ConvertTo-Json -Depth 6
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["AvailableModes"] == ["CPU", "NVIDIA NVENC", "Intel QSV", "AMD AMF"]
    assert payload["RuntimeReadyModes"] == ["CPU", "NVIDIA NVENC", "Intel QSV"]
    assert payload["HasAmfAdvertised"] is True
    assert payload["HasAmfRuntimeReady"] is False
    assert "AMD AMF: init failed" in payload["Summary"]


def test_core_falls_back_to_keep_original_for_conflicting_aspect_dar_and_sar() -> None:
    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$state = Get-VhsMp4AspectState -InputObject ([pscustomobject]@{{
  width = 720
  height = 576
  display_aspect_ratio = '4:3'
  sample_aspect_ratio = '64:45'
}})
[pscustomobject]@{{
  AspectMode = $state.AspectMode
  DetectedAspectMode = $state.DetectedAspectMode
  DetectedAspectConfidence = $state.DetectedAspectConfidence
  DisplayAspectRatio = $state.DetectedDisplayAspectRatio
  SampleAspectRatio = $state.DetectedSampleAspectRatio
  AspectSummary = $state.AspectSummary
}} | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["AspectMode"] == "Auto"
    assert payload["DetectedAspectMode"] == "KeepOriginal"
    assert payload["DetectedAspectConfidence"] == "Low"
    assert payload["DisplayAspectRatio"] == "4:3"
    assert payload["SampleAspectRatio"] == "64:45"
    assert payload["AspectSummary"]


def test_core_maps_anamorphic_and_square_pixel_aspect_output_geometry() -> None:
    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$pal4x3 = Get-VhsMp4AspectTargetGeometry -InputObject ([pscustomobject]@{{
  Width = 720
  Height = 576
  DisplayAspectRatio = '4:3'
  SampleAspectRatio = '16:15'
}}) -AspectMode 'Keep Original' -ScaleMode 'Original'
$pal16x9 = Get-VhsMp4AspectTargetGeometry -InputObject ([pscustomobject]@{{
  Width = 720
  Height = 576
  DisplayAspectRatio = '16:9'
  SampleAspectRatio = '64:45'
}}) -AspectMode 'Keep Original' -ScaleMode 'Original'
$ntsc4x3 = Get-VhsMp4AspectTargetGeometry -InputObject ([pscustomobject]@{{
  Width = 720
  Height = 480
  DisplayAspectRatio = '4:3'
  SampleAspectRatio = '8:9'
}}) -AspectMode 'Keep Original' -ScaleMode 'Original'
$ntsc16x9 = Get-VhsMp4AspectTargetGeometry -InputObject ([pscustomobject]@{{
  Width = 720
  Height = 480
  DisplayAspectRatio = '16:9'
  SampleAspectRatio = '32:27'
}}) -AspectMode 'Keep Original' -ScaleMode 'Original'
$pal704_4x3 = Get-VhsMp4AspectTargetGeometry -InputObject ([pscustomobject]@{{
  Width = 704
  Height = 576
  DisplayAspectRatio = '4:3'
  SampleAspectRatio = '12:11'
}}) -AspectMode 'Keep Original' -ScaleMode 'Original'
$pal704_16x9 = Get-VhsMp4AspectTargetGeometry -InputObject ([pscustomobject]@{{
  Width = 704
  Height = 576
  DisplayAspectRatio = '16:9'
  SampleAspectRatio = '16:11'
}}) -AspectMode 'Keep Original' -ScaleMode 'Original'
$ntsc704_4x3 = Get-VhsMp4AspectTargetGeometry -InputObject ([pscustomobject]@{{
  Width = 704
  Height = 480
  DisplayAspectRatio = '4:3'
  SampleAspectRatio = '10:11'
}}) -AspectMode 'Keep Original' -ScaleMode 'Original'
$ntsc704_16x9 = Get-VhsMp4AspectTargetGeometry -InputObject ([pscustomobject]@{{
  Width = 704
  Height = 480
  DisplayAspectRatio = '16:9'
  SampleAspectRatio = '40:33'
}}) -AspectMode 'Keep Original' -ScaleMode 'Original'
$conflictAuto = Get-VhsMp4AspectTargetGeometry -InputObject ([pscustomobject]@{{
  Width = 720
  Height = 576
  DisplayAspectRatio = '4:3'
  SampleAspectRatio = '64:45'
}}) -AspectMode 'Auto' -ScaleMode 'Original'
$squareOriginal = Get-VhsMp4AspectTargetGeometry -InputObject ([pscustomobject]@{{
  Width = 768
  Height = 576
  DisplayAspectRatio = '4:3'
  SampleAspectRatio = '1:1'
}}) -AspectMode 'Keep Original' -ScaleMode 'Original'
[pscustomobject]@{{
  Pal4x3 = $pal4x3
  Pal16x9 = $pal16x9
  Ntsc4x3 = $ntsc4x3
  Ntsc16x9 = $ntsc16x9
  Pal704_4x3 = $pal704_4x3
  Pal704_16x9 = $pal704_16x9
  Ntsc704_4x3 = $ntsc704_4x3
  Ntsc704_16x9 = $ntsc704_16x9
  ConflictAuto = $conflictAuto
  SquareOriginal = $squareOriginal
}} | ConvertTo-Json -Depth 8
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["Pal4x3"]["OutputWidth"] == 768
    assert payload["Pal4x3"]["OutputHeight"] == 576
    assert payload["Pal16x9"]["OutputWidth"] == 1024
    assert payload["Pal16x9"]["OutputHeight"] == 576
    assert payload["Ntsc4x3"]["OutputWidth"] == 640
    assert payload["Ntsc4x3"]["OutputHeight"] == 480
    assert payload["Ntsc16x9"]["OutputWidth"] == 854
    assert payload["Ntsc16x9"]["OutputHeight"] == 480
    assert payload["Pal704_4x3"]["OutputWidth"] == 768
    assert payload["Pal704_4x3"]["OutputHeight"] == 576
    assert payload["Pal704_16x9"]["OutputWidth"] == 1024
    assert payload["Pal704_16x9"]["OutputHeight"] == 576
    assert payload["Ntsc704_4x3"]["OutputWidth"] == 640
    assert payload["Ntsc704_4x3"]["OutputHeight"] == 480
    assert payload["Ntsc704_16x9"]["OutputWidth"] == 854
    assert payload["Ntsc704_16x9"]["OutputHeight"] == 480
    assert payload["ConflictAuto"]["OutputAspectMode"] == "KeepOriginal"
    assert payload["ConflictAuto"]["OutputWidth"] == 720
    assert payload["ConflictAuto"]["OutputHeight"] == 576
    assert payload["ConflictAuto"]["RequiresAspectCorrection"] is False
    assert payload["SquareOriginal"]["OutputWidth"] == 768
    assert payload["SquareOriginal"]["OutputHeight"] == 576
    assert payload["SquareOriginal"]["RequiresAspectCorrection"] is False


def test_core_uses_crop_and_rotate_before_aspect_output_geometry() -> None:
    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$cropped = Get-VhsMp4AspectTargetGeometry -InputObject ([pscustomobject]@{{
  Width = 720
  Height = 576
  DisplayAspectRatio = '16:9'
  SampleAspectRatio = '64:45'
}}) -AspectMode 'Force 16:9' -ScaleMode 'Original' -CropState ([pscustomobject]@{{
  Mode = 'Manual'
  Left = 8
  Top = 0
  Right = 8
  Bottom = 0
  SourceWidth = 720
  SourceHeight = 576
}})
$rotated = Get-VhsMp4AspectTargetGeometry -InputObject ([pscustomobject]@{{
  Width = 720
  Height = 576
  DisplayAspectRatio = '16:9'
  SampleAspectRatio = '64:45'
}}) -AspectMode 'Force 16:9' -ScaleMode 'Original' -RotateFlip '90 CW'
$rotatedCcw = Get-VhsMp4AspectTargetGeometry -InputObject ([pscustomobject]@{{
  Width = 720
  Height = 576
  DisplayAspectRatio = '16:9'
  SampleAspectRatio = '64:45'
}}) -AspectMode 'Force 16:9' -ScaleMode 'Original' -RotateFlip '90 CCW'
[pscustomobject]@{{
  Cropped = $cropped
  Rotated = $rotated
  RotatedCcw = $rotatedCcw
}} | ConvertTo-Json -Depth 8
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["Cropped"]["WorkingWidth"] == 704
    assert payload["Cropped"]["WorkingHeight"] == 576
    assert payload["Cropped"]["OutputWidth"] == 1024
    assert payload["Cropped"]["OutputHeight"] == 576
    assert payload["Rotated"]["WorkingWidth"] == 576
    assert payload["Rotated"]["WorkingHeight"] == 720
    assert payload["Rotated"]["OutputWidth"] == 576
    assert payload["Rotated"]["OutputHeight"] == 1024
    assert payload["RotatedCcw"]["WorkingWidth"] == 576
    assert payload["RotatedCcw"]["WorkingHeight"] == 720
    assert payload["RotatedCcw"]["OutputWidth"] == 576
    assert payload["RotatedCcw"]["OutputHeight"] == 1024


def test_core_applies_scale_after_aspect_geometry_without_double_correction() -> None:
    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$scaleOriginal = Get-VhsMp4AspectAwareScaleFilter -InputObject ([pscustomobject]@{{
  Width = 768
  Height = 576
  DisplayAspectRatio = '4:3'
  SampleAspectRatio = '1:1'
}}) -AspectMode 'Keep Original' -ScaleMode 'Original'
$scale720p = Get-VhsMp4AspectAwareScaleFilter -InputObject ([pscustomobject]@{{
  Width = 720
  Height = 576
  DisplayAspectRatio = '16:9'
  SampleAspectRatio = '64:45'
}}) -AspectMode 'Force 16:9' -ScaleMode '720p'
$scaleRotated720p = Get-VhsMp4AspectAwareScaleFilter -InputObject ([pscustomobject]@{{
  Width = 720
  Height = 576
  DisplayAspectRatio = '16:9'
  SampleAspectRatio = '64:45'
}}) -AspectMode 'Force 16:9' -ScaleMode '720p' -RotateFlip '90 CW'
[pscustomobject]@{{
  ScaleOriginal = $scaleOriginal
  Scale720p = $scale720p
  ScaleRotated720p = $scaleRotated720p
}} | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["ScaleOriginal"] == ""
    assert payload["Scale720p"] == "scale=1280:720:flags=lanczos"
    assert payload["ScaleRotated720p"] == "scale=406:720:flags=lanczos"


def test_core_builds_aspect_aware_video_chain_summary_and_ffmpeg_args(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    source = input_dir / "family_tape.avi"
    source.write_text("source", encoding="utf-8")

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$cropState = [pscustomobject]@{{
  Mode = 'Manual'
  Left = 8
  Top = 0
  Right = 8
  Bottom = 0
  SourceWidth = 720
  SourceHeight = 576
}}
$videoInfo = [pscustomobject]@{{
  Width = 720
  Height = 576
  DisplayAspectRatio = '16:9'
  SampleAspectRatio = '64:45'
}}
$videoChain = Get-VhsMp4VideoFilterChain -InputObject $videoInfo -CropState $cropState -AspectMode 'Force 16:9' -RotateFlip '90 CW' -ScaleMode '720p'
$summary = Get-VhsMp4FilterSummary -InputObject $videoInfo -CropState $cropState -AspectMode 'Force 16:9' -RotateFlip '90 CW' -ScaleMode '720p'
$args = Get-VhsMp4FfmpegArguments -SourcePath '{source}' -OutputPath '{output_dir / "filtered.mp4"}' -QualityMode 'Standard VHS' -CropState $cropState -AspectMode 'Force 16:9' -VideoInfo $videoInfo -RotateFlip '90 CW' -ScaleMode '720p'
[pscustomobject]@{{
  VideoChain = $videoChain
  Summary = $summary
  Args = $args
}} | ConvertTo-Json -Depth 8
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)
    args = payload["Args"]

    assert payload["VideoChain"] == "crop=704:576:8:0,transpose=1,scale=406:720:flags=lanczos"
    assert payload["Summary"] == "Aspect: Force 16:9 -> 406x720 | Crop: 8,0,8,0 | Rotate/flip: 90 CW | Scale: 720p"
    assert args[args.index("-vf") + 1] == payload["VideoChain"]


def test_core_scan_plan_populates_queue_item_aspect_summary_and_output_geometry(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    source = input_dir / "family_tape.avi"
    source.write_text("source", encoding="utf-8")

    tool_dir = tmp_path / "ffmpeg" / "bin"
    tool_dir.mkdir(parents=True)
    fake_ffmpeg = tool_dir / "ffmpeg.ps1"
    fake_ffprobe = tool_dir / "ffprobe.ps1"
    fake_ffmpeg.write_text("param()", encoding="utf-8")
    fake_ffprobe.write_text(
        r"""
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

if ($Args -contains "-show_entries") {
  "61.0"
  exit 0
}

@'
{
  "streams": [
    {
      "index": 0,
      "codec_type": "video",
      "codec_name": "mpeg2video",
      "codec_long_name": "MPEG-2 video",
      "width": 720,
      "height": 576,
      "sample_aspect_ratio": "64:45",
      "display_aspect_ratio": "16:9",
      "r_frame_rate": "25/1",
      "avg_frame_rate": "25/1",
      "bit_rate": "8000000",
      "nb_frames": "1525"
    },
    {
      "index": 1,
      "codec_type": "audio",
      "codec_name": "mp2",
      "channels": 2,
      "sample_rate": "48000",
      "bit_rate": "192000"
    }
  ],
  "format": {
    "filename": "family_tape.avi",
    "nb_streams": 2,
    "format_name": "avi",
    "format_long_name": "AVI",
    "duration": "61.0",
    "size": "1048576",
    "bit_rate": "8192000"
  }
}
'@
""".strip(),
        encoding="utf-8",
    )

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$plan = Get-VhsMp4Plan -InputDir '{input_dir}' -OutputDir '{output_dir}' -FfmpegPath '{fake_ffmpeg}'
$item = $plan[0]
[pscustomobject]@{{
  SourceName = $item.SourceName
  HasMediaInfo = $null -ne $item.MediaInfo
  DisplayAspectRatio = $item.MediaInfo.DisplayAspectRatio
  SampleAspectRatio = $item.MediaInfo.SampleAspectRatio
  AspectSummary = $item.AspectSummary
  DetectedAspectMode = $item.DetectedAspectMode
  OutputAspectWidth = $item.OutputAspectWidth
  OutputAspectHeight = $item.OutputAspectHeight
}} | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["SourceName"] == "family_tape.avi"
    assert payload["HasMediaInfo"] is True
    assert payload["DisplayAspectRatio"] == "16:9"
    assert payload["SampleAspectRatio"] == "64:45"
    assert payload["DetectedAspectMode"] == "Force16x9"
    assert "Result=Force16x9" in payload["AspectSummary"]
    assert payload["OutputAspectWidth"] == 1024
    assert payload["OutputAspectHeight"] == 576


def test_core_batch_fallback_scan_forwards_ffmpeg_path_into_plan_aspect_state(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    source = input_dir / "family_tape.avi"
    source.write_text("source", encoding="utf-8")

    tool_dir = tmp_path / "ffmpeg" / "bin"
    tool_dir.mkdir(parents=True)
    fake_ffmpeg = tool_dir / "ffmpeg.ps1"
    fake_ffprobe = tool_dir / "ffprobe.ps1"
    fake_ffmpeg.write_text(
        """
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

if ($Args[0] -eq "-version") {
  Write-Output "ffmpeg version fake"
  exit 0
}

$outputPath = $Args[-1]
if ($outputPath -ne "-version") {
  Set-Content -LiteralPath $outputPath -Value "optimized" -Encoding UTF8
}
""".strip(),
        encoding="utf-8",
    )
    fake_ffprobe.write_text(
        r"""
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

if ($Args -contains "-show_entries") {
  "61.0"
  exit 0
}

@'
{
  "streams": [
    {
      "index": 0,
      "codec_type": "video",
      "codec_name": "mpeg2video",
      "codec_long_name": "MPEG-2 video",
      "width": 720,
      "height": 576,
      "sample_aspect_ratio": "64:45",
      "display_aspect_ratio": "16:9",
      "r_frame_rate": "25/1",
      "avg_frame_rate": "25/1",
      "bit_rate": "8000000",
      "nb_frames": "1525"
    }
  ],
  "format": {
    "filename": "family_tape.avi",
    "nb_streams": 1,
    "format_name": "avi",
    "format_long_name": "AVI",
    "duration": "61.0",
    "size": "1048576",
    "bit_rate": "8192000"
  }
}
'@
""".strip(),
        encoding="utf-8",
    )

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$summary = Invoke-VhsMp4Batch -InputDir '{input_dir}' -OutputDir '{output_dir}' -QualityMode 'Standard VHS' -FfmpegPath '{fake_ffmpeg}'
$item = $summary.Items[0]
[pscustomobject]@{{
  HasMediaInfo = $null -ne $item.MediaInfo
  DisplayAspectRatio = $item.MediaInfo.DisplayAspectRatio
  SampleAspectRatio = $item.MediaInfo.SampleAspectRatio
  DetectedAspectMode = $item.DetectedAspectMode
  AspectSummary = $item.AspectSummary
  OutputAspectWidth = $item.OutputAspectWidth
  OutputAspectHeight = $item.OutputAspectHeight
}} | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["HasMediaInfo"] is True
    assert payload["DisplayAspectRatio"] == "16:9"
    assert payload["SampleAspectRatio"] == "64:45"
    assert payload["DetectedAspectMode"] == "Force16x9"
    assert "Result=Force16x9" in payload["AspectSummary"]
    assert payload["OutputAspectWidth"] == 1024
    assert payload["OutputAspectHeight"] == 576


def test_core_can_resolve_ffprobe_next_to_ffmpeg(tmp_path: Path) -> None:
    tool_dir = tmp_path / "ffmpeg" / "bin"
    tool_dir.mkdir(parents=True)
    ffmpeg = tool_dir / "ffmpeg.exe"
    ffprobe = tool_dir / "ffprobe.exe"
    ffmpeg.write_text("fake-ffmpeg", encoding="utf-8")
    ffprobe.write_text("fake-ffprobe", encoding="utf-8")

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
Resolve-VhsMp4FfprobePath -FfmpegPath '{ffmpeg}'
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    assert run.stdout.strip() == str(ffprobe)


def test_core_builds_ffmpeg_trim_args_without_breaking_split_output(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    source = input_dir / "family_tape.avi"
    source.write_text("source", encoding="utf-8")

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$startOnly = Get-VhsMp4FfmpegArguments -SourcePath '{source}' -OutputPath '{output_dir / "start.mp4"}' -QualityMode 'Standard VHS' -TrimStart '00:01:00'
$endOnly = Get-VhsMp4FfmpegArguments -SourcePath '{source}' -OutputPath '{output_dir / "end.mp4"}' -QualityMode 'Standard VHS' -TrimEnd '00:02:30'
$range = Get-VhsMp4FfmpegArguments -SourcePath '{source}' -OutputPath '{output_dir / "range.mp4"}' -QualityMode 'Standard VHS' -TrimStart '00:01:00' -TrimEnd '00:02:30'
$split = Get-VhsMp4FfmpegArguments -SourcePath '{source}' -OutputPath '{output_dir / "range-part%03d.mp4"}' -QualityMode 'Standard VHS' -TrimStart '00:01:00' -TrimEnd '00:02:30' -SplitOutput -MaxPartGb 3.8
[pscustomobject]@{{
  StartOnly = $startOnly
  EndOnly = $endOnly
  Range = $range
  Split = $split
}} | ConvertTo-Json -Depth 6
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    start_only = payload["StartOnly"]
    end_only = payload["EndOnly"]
    range_args = payload["Range"]
    split_args = payload["Split"]

    assert start_only[start_only.index("-ss") + 1] == "00:01:00"
    assert start_only.index("-ss") < start_only.index("-i")
    assert "-to" not in start_only

    assert end_only[end_only.index("-to") + 1] == "00:02:30"
    assert end_only.index("-to") < end_only.index("-i")
    assert "-ss" not in end_only

    assert range_args[range_args.index("-ss") + 1] == "00:01:00"
    assert range_args[range_args.index("-t") + 1] == "00:01:30"
    assert range_args.index("-ss") < range_args.index("-i")
    assert range_args.index("-t") < range_args.index("-i")

    assert split_args[split_args.index("-ss") + 1] == "00:01:00"
    assert split_args[split_args.index("-t") + 1] == "00:01:30"
    assert "-f" in split_args
    assert split_args[split_args.index("-f") + 1] == "segment"
    assert split_args[split_args.index("-segment_format") + 1] == "mp4"
    assert split_args[-1].endswith("range-part%03d.mp4")


def test_core_builds_filter_complex_concat_for_multi_trim_segments(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    source = input_dir / "family_tape.avi"
    source.write_text("source", encoding="utf-8")

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$segments = @(
  [pscustomobject]@{{ StartText = '00:00:10'; EndText = '00:00:20' }},
  [pscustomobject]@{{ StartText = '00:01:00'; EndText = '00:01:30' }}
)
$withAudio = Get-VhsMp4FfmpegArguments -SourcePath '{source}' -OutputPath '{output_dir / "kept.mp4"}' -QualityMode 'Universal MP4 H.264' -TrimSegments $segments -SourceHasAudio $true -Deinterlace 'YADIF' -ScaleMode 'PAL 576p' -AudioNormalize
$withoutAudio = Get-VhsMp4FfmpegArguments -SourcePath '{source}' -OutputPath '{output_dir / "video-only.mp4"}' -QualityMode 'Universal MP4 H.264' -TrimSegments $segments -SourceHasAudio $false
[pscustomobject]@{{
  WithAudio = $withAudio
  WithoutAudio = $withoutAudio
}} | ConvertTo-Json -Depth 6
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)
    with_audio = payload["WithAudio"]
    without_audio = payload["WithoutAudio"]

    assert "-filter_complex" in with_audio
    assert "-ss" not in with_audio
    filter_complex = with_audio[with_audio.index("-filter_complex") + 1]
    assert "trim=start=10:end=20" in filter_complex
    assert "trim=start=60:end=90" in filter_complex
    assert "concat=n=2:v=1:a=1[vout][aout]" in filter_complex
    assert "yadif=0:-1:0" in filter_complex
    assert "scale=-2:576:flags=lanczos" in filter_complex
    assert "loudnorm=I=-16:TP=-1.5:LRA=11" in filter_complex
    assert with_audio[with_audio.index("-map") + 1] == "[vout]"
    assert "[aout]" in with_audio
    assert "-vf" not in with_audio
    assert "-af" not in with_audio

    assert "-filter_complex" in without_audio
    no_audio_filter = without_audio[without_audio.index("-filter_complex") + 1]
    assert "concat=n=2:v=1:a=0[vout]" in no_audio_filter
    assert "[aout]" not in without_audio


def test_core_builds_video_and_audio_filter_args_with_trim_and_split(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    source = input_dir / "family_tape.avi"
    source.write_text("source", encoding="utf-8")

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$args = Get-VhsMp4FfmpegArguments -SourcePath '{source}' -OutputPath '{output_dir / "filtered-part%03d.mp4"}' -QualityMode 'Universal MP4 H.264' -TrimStart '00:01:00' -TrimEnd '00:02:00' -SplitOutput -MaxPartGb 3.8 -Deinterlace 'YADIF' -Denoise 'Light' -RotateFlip '90 CW' -ScaleMode '720p' -AudioNormalize
$videoChain = Get-VhsMp4VideoFilterChain -Deinterlace 'YADIF' -Denoise 'Light' -RotateFlip '90 CW' -ScaleMode '720p'
$audioChain = Get-VhsMp4AudioFilterChain -AudioNormalize
$summary = Get-VhsMp4FilterSummary -Deinterlace 'YADIF' -Denoise 'Light' -RotateFlip '90 CW' -ScaleMode '720p' -AudioNormalize
[pscustomobject]@{{
  Args = $args
  VideoChain = $videoChain
  AudioChain = $audioChain
  Summary = $summary
}} | ConvertTo-Json -Depth 6
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)
    args = payload["Args"]

    assert payload["VideoChain"] == "yadif=0:-1:0,hqdn3d=1.5:1.5:6:6,transpose=1,scale=-2:720:flags=lanczos"
    assert payload["AudioChain"] == "loudnorm=I=-16:TP=-1.5:LRA=11"
    assert payload["Summary"] == "Deinterlace: YADIF | Denoise: Light | Rotate/flip: 90 CW | Scale: 720p | Audio normalize: On"

    assert args[args.index("-ss") + 1] == "00:01:00"
    assert args[args.index("-t") + 1] == "00:01:00"
    assert args[args.index("-vf") + 1] == payload["VideoChain"]
    assert args[args.index("-af") + 1] == payload["AudioChain"]
    assert args.index("-vf") > args.index("-i")
    assert args.index("-vf") < args.index("-c:v")
    assert args.index("-af") < args.index("-c:a")
    assert args[args.index("-f") + 1] == "segment"
    assert args[-1].endswith("filtered-part%03d.mp4")


def test_core_prefers_manual_crop_state_over_auto_crop_state(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    source = input_dir / "family_tape.avi"
    source.write_text("source", encoding="utf-8")

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$cropSource = [pscustomobject]@{{
  CropMode = 'Auto'
  CropLeft = 4
  CropTop = 6
  CropRight = 8
  CropBottom = 10
  ManualCropMode = 'Manual'
  ManualCropLeft = 12
  ManualCropTop = 14
  ManualCropRight = 16
  ManualCropBottom = 18
  SourceWidth = 720
  SourceHeight = 576
}}
$state = Get-VhsMp4CropState -InputObject $cropSource
$filter = Get-VhsMp4CropFilter -CropState $state
[pscustomobject]@{{
  Mode = $state.Mode
  Left = $state.Left
  Top = $state.Top
  Right = $state.Right
  Bottom = $state.Bottom
  Filter = $filter
}} | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["Mode"] == "Manual"
    assert payload["Left"] == 12
    assert payload["Top"] == 14
    assert payload["Right"] == 16
    assert payload["Bottom"] == 18
    assert payload["Filter"] == "crop=692:544:12:14"


def test_core_omits_crop_filter_for_no_crop_state(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    source = input_dir / "family_tape.avi"
    source.write_text("source", encoding="utf-8")

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$cropSource = [pscustomobject]@{{
  CropMode = 'None'
  SourceWidth = 720
  SourceHeight = 576
}}
$state = Get-VhsMp4CropState -InputObject $cropSource
$args = Get-VhsMp4FfmpegArguments -SourcePath '{source}' -OutputPath '{output_dir / "no-crop.mp4"}' -QualityMode 'Standard VHS' -CropState $state
[pscustomobject]@{{
  Mode = $state.Mode
  Args = $args
  Filter = Get-VhsMp4CropFilter -CropState $state
}} | ConvertTo-Json -Depth 6
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["Mode"] == "None"
    assert payload["Filter"] == ""
    assert "-vf" not in payload["Args"]


def test_core_builds_ffmpeg_crop_filter_for_manual_crop_state(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    source = input_dir / "family_tape.avi"
    source.write_text("source", encoding="utf-8")

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$cropSource = [pscustomobject]@{{
  CropMode = 'Manual'
  CropLeft = 12
  CropTop = 14
  CropRight = 16
  CropBottom = 18
  SourceWidth = 720
  SourceHeight = 576
}}
$state = Get-VhsMp4CropState -InputObject $cropSource
$filter = Get-VhsMp4CropFilter -CropState $state
$args = Get-VhsMp4FfmpegArguments -SourcePath '{source}' -OutputPath '{output_dir / "manual-crop.mp4"}' -QualityMode 'Standard VHS' -CropState $state
[pscustomobject]@{{
  Mode = $state.Mode
  Filter = $filter
  Args = $args
}} | ConvertTo-Json -Depth 6
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["Mode"] == "Manual"
    assert payload["Filter"] == "crop=692:544:12:14"
    assert payload["Args"][payload["Args"].index("-vf") + 1] == "crop=692:544:12:14"


def test_core_rejects_invalid_crop_values(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    source = input_dir / "family_tape.avi"
    source.write_text("source", encoding="utf-8")

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$valid = [pscustomobject]@{{
  CropMode = 'Manual'
  CropLeft = 12
  CropTop = 14
  CropRight = 16
  CropBottom = 18
  SourceWidth = 720
  SourceHeight = 576
}}
$negative = [pscustomobject]@{{
  CropMode = 'Manual'
  CropLeft = -1
  CropTop = 0
  CropRight = 0
  CropBottom = 0
  SourceWidth = 720
  SourceHeight = 576
}}
$tooWide = [pscustomobject]@{{
  CropMode = 'Manual'
  CropLeft = 400
  CropTop = 0
  CropRight = 400
  CropBottom = 0
  SourceWidth = 720
  SourceHeight = 576
}}
$validState = Get-VhsMp4CropState -InputObject $valid
$validTest = Test-VhsMp4CropState -CropState $validState
$negativeTest = Test-VhsMp4CropState -CropState $negative
$tooWideTest = Test-VhsMp4CropState -CropState $tooWide
$rejected = $false
try {{
  Get-VhsMp4CropState -InputObject $negative | Out-Null
}}
catch {{
  $rejected = $true
}}
[pscustomobject]@{{
  ValidTest = $validTest
  NegativeTest = $negativeTest
  TooWideTest = $tooWideTest
  Rejected = $rejected
}} | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["ValidTest"] is True
    assert payload["NegativeTest"] is False
    assert payload["TooWideTest"] is False
    assert payload["Rejected"] is True


def test_core_detect_crop_sample_times_spread_across_duration() -> None:
    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
Get-VhsMp4CropDetectionSampleTimes -DurationSeconds 120 -SampleCount 5 | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload == [20, 40, 60, 80, 100]


def test_core_detect_crop_prefers_majority_sample_and_stays_conservative() -> None:
    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$detection = [pscustomobject]@{{
  SourceWidth = 720
  SourceHeight = 576
  Samples = @(
    [pscustomobject]@{{ Left = 12; Top = 14; Right = 16; Bottom = 18 }},
    [pscustomobject]@{{ Left = 12; Top = 14; Right = 16; Bottom = 18 }},
    [pscustomobject]@{{ Left = 12; Top = 14; Right = 16; Bottom = 18 }},
    [pscustomobject]@{{ Left = 8; Top = 10; Right = 12; Bottom = 14 }}
  )
}}
Get-VhsMp4DetectedCrop -InputObject $detection | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["Mode"] == "Auto"
    assert payload["Left"] == 12
    assert payload["Top"] == 14
    assert payload["Right"] == 16
    assert payload["Bottom"] == 18


def test_core_detect_crop_returns_no_crop_when_samples_are_unsafe_or_ambiguous() -> None:
    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$detection = [pscustomobject]@{{
  SourceWidth = 720
  SourceHeight = 576
  Samples = @(
    [pscustomobject]@{{ Left = 12; Top = 14; Right = 16; Bottom = 18 }},
    [pscustomobject]@{{ Left = 8; Top = 10; Right = 12; Bottom = 14 }}
  )
}}
Get-VhsMp4DetectedCrop -InputObject $detection | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["Mode"] == "None"
    assert payload["Left"] == 0
    assert payload["Top"] == 0
    assert payload["Right"] == 0
    assert payload["Bottom"] == 0


def test_core_detect_crop_treats_partial_sample_failures_as_unsafe() -> None:
    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$detection = [pscustomobject]@{{
  SourceWidth = 720
  SourceHeight = 576
  Samples = @(
    [pscustomobject]@{{ Left = 12; Top = 14; Right = 16; Bottom = 18 }},
    [pscustomobject]@{{ Left = 12; Top = 14; Right = 16; Bottom = 18 }},
    [pscustomobject]@{{ Left = 12; Top = 14; Right = 16; Bottom = 18 }},
    [pscustomobject]@{{ Left = 'bad'; Top = 14; Right = 16; Bottom = 18 }},
    [pscustomobject]@{{ Left = 12; Top = $null; Right = 16; Bottom = 18 }}
  )
}}
Get-VhsMp4DetectedCrop -InputObject $detection | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["Mode"] == "None"
    assert payload["Left"] == 0
    assert payload["Top"] == 0
    assert payload["Right"] == 0
    assert payload["Bottom"] == 0


def test_core_crop_filter_recomputes_dimensions_for_stale_mode_state(tmp_path: Path) -> None:
    source = tmp_path / "family_tape.avi"
    source.write_text("source", encoding="utf-8")

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$staleCrop = [pscustomobject]@{{
  Mode = 'Manual'
  Left = 12
  Top = 14
  Right = 16
  Bottom = 18
  Width = 1
  Height = 2
  SourceWidth = 720
  SourceHeight = 576
}}
Get-VhsMp4CropFilter -CropState $staleCrop
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    assert run.stdout.strip() == "crop=692:544:12:14"


def test_core_prepends_crop_to_existing_video_filter_chain(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    source = input_dir / "family_tape.avi"
    source.write_text("source", encoding="utf-8")

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$cropState = [pscustomobject]@{{
  Mode = 'Manual'
  Left = 12
  Top = 14
  Right = 16
  Bottom = 18
  SourceWidth = 720
  SourceHeight = 576
}}
$args = Get-VhsMp4FfmpegArguments -SourcePath '{source}' -OutputPath '{output_dir / "filtered.mp4"}' -QualityMode 'Standard VHS' -CropState $cropState -Deinterlace 'YADIF' -ScaleMode 'PAL 576p'
[pscustomobject]@{{
  Args = $args
}} | ConvertTo-Json -Depth 6
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)
    args = payload["Args"]

    assert args[args.index("-vf") + 1] == "crop=692:544:12:14,yadif=0:-1:0,scale=-2:576:flags=lanczos"


def test_core_includes_crop_inside_multi_trim_filter_complex(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    source = input_dir / "family_tape.avi"
    source.write_text("source", encoding="utf-8")

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$cropState = [pscustomobject]@{{
  Mode = 'Manual'
  Left = 12
  Top = 14
  Right = 16
  Bottom = 18
  SourceWidth = 720
  SourceHeight = 576
}}
$segments = @(
  [pscustomobject]@{{ StartText = '00:00:10'; EndText = '00:00:20' }},
  [pscustomobject]@{{ StartText = '00:01:00'; EndText = '00:01:30' }}
)
$args = Get-VhsMp4FfmpegArguments -SourcePath '{source}' -OutputPath '{output_dir / "multi-crop.mp4"}' -QualityMode 'Universal MP4 H.264' -CropState $cropState -TrimSegments $segments -SourceHasAudio $true -Deinterlace 'YADIF' -ScaleMode 'PAL 576p'
[pscustomobject]@{{
  Args = $args
}} | ConvertTo-Json -Depth 6
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)
    args = payload["Args"]

    assert "-filter_complex" in args
    assert "-vf" not in args
    filter_complex = args[args.index("-filter_complex") + 1]
    assert "crop=692:544:12:14" in filter_complex
    assert "trim=start=10:end=20" in filter_complex
    assert "trim=start=60:end=90" in filter_complex
    assert "concat=n=2:v=1:a=1[vout][aout]" in filter_complex


def test_core_builds_pal_576p_scale_filter() -> None:
    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$videoChain = Get-VhsMp4VideoFilterChain -ScaleMode 'PAL 576p'
$summary = Get-VhsMp4FilterSummary -ScaleMode 'PAL 576p'
[pscustomobject]@{{
  VideoChain = $videoChain
  Summary = $summary
}} | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["VideoChain"] == "scale=-2:576:flags=lanczos"
    assert payload["Summary"] == "Scale: PAL 576p"


def test_core_generates_preview_frame_with_ffmpeg(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    source = input_dir / "family_tape.avi"
    source.write_text("source", encoding="utf-8")

    fake_ffmpeg = tmp_path / "fake_ffmpeg.ps1"
    fake_ffmpeg.write_text(
        """
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$logPath = $env:FAKE_FFMPEG_LOG
if ($logPath) {
  Add-Content -LiteralPath $logPath -Value ($Args -join "`n") -Encoding UTF8
}

$outputPath = $Args[-1]
Set-Content -LiteralPath $outputPath -Value "preview" -Encoding UTF8
""".strip(),
        encoding="utf-8",
    )

    fake_ffmpeg_log = tmp_path / "fake-ffmpeg.log"
    env = os.environ.copy()
    env["FAKE_FFMPEG_LOG"] = str(fake_ffmpeg_log)

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$previewPath = Join-Path '{output_dir}' 'preview.png'
$result = New-VhsMp4PreviewFrame -SourcePath '{source}' -OutputPath $previewPath -FfmpegPath '{fake_ffmpeg}' -PreviewTime '00:00:10'
[pscustomobject]@{{
  OutputPath = $result.OutputPath
  PreviewTime = $result.PreviewTime
  ExitCode = $result.ExitCode
  Exists = Test-Path -LiteralPath $previewPath
}} | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["Exists"] is True
    assert payload["ExitCode"] == 0
    assert payload["PreviewTime"] == "00:00:10"
    assert payload["OutputPath"].endswith("preview.png")

    fake_invocation = fake_ffmpeg_log.read_text(encoding="utf-8")
    assert "-ss" in fake_invocation
    assert "00:00:10" in fake_invocation
    assert "-frames:v" in fake_invocation
    assert "1" in fake_invocation
    assert "-c:v" in fake_invocation
    assert "png" in fake_invocation
    assert "-pix_fmt" in fake_invocation
    assert "rgb24" in fake_invocation
    assert "-q:v" not in fake_invocation


def test_core_detects_crop_from_source_path_with_ffmpeg_cropdetect(tmp_path: Path) -> None:
    source = tmp_path / "family_tape.mp4"
    source.write_text("source", encoding="utf-8")

    fake_ffmpeg = tmp_path / "fake_ffmpeg_cropdetect.ps1"
    fake_ffmpeg.write_text(
        """
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$logPath = $env:FAKE_FFMPEG_LOG
if ($logPath) {
  Add-Content -LiteralPath $logPath -Value ($Args -join "`n") -Encoding UTF8
  Add-Content -LiteralPath $logPath -Value "`n---" -Encoding UTF8
}

[Console]::Error.WriteLine("[Parsed_cropdetect_0 @ 000001] x1:12 x2:705 y1:8 y2:565 w:694 h:558 x:12 y:8 pts:0 t:0.000 crop=694:558:12:8")
""".strip(),
        encoding="utf-8",
    )

    fake_ffmpeg_log = tmp_path / "fake-ffmpeg-cropdetect.log"
    env = os.environ.copy()
    env["FAKE_FFMPEG_LOG"] = str(fake_ffmpeg_log)

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$result = Get-VhsMp4DetectedCropFromSourcePath -SourcePath '{source}' -FfmpegPath '{fake_ffmpeg}' -DurationSeconds 180 -SourceWidth 720 -SourceHeight 576
[pscustomobject]@{{
  Mode = $result.Mode
  Left = $result.Left
  Top = $result.Top
  Right = $result.Right
  Bottom = $result.Bottom
  Width = $result.Width
  Height = $result.Height
  SampleCount = $result.SampleCount
  StableSampleCount = $result.StableSampleCount
  Summary = $result.Summary
}} | ConvertTo-Json -Compress
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["Mode"] == "Auto"
    assert payload["Left"] == 12
    assert payload["Top"] == 8
    assert payload["Right"] == 14
    assert payload["Bottom"] == 10
    assert payload["Width"] == 694
    assert payload["Height"] == 558
    assert payload["SampleCount"] == 5
    assert payload["StableSampleCount"] == 5
    assert "Auto crop" in payload["Summary"]

    fake_invocation = fake_ffmpeg_log.read_text(encoding="utf-8")
    assert "-vf" in fake_invocation
    assert "cropdetect" in fake_invocation
    assert fake_invocation.count("-ss") == 5


def test_core_customer_report_includes_trim_summary(tmp_path: Path) -> None:
    output_dir = tmp_path / "output"
    output_dir.mkdir()
    output_file = output_dir / "family_tape.mp4"

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$items = @(
  [pscustomobject]@{{
    SourceName = 'family_tape.avi'
    Status = 'done'
    OutputPath = '{output_file}'
    TrimSummary = '00:01:00 - 00:02:30'
  }}
)
$reportPath = Write-VhsMp4CustomerReport -OutputDir '{output_dir}' -Items $items -QualityMode 'Standard VHS' -FilterSummary 'Deinterlace: YADIF | Denoise: Light | Audio normalize: On'
Get-Content -LiteralPath $reportPath -Raw
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    assert "Filters: Deinterlace: YADIF | Denoise: Light | Audio normalize: On" in run.stdout
    assert "family_tape.avi | done | family_tape.mp4" in run.stdout
    assert "Trim: 00:01:00 - 00:02:30" in run.stdout


def test_core_batch_applies_per_file_trim_only_to_items_that_have_trim(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    trimmed_source = input_dir / "trimmed.avi"
    full_source = input_dir / "full.avi"
    trimmed_source.write_text("trimmed-source", encoding="utf-8")
    full_source.write_text("full-source", encoding="utf-8")
    trimmed_output = output_dir / "trimmed.mp4"
    full_output = output_dir / "full.mp4"

    fake_ffmpeg = tmp_path / "fake_ffmpeg.ps1"
    fake_ffmpeg.write_text(
        """
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$logPath = $env:FAKE_FFMPEG_LOG
if ($logPath) {
  Add-Content -LiteralPath $logPath -Value ($Args -join "`n") -Encoding UTF8
  Add-Content -LiteralPath $logPath -Value "`n---" -Encoding UTF8
}

$outputPath = $Args[-1]
if ($outputPath -ne "-version") {
  Set-Content -LiteralPath $outputPath -Value "converted" -Encoding UTF8
}
""".strip(),
        encoding="utf-8",
    )

    fake_ffmpeg_log = tmp_path / "fake-ffmpeg.log"
    env = os.environ.copy()
    env["FAKE_FFMPEG_LOG"] = str(fake_ffmpeg_log)

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$plan = @(
  [pscustomobject]@{{
    SourceName = 'trimmed.avi'
    SourcePath = '{trimmed_source}'
    OutputPath = '{trimmed_output}'
    Status = 'queued'
    TrimStartText = '00:01:00'
    TrimEndText = '00:02:30'
  }},
  [pscustomobject]@{{
    SourceName = 'full.avi'
    SourcePath = '{full_source}'
    OutputPath = '{full_output}'
    Status = 'queued'
  }}
)
$summary = Invoke-VhsMp4Batch -InputDir '{input_dir}' -OutputDir '{output_dir}' -QualityMode 'Standard VHS' -FfmpegPath '{fake_ffmpeg}' -Plan $plan
[pscustomobject]@{{
  Processed = $summary.ProcessedCount
  Failed = $summary.FailedCount
  Items = @($summary.Items | Select-Object SourceName, Status, TrimSummary)
}} | ConvertTo-Json -Depth 6
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)
    assert payload["Processed"] == 2
    assert payload["Failed"] == 0

    fake_invocation = fake_ffmpeg_log.read_text(encoding="utf-8")
    sections = [section.strip() for section in fake_invocation.split("---") if section.strip()]
    conversion_sections = [section for section in sections if str(trimmed_source) in section or str(full_source) in section]
    trimmed_section = next(section for section in conversion_sections if str(trimmed_source) in section)
    full_section = next(section for section in conversion_sections if str(full_source) in section)

    assert "-ss\n00:01:00" in trimmed_section
    assert "-t\n00:01:30" in trimmed_section
    assert "-ss" not in full_section
    assert "-t\n00:01:30" not in full_section


def test_core_batch_uses_multi_trim_segments_for_selected_file(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    segmented_source = input_dir / "segmented.avi"
    full_source = input_dir / "full.avi"
    segmented_source.write_text("segmented-source", encoding="utf-8")
    full_source.write_text("full-source", encoding="utf-8")
    segmented_output = output_dir / "segmented.mp4"
    full_output = output_dir / "full.mp4"

    fake_ffmpeg = tmp_path / "fake_ffmpeg.ps1"
    fake_ffmpeg.write_text(
        """
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$logPath = $env:FAKE_FFMPEG_LOG
if ($logPath) {
  Add-Content -LiteralPath $logPath -Value ($Args -join "`n") -Encoding UTF8
  Add-Content -LiteralPath $logPath -Value "`n---" -Encoding UTF8
}

$outputPath = $Args[-1]
if ($outputPath -ne "-version") {
  Set-Content -LiteralPath $outputPath -Value "converted" -Encoding UTF8
}
""".strip(),
        encoding="utf-8",
    )

    fake_ffmpeg_log = tmp_path / "fake-ffmpeg.log"
    env = os.environ.copy()
    env["FAKE_FFMPEG_LOG"] = str(fake_ffmpeg_log)

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$plan = @(
  [pscustomobject]@{{
    SourceName = 'segmented.avi'
    SourcePath = '{segmented_source}'
    OutputPath = '{segmented_output}'
    Status = 'queued'
    TrimSegments = @(
      [pscustomobject]@{{ StartText = '00:00:10'; EndText = '00:00:20' }},
      [pscustomobject]@{{ StartText = '00:01:00'; EndText = '00:01:30' }}
    )
    HasAudio = $true
  }},
  [pscustomobject]@{{
    SourceName = 'full.avi'
    SourcePath = '{full_source}'
    OutputPath = '{full_output}'
    Status = 'queued'
  }}
)
$summary = Invoke-VhsMp4Batch -InputDir '{input_dir}' -OutputDir '{output_dir}' -QualityMode 'Standard VHS' -FfmpegPath '{fake_ffmpeg}' -Plan $plan
[pscustomobject]@{{
  Processed = $summary.ProcessedCount
  Failed = $summary.FailedCount
  Items = @($summary.Items | Select-Object SourceName, Status, TrimSummary, TrimDurationSeconds)
}} | ConvertTo-Json -Depth 6
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)
    assert payload["Processed"] == 2
    assert payload["Failed"] == 0

    segmented_item = next(item for item in payload["Items"] if item["SourceName"] == "segmented.avi")
    assert segmented_item["TrimSummary"] == "2 seg | 00:00:10 - 00:00:20 ; 00:01:00 - 00:01:30"
    assert segmented_item["TrimDurationSeconds"] == 40

    fake_invocation = fake_ffmpeg_log.read_text(encoding="utf-8")
    sections = [section.strip() for section in fake_invocation.split("---") if section.strip()]
    conversion_sections = [section for section in sections if str(segmented_source) in section or str(full_source) in section]
    segmented_section = next(section for section in conversion_sections if str(segmented_source) in section)
    full_section = next(section for section in conversion_sections if str(full_source) in section)

    assert "-filter_complex" in segmented_section
    assert "concat=n=2:v=1:a=1[vout][aout]" in segmented_section
    assert "-ss" not in segmented_section
    assert "-filter_complex" not in full_section


def test_core_plans_and_builds_segmented_mp4_parts_for_split_outputs(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    skipped_source = input_dir / "already_done.mp4"
    queued_source = input_dir / "long_family_tape.avi"
    skipped_source.write_text("already-source", encoding="utf-8")
    queued_source.write_text("queued-source", encoding="utf-8")

    existing_first_part = output_dir / "already_done-part001.mp4"
    existing_first_part.write_text("keep-existing", encoding="utf-8")

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$plan = Get-VhsMp4Plan -InputDir '{input_dir}' -OutputDir '{output_dir}' -SplitOutput
$segmentSeconds = Get-VhsMp4SplitSegmentSeconds -MaxPartGb 3.8 -VideoMaxKbps 4500 -AudioBitrate '160k'
$splitArgs = Get-VhsMp4FfmpegArguments -SourcePath '{queued_source}' -OutputPath '{output_dir / "long_family_tape-part%03d.mp4"}' -QualityMode 'Standard VHS' -SplitOutput -MaxPartGb 3.8
[pscustomobject]@{{
  plan = @($plan | Select-Object SourceName, Status, OutputPath, OutputPattern, DisplayOutputName)
  segmentSeconds = $segmentSeconds
  splitArgs = $splitArgs
}} | ConvertTo-Json -Depth 6
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)
    plan = {item["SourceName"]: item for item in payload["plan"]}

    assert plan["already_done.mp4"]["Status"] == "skipped"
    assert plan["already_done.mp4"]["OutputPath"].endswith("already_done-part001.mp4")
    assert plan["already_done.mp4"]["OutputPattern"].endswith("already_done-part%03d.mp4")
    assert plan["already_done.mp4"]["DisplayOutputName"] == "already_done-part%03d.mp4"

    assert plan["long_family_tape.avi"]["Status"] == "queued"
    assert plan["long_family_tape.avi"]["OutputPath"].endswith("long_family_tape-part001.mp4")
    assert plan["long_family_tape.avi"]["OutputPattern"].endswith("long_family_tape-part%03d.mp4")

    args = payload["splitArgs"]
    assert args[args.index("-f") + 1] == "segment"
    assert args[args.index("-segment_time") + 1] == str(payload["segmentSeconds"])
    assert args[args.index("-segment_start_number") + 1] == "1"
    assert args[args.index("-segment_format") + 1] == "mp4"
    assert args[args.index("-segment_format_options") + 1] == "movflags=+faststart"
    assert args[args.index("-maxrate") + 1] == "4500k"
    assert args[args.index("-bufsize") + 1] == "9000k"
    assert args[-1].endswith("long_family_tape-part%03d.mp4")


def test_core_estimates_output_size_parts_and_usb_warning() -> None:
    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$fat32Risk = Get-VhsMp4EstimatedOutputInfo -DurationSeconds 7200 -QualityMode 'Better Quality' -AudioBitrate '192k'
$splitSafe = Get-VhsMp4EstimatedOutputInfo -DurationSeconds 7200 -QualityMode 'Better Quality' -AudioBitrate '192k' -SplitOutput -MaxPartGb 3.8
[pscustomobject]@{{
  fat32Risk = $fat32Risk
  splitSafe = $splitSafe
}} | ConvertTo-Json -Depth 6
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["fat32Risk"]["EstimatedGb"] > 4
    assert payload["fat32Risk"]["PartCount"] == 1
    assert payload["fat32Risk"]["FitsFat32"] is False
    assert "FAT32" in payload["fat32Risk"]["UsbNote"]
    assert "Split output" in payload["fat32Risk"]["UsbNote"]

    assert payload["splitSafe"]["EstimatedGb"] > 4
    assert payload["splitSafe"]["PartCount"] >= 2
    assert payload["splitSafe"]["FitsFat32"] is True
    assert "delova" in payload["splitSafe"]["UsbNote"]


def test_core_honors_explicit_video_bitrate_in_estimate_and_arguments(tmp_path: Path) -> None:
    source = tmp_path / "source.mp4"
    source.write_text("source", encoding="utf-8")
    output_dir = tmp_path / "output"
    output_dir.mkdir()

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$estimate = Get-VhsMp4EstimatedOutputInfo -DurationSeconds 600 -QualityMode 'Universal MP4 H.264' -AudioBitrate '160k' -VideoBitrate '5500k'
$args = Get-VhsMp4FfmpegArguments -SourcePath '{source}' -OutputPath '{output_dir / "out.mp4"}' -QualityMode 'Universal MP4 H.264' -AudioBitrate '160k' -VideoBitrate '5500k'
[pscustomobject]@{{
  Estimate = $estimate
  Args = $args
}} | ConvertTo-Json -Depth 6
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)
    args = payload["Args"]

    assert payload["Estimate"]["VideoKbps"] == 5500
    assert payload["Estimate"]["AudioKbps"] == 160
    assert payload["Estimate"]["TotalKbps"] == 5660
    assert args[args.index("-b:v") + 1] == "5500k"
    assert args[args.index("-maxrate") + 1] == "5500k"
    assert args[args.index("-bufsize") + 1] == "11000k"
    assert "-crf" not in args


def test_core_builds_test_sample_arguments_and_report(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    source = input_dir / "porodica.mpg"
    source.write_text("source", encoding="utf-8")

    fake_ffmpeg = tmp_path / "fake_ffmpeg.ps1"
    fake_ffmpeg.write_text(
        """
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$logPath = $env:FAKE_FFMPEG_LOG
if ($logPath) {
  Add-Content -LiteralPath $logPath -Value ($Args -join "`n") -Encoding UTF8
  Add-Content -LiteralPath $logPath -Value "`n---" -Encoding UTF8
}

$outputPath = $Args[-1]
Set-Content -LiteralPath $outputPath -Value "mp4 output" -Encoding UTF8
""".strip(),
        encoding="utf-8",
    )

    fake_ffmpeg_log = tmp_path / "fake-ffmpeg.log"
    env = os.environ.copy()
    env["FAKE_FFMPEG_LOG"] = str(fake_ffmpeg_log)

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
$samplePath = Get-VhsMp4SampleOutputPath -OutputDir '{output_dir}' -SourceName '{source.name}'
$sampleArgs = Get-VhsMp4FfmpegArguments -SourcePath '{source}' -OutputPath $samplePath -QualityMode 'Standard VHS' -SampleSeconds 120
$sampleResult = Invoke-VhsMp4File -SourcePath '{source}' -OutputPath $samplePath -FfmpegPath '{fake_ffmpeg}' -QualityMode 'Standard VHS' -SampleSeconds 120
$summary = Invoke-VhsMp4Batch -InputDir '{input_dir}' -OutputDir '{output_dir}' -QualityMode 'Smaller File' -FfmpegPath '{fake_ffmpeg}'
[pscustomobject]@{{
  samplePath = $samplePath
  sampleArgs = $sampleArgs
  sampleSuccess = $sampleResult.Success
  reportPath = $summary.ReportPath
  report = [string](Get-Content -LiteralPath $summary.ReportPath -Raw)
}} | ConvertTo-Json -Depth 6
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout)

    assert payload["samplePath"].endswith("samples\\porodica-sample.mp4")
    assert payload["sampleSuccess"] is True
    assert payload["sampleArgs"][payload["sampleArgs"].index("-t") + 1] == "120"
    assert Path(payload["samplePath"]).exists()
    assert Path(payload["reportPath"]).name == "IZVESTAJ.txt"
    assert "VHS MP4 Optimizer" in payload["report"]
    assert "porodica.mpg" in payload["report"]
    assert "Originalni fajlovi nisu menjani" in payload["report"]
    assert "USB PREDAJA CHECKLIST" in payload["report"]
    assert "exFAT" in payload["report"]
    assert "FAT32" in payload["report"]

    fake_invocation = fake_ffmpeg_log.read_text(encoding="utf-8")
    assert "-t\n120" in fake_invocation


def test_core_ffmpeg_preflight_blocks_run_context_before_conversion(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    source = input_dir / "porodica.mp4"
    source.write_text("source", encoding="utf-8")

    fake_ffmpeg = tmp_path / "fake_ffmpeg.ps1"
    fake_ffmpeg.write_text(
        """
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

if ($Args[0] -eq "-version") {
  Write-Output "ffmpeg missing codec support"
  exit 9
}

$outputPath = $Args[-1]
Set-Content -LiteralPath $outputPath -Value "mp4 output" -Encoding UTF8
""".strip(),
        encoding="utf-8",
    )

    command = f"""
$ErrorActionPreference = 'Stop'
Import-Module '{MODULE}' -Force
try {{
  New-VhsMp4RunContext -InputDir '{input_dir}' -OutputDir '{output_dir}' -FfmpegPath '{fake_ffmpeg}' | Out-Null
  'NO_ERROR'
}}
catch {{
  $_.Exception.Message
}}
""".strip()

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ],
        cwd=ROOT,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    assert "NO_ERROR" not in run.stdout
    assert "FFmpeg preflight" in run.stdout
    assert "exit code:" in run.stdout
