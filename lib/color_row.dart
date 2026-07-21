import 'package:flutter/material.dart';

/// Farbzeile: Vorschau-Kachel öffnet einen einfachen HSV-Farbwähler.
class ColorRow extends StatelessWidget {
  const ColorRow({
    super.key,
    required this.label,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _pick(context),
            child: Container(
              width: 48,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 6,
              children: [
                for (final c in _swatches)
                  GestureDetector(
                    onTap: () => onChanged(c),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.toARGB32() == color.toARGB32()
                              ? Colors.white
                              : Colors.white24,
                          width: c.toARGB32() == color.toARGB32() ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _swatches = [
    Color(0xFFFFFFFF),
    Color(0xFFFF0000),
    Color(0xFFFF6000),
    Color(0xFFFFD000),
    Color(0xFF00FF00),
    Color(0xFF00FFD0),
    Color(0xFF0080FF),
    Color(0xFF8040FF),
    Color(0xFFFF00A0),
  ];

  Future<void> _pick(BuildContext context) async {
    var hsv = HSVColor.fromColor(color);
    final result = await showDialog<Color>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(label),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: hsv.toColor(),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                _hsvSlider(
                  'Farbton',
                  hsv.hue,
                  0,
                  360,
                  (v) => setState(() => hsv = hsv.withHue(v)),
                ),
                _hsvSlider(
                  'Sättigung',
                  hsv.saturation,
                  0,
                  1,
                  (v) => setState(() => hsv = hsv.withSaturation(v)),
                ),
                _hsvSlider(
                  'Wert',
                  hsv.value,
                  0,
                  1,
                  (v) => setState(() => hsv = hsv.withValue(v)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, hsv.toColor()),
              child: const Text('Übernehmen'),
            ),
          ],
        ),
      ),
    );
    if (result != null) onChanged(result);
  }

  static Widget _hsvSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}
