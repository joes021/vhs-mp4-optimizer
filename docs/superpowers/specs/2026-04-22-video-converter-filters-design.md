# Video Converter Filters Design

## Goal

Dodati praktican `Video filters` sloj u Video Converter, tako da korisnik moze pre konverzije da ukljuci najcesce popravke za VHS/DVD/telefon materijal: deinterlace, denoise, rotate/flip, scale i audio normalize.

## Scope

Faza radi:

- globalne filter opcije za ceo batch
- `Deinterlace` preko FFmpeg `yadif` filtera
- `Denoise` preko blagih `hqdn3d` presetova
- `Rotate / Flip` preko FFmpeg `transpose`, `hflip` i `vflip`
- `Scale` izlazne visine: original, PAL 576p, 720p i 1080p
- `Audio normalize` preko jednog prolaza `loudnorm`
- GUI kontrole u kompaktnom `Video filters` redu
- CLI parametre za iste opcije
- report/log zapis aktivnih filtera
- release README/uputstvo sa kratkim objasnjenjem

Faza ne radi:

- frame-accurate timeline editor
- crop alat
- color correction ili LUT
- detekciju interlace statusa preko analize slike
- per-file filtere; trim ostaje per-file, filteri su globalni batch izbor
- dvoprolazni loudnorm workflow

## UX Design

Kontrole idu u poseban kompaktan red ispod `Quality mode` reda, zato sto su filteri sekundarna podesavanja. Red se zove `Video filters`, sa kratkim labelama:

- `Deinterlace`
- `Denoise`
- `Rotate/flip`
- `Scale`
- `Audio normalize`

Podrazumevano je sve iskljuceno ili `Original`, da se postojeci tok rada ne promeni. Nazivi su opisni i kratki, a status/log prikazuje aktivne filtere samo kada korisnik ukljuci nesto.

## Core Design

Shared PowerShell modul ostaje izvor istine. GUI i CLI samo prosledjuju opcije.

Core dodaje:

- `Get-VhsMp4VideoFilterChain`
- `Get-VhsMp4AudioFilterChain`
- `Get-VhsMp4FilterSummary`

`Get-VhsMp4FfmpegArguments` dodaje `-vf` kada postoji video filter chain i `-af` kada je ukljucen audio normalize. Filteri se ubacuju pre codec/audio bitrate parametara i rade zajedno sa trim, split output i sample tokovima.

## Error Handling

Opcije su `ValidateSet` vrednosti, pa CLI dobija jasnu gresku ako je uneta nepodrzana vrednost. GUI koristi dropdown/checkbox kontrole, tako da korisnik ne moze lako da unese pogresnu vrednost. Ako FFmpeg odbije filter nad konkretnim fajlom, fajl dobija postojece `failed` stanje, a batch nastavlja dalje.

## Testing

Testovi pokrivaju:

- video filter chain za deinterlace, denoise, rotate/flip i scale
- audio normalize `-af` argument
- kombinaciju filtera sa trim i split output argumentima
- CLI parametre
- GUI tokene i kontrole
- report/build release tokene
- PowerShell parser proveru za izvorne i release skripte
