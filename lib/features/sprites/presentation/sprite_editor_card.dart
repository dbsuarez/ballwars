import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/sprites/sprite_atlas.dart';
import '../../../core/sprites/sprite_edit.dart';

class SpriteEditorCard extends StatefulWidget {
  const SpriteEditorCard({
    super.key,
    required this.sprite,
    required this.edit,
    required this.sheet,
    required this.diagnostics,
    required this.onChanged,
    required this.onReset,
    this.expanded = false,
  });
  final SpriteDef sprite;
  final SpriteEdit edit;
  final ui.Image sheet;
  final List<SpriteFrameDiagnostics> diagnostics;
  final VoidCallback onChanged, onReset;
  final bool expanded;
  @override
  State<SpriteEditorCard> createState() => _SpriteEditorCardState();
}

class _SpriteEditorCardState extends State<SpriteEditorCard> {
  late final _name = TextEditingController(
    text: widget.edit.name ?? widget.sprite.label ?? widget.sprite.id,
  );
  late int _fps =
      (60 / (widget.edit.stepsPerFrame ?? widget.sprite.stepsPerFrame))
          .round()
          .clamp(1, 60);
  List<int> get _order =>
      widget.edit.order ?? List.generate(widget.sprite.frames.length, (i) => i);
  Offset get _anchor => widget.edit.anchor ?? widget.sprite.anchor;
  void _change(VoidCallback action) {
    setState(action);
    widget.onChanged();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Widget _row(String label, Widget control) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: control),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      initiallyExpanded: widget.expanded,
      title: Text(widget.edit.name ?? widget.sprite.label ?? widget.sprite.id),
      subtitle: Text(
        '${widget.edit.indexes(widget.sprite.frames.length).length} included frame(s)',
      ),
      childrenPadding: const EdgeInsets.all(12),
      children: [
        _row(
          'Name',
          TextField(
            key: ValueKey('sprite-name-${widget.sprite.id}'),
            controller: _name,
            maxLength: 80,
            decoration: InputDecoration(
              errorText: _name.text.trim().isEmpty ? 'Enter a name' : null,
            ),
            onChanged: (value) => _change(() => widget.edit.name = value),
          ),
        ),
        _row(
          'Frames / second',
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Slower',
                onPressed: _fps <= 1
                    ? null
                    : () => _change(
                        () => widget.edit.stepsPerFrame = (60 / --_fps)
                            .round()
                            .clamp(1, 60),
                      ),
                icon: const Icon(Icons.remove),
              ),
              Text('$_fps', textAlign: TextAlign.right),
              IconButton(
                tooltip: 'Faster',
                onPressed: _fps >= 60
                    ? null
                    : () => _change(
                        () => widget.edit.stepsPerFrame = (60 / ++_fps)
                            .round()
                            .clamp(1, 60),
                      ),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Text(
          'Actual playback: ${(60 / (widget.edit.stepsPerFrame ?? widget.sprite.stepsPerFrame)).toStringAsFixed(1)} fps',
        ),
        for (final axis in ['X', 'Y'])
          _row(
            'Anchor $axis',
            Row(
              children: [
                Expanded(
                  child: Slider(
                    key: ValueKey('sprite-anchor-${widget.sprite.id}-$axis'),
                    min: 0,
                    max: 1,
                    divisions: 100,
                    value: axis == 'X' ? _anchor.dx : _anchor.dy,
                    onChanged: (v) => _change(
                      () => widget.edit.anchor = axis == 'X'
                          ? Offset(v, _anchor.dy)
                          : Offset(_anchor.dx, v),
                    ),
                  ),
                ),
                Text(
                  '${((axis == 'X' ? _anchor.dx : _anchor.dy) * 100).round()}%',
                ),
              ],
            ),
          ),
        const Text(
          'Anchor: 0% is left/top, 100% is right/bottom. It is the point placed on the skill target.',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          key: ValueKey('allow-blank-${widget.sprite.id}'),
          title: const Text('Allow blank frames'),
          subtitle: const Text(
            'Keep intentional pauses or disappearance frames. Otherwise, exclude blank frames before saving.',
          ),
          value: widget.edit.allowBlankFrames,
          onChanged: (v) => _change(() => widget.edit.allowBlankFrames = v),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => _change(
                () => widget.edit.excluded.addAll([
                  for (var i = 0; i < widget.diagnostics.length; i++)
                    if (widget.diagnostics[i].blank) i,
                ]),
              ),
              child: const Text('Exclude blank frames'),
            ),
            TextButton(
              onPressed: () => _change(() => widget.edit.excluded.clear()),
              child: const Text('Include all'),
            ),
            TextButton(
              onPressed: () =>
                  _change(() => widget.edit.order = _order.reversed.toList()),
              child: const Text('Reverse order'),
            ),
          ],
        ),
        const Text(
          'Drag frames to change playback order. Uncheck a frame to exclude it.',
        ),
        if (_order.length != widget.sprite.frames.length ||
            _order.any((i) => i >= widget.sprite.frames.length))
          const Text('Cuts changed. Reset this sprite to edit its new frames.')
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _order.length,
            onReorder: (old, next) => _change(() {
              final order = [..._order];
              if (next > old) next--;
              order.insert(next, order.removeAt(old));
              widget.edit.order = order;
            }),
            itemBuilder: (context, index) {
              final source = _order[index], d = widget.diagnostics[source];
              return ListTile(
                key: ValueKey('frame-${widget.sprite.id}-$source'),
                contentPadding: EdgeInsets.zero,
                leading: Checkbox(
                  value: !widget.edit.excluded.contains(source),
                  onChanged: (v) => _change(
                    () => v == true
                        ? widget.edit.excluded.remove(source)
                        : widget.edit.excluded.add(source),
                  ),
                ),
                title: Row(
                  children: [
                    SizedBox.square(
                      dimension: 36,
                      child: CustomPaint(
                        painter: _CutPreview(
                          widget.sheet,
                          widget.sprite.frames[source],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Frame ${source + 1}${d.blank ? ' - BLANK' : ''}',
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  '${d.transparencyPercent.toStringAsFixed(1)}% transparent, ${d.partial} partial-alpha pixels\n${d.edges} visible edge pixels${d.bounds == null ? '' : ', art ${d.bounds!.width.round()} x ${d.bounds!.height.round()}'}',
                ),
                trailing: ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
              );
            },
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: widget.onReset,
            icon: const Icon(Icons.restore),
            label: const Text('Reset this sprite'),
          ),
        ),
      ],
    ),
  );
}

class _CutPreview extends CustomPainter {
  _CutPreview(this.sheet, this.source);
  final ui.Image sheet;
  final Rect source;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff444444),
    );
    final fit = applyBoxFit(BoxFit.contain, source.size, size);
    canvas.drawImageRect(
      sheet,
      source,
      Alignment.center.inscribe(fit.destination, Offset.zero & size),
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(covariant _CutPreview old) =>
      old.sheet != sheet || old.source != source;
}
