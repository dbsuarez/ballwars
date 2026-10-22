import 'package:flutter/material.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../ball_management/presentation/widgets/circular_ball_preview.dart';
import '../data/custom_group_repository.dart';
import '../domain/custom_group.dart';
import 'add_ball_dialog.dart';

/// The groups made on this device: create, rename and delete groups, and add
/// or remove their balls. They show up as categories in Match Setup.
class MyGroupsScreen extends StatefulWidget {
  final CustomGroupRepository repository;

  const MyGroupsScreen({super.key, required this.repository});

  @override
  State<MyGroupsScreen> createState() => _MyGroupsScreenState();
}

class _MyGroupsScreenState extends State<MyGroupsScreen> {
  List<CustomGroup>? _groups;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _error = null);
    try {
      final groups = await widget.repository.myGroups();
      if (mounted) setState(() => _groups = groups);
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't load your groups. Check your connection.\n$e");
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askName({required String title, String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(hintText: 'e.g. Anime, Pokémon, My barkada'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('SAVE')),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<bool> _confirm(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('CANCEL')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('DELETE')),
          ],
        ),
      ) ??
      false;

  Future<void> _newGroup() async {
    final name = (await _askName(title: 'New group'))?.trim();
    if (name == null || name.isEmpty) return;
    await _run(() => widget.repository.createGroup(name));
  }

  Future<void> _rename(CustomGroup group) async {
    final name = (await _askName(title: 'Rename group', initial: group.name))?.trim();
    if (name == null || name.isEmpty || name == group.name) return;
    await _run(() => widget.repository.renameGroup(group.id, name));
  }

  Future<void> _deleteGroup(CustomGroup group) async {
    if (!await _confirm('Delete "${group.name}" and its ${group.balls.length} balls?')) return;
    await _run(() => widget.repository.deleteGroup(group));
  }

  Future<void> _addBall(CustomGroup group) async {
    final added = await AddBallDialog.show(context, groupId: group.id, repository: widget.repository);
    if (added != null) await _reload();
  }

  Future<void> _editBall(CustomGroup group, CustomBall ball) async {
    final updated = await AddBallDialog.show(context, groupId: group.id, repository: widget.repository, existing: ball);
    if (updated != null) await _reload();
  }

  Future<void> _deleteBall(CustomBall ball) async {
    if (!await _confirm('Delete "${ball.name}"?')) return;
    await _run(() => widget.repository.deleteBall(ball));
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Groups'),
        bottom: _busy ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator()) : null,
      ),
      floatingActionButton: groups == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : _newGroup,
              icon: const Icon(Icons.add),
              label: const Text('NEW GROUP'),
            ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('TRY AGAIN')),
                ]),
              ),
            )
          : groups == null
              ? const Center(child: CircularProgressIndicator())
              : groups.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Make your own group of balls: anime characters, your friends, local brands...\n'
                          'They appear as categories in Match Setup.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                      children: [for (final g in groups) _groupCard(g)],
                    ),
    );
  }

  Widget _groupCard(CustomGroup group) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${group.name}  (${group.balls.length})', style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(tooltip: 'Rename', onPressed: _busy ? null : () => _rename(group), icon: const Icon(Icons.edit)),
                IconButton(
                  tooltip: 'Delete group',
                  onPressed: _busy ? null : () => _deleteGroup(group),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final ball in group.balls)
                  SizedBox(
                    width: 72,
                    child: GestureDetector(
                      onTap: _busy ? null : () => _editBall(group, ball),
                      onLongPress: _busy ? null : () => _deleteBall(ball),
                      child: Column(children: [
                        CircularBallPreview(ball: ball, size: 56),
                        const SizedBox(height: 4),
                        Text(ball.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      ]),
                    ),
                  ),
                SizedBox(
                  width: 72,
                  child: Column(children: [
                    IconButton.outlined(
                      iconSize: 32,
                      onPressed: _busy ? null : () => _addBall(group),
                      icon: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 4),
                    const Text('Add', style: TextStyle(fontSize: 12)),
                  ]),
                ),
              ],
            ),
            if (group.balls.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Tap a ball to edit it, long-press to delete it.', style: TextStyle(fontSize: 11, color: Colors.white54)),
              ),
          ],
        ),
      ),
    );
  }
}
