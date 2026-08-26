import 'package:flutter/painting.dart' show Color, Offset;

import 'model.dart';
import 'protobuf/ledato_stripes.pb.dart' as pb;

/// Aktuelle Schema-Version des Speicherformats — bei künftigen inkompatiblen
/// Änderungen an [pb.Document] hochzählen und hier verzweigen.
const int kSchemaVersion = 1;

/// Verknüpft [EffectType] und das generierte Protobuf-Enum [pb.Effect] über
/// den Namen (nicht die Ordinalzahl) — bleibt so robust, falls [EffectType]
/// in model.dart später umsortiert wird.
const Map<EffectType, pb.Effect> _effectToProto = {
  EffectType.solid: pb.Effect.EFFECT_SOLID,
  EffectType.gradient: pb.Effect.EFFECT_GRADIENT,
  EffectType.rainbow: pb.Effect.EFFECT_RAINBOW,
  EffectType.chase: pb.Effect.EFFECT_CHASE,
  EffectType.theater: pb.Effect.EFFECT_THEATER,
  EffectType.scanner: pb.Effect.EFFECT_SCANNER,
  EffectType.colorWipe: pb.Effect.EFFECT_COLOR_WIPE,
  EffectType.wave: pb.Effect.EFFECT_WAVE,
  EffectType.breathe: pb.Effect.EFFECT_BREATHE,
  EffectType.blink: pb.Effect.EFFECT_BLINK,
  EffectType.strobe: pb.Effect.EFFECT_STROBE,
  EffectType.sparkle: pb.Effect.EFFECT_SPARKLE,
  EffectType.confetti: pb.Effect.EFFECT_CONFETTI,
  EffectType.fire: pb.Effect.EFFECT_FIRE,
};

final Map<pb.Effect, EffectType> _effectFromProto = {
  for (final entry in _effectToProto.entries) entry.value: entry.key,
};

pb.Section sectionToProto(StripSection sec) => pb.Section(
  startX: sec.start.dx,
  startY: sec.start.dy,
  angle: sec.angle,
  ledCount: sec.ledCount,
  effect: _effectToProto[sec.effect] ?? pb.Effect.EFFECT_SOLID,
  color: sec.color.toARGB32(),
  color2: sec.color2.toARGB32(),
  brightness: sec.brightness,
  speed: sec.speed,
  reversed: sec.reversed,
);

StripSection sectionFromProto(pb.Section p) => StripSection(
  start: Offset(p.startX, p.startY),
  angle: p.angle,
  ledCount: p.ledCount,
  effect: _effectFromProto[p.effect] ?? EffectType.solid,
  color: Color(p.color),
  color2: Color(p.color2),
  brightness: p.brightness,
  speed: p.speed,
  reversed: p.reversed,
);

pb.Strip stripToProto(LedStrip s) => pb.Strip(
  id: s.id,
  name: s.name,
  ledsPerMeter: s.ledsPerMeter,
  enabled: s.enabled,
  sections: [for (final sec in s.sections) sectionToProto(sec)],
  continuousEffect: s.continuousEffect,
);

LedStrip stripFromProto(pb.Strip p) => LedStrip(
  id: p.id,
  name: p.name,
  ledsPerMeter: p.ledsPerMeter,
  enabled: p.enabled,
  sections: [for (final sec in p.sections) sectionFromProto(sec)],
  continuousEffect: p.continuousEffect,
);

pb.Page pageToProto(LedPage page) => pb.Page(
  id: page.id,
  name: page.name,
  durationMs: page.durationMs,
  sceneWidthMeters: page.sceneWidthMeters,
  sceneAspect: page.sceneAspect,
  useImageAspect: page.useImageAspect,
  backgroundPath: page.backgroundPath ?? '',
  backgroundDim: page.backgroundDim,
  glow: page.glow,
  strips: [for (final s in page.strips) stripToProto(s)],
);

LedPage pageFromProto(pb.Page p) => LedPage(
  id: p.id,
  name: p.name,
  durationMs: p.durationMs,
  sceneWidthMeters: p.sceneWidthMeters,
  sceneAspect: p.sceneAspect,
  useImageAspect: p.useImageAspect,
  backgroundPath: p.backgroundPath.isEmpty ? null : p.backgroundPath,
  backgroundDim: p.backgroundDim,
  glow: p.glow,
  strips: [for (final s in p.strips) stripFromProto(s)],
);

pb.Document documentToProto(List<LedPage> pages, int activePageIndex) =>
    pb.Document(
      schemaVersion: kSchemaVersion,
      activePageIndex: activePageIndex,
      pages: [for (final page in pages) pageToProto(page)],
    );

/// Liest ein geparstes [pb.Document] in Pages + aktiven Index zurück (ohne
/// Hintergrundbild selbst zu laden — das erledigt der Aufrufer anschließend
/// anhand von [LedPage.backgroundPath]).
({List<LedPage> pages, int activePageIndex}) documentFromProto(
  pb.Document doc,
) => (
  pages: [for (final p in doc.pages) pageFromProto(p)],
  activePageIndex: doc.activePageIndex,
);
