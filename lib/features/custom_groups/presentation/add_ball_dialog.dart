import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../ball_management/presentation/ball_editor_dialog.dart' show kNeonColorPresets;
import '../../ball_management/presentation/widgets/circular_ball_preview.dart';
import '../data/custom_group_repository.dart';
import '../data/image_prep.dart';

/// Adds a ball to a user group, or edits one ([existing]): name, picture,
/// how the picture sits on the ball (logo on white, or filling it) and its
/// line color (suggested from the picture). New pictures are shrunk to a
/// small PNG and uploaded; when editing, the picture is optional.
class AddBallDialog extends StatefulWidget {
  final String groupId;
  final CustomGroupRepository repository;
  final CustomBall? existing;

  const AddBallDialog({super.key, required this.groupId, required this.repository, this.existing});

  /// The added or updated ball, or null if cancelled.
  static Future<CustomBall?> show(
    BuildContext context, {
    required String groupId,
    required CustomGroupRepository repository,
    CustomBall? existing,
  }) =>
      showDialog<CustomBall>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AddBallDialog(groupId: groupId, repository: repository, existing: existing),
      );

  @override
  State<AddBallDialog> createState() => _AddBallDialogState();
}

class _AddBallDialogState extends State<AddBallDialog> {
  final TextEditingController _name = TextEditingController();
  Uint8List? _picked;
  PreparedImage? _prepared;
  BallImageStyle _style = BallImageStyle.logo;
  Color? _color;
  bool _working = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _name.text = existing.name;
      _style = existing.imageStyle;
      _color = existing.primaryColor;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Color get _lineColor => _color ?? _prepared?.suggestedColor ?? kNeonColorPresets.first;

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;
    if (_name.text.trim().isEmpty) {
      final file = result!.files.single.name;
      _name.text = file.contains('.') ? file.substring(0, file.lastIndexOf('.')) : file;
    }
    _picked = bytes;
    await _prepare();
  }

  Future<void> _prepare() async {
    final bytes = _picked;
    if (bytes == null) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final prepared = await ImagePrep.prepare(bytes, _style);
      if (mounted) setState(() => _prepared = prepared);
    } catch (_) {
      if (mounted) setState(() => _error = "That image couldn't be read. Try a PNG or JPEG.");
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _save() async {
    final prepared = _prepared;
    final name = _name.text.trim();
    if ((prepared == null && !_editing) || name.isEmpty) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final existing = widget.existing;
      final ball = existing == null
          ? await widget.repository.addBall(
              groupId: widget.groupId,
              name: name,
              png: prepared!.png,
              style: _style,
              color: _lineColor,
            )
          : await widget.repository.updateBall(
              existing,
              name: name,
              style: _style,
              color: _lineColor,
              png: prepared?.png,
            );
      if (mounted) Navigator.of(context).pop(ball);
    } catch (e) {
      if (mounted) {
        setState(() {
          _working = false;
          _error = '${_editing ? 'Saving' : 'Upload'} failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = CustomBall(
      id: 'preview',
      name: _name.text.isEmpty ? '?' : _name.text,
      imageBytes: _prepared?.png,
      // Until a new picture is picked, an edited ball shows its current one.
      imageUrl: _prepared == null ? widget.existing?.imageUrl : null,
      imageStyle: _style,
      primaryColor: _lineColor,
      glowColor: Color.lerp(_lineColor, Colors.white, 0.35)!,
    );
    final canSave = !_working && (_prepared != null || _editing) && _name.text.trim().isNotEmpty;

    return AlertDialog(
      title: Text(_editing ? 'Edit ball' : 'Add ball'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(onTap: _working ? null : _pick, child: CircularBallPreview(ball: preview, size: 110)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _working ? null : _pick,
              icon: const Icon(Icons.image),
              label: Text(_picked == null && !_editing ? 'Pick picture' : 'Change picture'),
            ),
            TextField(
              controller: _name,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (_) => setState(() {}),
            ),
            SegmentedButton<BallImageStyle>(
              segments: const [
                ButtonSegment(value: BallImageStyle.logo, label: Text('Logo'), icon: Icon(Icons.circle_outlined)),
                ButtonSegment(value: BallImageStyle.cover, label: Text('Fill'), icon: Icon(Icons.circle)),
              ],
              selected: {_style},
              onSelectionChanged: _working
                  ? null
                  : (s) {
                      setState(() => _style = s.first);
                      _prepare();
                    },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final c in {?_prepared?.suggestedColor, ?widget.existing?.primaryColor, ...kNeonColorPresets})
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.toARGB32() == _lineColor.toARGB32() ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (_working) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _working ? null : () => Navigator.of(context).pop(), child: const Text('CANCEL')),
        FilledButton(onPressed: canSave ? _save : null, child: Text(_editing ? 'SAVE' : 'ADD')),
      ],
    );
  }
}
