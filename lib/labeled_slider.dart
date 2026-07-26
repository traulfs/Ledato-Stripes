import 'package:flutter/material.dart';

/// Beschrifteter Schieberegler mit Wertanzeige rechts — kompaktes
/// Standardlayout, das in mehreren Dialogen wiederverwendet wird.
///
/// Mit [numberEntry] wird die reine Textanzeige durch ein Zahlenfeld
/// ersetzt, über das der Wert auch direkt eingetippt werden kann.
class LabeledSlider extends StatefulWidget {
  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.display,
    required this.onChanged,
    this.labelWidth = 90,
    this.numberEntry = false,
    this.unitSuffix,
    this.decimals = 0,
    this.displayScale = 1,
    this.fieldWidth = 64,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String display;
  final ValueChanged<double> onChanged;
  final double labelWidth;
  final bool numberEntry;
  final String? unitSuffix;

  /// Nachkommastellen im Zahlenfeld (0 = ganze Zahl).
  final int decimals;

  /// Faktor zwischen internem Wert und angezeigter Zahl, z. B. 100 um
  /// einen Anteil (0.2–2.0) als Prozentzahl (20–200) einzugeben.
  final double displayScale;
  final double fieldWidth;

  @override
  State<LabeledSlider> createState() => _LabeledSliderState();
}

class _LabeledSliderState extends State<LabeledSlider> {
  late final _controller = TextEditingController(text: _text);
  final _focusNode = FocusNode();

  String get _text {
    final scaled = widget.value * widget.displayScale;
    return widget.decimals > 0
        ? scaled.toStringAsFixed(widget.decimals).replaceAll('.', ',')
        : scaled.round().toString();
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _syncControllerToValue();
    });
  }

  @override
  void didUpdateWidget(covariant LabeledSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus) _syncControllerToValue();
  }

  void _syncControllerToValue() {
    if (_controller.text != _text) _controller.text = _text;
  }

  void _submit(String text) {
    final v = double.tryParse(text.replaceAll(',', '.'));
    if (v == null) return;
    final unscaled = v / widget.displayScale;
    widget.onChanged(unscaled.clamp(widget.min, widget.max));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clamped = widget.value.clamp(widget.min, widget.max);
    return Row(
      children: [
        SizedBox(
          width: widget.labelWidth,
          child: Text(widget.label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: Slider(
            value: clamped,
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            onChanged: widget.onChanged,
          ),
        ),
        if (widget.numberEntry)
          SizedBox(
            width: widget.fieldWidth,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
              keyboardType: TextInputType.numberWithOptions(
                decimal: widget.decimals > 0,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 6,
                ),
                border: const OutlineInputBorder(),
                suffixText: widget.unitSuffix,
              ),
              onSubmitted: _submit,
              onChanged: _submit,
            ),
          )
        else
          SizedBox(
            width: 48,
            child: Text(
              widget.display,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}

/// Meterangabe im deutschen Format, z. B. "2,35 m".
String fmtMeters(double m) => '${m.toStringAsFixed(2).replaceAll('.', ',')} m';
