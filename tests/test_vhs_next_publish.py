from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_mock_command(bin_dir: Path, name: str, script_body: str) -> None:
    ps1_path = bin_dir / f"{name}-mock.ps1"
    cmd_path = bin_dir / f"{name}.cmd"
    ps1_path.write_text(script_body, encoding="utf-8")
    cmd_path.write_text(
        "@echo off\r\n"
        f"powershell -NoProfile -ExecutionPolicy Bypass -File \"%~dp0{name}-mock.ps1\" %*\r\n"
        "exit /b %ERRORLEVEL%\r\n",
        encoding="ascii",
    )


def test_vhs_next_publish_tokens_exist() -> None:
    publish_script = read(ROOT / "scripts" / "publish-vhs-mp4-next-github-release.ps1")

    for token in [
        "installer-manifest.json",
        "gh release view",
        "gh release create",
        "gh release upload",
        "vhs-mp4-optimizer-next-",
        "VHS MP4 Optimizer Next",
    ]:
        assert token in publish_script, f"missing next publish token: {token}"


def test_vhs_next_publish_can_create_release_when_missing(tmp_path: Path) -> None:
    output_root = tmp_path / "dist"
    output_root.mkdir(parents=True)
    portable_zip = output_root / "VHS-MP4-Optimizer-Next-portable-1.1.0-test.zip"
    setup_exe = output_root / "VHS-MP4-Optimizer-Next-Setup-1.1.0-test.exe"
    portable_zip.write_bytes(b"zip")
    setup_exe.write_bytes(b"exe")

    manifest = {
        "Version": "1.1.0-test",
        "GitRef": "abc1234",
        "ReleaseTag": "vhs-mp4-optimizer-next-1.1.0-test",
        "Repository": "joes021/vhs-mp4-optimizer",
        "Branch": "codex/avalonia-migration",
        "PortableZipPath": str(portable_zip),
        "PortableZipExists": True,
        "SetupExePath": str(setup_exe),
        "SetupBuilt": True,
    }
    (output_root / "installer-manifest.json").write_text(json.dumps(manifest), encoding="utf-8")

    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    gh_log = tmp_path / "gh.log"
    git_log = tmp_path / "git.log"

    write_mock_command(
        bin_dir,
        "gh",
        """
$logPath = $env:GH_MOCK_LOG
$argsText = ($args -join ' ')
Add-Content -LiteralPath $logPath -Value $argsText
if ($args.Length -ge 3 -and $args[0] -eq 'release' -and $args[1] -eq 'view') { exit 1 }
exit 0
""".strip(),
    )
    write_mock_command(
        bin_dir,
        "git",
        """
$logPath = $env:GIT_MOCK_LOG
$argsText = ($args -join ' ')
Add-Content -LiteralPath $logPath -Value $argsText
if ($args.Length -ge 1 -and $args[0] -eq 'show-ref') { exit 1 }
exit 0
""".strip(),
    )

    env = os.environ.copy()
    env["PATH"] = str(bin_dir) + os.pathsep + env["PATH"]
    env["GH_MOCK_LOG"] = str(gh_log)
    env["GIT_MOCK_LOG"] = str(git_log)

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(ROOT / "scripts" / "publish-vhs-mp4-next-github-release.ps1"),
            "-OutputRoot",
            str(output_root),
        ],
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=180,
    )

    assert run.returncode == 0, run.stderr
    gh_lines = gh_log.read_text(encoding="utf-8").splitlines()
    git_lines = git_log.read_text(encoding="utf-8").splitlines() if git_log.exists() else []
    assert any(line.startswith("release view vhs-mp4-optimizer-next-1.1.0-test") for line in gh_lines)
    assert any(line.startswith("release create vhs-mp4-optimizer-next-1.1.0-test") for line in gh_lines)
    assert any("VHS-MP4-Optimizer-Next-portable-1.1.0-test.zip" in line for line in gh_lines)
    assert any("VHS-MP4-Optimizer-Next-Setup-1.1.0-test.exe" in line for line in gh_lines)
    assert any(line.startswith("show-ref --verify --quiet refs/tags/vhs-mp4-optimizer-next-1.1.0-test") for line in git_lines)
    assert any(line.startswith("tag vhs-mp4-optimizer-next-1.1.0-test") for line in git_lines)
    assert any(line.startswith("push origin refs/tags/vhs-mp4-optimizer-next-1.1.0-test") for line in git_lines)


def test_vhs_next_publish_can_upload_assets_to_existing_release(tmp_path: Path) -> None:
    output_root = tmp_path / "dist"
    output_root.mkdir(parents=True)
    portable_zip = output_root / "VHS-MP4-Optimizer-Next-portable-1.1.0-test.zip"
    setup_exe = output_root / "VHS-MP4-Optimizer-Next-Setup-1.1.0-test.exe"
    portable_zip.write_bytes(b"zip")
    setup_exe.write_bytes(b"exe")

    manifest = {
        "Version": "1.1.0-test",
        "GitRef": "abc1234",
        "ReleaseTag": "vhs-mp4-optimizer-next-1.1.0-test",
        "Repository": "joes021/vhs-mp4-optimizer",
        "Branch": "codex/avalonia-migration",
        "PortableZipPath": str(portable_zip),
        "PortableZipExists": True,
        "SetupExePath": str(setup_exe),
        "SetupBuilt": True,
    }
    (output_root / "installer-manifest.json").write_text(json.dumps(manifest), encoding="utf-8")

    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    gh_log = tmp_path / "gh.log"
    git_log = tmp_path / "git.log"

    write_mock_command(
        bin_dir,
        "gh",
        """
$logPath = $env:GH_MOCK_LOG
$argsText = ($args -join ' ')
Add-Content -LiteralPath $logPath -Value $argsText
exit 0
""".strip(),
    )
    write_mock_command(
        bin_dir,
        "git",
        """
$logPath = $env:GIT_MOCK_LOG
$argsText = ($args -join ' ')
Add-Content -LiteralPath $logPath -Value $argsText
exit 0
""".strip(),
    )

    env = os.environ.copy()
    env["PATH"] = str(bin_dir) + os.pathsep + env["PATH"]
    env["GH_MOCK_LOG"] = str(gh_log)
    env["GIT_MOCK_LOG"] = str(git_log)

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(ROOT / "scripts" / "publish-vhs-mp4-next-github-release.ps1"),
            "-OutputRoot",
            str(output_root),
        ],
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=180,
    )

    assert run.returncode == 0, run.stderr
    gh_lines = gh_log.read_text(encoding="utf-8").splitlines()
    git_lines = git_log.read_text(encoding="utf-8").splitlines() if git_log.exists() else []
    assert any(line.startswith("release view vhs-mp4-optimizer-next-1.1.0-test") for line in gh_lines)
    assert any(line.startswith("release upload vhs-mp4-optimizer-next-1.1.0-test") for line in gh_lines)
    assert any(line.startswith("release edit vhs-mp4-optimizer-next-1.1.0-test") for line in gh_lines)
    assert git_lines == []
