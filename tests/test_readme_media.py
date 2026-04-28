from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]


def test_readme_embeds_generated_media_assets() -> None:
    readme = (ROOT / "README.md").read_text(encoding="utf-8")

    expected_assets = [
        "docs/media/readme-main-overview.png",
        "docs/media/readme-player-trim.png",
        "docs/media/readme-batch-controls.png",
        "docs/media/readme-workflow.gif",
    ]

    for asset in expected_assets:
        assert asset in readme, f"README missing media reference: {asset}"


def test_build_readme_media_script_generates_expected_assets(tmp_path: Path) -> None:
    script_path = ROOT / "scripts" / "build-readme-media.ps1"
    output_dir = tmp_path / "media"

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(script_path),
            "-OutputDir",
            str(output_dir),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=240,
    )

    assert run.returncode == 0, run.stderr

    png_assets = [
        output_dir / "readme-main-overview.png",
        output_dir / "readme-player-trim.png",
        output_dir / "readme-batch-controls.png",
    ]
    gif_asset = output_dir / "readme-workflow.gif"

    for asset in png_assets:
        assert asset.exists(), f"missing screenshot: {asset.name}"
        assert asset.stat().st_size > 10_000, f"screenshot too small: {asset.name}"
        with Image.open(asset) as image:
            assert image.width >= 1000
            assert image.height >= 700

    assert gif_asset.exists(), "missing workflow gif"
    assert gif_asset.stat().st_size > 20_000
    with Image.open(gif_asset) as image:
        assert getattr(image, "is_animated", False) is True
        assert getattr(image, "n_frames", 1) >= 3
