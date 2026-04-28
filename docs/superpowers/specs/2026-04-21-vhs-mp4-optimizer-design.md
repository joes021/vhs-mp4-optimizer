# VHS MP4 Optimizer Design

**Goal:** Napraviti mali Windows GUI alat koji smanjuje vec napravljene velike `.mp4`, DV/MSDV `.avi` i MPEG `.mpg/.mpeg` fajlove iz VHS/DVD digitalizacije u prakticne MP4 kopije za predaju musterijama, uz ocuvan vizuelni kvalitet i normalnu velicinu fajla.

**Context:** Projekat vec ima lokalni PowerShell/WinForms obrazac za video konverziju. Novi alat koristi isti jednostavan stil: izbor foldera, skeniranje, status po fajlu, start/stop, log i automatska provera FFmpeg-a.

## User Flow

Korisnik pokrece `optimize-vhs-mp4-gui.bat`, izabere folder sa velikim `.mp4`, `.avi`, `.mpg` ili `.mpeg` fajlovima i po potrebi izlazni folder. Podrazumevani izlaz je `vhs-mp4-output` u ulaznom folderu.

GUI zatim:

- pronalazi `.mp4`, `.avi`, `.mpg` i `.mpeg` fajlove u ulaznom folderu
- prikazuje za svaki fajl da li je `queued` ili `skipped`
- preskace izlaz ako istoimeni optimizovani `.mp4` vec postoji
- pokrece FFmpeg tek na klik `Start Conversion`
- prikazuje napredak, log i zavrsni zbir
- prikazuje procenat i ETA za fajl koji se trenutno obradjuje
- opciono deli dugacke izlaze na validne MP4 delove `base-part001.mp4`, `base-part002.mp4`, itd.
- prikazuje okvirnu velicinu izlaza i USB napomenu za FAT32/exFAT pre pokretanja obrade
- nikada ne brise niti menja originalne fajlove

## Quality Modes

Default mode is `Standard VHS`:

- video codec: `libx264`
- CRF: `22`
- preset: `slow`
- pixel format: `yuv420p`
- audio codec: `aac`
- audio bitrate: `160k`
- `-movflags +faststart`
- keep original resolution and frame rate

Other modes:

- `Smaller File`: CRF `24`, preset `slow`, audio `128k`
- `Better Quality`: CRF `20`, preset `slow`, audio `192k`

The tool does not upscale, resize, crop, or deinterlace by default. It only makes a smaller H.264 MP4 delivery copy from MP4, AVI, MPG, or MPEG input.

## Split Output

`Split output` je opciona isporucna opcija za dugacke snimke i USB medije koji ne primaju velike pojedinacne fajlove. Podrazumevana vrednost je `3.8` GB po delu.

Split mode:

- menja izlaz iz `base.mp4` u `base-part001.mp4`, `base-part002.mp4`, ...
- za skip proveru koristi prvi ocekivani deo, `base-part001.mp4`
- koristi FFmpeg segment muxer, ne obicno secenje fajla na bajtove
- dodaje konzervativan bitrate limit po quality modu da delovi ostanu oko zadate velicine

Ovo cuva MP4 delove kao zasebne fajlove koji mogu da se puste pojedinacno.

## Estimate And USB Notes

`Scan Files` pokusava da procita trajanje svakog ulaza preko `ffprobe`, zatim racuna okvirnu isporucnu velicinu prema izabranom quality modu. Procena koristi konzervativne bitrate vrednosti:

- `Smaller File`: oko `3000k` video plus audio
- `Standard VHS`: oko `4500k` video plus audio
- `Better Quality`: oko `6500k` video plus audio

GUI prikazuje:

- `Estimate`: okvirna velicina izlaza, ili velicina i broj delova kada je split ukljucen
- `USB note`: `FAT32 OK`, `exFAT OK`, ili upozorenje da treba ukljuciti `Split output`/koristiti `exFAT`

Procena je namenjena odluci pre pokretanja posla; stvarna velicina moze odstupiti jer H.264 kvalitet zavisi od sadrzaja snimka.
