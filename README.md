# VHS MP4 Optimizer

Windows alat za batch konverziju, trim, preview i pakovanje video fajlova iz VHS, DVD, DV/MSDV i slicnih izvora.

## Sta sadrzi

- PowerShell/WinForms GUI za konverziju i pregled videa
- trim, multi-cut, crop/overscan i aspect korekciju po fajlu
- workflow preset-e za brzi rad
- release builder za portable paket
- installer builder za `Setup.exe`
- testove koji cuvaju release paket i GUI tok od regresija

## Podrzani ulazi

Najcesci ulazi su:

- `.mp4`
- `.avi`
- `.mpg` / `.mpeg`
- `.mov`
- `.mkv`
- `.wmv`
- `.ts`
- `.m2ts`
- `.vob`

## Brzi start

Za razvoj i lokalno pokretanje:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/optimize-vhs-mp4-gui.ps1
```

Za osvezavanje portable release foldera:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-vhs-mp4-release.ps1
```

Za pravljenje portable ZIP paketa i installera:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-vhs-mp4-installer.ps1
```

## Testovi

Fokusirani test paket:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py tests/test_optimize_vhs_mp4_gui_tokens.py tests/test_vhs_release_package.py tests/test_vhs_installer_packaging.py -q
```

## Struktura

- `scripts/` - izvorne skripte i builder-i
- `assets/` - ikona i staticki resursi
- `release/` - gotov portable paket
- `packaging/` - Inno Setup skripta
- `tests/` - regresioni testovi
- `docs/` - korisnicko uputstvo, planovi i specifikacije

## Napomena

Ovaj repozitorijum je namerno odvojen od drugih projekata. Sadrzi samo fajlove koji pripadaju video konverteru.
