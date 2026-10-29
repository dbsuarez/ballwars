import 'package:flutter/material.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../data/loadout_preset_store.dart';
import '../domain/loadout_preset.dart';

class LoadoutPresetsDialog extends StatefulWidget {
  const LoadoutPresetsDialog({
    super.key,
    required this.currentKinds,
    required this.currentCustomIds,
    required this.availableCustomNames,
    this.store,
  });

  final Set<PowerUpKind> currentKinds;
  final Set<String> currentCustomIds;
  final Map<String, String> availableCustomNames;
  final LoadoutPresetStore? store;

  @override
  State<LoadoutPresetsDialog> createState() => _LoadoutPresetsDialogState();
}

class _LoadoutPresetsDialogState extends State<LoadoutPresetsDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final _store = widget.store ?? LoadoutPresetStore();
  List<LoadoutPreset> _saved = [];
  bool _loading = true;
  bool _busy = false;
  bool _readFailed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final saved = await _store.read();
      if (mounted) {
        setState(() {
          _saved = saved;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _readFailed = true;
          _error =
              'Could not load saved presets. Close and try again. Built-in presets are still available.';
        });
      }
    }
  }

  Future<void> _save(List<LoadoutPreset> next) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _store.write(next);
      if (mounted) {
        setState(() => _saved = next);
        _tabs.animateTo(1);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not save presets. Your previous presets have been kept. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _name({LoadoutPreset? existing}) async {
    var draftName = existing?.name ?? '';
    final form = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Save loadout preset' : 'Rename preset'),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: draftName,
            onChanged: (value) => draftName = value,
            autofocus: true,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Preset name',
              hintText: 'e.g. Friday Mayhem',
            ),
            validator: (value) {
              final name = value?.trim() ?? '';
              if (name.isEmpty) return 'Enter a name.';
              if (_saved.any(
                (p) =>
                    p.id != existing?.id &&
                    p.name.toLowerCase() == name.toLowerCase(),
              )) {
                return 'A saved preset already uses this name.';
              }
              return null;
            },
            onFieldSubmitted: (_) {
              if (form.currentState!.validate()) {
                Navigator.pop(context, draftName.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, draftName.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted || name == null) return;
    final preset =
        existing?.renamed(name) ??
        LoadoutPreset(
          id: 'saved-${DateTime.now().microsecondsSinceEpoch}',
          name: name,
          kinds: widget.currentKinds,
          customIds: widget.currentCustomIds,
        );
    await _save(
      existing == null
          ? [..._saved, preset]
          : [
              for (final item in _saved)
                if (item.id == existing.id) preset else item,
            ],
    );
  }

  Future<void> _delete(LoadoutPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${preset.name}?'),
        content: const Text(
          'This removes the preset, not the skills or current selection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) {
      await _save(_saved.where((p) => p.id != preset.id).toList());
    }
  }

  Widget _list(List<LoadoutPreset> presets, {bool editable = false}) {
    if (presets.isEmpty) {
      return const Center(
        child: Text(
          'No saved presets yet.\nChoose items, then save your selection.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      itemCount: presets.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final preset = presets[index];
        final available = preset.customIds
            .where(widget.availableCustomNames.containsKey)
            .toSet();
        final missing = preset.customIds.length - available.length;
        final count = preset.kinds.length + available.length;
        final labels = [
          ...preset.kinds.map((k) => k.label),
          ...available.map((id) => widget.availableCustomNames[id]!),
        ]..sort();
        return ListTile(
          key: ValueKey('loadout-preset-${preset.id}'),
          title: Text(preset.name),
          subtitle: Text(
            [
              if (preset.description.isNotEmpty) preset.description,
              editable
                  ? '$count pickups: ${labels.join(', ')}'
                  : '$count pickups',
              if (missing > 0)
                '$missing custom skills unavailable; these will be skipped.',
            ].join('\n'),
          ),
          isThreeLine: false,
          onTap: _busy || count == 0
              ? null
              : () => Navigator.pop(context, preset),
          trailing: editable
              ? PopupMenuButton<String>(
                  enabled: !_busy && !_readFailed,
                  tooltip: '${preset.name} options',
                  onSelected: (action) => action == 'rename'
                      ? _name(existing: preset)
                      : _delete(preset),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                )
              : const Icon(Icons.chevron_right),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: AlertDialog(
      title: const Text('Loadout presets'),
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      content: SizedBox(
        width: 620,
        height: MediaQuery.sizeOf(context).height * .55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tap a preset to replace the pickup selection. Traps stay automatic. Saved presets stay on this device.',
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Built-in'),
                Tab(text: 'Saved'),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _list(LoadoutPreset.builtIns),
                        _list(_saved, editable: true),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          key: const ValueKey('save-loadout-preset'),
          onPressed:
              _busy ||
                  _loading ||
                  _readFailed ||
                  (!widget.currentKinds.any((k) => !k.isTrap) &&
                      widget.currentCustomIds.isEmpty)
              ? null
              : () => _name(),
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('Save selection'),
        ),
      ],
    ),
  );
}
