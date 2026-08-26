# Ledato Stripes

Konfigurator für LED-Stripes: Stripes und ihre Abschnitte frei über einem
Hintergrundbild platzieren, Effekte zuweisen, LED-Matrizen erzeugen und das
Ergebnis als `.ledato`-Konfiguration speichern. Läuft auf macOS, Windows,
iOS und Android.

```bash
flutter pub get
flutter run              # -d macos, -d windows, ...
flutter test
```

## Dokumentation

* [`docs/firmware.md`](docs/firmware.md) — was eine Controller-Firmware aus
  einer `.ledato`-Konfiguration lesen muss; Schwerpunkt Matrix-Adressierung
* [`docs/windows.md`](docs/windows.md) — Windows-Version bauen, weitergeben
  und was dort anders ist als auf macOS

## Werkzeuge

| Skript | Zweck |
| --- | --- |
| `tools/dump_config.sh` | `.ledato`-Konfiguration in lesbarer Textform anzeigen |
| `tools/ddp_client.py` | Test-Effekte per DDP an die App senden |
| `tools/ddp_clock.py`, `tools/ddp_clock2.py` | Uhr-Layouts über DDP ansteuern |
| `tools/make_windows_icon.py` | Windows-App-Icon aus `assets/icon/app_icon.png` erzeugen |
| `tools/gen_proto.sh` | Dart-Code aus `proto/ledato_stripes.proto` generieren |
