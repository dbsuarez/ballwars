import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/neon_button.dart';
import '../domain/custom_ball.dart';
import 'widgets/circular_ball_preview.dart';

const List<Color> kNeonColorPresets = [
  Color(0xFF28E21B),
  Color(0xFF00E5FF),
  Color(0xFFFF1744),
  Color(0xFFFFEA00),
  Color(0xFFAA00FF),
  Color(0xFFFF6D00),
];

class BallEditorDialog extends StatefulWidget {
  final CustomBall? existing;
  final void Function(CustomBall) onSave;

  const BallEditorDialog({super.key, this.existing, required this.onSave});

  @override
  State<BallEditorDialog> createState() => _BallEditorDialogState();
}

class _BallEditorDialogState extends State<BallEditorDialog> {
  late final TextEditingController _nameController;
  late Color _primaryColor;
  late Color _glowColor;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _primaryColor = widget.existing?.primaryColor ?? kNeonColorPresets[0];
    _glowColor = widget.existing?.glowColor ?? kNeonColorPresets[1];
    _imageBytes = widget.existing?.imageBytes;
  }

  CustomBall get _previewBall => CustomBall(
        id: widget.existing?.id ?? 'preview',
        name: _nameController.text.isEmpty ? 'New Ball' : _nameController.text,
        imageBytes: _imageBytes,
        primaryColor: _primaryColor,
        glowColor: _glowColor,
      );

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes != null) {
      setState(() => _imageBytes = bytes);
    }
  }

  Widget _colorPresetRow(Color selected, ValueChanged<Color> onSelect) {
    return Wrap(
      spacing: 8,
      children: kNeonColorPresets.map((c) {
        final isSelected = c.value == selected.value;
        return GestureDetector(
          onTap: () => onSelect(c),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0A0E17),
      title: const Text('Create Ball'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularBallPreview(ball: _previewBall, size: 96),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft, child: Text('Primary Color')),
            _colorPresetRow(_primaryColor, (c) => setState(() => _primaryColor = c)),
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft, child: Text('Glow Color')),
            _colorPresetRow(_glowColor, (c) => setState(() => _glowColor = c)),
            const SizedBox(height: 12),
            NeonButton(label: 'UPLOAD IMAGE', onPressed: _pickImage),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        NeonButton(
          label: 'SAVE',
          onPressed: () {
            if (_nameController.text.trim().isEmpty) return;
            widget.onSave(CustomBall(
              id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
              name: _nameController.text.trim(),
              imageBytes: _imageBytes,
              primaryColor: _primaryColor,
              glowColor: _glowColor,
            ));
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
