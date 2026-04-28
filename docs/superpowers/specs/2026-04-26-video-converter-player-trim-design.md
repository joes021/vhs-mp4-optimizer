# Video Converter Player Trim Window Design

## Goal

Dodati ozbiljniji `Player / Trim` tok u Video Converter, tako da korisnik moze da otvori jedan fajl iz batch tabele u posebnom prozoru, pregleda ga kao pravi player za moderne formate i precizno podesi `Start`, `End` i segmente bez napustanja glavnog konverter workflow-a.

Primarni cilj nije da alat postane pun profesionalni editor, nego da znacajno ubrza realan rad sa VHS/digitalizacija materijalom i dugackim kucnim snimcima.

## Chosen Direction

Za ovu fazu je izabran hibridni pristup:

- poseban `Player / Trim` prozor kao glavni editor za jedan fajl
- pravi playback u tom prozoru za moderne ulaze
- bez audio reprodukcije u prvoj verziji
- stabilan fallback na postojeci `preview / timeline` tok za stare ili problematicke formate
- `Save to Queue` vraca trim/segment izmene nazad u glavni batch plan

Ovim se dobija jaci korisnicki utisak pravog playera, ali bez rizika da stari formati ili neuspela player integracija blokiraju ostatak alata.

## Scope

Faza radi:

- poseban `Player / Trim` prozor za jedan izabrani fajl
- otvaranje prozora na dupli klik u tabeli
- otvaranje prozora preko zasebnog dugmeta `Open Player`
- pravi playback bez zvuka za `MP4`, `MOV` i `MKV`
- `Play / Pause`, `Stop`, timeline pomeranje i prikaz `current / total`
- `frame-by-frame` pomeranje
- `Set Start`, `Set End`, `Add Segment`, `Remove Segment`, `Clear`
- vizuelne `In / Out` markere na timeline-u
- `Save to Queue` kao glavno dugme koje cuva izmene nazad u batch
- fallback `Preview mode` za `AVI`, `MSDV` i `MPG`
- fallback `Preview mode` ako playback engine nije dostupan ili ne moze da inicijalizuje reprodukciju
- upozorenje za nesacuvane izmene pri zatvaranju ili prelasku na drugi fajl

Faza ne radi:

- audio playback
- poseban export iz player prozora
- multi-file edit iz player prozora
- crop / color correction / dodatne filter editore u player prozoru
- potpuno isti playback put za sve formate
- profesionalni NLE timeline sa vise traka

## Architecture

Postojeci batch ekran ostaje centralni radni prostor. Novi `Player / Trim` prozor ne uvodi drugi model podataka, nego radi nad istim plan stavkama koje glavni queue vec koristi.

Sistem se deli na tri sloja:

1. `Main Queue UI`
   - skeniranje foldera
   - batch tabela
   - filteri, split, kvalitet, start konverzije
   - otvaranje `Player / Trim` prozora

2. `Player / Trim Window`
   - playback ili fallback preview za jedan fajl
   - edit trim opsega i segmenata
   - lokalni prikaz statusa i nesacuvanih izmena

3. `Shared Trim State`
   - postoji kao izvor istine za `TrimStartText`, `TrimEndText`, `TrimSegments`, `TrimSummary`, procene i slicno
   - `Save to Queue` samo upisuje ili osvezava ta polja na istoj plan stavci
   - `Start Conversion` i dalje koristi postojeci FFmpeg put i iste trim podatke

Najvaznije pravilo ove faze je da nema dupliranja trim logike. Player prozor je editor nad istim podacima, ne paralelan sistem.

## Window UX

`Player / Trim` prozor treba da bude odvojen od glavnog batch ekrana i da ostavi dovoljno mesta za pregled videa i rad nad markerima.

Predlozeni raspored:

- naslovna traka sa nazivom fajla
- informacioni red sa formatom, trajanjem, rezolucijom i FPS
- veliki centralni video prikaz
- transport red:
  - `Play / Pause`
  - `Stop`
  - `<< Frame`
  - `Frame >>`
  - prikaz `current / total`
- veliki timeline ispod playera
- vidljivi `Start` i `End` markeri na timeline-u
- segment kontrole:
  - `Set Start`
  - `Set End`
  - `Add Segment`
  - `Remove Segment`
  - `Clear`
- donji komandni red:
  - `Save to Queue`
  - `Cancel`

Prikaz treba jasno da razlikuje dva stanja:

- `Playback mode` za moderne formate
- `Preview mode` za fallback

Korisnik ne mora da zna tehnicku pozadinu, ali prozor mora da komunicira da li fajl trenutno radi kao pravi player ili kao precizan preview editor.

## Format Strategy

Prva verzija playera ne pokusava da izjednaci sve ulaze.

`Playback mode` vazi za:

- `MP4`
- `MOV`
- `MKV`

`Preview mode` fallback vazi za:

- `AVI`
- `MSDV`
- `MPG`

Fallback ostaje funkcionalno jak:

- timeline skokovi
- frame-by-frame
- `Set Start / Set End`
- segmenti
- cuvanje nazad u queue

Time stari formati ostaju upotrebljivi i stabilni, a moderan playback dolazi tamo gde najvise vredi.

## Playback Engine

Za playback se dozvoljava dodatna player komponenta, umesto oslanjanja samo na Windows-native ponasanje.

Razlozi:

- stabilniji i predvidljiviji playback za `MP4 / MOV / MKV`
- manja zavisnost od toga sta je konkretna Windows instalacija vec sposobna da pusti
- bolji temelj za kasnije prosirenje player funkcija

Bitno ogranicenje:

- dodatna komponenta ne sme biti single point of failure
- ako playback engine nije dostupan ili padne inicijalizacija, alat prelazi u `Preview mode`
- trim/editor tok mora ostati dostupan i tada

Release paket kasnije treba da dokumentuje ili bundluje taj runtime, ali korisnicki tok ne sme delovati pokvareno ako playback nije moguc.

## Data Flow

Tok rada po fajlu:

1. korisnik skenira folder i dobije batch listu
2. korisnik duplo klikne fajl ili klikne `Open Player`
3. otvara se `Player / Trim` prozor za tu plan stavku
4. prozor ucitava playback ili fallback preview rezim
5. korisnik pomera timeline, markere i segmente
6. klik na `Save to Queue` upisuje izmene nazad u tu plan stavku
7. batch tabela osvezava `Range`, segmente i procene
8. `Start Conversion` koristi iste podatke bez dodatne konverzije modela

Ako korisnik zatvara prozor sa nesacuvanim izmenama, prikazuje se `Save / Discard / Cancel`.

## Main Window Impact

Glavni batch ekran ostaje glavni centar rada. Potrebne promene su ogranicene:

- novo dugme `Open Player`
- dupli klik na grid red otvara prozor
- postojeci desni `Preview / Properties` panel moze da ostane kao brzi pregled i lagani trim tok
- `Player / Trim` postaje glavni "pro" nacin za ozbiljniji rad po fajlu

Ovaj pristup smanjuje layout rizik na glavnom ekranu i dozvoljava da se napredniji editor razvija odvojeno.

## Error Handling

Greske moraju biti kratke i vezane za konkretan fajl ili rezim:

- playback engine nije dostupan: preci u `Preview mode` i prikazati jasnu poruku
- format nije podrzan za pravi playback: otvoriti `Preview mode` bez hard error-a
- fajl nestane sa diska: obavestiti korisnika i ne otvarati editor
- neispravan trim opseg: zadrzati korisnika u prozoru i traziti korekciju
- neuspeh pri ucitavanju frame preview-a: poruku dati u status zoni prozora, bez rusenja editora

## Testing

Testovi za ovu fazu treba da pokriju:

- GUI tokene za `Open Player`, dupli klik i `Player / Trim`
- logiku otvaranja player prozora iz grid selekcije
- status za `Playback mode` i `Preview mode`
- `Save to Queue` tok bez posebnog exporta
- nesacuvane izmene i `Save / Discard / Cancel` tok
- fallback grananje za stare formate ili neuspesan playback engine
- zadrzavanje postojece trim/segment logike kroz isti shared state

Postojeci testovi za:

- scan
- drag & drop
- preview/timeline
- trim segmente
- split output
- filtere
- release paket

moraju ostati zeleni.

## Follow-on Phases

Ovaj dokument pokriva samo prvu sledecu podfazu: `Player / Trim` prozor.

Naredni prioriteti ostaju:

1. `Presets / Profiles`
2. `VHS-specific tools`
3. `Batch polish`

Oni ce dobiti zasebne dizajn dokumente i implementacione planove, kako bi svaka faza ostala jasna i proverljiva.
