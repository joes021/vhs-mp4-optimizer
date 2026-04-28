# Video Converter Media Info Design

## Goal

Dodati pravi media-info sloj za svaki ulazni video fajl, tako da korisnik pre konverzije vidi sta je tacno dobio: kontejner, video/audio kodeke, rezoluciju, odnos stranica, FPS, broj frejmova, protok, trajanje i velicinu.

## Scope

Faza radi:

- `Get-VhsMp4MediaInfo` u core modulu, preko `ffprobe -show_format -show_streams -of json`
- normalizovane properties vrednosti za GUI i buduce odluke
- dodatne kolone u tabeli: kontejner, rezolucija, trajanje, video, audio, bitrate i frames
- desni `Properties / Media info` panel koji prikazuje detalje izabranog fajla
- release README i uputstvo sa novom funkcijom

Faza ne radi:

- video preview
- rucni trim i marker split
- cuvanje posebnog sidecar media-info JSON fajla

## Architecture

Core modul ostaje izvor istine. GUI tokom `Scan Files` poziva `Get-VhsMp4MediaInfo`; isti rezultat koristi za bolju procenu trajanja i za prikaz properties panela. Ako `ffprobe` ne moze da procita fajl, skeniranje ne puca: tabela pokazuje `Media info: nije dostupno`, a procena ostaje `--`.

## Testing

Testovi pokrivaju:

- parsiranje realnog `ffprobe` JSON oblika kroz lazni `ffprobe.ps1`
- sibling `ffprobe.ps1` pored `ffmpeg.ps1`
- GUI tokene za nove kolone i properties panel
- release README tokene za media-info funkciju
