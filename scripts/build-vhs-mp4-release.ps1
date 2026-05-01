[CmdletBinding()]
param(
    [string]$ReleaseRoot,
    [string]$Version,
    [string]$GitRef,
    [string]$ReleaseTag,
    [string]$Repository = "joes021/vhs-mp4-optimizer"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-GitValue {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [string]$Fallback = "unknown"
    )

    try {
        $result = & git @Arguments 2>$null
        if ($LASTEXITCODE -ne 0) {
            return $Fallback
        }

        $text = [string]($result | Select-Object -First 1)
        if ([string]::IsNullOrWhiteSpace($text)) {
            return $Fallback
        }

        return $text.Trim()
    }
    catch {
        return $Fallback
    }
}

function Get-ProjectVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $versionPath = Join-Path $ProjectRoot "version.json"
    if (-not (Test-Path -LiteralPath $versionPath)) {
        throw "version.json nije pronadjen u root-u projekta: $versionPath"
    }

    $parsed = Get-Content -LiteralPath $versionPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    $version = [string]$parsed.Version
    if ([string]::IsNullOrWhiteSpace($version) -or $version -notmatch '^\d+\.\d+\.\d+$') {
        throw "version.json mora imati Version u formatu a.b.c"
    }

    return $version
}

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if ([string]::IsNullOrWhiteSpace($ReleaseRoot)) {
    $ReleaseRoot = Join-Path $projectRoot "release\VHS MP4 Optimizer"
}

if ([string]::IsNullOrWhiteSpace($GitRef)) {
    $GitRef = Get-GitValue -Arguments @("rev-parse", "--short", "HEAD")
}
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Get-ProjectVersion -ProjectRoot $projectRoot
}
if ([string]::IsNullOrWhiteSpace($ReleaseTag)) {
    $ReleaseTag = "vhs-mp4-optimizer-" + $Version
}

$releaseRootFull = [System.IO.Path]::GetFullPath($ReleaseRoot)
$releaseParentFull = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "release"))
if (-not $releaseRootFull.StartsWith($releaseParentFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "ReleaseRoot mora biti unutar release foldera: $releaseParentFull"
}

if (Test-Path -LiteralPath $releaseRootFull) {
    try {
        Remove-Item -LiteralPath $releaseRootFull -Recurse -Force
    }
    catch {
        Write-Warning "Release folder je trenutno otvoren ili zakljucan. Postojeci poznati fajlovi bice osvezeni na mestu."
    }
}

$scriptsDir = Join-Path $releaseRootFull "scripts"
$assetsDir = Join-Path $releaseRootFull "assets"
$docsDir = Join-Path $releaseRootFull "docs"
$docsMediaDir = Join-Path $docsDir "media"
$null = New-Item -ItemType Directory -Path $scriptsDir -Force
$null = New-Item -ItemType Directory -Path $assetsDir -Force
$null = New-Item -ItemType Directory -Path $docsMediaDir -Force

$scriptFiles = @(
    "optimize-vhs-mp4-core.psm1",
    "optimize-vhs-mp4-gui.ps1",
    "optimize-vhs-mp4.ps1",
    "optimize-vhs-mp4-gui.bat",
    "optimize-vhs-mp4-gui.vbs",
    "install-vhs-mp4-shortcut.ps1"
)

foreach ($scriptFile in $scriptFiles) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $scriptFile) -Destination (Join-Path $scriptsDir $scriptFile) -Force
}

Copy-Item -LiteralPath (Join-Path $projectRoot "assets\vhs-mp4-optimizer.ico") -Destination (Join-Path $assetsDir "vhs-mp4-optimizer.ico") -Force
Copy-Item -LiteralPath (Join-Path $projectRoot "docs\VHS_MP4_OPTIMIZER_UPUTSTVO.md") -Destination (Join-Path $docsDir "VHS_MP4_OPTIMIZER_UPUTSTVO.md") -Force
Copy-Item -LiteralPath (Join-Path $projectRoot "docs\VHS_MP4_OPTIMIZER_UPUTSTVO.html") -Destination (Join-Path $docsDir "VHS_MP4_OPTIMIZER_UPUTSTVO.html") -Force
foreach ($mediaName in @("readme-main-overview.png", "readme-player-trim.png", "readme-batch-controls.png")) {
    Copy-Item -LiteralPath (Join-Path $projectRoot ("docs\media\" + $mediaName)) -Destination (Join-Path $docsMediaDir $mediaName) -Force
}

$releaseApiUrl = "https://api.github.com/repos/$Repository/releases/latest"
$releasesPageUrl = "https://github.com/$Repository/releases"
$appManifest = [pscustomobject]@{
    AppName = "VHS MP4 Optimizer"
    Version = $Version
    GitRef = $GitRef
    ReleaseTag = $ReleaseTag
    Repository = $Repository
    LatestReleaseApi = $releaseApiUrl
    ReleasesPage = $releasesPageUrl
    BuiltAtUtc = (Get-Date).ToUniversalTime().ToString("o")
}
$appManifestPath = Join-Path $releaseRootFull "app-manifest.json"
$appManifestJson = $appManifest | ConvertTo-Json -Depth 5
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($appManifestPath, $appManifestJson, $utf8NoBom)

$launcher = @"
@echo off
setlocal
wscript.exe "%~dp0VHS MP4 Optimizer.vbs"
endlocal
"@
[string]$launcher = $launcher.TrimStart([char]0xFEFF)
[System.IO.File]::WriteAllText((Join-Path $releaseRootFull "VHS MP4 Optimizer.bat"), $launcher, $utf8NoBom)

$hiddenLauncher = @"
Option Explicit

Dim shell
Dim fileSystem
Dim rootDir
Dim command

Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

rootDir = fileSystem.GetParentFolderName(WScript.ScriptFullName)
shell.CurrentDirectory = rootDir

command = "powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -WindowStyle Hidden -File " & Chr(34) & rootDir & "\scripts\optimize-vhs-mp4-gui.ps1" & Chr(34)
shell.Run command, 0, False
"@
[string]$hiddenLauncher = $hiddenLauncher.TrimStart([char]0xFEFF)
[System.IO.File]::WriteAllText((Join-Path $releaseRootFull "VHS MP4 Optimizer.vbs"), $hiddenLauncher, $utf8NoBom)

$shortcutLauncher = @"
@echo off
setlocal
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0scripts\install-vhs-mp4-shortcut.ps1"
pause
endlocal
"@
[string]$shortcutLauncher = $shortcutLauncher.TrimStart([char]0xFEFF)
[System.IO.File]::WriteAllText((Join-Path $releaseRootFull "Install Desktop Shortcut.bat"), $shortcutLauncher, $utf8NoBom)

$readme = @"
Video Converter / VHS MP4 Optimizer
===================================

Ovaj folder mozes da kopiras na drugi Windows racunar i da pokrenes alat bez ostatka projekta.

Brzi start:
1. Pokreni "VHS MP4 Optimizer.vbs" (ili "VHS MP4 Optimizer.bat" kao fallback launcher).
2. Ako FFmpeg nije spreman, klikni "Install FFmpeg" ili rucno izaberi ffmpeg.exe.
3. Izaberi Input folder sa video fajlovima: .mp4, .avi, .mpg, .mpeg, .mov, .mkv, .m4v, .wmv, .ts, .m2ts ili .vob. Scan Files pregleda i podfoldere.
4. Ako ti je lakse, prevuci folder ili direktne video fajlove pravo u prozor programa.
5. Dok vuces fajlove preko prozora, program se oboji zeleno i prikaze drop poruku da bude jasno gde hvata.
6. Klikni "Scan Files" kada radis iz foldera ili proveri listu koju je drag & drop odmah ucitao.
7. Gornji deo prozora je sada podeljen na "Source / Output / FFmpeg", "Quick Setup" i skriveni "Advanced Settings".
8. U "Quick Setup" odradjujes svakodnevni batch tok, a "Show Advanced" ukljucujes samo kad ti trebaju detaljni parametri.
9. Izaberi "Workflow preset" ako zelis da odmah ucitas gotova opsta batch podesavanja:
   - USB standard za najprakticniju USB predaju.
   - Mali fajl kada juris sto manju velicinu.
   - High quality arhiva kada je bitniji kvalitet i arhiva.
   - HEVC manji fajl kada zelis manji fajl uz H.265.
   - VHS cleanup kada hoces deinterlace, denoise, audio normalize i Auto apply crop if detected za tipican VHS materijal.
   - Ako posle rucno menjas opsta polja, stanje prelazi u Custom.
10. Po potrebi koristi "Save Preset", "Delete Preset", "Import Preset" i "Export Preset" za sopstvene profile.
11. Ako ne koristis workflow preset ili hoces da ga proveris, izaberi profil:
   - Universal MP4 H.264 za najkompatibilniju predaju musteriji.
   - Small MP4 H.264 za manji fajl.
   - High Quality MP4 H.264 za vazne snimke.
   - HEVC H.265 Smaller za jos manji fajl uz noviji H.265 kodek.
12. Pogledaj "Media info" kolone i "Properties" panel na glavnom batch ekranu za format, kontejner, rezoluciju, odnos stranica, FPS, frames, protok, audio i trajanje.
13. Ako treba ozbiljniji pregled ili trim, izaberi fajl i klikni "Open Player" ili ga otvori duplim klikom.
14. U prozoru "Player / Trim":
   - "Playback mode" radi za moderne fajlove kao .mp4, .mov i .mkv.
   - "Preview mode" je fallback za .avi, MSDV i .mpg, ili kad playback ne moze da se otvori.
   - "Preview Frame", "Auto preview", "Open Video", "Play / Pause", timeline i Frame dugmad sluze za precizno pomeranje kroz video.
   - veliki preview je levo, timeline je ispod preview-a, a trim/crop/aspect/properties alati su u desnoj koloni.
   - "Set Start", "Set End", "Apply Trim", "Add Segment", "Remove", "Clear Seg" i "Clear Trim" rade trim unutar posebnog prozora.
   - "Start", "End" i "CUT" oznake ostaju stalno vidljive iznad trim sekcije.
   - "Aspect / Pixel shape" deo drzi lokalni "Aspect mode" za izabrani fajl.
   - U "Aspect mode" imas "Auto", "Keep Original", "Force 4:3" i "Force 16:9".
   - Linija "Detected: ... -> ..." pokazuje sta je alat procitao i na koju geometriju planira izlaz.
   - Linija sa "DAR", "SAR" i "Planned output aspect" pomaze da odmah proveris da li je slika pravilno protumacena.
   - "Crop / Overscan" deo sluzi da skines crne ivice i VHS overscan bez izlaska iz istog prozora.
   - "Detect Crop" predlaze crop, "Auto Crop" odmah prihvata auto rezultat, a "Clear Crop" vraca stanje na bez crop-a.
   - Polja "Left", "Top", "Right" i "Bottom" sluze za rucnu pixel korekciju po strani.
   - "Crop overlay" preko preview slike pokazuje aktivnu crop zonu dok proveravas kadar.
   - "Save to Queue" vraca trim izmene nazad u glavni batch.
15. Glavni batch ekran ostaje cist i fokusiran na queue:
   - prikazuje folder putanje, preset-e, batch akcije, queue tabelu i "Properties" pregled
   - ne drzi stalno otvoren preview/trimming panel
   - kolone "Range", "Crop" i "Aspect" i dalje pokazuju sta je vec podeseno za svaki fajl
16. Ako snimak treba tehnicki popraviti, klikni "Show Advanced" pa koristi "Video filters":
   - "Deinterlace" za nazubljene linije kod VHS/DVD interlaced snimaka.
   - "Denoise" za blago smanjenje suma.
   - "Rotate/flip" za pogresno okrenute snimke.
   - "Scale" za izlaz na PAL 576p, 720p ili 1080p.
   - "Audio normalize" za tise ili neujednacene snimke.
   - "Auto apply crop if detected" automatski primenjuje detektovan crop pri Start Conversion ako fajl nema rucni crop.
17. U istom "Advanced Settings" delu imas i "Encode engine":
   - "Auto" za provereni CPU tok.
   - "CPU (libx264/libx265)" kada hoces najpredvidljiviji kvalitet i kompatibilnost.
   - "NVIDIA NVENC", "Intel QSV" i "AMD AMF" kada ih FFmpeg i masina stvarno podrzavaju.
   - Ako hardware init padne, alat bezbedno pada nazad na CPU umesto da prekine batch.
18. Klikni "Test Sample" za probni MP4 od 120 sekundi.
19. Ako je USB FAT32 ili fajl moze biti veci od 4 GB, ukljuci "Split output" i ostavi 3.8 GB.
20. Klikni "Start Conversion".
21. Donji workspace ima tabove "Status", "Progress" i "Log", tako da pratnja batch-a ne smanjuje preview prostor.
22. "Pause" zavrsava trenutni fajl i onda staje pre sledeceg.
23. Kada batch udje u "Paused", mozes da kliknes "Resume", da menjas Workflow preset i ostala opsta batch podesavanja, kao i da koristis "Move Up" / "Move Down" za queued redosled.
24. "Queue" meni i batch dugmad dodaju "Skip Selected", "Retry Failed", "Clear Completed", "Save Queue" i "Load Queue" bez izlaska iz glavnog ekrana.
25. Posle obrade prebaci gotove MP4 fajlove, IZVESTAJ.txt i po potrebi USB PREDAJA CHECKLIST.txt.
26. U meniju "Help" imas "About VHS MP4 Optimizer", "Check for Updates" i "Open User Guide".
27. Ako je dostupan noviji GitHub release, program moze da te pita da li hoces update pre preuzimanja.

Desktop precica:
- Pokreni "Install Desktop Shortcut.bat" ako zelis precicu "VHS MP4 Optimizer" na desktopu.

Napomene:
- Originalni fajlovi se ne menjaju.
- Gotovi fajlovi idu u output folder koji izaberes u programu.
- Za moderne USB memorije najprakticniji je exFAT.
- Stari profili Standard VHS, Smaller File, Better Quality i Custom ostaju dostupni za dosadasnji VHS tok rada.
- Workflow preset cuva samo opsta batch podesavanja, ukljucujuci Auto apply crop if detected, i ne dira trim, segmente, Input folder, Output folder ni FFmpeg path.
- Save Preset, Delete Preset, Import Preset i Export Preset rade nad korisnickim workflow profilima.
- Media info koristi ffprobe iz FFmpeg paketa i ne menja originalne fajlove.
- Preview Frame i trim ne menjaju original; trim se primenjuje samo na gotovu MP4 kopiju.
- Crop / Overscan radi po fajlu: Detect Crop i Auto Crop pune Left, Top, Right i Bottom, Clear Crop ih brise, a Crop overlay pomaze da proveris kadar pre Save to Queue.
- Auto apply crop if detected koristi auto crop pri batch obradi, ali ne gazi rucno unete crop vrednosti.
- Open Player otvara poseban floating editor; izmene se vracaju tek kada kliknes Save to Queue.
- Playback mode i Preview mode koriste isti trim rezultat u glavnom queue-u.
- Pause / Resume radi samo nad preostalim queued fajlovima; vec gotovi fajlovi ostaju gotovi.
- "Paused after current file" pokazuje da je zahtev za pauzu primljen, a "Paused" da batch ceka Resume.
- "Move Up" i "Move Down" pomeraju samo queued stavke, da mozes da prepakujes ostatak reda.
- "Queue" meni okuplja "Save Queue", "Load Queue", "Skip Selected", "Retry Failed" i "Clear Completed".
- Batch dugmad "Skip Selected", "Retry Failed" i "Clear Completed" daju isti tok bez otvaranja menija.
- Quick Setup cuva svakodnevni batch tok cistim, a Show Advanced otkriva dublja podesavanja samo kada ti zatrebaju.
- Status, Progress i Log tabovi dole oslobadjaju vise vertikalnog prostora za grid, dok preview zivi u posebnom Player / Trim prozoru.
- Aspect / Pixel shape koristi lokalni Aspect mode po fajlu; Auto, Keep Original, Force 4:3 i Force 16:9 pomazu kad PAL/DV ili NTSC/DV snimak izgleda stisnuto ili razvuceno.
- Detected, DAR, SAR i Planned output aspect daju brz tehnicki pregled pre Save to Queue.
- Encode engine daje "Auto", "CPU (libx264/libx265)", "NVIDIA NVENC", "Intel QSV" i "AMD AMF", uz siguran fallback na CPU ako hardware init ne prodje.
- Video filters su podrazumevano iskljuceni; prvo probaj Test Sample za vazne snimke.
- Help -> About pokazuje Current version, Release tag, Install type, Install path i GitHub repo.
- Help -> Check for Updates proverava poslednji GitHub release i pita pre download/install toka.
"@
$null = New-Item -ItemType Directory -Path $releaseRootFull -Force
Set-Content -LiteralPath (Join-Path $releaseRootFull "README - kako se koristi.txt") -Value $readme -Encoding UTF8

$checklist = @"
USB PREDAJA CHECKLIST
=====================

[ ] USB je formatiran kao exFAT ako ima fajlova vecih od 4 GB.
[ ] Ako musterija koristi FAT32 USB, ukljucen je Split output na oko 3.8 GB.
[ ] Gotovi MP4 fajlovi su kopirani na USB.
[ ] IZVESTAJ.txt je kopiran uz video fajlove.
[ ] Bar prvi minut svakog MP4 fajla je pusten i proveren.
[ ] Originalni veliki fajlovi ostaju kod tebe kao arhiva.
"@
$null = New-Item -ItemType Directory -Path $releaseRootFull -Force
Set-Content -LiteralPath (Join-Path $releaseRootFull "USB PREDAJA CHECKLIST.txt") -Value $checklist -Encoding UTF8

Write-Host "Release folder: $releaseRootFull"
