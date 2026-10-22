import 'package:flutter/material.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../application/replay_video_exporter.dart';
import '../data/video_encoder.dart';

/// Exports a finished match as a video, saves it to the gallery and offers
/// to share it. Shows progress and can be cancelled.
class ExportVideoDialog extends StatefulWidget {
  final List<CustomBall> contestants;
  final int seed;
  final double arenaRadius;
  final double speedMultiplier;
  final VideoEncoder encoder;
  final VideoSaver saver;

  const ExportVideoDialog({
    super.key,
    required this.contestants,
    required this.seed,
    required this.arenaRadius,
    required this.speedMultiplier,
    required this.encoder,
    required this.saver,
  });

  static Future<void> show(
    BuildContext context, {
    required List<CustomBall> contestants,
    required int seed,
    required double arenaRadius,
    required double speedMultiplier,
    required VideoExportBackend backend,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExportVideoDialog(
        contestants: contestants,
        seed: seed,
        arenaRadius: arenaRadius,
        speedMultiplier: speedMultiplier,
        encoder: backend,
        saver: backend,
      ),
    );
  }

  @override
  State<ExportVideoDialog> createState() => _ExportVideoDialogState();
}

enum _Phase { exporting, saved, failed }

class _ExportVideoDialogState extends State<ExportVideoDialog> {
  _Phase _phase = _Phase.exporting;
  double _progress = 0;
  bool _cancelled = false;
  String? _savedVideo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final path = await ReplayVideoExporter(encoder: widget.encoder).export(
        contestants: widget.contestants,
        seed: widget.seed,
        arenaRadius: widget.arenaRadius,
        speedMultiplier: widget.speedMultiplier,
        isCancelled: () => _cancelled,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      final saved = await widget.saver.save(path);
      if (mounted) {
        setState(() {
          _savedVideo = saved;
          _phase = _Phase.saved;
        });
      }
    } on ExportCancelled {
      // Dialog is already closing.
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _phase = _Phase.failed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.exporting:
        return AlertDialog(
          title: const Text('SAVING VIDEO'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 12),
              Text('${(_progress * 100).round()}%', textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _cancelled = true;
                Navigator.of(context).pop();
              },
              child: const Text('CANCEL'),
            ),
          ],
        );
      case _Phase.saved:
        return AlertDialog(
          title: const Text('VIDEO SAVED'),
          content: Text(widget.saver.savedMessage),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CLOSE')),
            FilledButton.icon(
              onPressed: () => widget.saver.share(_savedVideo!),
              icon: const Icon(Icons.share),
              label: const Text('SHARE'),
            ),
          ],
        );
      case _Phase.failed:
        return AlertDialog(
          title: const Text('COULD NOT SAVE VIDEO'),
          content: Text(_error ?? 'Unknown error'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CLOSE')),
          ],
        );
    }
  }
}
