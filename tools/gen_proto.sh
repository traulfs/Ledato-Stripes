#!/usr/bin/env bash
# Generiert die Dart-Protobuf-Klassen aus proto/ledato_stripes.proto neu.
# Voraussetzungen (einmalig):
#   brew install protobuf
#   dart pub global activate protoc_plugin
#   export PATH="$PATH:$HOME/.pub-cache/bin"
set -euo pipefail
cd "$(dirname "$0")/.."

protoc \
  --dart_out=lib/protobuf \
  --proto_path=proto \
  proto/ledato_stripes.proto

echo "Generiert nach lib/protobuf/."
