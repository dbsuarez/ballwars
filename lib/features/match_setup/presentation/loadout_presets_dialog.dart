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
  final Map<String, LoadoutPreset> _selected = {};

  LoadoutPreset get _combined => LoadoutPreset.combine(_selected.values);
  int get _combinedCount =>
      _combined.kinds.length +
      _combined.customIds.where(widget.availableCustomNames.containsKey).length;

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
        setState(() {
          _saved = next;
          for (final key
              in _selected.keys
                  .where((key) => key.startsWith('saved:'))
                  .toList()) {
            final updated = next
                .where((p) => 'saved:${p.id}' == key)
                .firstOrNull;
            if (updated == null) {
              _selected.remove(key);
            } else {
              _selected[key] = updated;
            }
          }
        });
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
          kinds: _selected.isEmpty ? widget.currentKinds : _combined.kinds,
          customIds: _selected.isEmpty
              ? widget.currentCustomIds
              : _combined.customIds.where(
                  widget.availableCustomNames.containsKey,
                ),
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

  Future<void> _info(LoadoutPreset preset) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(preset.name),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (preset.description.isNotEmpty) ...[
                Text(preset.description),
                const SizedBox(height: 12),
              ],
              for (final category in [
                ('Weapons', preset.kinds.where((kind) => kind.isWeapon)),
                ('Power-ups', preset.kinds.where((kind) => !kind.isWeapon)),
              ])
                if (category.$2.isNotEmpty) ...[
                  Text(
                    category.$1,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    (category.$2.map((kind) => kind.label).toList()..sort())
                        .join(', '),
                  ),
                  const SizedBox(height: 12),
                ],
              if (preset.customIds.isNotEmpty) ...[
                Text(
                  'Custom skills',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final id in preset.customIds)
                  Text(
                    widget.availableCustomNames[id] ??
                        '$id (unavailable; skipped)',
                  ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Traps stay automatic and are not part of this pickup pool.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

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
        final selectionKey = '${editable ? 'saved' : 'builtin'}:${preset.id}';
        final selected = _selected.containsKey(selectionKey);
        return ListTile(
          key: ValueKey('loadout-preset-${preset.id}'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          minLeadingWidth: 20,
          horizontalTitleGap: 8,
          leading: Icon(
            selected ? Icons.check_box : Icons.check_box_outline_blank,
            size: 20,
          ),
          selected: selected,
          title: Text(preset.name),
          subtitle: Text(
            [
              if (preset.description.isNotEmpty) preset.description,
              '$count pickups',
              if (missing > 0)
                '$missing custom skills unavailable; these will be skipped.',
            ].join('\n'),
          ),
          isThreeLine: false,
          onTap: _busy || count == 0
              ? null
              : () => setState(() {
                  if (selected) {
                    _selected.remove(selectionKey);
                  } else {
                    _selected[selectionKey] = preset;
                  }
                }),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (editable)
                PopupMenuButton<String>(
                  enabled: !_busy && !_readFailed,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  tooltip: '${preset.name} options',
                  onSelected: (action) => action == 'rename'
                      ? _name(existing: preset)
                      : _delete(preset),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              IconButton(
                tooltip: 'About ${preset.name}',
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                padding: EdgeInsets.zero,
                onPressed: () => _info(preset),
                icon: const Icon(Icons.info_outline, size: 20),
              ),
              const Icon(Icons.chevron_right, size: 16),
            ],
          ),
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
              'Select one or more presets to combine. Traps stay automatic. Saved presets stay on this device.',
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
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '${_selected.length} presets / $_combinedCount unique pickups',
                ),
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
        OutlinedButton.icon(
          key: const ValueKey('save-loadout-preset'),
          onPressed:
              _busy ||
                  _loading ||
                  _readFailed ||
                  (_selected.isNotEmpty
                      ? _combinedCount == 0
                      : (!widget.currentKinds.any((k) => !k.isTrap) &&
                            widget.currentCustomIds.isEmpty))
              ? null
              : () => _name(),
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('Save'),
        ),
        FilledButton(
          key: const ValueKey('apply-loadout-presets'),
          onPressed: _busy || _combinedCount == 0
              ? null
              : () => Navigator.pop(context, _combined),
          child: const Text('Apply'),
        ),
      ],
    ),
  );
}
