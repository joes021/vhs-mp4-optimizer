from __future__ import annotations

import json
import shutil
import subprocess
import zipfile
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[1]


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_vhs_next_packaging_tokens_exist() -> None:
    release_builder = read(ROOT / "scripts" / "build-vhs-mp4-next-release.ps1")
    installer_builder = read(ROOT / "scripts" / "build-vhs-mp4-next-installer.ps1")
    inno_script = read(ROOT / "packaging" / "vhs-mp4-optimizer-next.iss")

    for token in [
        "dotnet",
        "publish",
        "VHS MP4 Optimizer Next",
        "app-manifest.json",
        "README.txt",
        "VhsMp4Optimizer.App.exe",
        "VHS_MP4_OPTIMIZER_UPUTSTVO.html",
        "avalonia-logo.ico",
    ]:
        assert token in release_builder, f"missing next release token: {token}"

    for token in [
        "build-vhs-mp4-next-release.ps1",
        "Compress-Archive",
        "installer-manifest.json",
        "VHS-MP4-Optimizer-Next-portable-",
        "VHS-MP4-Optimizer-Next-Setup-",
        "ISCC.exe",
        "Branch",
        "codex/avalonia-migration",
    ]:
        assert token in installer_builder, f"missing next installer token: {token}"

    for token in [
        "AppName={#MyAppName}",
        "DefaultDirName={localappdata}\\Programs\\VHS MP4 Optimizer Next",
        "OutputBaseFilename=VHS-MP4-Optimizer-Next-Setup-",
        "VhsMp4Optimizer.App.exe",
        "avalonia-logo.ico",
    ]:
        assert token in inno_script, f"missing next inno token: {token}"


def test_vhs_next_release_builder_creates_manifest_and_docs(tmp_path: Path) -> None:
    release_root = tmp_path / "VHS MP4 Optimizer Next"
    version = "1.1.0-test"
    git_ref = "next123"

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(ROOT / "scripts" / "build-vhs-mp4-next-release.ps1"),
            "-ReleaseRoot",
            str(release_root),
            "-Version",
            version,
            "-GitRef",
            git_ref,
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=300,
    )

    assert run.returncode == 0, run.stderr
    manifest = json.loads((release_root / "app-manifest.json").read_text(encoding="utf-8"))
    assert manifest["AppName"] == "VHS MP4 Optimizer Next"
    assert manifest["Version"] == version
    assert manifest["GitRef"] == git_ref
    assert (release_root / "app" / "VhsMp4Optimizer.App.exe").exists()
    assert (release_root / "docs" / "VHS_MP4_OPTIMIZER_UPUTSTVO.html").exists()


def test_vhs_next_installer_builder_creates_portable_zip_and_manifest(tmp_path: Path) -> None:
    output_root = tmp_path / "dist"
    release_root = tmp_path / "release" / "VHS MP4 Optimizer Next"
    version = "1.1.0-test"
    git_ref = "next456"

    try:
        run = subprocess.run(
            [
                "powershell",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(ROOT / "scripts" / "build-vhs-mp4-next-installer.ps1"),
                "-OutputRoot",
                str(output_root),
                "-ReleaseRoot",
                str(release_root),
                "-Version",
                version,
                "-GitRef",
                git_ref,
            ],
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
            timeout=300,
        )

        assert run.returncode == 0, run.stderr
        portable_zip = output_root / f"VHS-MP4-Optimizer-Next-portable-{version}.zip"
        manifest_path = output_root / "installer-manifest.json"
        assert portable_zip.exists()
        assert manifest_path.exists()

        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        assert manifest["Version"] == version
        assert manifest["GitRef"] == git_ref
        assert manifest["ReleaseTag"] == f"vhs-mp4-optimizer-next-{version}"
        assert manifest["Branch"] == "codex/avalonia-migration"

        with zipfile.ZipFile(portable_zip) as archive:
            names = set(archive.namelist())
        assert "VHS MP4 Optimizer Next/app-manifest.json" in names
        assert "VHS MP4 Optimizer Next/README.txt" in names
        assert "VHS MP4 Optimizer Next/app/VhsMp4Optimizer.App.exe" in names
    finally:
        shutil.rmtree(tmp_path / "release", ignore_errors=True)


def test_vhs_next_setup_exe_can_install_release_payload_to_custom_dir(tmp_path: Path) -> None:
    output_root = tmp_path / "dist"
    release_root = tmp_path / "release" / "VHS MP4 Optimizer Next"
    version = "1.1.0-smoke"
    git_ref = "nextsmoke"

    try:
        run = subprocess.run(
            [
                "powershell",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(ROOT / "scripts" / "build-vhs-mp4-next-installer.ps1"),
                "-OutputRoot",
                str(output_root),
                "-ReleaseRoot",
                str(release_root),
                "-Version",
                version,
                "-GitRef",
                git_ref,
            ],
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
            timeout=300,
        )

        assert run.returncode == 0, run.stderr
        manifest = json.loads((output_root / "installer-manifest.json").read_text(encoding="utf-8"))
        if not manifest["SetupBuilt"]:
            pytest.skip("Inno Setup nije dostupan za Avalonia installer smoke test.")

        setup_path = Path(manifest["SetupExePath"])
        install_dir = tmp_path / "installed-next-app"
        install_run = subprocess.run(
            [
                str(setup_path),
                "/VERYSILENT",
                "/SUPPRESSMSGBOXES",
                "/NORESTART",
                "/NOICONS",
                "/SP-",
                f"/DIR={install_dir}",
            ],
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
            timeout=300,
        )

        assert install_run.returncode == 0, install_run.stderr
        assert (install_dir / "app-manifest.json").exists()
        assert (install_dir / "README.txt").exists()
        assert (install_dir / "app" / "VhsMp4Optimizer.App.exe").exists()
    finally:
        shutil.rmtree(tmp_path / "release", ignore_errors=True)
