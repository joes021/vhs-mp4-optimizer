from pathlib import Path


def test_vhs_gui_launcher_targets_gui_script() -> None:
    launcher = Path("scripts/optimize-vhs-mp4-gui.bat").read_text(encoding="utf-8")
    hidden_launcher = Path("scripts/optimize-vhs-mp4-gui.vbs").read_text(encoding="utf-8")

    for token in [
        "wscript.exe",
        "optimize-vhs-mp4-gui.vbs",
    ]:
        assert token in launcher, f"missing launcher token: {token}"

    for token in [
        "WScript.Shell",
        "powershell.exe",
        "ExecutionPolicy RemoteSigned",
        "WindowStyle Hidden",
        "optimize-vhs-mp4-gui.ps1",
        "Run command, 0, False",
    ]:
        assert token in hidden_launcher, f"missing hidden launcher token: {token}"


def test_vhs_shortcut_installer_sets_custom_icon() -> None:
    installer = Path("scripts/install-vhs-mp4-shortcut.ps1").read_text(encoding="utf-8")

    for token in [
        "VHS MP4 Optimizer.lnk",
        "VHS MP4 Optimizer.vbs",
        "assets",
        "vhs-mp4-optimizer.ico",
        "IconLocation",
        "wscript.exe",
        "Arguments",
        "WScript.Shell",
    ]:
        assert token in installer, f"missing shortcut installer token: {token}"

    assert Path("assets/vhs-mp4-optimizer.ico").exists()
