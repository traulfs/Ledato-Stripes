import 'package:flutter/material.dart';

import 'app_state.dart';
import 'model.dart';

/// Verwaltung aller Pages (Lichtszenen): anlegen, umbenennen, Dauer setzen,
/// duplizieren, löschen, per Ziehen umsortieren, antippen aktiviert eine
/// Page und kehrt zum Editor zurück.
class PagesScreen extends StatelessWidget {
  const PagesScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seiten')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) => ReorderableListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: state.pages.length,
          onReorderItem: state.reorderPage,
          itemBuilder: (context, index) =>
              _PageTile(key: ValueKey(state.pages[index].id), state: state, index: index),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Page hinzufügen',
        onPressed: state.addPage,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PageTile extends StatefulWidget {
  const _PageTile({super.key, required this.state, required this.index});

  final AppState state;
  final int index;

  @override
  State<_PageTile> createState() => _PageTileState();
}

class _PageTileState extends State<_PageTile> {
  late final TextEditingController _nameController;
  late final TextEditingController _durationController;

  LedPage get _page => widget.state.pages[widget.index];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _page.name);
    _durationController = TextEditingController(
      text: _formatSeconds(_page.durationMs),
    );
  }

  @override
  void didUpdateWidget(covariant _PageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_nameController.text != _page.name) {
      _nameController.text = _page.name;
    }
    final durationText = _formatSeconds(_page.durationMs);
    if (_durationController.text != durationText) {
      _durationController.text = durationText;
    }
  }

  static String _formatSeconds(int ms) {
    final s = ms / 1000;
    return s == s.roundToDouble() ? s.toInt().toString() : s.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final isActive = widget.index == widget.state.activePageIndex;
    final sectionCount = page.strips.fold(
      0,
      (sum, s) => sum + s.sections.length,
    );
    return Card(
      key: widget.key,
      color: isActive
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: InkWell(
        onTap: () async {
          await widget.state.setActivePage(widget.index);
          if (context.mounted) Navigator.of(context).pop();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: widget.index,
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.drag_handle),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    labelText: 'Name',
                  ),
                  onSubmitted: (v) => widget.state.renamePage(page, v),
                  onTapOutside: (_) =>
                      widget.state.renamePage(page, _nameController.text),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _durationController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    labelText: 'Dauer (s)',
                  ),
                  onSubmitted: (v) => _applyDuration(v),
                  onTapOutside: (_) => _applyDuration(_durationController.text),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${page.strips.length} Stripes · $sectionCount Abschnitte',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              IconButton(
                tooltip: 'Duplizieren',
                icon: const Icon(Icons.copy_outlined),
                onPressed: () => widget.state.duplicatePage(widget.index),
              ),
              IconButton(
                tooltip: widget.state.pages.length <= 1
                    ? 'Mindestens eine Page erforderlich'
                    : 'Löschen',
                icon: const Icon(Icons.delete_outline),
                onPressed: widget.state.pages.length <= 1
                    ? null
                    : () => widget.state.removePage(widget.index),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyDuration(String text) {
    final seconds = double.tryParse(text.replaceAll(',', '.'));
    if (seconds != null) {
      widget.state.setPageDuration(_page, (seconds * 1000).round());
    }
  }
}
