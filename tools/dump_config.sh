#!/usr/bin/env bash
# Zeigt eine .ledato-Konfiguration in lesbarer Textform an.
#
# Die Datei enthält rohe Protobuf-Bytes ohne Rahmen (siehe proto_mapper.dart),
# protoc kann sie also direkt mit dem Schema dekodieren.
#
# Voraussetzung:  brew install protobuf
#
# Beispiele:
#   tools/dump_config.sh Clock1.ledato
#   tools/dump_config.sh                       # die Autosave-Datei der App
#   tools/dump_config.sh Clock1.ledato | grep -A8 'matrices'
set -euo pipefail
cd "$(dirname "$0")/.."

# Ohne Argument: die Konfiguration, die die macOS-App automatisch speichert.
default_config="$HOME/Library/Containers/de.taskit.ledatoStripes/Data/Library/Application Support/de.taskit.ledatoStripes/ledato_stripes_config.ledato"
file="${1:-$default_config}"

if [[ ! -f "$file" ]]; then
  echo "Datei nicht gefunden: $file" >&2
  exit 1
fi

protoc \
  --decode=ledato_stripes.Document \
  --proto_path=proto \
  proto/ledato_stripes.proto \
  < "$file"
