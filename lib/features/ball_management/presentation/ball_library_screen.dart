import 'package:flutter/material.dart';
import '../../../core/widgets/neon_button.dart';
import '../domain/ball_repository.dart';
import '../domain/custom_ball.dart';
import 'ball_editor_dialog.dart';
import 'widgets/circular_ball_preview.dart';

class BallLibraryScreen extends StatefulWidget {
  final BallRepository repository;
  final bool selectable;
  final void Function(List<String>)? onSelectionChanged;

  const BallLibraryScreen({
    super.key,
    required this.repository,
    this.selectable = false,
    this.onSelectionChanged,
  });

  @override
  State<BallLibraryScreen> createState() => _BallLibraryScreenState();
}

class _BallLibraryScreenState extends State<BallLibraryScreen> {
  final Set<String> _selectedIds = {};

  void _toggleSelection(CustomBall ball) {
    if (!widget.selectable) return;
    setState(() {
      if (_selectedIds.contains(ball.id)) {
        _selectedIds.remove(ball.id);
      } else {
        _selectedIds.add(ball.id);
      }
    });
    widget.onSelectionChanged?.call(_selectedIds.toList());
  }

  void _openEditor() {
    showDialog(
      context: context,
      builder: (_) => BallEditorDialog(
        onSave: (ball) => setState(() => widget.repository.add(ball)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balls = widget.repository.getAll();

    return Scaffold(
      appBar: AppBar(title: const Text('Ball Library')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            NeonButton(label: 'CREATE NEW BALL', onPressed: _openEditor),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: balls.length,
                itemBuilder: (context, index) {
                  final ball = balls[index];
                  final isSelected = _selectedIds.contains(ball.id);
                  return GestureDetector(
                    onTap: () => _toggleSelection(ball),
                    child: Column(
                      children: [
                        Opacity(
                          opacity: !widget.selectable || isSelected ? 1.0 : 0.5,
                          child: CircularBallPreview(ball: ball, size: 72),
                        ),
                        const SizedBox(height: 8),
                        Text(ball.name, textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
