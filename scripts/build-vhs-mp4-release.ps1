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

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if ([string]::IsNullOrWhiteSpace($ReleaseRoot)) {
    $ReleaseRoot = Join-Path $projectRoot "release\VHS MP4 Optimizer"
}

if ([string]::IsNullOrWhiteSpace($GitRef)) {
    $GitRef = Get-GitValue -Arguments @("rev-parse", "--short", "HEAD")
}
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = (Get-Date -Format "yyyy.MM.dd") + "-" + $GitRef
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
$null = New-Item -ItemType Directory -Path $scriptsDir -Force
$null = New-Item -ItemType Directory -Path $assetsDir -Force

$scriptFiles = @(
    "optimize-vhs-mp4-core.psm1",
    "optimize-vhs-mp4-gui.ps1",
    "optimize-vhs-mp4.ps1",
    "optimize-vhs-mp4-gui.bat",
    "install-vhs-mp4-shortcut.ps1"
)

foreach ($scriptFile in $scriptFiles) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $scriptFile) -Destination (Join-Path $scriptsDir $scriptFile) -Force
}

Copy-Item -LiteralPath (Join-Path $projectRoot "assets\vhs-mp4-optimizer.ico") -Destination (Join-Path $assetsDir "vhs-mp4-optimizer.ico") -Force

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
call "%~dp0scripts\optimize-vhs-mp4-gui.bat"
endlocal
"@
Set-Content -LiteralPath (Join-Path $releaseRootFull "VHS MP4 Optimizer.bat") -Value $launcher -Encoding UTF8

$shortcutLauncher = @"
@echo off
setlocal
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0scripts\install-vhs-mp4-shortcut.ps1"
pause
endlocal
"@
Set-Content -LiteralPath (Join-Path $releaseRootFull "Install Desktop Shortcut.bat") -Value $shortcutLauncher -Encoding UTF8

$readme = @"
Video Converter / VHS MP4 Optimizer
===================================

Ovaj folder mozes da kopiras na drugi Windows racunar i da pokrenes alat bez ostatka projekta.

Brzi start:
1. Pokreni "VHS MP4 Optimizer.bat".
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
12. Pogledaj "Media info" kolone i "Properties" panel za format, kontejner, rezoluciju, odnos stranica, FPS, frames, protok, audio i trajanje.
13. Ako treba ozbiljniji pregled ili trim, izaberi fajl i klikni "Open Player" ili ga otvori duplim klikom.
14. U prozoru "Player / Trim":
   - "Playback mode" radi za moderne fajlove kao .mp4, .mov i .mkv.
   - "Preview mode" je fallback za .avi, MSDV i .mpg, ili kad playback ne moze da se otvori.
   - "Play / Pause", timeline i Frame dugmad sluze za precizno pomeranje kroz video.
   - "Set Start", "Set End", "Add Segment", "Remove" i "Clear Seg" rade trim unutar posebnog prozora.
   - "Aspect / Pixel shape" deo drzi lokalni "Aspect mode" za izabrani fajl.
   - U "Aspect mode" imas "Auto", "Keep Original", "Force 4:3" i "Force 16:9".
   - Linija "Detected: ... -> ..." pokazuje sta je alat procitao i na koju geometriju planira izlaz.
   - Linija sa "DAR", "SAR" i "Planned output aspect" pomaze da odmah proveris da li je slika pravilno protumacena.
   - "Crop / Overscan" deo sluzi da skines crne ivice i VHS overscan bez izlaska iz istog prozora.
   - "Detect Crop" predlaze crop, "Auto Crop" odmah prihvata auto rezultat, a "Clear Crop" vraca stanje na bez crop-a.
   - Polja "Left", "Top", "Right" i "Bottom" sluze za rucnu pixel korekciju po strani.
   - "Crop overlay" preko preview slike pokazuje aktivnu crop zonu dok proveravas kadar.
   - "Save to Queue" vraca trim izmene nazad u glavni batch.
15. Ako treba brzi pregled ili sitna korekcija bez otvaranja posebnog prozora, koristi "Preview / Properties" panel:
   - "Trim selected file" je pri vrhu desnog panela.
   - "Preview Frame" pravi jednu sliku iz videa na zadatom vremenu.
   - "Auto preview" sam osvezava frame dok pomeras timeline ili ides frame po frame; iskljuci ga za spore fajlove.
   - "Open Video" otvara originalni fajl u Windows player-u.
   - "Start" i "End" primaju HH:MM:SS, MM:SS ili sekunde.
   - "Apply Trim" cuva jedan trim ili menja izabrani segment.
   - "Add Segment" dodaje jos jedan keep range za isti fajl.
   - "Remove" brise trenutno izabrani segment, a "Clear Seg" prazni multi-cut listu.
   - "Clear Trim" brise sve trim podatke za izabrani fajl.
   - Crop overlay i kolone "Range" / "Crop" pokazuju koji fajlovi imaju trim i da li je crop Auto ili Manual.
16. Ako snimak treba tehnicki popraviti, klikni "Show Advanced" pa koristi "Video filters":
   - "Deinterlace" za nazubljene linije kod VHS/DVD interlaced snimaka.
   - "Denoise" za blago smanjenje suma.
   - "Rotate/flip" za pogresno okrenute snimke.
   - "Scale" za izlaz na PAL 576p, 720p ili 1080p.
   - "Audio normalize" za tise ili neujednacene snimke.
   - "Auto apply crop if detected" automatski primenjuje detektovan crop pri Start Conversion ako fajl nema rucni crop.
17. Klikni "Test Sample" za probni MP4 od 120 sekundi.
18. Ako je USB FAT32 ili fajl moze biti veci od 4 GB, ukljuci "Split output" i ostavi 3.8 GB.
19. Klikni "Start Conversion".
20. Donji workspace ima tabove "Status", "Progress" i "Log", tako da pratnja batch-a ne smanjuje preview prostor.
21. "Pause" zavrsava trenutni fajl i onda staje pre sledeceg.
22. Kada batch udje u "Paused", mozes da kliknes "Resume", da menjas Workflow preset i ostala opsta batch podesavanja, kao i da koristis "Move Up" / "Move Down" za queued redosled.
23. Posle obrade prebaci gotove MP4 fajlove, IZVESTAJ.txt i po potrebi USB PREDAJA CHECKLIST.txt.
24. U meniju "Help" imas "About VHS MP4 Optimizer", "Check for Updates" i "Open User Guide".
25. Ako je dostupan noviji GitHub release, program moze da te pita da li hoces update pre preuzimanja.

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
- Open Player cuva izmene tek kada kliknes Save to Queue.
- Playback mode i Preview mode koriste isti trim rezultat u glavnom queue-u.
- Pause / Resume radi samo nad preostalim queued fajlovima; vec gotovi fajlovi ostaju gotovi.
- "Paused after current file" pokazuje da je zahtev za pauzu primljen, a "Paused" da batch ceka Resume.
- "Move Up" i "Move Down" pomeraju samo queued stavke, da mozes da prepakujes ostatak reda.
- Quick Setup cuva svakodnevni batch tok cistim, a Show Advanced otkriva dublja podesavanja samo kada ti zatrebaju.
- Status, Progress i Log tabovi dole oslobadjaju vise vertikalnog prostora za grid i preview.
- Aspect / Pixel shape koristi lokalni Aspect mode po fajlu; Auto, Keep Original, Force 4:3 i Force 16:9 pomazu kad PAL/DV ili NTSC/DV snimak izgleda stisnuto ili razvuceno.
- Detected, DAR, SAR i Planned output aspect daju brz tehnicki pregled pre Save to Queue.
- Video filters su podrazumevano iskljuceni; prvo probaj Test Sample za vazne snimke.
- Help -> About pokazuje Current version, Release tag, Install type, Install path i GitHub repo.
- Help -> Check for Updates proverava poslednji GitHub release i pita pre download/install toka.
"@
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
Set-Content -LiteralPath (Join-Path $releaseRootFull "USB PREDAJA CHECKLIST.txt") -Value $checklist -Encoding UTF8

Write-Host "Release folder: $releaseRootFull"
