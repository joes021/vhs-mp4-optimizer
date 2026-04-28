# Video Converter Crop / Overscan Design

## Goal

Dodati VHS-specifičan `Crop / Overscan` alat u `Video Converter`, tako da korisnik može da ukloni crne ivice i overscan zone sa starih snimaka bez izlaska iz postojećeg `Player / Trim` toka, uz mogućnost potpuno automatskog rada kada korisnik ne želi ručno pregledanje.

Primarni cilj ove faze nije da alat postane pun video editor, nego da tipične VHS ivice i overscan problemi postanu brzi za rešavanje i u ručnom i u batch režimu.

## Chosen Direction

Za ovu fazu bira se hibridni crop pristup:

- crop alat živi u postojećem `Player / Trim` prozoru
- radi **po fajlu**
- ima `Detect Crop` koji predlaže crop
- ima `Auto Crop` koji odmah prihvata automatski rezultat
- ima ručna pixel polja `Left / Top / Right / Bottom`
- ima vizuelni overlay preko preview-a
- u glavnom batch prozoru postoji checkbox `Auto apply crop if detected`
- batch auto-crop radi tek pri `Start Conversion`
- ručni crop uvek ima prednost nad automatskim crop-om

Ovim dobijamo i precizan ručni alat i potpuno automatski tok za korisnike koji ne žele da potvrđuju svaki fajl posebno.

## Scope

Ova faza radi:

- novu sekciju `Crop / Overscan` u `Player / Trim` prozoru
- dugmad `Detect Crop`, `Auto Crop`, `Clear Crop`
- ručna pixel polja `Left`, `Top`, `Right`, `Bottom`
- vizuelni crop overlay preko preview-a
- auto-detect crop-a iz više frame-ova raspoređenih kroz snimak
- čuvanje crop stanja po fajlu
- status stanja `No crop`, `Auto crop`, `Manual crop`
- batch opciju `Auto apply crop if detected`
- batch primenu auto-crop-a tek na `Start Conversion`
- bezbedan fallback kada detekcija nije dovoljno sigurna
- FFmpeg crop primenu pri konverziji
- prikaz crop statusa u glavnom queue prikazu
- log/report trag za crop odluku

Ova faza ne radi:

- crop po procentima
- globalni crop za ceo batch
- `Copy to All`
- ručno povlačenje crop ivica mišem preko slike
- crop preset biblioteke
- napredni content-aware crop za nestabilan kadar
- automatsko aspect correction ponašanje

## Crop State Model

Svaki fajl dobija sopstveno crop stanje. Prva verzija uvodi tri jasna stanja:

1. `No crop`
   - nema ni ručnog ni automatskog crop-a

2. `Auto crop`
   - alat je sam detektovao crop i on je prihvaćen za taj fajl

3. `Manual crop`
   - korisnik je ručno podesio ili doterao vrednosti

Prioritet je strogo definisan:

`Manual crop` > `Auto crop` > `No crop`

To znači:

- batch auto-crop nikad ne pregazi ručni crop
- ručna izmena bilo kog pixel polja automatski pretvara stanje u `Manual crop`
- `Clear Crop` vraća fajl na `No crop`

## Data Model

Crop podaci treba da budu deo istog per-file plan state modela kao i trim, preview pozicija i segmenti.

Predlog minimalnih polja po fajlu:

- `CropMode`
  - `None`
  - `Auto`
  - `Manual`
- `CropLeft`
- `CropTop`
- `CropRight`
- `CropBottom`
- `CropSummary`
- `CropDetectedAt`
- `CropDetectionConfidence`
- `CropDetectionSampleCount`

Prva verzija ne mora sve da izlaže korisniku u UI-ju, ali interni model treba da ostane dovoljno jasan da kasnije može da se proširi.

## Detection Strategy

Auto-detect crop mora biti konzervativan i bezbedan.

Predloženo ponašanje:

- analiza ne koristi samo prvi frame
- uzima više frame-ova kroz snimak
- traži stabilne crne ivice / overscan zone
- crop predlaže samo ono što je dovoljno dosledno kroz više uzoraka
- ako rezultat nije dovoljno siguran, detekcija vraća `No crop`

Pravila:

- `Detect Crop`
  - analizira više frame-ova
  - popunjava `Left / Top / Right / Bottom`
  - ne mora automatski da zaključa rezultat kao ručni

- `Auto Crop`
  - pokreće istu detekciju
  - ako je rezultat dobar, odmah upisuje `Auto crop`
  - ako nije siguran, ostavlja `No crop`

- `Auto apply crop if detected`
  - u batch režimu pokušava detekciju tek pri `Start Conversion`
  - važi samo za fajlove bez ručnog crop-a

## Player / Trim UI

Sekcija `Crop / Overscan` u `Player / Trim` prozoru dobija:

- `Detect Crop`
- `Auto Crop`
- `Clear Crop`
- pixel polja:
  - `Left`
  - `Top`
  - `Right`
  - `Bottom`
- kratku status liniju:
  - `Crop: --`
  - `Crop: Auto`
  - `Crop: Manual`

Preview dobija crop overlay:

- zatamnjene zone koje će biti odsečene
- jasnu unutrašnju granicu onoga što ostaje

Korisnički tok:

1. otvori fajl u `Player / Trim`
2. klikni `Detect Crop` ili `Auto Crop`
3. po potrebi ručno koriguj `Left / Top / Right / Bottom`
4. `Save to Queue`

## Main Window UI

Glavni batch ekran dobija dve stvari:

1. novi checkbox:
   - `Auto apply crop if detected`

2. novu queue informaciju:
   - posebna kolona ili status ćelija sa:
     - `Crop: Auto`
     - `Crop: Manual`
     - `Crop: --`

Korisnik tako odmah vidi koji fajlovi već imaju crop, bez otvaranja svakog reda.

## Batch Rules

Najvažnija pravila batch ponašanja:

1. `Scan Files` ostaje brz i ne pokreće crop detekciju
2. `Auto apply crop if detected` radi tek na `Start Conversion`
3. ručni crop ima prednost i ne sme biti pregažen
4. ako auto-detect ne uspe, fajl ide dalje bez crop-a
5. crop ne sme da ruši konverziju ako detekcija ne uspe
6. ako je crop već upisan za fajl, nije potrebno ponavljati istu detekciju bez razloga

## FFmpeg Integration

Crop treba da uđe u isti filter tok kao i postojeći video filteri.

Redosled treba da ostane smislen i stabilan:

- crop treba da se uklopi sa:
  - deinterlace
  - denoise
  - rotate/flip
  - scale
  - trim/split

Tačan redosled implementacije treba da prati postojeći filter model u kodu i da minimizira rizik od regresija. Ako postojeća filter kompozicija već ima jasnu logiku, crop treba ući kao njen prirodni deo, ne kao paralelna grana.

## Error Handling

Crop sistem mora da bude tih i bezbedan:

- detekcija neuspešna:
  - ne ruši alat
  - vraća `No crop`
  - daje kratku log/status napomenu

- ručno unete neispravne vrednosti:
  - prijaviti jasnu poruku
  - ne prihvatiti crop dok nije validan

- crop previše agresivan ili van granica:
  - odbiti ili ograničiti vrednosti

- preview overlay ne sme da prikazuje stanje koje nije stvarno upisano

## Testing

Testovi treba da pokriju:

- GUI tokene za `Crop / Overscan`
- `Detect Crop`, `Auto Crop`, `Clear Crop`
- pixel polja `Left / Top / Right / Bottom`
- crop overlay tokene
- per-file crop state
- prioritet `Manual > Auto > None`
- batch `Auto apply crop if detected`
- pravilo da `Scan Files` ne pokreće crop detekciju
- FFmpeg filter integraciju
- log/report/release README tokene

Postojeći testovi za:

- trim
- multi-cut
- preview
- player
- workflow preset
- split output
- release paket

moraju ostati zeleni.

## Follow-on Phases

Posle ove crop/overscan podfaze prirodan nastavak VHS-specifičnog rada je:

1. `4:3 / 16:9 aspect correction`
2. jači `Deinterlace / VHS cleanup` profili
3. kasnije `Copy to All` ili batch crop helpers, ako zaista zatrebaju
