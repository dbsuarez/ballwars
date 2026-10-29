import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../skills/domain/skill_library.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../data/sprite_atlas_repository.dart';
import '../data/sprite_backup_file.dart';
import '../domain/sprite_backup.dart';
import '../application/sprite_backup_service.dart';
import '../application/custom_sprite_loader.dart';

class SpriteBackupScreen extends StatefulWidget {
  const SpriteBackupScreen({
    super.key,
    required this.repository,
    required this.library,
    required this.tuning,
    this.service,
    this.saveFile,
  });
  final SpriteAtlasRepository repository;
  final SkillLibrary library;
  final PowerUpConfig tuning;
  final SpriteBackupService? service;
  final Future<bool> Function(Uint8List, String)? saveFile;
  @override
  State<SpriteBackupScreen> createState() => _SpriteBackupScreenState();
}

class _SpriteBackupScreenState extends State<SpriteBackupScreen> {
  late final SpriteBackupService _service =
      widget.service ?? SpriteBackupService(widget.repository);
  List<CustomAtlas>? _atlases;
  final Set<String> _selected = {};
  List<SpriteRestoreItem>? _review;
  final Map<String, SpriteRestoreChoice> _choices = {};
  SpriteRestoreResult? _result;
  Uint8List? _exportBytes;
  bool _busy = false;
  String? _error, _message;
  (int, int)? _progress;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repository.list();
      if (mounted) {
        setState(() {
          _atlases = items;
          _selected.addAll(items.map((a) => a.id));
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load the library: $e');
    }
  }

  void _onProgress(int n, int total) {
    if (mounted) setState(() => _progress = (n, total));
  }

  Future<void> _prepareExport() async {
    setState(() {
      _busy = true;
      _error = _message = null;
      _progress = null;
      _exportBytes = null;
    });
    try {
      final backup = await _service.export(
        _atlases!.where((a) => _selected.contains(a.id)).toList(),
        progress: _onProgress,
      );
      final bytes = backup.encode();
      if (mounted) setState(() => _exportBytes = bytes);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'Backup could not be prepared. No file was saved.\n$e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _saveExport() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final name =
          'ballwars-sprites-${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}.bwsprites';
      final saved = await (widget.saveFile ?? saveSpriteBackupFile)(
        _exportBytes!,
        name,
      );
      if (mounted && saved) {
        setState(
          () => _message = kIsWeb
              ? 'Backup download started.'
              : 'Sprite backup saved.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'Could not save the backup. The prepared file is kept for retry.\n$e',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openBackup() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (picked == null) return;
      setState(() {
        _busy = true;
        _error = _message = null;
        _review = null;
        _choices.clear();
        _result = null;
      });
      final file = picked.files.single;
      if (file.size > SpriteBackup.maxFileBytes || file.bytes == null) {
        throw const FormatException(
          'Choose a readable .bwsprites backup no larger than 48 MB.',
        );
      }
      final backup = await SpriteBackup.decode(file.bytes!);
      final review = await _service.review(backup);
      if (mounted) {
        setState(() {
          _review = review;
          _choices.clear();
          _result = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'Backup could not be opened. No library changes were made.\n$e',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<String> _affected(SpriteRestoreItem item) => [
    for (final skill in widget.library.all(widget.tuning))
      if (item.removedNames.any(
        (name) => widget.library
            .spriteReferences(skill)
            .contains('custom.${item.entry.id}.$name'),
      ))
        skill.name,
    for (final effect in widget.library.effects.values)
      if (item.removedNames.any(
        (name) => effect.spriteId == 'custom.${item.entry.id}.$name',
      ))
        'Effect: ${effect.name}',
  ];
  Future<void> _restore() async {
    final selected = _review!
        .where(
          (i) =>
              (_choices[i.entry.id] ?? i.defaultChoice) !=
              SpriteRestoreChoice.skip,
        )
        .toList();
    final replacements = selected
        .where(
          (i) =>
              (_choices[i.entry.id] ?? i.defaultChoice) ==
              SpriteRestoreChoice.replace,
        )
        .toList();
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Restore sprite backup?'),
        content: Text(
          '${selected.length} upload(s) will be restored. Stable sprite IDs are preserved. Skill settings are not changed.'
          '${replacements.isEmpty ? '' : '\n\nReplace existing artwork: ${replacements.map((i) => i.entry.name).join(', ')}. Existing skills and older replays will use this artwork.'}'
          '${[for (final i in replacements)
            if (i.removedNames.isNotEmpty) '\n${i.entry.name}: removed sprites ${i.removedNames.join(', ')}. Affected skills: ${_affected(i).isEmpty ? 'none in this library' : _affected(i).join(', ')}. Removed sprite references use built-in art.'].join()}'
          '\n\nOther library entries are kept. If the connection fails, completed uploads stay restored and failed entries can be retried.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = _message = null;
      _progress = null;
    });
    try {
      final result = await _service.restore(
        _review!,
        _choices,
        progress: _onProgress,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        for (final id in result.restored) {
          _choices[id] = SpriteRestoreChoice.skip;
        }
        _message =
            '${result.restored.length} restored, ${result.skipped.length} skipped, ${result.failed.length} failed.';
      });
      if (result.restored.isNotEmpty) {
        final loader = CustomSpriteLoader(widget.repository);
        await loader.load();
        if (mounted && loader.problems.isNotEmpty) {
          setState(() => _error = loader.problems.join('\n'));
        }
        final library = await widget.repository.list();
        if (mounted) {
          setState(() {
            _atlases = library;
            _selected.addAll(result.restored);
            _exportBytes = null;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Restore failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRestore =
        _review?.any(
          (i) =>
              (_choices[i.entry.id] ?? i.defaultChoice) !=
              SpriteRestoreChoice.skip,
        ) ??
        false;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: DefaultTabController(
            length: 2,
            child: PopScope(
              canPop: !_busy,
              child: Scaffold(
                appBar: AppBar(
                  title: const Text('Sprite backups'),
                  bottom: const TabBar(
                    tabs: [
                      Tab(text: 'Export'),
                      Tab(text: 'Restore'),
                    ],
                  ),
                ),
                body: Column(
                  children: [
                    if (_busy)
                      LinearProgressIndicator(
                        value: _progress == null || _progress!.$2 == 0
                            ? null
                            : _progress!.$1 / _progress!.$2,
                      ),
                    if (_progress != null)
                      Text('${_progress!.$1} / ${_progress!.$2}'),
                    if (_error != null)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 130),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_message!),
                      ),
                    Expanded(
                      child: AbsorbPointer(
                        absorbing: _busy,
                        child: TabBarView(
                          children: [
                            Column(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'Back up uploaded artwork and sprite IDs in one .bwsprites file. Built-in artwork and skill settings are not included. Select up to 64 uploads / 32 MB of artwork.',
                                  ),
                                ),
                                Expanded(
                                  child: _atlases == null
                                      ? Center(
                                          child: _error == null
                                              ? const CircularProgressIndicator()
                                              : TextButton(
                                                  onPressed: _load,
                                                  child: const Text('Retry'),
                                                ),
                                        )
                                      : _atlases!.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'No uploaded sprites to back up.',
                                          ),
                                        )
                                      : ListView(
                                          children: [
                                            CheckboxListTile(
                                              title: const Text('Select all'),
                                              value:
                                                  _selected.length ==
                                                  _atlases!.length,
                                              onChanged: (v) => setState(() {
                                                _exportBytes = null;
                                                _selected.clear();
                                                if (v == true) {
                                                  _selected.addAll(
                                                    _atlases!.map((a) => a.id),
                                                  );
                                                }
                                              }),
                                            ),
                                            for (final a in _atlases!)
                                              CheckboxListTile(
                                                title: Text(a.name),
                                                subtitle: Text(
                                                  '${a.atlas.sprites.length} sprite(s)',
                                                ),
                                                value: _selected.contains(a.id),
                                                onChanged: (v) => setState(() {
                                                  _exportBytes = null;
                                                  v == true
                                                      ? _selected.add(a.id)
                                                      : _selected.remove(a.id);
                                                }),
                                              ),
                                          ],
                                        ),
                                ),
                                SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: _exportBytes == null
                                        ? FilledButton.icon(
                                            key: const ValueKey(
                                              'prepare-sprite-backup',
                                            ),
                                            onPressed: _selected.isEmpty
                                                ? null
                                                : _prepareExport,
                                            icon: const Icon(
                                              Icons.inventory_2_outlined,
                                            ),
                                            label: const Text('Prepare backup'),
                                          )
                                        : Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Ready - ${(_exportBytes!.length / 1024).round()} KB',
                                              ),
                                              FilledButton.icon(
                                                key: const ValueKey(
                                                  'save-sprite-backup',
                                                ),
                                                onPressed: _saveExport,
                                                icon: const Icon(
                                                  Icons.download_outlined,
                                                ),
                                                label: const Text(
                                                  'Save backup file',
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: OutlinedButton.icon(
                                    key: const ValueKey('open-sprite-backup'),
                                    onPressed: _openBackup,
                                    icon: const Icon(Icons.upload_file),
                                    label: const Text('Open .bwsprites backup'),
                                  ),
                                ),
                                Expanded(
                                  child: _review == null
                                      ? const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Text(
                                            'Preview a backup before changing the library. New entries keep their IDs. Conflicts are skipped unless you choose Replace.',
                                          ),
                                        )
                                      : ListView(
                                          children: [
                                            for (final i in _review!)
                                              Card(
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        i.entry.name,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(
                                                        '${i.entry.atlas.sprites.length} sprite(s) - ${(i.entry.sheet.length / 1024).round()} KB',
                                                      ),
                                                      ExpansionTile(
                                                        tilePadding:
                                                            EdgeInsets.zero,
                                                        title: const Text(
                                                          'Sprite contents',
                                                        ),
                                                        children: [
                                                          for (final sprite
                                                              in i
                                                                  .entry
                                                                  .atlas
                                                                  .sprites
                                                                  .values)
                                                            ListTile(
                                                              dense: true,
                                                              title: Text(
                                                                sprite.id
                                                                    .replaceAll(
                                                                      '-',
                                                                      ' ',
                                                                    ),
                                                              ),
                                                              subtitle: Text(
                                                                '${sprite.frames.length} frame(s)',
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      Text(switch (i.status) {
                                                        SpriteRestoreStatus
                                                            .missing =>
                                                          i.sameName
                                                              ? 'Same name, different ID: restores as a separate entry.'
                                                              : 'New entry: original sprite IDs will be restored.',
                                                        SpriteRestoreStatus
                                                            .identical =>
                                                          'Already present: identical artwork and metadata.',
                                                        SpriteRestoreStatus
                                                            .conflict =>
                                                          'Conflict: this ID already has different artwork or metadata.',
                                                      }),
                                                      if (_result?.restored
                                                              .contains(
                                                                i.entry.id,
                                                              ) ??
                                                          false)
                                                        const Text(
                                                          'Restored successfully',
                                                        ),
                                                      if (_result?.failed
                                                              .containsKey(
                                                                i.entry.id,
                                                              ) ??
                                                          false)
                                                        Text(
                                                          'Failed: ${_result!.failed[i.entry.id]}',
                                                          style: TextStyle(
                                                            color: Theme.of(
                                                              context,
                                                            ).colorScheme.error,
                                                          ),
                                                        ),
                                                      DropdownButton<
                                                        SpriteRestoreChoice
                                                      >(
                                                        key: ValueKey(
                                                          'restore-choice-${i.entry.id}',
                                                        ),
                                                        isExpanded: true,
                                                        value:
                                                            _choices[i
                                                                .entry
                                                                .id] ??
                                                            i.defaultChoice,
                                                        items: [
                                                          const DropdownMenuItem(
                                                            value:
                                                                SpriteRestoreChoice
                                                                    .skip,
                                                            child: Text('Skip'),
                                                          ),
                                                          if (i.status ==
                                                              SpriteRestoreStatus
                                                                  .missing)
                                                            const DropdownMenuItem(
                                                              value:
                                                                  SpriteRestoreChoice
                                                                      .restore,
                                                              child: Text(
                                                                'Restore with original IDs',
                                                              ),
                                                            ),
                                                          if (i.status ==
                                                              SpriteRestoreStatus
                                                                  .conflict)
                                                            const DropdownMenuItem(
                                                              value:
                                                                  SpriteRestoreChoice
                                                                      .replace,
                                                              child: Text(
                                                                'Replace existing artwork',
                                                              ),
                                                            ),
                                                        ],
                                                        onChanged:
                                                            (_result?.restored
                                                                    .contains(
                                                                      i
                                                                          .entry
                                                                          .id,
                                                                    ) ??
                                                                false)
                                                            ? null
                                                            : (v) => setState(
                                                                () =>
                                                                    _choices[i
                                                                            .entry
                                                                            .id] =
                                                                        v!,
                                                              ),
                                                      ),
                                                      if (i
                                                          .removedNames
                                                          .isNotEmpty)
                                                        Text(
                                                          'Replacing removes: ${i.removedNames.join(', ')}',
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                ),
                                SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: FilledButton.icon(
                                      key: const ValueKey(
                                        'restore-sprite-backup',
                                      ),
                                      onPressed: hasRestore ? _restore : null,
                                      icon: const Icon(Icons.restore),
                                      label: Text(
                                        _result?.failed.isNotEmpty ?? false
                                            ? 'Retry selected entries'
                                            : 'Restore selected entries',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
