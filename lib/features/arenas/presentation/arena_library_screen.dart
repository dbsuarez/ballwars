import 'arena_image_crop.dart';
import '../domain/arena_background_style.dart';
import '../../../core/sprites/sprite_registry.dart';
import '../../sprites/application/custom_sprite_loader.dart';
import '../../settings/presentation/app_settings_scope.dart';
import 'arena_background_import.dart';
import '../../sprites/presentation/sprites_screen.dart';
import '../domain/arena_placement.dart';
import '../../admin_guide/presentation/admin_guide_screen.dart';
import '../../settings/presentation/power_up_test_screen.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/widgets/color_picker_dialog.dart';
import '../../arena_simulation/presentation/arena_preview.dart';
import '../../match_setup/presentation/arena_geometry_editor.dart';
import '../domain/arena_catalog.dart';
import '../domain/arena_theme.dart';
import '../domain/arena_geometry.dart';

class ArenaLibraryScreen extends StatefulWidget {
  const ArenaLibraryScreen({
    super.key,
    required this.initial,
    required this.onSave,
  });
  final ArenaCatalog initial;
  final Future<void> Function(ArenaCatalog) onSave;
  @override
  State<ArenaLibraryScreen> createState() => _ArenaLibraryScreenState();
}

class _ArenaLibraryScreenState extends State<ArenaLibraryScreen> {
  late ArenaCatalog catalog = widget.initial;
  bool busy = false;
  Future<void> persist(ArenaCatalog next) async {
    await widget.onSave(next);
    if (mounted) setState(() => catalog = next);
  }

  String uniqueName(String base) {
    var name = base;
    var i = 2;
    while (catalog.arenas.any(
      (a) => a.name.toLowerCase() == name.toLowerCase(),
    )) {
      name = '$base $i';
      i++;
    }
    return name;
  }

  Future<void> edit([ArenaDefinition? source, bool duplicate = false]) async {
    final draft = source == null
        ? ArenaDefinition(id: const Uuid().v4(), name: uniqueName('New arena'))
        : duplicate
        ? ArenaDefinition.fromJson({
            ...source.toJson(),
            'id': const Uuid().v4(),
            'name': uniqueName(
              '${source.name.characters.take(30).toString()} copy',
            ),
          })
        : source;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArenaEditorScreen(
          initial: draft,
          onSave: (arena) => persist(catalog.withArena(arena)),
        ),
      ),
    );
  }

  Future<void> remove(ArenaDefinition arena) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${arena.name}?'),
        content: const Text(
          'This removes it from new match selections. Existing matches and replays keep their saved arena. If it is the default, new matches fall back to its built-in trap theme.',
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
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await persist(catalog.without(arena.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Arena editor'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Custom arenas'),
            Tab(text: 'Templates'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Create arena',
            onPressed: busy || catalog.arenas.length >= ArenaCatalog.maxArenas
                ? null
                : () => edit(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: TabBarView(
        children: [
          catalog.arenas.isEmpty
              ? Center(
                  child: FilledButton.icon(
                    onPressed: () => edit(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create arena'),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: catalog.arenas.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final arena = catalog.arenas[i];
                    return Card(
                      child: ListTile(
                        onTap: busy ? null : () => edit(arena),
                        leading: ArenaPreview(
                          decoration: arena.trapTheme,
                          arena: arena,
                          size: 64,
                        ),
                        title: Text(arena.name),
                        subtitle: Text(
                          '${arena.shape.label} - ${arena.trapCaption}${arena.enabled ? '' : ' - Hidden'}${catalog.defaultId == arena.id ? ' - Default' : ''}',
                        ),
                        trailing: PopupMenuButton<String>(
                          enabled: !busy,
                          onSelected: (action) {
                            if (action == 'copy') {
                              edit(arena, true);
                            } else {
                              remove(arena);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'copy',
                              child: Text('Duplicate'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ListView(
            children: [
              for (final theme in ArenaDecoration.values)
                ListTile(
                  leading: ArenaPreview(decoration: theme, size: 64),
                  title: Text(theme.label),
                  subtitle: Text(theme.hazardCaption),
                  trailing: const Icon(Icons.copy_outlined),
                  onTap: () => edit(
                    ArenaDefinition(
                      id: 'template_${theme.name}',
                      name: theme.label,
                      theme: theme,
                      trapTheme: theme,
                    ),
                    true,
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class ArenaEditorScreen extends StatefulWidget {
  const ArenaEditorScreen({
    super.key,
    required this.initial,
    required this.onSave,
  });
  final ArenaDefinition initial;
  final Future<void> Function(ArenaDefinition) onSave;
  @override
  State<ArenaEditorScreen> createState() => _ArenaEditorScreenState();
}

class _ArenaEditorScreenState extends State<ArenaEditorScreen> {
  late final name = TextEditingController(text: widget.initial.name);
  late ArenaDecoration theme = widget.initial.theme,
      traps = widget.initial.trapTheme;
  late ArenaShape shape = widget.initial.shape;
  late CenterObstacle obstacle = widget.initial.obstacle;
  late double scale = widget.initial.obstacleScale;
  late int? floor = widget.initial.floorColor,
      accent = widget.initial.accentColor,
      rim = widget.initial.rimColor;
  late String? backgroundSpriteId = widget.initial.backgroundSpriteId;
  late ArenaBackgroundStyle backgroundStyle = widget.initial.backgroundStyle;
  VoidCallback? _imageLease;
  bool _preparedImage = false, _loadingImage = false;
  String? _mediaError;
  late bool enabled = widget.initial.enabled;
  late bool arenaTraps = widget.initial.arenaTrapsEnabled;
  bool busy = false, allowPop = false;
  String? error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_preparedImage) {
      _preparedImage = true;
      if (backgroundSpriteId case final id?) {
        _imageLease = SpriteRegistry.pin([id]);
        if (!SpriteRegistry.has(id)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) loadBackground();
          });
        }
      }
    }
  }

  Future<void> loadBackground() async {
    final id = backgroundSpriteId;
    if (id == null || _loadingImage) return;
    setState(() {
      _loadingImage = true;
      _mediaError = null;
    });
    try {
      final repository = AppSettingsScope.maybeScope(context)?.sprites;
      if (repository == null) {
        throw StateError(
          'Media library is unavailable. Reopen the editor when connected.',
        );
      }
      await CustomSpriteLoader(repository).load();
      if (!SpriteRegistry.has(id)) {
        throw StateError(
          'Background could not be loaded. Check your connection and retry.',
        );
      }
    } catch (e) {
      if (mounted && backgroundSpriteId == id) {
        setState(() => _mediaError = '$e');
      }
    } finally {
      if (mounted) setState(() => _loadingImage = false);
    }
  }

  void selectBackground(String? id) {
    _imageLease?.call();
    _imageLease = id == null ? null : SpriteRegistry.pin([id]);
    setState(() {
      backgroundSpriteId = id;
      backgroundStyle = const ArenaBackgroundStyle();
      _mediaError = null;
    });
    if (id != null && !SpriteRegistry.has(id)) loadBackground();
  }

  Widget mediaTab() => ValueListenableBuilder(
    valueListenable: SpriteRegistry.revision,
    builder: (context, _, _) {
      final image = backgroundSpriteId == null
          ? null
          : SpriteRegistry.frame(backgroundSpriteId!);
      Widget slider(
        String label,
        double value,
        double min,
        double max,
        ValueChanged<double> changed, {
        String? suffix,
      }) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(suffix ?? '${value.toStringAsFixed(2)}×'),
            ],
          ),
          Slider(
            key: ValueKey('arena-background-${label.toLowerCase()}'),
            value: value,
            min: min,
            max: max,
            onChanged: busy ? null : changed,
          ),
        ],
      );
      return ListView(
        key: const PageStorageKey('arena-media-tab'),
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Background image',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: busy || _loadingImage
                    ? null
                    : () async {
                        final id = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ArenaBackgroundImport(),
                          ),
                        );
                        if (id != null && mounted) selectBackground(id);
                      },
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Upload & crop'),
              ),
              OutlinedButton.icon(
                onPressed: busy || _loadingImage
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final id = await selectSkillSprite(
                          context,
                          title: 'Background library',
                          current: backgroundSpriteId,
                        );
                        if (id != null && mounted) {
                          if (!id.endsWith('.background')) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Choose a background imported with Upload & crop.',
                                ),
                              ),
                            );
                            return;
                          }
                          selectBackground(id);
                        }
                      },
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Library'),
              ),
              if (backgroundSpriteId != null)
                TextButton.icon(
                  onPressed: busy ? null : () => selectBackground(null),
                  icon: const Icon(Icons.close),
                  label: const Text('Use template'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (image != null) ...[
            ArenaImageCrop(
              image: image,
              style: backgroundStyle,
              enabled: !busy,
              onChanged: (value) => setState(() => backgroundStyle = value),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Drag to move. Pinch to zoom. Adjustments affect this arena only; the library image stays unchanged. Previously cropped-away areas require the original file.',
              ),
            ),
            slider(
              'Zoom',
              backgroundStyle.zoom,
              1,
              4,
              (v) => setState(
                () => backgroundStyle = backgroundStyle.copyWith(zoom: v),
              ),
            ),
            slider(
              'Horizontal',
              backgroundStyle.x,
              0,
              1,
              (v) => setState(
                () => backgroundStyle = backgroundStyle.copyWith(x: v),
              ),
              suffix: '${(backgroundStyle.x * 100).round()}%',
            ),
            slider(
              'Vertical',
              backgroundStyle.y,
              0,
              1,
              (v) => setState(
                () => backgroundStyle = backgroundStyle.copyWith(y: v),
              ),
              suffix: '${(backgroundStyle.y * 100).round()}%',
            ),
            slider(
              'Dim image',
              backgroundStyle.dim,
              0,
              1,
              (v) => setState(
                () => backgroundStyle = backgroundStyle.copyWith(dim: v),
              ),
              suffix: '${(backgroundStyle.dim * 100).round()}%',
            ),
            const Text(
              'Dimming darkens only the background image. Balls, text, traps and effects keep their colors.',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: busy
                    ? null
                    : () => setState(
                        () => backgroundStyle = const ArenaBackgroundStyle(),
                      ),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset image adjustments'),
              ),
            ),
          ] else if (backgroundSpriteId != null) ...[
            if (_loadingImage) const LinearProgressIndicator(),
            Text(_mediaError ?? 'Background is not loaded yet.'),
            OutlinedButton.icon(
              onPressed: _loadingImage ? null : loadBackground,
              icon: const Icon(Icons.refresh),
              label: const Text('Load image'),
            ),
          ] else
            const Text(
              'Choose a library image or upload one. Template colors stay in Appearance.',
            ),
        ],
      );
    },
  );

  ArenaDefinition get draft => ArenaDefinition(
    id: widget.initial.id,
    name: name.text,
    theme: theme,
    trapTheme: traps,
    shape: shape,
    obstacle: obstacle,
    obstacleScale: scale,
    backgroundSpriteId: backgroundSpriteId,
    backgroundStyle: backgroundStyle,
    floorColor: floor,
    accentColor: accent,
    rimColor: rim,
    enabled: enabled,
    arenaTrapsEnabled: arenaTraps,
  );
  bool get dirty =>
      jsonEncode(draft.toJson()) != jsonEncode(widget.initial.toJson());
  @override
  void dispose() {
    name.dispose();
    _imageLease?.call();
    super.dispose();
  }

  void close() {
    setState(() => allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> back() async {
    if (busy) return;
    if (!dirty) {
      close();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard arena changes?'),
        content: const Text('Your unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) close();
  }

  Future<void> testArena() async {
    FocusScope.of(context).unfocus();
    try {
      final arena = draft.validated();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PowerUpTestScreen(initialArena: arena),
        ),
      );
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message.toString());
    }
  }

  Future<void> save() async {
    if (busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final map = draft.validated();
      final problem = ArenaPlacement.problem(
        shape: map.shape,
        obstacle: map.obstacle,
        obstacleScale: map.obstacleScale,
        minimumScale: AppSettingsScope.of(context).minimumArenaScale,
        ballRadiusRatio: .107 * 1.25,
      );
      if (problem != null) throw FormatException(problem);
      await widget.onSave(map);
      if (mounted) close();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = '$e'
              .replaceFirst('FormatException: ', '')
              .replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget row(String title, Widget control) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        SizedBox(width: 110, child: Text(title)),
        const SizedBox(width: 12),
        Expanded(child: control),
      ],
    ),
  );
  Widget choice<T>(
    T value,
    List<T> values,
    String Function(T) label,
    ValueChanged<T> changed,
  ) => DropdownButton<T>(
    value: value,
    isExpanded: true,
    items: [
      for (final v in values)
        DropdownMenuItem(
          value: v,
          child: Text(label(v), overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: busy
        ? null
        : (v) {
            if (v != null) changed(v);
          },
  );
  Widget colorRow(String label, int? value, ValueChanged<int?> changed) => row(
    label,
    Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 40),
            ),
            onPressed: busy
                ? null
                : () async {
                    final color = await showColorPicker(
                      context,
                      initialColor: Color(value ?? 0xff3b82f6),
                      title: label,
                    );
                    if (color != null && mounted) {
                      setState(
                        () => changed(color.withValues(alpha: 1).toARGB32()),
                      );
                    }
                  },
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  color: value == null ? Colors.transparent : Color(value),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value == null ? 'Theme' : 'Change',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Use theme color',
          onPressed: busy || value == null
              ? null
              : () => setState(() => changed(null)),
          icon: const Icon(Icons.restart_alt),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) back();
    },
    child: DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: busy ? null : back,
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Edit arena'),
          actions: [
            IconButton(
              tooltip: 'Arena editor help',
              onPressed: () => openAdminGuide(context, topic: 'arena-editor'),
              icon: const Icon(Icons.help_outline),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  height: MediaQuery.viewInsetsOf(context).bottom > 0
                      ? 64
                      : 145,
                  child: ArenaPreview(
                    decoration: traps,
                    arena: draft,
                    size: 145,
                  ),
                ),
              ),
              const TabBar(
                labelPadding: EdgeInsets.symmetric(horizontal: 2),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: TextStyle(fontSize: 12),
                tabs: [
                  Tab(text: 'Identity'),
                  Tab(text: 'Appearance'),
                  Tab(text: 'Geometry'),
                  Tab(
                    key: ValueKey('arena-media-tab'),
                    child: Text('Media\nLibrary', textAlign: TextAlign.center),
                  ),
                ],
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    error!,
                    key: const ValueKey('arena-save-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        row(
                          'Name',
                          TextField(
                            key: const ValueKey('arena-name'),
                            controller: name,
                            enabled: !busy,
                            maxLength: ArenaDefinition.maxNameCharacters,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Arena name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Available to players'),
                          subtitle: const Text(
                            'Hidden arenas remain in existing replays.',
                          ),
                          value: enabled,
                          onChanged: busy
                              ? null
                              : (v) => setState(() => enabled = v),
                        ),
                      ],
                    ),
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        row(
                          'Background',
                          choice(
                            theme,
                            ArenaDecoration.values,
                            (v) => v.label,
                            (v) => setState(() => theme = v),
                          ),
                        ),
                        const Text(
                          'Full square artwork is masked by the selected arena boundary. Colors use the theme until you override them.',
                        ),
                        colorRow('Floor', floor, (v) => floor = v),
                        colorRow('Details', accent, (v) => accent = v),
                        colorRow('Boundary', rim, (v) => rim = v),
                      ],
                    ),
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Arena geometry'),
                          subtitle: Text(
                            '${shape.label} boundary - ${obstacle.label} center obstacle',
                          ),
                          trailing: const Icon(Icons.tune),
                          onTap: busy
                              ? null
                              : () async {
                                  final picked = await showArenaGeometryEditor(
                                    context,
                                    shape: shape,
                                    obstacle: obstacle,
                                    scale: scale,
                                    allowRotation: false,
                                  );
                                  if (picked != null && mounted) {
                                    setState(() {
                                      shape = picked.shape;
                                      obstacle = picked.obstacle;
                                      scale = picked.scale;
                                    });
                                  }
                                },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Arena traps by default'),
                          value: arenaTraps,
                          onChanged: busy
                              ? null
                              : (v) => setState(() => arenaTraps = v),
                        ),
                        row(
                          'Arena traps',
                          choice(
                            traps,
                            ArenaDecoration.values,
                            (v) => v.hazardCaption,
                            (v) => setState(() => traps = v),
                          ),
                        ),
                        const Text(
                          'Arena trap damage, timing and effects come from Skill Management. Match trap toggles still apply. Players can override geometry in Match Settings.',
                        ),
                      ],
                    ),
                    mediaTab(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: busy ? null : back,
                      child: const Text('Cancel'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('test-arena'),
                      onPressed: busy ? null : testArena,
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Test'),
                    ),
                    FilledButton.icon(
                      key: const ValueKey('save-arena'),
                      onPressed: busy ? null : save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(busy ? 'Saving...' : 'Save'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
