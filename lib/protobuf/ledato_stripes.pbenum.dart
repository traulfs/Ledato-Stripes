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
