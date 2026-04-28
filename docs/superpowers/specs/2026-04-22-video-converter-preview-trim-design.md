# Video Converter Preview Trim Design

## Goal

Dodati radionicki `Preview / Trim` tok za Video Converter, tako da korisnik pre batch konverzije moze da izabere fajl, vidi preview sliku, proveri properties, rucno podesi pocetak/kraj snimka i tek onda pusti konverziju. Primarni cilj je bolji realni VHS/digitalizacija workflow, ne opsti profesionalni editor.

## Chosen UI Direction

Izabrana je varijanta A: postojeca tabela ostaje glavni radni prostor, a desni panel postaje `Preview / Properties`.

Desni panel prikazuje za trenutno izabrani fajl:

- preview frame iz videa
- dugme `Preview Frame`
- dugme `Open Video`
- polja `Start` i `End`
- dugme `Apply Trim`
- procenu trimovane duzine i izlazne velicine kada je dostupna
- postojeci media-info/properties tekst

Tabela dobija vidljivu oznaku za fajlove koji imaju rucni trim, na primer kolonu `Trim` ili `Range`, da korisnik ne zaboravi sta je podesio pre `Start Conversion`.

## Scope

Faza radi:

- trim podesavanja po pojedinacnom fajlu
- vreme u formatima `HH:MM:SS`, `MM:SS` ili sekunde
- validaciju da je `Start` manji od `End` kada su oba uneta
- preview frame generisan preko FFmpeg-a bez menjanja originalnog fajla
- `Open Video` za otvaranje originalnog fajla u podrazumevanom Windows player-u
- primenu trim opsega tokom konverzije
- kombinovanje trimovanog izlaza sa postojecim `Split output`
- izvestaj koji belezi koji fajlovi su trimovani
- release README/uputstvo sa osnovnim objasnjenjem preview/trim toka

Faza ne radi:

- frame-accurate timeline editor
- vise trim segmenata iz jednog fajla
- crop, rotate, color correction ili filter editor
- cuvanje projekta izmedju pokretanja programa
- embedded video playback unutar PowerShell WinForms aplikacije

## Core Design

Shared PowerShell modul ostaje izvor istine. GUI ne treba sam da sklapa FFmpeg argumente.

Core modul dodaje pomocne funkcije:

- `Convert-VhsMp4TimeTextToSeconds` parsira korisnicki unos vremena
- `Get-VhsMp4TrimWindow` validira `Start`/`End` i vraca normalizovan trim opseg
- `Format-VhsMp4FfmpegTime` formatira vreme za FFmpeg argumente
- `New-VhsMp4PreviewFrame` generise jedan JPG/PNG frame za preview

`Get-VhsMp4FfmpegArguments`, `Invoke-VhsMp4File`, `Start-VhsMp4FileProcess` i `Invoke-VhsMp4Batch` dobijaju opcione trim parametre. Kada je trim aktivan:

- `-ss` se dodaje za pocetak
- `-t` se koristi kada su poznati pocetak i kraj
- `-to` se koristi kada postoji samo kraj
- `Split output` se primenjuje na vec trimovani izlaz

Originalni fajlovi se nikada ne menjaju.

## GUI Design

Desni panel postaje podeljen vertikalno:

1. preview zona sa slikom izabranog fajla
2. preview kontrole: preview vreme, `Preview Frame`, `Open Video`
3. trim kontrole: `Start`, `End`, `Apply Trim`, `Clear Trim`
4. media-info/properties tekst

Kada korisnik klikne fajl u tabeli, panel prikazuje podesavanja za taj fajl. `Apply Trim` pamti trim u plan stavci, osvezava tabelu i procenu. `Clear Trim` brise trim samo za izabrani fajl.

Ako nije izabran fajl, panel prikazuje kratko uputstvo. Ako FFmpeg/ffprobe nije dostupan, preview dugme je onemoguceno ili prikazuje jasnu gresku, ali media tabela i dalje moze da radi koliko je moguce.

## Data Flow

`Scan Files` pravi batch plan kao i do sada. Svaka plan stavka moze da dobije dodatna polja:

- `TrimStartText`
- `TrimEndText`
- `TrimStartSeconds`
- `TrimEndSeconds`
- `TrimSummary`
- `PreviewFramePath`

Tok rada:

1. korisnik skenira folder
2. izabere fajl u tabeli
3. generise preview frame ili otvori video u player-u
4. unese `Start`/`End`
5. klikne `Apply Trim`
6. plan stavka se azurira
7. `Start Conversion` salje trim parametre za svaku stavku posebno
8. izvestaj belezi finalni opseg

## Error Handling

Greske treba da budu korisnicke, kratke i vezane za konkretan fajl:

- neispravno vreme: prikazati primer dozvoljenog formata
- `End` pre `Start`: traziti korekciju opsega
- preview frame nije uspeo: prikazati FFmpeg gresku u log/status prostoru
- fajl nema citljivo trajanje: dozvoliti rucni trim, ali bez procene nove velicine
- fajl nestane sa diska: stavka dobija status greske, batch nastavlja sledeci fajl

## Testing

Testovi pokrivaju:

- parsiranje `HH:MM:SS`, `MM:SS` i sekundi
- odbijanje neispravnog trim opsega
- FFmpeg argumente za `Start`, `End`, `Start + End`, `SampleSeconds` i `Split output`
- preview frame komandu preko laznog FFmpeg procesa
- GUI tokene za `Preview Frame`, `Open Video`, `Apply Trim`, `Clear Trim` i trim kolonu
- release README tokene za preview/trim
- parser proveru za GUI skriptu

Postojeci testovi za VHS profile, opste video ulaze, media info, progress/ETA i split output moraju ostati zeleni.
