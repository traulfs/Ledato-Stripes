# Firmware-Implementierung

Diese Beschreibung sagt, was eine Controller-Firmware aus einer
`.ledato`-Konfiguration lesen muss, um dieselbe Lichtszene auszugeben, die
die App anzeigt. Schwerpunkt: die **Matrix-Konfiguration**, also die Frage,
wie aus einem Pixel `(x, y)` ein LED-Index auf einem bestimmten Stripe wird.

Verbindliche Quellen im Repo:

| Thema | Datei |
| --- | --- |
| Speicherformat | `proto/ledato_stripes.proto` |
| Matrix-Adressierung (Referenzimplementierung) | `lib/model.dart` → `LedMatrix.ledIndexAt` |
| Matrix-Erzeugung (Geometrie, Mäander) | `lib/app_state.dart` → `createMatrix` |
| Effektberechnung | `lib/effects.dart` → `ledColor` |
| DDP-Dekodierung | `lib/ddp_server.dart` |
| Konfiguration im Klartext ansehen | `tools/dump_config.sh` |

---

## 1. Überblick

Die Firmware hat drei Aufgaben:

1. **Konfiguration lesen** — eine `.ledato`-Datei (rohe Protobuf-Bytes,
   `ledato_stripes.Document`) parsen und validieren.
2. **Effekte rechnen** — pro Frame für jede LED eine Farbe bestimmen. Die
   Berechnung ist rein deterministisch aus (Konfiguration, LED-Index, Zeit),
   es gibt keinen Zustand pro LED.
3. **Ausgeben** — die Farben auf die physischen Ausgangskanäle schreiben.
   Jeder Stripe ist ein eigener Kanal mit eigener Einspeisung.

Optional dazu: **DDP-Empfang**, damit externe Software (z. B.
`tools/ddp_client.py`, ein Media-Server, eine Uhr-Anwendung) die gerechneten
Effekte übersteuern kann.

---

## 2. Konfigurationsdatei

* Die Datei enthält **rohe Protobuf-Bytes ohne Rahmen** — kein Header, keine
  Länge, keine Kompression. `Document::ParseFromArray(bytes, len)` genügt.
* `schema_version` ist aktuell **1**. Die Firmware sollte eine unbekannte,
  höhere Version ablehnen statt zu raten.
* Struktur: `Document` → `Page[]` → `Strip[]` + `Matrix[]`.
* `active_page_index` zeigt auf die Page, die beim Start laufen soll.
  Mehrere Pages = ein Player, der nach `Page.duration_ms` zur nächsten
  weiterschaltet.

Rein für die Anzeige in der App und für die Firmware **irrelevant**:
`scene_width_meters`, `scene_aspect`, `use_image_aspect`, `background_path`,
`background_dim`, `glow` sowie `Section.start_x`, `start_y`, `angle`. Diese
Felder beschreiben, *wo* die LEDs im Bild liegen — für die Ansteuerung zählt
nur die Reihenfolge.

---

## 3. Stripes und Adressierung

Ein `Strip` ist ein real durchverkabeltes Stück mit **einer** Einspeisung.
Seine LEDs werden über alle `Section`-Einträge hinweg **fortlaufend**
nummeriert:

```
Globaler Index eines Stripes:
  Section 0: 0 .. led_count[0]-1
  Section 1: led_count[0] .. led_count[0]+led_count[1]-1
  ...
```

Die Sections müssen räumlich *nicht* zusammenhängen (Lücke hinter einem
Schrank, Ecke ohne Sichtbezug) — elektrisch sind sie ein Stripe.

**Kanalzuordnung:** Die Position des Stripes in `Page.strips` + 1 ist seine
Adresse, sowohl als Ausgangskanal als auch als DDP-`destination`
(`destination N ⇒ strips[N-1]`, siehe `lib/ddp_server.dart`).

Grenzen aus `lib/model.dart`: max. **8 Stripes**, max. **300 LEDs pro
Stripe**, LED-Dichten **30 / 60 / 144** pro Meter.

---

## 4. Matrix-Konfiguration

### 4.1 Was eine Matrix ist — und was nicht

Eine Matrix ist **kein eigener Objekttyp**. Sie besteht aus ganz normalen
Stripes: jede Zeile ist eine `Section`, die Zeilen liegen im Abstand
`1 / leds_per_meter` Meter übereinander. Die `Matrix`-Nachricht steht
*neben* diesen Stripes und sagt nur eines: **wie die fortlaufenden
LED-Indizes der beteiligten Stripes als Pixelfläche zu lesen sind.**

Die Aufgabenteilung:

* **Stripes + Sections** halten die Geometrie (wo jede Zeile in der Szene
  liegt). Sie bleiben frei verschiebbar.
* **Matrix** hält die logische Struktur, die ein Controller braucht, um
  `(x, y)` auf einen LED-Index abzubilden.

Damit ist die `Matrix`-Nachricht die eigentliche Schnittstelle zur Firmware.

### 4.2 Felder

```proto
message Matrix {
  string id = 1;
  string name = 2;
  uint32 columns = 3;         // Breite in Pixeln
  uint32 rows = 4;            // Höhe in Pixeln (über alle Stripes)
  MatrixWiring wiring = 5;    // SERPENTINE (Mäander) | PROGRESSIVE
  MatrixOrigin origin = 6;    // Ecke von Zeile 0 / Spalte 0
  uint32 leds_per_meter = 7;  // zugleich der Pixelabstand
  repeated MatrixBank banks = 8;
}

message MatrixBank {
  string strip_id = 1;   // verweist auf Strip.id in derselben Page
  uint32 first_row = 2;  // erste Matrixzeile dieses Stripes
  uint32 row_count = 3;  // Anzahl Zeilen dieses Stripes
}
```

* `leds_per_meter` ist die Dichte **aller** beteiligten Stripes und zugleich
  der Pixelabstand: Zeilenabstand = Spaltenabstand = `1 / leds_per_meter`
  Meter. Die Pixel sind also quadratisch.
* `banks` sind die Stripes der Matrix, **von der Ursprungsecke weg
  gestapelt**. Ein Bank-Eintrag ist ein zusammenhängender Zeilenblock.

### 4.3 Bänke: jeder Stripe zählt bei 0

Der entscheidende Punkt: **der LED-Index ist bankweise.** Er beginnt in
jedem Stripe wieder bei 0 — passend dazu, dass jeder Stripe seine eigene
Einspeisung hat. Es gibt keinen matrixweiten fortlaufenden Index.

Ebenso ist die **Mäander-Parität bankweise**: sie richtet sich nach der
Zeile *innerhalb des Stripes* (`local`), nicht nach der globalen Matrixzeile.
Ein Stripe, der bei `first_row = 4` beginnt, läuft in seiner lokalen Zeile 0
also **vorwärts**, obwohl 4 eine gerade globale Zeile ist. Physisch heißt
das: jeder Stripe wird an derselben Kante eingespeist.

### 4.4 Adressierung — der Algorithmus

Für ein Pixel `(x, y)` in Matrixkoordinaten (Ursprung = `origin`-Ecke):

```
1. Bereich prüfen:  0 <= x < columns,  0 <= y < rows
2. Bank finden:     die Bank mit  first_row <= y < first_row + row_count
3. Lokale Zeile:    local = y - first_row
4. Richtung:        backwards = (wiring == SERPENTINE) && (local ungerade)
5. Spalte:          col = backwards ? columns - 1 - x : x
6. Index:           index = local * columns + col
```

Ergebnis ist das Paar **(Bank, Index)** — also *welcher Stripe* und
*welche LED auf diesem Stripe*. Die Referenzimplementierung steht in
`lib/model.dart` als `LedMatrix.ledIndexAt`.

Als C:

```c
typedef struct { int bank; int index; } led_addr_t;

// Gibt 0 zurück, wenn (x,y) außerhalb liegt oder keine Bank die Zeile deckt.
int matrix_led_at(const matrix_t *m, int x, int y, led_addr_t *out) {
    if (x < 0 || x >= m->columns || y < 0 || y >= m->rows) return 0;
    for (int b = 0; b < m->bank_count; b++) {
        const bank_t *bk = &m->banks[b];
        if (y < bk->first_row || y >= bk->first_row + bk->row_count) continue;
        int local     = y - bk->first_row;
        int backwards = (m->wiring == MATRIX_WIRING_SERPENTINE) && (local & 1);
        int col       = backwards ? m->columns - 1 - x : x;
        out->bank  = b;
        out->index = local * m->columns + col;
        return 1;
    }
    return 0;
}
```

### 4.5 Verdrahtungsarten

* **`MATRIX_WIRING_SERPENTINE` (Mäander, Default)** — jede zweite Zeile eines
  Stripes läuft rückwärts, das Kabel schlängelt sich ohne Rückleitung durch
  den Block. Das ist die Verdrahtung, die die App beim Erzeugen einer Matrix
  anlegt: sie setzt die ungeraden Zeilen auf Winkel 180° und lässt sie an der
  rechten Kante beginnen, sodass der fortlaufende LED-Index exakt dem realen
  Kabelverlauf folgt.
* **`MATRIX_WIRING_PROGRESSIVE` (Zeilenweise)** — jede Zeile beginnt an
  derselben Kante, zwischen den Zeilen liegt eine Rückleitung. `backwards`
  ist dann immer falsch.

> Hinweis: Die App dreht die Zeilen bewusst über den **Winkel** der Section,
> nicht über `Section.reversed`. `reversed` dreht nur die Farbberechnung, nicht
> die Position der LEDs — es über `reversed` zu lösen würde die Adressierung
> (auch die über DDP) falsch machen.

### 4.6 Ursprungsecke

`origin` sagt, in welcher **physischen** Ecke Zeile 0 / Spalte 0 liegt und in
welcher der erste Stripe eingespeist wird. Die Matrixkoordinaten `(x, y)` im
Algorithmus oben sind immer relativ zu dieser Ecke.

Hat die Firmware Bildinhalt in der üblichen Bildschirmkonvention (Ursprung
oben links, `W = columns`, `H = rows`), rechnet sie vor der Adressierung um:

| `origin` | `x` | `y` |
| --- | --- | --- |
| `TOP_LEFT` | `sx` | `sy` |
| `TOP_RIGHT` | `W-1-sx` | `sy` |
| `BOTTOM_LEFT` | `sx` | `H-1-sy` |
| `BOTTOM_RIGHT` | `W-1-sx` | `H-1-sy` |

**Stand heute:** Der Matrix-Dialog der App (`lib/main.dart`,
`_showMatrixDialog`) fragt nur Spalten, Zeilen, Stripe-Anzahl und Dichte ab.
`createMatrix` schreibt deshalb immer `SERPENTINE` + `TOP_LEFT`. Die Firmware
sollte die anderen Werte trotzdem korrekt behandeln — das Format sieht sie
vor, und sie werden nachgereicht, sobald die UI sie anbietet.

### 4.7 Validierung beim Laden

Die Firmware sollte eine Matrix ablehnen (oder als gewöhnliche Stripes
behandeln), wenn:

* eine `strip_id` in `Page.strips` nicht auflösbar ist;
* die Bänke die Zeilen nicht **lückenlos und überschneidungsfrei** abdecken,
  also `Σ row_count != rows` gilt oder eine Zeile doppelt/gar nicht vorkommt;
* die LED-Anzahl eines Stripes nicht zu seinem Block passt:
  `Σ Section.led_count != columns * row_count`;
* `Strip.leds_per_meter` einer Bank von `Matrix.leds_per_meter` abweicht;
* `columns * row_count > 300` (Maximum pro Stripe).

### 4.8 Beispiel

`matrix.ledato` im Repo enthält eine 64×16-Matrix aus 4 Stripes à 4 Zeilen
(256 LEDs pro Stripe):

```
matrices {
  name: "Matrix 64×16"
  columns: 64
  rows: 16
  leds_per_meter: 60
  banks { strip_id: "..._0"  first_row: 0   row_count: 4 }
  banks { strip_id: "..._1"  first_row: 4   row_count: 4 }
  banks { strip_id: "..._2"  first_row: 8   row_count: 4 }
  banks { strip_id: "..._3"  first_row: 12  row_count: 4 }
}
```

`wiring` und `origin` fehlen im Dump, weil proto3 Default-Werte nicht
schreibt — es gilt also `SERPENTINE` und `TOP_LEFT`.

Zwei Rechenbeispiele:

| Pixel | Bank | `local` | Richtung | `col` | Index |
| --- | --- | --- | --- | --- | --- |
| `(5, 6)` | 1 (Zeilen 4–7) | 2 | vorwärts | 5 | `2*64+5 = 133` |
| `(5, 7)` | 1 (Zeilen 4–7) | 3 | rückwärts | 58 | `3*64+58 = 250` |

Pixel `(5, 6)` liegt also auf dem **zweiten** Stripe der Matrix, LED 133.

> **Offener Punkt im Format:** Der Kommentar an `Matrix.banks` im Proto sagt
> „Die Position in dieser Liste + 1 ist die DDP-destination des Stripes." Das
> stimmt nur, solange die Matrix-Stripes die ersten Stripes der Page sind
> (`createMatrix` hängt sie hinten an). Verbindlich ist die Regel aus
> `lib/ddp_server.dart` / `AppState._onDdpFrame`: **Index des Stripes in
> `Page.strips` + 1**. Die Firmware sollte den Kanal deshalb über
> `MatrixBank.strip_id` → Position in `Page.strips` auflösen, nicht über die
> Bank-Position.

---

## 5. Effekte

`Section` trägt die vollständige Optik: `effect`, `color`, `color2`,
`brightness` (0..1), `speed` (0..1), `reversed`. Jeder Abschnitt läuft für
sich — wie ein eigener kleiner Stripe.

Farben stehen verlustfrei als **ARGB-uint32** in der Datei (nicht als
1-Byte-Palette). Der Alphakanal spielt für die Ausgabe keine Rolle;
`Strip.enabled == false` heißt „Stripe aus", nicht „transparent".

### 5.1 Durchlaufende Effekte

`Strip.continuous_effect` (Default `false`) lässt den Effekt über **alle**
Abschnitte hinweg laufen, als wäre der Stripe ein einziges langes Stück. Ein
Lauflicht wandert dann im Mäander durch die ganze Matrix, statt in jeder
Zeile neu zu beginnen. Konkret (siehe `lib/editor_canvas.dart` und
`lib/effects.dart`):

| | `continuous_effect = false` | `continuous_effect = true` |
| --- | --- | --- |
| `count` | `Section.led_count` | LEDs des ganzen Stripes |
| `index` | lokal im Abschnitt | global über den Stripe |
| `reversed` | aus dem Abschnitt | aus **Abschnitt 0** des Stripes |

Alle übrigen Parameter (Effekt, Farben, Helligkeit, Tempo) kommen weiterhin
aus dem jeweiligen Abschnitt. Matrizen, die die App anlegt, setzen
`continuous_effect = true`.

### 5.2 Gemeinsame Größen

```
speed_eff = 0.05 + speed * speed * 4.0        // nichtlinear, damit der Regler feinfühlig ist
i         = reversed ? n - 1 - index : index
pos       = (n == 1) ? 0.0 : i / (n - 1)      // 0..1 entlang des Abschnitts
Ausgabe   = farbe * brightness                // linear pro Kanal, am Ende
```

### 5.3 Effektformeln

`n` = `count`, `t` = Zeit in Sekunden, `s` = `speed_eff`.
`scale(c, v)` skaliert die RGB-Kanäle linear.

| Effekt | Formel |
| --- | --- |
| `SOLID` | `color` |
| `GRADIENT` | `lerp(color, color2, pos)` |
| `RAINBOW` | `hue = ((pos*1.5 - t*s*0.25) mod 1)`, HSV(hue, 1, 1) |
| `CHASE` | Kopf bei `(t*s*60) mod n`, Schweif `max(4, n*0.12)`, quadratisch abfallend, Sockel 0.03 |
| `THEATER` | jede dritte LED an: `i mod 3 == floor(t*s*8) mod 3`, sonst `scale(color, 0.04)` |
| `SCANNER` | Kopf pendelt über `(t*s*30) mod (2*(n-1))`, Gauß mit `sigma = max(1.2, n*0.02)`, Sockel 0.03 |
| `COLOR_WIPE` | `prog = (t*s*60) mod (2n)`; `color`/`color2` je nach Halbwelle |
| `WAVE` | `v = 0.5 + 0.5*sin(2π*(pos*3 - t*s*1.5))`, `lerp(color2, color, v)` |
| `BREATHE` | `v = 0.5 - 0.5*cos(t*s*π)`, `lerp(scale(color,0.05), color, v)` |
| `BLINK` | `floor(t*(0.5 + speed*4))` gerade → `color`, sonst `color2` |
| `STROBE` | Periode `1/(1 + speed*9)`, erste 15 % `color`, sonst `scale(color, 0.02)` |
| `SPARKLE` | Frame `floor(t*(2 + speed*20))`, `hash < 0.08` → voll, sonst 0.12 |
| `CONFETTI` | Rate `1 + speed*4`, `hash < 0.12` → zufälliger Farbton, über den Frame ausblendend |
| `FIRE` | Flackern `t*(4 + speed*12)`, zwischen zwei Hashes interpoliert, `heat = (1.1 - pos*0.7)*(0.35 + 0.65*flicker)`, feste Palette schwarz→rot→orange→weiß |

Beachte: `BLINK`, `STROBE`, `SPARKLE`, `CONFETTI` und `FIRE` rechnen mit dem
**rohen** `speed`-Wert aus der Section, nicht mit `speed_eff` — in der Tabelle
oben steht dort entsprechend `speed` statt `s`.

### 5.4 Zufallseffekte: bewusste Abweichung

`SPARKLE`, `CONFETTI` und `FIRE` ziehen in der App einen Seed aus
`hashCode` des Stripe- bzw. Section-Objekts. Das ist in Dart die
Identitäts-Hash — sie ändert sich **bei jedem Programmstart**. Diese Effekte
sind zwischen App und Firmware (und sogar zwischen zwei App-Starts) deshalb
grundsätzlich nicht Frame-für-Frame gleich; nur ihr Charakter stimmt überein.

Die Firmware soll dafür einen **stabilen** Seed verwenden, z. B. den Index
des Stripes bzw. der Section in der Konfiguration. Die Hashfunktion selbst
ist portierbar (32-Bit-Ganzzahlarithmetik, siehe `_hash` in
`lib/effects.dart`).

---

## 6. DDP

DDP (Distributed Display Protocol, <http://www.3waylabs.com/ddp/>), UDP,
Standardport **4048**. Die App implementiert die Empfängerseite in
`lib/ddp_server.dart`; die Firmware braucht dieselbe Dekodierung.

Header (10 Byte):

| Byte | Inhalt |
| --- | --- |
| 0 | Flags: `0x40` Version 1, `0x01` PUSH, `0x10` Timecode folgt, `0x02` Query, `0x04` Reply |
| 1 | Sequenznummer (0 = deaktiviert) |
| 2 | Datentyp, z. B. `0x0B` = RGB24. Bits 3–5 = Kanäle pro Pixel, `0b011` = RGBW |
| 3 | Zieladresse |
| 4–7 | Kanal-Offset in **Byte** (big endian) |
| 8–9 | Datenlänge in Byte (big endian) |

Danach, falls Flag `0x10` gesetzt, 4 Byte Timecode (wird ignoriert), dann die
Nutzdaten.

Regeln:

* Pakete mit Query- oder Reply-Flag werden ignoriert.
* Gültige Zieladressen sind **1..245**. Reserviert: 0 (ungültig), 246/250/251
  (JSON-Steuerung/-Konfiguration/-Status, nicht implementiert), 255 (alle
  Geräte).
* `pixel_start = channel_offset / bytes_per_pixel`,
  `pixel_count = data_len / bytes_per_pixel`.
* Ein Stripe kann über mehrere Pakete kommen (max. 480 Pixel bzw. 1440 Byte
  Nutzlast pro Paket) — bei max. 300 LEDs praktisch nie nötig.

**Übersteuerung:** Empfangene Farben ersetzen die gerechneten Effektfarben.
In der App verfallen sie nach **2 Sekunden** ohne neues Paket
(`AppState.ddpStaleTimeout`), danach übernimmt wieder der Effekt. Ein
DDP-Sender muss also kontinuierlich senden, nicht nur einmal.

**Matrix über DDP:** Ein Sender adressiert keine Matrix, sondern Stripes. Er
rechnet `(x, y)` mit dem Algorithmus aus Abschnitt 4.4 auf `(Bank, Index)`
um, bildet die Bank auf die `destination` des Stripes ab und schickt pro
Stripe ein Paket mit `columns * row_count` Pixeln.

---

## 7. Empfohlener Aufbau

```
Start
 ├─ Konfiguration laden        Document parsen, schema_version prüfen
 ├─ Validieren                 Abschnitt 4.7; ungültige Matrizen verwerfen
 ├─ Adresstabelle bauen        einmalig (x,y) → (Kanal, LED) für jede Matrix,
 │                             damit der Renderpfad keine Bank-Suche macht
 └─ Renderschleife  (z. B. 30–60 fps)
     ├─ t fortschreiben
     ├─ pro Stripe, pro Section: Farbe je LED (Abschnitt 5)
     ├─ DDP-Übersteuerung anwenden, solange nicht älter als 2 s
     ├─ Framebuffer ausgeben
     └─ Page wechseln, wenn duration_ms abgelaufen (nur bei mehreren Pages)
```

Die Adresstabelle lohnt sich: `columns * rows` Einträge à 2 Byte reichen für
64×16 = 1024 Pixel, und der Renderpfad wird ein reiner Tabellenzugriff.

---

## 8. Offene Punkte

* **2D-Effekte** gibt es im Format noch nicht. Effekte sind heute
  eindimensional entlang eines Abschnitts bzw. — mit `continuous_effect` —
  entlang des ganzen Stripes. Ein Effekt, der eine Matrix als Fläche
  behandelt (Plasma, Laufschrift, Bild), braucht eine Erweiterung des
  Schemas; `Matrix` liefert dafür bereits die vollständige `(x, y)`-Abbildung.
* **`origin` und `wiring`** werden von der App noch nicht angeboten (siehe
  4.6). Die Firmware sollte sie trotzdem auswerten.
* **Kanalzuordnung der Bänke** — die Doppeldeutigkeit aus Abschnitt 4.8
  sollte im Proto-Kommentar geradegezogen werden.
* **`Matrix.name` und `Matrix.id`** sind reine Anzeige-/Referenzfelder; die
  Firmware braucht sie nur zum Loggen.
