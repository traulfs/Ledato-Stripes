import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Color;

/// Standard-UDP-Port des DDP-Protokolls (Distributed Display Protocol),
/// wie u. a. von WLED, xLights und ähnlicher Lichtsteuerungs-Software
/// verwendet.
const int kDdpDefaultPort = 4048;

const int _headerLen = 10;
const int _flagTime = 0x10;
const int _flagReply = 0x04;
const int _flagQuery = 0x02;

// Reservierte Zieladressen (Byte 3 des Headers): 0 = ungültig, 246/250/251 =
// JSON-Steuerung/-Konfiguration/-Status (nicht implementiert), 255 = "alle
// Geräte". Für uns gültig bleiben nur 1..245 — die Stripe-Nummer.
const int _idControl = 246;
const int _idAll = 255;

/// Empfängt DDP-Pakete per UDP und reicht dekodierte Pixel-Frames über
/// [onFrame] weiter: Zieladresse (1-basiert, aus Byte 3 des Headers),
/// Start-Pixel-Index innerhalb dieses Ziels (aus dem Kanal-Offset) und die
/// dekodierten Farben. Kennt nichts von Stripes/Sections — reine
/// Protokoll-Dekodierung, unabhängig vom App-Zustand.
class DdpServer {
  DdpServer({required this.onFrame});

  final void Function(int destination, int pixelStart, List<Color> colors)
  onFrame;

  RawDatagramSocket? _socket;
  int _port = kDdpDefaultPort;

  bool get isRunning => _socket != null;
  int get port => _port;

  Future<void> start({int port = kDdpDefaultPort}) async {
    await stop();
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
    _port = _socket!.port;
    _socket!.listen(_onEvent);
  }

  Future<void> stop() async {
    _socket?.close();
    _socket = null;
  }

  void _onEvent(RawSocketEvent event) {
    final socket = _socket;
    if (socket == null || event != RawSocketEvent.read) return;
    final datagram = socket.receive();
    if (datagram != null) _handlePacket(datagram.data);
  }

  void _handlePacket(Uint8List bytes) {
    if (bytes.length < _headerLen) return;
    final flags = bytes[0];
    if (flags & (_flagQuery | _flagReply) != 0) return;

    final destination = bytes[3];
    if (destination < 1 || destination >= _idControl || destination == _idAll) {
      return;
    }

    final channelOffset =
        (bytes[4] << 24) | (bytes[5] << 16) | (bytes[6] << 8) | bytes[7];
    final dataLen = (bytes[8] << 8) | bytes[9];

    var dataStart = _headerLen;
    if (flags & _flagTime != 0) dataStart += 4; // Timecode, wird ignoriert
    if (bytes.length < dataStart + dataLen) return; // unvollständiges Paket

    // Kanalzahl pro Pixel aus dem Datentyp-Byte (siehe DDP-Spezifikation):
    // Bits 3-5 kodieren die Kanalanzahl, 0b011 = RGBW (4 Kanäle), sonst wird
    // von RGB (3 Kanäle) ausgegangen — deckt alle gängigen Sender ab.
    final dataType = bytes[2];
    final bytesPerPixel = ((dataType & 0x38) >> 3) == 0x3 ? 4 : 3;
    final pixelStart = channelOffset ~/ bytesPerPixel;
    final pixelCount = dataLen ~/ bytesPerPixel;
    if (pixelCount <= 0) return;

    final colors = List<Color>.generate(pixelCount, (i) {
      final p = dataStart + i * bytesPerPixel;
      return Color.fromARGB(255, bytes[p], bytes[p + 1], bytes[p + 2]);
    });
    onFrame(destination, pixelStart, colors);
  }
}
