from __future__ import annotations

import json
import subprocess
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_vhs_installer_packaging_tokens_exist() -> None:
    installer_builder = read(ROOT / "scripts" / "build-vhs-mp4-installer.ps1")
    release_publisher = read(ROOT / "scripts" / "publish-vhs-mp4-github-release.ps1")
    inno_script = read(ROOT / "packaging" / "vhs-mp4-optimizer.iss")

    for token in [
        "build-vhs-mp4-release.ps1",
        "Compress-Archive",
        "VHS-MP4-Optimizer-portable-",
        "VHS-MP4-Optimizer-Setup-",
        "installer-manifest.json",
        "app-manifest.json",
        "ISCC.exe",
        "Inno Setup",
        "GitRef",
        "ReleaseTag",
        "Repository",
        "SetupBuilt",
    ]:
        assert token in installer_builder, f"missing installer builder token: {token}"

    for token in [
        "gh release create",
        "gh release upload",
        "gh release view",
        "VHS MP4 Optimizer",
        "joes021/vhs-mp4-optimizer",
        '[string]$Target = "main"',
        "--clobber",
        "refs/tags/",
        "git push",
        "show-ref",
        "GetTempFileName",
        "Remove-Item -LiteralPath $stdoutPath, $stderrPath",
        "Start-Process -FilePath \"gh\"",
        "Start-Process -FilePath \"git\"",
        "ConvertTo-ProcessArgumentString",
    ]:
        assert token in release_publisher, f"missing release publisher token: {token}"

    for token in [
        "AppName=VHS MP4 Optimizer",
        "DefaultDirName={localappdata}\\Programs\\VHS MP4 Optimizer",
        "DefaultGroupName=VHS MP4 Optimizer",
        "PrivilegesRequired=lowest",
        "OutputBaseFilename",
        "Compression=lzma",
        "CreateDesktopIcon",
        "VHS MP4 Optimizer.bat",
        "assets\\vhs-mp4-optimizer.ico",
    ]:
        assert token in inno_script, f"missing inno setup token: {token}"


def test_vhs_installer_builder_creates_portable_zip_and_manifest(tmp_path: Path) -> None:
    output_root = tmp_path / "dist"
    version = "2026.04.28-test"
    git_ref = "test-sha"

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(ROOT / "scripts" / "build-vhs-mp4-installer.ps1"),
            "-OutputRoot",
            str(output_root),
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
        timeout=180,
    )

    assert run.returncode == 0, run.stderr

    portable_zip = output_root / f"VHS-MP4-Optimizer-portable-{version}.zip"
    manifest_path = output_root / "installer-manifest.json"
    assert portable_zip.exists(), portable_zip
    assert manifest_path.exists(), manifest_path

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    assert manifest["Version"] == version
    assert manifest["GitRef"] == git_ref
    assert manifest["ReleaseTag"] == f"vhs-mp4-optimizer-{version}"
    assert manifest["Repository"] == "joes021/vhs-mp4-optimizer"
    assert manifest["PortableZipPath"].endswith(portable_zip.name)
    assert manifest["PortableZipExists"] is True
    assert "SetupBuilt" in manifest

    with zipfile.ZipFile(portable_zip) as archive:
        names = set(archive.namelist())
    assert "VHS MP4 Optimizer/VHS MP4 Optimizer.bat" in names
    assert "VHS MP4 Optimizer/README - kako se koristi.txt" in names
    assert "VHS MP4 Optimizer/app-manifest.json" in names
    assert "VHS MP4 Optimizer/scripts/optimize-vhs-mp4-gui.ps1" in names


def test_vhs_release_builder_creates_app_manifest(tmp_path: Path) -> None:
    release_root = ROOT / "release" / "_pytest_app_manifest"
    version = "2026.04.29-test"
    git_ref = "abc1234"
    release_tag = f"vhs-mp4-optimizer-{version}"

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(ROOT / "scripts" / "build-vhs-mp4-release.ps1"),
            "-ReleaseRoot",
            str(release_root),
            "-Version",
            version,
            "-GitRef",
            git_ref,
            "-ReleaseTag",
            release_tag,
            "-Repository",
            "joes021/vhs-mp4-optimizer",
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=180,
    )

    assert run.returncode == 0, run.stderr

    app_manifest = json.loads((release_root / "app-manifest.json").read_text(encoding="utf-8"))
    assert app_manifest["AppName"] == "VHS MP4 Optimizer"
    assert app_manifest["Version"] == version
    assert app_manifest["GitRef"] == git_ref
    assert app_manifest["ReleaseTag"] == release_tag
    assert app_manifest["Repository"] == "joes021/vhs-mp4-optimizer"
    assert app_manifest["LatestReleaseApi"].endswith("/releases/latest")
