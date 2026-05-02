import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RELEASE_ROOT = ROOT / "release" / "VHS MP4 Optimizer"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_vhs_release_folder_is_copyable_and_self_contained() -> None:
    expected_files = [
        RELEASE_ROOT / "VHS MP4 Optimizer.bat",
        RELEASE_ROOT / "VHS MP4 Optimizer.vbs",
        RELEASE_ROOT / "Install Desktop Shortcut.bat",
        RELEASE_ROOT / "README - kako se koristi.txt",
        RELEASE_ROOT / "USB PREDAJA CHECKLIST.txt",
        RELEASE_ROOT / "app-manifest.json",
        RELEASE_ROOT / "docs" / "VHS_MP4_OPTIMIZER_UPUTSTVO.html",
        RELEASE_ROOT / "docs" / "media" / "readme-main-overview.png",
        RELEASE_ROOT / "docs" / "media" / "readme-player-trim.png",
        RELEASE_ROOT / "docs" / "media" / "readme-batch-controls.png",
        RELEASE_ROOT / "scripts" / "optimize-vhs-mp4-core.psm1",
        RELEASE_ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1",
        RELEASE_ROOT / "scripts" / "optimize-vhs-mp4.ps1",
        RELEASE_ROOT / "scripts" / "optimize-vhs-mp4-gui.bat",
        RELEASE_ROOT / "scripts" / "optimize-vhs-mp4-gui.vbs",
        RELEASE_ROOT / "scripts" / "install-vhs-mp4-shortcut.ps1",
        RELEASE_ROOT / "assets" / "vhs-mp4-optimizer.ico",
    ]

    for file_path in expected_files:
        assert file_path.exists(), f"missing release file: {file_path}"

    launcher = read(RELEASE_ROOT / "VHS MP4 Optimizer.bat")
    assert "wscript.exe" in launcher
    assert "VHS MP4 Optimizer.vbs" in launcher
    assert "C:\\Users" not in launcher

    hidden_launcher = read(RELEASE_ROOT / "VHS MP4 Optimizer.vbs")
    assert "WScript.Shell" in hidden_launcher
    assert "optimize-vhs-mp4-gui.ps1" in hidden_launcher

    shortcut_launcher = read(RELEASE_ROOT / "Install Desktop Shortcut.bat")
    assert "scripts\\install-vhs-mp4-shortcut.ps1" in shortcut_launcher
    assert "ExecutionPolicy RemoteSigned" in shortcut_launcher

    readme = read(RELEASE_ROOT / "README - kako se koristi.txt")
    for token in [
        "Video Converter",
        "VHS MP4 Optimizer",
        "Help",
        "About VHS MP4 Optimizer",
        "Check for Updates",
        "Open User Guide",
        "Install FFmpeg",
        "Test Sample",
        "Start Conversion",
        "Universal MP4 H.264",
        "Small MP4 H.264",
        "High Quality MP4 H.264",
        "HEVC H.265 Smaller",
        "Media info",
        "Properties",
        "Preview Frame",
        "Auto preview",
        "Open Video",
        "Open Player",
        "Player / Trim",
        "Save to Queue",
        "Pause",
        "Resume",
        "Queue",
        "Skip Selected",
        "Retry Failed",
        "Clear Completed",
        "Save Queue",
        "Load Queue",
        "Move Up",
        "Move Down",
        "Paused after current file",
        "Encode engine",
        "CPU (libx264/libx265)",
        "NVIDIA NVENC",
        "Intel QSV",
        "AMD AMF",
        "Playback mode",
        "Preview mode",
        "Aspect / Pixel shape",
        "Aspect mode",
        "Keep Original",
        "Force 4:3",
        "Force 16:9",
        "Crop / Overscan",
        "Detect Crop",
        "Auto Crop",
        "Clear Crop",
        "Auto apply crop if detected",
        "Crop overlay",
        "Left",
        "Top",
        "Right",
        "Bottom",
        "Workflow preset",
        "Save Preset",
        "Delete Preset",
        "Import Preset",
        "Export Preset",
        "USB standard",
        "Mali fajl",
        "High quality arhiva",
        "HEVC manji fajl",
        "VHS cleanup",
        "Custom",
        "Start",
        "End",
        "Apply Trim",
        "Cut Segment",
        "Remove",
        "Clear Cuts",
        "Clear Trim",
        "trim",
        "Video filters",
        "Deinterlace",
        "Denoise",
        "Rotate/flip",
        "Scale",
        "PAL 576p",
        "Audio normalize",
        "format, kontejner, rezoluciju",
        ".mov",
        ".mkv",
        ".wmv",
        ".m2ts",
        ".vob",
        "IZVESTAJ.txt",
        "USB PREDAJA CHECKLIST.txt",
        "Originalni fajlovi se ne menjaju",
    ]:
        assert token in readme, f"missing README token: {token}"

    app_manifest = json.loads(read(RELEASE_ROOT / "app-manifest.json"))
    assert app_manifest["AppName"] == "VHS MP4 Optimizer"
    assert app_manifest["Repository"] == "joes021/vhs-mp4-optimizer"
    assert app_manifest["LatestReleaseApi"].endswith("/releases/latest")
    assert "Version" in app_manifest
    assert "ReleaseTag" in app_manifest

    checklist = read(RELEASE_ROOT / "USB PREDAJA CHECKLIST.txt")
    for token in [
        "USB PREDAJA CHECKLIST",
        "exFAT",
        "FAT32",
        "3.8 GB",
        "IZVESTAJ.txt",
    ]:
        assert token in checklist, f"missing checklist token: {token}"


def test_vhs_release_launchers_are_written_without_utf8_bom() -> None:
    for launcher_path in [
        RELEASE_ROOT / "VHS MP4 Optimizer.vbs",
        RELEASE_ROOT / "VHS MP4 Optimizer.bat",
        RELEASE_ROOT / "Install Desktop Shortcut.bat",
    ]:
        data = launcher_path.read_bytes()
        assert not data.startswith(b"\xef\xbb\xbf"), f"launcher should not have UTF-8 BOM: {launcher_path}"


def test_vhs_release_builder_documents_all_packaged_files() -> None:
    builder = read(ROOT / "scripts" / "build-vhs-mp4-release.ps1")

    for token in [
        "release\\VHS MP4 Optimizer",
        "Video Converter",
        "README - kako se koristi.txt",
        "USB PREDAJA CHECKLIST.txt",
        "VHS MP4 Optimizer.bat",
        "Install Desktop Shortcut.bat",
        "optimize-vhs-mp4-gui.ps1",
        "install-vhs-mp4-shortcut.ps1",
        "vhs-mp4-optimizer.ico",
        "Copy-Item",
        "Remove-Item",
        "Preview Frame",
        "Auto preview",
        "Open Player",
        "Player / Trim",
        "Save to Queue",
        "Pause",
        "Resume",
        "Queue",
        "Skip Selected",
        "Retry Failed",
        "Clear Completed",
        "Save Queue",
        "Load Queue",
        "Move Up",
        "Move Down",
        "Paused after current file",
        "Encode engine",
        "CPU (libx264/libx265)",
        "NVIDIA NVENC",
        "Intel QSV",
        "AMD AMF",
        "Playback mode",
        "Preview mode",
        "Aspect / Pixel shape",
        "Aspect mode",
        "Keep Original",
        "Force 4:3",
        "Force 16:9",
        "Crop / Overscan",
        "Detect Crop",
        "Auto Crop",
        "Clear Crop",
        "Auto apply crop if detected",
        "Crop overlay",
        "Left",
        "Top",
        "Right",
        "Bottom",
        "Workflow preset",
        "Save Preset",
        "Delete Preset",
        "Import Preset",
        "Export Preset",
        "USB standard",
        "VHS cleanup",
        "Custom",
        "Apply Trim",
        "Cut Segment",
        "Clear Cuts",
        "Video filters",
        "Audio normalize",
    ]:
        assert token in builder, f"missing release builder token: {token}"


def test_vhs_docs_and_release_scripts_cover_aspect_workflow() -> None:
    guide = read(ROOT / "docs" / "VHS_MP4_OPTIMIZER_UPUTSTVO.md")
    for token in [
        "Aspect / Pixel shape",
        "Aspect mode",
        "Auto",
        "Keep Original",
        "Force 4:3",
        "Force 16:9",
        "DAR",
        "SAR",
        "Planned output aspect",
        "Pause",
        "Resume",
        "Queue",
        "Skip Selected",
        "Retry Failed",
        "Clear Completed",
        "Save Queue",
        "Load Queue",
        "Move Up",
        "Move Down",
        "Encode engine",
        "Intel QSV",
    ]:
        assert token in guide, f"missing guide token: {token}"

    packaged_gui = read(RELEASE_ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1")
    for token in [
        "Aspect / Pixel shape",
        "playerAspectModeComboBox",
        "Keep Original",
        "Force 4:3",
        "Force 16:9",
    ]:
        assert token in packaged_gui, f"missing packaged GUI token: {token}"

    packaged_core = read(RELEASE_ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    for token in [
        "Get-VhsMp4AspectState",
        "Get-VhsMp4AspectSnapshot",
    ]:
        assert token in packaged_core, f"missing packaged core token: {token}"


def test_vhs_html_user_guide_is_rich_and_packaged() -> None:
    html_guide = read(ROOT / "docs" / "VHS_MP4_OPTIMIZER_UPUTSTVO.html")
    packaged_html_guide = read(RELEASE_ROOT / "docs" / "VHS_MP4_OPTIMIZER_UPUTSTVO.html")

    for token in [
        "<!DOCTYPE html>",
        "<nav",
        "Brzi start",
        "Workflow preset",
        "Player / Trim",
        "Queue alati",
        "Encode engine",
        "Help / About / Update",
        "readme-main-overview.png",
        "readme-player-trim.png",
        "readme-batch-controls.png",
        "#brzi-start",
        "#player-trim",
        "#queue-alati",
    ]:
        assert token in html_guide, f"missing HTML guide token: {token}"
        assert token in packaged_html_guide, f"missing packaged HTML guide token: {token}"
