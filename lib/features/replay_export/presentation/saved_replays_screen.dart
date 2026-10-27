import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

import '../data/saved_replay_store.dart';
import '../data/short_link_repository.dart';

class SavedReplaysScreen extends StatefulWidget {
  const SavedReplaysScreen({super.key, required this.onOpen, this.shortLinks});
  final ValueChanged<Uri> onOpen;
  final ShortLinkRepository? shortLinks;

  @override
  State<SavedReplaysScreen> createState() => _SavedReplaysScreenState();
}

class _SavedReplaysScreenState extends State<SavedReplaysScreen> {
  late Future<List<SavedReplay>> _entries = SavedReplayStore.load();
  String? _sharingId;

  Future<void> _share(SavedReplay entry) async {
    if (_sharingId != null) return;
    setState(() => _sharingId = entry.id);
    try {
      var shareUri = entry.shareUri == null ? null : Uri.parse(entry.shareUri!);
      if (shareUri == null) {
        final repository = widget.shortLinks;
        if (repository == null) {
          throw StateError('Server sharing is unavailable.');
        }
        final replay = Uri.parse(entry.uri);
        final code = await repository.create(replay.queryParameters);
        shareUri = replay.replace(queryParameters: {'r': code});
        await SavedReplayStore.attachShareUri(entry.id, shareUri);
      }
      await Clipboard.setData(ClipboardData(text: shareUri.toString()));
      if (mounted) {
        setState(() => _entries = SavedReplayStore.load());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Share link copied. Your replay is also kept on this device.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not create a share link. Your replay is safe on this device. ${_shareFailureReason(error)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharingId = null);
    }
  }

  /// Why sharing failed, in plain words: the server's own reason when it answered, else a connection hint.
  static String _shareFailureReason(Object error) {
    if (error is StateError) return error.message;
    if (error is PostgrestException) return 'The server said: ${error.message}';
    if (error is AuthException) return 'Sign-in failed: ${error.message}';
    return 'Check your connection and try again.';
  }

  Future<void> _rename(SavedReplay entry) async {
    final controller = TextEditingController(text: entry.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename replay'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 240,
          decoration: const InputDecoration(labelText: 'Replay name'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null) return;
    try {
      await SavedReplayStore.rename(entry.id, name);
      if (mounted) setState(() => _entries = SavedReplayStore.load());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Replay rename failed: $error')));
      }
    }
  }

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
                title: Text(entry.displayName),
                subtitle: Text(_stamp(entry.savedAt)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onOpen(Uri.parse(entry.uri));
                },
                trailing: PopupMenuButton<String>(
                  enabled: _sharingId != entry.id,
                  tooltip: 'Replay options',
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(
                      value: 'share',
                      child: Text(
                        entry.shareUri == null
                            ? 'Create share link'
                            : 'Copy share link',
                      ),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  onSelected: (action) async {
                    if (action == 'share') {
                      await _share(entry);
                      return;
                    }
                    if (action == 'rename') {
                      await _rename(entry);
                      return;
                    }
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
