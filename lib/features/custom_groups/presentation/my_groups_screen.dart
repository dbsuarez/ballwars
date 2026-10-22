import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../ball_management/presentation/widgets/circular_ball_preview.dart';
import '../data/custom_group_repository.dart';
import '../domain/custom_group.dart';
import 'ball_editor_sheet.dart';

/// The groups made on this device: create, rename and delete groups, and add,
/// edit or remove their balls. They show up as categories in Match Setup.
/// With [allGroups] (admin) it lists every user's groups instead.
class MyGroupsScreen extends StatefulWidget {
  final CustomGroupRepository repository;
  final bool allGroups;

  const MyGroupsScreen({super.key, required this.repository, this.allGroups = false});

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
      final groups = widget.allGroups ? await widget.repository.allGroups() : await widget.repository.myGroups();
      if (mounted) setState(() => _groups = groups);
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't load the groups. Check your connection.\n$e");
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
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Save')),
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
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
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
    final added = await BallEditorSheet.show(context, groupId: group.id, repository: widget.repository);
    if (added != null) await _reload();
  }

  Future<void> _editBall(CustomGroup group, CustomBall ball) async {
    final result = await BallEditorSheet.show(context, groupId: group.id, repository: widget.repository, existing: ball);
    if (result == BallEditorSheet.deleted) {
      await _run(() => widget.repository.deleteBall(ball));
    } else if (result != null) {
      await _reload();
    }
  }

  Future<void> _deleteBall(CustomBall ball) async {
    if (!await _confirm('Delete "${ball.name}"?')) return;
    await _run(() => widget.repository.deleteBall(ball));
  }

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    final groups = _groups;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.allGroups ? "Everyone's groups" : 'My groups'),
        actions: [
          if (!widget.allGroups && groups != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: _busy ? null : _newGroup,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 14)),
                child: const Text('New group'),
              ),
            ),
        ],
        bottom: _busy ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator()) : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center, style: AppText.ui(14, FontWeight.w500, color: c.muted)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _reload, child: const Text('Try again')),
                    ],
                  ),
                )
              : groups == null
              ? const CircularProgressIndicator()
              : groups.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    widget.allGroups
                        ? 'Nobody has made a group yet.'
                        : 'Make your own group of balls: anime characters, your friends, local brands…\n'
                              'They appear as categories when you start a match.',
                    textAlign: TextAlign.center,
                    style: AppText.ui(14, FontWeight.w500, color: c.muted, height: 1.5),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    for (final g in groups) Padding(padding: const EdgeInsets.only(bottom: 12), child: _groupCard(c, g)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      child: Text(
                        'Tap a ball to edit it; long-press to delete it.',
                        style: AppText.ui(12, FontWeight.w500, color: c.muted),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _groupCard(BallWarsColors c, CustomGroup group) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 4, 18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: group.name, style: AppText.ui(16, FontWeight.w700, color: c.text)),
                      TextSpan(text: '   ${group.balls.length} balls', style: AppText.mono(12, color: c.muted)),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Group options',
                enabled: !_busy,
                icon: Icon(Icons.more_horiz, color: c.muted),
                onSelected: (v) => v == 'rename' ? _rename(group) : _deleteGroup(group),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete group')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final ball in group.balls)
                SizedBox(
                  width: 60,
                  child: InkWell(
                    onTap: _busy ? null : () => _editBall(group, ball),
                    onLongPress: _busy ? null : () => _deleteBall(ball),
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        CircularBallPreview(ball: ball, size: 50),
                        const SizedBox(height: 6),
                        Text(
                          ball.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.ui(11, FontWeight.w600, color: c.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(
                width: 60,
                child: InkWell(
                  onTap: _busy ? null : () => _addBall(group),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.border, width: 1.5)),
                        child: Icon(Icons.add, color: c.muted),
                      ),
                      const SizedBox(height: 6),
                      Text('Add', style: AppText.ui(11, FontWeight.w600, color: c.muted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
