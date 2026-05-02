from pathlib import Path
import os
import subprocess


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "optimize-vhs-mp4.ps1"


def test_cli_skips_existing_outputs_logs_results_and_uses_quality_mode(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "delivery"
    input_dir.mkdir()
    output_dir.mkdir()

    skipped_source = input_dir / "porodica_01.mp4"
    processed_source = input_dir / "porodica_02.mpg"
    skipped_source.write_text("source-a", encoding="utf-8")
    processed_source.write_text("source-b", encoding="utf-8")

    existing_output = output_dir / "porodica_01.mp4"
    existing_output.write_text("keep-me", encoding="utf-8")

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
Set-Content -LiteralPath $outputPath -Value "small delivery mp4" -Encoding UTF8
""".strip(),
        encoding="utf-8",
    )
    fake_ffprobe = tmp_path / "ffprobe.ps1"
    fake_ffprobe.write_text(
        """
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$payload = @{
  format = @{
    filename = $Args[-1]
    duration = "300.0"
    size = "1024"
    bit_rate = "1000000"
    format_name = "avi"
    format_long_name = "AVI"
  }
  streams = @(
    @{
      codec_type = "video"
      codec_name = "mpeg4"
      width = 720
      height = 576
      display_aspect_ratio = "4:3"
      sample_aspect_ratio = "1:1"
      avg_frame_rate = "25/1"
      nb_frames = "7500"
      bit_rate = "900000"
    },
    @{
      codec_type = "audio"
      codec_name = "mp2"
      channels = 2
      sample_rate = "48000"
      bit_rate = "128000"
    }
  )
}
$payload | ConvertTo-Json -Depth 6 -Compress
""".strip(),
        encoding="utf-8",
    )
    fake_ffprobe = tmp_path / "ffprobe.ps1"
    fake_ffprobe.write_text(
        """
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$payload = @{
  format = @{
    filename = $Args[-1]
    duration = "300.0"
    size = "1024"
    bit_rate = "1000000"
    format_name = "avi"
    format_long_name = "AVI"
  }
  streams = @(
    @{
      codec_type = "video"
      codec_name = "mpeg4"
      width = 720
      height = 576
      display_aspect_ratio = "4:3"
      sample_aspect_ratio = "1:1"
      avg_frame_rate = "25/1"
      nb_frames = "7500"
      bit_rate = "900000"
    },
    @{
      codec_type = "audio"
      codec_name = "mp2"
      channels = 2
      sample_rate = "48000"
      bit_rate = "128000"
    }
  )
}
$payload | ConvertTo-Json -Depth 6 -Compress
""".strip(),
        encoding="utf-8",
    )

    fake_ffmpeg_log = tmp_path / "fake-ffmpeg.log"
    env = os.environ.copy()
    env["FAKE_FFMPEG_LOG"] = str(fake_ffmpeg_log)

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(SCRIPT),
            "-InputDir",
            str(input_dir),
            "-OutputDir",
            str(output_dir),
            "-QualityMode",
            "Smaller File",
            "-FfmpegPath",
            str(fake_ffmpeg),
        ],
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    assert existing_output.read_text(encoding="utf-8") == "keep-me"
    assert processed_source.read_text(encoding="utf-8") == "source-b"
    assert (output_dir / "porodica_02.mp4").exists()
    assert (output_dir / "IZVESTAJ.txt").exists()

    log_files = list((output_dir / "logs").glob("optimize-vhs-mp4-*.log"))
    assert log_files, "expected optimizer log to be created"

    fake_invocation = fake_ffmpeg_log.read_text(encoding="utf-8")
    assert str(processed_source) in fake_invocation
    assert str(skipped_source) not in fake_invocation
    assert "-crf\n24" in fake_invocation
    assert "-b:a\n128k" in fake_invocation
    assert "Processed: 1" in run.stdout
    assert "Skipped: 1" in run.stdout
    assert "Failed: 0" in run.stdout
    assert "Report:" in run.stdout
    assert "porodica_02.mpg" in (output_dir / "IZVESTAJ.txt").read_text(encoding="utf-8")


def test_cli_split_output_uses_segment_muxer_and_part_names(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "delivery"
    input_dir.mkdir()
    output_dir.mkdir()

    skipped_source = input_dir / "porodica_01.mp4"
    processed_source = input_dir / "porodica_02.avi"
    skipped_source.write_text("source-a", encoding="utf-8")
    processed_source.write_text("source-b", encoding="utf-8")

    existing_first_part = output_dir / "porodica_01-part001.mp4"
    existing_first_part.write_text("keep-me", encoding="utf-8")

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
Set-Content -LiteralPath $outputPath -Value "split delivery mp4" -Encoding UTF8
""".strip(),
        encoding="utf-8",
    )

    fake_ffmpeg_log = tmp_path / "fake-ffmpeg.log"
    env = os.environ.copy()
    env["FAKE_FFMPEG_LOG"] = str(fake_ffmpeg_log)

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(SCRIPT),
            "-InputDir",
            str(input_dir),
            "-OutputDir",
            str(output_dir),
            "-QualityMode",
            "Standard VHS",
            "-SplitOutput",
            "-MaxPartGb",
            "3.8",
            "-FfmpegPath",
            str(fake_ffmpeg),
        ],
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    assert existing_first_part.read_text(encoding="utf-8") == "keep-me"
    assert processed_source.read_text(encoding="utf-8") == "source-b"
    assert (output_dir / "porodica_02-part%03d.mp4").exists()

    fake_invocation = fake_ffmpeg_log.read_text(encoding="utf-8")
    assert str(processed_source) in fake_invocation
    assert str(skipped_source) not in fake_invocation
    assert "-f\nsegment" in fake_invocation
    assert "-segment_start_number\n1" in fake_invocation
    assert "-segment_format_options\nmovflags=+faststart" in fake_invocation
    assert "porodica_02-part%03d.mp4" in fake_invocation
    assert "Processed: 1" in run.stdout
    assert "Skipped: 1" in run.stdout
    assert "Failed: 0" in run.stdout


def test_cli_accepts_hevc_video_converter_profile(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "delivery"
    input_dir.mkdir()
    output_dir.mkdir()

    processed_source = input_dir / "phone.mov"
    processed_source.write_text("source", encoding="utf-8")

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
  Set-Content -LiteralPath $outputPath -Value "hevc delivery mp4" -Encoding UTF8
}
""".strip(),
        encoding="utf-8",
    )

    fake_ffmpeg_log = tmp_path / "fake-ffmpeg.log"
    env = os.environ.copy()
    env["FAKE_FFMPEG_LOG"] = str(fake_ffmpeg_log)

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(SCRIPT),
            "-InputDir",
            str(input_dir),
            "-OutputDir",
            str(output_dir),
            "-QualityMode",
            "HEVC H.265 Smaller",
            "-FfmpegPath",
            str(fake_ffmpeg),
        ],
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    assert (output_dir / "phone.mp4").exists()

    fake_invocation = fake_ffmpeg_log.read_text(encoding="utf-8")
    assert "-c:v\nlibx265" in fake_invocation
    assert "-tag:v\nhvc1" in fake_invocation
    assert "-crf\n26" in fake_invocation
    assert "Processed: 1" in run.stdout


def test_cli_accepts_trim_start_and_end_options(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "delivery"
    input_dir.mkdir()
    output_dir.mkdir()

    processed_source = input_dir / "family_tape.avi"
    processed_source.write_text("source", encoding="utf-8")

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
  Set-Content -LiteralPath $outputPath -Value "trimmed delivery mp4" -Encoding UTF8
}
""".strip(),
        encoding="utf-8",
    )
    fake_ffprobe = tmp_path / "ffprobe.ps1"
    fake_ffprobe.write_text(
        """
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$payload = @{
  format = @{
    filename = $Args[-1]
    duration = "300.0"
    size = "1024"
    bit_rate = "1000000"
    format_name = "avi"
    format_long_name = "AVI"
  }
  streams = @(
    @{
      codec_type = "video"
      codec_name = "mpeg4"
      width = 720
      height = 576
      display_aspect_ratio = "4:3"
      sample_aspect_ratio = "1:1"
      avg_frame_rate = "25/1"
      nb_frames = "7500"
      bit_rate = "900000"
    },
    @{
      codec_type = "audio"
      codec_name = "mp2"
      channels = 2
      sample_rate = "48000"
      bit_rate = "128000"
    }
  )
}
$payload | ConvertTo-Json -Depth 6 -Compress
""".strip(),
        encoding="utf-8",
    )

    fake_ffmpeg_log = tmp_path / "fake-ffmpeg.log"
    env = os.environ.copy()
    env["FAKE_FFMPEG_LOG"] = str(fake_ffmpeg_log)

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(SCRIPT),
            "-InputDir",
            str(input_dir),
            "-OutputDir",
            str(output_dir),
            "-QualityMode",
            "Standard VHS",
            "-TrimStart",
            "00:01:00",
            "-TrimEnd",
            "00:02:30",
            "-FfmpegPath",
            str(fake_ffmpeg),
        ],
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    assert (output_dir / "family_tape.mp4").exists()

    fake_invocation = fake_ffmpeg_log.read_text(encoding="utf-8")
    assert "-filter_complex" in fake_invocation
    assert "trim=start=0:end=60" in fake_invocation
    assert "trim=start=150:end=300" in fake_invocation
    assert "concat=n=2:v=1:a=1[vout][aout]" in fake_invocation
    assert str(processed_source) in fake_invocation
    assert "Processed: 1" in run.stdout


def test_cli_accepts_video_filter_options(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "delivery"
    input_dir.mkdir()
    output_dir.mkdir()

    processed_source = input_dir / "family_tape.avi"
    processed_source.write_text("source", encoding="utf-8")

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
  Set-Content -LiteralPath $outputPath -Value "filtered delivery mp4" -Encoding UTF8
}
""".strip(),
        encoding="utf-8",
    )

    fake_ffmpeg_log = tmp_path / "fake-ffmpeg.log"
    env = os.environ.copy()
    env["FAKE_FFMPEG_LOG"] = str(fake_ffmpeg_log)

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(SCRIPT),
            "-InputDir",
            str(input_dir),
            "-OutputDir",
            str(output_dir),
            "-QualityMode",
            "Universal MP4 H.264",
            "-Deinterlace",
            "YADIF",
            "-Denoise",
            "Medium",
            "-RotateFlip",
            "90 CCW",
            "-ScaleMode",
            "PAL 576p",
            "-AudioNormalize",
            "-FfmpegPath",
            str(fake_ffmpeg),
        ],
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )

    assert run.returncode == 0, run.stderr
    assert (output_dir / "family_tape.mp4").exists()

    fake_invocation = fake_ffmpeg_log.read_text(encoding="utf-8")
    assert "-vf\nyadif=0:-1:0,hqdn3d=3:3:8:8,transpose=2,scale=-2:576:flags=lanczos" in fake_invocation
    assert "-af\nloudnorm=I=-16:TP=-1.5:LRA=11" in fake_invocation
    assert str(processed_source) in fake_invocation
    assert "Processed: 1" in run.stdout
