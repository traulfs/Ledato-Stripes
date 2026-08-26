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

import 'ledato_stripes.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'ledato_stripes.pbenum.dart';

class Document extends $pb.GeneratedMessage {
  factory Document({
    $core.int? schemaVersion,
    $core.Iterable<Page>? pages,
    $core.int? activePageIndex,
  }) {
    final result = create();
    if (schemaVersion != null) result.schemaVersion = schemaVersion;
    if (pages != null) result.pages.addAll(pages);
    if (activePageIndex != null) result.activePageIndex = activePageIndex;
    return result;
  }

  Document._();

  factory Document.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Document.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Document',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ledato_stripes'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'schemaVersion',
        fieldType: $pb.PbFieldType.OU3)
    ..pPM<Page>(2, _omitFieldNames ? '' : 'pages', subBuilder: Page.create)
    ..aI(3, _omitFieldNames ? '' : 'activePageIndex',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Document clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Document copyWith(void Function(Document) updates) =>
      super.copyWith((message) => updates(message as Document)) as Document;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Document create() => Document._();
  @$core.override
  Document createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Document getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Document>(create);
  static Document? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get schemaVersion => $_getIZ(0);
  @$pb.TagNumber(1)
  set schemaVersion($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSchemaVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearSchemaVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<Page> get pages => $_getList(1);

  @$pb.TagNumber(3)
  $core.int get activePageIndex => $_getIZ(2);
  @$pb.TagNumber(3)
  set activePageIndex($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasActivePageIndex() => $_has(2);
  @$pb.TagNumber(3)
  void clearActivePageIndex() => $_clearField(3);
}

class Page extends $pb.GeneratedMessage {
  factory Page({
    $core.String? id,
    $core.String? name,
    $core.int? durationMs,
    $core.double? sceneWidthMeters,
    $core.double? sceneAspect,
    $core.bool? useImageAspect,
    $core.String? backgroundPath,
    $core.double? backgroundDim,
    $core.double? glow,
    $core.Iterable<Strip>? strips,
    $core.Iterable<Matrix>? matrices,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (durationMs != null) result.durationMs = durationMs;
    if (sceneWidthMeters != null) result.sceneWidthMeters = sceneWidthMeters;
    if (sceneAspect != null) result.sceneAspect = sceneAspect;
    if (useImageAspect != null) result.useImageAspect = useImageAspect;
    if (backgroundPath != null) result.backgroundPath = backgroundPath;
    if (backgroundDim != null) result.backgroundDim = backgroundDim;
    if (glow != null) result.glow = glow;
    if (strips != null) result.strips.addAll(strips);
    if (matrices != null) result.matrices.addAll(matrices);
    return result;
  }

  Page._();

  factory Page.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Page.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Page',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ledato_stripes'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aI(3, _omitFieldNames ? '' : 'durationMs', fieldType: $pb.PbFieldType.OU3)
    ..aD(4, _omitFieldNames ? '' : 'sceneWidthMeters')
    ..aD(5, _omitFieldNames ? '' : 'sceneAspect')
    ..aOB(6, _omitFieldNames ? '' : 'useImageAspect')
    ..aOS(7, _omitFieldNames ? '' : 'backgroundPath')
    ..aD(8, _omitFieldNames ? '' : 'backgroundDim')
    ..aD(9, _omitFieldNames ? '' : 'glow')
    ..pPM<Strip>(10, _omitFieldNames ? '' : 'strips', subBuilder: Strip.create)
    ..pPM<Matrix>(11, _omitFieldNames ? '' : 'matrices',
        subBuilder: Matrix.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Page clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Page copyWith(void Function(Page) updates) =>
      super.copyWith((message) => updates(message as Page)) as Page;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Page create() => Page._();
  @$core.override
  Page createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Page getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Page>(create);
  static Page? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get durationMs => $_getIZ(2);
  @$pb.TagNumber(3)
  set durationMs($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDurationMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearDurationMs() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get sceneWidthMeters => $_getN(3);
  @$pb.TagNumber(4)
  set sceneWidthMeters($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSceneWidthMeters() => $_has(3);
  @$pb.TagNumber(4)
  void clearSceneWidthMeters() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get sceneAspect => $_getN(4);
  @$pb.TagNumber(5)
  set sceneAspect($core.double value) => $_setDouble(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSceneAspect() => $_has(4);
  @$pb.TagNumber(5)
  void clearSceneAspect() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get useImageAspect => $_getBF(5);
  @$pb.TagNumber(6)
  set useImageAspect($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUseImageAspect() => $_has(5);
  @$pb.TagNumber(6)
  void clearUseImageAspect() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get backgroundPath => $_getSZ(6);
  @$pb.TagNumber(7)
  set backgroundPath($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasBackgroundPath() => $_has(6);
  @$pb.TagNumber(7)
  void clearBackgroundPath() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.double get backgroundDim => $_getN(7);
  @$pb.TagNumber(8)
  set backgroundDim($core.double value) => $_setDouble(7, value);
  @$pb.TagNumber(8)
  $core.bool hasBackgroundDim() => $_has(7);
  @$pb.TagNumber(8)
  void clearBackgroundDim() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.double get glow => $_getN(8);
  @$pb.TagNumber(9)
  set glow($core.double value) => $_setDouble(8, value);
  @$pb.TagNumber(9)
  $core.bool hasGlow() => $_has(8);
  @$pb.TagNumber(9)
  void clearGlow() => $_clearField(9);

  @$pb.TagNumber(10)
  $pb.PbList<Strip> get strips => $_getList(9);

  @$pb.TagNumber(11)
  $pb.PbList<Matrix> get matrices => $_getList(10);
}

/// Logische LED-Matrix, gebildet aus einem oder mehreren Stripes.
///
/// Diese Nachricht ist die Schnittstelle zur Controller-Firmware: sie sagt,
/// wie die fortlaufenden LED-Indizes der beteiligten Stripes als Pixelfläche
/// zu lesen sind. Die geometrische Wahrheit (wo jede Zeile in der Szene
/// liegt) steckt weiterhin in den Stripes und ihren Abschnitten — hier steht
/// nur die logische Struktur, die ein Controller braucht, um (x, y) auf einen
/// LED-Index abzubilden.
///
/// Adressierung, die die Firmware daraus ableiten kann:
///   Zeile r liegt in dem Bank-Eintrag mit first_row <= r < first_row+row_count.
///   Innerhalb der Bank ist local = r - first_row.
///   Bei SERPENTINE laufen Zeilen mit ungeradem local rückwärts.
///   Index in der Bank = local * columns + (rückwärts ? columns-1-x : x).
/// Der Index ist bankweise, beginnt in jedem Stripe also wieder bei 0 —
/// passend dazu, dass jeder Stripe seine eigene Einspeisung hat.
class Matrix extends $pb.GeneratedMessage {
  factory Matrix({
    $core.String? id,
    $core.String? name,
    $core.int? columns,
    $core.int? rows,
    MatrixWiring? wiring,
    MatrixOrigin? origin,
    $core.int? ledsPerMeter,
    $core.Iterable<MatrixBank>? banks,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (columns != null) result.columns = columns;
    if (rows != null) result.rows = rows;
    if (wiring != null) result.wiring = wiring;
    if (origin != null) result.origin = origin;
    if (ledsPerMeter != null) result.ledsPerMeter = ledsPerMeter;
    if (banks != null) result.banks.addAll(banks);
    return result;
  }

  Matrix._();

  factory Matrix.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Matrix.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Matrix',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ledato_stripes'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aI(3, _omitFieldNames ? '' : 'columns', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'rows', fieldType: $pb.PbFieldType.OU3)
    ..aE<MatrixWiring>(5, _omitFieldNames ? '' : 'wiring',
        enumValues: MatrixWiring.values)
    ..aE<MatrixOrigin>(6, _omitFieldNames ? '' : 'origin',
        enumValues: MatrixOrigin.values)
    ..aI(7, _omitFieldNames ? '' : 'ledsPerMeter',
        fieldType: $pb.PbFieldType.OU3)
    ..pPM<MatrixBank>(8, _omitFieldNames ? '' : 'banks',
        subBuilder: MatrixBank.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Matrix clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Matrix copyWith(void Function(Matrix) updates) =>
      super.copyWith((message) => updates(message as Matrix)) as Matrix;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Matrix create() => Matrix._();
  @$core.override
  Matrix createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Matrix getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Matrix>(create);
  static Matrix? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get columns => $_getIZ(2);
  @$pb.TagNumber(3)
  set columns($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasColumns() => $_has(2);
  @$pb.TagNumber(3)
  void clearColumns() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get rows => $_getIZ(3);
  @$pb.TagNumber(4)
  set rows($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRows() => $_has(3);
  @$pb.TagNumber(4)
  void clearRows() => $_clearField(4);

  @$pb.TagNumber(5)
  MatrixWiring get wiring => $_getN(4);
  @$pb.TagNumber(5)
  set wiring(MatrixWiring value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasWiring() => $_has(4);
  @$pb.TagNumber(5)
  void clearWiring() => $_clearField(5);

  @$pb.TagNumber(6)
  MatrixOrigin get origin => $_getN(5);
  @$pb.TagNumber(6)
  set origin(MatrixOrigin value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasOrigin() => $_has(5);
  @$pb.TagNumber(6)
  void clearOrigin() => $_clearField(6);

  /// LED-Dichte aller beteiligten Stripes; zugleich der Pixelabstand der
  /// Matrix (Zeilenabstand = Spaltenabstand = 1/leds_per_meter Meter).
  @$pb.TagNumber(7)
  $core.int get ledsPerMeter => $_getIZ(6);
  @$pb.TagNumber(7)
  set ledsPerMeter($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLedsPerMeter() => $_has(6);
  @$pb.TagNumber(7)
  void clearLedsPerMeter() => $_clearField(7);

  /// Die Stripes der Matrix, von der Ursprungsecke weg gestapelt. Die
  /// Position in dieser Liste + 1 ist die DDP-destination des Stripes.
  @$pb.TagNumber(8)
  $pb.PbList<MatrixBank> get banks => $_getList(7);
}

/// Ein Stripe als zusammenhängender Zeilenblock der Matrix.
class MatrixBank extends $pb.GeneratedMessage {
  factory MatrixBank({
    $core.String? stripId,
    $core.int? firstRow,
    $core.int? rowCount,
  }) {
    final result = create();
    if (stripId != null) result.stripId = stripId;
    if (firstRow != null) result.firstRow = firstRow;
    if (rowCount != null) result.rowCount = rowCount;
    return result;
  }

  MatrixBank._();

  factory MatrixBank.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MatrixBank.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MatrixBank',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ledato_stripes'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'stripId')
    ..aI(2, _omitFieldNames ? '' : 'firstRow', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'rowCount', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MatrixBank clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MatrixBank copyWith(void Function(MatrixBank) updates) =>
      super.copyWith((message) => updates(message as MatrixBank)) as MatrixBank;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MatrixBank create() => MatrixBank._();
  @$core.override
  MatrixBank createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MatrixBank getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MatrixBank>(create);
  static MatrixBank? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get stripId => $_getSZ(0);
  @$pb.TagNumber(1)
  set stripId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStripId() => $_has(0);
  @$pb.TagNumber(1)
  void clearStripId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get firstRow => $_getIZ(1);
  @$pb.TagNumber(2)
  set firstRow($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFirstRow() => $_has(1);
  @$pb.TagNumber(2)
  void clearFirstRow() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get rowCount => $_getIZ(2);
  @$pb.TagNumber(3)
  set rowCount($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRowCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearRowCount() => $_clearField(3);
}

class Strip extends $pb.GeneratedMessage {
  factory Strip({
    $core.String? id,
    $core.String? name,
    $core.int? ledsPerMeter,
    $core.bool? enabled,
    $core.Iterable<Section>? sections,
    $core.bool? continuousEffect,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (ledsPerMeter != null) result.ledsPerMeter = ledsPerMeter;
    if (enabled != null) result.enabled = enabled;
    if (sections != null) result.sections.addAll(sections);
    if (continuousEffect != null) result.continuousEffect = continuousEffect;
    return result;
  }

  Strip._();

  factory Strip.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Strip.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Strip',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ledato_stripes'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aI(3, _omitFieldNames ? '' : 'ledsPerMeter',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(4, _omitFieldNames ? '' : 'enabled')
    ..pPM<Section>(5, _omitFieldNames ? '' : 'sections',
        subBuilder: Section.create)
    ..aOB(6, _omitFieldNames ? '' : 'continuousEffect')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Strip clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Strip copyWith(void Function(Strip) updates) =>
      super.copyWith((message) => updates(message as Strip)) as Strip;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Strip create() => Strip._();
  @$core.override
  Strip createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Strip getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Strip>(create);
  static Strip? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get ledsPerMeter => $_getIZ(2);
  @$pb.TagNumber(3)
  set ledsPerMeter($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLedsPerMeter() => $_has(2);
  @$pb.TagNumber(3)
  void clearLedsPerMeter() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get enabled => $_getBF(3);
  @$pb.TagNumber(4)
  set enabled($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEnabled() => $_has(3);
  @$pb.TagNumber(4)
  void clearEnabled() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<Section> get sections => $_getList(4);

  /// Effekte über alle Abschnitte hinweg durchlaufen lassen, statt jeden
  /// Abschnitt für sich rechnen zu lassen (z. B. ein Lauflicht, das sich
  /// durch eine Matrix schlängelt). Default false = bisheriges Verhalten.
  @$pb.TagNumber(6)
  $core.bool get continuousEffect => $_getBF(5);
  @$pb.TagNumber(6)
  set continuousEffect($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasContinuousEffect() => $_has(5);
  @$pb.TagNumber(6)
  void clearContinuousEffect() => $_clearField(6);
}

class Section extends $pb.GeneratedMessage {
  factory Section({
    $core.double? startX,
    $core.double? startY,
    $core.double? angle,
    $core.int? ledCount,
    Effect? effect,
    $core.int? color,
    $core.int? color2,
    $core.double? brightness,
    $core.double? speed,
    $core.bool? reversed,
  }) {
    final result = create();
    if (startX != null) result.startX = startX;
    if (startY != null) result.startY = startY;
    if (angle != null) result.angle = angle;
    if (ledCount != null) result.ledCount = ledCount;
    if (effect != null) result.effect = effect;
    if (color != null) result.color = color;
    if (color2 != null) result.color2 = color2;
    if (brightness != null) result.brightness = brightness;
    if (speed != null) result.speed = speed;
    if (reversed != null) result.reversed = reversed;
    return result;
  }

  Section._();

  factory Section.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Section.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Section',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ledato_stripes'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'startX')
    ..aD(2, _omitFieldNames ? '' : 'startY')
    ..aD(3, _omitFieldNames ? '' : 'angle')
    ..aI(4, _omitFieldNames ? '' : 'ledCount', fieldType: $pb.PbFieldType.OU3)
    ..aE<Effect>(5, _omitFieldNames ? '' : 'effect', enumValues: Effect.values)
    ..aI(6, _omitFieldNames ? '' : 'color', fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'color2', fieldType: $pb.PbFieldType.OU3)
    ..aD(8, _omitFieldNames ? '' : 'brightness')
    ..aD(9, _omitFieldNames ? '' : 'speed')
    ..aOB(10, _omitFieldNames ? '' : 'reversed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Section clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Section copyWith(void Function(Section) updates) =>
      super.copyWith((message) => updates(message as Section)) as Section;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Section create() => Section._();
  @$core.override
  Section createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Section getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Section>(create);
  static Section? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get startX => $_getN(0);
  @$pb.TagNumber(1)
  set startX($core.double value) => $_setDouble(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStartX() => $_has(0);
  @$pb.TagNumber(1)
  void clearStartX() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get startY => $_getN(1);
  @$pb.TagNumber(2)
  set startY($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStartY() => $_has(1);
  @$pb.TagNumber(2)
  void clearStartY() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get angle => $_getN(2);
  @$pb.TagNumber(3)
  set angle($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAngle() => $_has(2);
  @$pb.TagNumber(3)
  void clearAngle() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get ledCount => $_getIZ(3);
  @$pb.TagNumber(4)
  set ledCount($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLedCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearLedCount() => $_clearField(4);

  @$pb.TagNumber(5)
  Effect get effect => $_getN(4);
  @$pb.TagNumber(5)
  set effect(Effect value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasEffect() => $_has(4);
  @$pb.TagNumber(5)
  void clearEffect() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get color => $_getIZ(5);
  @$pb.TagNumber(6)
  set color($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasColor() => $_has(5);
  @$pb.TagNumber(6)
  void clearColor() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get color2 => $_getIZ(6);
  @$pb.TagNumber(7)
  set color2($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasColor2() => $_has(6);
  @$pb.TagNumber(7)
  void clearColor2() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.double get brightness => $_getN(7);
  @$pb.TagNumber(8)
  set brightness($core.double value) => $_setDouble(7, value);
  @$pb.TagNumber(8)
  $core.bool hasBrightness() => $_has(7);
  @$pb.TagNumber(8)
  void clearBrightness() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.double get speed => $_getN(8);
  @$pb.TagNumber(9)
  set speed($core.double value) => $_setDouble(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSpeed() => $_has(8);
  @$pb.TagNumber(9)
  void clearSpeed() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get reversed => $_getBF(9);
  @$pb.TagNumber(10)
  set reversed($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasReversed() => $_has(9);
  @$pb.TagNumber(10)
  void clearReversed() => $_clearField(10);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
