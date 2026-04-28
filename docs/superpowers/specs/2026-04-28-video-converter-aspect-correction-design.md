# Video Converter Aspect Correction Design

## Goal

Dodati per-file `Aspect mode` sistem u `Video Converter`, tako da alat moze da prepozna i ispravi pogresan ili nepostojeci `4:3 / 16:9` prikaz kod PAL/DV i NTSC/DV materijala, uz bezbedan automatski rezim, rucni override i predvidljiv square-pixel izlaz.

Primarni cilj ove faze nije da alat postane pun broadcast transcode sistem, nego da tipicni VHS, DV AVI, MPEG i slicni snimci dobiju ispravan prikaz na danasnjim playerima i televizorima bez rucnog petljanja oko `SAR/DAR` matematike.

## Chosen Direction

Za ovu fazu bira se hibridni aspect pristup:

- uvodi se per-file `Aspect mode`
- opcije su:
  - `Auto`
  - `Keep Original`
  - `Force 4:3`
  - `Force 16:9`
- auto-detect radi vec pri `Scan Files`
- auto-detect koristi:
  - `DisplayAspectRatio`
  - `SampleAspectRatio`
  - PAL/DV i NTSC/DV heuristiku
- podrazumevani izlaz za anamorphic slucajeve ide u square-pixel rezoluciju
- rucni override radi po fajlu
- postoji `Copy Aspect to All` za brzu batch primenu
- glavna "pro" kontrola zivi i u `Player / Trim` prozoru

Ovim dobijamo tri sloja kontrole:

1. automatsku aspect odluku
2. rucni override po fajlu
3. batch ubrzanje za slicne izvore

## Scope

Ova faza radi:

- novu per-file aspect odluku pri `Scan Files`
- aspect status u glavnom queue prikazu
- `Aspect mode` izbor u glavnom prozoru
- `Copy Aspect to All`
- posebnu sekciju `Aspect / Pixel shape` u `Player / Trim` prozoru
- automatsko mapiranje anamorphic ulaza na square-pixel izlaz
- prikaz detektovanog ulaza i planiranog izlaza u UI-ju
- bezbedan fallback na `Keep Original` kada auto nije siguran
- FFmpeg integraciju aspect odluke sa postojecim filter tokom
- log/report trag za aspect odluku

Ova faza ne radi:

- napredne custom ratio vrednosti tipa `1.66:1`, `2.35:1`
- potpuno opstu heuristiku za sve moguce rezolucije
- rucno crtanje aspect regiona preko slike
- automatski content-aware detect stvarnog kadra
- broadcast-level interlace/aspect ekspertske profile
- zaseban aspect preset editor

## Aspect State Model

Svaki fajl dobija svoje aspect stanje. Prva verzija uvodi sledece rezime:

1. `Auto`
   - alat sam bira prikaz iz metadata i heuristike

2. `Keep Original`
   - alat cuva stvarni display aspect izvora
   - ako je ulaz anamorphic, izlaz prelazi u square-pixel varijantu koja verno cuva isti prikaz

3. `Force 4:3`
   - alat forsira izlaz kao `4:3`

4. `Force 16:9`
   - alat forsira izlaz kao `16:9`

Prioritet je strogo definisan:

`Force 4:3 / Force 16:9 / Keep Original` > `Auto`

To znaci:

- rucni izbor uvek ima prednost nad automatikom
- `Copy Aspect to All` ne menja crop, trim ni druge per-file odluke
- ako korisnik vrati fajl na `Auto`, opet se koristi detekcija sa scan-a

## Data Model

Aspect podaci treba da budu deo istog per-file state modela kao trim, crop, preview i procene.

Predlog minimalnih polja po fajlu:

- `AspectMode`
  - `Auto`
  - `KeepOriginal`
  - `Force4x3`
  - `Force16x9`
- `DetectedAspectMode`
- `DetectedAspectLabel`
- `DetectedDisplayAspectRatio`
- `DetectedSampleAspectRatio`
- `DetectedAspectConfidence`
- `OutputAspectWidth`
- `OutputAspectHeight`
- `AspectSummary`
- `AspectDetectionSource`

Prva verzija ne mora sva polja da izlozi korisniku, ali interni model treba da ostane dovoljno jasan da moze da se prosiri bez lomljenja.

## Detection Strategy

Auto-detect aspect mora da bude konzervativan i predvidljiv.

Pravila prve verzije:

- `Auto` prvo pokusava da zakljuci aspect iz postojecih metadata
- zatim, samo ako metadata nisu dovoljno pouzdani, ukljucuje PAL/DV i NTSC/DV heuristiku
- fokus prve verzije je na:
  - `720x576`
  - `704x576`
  - `720x480`
  - `704x480`

Heuristika ne sme agresivno da pogadja. Ako nema dovoljno osnova:

- alat pada na `Keep Original`
- ne izmislja `4:3` ili `16:9` bez razloga

Normativni redosled odluke prve verzije:

1. validan `DAR`, ako jasno pokazuje `4:3` ili `16:9`
2. validan `SAR`, ako iz njega moze da se izvede `4:3` ili `16:9`
3. poznata PAL/DV ili NTSC/DV rezolucija, ako metadata nisu dovoljni
4. fallback na `Keep Original`

Za prvu verziju `validan` znaci:

- vrednost postoji
- moze da se parsira
- daje smislen odnos stranica
- odnos moze bezbedno da se mapira na `4:3` ili `16:9`

Za prvu verziju `unsafe` znaci bilo koji od sledecih slucajeva:

- `DAR` i `SAR` oba postoje i vode ka razlicitim ciljevima (`4:3` naspram `16:9`)
- metadata vode ka odnosu koji nije blizu ciljanim `4:3` ili `16:9`
- metadata nedostaju, a rezolucija nije u podrzanom PAL/DV ili NTSC/DV skupu
- ulazna kombinacija deluje nedosledno i ne moze sigurno da se objasni prvim skupom pravila

Kad su i `DAR` i `SAR` prisutni:

- ako se slazu, rezultat se prihvata sa `High` poverenjem
- ako `DAR` jasno ukazuje na `4:3` ili `16:9`, a `SAR` nije upotrebljiv, koristi se `DAR`
- ako `SAR` jasno ukazuje na `4:3` ili `16:9`, a `DAR` nije upotrebljiv, koristi se `SAR`
- ako su oba upotrebljiva, ali konfliktna, rezultat je `Keep Original`, bez agresivne auto odluke

`DetectedAspectConfidence` nije samo UI ukras. U prvoj verziji:

- `High` se koristi kad se `DAR` i `SAR` slazu ili kad jedan validan metadata signal postoji bez konkurentskog signala
- `Medium` se koristi kad odluka dolazi iz podrzane PAL/DV ili NTSC/DV heuristike bez konflikta
- `Low` i `Unknown` teraju `Auto` da padne na `Keep Original`
- UI i log treba da prikazu da li je odluka dosla iz `DAR`, `SAR`, heuristike ili fallback-a

Normativno mapiranje prve verzije:

- validan `DAR` + validan `SAR` + isti zakljucak -> `High`
- samo validan `DAR` -> `High`
- samo validan `SAR` -> `High`
- podrzana PAL/DV ili NTSC/DV heuristika bez konflikta -> `Medium`
- konfliktni metadata signali ili odnos van podrzanih ciljeva -> `Low`
- bez upotrebljivih signala -> `Unknown`

Primeri prve verzije:

- `720x576`, `DAR=16:9`, `SAR=64:45` -> `Auto 16:9`, poverenje `High`
- `720x576`, `DAR=4:3`, `SAR=64:45` -> konflikt metapodataka, `Keep Original`, poverenje `Low`

## Output Mapping

Podrazumevana square-pixel mapiranja u prvoj verziji:

- PAL `4:3` -> `768x576`
- PAL `16:9` -> `1024x576`
- NTSC `4:3` -> `640x480`
- NTSC `16:9` -> `854x480`

Pravila:

- ako je ulaz vec square-pixel i dosledan, ne radi se nepotrebna aspect korekcija
- ako je ulaz anamorphic, izlaz prelazi u square-pixel oblik koji cuva isti prikaz
- `Keep Original` cuva stvarni display aspect, ne samo storage rezoluciju
- `Force 4:3` i `Force 16:9` prepisuju auto odluku i vode ka odgovarajucem square-pixel izlazu
- `Scale = Original` ne znaci "zadrzi storage raster po svaku cenu"
- `Scale = Original` znaci "ne trazi dodatni korisnicki resize van onoga sto zahtevaju crop, rotate i aspect korekcija"
- zato anamorphic ulaz uz `Scale = Original` i dalje sme da promeni raster u square-pixel osnovu
- primer: PAL `720x576` `4:3` + `Scale = Original` -> `768x576`, ne samo `720x576` sa prepisanim metadata

## Relationship With Scale

Aspect odluka se donosi pre skaliranja, ali ciljna geometrija mora da se racuna nad stvarnim dimenzijama koje ostaju posle crop-a i eventualne rotacije koja menja orijentaciju slike.

To znaci:

- redosled prve verzije je:
  1. procitaj metadata i donesi `Aspect mode` odluku
  2. primeni crop, ako postoji
  3. primeni `rotate/flip` semantiku za dimenzije
  4. izracunaj ciljnu display geometriju nad radnom sirinom i visinom
  5. primeni `Scale`
  6. sastavi zavrsni izlazni format

Za prvu verziju:

- `flip` i rotacija od `180` stepeni ne menjaju racunanje radne sirine i visine
- rotacija od `90` ili `270` stepeni menja radnu geometriju tako sto zamenjuje sirinu i visinu pre aspect racunice
- aspect mode ostaje isti kao korisnicka namera (`Keep Original`, `Force 4:3`, `Force 16:9`, `Auto`), ali izlazna orijentacija mora da prati rotirani kadar

- `Keep Original` + `PAL 576p`
  - visina se racuna iz post-crop slike
  - sirina se racuna da sacuva isti display aspect

- `Keep Original` + `Scale = Original`
  - square-pixel ulaz ostaje na istoj radnoj geometriji
  - anamorphic ulaz prelazi u square-pixel osnovu koja cuva isti display aspect

- `Keep Original` + `720p`
  - visina postaje `720`
  - sirina se racuna iz odabrane aspect odluke i post-crop geometrije

- `Keep Original` + `1080p`
  - visina postaje `1080`
  - sirina se racuna iz odabrane aspect odluke i post-crop geometrije

- `Auto`
  - isto ponasanje, samo aspect prvo dolazi iz detekcije

- `Force 4:3` / `Force 16:9`
  - prepisuju auto odluku pre skaliranja

Primeri:

- `720x576` PAL anamorphic, bez crop-a, `Force 16:9` -> square-pixel osnova je `1024x576`, pa se tek onda primenjuje dodatni `Scale`
- `720x576` PAL anamorphic, crop `Left=8`, `Right=8`, `Top=0`, `Bottom=0`, `Force 16:9` -> aspect se cuva kao `16:9`, ali se ciljna sirina racuna iz post-crop visine i geometrije koja je ostala posle crop-a, ne iz originalnih `720x576`
- `720x576` PAL anamorphic, rotacija `90`, `Force 16:9` -> radna geometrija se prvo tretira kao rotirana, pa izlaz mora da prati portretnu orijentaciju rotiranog kadra umesto da zadrzi originalnu vodoravnu geometriju

Prakticno: korisnik bira nameru, a alat resava `SAR/DAR`, crop-aware geometriju i izlaznu rezoluciju.

## Main Window UI

Glavni batch ekran dobija:

1. novu kolonu `Aspect`
   - primeri:
     - `Auto 4:3`
     - `Auto 16:9`
     - `Keep`
     - `Manual 4:3`
     - `Manual 16:9`

2. novu batch kontrolu:
   - `Aspect mode` dropdown

3. novo batch dugme:
   - `Copy Aspect to All`

Korisnik tako odmah vidi:

- sta je detektovano
- da li je izbor auto ili rucni
- sta ce izlaz verovatno biti

## Player / Trim UI

`Player / Trim` prozor dobija novu sekciju `Aspect / Pixel shape`.

Sekcija dobija:

- dropdown:
  - `Auto`
  - `Keep Original`
  - `Force 4:3`
  - `Force 16:9`
- status liniju tipa:
  - `Detected: PAL DV 16:9 -> 1024x576`
- prikaz ulaznih vrednosti:
  - `DAR`
  - `SAR`
  - planirani izlaz

Poenta UI-ja je da korisnik odmah vidi:

- sta fajl verovatno jeste sada
- sta ce izlaz postati
- da li je to automatika ili rucni override

## Batch Behavior

Najvaznija batch pravila:

1. aspect auto-detect radi vec pri `Scan Files`
2. rezultat se pamti uz fajl
3. rucni override ima prednost
4. `Copy Aspect to All` menja samo `Aspect mode`
5. ako auto nije siguran, koristi se `Keep Original`
6. aspect odluka ne sme da rusi scan ni batch obradu

Ovaj deo je namerno drugaciji od crop faze: ovde korisnik odmah dobija vrednost vec na scan-u, jer je aspect analiza laksa i korisno je da odmah vidi planirani prikaz.

## FFmpeg Integration

Aspect odluka mora prirodno da udje u postojeci video filter tok i geometriju izlaza.

To znaci:

- mora da se uklopi sa:
  - crop
  - deinterlace
  - denoise
  - rotate/flip
  - scale
  - split
  - trim

Normativno pravilo prve verzije:

- aspect odluka se cuva kao semantika (`Keep Original`, `Force 4:3`, `Force 16:9`, `Auto`)
- crop se primenjuje pre zavrsnog scale koraka
- izlazna geometrija za aspect korekciju mora da koristi post-crop dimenzije i, kod rotacije `90/270`, post-rotate orijentaciju
- `Scale` ne sme ponovo da "popravlja" aspect koji je vec izracunat

Integracija treba da prati postojeci model filter lanca i da minimizuje regresije. Aspect logika ne treba da postane paralelni sistem van postojeceg FFmpeg argument builder toka.

## Error Handling

Aspect sistem mora da bude tih i bezbedan:

- los ili nedosledan `DAR/SAR`
  - ne rusi alat
  - ako konflikt nije bezbedno resiv, pada na `Keep Original`

- nepoznata rezolucija
  - ne rusi alat
  - koristi `Keep Original`

- rucni override i scale u kombinaciji
  - mora da daju validnu rezoluciju
  - ako nije moguce, korisnik dobija jasnu poruku

- UI ne sme da prikazuje lazni rezultat koji stvarni izlaz nece pratiti

## Testing

Testovi treba da pokriju:

- auto-detect iz `DAR/SAR`
- PAL/DV i NTSC/DV heuristiku
- fallback na `Keep Original`
- square-pixel mapiranja
- interakciju sa `Scale`
- nove GUI tokene za `Aspect mode`, `Copy Aspect to All` i `Aspect / Pixel shape`
- prikaz `Aspect` kolone u queue-u
- `Player / Trim` status prikaz
- FFmpeg argument integraciju
- release README i uputstvo tokene

Postojeci testovi za:

- trim
- crop
- preview
- player
- workflow preset
- split output
- release paket

moraju ostati zeleni.

## Follow-on Phases

Posle ove aspect podfaze prirodan nastavak VHS-specificnog rada je:

1. jaci `Deinterlace / VHS cleanup` profili
2. dodatne VHS heuristike za nestabilne capture izvore
3. eventualni `Copy to All` i za crop geometriju, ako se pokaze korisnim
