// This is a generated file - do not edit.
//
// Generated from ledato_stripes.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use matrixWiringDescriptor instead')
const MatrixWiring$json = {
  '1': 'MatrixWiring',
  '2': [
    {'1': 'MATRIX_WIRING_SERPENTINE', '2': 0},
    {'1': 'MATRIX_WIRING_PROGRESSIVE', '2': 1},
  ],
};

/// Descriptor for `MatrixWiring`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List matrixWiringDescriptor = $convert.base64Decode(
    'CgxNYXRyaXhXaXJpbmcSHAoYTUFUUklYX1dJUklOR19TRVJQRU5USU5FEAASHQoZTUFUUklYX1'
    'dJUklOR19QUk9HUkVTU0lWRRAB');

@$core.Deprecated('Use matrixOriginDescriptor instead')
const MatrixOrigin$json = {
  '1': 'MatrixOrigin',
  '2': [
    {'1': 'MATRIX_ORIGIN_TOP_LEFT', '2': 0},
    {'1': 'MATRIX_ORIGIN_TOP_RIGHT', '2': 1},
    {'1': 'MATRIX_ORIGIN_BOTTOM_LEFT', '2': 2},
    {'1': 'MATRIX_ORIGIN_BOTTOM_RIGHT', '2': 3},
  ],
};

/// Descriptor for `MatrixOrigin`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List matrixOriginDescriptor = $convert.base64Decode(
    'CgxNYXRyaXhPcmlnaW4SGgoWTUFUUklYX09SSUdJTl9UT1BfTEVGVBAAEhsKF01BVFJJWF9PUk'
    'lHSU5fVE9QX1JJR0hUEAESHQoZTUFUUklYX09SSUdJTl9CT1RUT01fTEVGVBACEh4KGk1BVFJJ'
    'WF9PUklHSU5fQk9UVE9NX1JJR0hUEAM=');

@$core.Deprecated('Use effectDescriptor instead')
const Effect$json = {
  '1': 'Effect',
  '2': [
    {'1': 'EFFECT_SOLID', '2': 0},
    {'1': 'EFFECT_GRADIENT', '2': 1},
    {'1': 'EFFECT_RAINBOW', '2': 2},
    {'1': 'EFFECT_CHASE', '2': 3},
    {'1': 'EFFECT_THEATER', '2': 4},
    {'1': 'EFFECT_SCANNER', '2': 5},
    {'1': 'EFFECT_COLOR_WIPE', '2': 6},
    {'1': 'EFFECT_WAVE', '2': 7},
    {'1': 'EFFECT_BREATHE', '2': 8},
    {'1': 'EFFECT_BLINK', '2': 9},
    {'1': 'EFFECT_STROBE', '2': 10},
    {'1': 'EFFECT_SPARKLE', '2': 11},
    {'1': 'EFFECT_CONFETTI', '2': 12},
    {'1': 'EFFECT_FIRE', '2': 13},
  ],
};

/// Descriptor for `Effect`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List effectDescriptor = $convert.base64Decode(
    'CgZFZmZlY3QSEAoMRUZGRUNUX1NPTElEEAASEwoPRUZGRUNUX0dSQURJRU5UEAESEgoORUZGRU'
    'NUX1JBSU5CT1cQAhIQCgxFRkZFQ1RfQ0hBU0UQAxISCg5FRkZFQ1RfVEhFQVRFUhAEEhIKDkVG'
    'RkVDVF9TQ0FOTkVSEAUSFQoRRUZGRUNUX0NPTE9SX1dJUEUQBhIPCgtFRkZFQ1RfV0FWRRAHEh'
    'IKDkVGRkVDVF9CUkVBVEhFEAgSEAoMRUZGRUNUX0JMSU5LEAkSEQoNRUZGRUNUX1NUUk9CRRAK'
    'EhIKDkVGRkVDVF9TUEFSS0xFEAsSEwoPRUZGRUNUX0NPTkZFVFRJEAwSDwoLRUZGRUNUX0ZJUk'
    'UQDQ==');

@$core.Deprecated('Use documentDescriptor instead')
const Document$json = {
  '1': 'Document',
  '2': [
    {'1': 'schema_version', '3': 1, '4': 1, '5': 13, '10': 'schemaVersion'},
    {
      '1': 'pages',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.ledato_stripes.Page',
      '10': 'pages'
    },
    {
      '1': 'active_page_index',
      '3': 3,
      '4': 1,
      '5': 13,
      '10': 'activePageIndex'
    },
  ],
};

/// Descriptor for `Document`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List documentDescriptor = $convert.base64Decode(
    'CghEb2N1bWVudBIlCg5zY2hlbWFfdmVyc2lvbhgBIAEoDVINc2NoZW1hVmVyc2lvbhIqCgVwYW'
    'dlcxgCIAMoCzIULmxlZGF0b19zdHJpcGVzLlBhZ2VSBXBhZ2VzEioKEWFjdGl2ZV9wYWdlX2lu'
    'ZGV4GAMgASgNUg9hY3RpdmVQYWdlSW5kZXg=');

@$core.Deprecated('Use pageDescriptor instead')
const Page$json = {
  '1': 'Page',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'duration_ms', '3': 3, '4': 1, '5': 13, '10': 'durationMs'},
    {
      '1': 'scene_width_meters',
      '3': 4,
      '4': 1,
      '5': 1,
      '10': 'sceneWidthMeters'
    },
    {'1': 'scene_aspect', '3': 5, '4': 1, '5': 1, '10': 'sceneAspect'},
    {'1': 'use_image_aspect', '3': 6, '4': 1, '5': 8, '10': 'useImageAspect'},
    {'1': 'background_path', '3': 7, '4': 1, '5': 9, '10': 'backgroundPath'},
    {'1': 'background_dim', '3': 8, '4': 1, '5': 1, '10': 'backgroundDim'},
    {'1': 'glow', '3': 9, '4': 1, '5': 1, '10': 'glow'},
    {
      '1': 'strips',
      '3': 10,
      '4': 3,
      '5': 11,
      '6': '.ledato_stripes.Strip',
      '10': 'strips'
    },
    {
      '1': 'matrices',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.ledato_stripes.Matrix',
      '10': 'matrices'
    },
  ],
};

/// Descriptor for `Page`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pageDescriptor = $convert.base64Decode(
    'CgRQYWdlEg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEh8KC2R1cmF0aW9uX2'
    '1zGAMgASgNUgpkdXJhdGlvbk1zEiwKEnNjZW5lX3dpZHRoX21ldGVycxgEIAEoAVIQc2NlbmVX'
    'aWR0aE1ldGVycxIhCgxzY2VuZV9hc3BlY3QYBSABKAFSC3NjZW5lQXNwZWN0EigKEHVzZV9pbW'
    'FnZV9hc3BlY3QYBiABKAhSDnVzZUltYWdlQXNwZWN0EicKD2JhY2tncm91bmRfcGF0aBgHIAEo'
    'CVIOYmFja2dyb3VuZFBhdGgSJQoOYmFja2dyb3VuZF9kaW0YCCABKAFSDWJhY2tncm91bmREaW'
    '0SEgoEZ2xvdxgJIAEoAVIEZ2xvdxItCgZzdHJpcHMYCiADKAsyFS5sZWRhdG9fc3RyaXBlcy5T'
    'dHJpcFIGc3RyaXBzEjIKCG1hdHJpY2VzGAsgAygLMhYubGVkYXRvX3N0cmlwZXMuTWF0cml4Ug'
    'htYXRyaWNlcw==');

@$core.Deprecated('Use matrixDescriptor instead')
const Matrix$json = {
  '1': 'Matrix',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'columns', '3': 3, '4': 1, '5': 13, '10': 'columns'},
    {'1': 'rows', '3': 4, '4': 1, '5': 13, '10': 'rows'},
    {
      '1': 'wiring',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.ledato_stripes.MatrixWiring',
      '10': 'wiring'
    },
    {
      '1': 'origin',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.ledato_stripes.MatrixOrigin',
      '10': 'origin'
    },
    {'1': 'leds_per_meter', '3': 7, '4': 1, '5': 13, '10': 'ledsPerMeter'},
    {
      '1': 'banks',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.ledato_stripes.MatrixBank',
      '10': 'banks'
    },
  ],
};

/// Descriptor for `Matrix`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List matrixDescriptor = $convert.base64Decode(
    'CgZNYXRyaXgSDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSGAoHY29sdW1ucx'
    'gDIAEoDVIHY29sdW1ucxISCgRyb3dzGAQgASgNUgRyb3dzEjQKBndpcmluZxgFIAEoDjIcLmxl'
    'ZGF0b19zdHJpcGVzLk1hdHJpeFdpcmluZ1IGd2lyaW5nEjQKBm9yaWdpbhgGIAEoDjIcLmxlZG'
    'F0b19zdHJpcGVzLk1hdHJpeE9yaWdpblIGb3JpZ2luEiQKDmxlZHNfcGVyX21ldGVyGAcgASgN'
    'UgxsZWRzUGVyTWV0ZXISMAoFYmFua3MYCCADKAsyGi5sZWRhdG9fc3RyaXBlcy5NYXRyaXhCYW'
    '5rUgViYW5rcw==');

@$core.Deprecated('Use matrixBankDescriptor instead')
const MatrixBank$json = {
  '1': 'MatrixBank',
  '2': [
    {'1': 'strip_id', '3': 1, '4': 1, '5': 9, '10': 'stripId'},
    {'1': 'first_row', '3': 2, '4': 1, '5': 13, '10': 'firstRow'},
    {'1': 'row_count', '3': 3, '4': 1, '5': 13, '10': 'rowCount'},
  ],
};

/// Descriptor for `MatrixBank`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List matrixBankDescriptor = $convert.base64Decode(
    'CgpNYXRyaXhCYW5rEhkKCHN0cmlwX2lkGAEgASgJUgdzdHJpcElkEhsKCWZpcnN0X3JvdxgCIA'
    'EoDVIIZmlyc3RSb3cSGwoJcm93X2NvdW50GAMgASgNUghyb3dDb3VudA==');

@$core.Deprecated('Use stripDescriptor instead')
const Strip$json = {
  '1': 'Strip',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'leds_per_meter', '3': 3, '4': 1, '5': 13, '10': 'ledsPerMeter'},
    {'1': 'enabled', '3': 4, '4': 1, '5': 8, '10': 'enabled'},
    {
      '1': 'sections',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.ledato_stripes.Section',
      '10': 'sections'
    },
    {
      '1': 'continuous_effect',
      '3': 6,
      '4': 1,
      '5': 8,
      '10': 'continuousEffect'
    },
  ],
};

/// Descriptor for `Strip`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stripDescriptor = $convert.base64Decode(
    'CgVTdHJpcBIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZRIkCg5sZWRzX3Blcl'
    '9tZXRlchgDIAEoDVIMbGVkc1Blck1ldGVyEhgKB2VuYWJsZWQYBCABKAhSB2VuYWJsZWQSMwoI'
    'c2VjdGlvbnMYBSADKAsyFy5sZWRhdG9fc3RyaXBlcy5TZWN0aW9uUghzZWN0aW9ucxIrChFjb2'
    '50aW51b3VzX2VmZmVjdBgGIAEoCFIQY29udGludW91c0VmZmVjdA==');

@$core.Deprecated('Use sectionDescriptor instead')
const Section$json = {
  '1': 'Section',
  '2': [
    {'1': 'start_x', '3': 1, '4': 1, '5': 1, '10': 'startX'},
    {'1': 'start_y', '3': 2, '4': 1, '5': 1, '10': 'startY'},
    {'1': 'angle', '3': 3, '4': 1, '5': 1, '10': 'angle'},
    {'1': 'led_count', '3': 4, '4': 1, '5': 13, '10': 'ledCount'},
    {
      '1': 'effect',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.ledato_stripes.Effect',
      '10': 'effect'
    },
    {'1': 'color', '3': 6, '4': 1, '5': 13, '10': 'color'},
    {'1': 'color2', '3': 7, '4': 1, '5': 13, '10': 'color2'},
    {'1': 'brightness', '3': 8, '4': 1, '5': 1, '10': 'brightness'},
    {'1': 'speed', '3': 9, '4': 1, '5': 1, '10': 'speed'},
    {'1': 'reversed', '3': 10, '4': 1, '5': 8, '10': 'reversed'},
  ],
};

/// Descriptor for `Section`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sectionDescriptor = $convert.base64Decode(
    'CgdTZWN0aW9uEhcKB3N0YXJ0X3gYASABKAFSBnN0YXJ0WBIXCgdzdGFydF95GAIgASgBUgZzdG'
    'FydFkSFAoFYW5nbGUYAyABKAFSBWFuZ2xlEhsKCWxlZF9jb3VudBgEIAEoDVIIbGVkQ291bnQS'
    'LgoGZWZmZWN0GAUgASgOMhYubGVkYXRvX3N0cmlwZXMuRWZmZWN0UgZlZmZlY3QSFAoFY29sb3'
    'IYBiABKA1SBWNvbG9yEhYKBmNvbG9yMhgHIAEoDVIGY29sb3IyEh4KCmJyaWdodG5lc3MYCCAB'
    'KAFSCmJyaWdodG5lc3MSFAoFc3BlZWQYCSABKAFSBXNwZWVkEhoKCHJldmVyc2VkGAogASgIUg'
    'hyZXZlcnNlZA==');
