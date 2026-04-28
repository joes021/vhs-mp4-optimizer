# Video Converter Phase 1 Design

## Goal

Pretvoriti postojeci VHS MP4 Optimizer u siri Windows video converter, bez gubljenja stabilnih VHS tokova koji vec rade. Faza 1 uvodi opste video ulaze i izlazne profile; trim, marker split i preview ostaju sledece faze.

## Scope

Faza 1 radi:

- podrsku za ulaze `.mp4`, `.avi`, `.mpg`, `.mpeg`, `.mov`, `.mkv`, `.m4v`, `.wmv`, `.ts`, `.m2ts`, `.vob`
- nove profile:
  - `Universal MP4 H.264`
  - `Small MP4 H.264`
  - `High Quality MP4 H.264`
  - `HEVC H.265 Smaller`
- zadrzava stare profile `Standard VHS`, `Smaller File`, `Better Quality`, `Custom` kao kompatibilne izbore
- menja korisnicki tekst ka `Video Converter`, ali ostavlja postojece skripte/fajlove za kompatibilnost
- osvezava release paket i uputstvo

Faza 1 ne radi:

- rucni trim start/end
- split by markers
- thumbnail/preview frame
- remux/fast cut
- media-info kolone osim postojece procene velicine

## Architecture

Shared PowerShell modul ostaje izvor istine. `Get-VhsMp4SupportedExtensions` se prosiruje, a `Get-VhsMp4QualityProfile` postaje profilni resolver koji vraca codec, CRF, preset i audio bitrate. FFmpeg argumenti koriste profilni `VideoCodec`, tako da GUI i CLI dobijaju H.264 i H.265 kroz isti put.

GUI zadrzava postojece kontrole i dodaje nove opcije u isti `Quality mode` dropdown. Time faza 1 ne uvodi novi layout rizik pre trim/preview faza.

## Testing

Dodaju se pytest provere za:

- nove ulazne ekstenzije u planiranju
- H.264/H.265 FFmpeg argumente po profilu
- GUI tokene za `Video Converter`, nove profile i nove formate
- release README/build skriptu sa novim nazivom i profilima

Postojeci VHS testovi moraju ostati zeleni.
