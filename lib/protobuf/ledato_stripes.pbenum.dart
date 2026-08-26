// This is a generated file - do not edit.
//
// Generated from ledato_stripes.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class MatrixWiring extends $pb.ProtobufEnum {
  /// Mäander: jede zweite Zeile eines Stripes läuft rückwärts, das Kabel
  /// schlängelt sich ohne Rückleitung durch den Block.
  static const MatrixWiring MATRIX_WIRING_SERPENTINE =
      MatrixWiring._(0, _omitEnumNames ? '' : 'MATRIX_WIRING_SERPENTINE');

  /// Jede Zeile beginnt an derselben Kante, zwischen den Zeilen liegt eine
  /// Rückleitung.
  static const MatrixWiring MATRIX_WIRING_PROGRESSIVE =
      MatrixWiring._(1, _omitEnumNames ? '' : 'MATRIX_WIRING_PROGRESSIVE');

  static const $core.List<MatrixWiring> values = <MatrixWiring>[
    MATRIX_WIRING_SERPENTINE,
    MATRIX_WIRING_PROGRESSIVE,
  ];

  static final $core.List<MatrixWiring?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static MatrixWiring? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MatrixWiring._(super.value, super.name);
}

/// Ecke, in der Zeile 0 / Spalte 0 liegt und in der der erste Stripe
/// eingespeist wird.
class MatrixOrigin extends $pb.ProtobufEnum {
  static const MatrixOrigin MATRIX_ORIGIN_TOP_LEFT =
      MatrixOrigin._(0, _omitEnumNames ? '' : 'MATRIX_ORIGIN_TOP_LEFT');
  static const MatrixOrigin MATRIX_ORIGIN_TOP_RIGHT =
      MatrixOrigin._(1, _omitEnumNames ? '' : 'MATRIX_ORIGIN_TOP_RIGHT');
  static const MatrixOrigin MATRIX_ORIGIN_BOTTOM_LEFT =
      MatrixOrigin._(2, _omitEnumNames ? '' : 'MATRIX_ORIGIN_BOTTOM_LEFT');
  static const MatrixOrigin MATRIX_ORIGIN_BOTTOM_RIGHT =
      MatrixOrigin._(3, _omitEnumNames ? '' : 'MATRIX_ORIGIN_BOTTOM_RIGHT');

  static const $core.List<MatrixOrigin> values = <MatrixOrigin>[
    MATRIX_ORIGIN_TOP_LEFT,
    MATRIX_ORIGIN_TOP_RIGHT,
    MATRIX_ORIGIN_BOTTOM_LEFT,
    MATRIX_ORIGIN_BOTTOM_RIGHT,
  ];

  static final $core.List<MatrixOrigin?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static MatrixOrigin? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MatrixOrigin._(super.value, super.name);
}

class Effect extends $pb.ProtobufEnum {
  static const Effect EFFECT_SOLID =
      Effect._(0, _omitEnumNames ? '' : 'EFFECT_SOLID');
  static const Effect EFFECT_GRADIENT =
      Effect._(1, _omitEnumNames ? '' : 'EFFECT_GRADIENT');
  static const Effect EFFECT_RAINBOW =
      Effect._(2, _omitEnumNames ? '' : 'EFFECT_RAINBOW');
  static const Effect EFFECT_CHASE =
      Effect._(3, _omitEnumNames ? '' : 'EFFECT_CHASE');
  static const Effect EFFECT_THEATER =
      Effect._(4, _omitEnumNames ? '' : 'EFFECT_THEATER');
  static const Effect EFFECT_SCANNER =
      Effect._(5, _omitEnumNames ? '' : 'EFFECT_SCANNER');
  static const Effect EFFECT_COLOR_WIPE =
      Effect._(6, _omitEnumNames ? '' : 'EFFECT_COLOR_WIPE');
  static const Effect EFFECT_WAVE =
      Effect._(7, _omitEnumNames ? '' : 'EFFECT_WAVE');
  static const Effect EFFECT_BREATHE =
      Effect._(8, _omitEnumNames ? '' : 'EFFECT_BREATHE');
  static const Effect EFFECT_BLINK =
      Effect._(9, _omitEnumNames ? '' : 'EFFECT_BLINK');
  static const Effect EFFECT_STROBE =
      Effect._(10, _omitEnumNames ? '' : 'EFFECT_STROBE');
  static const Effect EFFECT_SPARKLE =
      Effect._(11, _omitEnumNames ? '' : 'EFFECT_SPARKLE');
  static const Effect EFFECT_CONFETTI =
      Effect._(12, _omitEnumNames ? '' : 'EFFECT_CONFETTI');
  static const Effect EFFECT_FIRE =
      Effect._(13, _omitEnumNames ? '' : 'EFFECT_FIRE');

  static const $core.List<Effect> values = <Effect>[
    EFFECT_SOLID,
    EFFECT_GRADIENT,
    EFFECT_RAINBOW,
    EFFECT_CHASE,
    EFFECT_THEATER,
    EFFECT_SCANNER,
    EFFECT_COLOR_WIPE,
    EFFECT_WAVE,
    EFFECT_BREATHE,
    EFFECT_BLINK,
    EFFECT_STROBE,
    EFFECT_SPARKLE,
    EFFECT_CONFETTI,
    EFFECT_FIRE,
  ];

  static final $core.List<Effect?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 13);
  static Effect? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Effect._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
