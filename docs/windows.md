# Windows-Version

Die App läuft auf Windows aus derselben Codebasis wie auf macOS, iOS und
Android — plattformspezifisch ist nur der Runner unter `windows/` und das,
was unten unter „Unterschiede zu macOS" steht.

## Voraussetzungen

Auf dem Windows-Rechner, der baut:

* Windows 10 (1809 oder neuer) oder Windows 11, 64-bit
* **Visual Studio 2022** mit der Arbeitslast **„Desktopentwicklung mit C++"**
  (enthält MSVC-Compiler, CMake und das Windows-SDK). Visual Studio *Code*
  genügt dafür nicht.
* Flutter SDK 3.44 oder neuer

Einmalig prüfen:

```powershell
flutter config --enable-windows-desktop
flutter doctor -v
```

`flutter doctor` muss „Visual Studio - develop Windows apps" mit Häkchen
zeigen.

## Bauen und starten

```powershell
flutter pub get
flutter run -d windows                 # Debug, mit Hot Reload
flutter build windows --release        # Release-Build
```

Das Ergebnis liegt in:

```
build\windows\x64\runner\Release\
├─ ledato_stripes.exe
├─ flutter_windows.dll
├─ file_selector_windows_plugin.dll
├─ share_plus_plugin.dll
├─ url_launcher_windows_plugin.dll
└─ data\                     Assets, Icudtl, AOT-Code
```

## Weitergabe

Weiterzugeben ist der **komplette Inhalt** des `Release`-Ordners — die
`.exe` allein läuft nicht. Auf dem Zielrechner muss außerdem das
**Visual C++ Redistributable** installiert sein (`msvcp140.dll`,
`vcruntime140.dll`, `vcruntime140_1.dll`); auf den meisten Windows-Systemen
ist es das ohnehin.

Ein Installer (MSIX, Inno Setup o. Ä.) ist bisher nicht eingerichtet.

## Unterschiede zu macOS

| | macOS | Windows |
| --- | --- | --- |
| Konfiguration (Autosave) | App-Sandbox-Container | `%APPDATA%\de.taskit\Ledato Stripes\ledato_stripes_config.ledato` |
| Sandbox | ja, mit Entitlements | nein |
| DDP-Server | Entitlement `network.server` | Firewall-Freigabe, siehe unten |
| Speichern/Öffnen | nativer Dialog | nativer Dialog (gleiches Verhalten) |
| Teilen-Dialog | nicht genutzt | nicht genutzt (nur iOS/Android) |

Den Autosave-Pfad bildet `path_provider_windows` aus **CompanyName** und
**ProductName** der Versionsressource in `windows/runner/Runner.rc`. Wer
diese Felder ändert, verschiebt damit auch den Speicherort der Konfiguration
— eine vorhandene Datei bleibt dann im alten Ordner liegen.

### Firewall und DDP

Der eingebaute DDP-Server lauscht auf **UDP 4048**. Beim ersten Start zeigt
Windows deshalb die Abfrage der Defender-Firewall; für den Empfang im
lokalen Netz muss mindestens **„Private Netzwerke"** freigegeben werden.
Ohne Freigabe startet der Server zwar, es kommen aber nur Pakete vom selben
Rechner an.

Nachträglich (PowerShell als Administrator):

```powershell
New-NetFirewallRule -DisplayName "Ledato Stripes DDP" `
  -Direction Inbound -Protocol UDP -LocalPort 4048 `
  -Profile Private -Action Allow
```

Die IP-Adressen, an die ein DDP-Sender schicken kann, zeigt die App im
Dialog „DDP-Server" an.

## App-Icon

Das Windows-Icon liegt als `windows/runner/resources/app_icon.ico` und wird
über `windows/runner/Runner.rc` in die `.exe` eingebettet. Neu erzeugen aus
`assets/icon/app_icon.png`:

```bash
python3 tools/make_windows_icon.py     # braucht: pip install pillow
```

Das Skript schreibt alle Größen von 16 bis 256 px in die `.ico`, damit
Windows in Titelleiste, Taskleiste und Explorer jeweils eine passende
Auflösung findet, statt aus 256 px herunterzuskalieren.

`dart run flutter_launcher_icons` erzeugt bewusst **nur** die Android- und
iOS-Icons (siehe Kommentar in `pubspec.yaml`) — es könnte in die `.ico` nur
eine einzige Größe schreiben.

## Werkzeuge unter `tools/`

* `ddp_client.py` — läuft unverändert, braucht nur Python 3.
* `dump_config.sh` — Bash-Skript; unter Windows über **Git Bash** oder WSL
  aufrufen. Der Standardpfad darin zeigt auf den macOS-Container; unter
  Windows die Datei explizit angeben:

  ```bash
  tools/dump_config.sh "$APPDATA/de.taskit/Ledato Stripes/ledato_stripes_config.ledato"
  ```

  Alternativ direkt mit `protoc`:

  ```powershell
  protoc --decode=ledato_stripes.Document --proto_path=proto proto\ledato_stripes.proto < datei.ledato
  ```

## Stand

Getestet ist bisher: `flutter analyze` und die Widget-Tests laufen sauber,
und der Dart-Code enthält keine plattformabhängigen Pfade oder Aufrufe. Der
C++-Runner selbst wurde **nicht kompiliert** — dafür ist ein Windows-Rechner
mit Visual Studio nötig.
