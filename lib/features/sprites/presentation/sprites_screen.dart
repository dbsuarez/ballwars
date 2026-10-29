import 'package:flutter/material.dart';
import '../../../core/sprites/sprite_registry.dart';
import '../../skills/domain/skill_library.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../application/custom_sprite_loader.dart';
import '../data/sprite_atlas_repository.dart';
import 'sprite_import_screen.dart';
import 'sprite_backup_screen.dart';

class SpritesScreen extends StatefulWidget {
  const SpritesScreen({
    super.key,
    required this.repository,
    required this.library,
    required this.tuning,
  });
  final SpriteAtlasRepository repository;
  final SkillLibrary library;
  final PowerUpConfig tuning;
  @override
  State<SpritesScreen> createState() => _SpritesScreenState();
}

class _SpritesScreenState extends State<SpritesScreen> {
  List<CustomAtlas>? _items;
  String? _error;
  bool _busy = false;
  final TextEditingController _search = TextEditingController();
  String _query = '', _filter = 'All';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CustomAtlas> get _filtered => [
    for (final a in _items ?? <CustomAtlas>[])
      if ((_query.isEmpty ||
              '${a.name} ${a.atlas.sprites.keys.join(' ')} ${a.atlas.sprites.values.map((s) => s.label ?? '').join(' ')}'
                  .toLowerCase()
                  .contains(_query)) &&
          (_filter == 'All' || (_filter == 'Assigned') == _users(a).isNotEmpty))
        a,
  ];
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
          _items = items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'Could not load sprites. Check connection and migration 023.\n$e',
        );
      }
    }
  }

  List<String> _users(CustomAtlas atlas) => [
    for (final s in widget.library.all(widget.tuning))
      if (widget.library
          .spriteReferences(s)
          .any((id) => id.startsWith('custom.${atlas.id}.')))
        s.name,
    for (final effect in widget.library.effects.values)
      if (effect.spriteId.startsWith('custom.${atlas.id}.'))
        'Effect: ${effect.name}',
  ];
  Future<void> _import([
    CustomAtlas? existing,
    bool editExisting = false,
  ]) async {
    final saved = await Navigator.push<CustomAtlas>(
      context,
      MaterialPageRoute(
        builder: (_) => SpriteImportScreen(
          repository: widget.repository,
          existing: existing,
          editExisting: editExisting,
          usage: existing == null
              ? const {}
              : {
                  for (final name in existing.atlas.sprites.keys)
                    name: [
                      for (final s in widget.library.all(widget.tuning))
                        if (widget.library
                            .spriteReferences(s)
                            .contains('custom.${existing.id}.$name'))
                          s.name,
                      for (final effect in widget.library.effects.values)
                        if (effect.spriteId == 'custom.${existing.id}.$name')
                          'Effect: ${effect.name}',
                    ],
                },
        ),
      ),
    );
    if (saved == null || !mounted) return;
    setState(() => _busy = true);
    final loader = CustomSpriteLoader(widget.repository);
    await loader.load();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = loader.problems.isEmpty ? null : loader.problems.join('\n');
    });
    await _load();
    if (mounted && loader.problems.isNotEmpty) {
      setState(() => _error = loader.problems.join('\n'));
    }
  }

  Future<void> _delete(CustomAtlas a) async {
    final users = _users(a);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${a.name}?'),
        content: Text(
          users.isEmpty
              ? 'This removes the uploaded artwork. Built-in art is preserved.'
              : 'These skill/effect references will lose artwork:\n${users.join(', ')}\nExisting replays remain playable.',
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
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.delete(a.id);
      SpriteRegistry.unregister('custom.${a.id}');
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = 'Delete failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Sprites'),
            actions: [
              IconButton(
                key: const ValueKey('sprite-backups'),
                tooltip: 'Backup / restore',
                icon: const Icon(Icons.backup_outlined),
                onPressed: _busy
                    ? null
                    : () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SpriteBackupScreen(
                              repository: widget.repository,
                              library: widget.library,
                              tuning: widget.tuning,
                            ),
                          ),
                        );
                        if (mounted) await _load();
                      },
              ),
              IconButton(
                tooltip: 'Refresh sprites',
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  key: const ValueKey('search-sprite-library'),
                  controller: _search,
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search uploads or sprites',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            key: const ValueKey('clear-sprite-library-search'),
                            tooltip: 'Clear search',
                            onPressed: () => setState(() {
                              _search.clear();
                              _query = '';
                            }),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final filter in ['All', 'Assigned', 'Unassigned'])
                      ChoiceChip(
                        label: Text(filter),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                  ],
                ),
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Expanded(
                child: _items == null
                    ? Center(
                        child: _error == null
                            ? const CircularProgressIndicator()
                            : TextButton(
                                onPressed: _load,
                                child: const Text('Retry'),
                              ),
                      )
                    : _items!.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Upload your first icon or sprite sheet. Then select it in Edit Skill > Appearance.',
                          ),
                        ),
                      )
                    : _filtered.isEmpty
                    ? const Center(
                        child: Text('No sprites match your search and filter.'),
                      )
                    : ListView(
                        children: [
                          for (final a in _filtered)
                            ListTile(
                              leading: SpriteThumbnail(
                                id: 'custom.${a.id}.${a.atlas.sprites.keys.first}',
                              ),
                              title: Text(a.name),
                              subtitle: Text(
                                '${a.atlas.sprites.length} sprite(s)\n${_users(a).isEmpty ? 'Not assigned' : _users(a).join(', ')}',
                              ),
                              onTap: () => showDialog<void>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(a.name),
                                  content: SizedBox(
                                    width: 320,
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (final s
                                              in a.atlas.sprites.values)
                                            ListTile(
                                              leading: SpriteThumbnail(
                                                id: 'custom.${a.id}.${s.id}',
                                              ),
                                              title: Text(s.label ?? s.id),
                                              subtitle: Text(
                                                '${s.frames.length} frame(s)',
                                              ),
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
                              ),
                              trailing: PopupMenuButton<String>(
                                tooltip: 'Actions for ${a.name}',
                                enabled: !_busy,
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _import(a, true);
                                  } else if (action == 'replace') {
                                    _import(a);
                                  } else {
                                    _delete(a);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: ListTile(
                                      leading: Icon(Icons.edit_outlined),
                                      title: Text('Edit sprites'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'replace',
                                    child: ListTile(
                                      leading: Icon(Icons.find_replace),
                                      title: Text('Replace artwork'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(Icons.delete_outline),
                                      title: Text('Delete'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _import(),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Import sprites'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class SpriteThumbnail extends StatefulWidget {
  const SpriteThumbnail({super.key, required this.id, this.size = 40});
  final String? id;
  final double size;
  @override
  State<SpriteThumbnail> createState() => _SpriteThumbnailState();
}

class _SpriteThumbnailState extends State<SpriteThumbnail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );
  @override
  void initState() {
    super.initState();
    if (widget.id != null && SpriteRegistry.frameCount(widget.id!) > 1) {
      _clock.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SpriteThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.id != null && SpriteRegistry.frameCount(widget.id!) > 1) {
      _clock.repeat();
    } else {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: AnimatedBuilder(
      animation: _clock,
      builder: (_, _) {
        final image = widget.id == null
            ? null
            : SpriteRegistry.frameAt(widget.id!, (_clock.value * 3600).floor());
        return image == null
            ? const Icon(Icons.image_outlined)
            : ClipRect(
                child: Opacity(
                  opacity: SpriteRegistry.imageOpacity(image),
                  child: Transform.scale(
                    scale: SpriteRegistry.imageScale(image),
                    child: RawImage(
                      image: image,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
              );
      },
    ),
  );
}

Future<String?> selectSkillSprite(
  BuildContext context, {
  required String title,
  String? current,
  bool includeBuiltIns = false,
}) async => showDialog<String>(
  context: context,
  builder: (context) => _SkillSpriteDialog(
    title: title,
    current: current,
    includeBuiltIns: includeBuiltIns,
  ),
);

class _SkillSpriteDialog extends StatefulWidget {
  const _SkillSpriteDialog({
    required this.title,
    this.current,
    this.includeBuiltIns = false,
  });
  final String title;
  final String? current;
  final bool includeBuiltIns;
  @override
  State<_SkillSpriteDialog> createState() => _SkillSpriteDialogState();
}

class _SkillSpriteDialogState extends State<_SkillSpriteDialog> {
  final _search = TextEditingController();
  String _query = '', _filter = 'All';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: SpriteRegistry.revision,
    builder: (context, _, _) {
      final ids =
          SpriteRegistry.ids
              .where(
                (id) =>
                    (widget.includeBuiltIns || id.startsWith('custom.')) &&
                    ('${SpriteRegistry.displayLabel(id)} $id'
                        .toLowerCase()
                        .contains(_query)) &&
                    (_filter == 'All' ||
                        (_filter == 'Animated') ==
                            (SpriteRegistry.frameCount(id) > 1)),
              )
              .toList()
            ..sort(
              (a, b) => SpriteRegistry.displayLabel(a).toLowerCase().compareTo(
                SpriteRegistry.displayLabel(b).toLowerCase(),
              ),
            );
      return AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 360,
          height: (MediaQuery.sizeOf(context).height * .6).clamp(220.0, 460.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('search-skill-sprites'),
                controller: _search,
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search artwork',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          key: const ValueKey('clear-skill-sprite-search'),
                          tooltip: 'Clear search',
                          onPressed: () => setState(() {
                            _search.clear();
                            _query = '';
                          }),
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final f in ['All', 'Static', 'Animated'])
                    ChoiceChip(
                      label: Text(f),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ],
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Built-in art'),
                selected: widget.current == null,
                onTap: () => Navigator.pop(context, ''),
              ),
              if (widget.current != null)
                ListTile(
                  dense: true,
                  leading: SpriteRegistry.has(widget.current!)
                      ? SpriteThumbnail(id: widget.current, size: 28)
                      : const Icon(Icons.warning_amber),
                  title: Text(
                    '${SpriteRegistry.has(widget.current!) ? 'Selected' : 'Missing'}: ${SpriteRegistry.displayLabel(widget.current!)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: SpriteRegistry.has(widget.current!)
                      ? null
                      : const Text(
                          'Using built-in art until this sprite is available.',
                        ),
                ),
              Expanded(
                child: ids.isEmpty
                    ? const Center(
                        child: Text(
                          'No artwork matches. Import sprites from Skill Management > Sprites, or clear the filters.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: ids.length,
                        itemBuilder: (context, index) {
                          final id = ids[index];
                          return Tooltip(
                            message: id,
                            child: ListTile(
                              key: ValueKey('select-sprite-$id'),
                              leading: SpriteThumbnail(id: id),
                              title: Text(
                                SpriteRegistry.collectionLabel(id) ??
                                    (widget.includeBuiltIns
                                        ? 'Built-in / ${id.split('.').first}'
                                        : SpriteRegistry.spriteLabel(id)),
                              ),
                              subtitle: Text(
                                '${SpriteRegistry.spriteLabel(id).replaceAll('-', ' ')} - ${SpriteRegistry.frameCount(id)} frame(s)',
                              ),
                              selected: widget.current == id,
                              trailing: widget.current == id
                                  ? const Icon(Icons.check)
                                  : null,
                              onTap: () => Navigator.pop(context, id),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
}
