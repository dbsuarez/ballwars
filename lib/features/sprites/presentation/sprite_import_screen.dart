import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/sprites/sprite_atlas.dart';
import '../../../core/sprites/sprite_import.dart';
import '../../../core/sprites/sprite_registry.dart';
import '../../../core/sprites/sprite_replacement.dart';
import '../../../core/sprites/sprite_edit.dart';
import '../../../core/widgets/color_picker_dialog.dart';
import 'sprite_editor_card.dart';
import 'sprite_comparison_preview.dart';
import '../data/sprite_atlas_repository.dart';

/// Metadata editor only: the original uploaded pixels remain intact.
class SpriteImportScreen extends StatefulWidget {
  const SpriteImportScreen({
    super.key,
    required this.repository,
    this.existing,
    this.usage = const {},
    this.editExisting = false,
  });
  final SpriteAtlasRepository repository;
  final CustomAtlas? existing;
  final bool editExisting;

  /// Existing sprite name -> names of affected skills (including draft changes).
  final Map<String, List<String>> usage;
  @override
  State<SpriteImportScreen> createState() => _SpriteImportScreenState();
}

class _SpriteImportScreenState extends State<SpriteImportScreen> {
  final _name = TextEditingController();
  final _sprite = TextEditingController(text: 'sprite');
  Uint8List? _bytes;
  ui.Image? _image;
  Uint8List? _rgba;
  String _file = '', _error = '';
  Map<String, dynamic>? _metadata;
  SpriteAtlas? _loadedAtlas;
  int _columns = 1, _rows = 1, _inset = 0, _fps = 10, _preview = 0;
  int get _steps => (60 / _fps).round().clamp(1, 60);
  int _frameSize = 128;
  bool _animation = true, _busy = false, _trimEdges = false;
  SpriteFit _fit = SpriteFit.contain;
  Offset _anchor = const Offset(.5, .5);
  bool _opaque = false;
  bool _blank = false;
  final Map<String, SpriteEdit> _edits = {};
  final Map<Rect, SpriteFrameDiagnostics> _diagnostics = {};
  int _editReset = 0, _sourceVersion = 0;
  bool _smooth = false, _previewBusy = false;
  SpritePreviewBackground _previewBackground = SpritePreviewBackground.dark;
  Color _ballColor = const Color(0xffe65c56);
  ui.Image? _optimized;
  SpriteAtlas? _optimizedAtlas;
  String? _optimizedSignature;
  String _signature(SpriteAtlas atlas) =>
      '$_sourceVersion:$_frameSize:$_smooth:${jsonEncode(spriteAtlasJson(atlas))}';
  SpriteFrameDiagnostics _inspect(Rect frame) => _diagnostics.putIfAbsent(
    frame,
    () => SpriteFrameDiagnostics.inspect(
      _rgba!,
      _image!.width,
      _image!.height,
      frame,
    ),
  );
  SpriteEdit _edit(String id) => _edits.putIfAbsent(id, SpriteEdit.new);
  final Map<String, String?> _mapping = {};
  @override
  void initState() {
    super.initState();
    final old = widget.existing;
    if (old != null) {
      _name.text = old.name;
      if (old.atlas.sprites.length == 1) {
        _sprite.text = old.atlas.sprites.keys.single;
        final sprite = old.atlas.sprites.values.single;
        _fps = (60 / sprite.stepsPerFrame).round().clamp(1, 60);
        _anchor = sprite.anchor;
      }
      _frameSize = old.atlas.sprites.values.any((s) => s.output > 128)
          ? 256
          : 128;
      if (widget.editExisting) _loadExisting();
    }
  }

  Map<String, String?> _effectiveMapping(SpriteAtlas next) => {
    ...SpriteReplacement.defaults(widget.existing!.atlas, next),
    ..._mapping,
  };
  SpriteAtlas? get _cuts {
    if (_loadedAtlas != null) return _loadedAtlas;
    final image = _image;
    if (image == null) return null;
    final base = _metadata != null
        ? SpriteImport.metadata(_metadata!, sheet: _file)
        : SpriteImport.grid(
            sheet: _file,
            width: image.width,
            height: image.height,
            columns: _columns,
            rows: _rows,
            animation: _animation,
            spriteName: _sprite.text,
            stepsPerFrame: _steps,
            inset: _inset,
          );
    return SpriteAtlas(
      sheet: base.sheet,
      sheetSize: base.sheetSize,
      sprites: {
        for (final s in base.sprites.values)
          s.id: SpriteDef(
            id: s.id,
            frames: _trimEdges && _metadata == null && _rgba != null
                ? SpriteImport.trimToCleanEdges(
                    _rgba!,
                    image.width,
                    image.height,
                    s.frames,
                  )
                : s.frames,
            output: 128,
            anchor: _anchor,
            fit: s.sourceSizes == null ? _fit : SpriteFit.contain,
            sourceSizes: s.sourceSizes,
            sourceOffsets: s.sourceOffsets,
            stepsPerFrame: _metadata == null ? _steps : s.stepsPerFrame,
          ),
      },
    );
  }

  SpriteAtlas? get _atlas {
    final cuts = _cuts;
    if (cuts == null) return null;
    final sprites = <String, SpriteDef>{};
    for (final original in cuts.sprites.values) {
      final s = (_edits[original.id] ?? SpriteEdit()).apply(original);
      if (sprites.containsKey(s.id)) {
        throw FormatException(
          'Duplicate sprite name: ${s.id}. Give each sprite a unique name.',
        );
      }
      sprites[s.id] = s;
    }
    return SpriteAtlas(
      sheet: cuts.sheet,
      sheetSize: cuts.sheetSize,
      sprites: sprites,
    );
  }

  List<String> _problems(SpriteAtlas atlas) => [
    if (_blank)
      'The image is fully transparent. Choose artwork with visible pixels.',
    ...atlas.problems(
      sheetSize: Size(_image!.width.toDouble(), _image!.height.toDouble()),
    ),
    if (_rgba != null)
      for (final original in _cuts!.sprites.values)
        if (!(_edits[original.id]?.allowBlankFrames ?? false))
          for (final i in (_edits[original.id] ?? SpriteEdit()).indexes(
            original.frames.length,
          ))
            if (i < original.frames.length &&
                _inspect(original.frames[i]).blank)
              '${_edits[original.id]?.name ?? original.id} frame ${i + 1} is blank. Exclude it or enable Allow blank frames.',
    if (_metadata == null && _loadedAtlas == null && _rgba != null)
      ...SpriteImport.edgeProblems(
        atlas,
        _rgba!,
        _image!.width,
        _image!.height,
      ),
  ];

  Future<void> _pick() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'webp'],
        withData: true,
      );
      if (picked == null) return;
      final f = picked.files.single;
      final bytes = f.bytes;
      if (bytes == null) {
        throw const FormatException(
          'Cannot read that file. Please choose it again.',
        );
      }
      final type = f.name.toLowerCase().endsWith('.webp')
          ? 'image/webp'
          : 'image/png';
      final image = await validateSpriteSheet(bytes, type, source: true);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      var opaque = true;
      var blank = true;
      if (data != null) {
        for (var i = 3; i < data.lengthInBytes; i += 4) {
          final alpha = data.getUint8(i);
          if (alpha < 255) opaque = false;
          if (alpha >= 24) blank = false;
          if (!opaque && !blank) break;
        }
      }
      if (!mounted) {
        image.dispose();
        return;
      }
      _image?.dispose();
      setState(() {
        _image = image;
        _sourceVersion++;
        _edits.clear();
        _diagnostics.clear();
        _editReset++;
        _optimized?.dispose();
        _optimized = null;
        _optimizedAtlas = null;
        _optimizedSignature = null;
        _opaque = opaque;
        _blank = blank;
        _bytes = bytes;
        _rgba = data?.buffer.asUint8List();
        _file = f.name;
        _metadata = null;
        _loadedAtlas = null;
        _mapping.clear();
        _columns = _rows = 1;
        _inset = _preview = 0;
        _error = '';
        if (_name.text.isEmpty) {
          _name.text = f.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open sheet: $e');
    }
  }

  Future<void> _loadExisting() async {
    final old = widget.existing!;
    setState(() => _busy = true);
    ui.Image? image;
    try {
      final bytes = await fetchSpriteSheet(Uri.parse(old.sheetUrl));
      image = await validateSpriteSheet(
        bytes,
        old.sheetPath.endsWith('.webp') ? 'image/webp' : 'image/png',
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (!mounted) {
        image.dispose();
        return;
      }
      final rgba = data!.buffer.asUint8List();
      var opaque = true, blank = true;
      for (var i = 3; i < rgba.length; i += 4) {
        if (rgba[i] < 255) opaque = false;
        if (rgba[i] >= 24) blank = false;
        if (!opaque && !blank) break;
      }
      setState(() {
        _image?.dispose();
        _image = image;
        _bytes = bytes;
        _rgba = rgba;
        _opaque = opaque;
        _blank = blank;
        _file = old.name;
        _loadedAtlas = old.atlas;
        _sourceVersion++;
        _diagnostics.clear();
        _edits.clear();
      });
    } catch (e) {
      image?.dispose();
      if (mounted) {
        setState(() => _error = 'Could not load current artwork: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<({SpriteAtlas atlas, Uint8List bytes})> _prepareUpload(
    SpriteAtlas atlas,
    ui.Image sheet,
  ) async {
    if (_loadedAtlas != null &&
        !_smooth &&
        atlas.sprites.values.every(
          (s) => s.output <= _frameSize && s.height <= _frameSize,
        )) {
      return (atlas: atlas, bytes: _bytes!);
    }
    return SpriteRegistry.normalizeUpload(
      atlas,
      sheet,
      frameSize: _frameSize,
      filterQuality: _smooth ? FilterQuality.medium : FilterQuality.none,
    );
  }

  Future<void> _pickJson() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (picked == null) return;
      final bytes = picked.files.single.bytes;
      if (bytes == null || bytes.length > 262144) {
        throw const FormatException(
          'JSON must be readable and no larger than 256 KB.',
        );
      }
      final metadata = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(bytes)) as Map,
      );
      SpriteImport.metadata(metadata, sheet: _file);
      if (mounted) {
        setState(() {
          _metadata = metadata;
          _loadedAtlas = null;
          _edits.clear();
          _editReset++;
          _mapping.clear();
          _preview = 0;
          _error = '';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not import JSON: $e');
    }
  }

  Future<void> _save(SpriteAtlas atlas) async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final mapping = widget.existing == null
          ? <String, String?>{}
          : _effectiveMapping(atlas);
      final replacement = widget.existing == null
          ? atlas
          : SpriteReplacement.apply(atlas, mapping);
      final removed = mapping.entries
          .where((e) => e.value == null)
          .map((e) => e.key)
          .toList();
      final affected = {
        for (final name in removed) ...?widget.usage[name],
      }.toList();
      final remapped = mapping.entries
          .where((e) => e.value != null && e.key != e.value)
          .map((e) => '${e.key} uses ${e.value}')
          .join(', ');
      final optimized = await _prepareUpload(replacement, _image!);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(
            widget.existing == null
                ? 'Upload optimized artwork?'
                : 'Replace ${widget.existing!.name}?',
          ),
          content: Text(
            'Original: ${_image!.width} x ${_image!.height}, ${(_bytes!.length / 1024).round()} KB\nUpload: ${optimized.atlas.sheetSize!.width.round()} x ${optimized.atlas.sheetSize!.height.round()}, ${(optimized.bytes.length / 1024).round()} KB\nMaximum per frame: $_frameSize x $_frameSize\nTransparency and proportions are preserved. Your original file stays untouched.'
            '${widget.existing == null ? '' : '\n\n${mapping.values.whereType<String>().length} existing sprite IDs preserved. Existing assignments and replays use the replacement artwork.'}'
            '${remapped.isEmpty ? '' : '\nArtwork matches: $remapped'}'
            '${removed.isEmpty ? '' : '\n\nRemoved sprites: ${removed.join(', ')}. Their assignments fall back to built-in art. This also applies to older replays.'}'
            '${affected.isEmpty ? '' : '\nAffected skills: ${affected.join(', ')}'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(widget.existing == null ? 'Upload' : 'Replace'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final saved = await widget.repository.save(
        id: widget.existing?.id,
        expectedUpdatedAt: widget.existing?.updatedAt,
        name: _name.text,
        sheet: optimized.bytes,
        contentType: optimized.bytes[0] == 137 ? 'image/png' : 'image/webp',
        atlas: optimized.atlas,
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'Upload failed. Your edits are kept. Check connection, admin login and migration 023, then retry.\n$e';
        });
      }
    }
  }

  Future<void> _generateComparison(SpriteAtlas atlas) async {
    final signature = _signature(atlas), source = _image!.clone();
    setState(() => _previewBusy = true);
    ui.Codec? codec;
    ui.Image? optimized;
    try {
      final result = await _prepareUpload(atlas, source);
      codec = await ui.instantiateImageCodec(result.bytes);
      optimized = (await codec.getNextFrame()).image;
      String? current;
      try {
        final a = _atlas;
        if (a != null) current = _signature(a);
      } catch (_) {
        /* Keep invalid edits for correction. */
      }
      if (!mounted || current != signature) {
        optimized.dispose();
        return;
      }
      setState(() {
        _optimized?.dispose();
        _optimized = optimized;
        _optimizedAtlas = result.atlas;
        _optimizedSignature = signature;
        _error = '';
      });
    } catch (e) {
      optimized?.dispose();
      if (mounted) setState(() => _error = 'Could not generate comparison: $e');
    } finally {
      source.dispose();
      codec?.dispose();
      if (mounted) setState(() => _previewBusy = false);
    }
  }

  Widget _row(String label, Widget control) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Expanded(child: control),
      ],
    ),
  );
  Widget _number(String label, int value, int max, ValueChanged<int> change) =>
      _row(
        label,
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Decrease $label',
              onPressed: value > (label == 'Cell inset' ? 0 : 1)
                  ? () => setState(() => change(value - 1))
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Text('$value', textAlign: TextAlign.right),
            IconButton(
              tooltip: 'Increase $label',
              onPressed: value < max
                  ? () => setState(() => change(value + 1))
                  : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      );
  @override
  void dispose() {
    _name.dispose();
    _sprite.dispose();
    _image?.dispose();
    _optimized?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SpriteAtlas? atlas;
    String? issue;
    try {
      atlas = _atlas;
      if (atlas != null) {
        final p = _problems(atlas);
        if (p.isNotEmpty) issue = p.join('\n');
        if (widget.existing != null) {
          SpriteReplacement.apply(atlas, _effectiveMapping(atlas));
        }
      }
    } catch (e) {
      issue = e.toString();
    }
    final sprites = atlas?.sprites.values.toList() ?? <SpriteDef>[];
    final selected = sprites.isEmpty
        ? null
        : sprites[_preview.clamp(0, sprites.length - 1)];
    SpriteAtlas? cuts;
    try {
      cuts = _cuts;
    } catch (_) {
      /* Slice controls remain available to fix the input. */
    }
    final fresh = atlas != null && _optimizedSignature == _signature(atlas);
    final canSave =
        atlas != null &&
        issue == null &&
        _name.text.trim().isNotEmpty &&
        !_busy;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: DefaultTabController(
            length: 4,
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  widget.existing == null
                      ? 'Import sprites'
                      : widget.editExisting
                      ? 'Edit sprites'
                      : 'Replace sprites',
                ),
                bottom: const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'Sheet'),
                    Tab(text: 'Slices'),
                    Tab(text: 'Sprites'),
                    Tab(text: 'Preview'),
                  ],
                ),
              ),
              body: Column(
                children: [
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        ListView(
                          key: const ValueKey('sprite-import-sheet'),
                          padding: const EdgeInsets.all(16),
                          children: [
                            const Text(
                              'Upload your artwork. Single icon: keep a 1 x 1 grid. Sheet: choose separate icons or animation on Slices.',
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              key: const ValueKey('pick-sprite-sheet'),
                              onPressed: _busy ? null : _pick,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Choose PNG / WebP'),
                            ),
                            const Text(
                              'Source: up to 16 MB, 8192 pixels per side and 16 megapixels. Automatically resized before upload. Transparent backgrounds recommended.',
                            ),
                            if (_image != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                '$_file - ${_image!.width} x ${_image!.height}',
                              ),
                              SizedBox(
                                height: 200,
                                child: CustomPaint(
                                  painter: const _Checkerboard(),
                                  child: RawImage(
                                    image: _image,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.none,
                                  ),
                                ),
                              ),
                            ],
                            if (_opaque)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'No transparency detected. The background will appear in the game. Export PNG / WebP with a transparent background if that is unintended.',
                                ),
                              ),
                            _row(
                              'Artwork use',
                              DropdownButton<int>(
                                isExpanded: true,
                                value: _frameSize,
                                items: const [
                                  DropdownMenuItem(
                                    value: 128,
                                    child: Text('Icon / held (128 px)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 256,
                                    child: Text('Projectile / effect (256 px)'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _frameSize = v!),
                              ),
                            ),
                            _row(
                              'Upload name',
                              TextField(
                                key: const ValueKey('sprite-upload-name'),
                                controller: _name,
                                maxLength: 80,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  hintText: 'Kage Bunshin',
                                ),
                              ),
                            ),
                            _row(
                              'Resizing',
                              DropdownButton<bool>(
                                key: const ValueKey('sprite-resampling'),
                                isExpanded: true,
                                value: _smooth,
                                items: const [
                                  DropdownMenuItem(
                                    value: false,
                                    child: Text('Pixel art'),
                                  ),
                                  DropdownMenuItem(
                                    value: true,
                                    child: Text('Smooth'),
                                  ),
                                ],
                                onChanged: (v) => setState(() => _smooth = v!),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _image == null || _busy
                                  ? null
                                  : _pickJson,
                              icon: const Icon(Icons.data_object),
                              label: const Text(
                                'Import Aseprite / TexturePacker JSON',
                              ),
                            ),
                            if (_metadata != null)
                              TextButton(
                                onPressed: () =>
                                    setState(() => _metadata = null),
                                child: const Text('Remove JSON and use grid'),
                              ),
                          ],
                        ),
                        ListView(
                          key: const ValueKey('sprite-import-slices'),
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (_metadata != null || _loadedAtlas != null)
                              const Text(
                                'Slices and animation timing come from the JSON. Trimmed frame positions are preserved.',
                              )
                            else ...[
                              _number(
                                'Columns',
                                _columns,
                                256,
                                (v) => _columns = v,
                              ),
                              _number('Rows', _rows, 256, (v) => _rows = v),
                              _number(
                                'Cell inset',
                                _inset,
                                40,
                                (v) => _inset = v,
                              ),
                              _row(
                                'Sheet contains',
                                DropdownButton<bool>(
                                  isExpanded: true,
                                  value: _animation,
                                  items: const [
                                    DropdownMenuItem(
                                      value: true,
                                      child: Text('One animation'),
                                    ),
                                    DropdownMenuItem(
                                      value: false,
                                      child: Text('Separate icons'),
                                    ),
                                  ],
                                  onChanged: (v) => setState(() {
                                    _animation = v!;
                                    _preview = 0;
                                  }),
                                ),
                              ),
                              const Text(
                                'Frames read left to right, then top to bottom. Keep a transparent gutter between cells to prevent neighboring artwork bleeding.',
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Trim to clean edges'),
                                subtitle: const Text(
                                  'Move cuts inward to a clear row or column. Review the boxes before saving; original pixels are preserved.',
                                ),
                                value: _trimEdges,
                                onChanged: (v) =>
                                    setState(() => _trimEdges = v),
                              ),
                            ],
                            if (_image != null)
                              SizedBox(
                                height: 250,
                                child: CustomPaint(
                                  painter: _SheetPainter(
                                    _image!,
                                    atlas,
                                    issue != null,
                                  ),
                                ),
                              ),
                            if (issue != null)
                              Text(
                                issue,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                          ],
                        ),
                        ListView(
                          key: const ValueKey('sprite-import-sprites'),
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (_metadata == null && _loadedAtlas == null) ...[
                              _row(
                                'Sprite name',
                                TextField(
                                  controller: _sprite,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    hintText: 'shadow-clone',
                                  ),
                                ),
                              ),
                              _number(
                                'Frames / second',
                                _fps,
                                60,
                                (v) => _fps = v,
                              ),
                              Text(
                                '${(60 / _steps).toStringAsFixed(1)} frames / second',
                              ),
                            ],
                            if (widget.existing != null && atlas != null) ...[
                              const Divider(),
                              const Text(
                                'Preserve existing assignments',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                'Match each existing sprite to artwork in the new sheet. Its saved ID stays unchanged. Remove makes affected skills and older replays use built-in art.',
                              ),
                              for (final name
                                  in widget.existing!.atlas.sprites.keys)
                                _row(
                                  name,
                                  DropdownButton<String>(
                                    key: ValueKey('replacement-$name'),
                                    isExpanded: true,
                                    value:
                                        atlas.sprites.containsKey(
                                          _effectiveMapping(atlas)[name],
                                        )
                                        ? _effectiveMapping(atlas)[name]
                                        : '',
                                    items: [
                                      const DropdownMenuItem(
                                        value: '',
                                        child: Text('Remove'),
                                      ),
                                      for (final next in atlas.sprites.keys)
                                        DropdownMenuItem(
                                          value: next,
                                          child: Text(
                                            next,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                    onChanged: (value) => setState(
                                      () => _mapping[name] = value == ''
                                          ? null
                                          : value,
                                    ),
                                  ),
                                ),
                              const Divider(),
                            ],
                            _row(
                              'Fit',
                              DropdownButton<SpriteFit>(
                                isExpanded: true,
                                value: _metadata == null
                                    ? _fit
                                    : SpriteFit.contain,
                                items: [
                                  for (final f in SpriteFit.values)
                                    DropdownMenuItem(
                                      value: f,
                                      child: Text(f.name),
                                    ),
                                ],
                                onChanged:
                                    _metadata != null || _loadedAtlas != null
                                    ? null
                                    : (v) => setState(() => _fit = v!),
                              ),
                            ),
                            if (cuts != null &&
                                cuts
                                    .problems(
                                      sheetSize: Size(
                                        _image!.width.toDouble(),
                                        _image!.height.toDouble(),
                                      ),
                                    )
                                    .isEmpty)
                              for (final s in cuts.sprites.values)
                                SpriteEditorCard(
                                  key: ValueKey(
                                    'sprite-editor-${s.id}-$_editReset',
                                  ),
                                  sprite: s,
                                  edit: _edit(s.id),
                                  sheet: _image!,
                                  diagnostics: [
                                    for (final f in s.frames) _inspect(f),
                                  ],
                                  expanded: cuts.sprites.length == 1,
                                  onChanged: () => setState(() {}),
                                  onReset: () => setState(() {
                                    _edits.remove(s.id);
                                    _editReset++;
                                  }),
                                ),
                            _row(
                              'Anchor',
                              DropdownButton<Offset>(
                                isExpanded: true,
                                value: _anchor,
                                items: [
                                  if (!const [
                                    Offset(.5, .5),
                                    Offset(.5, 1),
                                    Offset(0, .5),
                                  ].contains(_anchor))
                                    DropdownMenuItem(
                                      value: _anchor,
                                      child: const Text('Existing anchor'),
                                    ),
                                  const DropdownMenuItem(
                                    value: Offset(.5, .5),
                                    child: Text('Center'),
                                  ),
                                  const DropdownMenuItem(
                                    value: Offset(.5, 1),
                                    child: Text('Bottom'),
                                  ),
                                  const DropdownMenuItem(
                                    value: Offset(0, .5),
                                    child: Text('Left / grip'),
                                  ),
                                ],
                                onChanged: (v) => setState(() => _anchor = v!),
                              ),
                            ),
                            for (var i = 0; i < sprites.length; i++)
                              ListTile(
                                title: Text(sprites[i].label ?? sprites[i].id),
                                subtitle: Text(
                                  '${sprites[i].frames.length} frame(s) - ${(60 / sprites[i].stepsPerFrame).toStringAsFixed(1)} fps',
                                ),
                                selected: i == _preview,
                                onTap: () => setState(() => _preview = i),
                              ),
                          ],
                        ),
                        ListView(
                          key: const ValueKey('sprite-import-preview'),
                          padding: const EdgeInsets.all(16),
                          children: [
                            const Text(
                              'Animation preview. The source pixels are preserved; fit controls how artwork fills the skill slot. Tint and gameplay size are configured in Edit Skill.',
                            ),
                            _row(
                              'Background',
                              DropdownButton<SpritePreviewBackground>(
                                key: const ValueKey(
                                  'sprite-preview-background',
                                ),
                                isExpanded: true,
                                value: _previewBackground,
                                items: [
                                  for (final b
                                      in SpritePreviewBackground.values)
                                    DropdownMenuItem(
                                      value: b,
                                      child: Text(b.name),
                                    ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _previewBackground = v!),
                              ),
                            ),
                            _row(
                              'Ball color',
                              OutlinedButton.icon(
                                key: const ValueKey(
                                  'sprite-preview-ball-color',
                                ),
                                icon: Icon(Icons.circle, color: _ballColor),
                                label: const Text('Choose'),
                                onPressed: () async {
                                  final color = await showColorPicker(
                                    context,
                                    initialColor: _ballColor,
                                    title: 'Preview ball color',
                                  );
                                  if (color != null && mounted) {
                                    setState(() => _ballColor = color);
                                  }
                                },
                              ),
                            ),
                            if (selected != null && _image != null)
                              SpriteComparisonPreview(
                                source: _image!,
                                sprite: selected,
                                optimized: fresh ? _optimized : null,
                                optimizedSprite: fresh
                                    ? _optimizedAtlas?.sprites[selected.id]
                                    : null,
                                background: _previewBackground,
                                ballColor: _ballColor,
                              ),
                            if (_optimized != null && !fresh)
                              const Text(
                                'Edits changed. Generate a new comparison to see the current upload.',
                              ),
                            OutlinedButton.icon(
                              key: const ValueKey('generate-sprite-comparison'),
                              onPressed:
                                  atlas == null || issue != null || _previewBusy
                                  ? null
                                  : () => _generateComparison(atlas!),
                              icon: const Icon(Icons.compare),
                              label: Text(
                                _previewBusy
                                    ? 'Generating...'
                                    : 'Generate optimized comparison',
                              ),
                            ),
                            if (sprites.length > 1)
                              DropdownButton<int>(
                                isExpanded: true,
                                value: _preview.clamp(0, sprites.length - 1),
                                items: [
                                  for (var i = 0; i < sprites.length; i++)
                                    DropdownMenuItem(
                                      value: i,
                                      child: Text(
                                        sprites[i].label ?? sprites[i].id,
                                      ),
                                    ),
                                ],
                                onChanged: (v) => setState(() => _preview = v!),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (issue != null)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 72),
                          child: SingleChildScrollView(
                            child: Text(
                              issue,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      FilledButton.icon(
                        key: const ValueKey('save-sprite-upload'),
                        onPressed: canSave ? () => _save(atlas!) : null,
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _busy
                              ? 'Uploading...'
                              : widget.existing == null || widget.editExisting
                              ? 'Save sprites'
                              : 'Replace sprites',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetPainter extends CustomPainter {
  _SheetPainter(this.image, this.atlas, this.invalid);
  final ui.Image image;
  final SpriteAtlas? atlas;
  final bool invalid;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width / image.width).clamp(
      0.0,
      size.height / image.height,
    );
    canvas.scale(scale);
    canvas.drawImage(
      image,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.none,
    );
    for (final s in atlas?.sprites.values ?? <SpriteDef>[]) {
      for (final r in s.frames) {
        canvas.drawRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1 / scale
            ..color = invalid ? Colors.red : Colors.cyan,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SheetPainter old) => true;
}

class _Checkerboard extends CustomPainter {
  const _Checkerboard();
  @override
  void paint(Canvas canvas, Size size) {
    for (var y = 0.0; y < size.height; y += 12) {
      for (var x = 0.0; x < size.width; x += 12) {
        canvas.drawRect(
          Rect.fromLTWH(x, y, 12, 12),
          Paint()
            ..color = ((x ~/ 12 + y ~/ 12).isEven
                ? const Color(0xff303030)
                : const Color(0xff484848)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Checkerboard old) => false;
}
