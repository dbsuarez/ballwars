import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../ball_management/presentation/widgets/circular_ball_preview.dart';
import '../data/custom_group_repository.dart';
import '../data/image_prep.dart';
import 'widgets/circle_cropper.dart';

/// Line colors offered next to the one suggested from the picture.
const List<Color> kBallColorPresets = [
  Color(0xFF4FD1C5),
  Color(0xFFFF7A59),
  Color(0xFFFFD60A),
  Color(0xFF0A84FF),
  Color(0xFF34C759),
  Color(0xFFBF5AF2),
  Color(0xFFFF3B6B),
];

/// Adds a ball to a user group, or edits one ([existing]), in a bottom
/// sheet: name, picture (framed with [CircleCropper], then shrunk to a
/// 256 px PNG before upload), logo-on-white or fill, and line color.
class BallEditorSheet extends StatefulWidget {
  final String groupId;
  final CustomGroupRepository repository;
  final CustomBall? existing;

  const BallEditorSheet({super.key, required this.groupId, required this.repository, this.existing});

  /// Returned by [show] when the user deleted the ball.
  static const CustomBall deleted = CustomBall(
    id: 'deleted',
    name: '',
    primaryColor: Color(0x00000000),
    glowColor: Color(0x00000000),
  );

  /// The added or updated ball, [deleted], or null if cancelled.
  static Future<CustomBall?> show(
    BuildContext context, {
    required String groupId,
    required CustomGroupRepository repository,
    CustomBall? existing,
  }) =>
      showModalBottomSheet<CustomBall>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => BallEditorSheet(groupId: groupId, repository: repository, existing: existing),
      );

  @override
  State<BallEditorSheet> createState() => _BallEditorSheetState();
}

class _BallEditorSheetState extends State<BallEditorSheet> {
  final TextEditingController _name = TextEditingController();
  ui.Image? _picture;
  Rect? _crop;
  Color? _suggested;
  BallImageStyle _style = BallImageStyle.cover; // New balls: picture fills the ball.
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
    _picture?.dispose();
    super.dispose();
  }

  Color get _lineColor => _color ?? _suggested ?? kBallColorPresets.first;

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final picture = await ImagePrep.decodeForCropping(bytes);
      final suggestion = await ImagePrep.fromImage(picture, BallImageStyle.cover);
      if (!mounted) return;
      setState(() {
        _picture?.dispose();
        _picture = picture;
        _crop = null;
        _suggested = suggestion.suggestedColor;
        if (!_editing) _color = null;
        if (_name.text.trim().isEmpty) {
          final n = file!.name;
          _name.text = n.contains('.') ? n.substring(0, n.lastIndexOf('.')) : n;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = "That picture couldn't be read. Try a PNG or JPEG.");
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final picture = _picture;
    if (name.isEmpty || (picture == null && !_editing)) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final png = picture == null ? null : (await ImagePrep.fromImage(picture, _style, crop: _crop)).png;
      final existing = widget.existing;
      final ball = existing == null
          ? await widget.repository.addBall(groupId: widget.groupId, name: name, png: png!, style: _style, color: _lineColor)
          : await widget.repository.updateBall(existing, name: name, style: _style, color: _lineColor, png: png);
      if (mounted) Navigator.of(context).pop(ball);
    } catch (e) {
      if (mounted) {
        setState(() {
          _working = false;
          _error = "Couldn't save: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    final picture = _picture;
    final canSave = !_working && (picture != null || _editing) && _name.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_editing ? 'Edit ball' : 'Add ball', style: AppText.ui(18, FontWeight.w700, color: c.text)),
                ),
                if (_editing)
                  TextButton(
                    onPressed: _working ? null : () => Navigator.of(context).pop(BallEditorSheet.deleted),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF7A59)),
                    child: const Text('Delete'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: picture != null
                  ? CircleCropper(image: picture, ringColor: _lineColor, onChanged: (r) => _crop = r)
                  : InkWell(
                      onTap: _working ? null : _pick,
                      customBorder: const CircleBorder(),
                      child: _editing
                          ? CircularBallPreview(ball: widget.existing!.copyWith(imageStyle: _style, primaryColor: _lineColor), size: 140)
                          : Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.border, width: 1.5)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined, color: c.muted, size: 32),
                                  const SizedBox(height: 6),
                                  Text('Pick picture', style: AppText.ui(13, FontWeight.w600, color: c.muted)),
                                ],
                              ),
                            ),
                    ),
            ),
            const SizedBox(height: 8),
            Center(
              child: picture != null
                  ? Text('Drag to move · pinch or scroll to zoom', style: AppText.ui(12, FontWeight.w500, color: c.muted))
                  : _editing
                  ? TextButton(onPressed: _working ? null : _pick, child: const Text('Change picture'))
                  : const SizedBox.shrink(),
            ),
            if (picture != null)
              Center(child: TextButton(onPressed: _working ? null : _pick, child: const Text('Choose another'))),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            Text('PICTURE', style: AppText.ui(11, FontWeight.w700, color: c.muted, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            SegmentedButton<BallImageStyle>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: BallImageStyle.logo, label: Text('Logo on white')),
                ButtonSegment(value: BallImageStyle.cover, label: Text('Fill the ball')),
              ],
              selected: {_style},
              onSelectionChanged: _working ? null : (s) => setState(() => _style = s.first),
            ),
            const SizedBox(height: 20),
            Text('LINE COLOR', style: AppText.ui(11, FontWeight.w700, color: c.muted, letterSpacing: 0.8)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final color in {?_suggested, ?widget.existing?.primaryColor, ...kBallColorPresets})
                  Semantics(
                    button: true,
                    selected: color.toARGB32() == _lineColor.toARGB32(),
                    label: color == _suggested ? 'Color from the picture' : 'Line color',
                    child: InkWell(
                      onTap: () => setState(() => _color = color),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 40,
                        height: 40,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.toARGB32() == _lineColor.toARGB32() ? c.text : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: DecoratedBox(decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      ),
                    ),
                  ),
              ],
            ),
            if (_suggested != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('The first color comes from your picture.', style: AppText.ui(12, FontWeight.w500, color: c.muted)),
              ),
            if (_working) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!, style: AppText.ui(13, FontWeight.w600, color: const Color(0xFFFF7A59))),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _working ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(onPressed: canSave ? _save : null, child: Text(_editing ? 'Save' : 'Add')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
