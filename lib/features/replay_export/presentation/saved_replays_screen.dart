import 'package:flutter/material.dart';

import '../data/saved_replay_store.dart';

class SavedReplaysScreen extends StatefulWidget {
  const SavedReplaysScreen({super.key, required this.onOpen});
  final ValueChanged<Uri> onOpen;

  @override
  State<SavedReplaysScreen> createState() => _SavedReplaysScreenState();
}

class _SavedReplaysScreenState extends State<SavedReplaysScreen> {
  late Future<List<SavedReplay>> _entries = SavedReplayStore.load();

  String _stamp(DateTime value) {
    if (value.millisecondsSinceEpoch == 0) {
      return 'Legacy saved replay';
    }
    final local = value.toLocal();
    String two(int n) => '$n'.padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Saved replays')),
    body: FutureBuilder<List<SavedReplay>>(
      future: _entries,
      builder: (context, snapshot) {
        final entries = snapshot.data;
        if (entries == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (entries.isEmpty) {
          return const Center(child: Text('No saved replays yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: Text('Replay ${entries.length - index}'),
                subtitle: Text(_stamp(entry.savedAt)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onOpen(Uri.parse(entry.uri));
                },
                trailing: IconButton(
                  tooltip: 'Delete replay',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await SavedReplayStore.remove(entry.id);
                    if (mounted) {
                      setState(() => _entries = SavedReplayStore.load());
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
