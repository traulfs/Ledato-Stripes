import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledato_stripes/ddp_server.dart';

/// Baut ein reales DDP-Paket (10-Byte-Header + RGB24-Daten) wie es z. B.
/// xLights oder WLED senden würden.
Uint8List _ddpPacket({
  required int destination,
  required int channelOffset,
  required List<List<int>> rgbPixels,
  bool push = true,
  bool query = false,
}) {
  final data = Uint8List(rgbPixels.length * 3);
  for (var i = 0; i < rgbPixels.length; i++) {
    data[i * 3] = rgbPixels[i][0];
    data[i * 3 + 1] = rgbPixels[i][1];
    data[i * 3 + 2] = rgbPixels[i][2];
  }
  final flags = 0x40 | (push ? 0x01 : 0) | (query ? 0x02 : 0);
  final packet = Uint8List(10 + data.length)
    ..[0] = flags
    ..[1] =
        0 // sequenceNum
    ..[2] =
        0x0B // DDP_TYPE_RGB24
    ..[3] = destination
    ..[4] = (channelOffset >> 24) & 0xff
    ..[5] = (channelOffset >> 16) & 0xff
    ..[6] = (channelOffset >> 8) & 0xff
    ..[7] = channelOffset & 0xff
    ..[8] = (data.length >> 8) & 0xff
    ..[9] = data.length & 0xff;
  packet.setRange(10, 10 + data.length, data);
  return packet;
}

/// Schickt [packet] so lange, bis [frames] einen Eintrag hat oder die Frist
/// abläuft. UDP darf Pakete verwerfen: ohne Wiederholung hängt der Test an
/// einer einzigen Zustellung, und genau die ist im Windows-CI schon
/// ausgeblieben. Mehrfach empfangene Kopien sind unkritisch — geprüft wird,
/// dass *nur* das erlaubte Paket durchkommt, nicht wie oft.
Future<void> _sendUntilReceived(
  RawDatagramSocket sender,
  Uint8List packet,
  DdpServer server,
  List<(int, int, List<Color>)> frames,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (frames.isEmpty && DateTime.now().isBefore(deadline)) {
    sender.send(packet, InternetAddress.loopbackIPv4, server.port);
    await Future.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  test(
    'DdpServer dekodiert ein echtes DDP-Paket (Ziel, Offset, Farben)',
    () async {
      final frames = <(int, int, List<Color>)>[];
      final server = DdpServer(
        onFrame: (dest, start, colors) => frames.add((dest, start, colors)),
      );
      await server.start(port: 0);
      addTearDown(server.stop);

      final sender = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      addTearDown(sender.close);

      final packet = _ddpPacket(
        destination: 3,
        channelOffset: 0,
        rgbPixels: [
          [255, 0, 0],
          [0, 255, 0],
          [0, 0, 255],
        ],
      );
      await _sendUntilReceived(sender, packet, server, frames);

      expect(frames, isNotEmpty);
      final (dest, start, colors) = frames.first;
      expect(dest, 3);
      expect(start, 0);
      expect(colors, [
        const Color.fromARGB(255, 255, 0, 0),
        const Color.fromARGB(255, 0, 255, 0),
        const Color.fromARGB(255, 0, 0, 255),
      ]);
    },
  );

  test(
    'DdpServer respektiert den Kanal-Offset (Fortsetzung eines Frames)',
    () async {
      final frames = <(int, int, List<Color>)>[];
      final server = DdpServer(
        onFrame: (dest, start, colors) => frames.add((dest, start, colors)),
      );
      await server.start(port: 0);
      addTearDown(server.stop);

      final sender = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      addTearDown(sender.close);

      // Offset in Bytes: Pixel 5 beginnt bei Byte 15 (5 * 3 Kanäle).
      final packet = _ddpPacket(
        destination: 1,
        channelOffset: 15,
        rgbPixels: [
          [10, 20, 30],
        ],
      );
      await _sendUntilReceived(sender, packet, server, frames);

      expect(frames, isNotEmpty);
      final (dest, start, colors) = frames.first;
      expect(dest, 1);
      expect(start, 5);
      expect(colors, [const Color.fromARGB(255, 10, 20, 30)]);
    },
  );

  test(
    'DdpServer verwirft Query-/Reply-Pakete und reservierte Zieladressen',
    () async {
      final frames = <(int, int, List<Color>)>[];
      final server = DdpServer(
        onFrame: (dest, start, colors) => frames.add((dest, start, colors)),
      );
      await server.start(port: 0);
      addTearDown(server.stop);

      final sender = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      addTearDown(sender.close);

      // Query-Paket (Auto-Discovery) — muss ignoriert werden.
      sender.send(
        _ddpPacket(
          destination: 1,
          channelOffset: 0,
          rgbPixels: [
            [1, 2, 3],
          ],
          query: true,
        ),
        InternetAddress.loopbackIPv4,
        server.port,
      );
      // Reservierte Zieladresse (JSON-Status) — muss ignoriert werden.
      sender.send(
        _ddpPacket(
          destination: 251,
          channelOffset: 0,
          rgbPixels: [
            [1, 2, 3],
          ],
        ),
        InternetAddress.loopbackIPv4,
        server.port,
      );
      // Gültiges Paket zur Kontrolle, damit wir wissen, dass wir lange genug
      // gewartet haben.
      final control = _ddpPacket(
        destination: 2,
        channelOffset: 0,
        rgbPixels: [
          [9, 9, 9],
        ],
      );
      await _sendUntilReceived(sender, control, server, frames);

      // Angekommen sein darf ausschließlich das Kontrollpaket: die beiden
      // davor gesendeten müssen verworfen worden sein, egal wie oft das
      // Kontrollpaket wiederholt wurde.
      expect(frames, isNotEmpty);
      expect(frames.map((f) => f.$1), everyElement(2));
    },
  );
}
