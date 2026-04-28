from pathlib import Path


def test_vhs_gui_launcher_targets_gui_script() -> None:
    launcher = Path("scripts/optimize-vhs-mp4-gui.bat").read_text(encoding="utf-8")

    for token in [
        "powershell",
        "ExecutionPolicy Bypass",
        "optimize-vhs-mp4-gui.ps1",
    ]:
        assert token in launcher, f"missing launcher token: {token}"


def test_vhs_shortcut_installer_sets_custom_icon() -> None:
    installer = Path("scripts/install-vhs-mp4-shortcut.ps1").read_text(encoding="utf-8")

    for token in [
        "VHS MP4 Optimizer.lnk",
        "assets",
        "vhs-mp4-optimizer.ico",
        "IconLocation",
        "optimize-vhs-mp4-gui.bat",
        "WScript.Shell",
    ]:
        assert token in installer, f"missing shortcut installer token: {token}"

    assert Path("assets/vhs-mp4-optimizer.ico").exists()
