import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../ball_management/presentation/widgets/circular_ball_preview.dart';
import '../../replay_export/domain/replay_link.dart';
import '../data/custom_group_repository.dart';
import '../domain/custom_group.dart';
import 'ball_editor_sheet.dart';

/// The groups made on this device: create, rename and delete groups, and add,
/// edit or remove their balls. They show up as categories in Match Setup,
/// together with the groups added from other players (listed below them).
/// Any group can be shared as a link (`?g=<id>`) that adds it for others.
/// With [allGroups] (admin) it lists every user's groups instead, each with a
/// switch that puts it in the admin's own categories.
class MyGroupsScreen extends StatefulWidget {
  /// This device's own account: its groups and the groups it added.
  final CustomGroupRepository repository;

  /// Where edits go when set: the admin's session in [allGroups] mode, which
  /// may change anyone's groups. The "In my categories" switches still use
  /// [repository], since they belong to this device.
  final CustomGroupRepository? editRepository;
  final bool allGroups;

  const MyGroupsScreen({super.key, required this.repository, this.editRepository, this.allGroups = false});

  @override
  State<MyGroupsScreen> createState() => _MyGroupsScreenState();
}

class _MyGroupsScreenState extends State<MyGroupsScreen> {
  List<CustomGroup>? _groups;

  /// Groups from other players in this user's categories.
  List<CustomGroup> _saved = const [];
  String? _error;
  bool _busy = false;

  CustomGroupRepository get _edits => widget.editRepository ?? widget.repository;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _error = null);
    try {
      final groups = widget.allGroups ? await _edits.allGroups() : await widget.repository.myGroups();
      List<CustomGroup> saved;
      try {
        saved = await widget.repository.savedGroups();
      } catch (_) {
        saved = const []; // Not set up yet (migration 004).
      }
      if (mounted) {
        setState(() {
          _groups = groups;
          _saved = saved;
        });
      }
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
    await _run(() => _edits.renameGroup(group.id, name));
  }

  Future<void> _deleteGroup(CustomGroup group) async {
    if (!await _confirm('Delete "${group.name}" and its ${group.balls.length} balls?')) return;
    await _run(() => _edits.deleteGroup(group));
  }

  Future<void> _addBall(CustomGroup group) async {
    final added = await BallEditorSheet.show(context, groupId: group.id, repository: _edits);
    if (added != null) await _reload();
  }

  Future<void> _editBall(CustomGroup group, CustomBall ball) async {
    final result = await BallEditorSheet.show(context, groupId: group.id, repository: _edits, existing: ball);
    if (result == BallEditorSheet.deleted) {
      await _run(() => _edits.deleteBall(ball));
    } else if (result != null) {
      await _reload();
    }
  }

  void _share(CustomGroup group) {
    Clipboard.setData(ClipboardData(text: ReplayLink.groupUri(group.id).toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Link copied. Anyone who opens it can add "${group.name}" to their categories.')),
    );
  }

  Future<void> _setSaved(CustomGroup group, bool saved) =>
      _run(() => saved ? widget.repository.saveGroup(group.id) : widget.repository.unsaveGroup(group.id));

  Future<void> _deleteBall(CustomBall ball) async {
    if (!await _confirm('Delete "${ball.name}"?')) return;
    await _run(() => _edits.deleteBall(ball));
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
              : groups.isEmpty && _saved.isEmpty
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
                    for (final g in groups)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _groupCard(
                          c,
                          g,
                          // Admin list: a switch for other players' groups.
                          inMyCategories: widget.allGroups && g.ownerId != widget.repository.userId
                              ? _saved.any((s) => s.id == g.id)
                              : null,
                        ),
                      ),
                    if (!widget.allGroups && _saved.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
                        child: Text('ADDED FROM OTHERS', style: AppText.mono(11, color: c.muted, letterSpacing: 1.2)),
                      ),
                      for (final g in _saved)
                        Padding(padding: const EdgeInsets.only(bottom: 12), child: _groupCard(c, g, editable: false)),
                    ],
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

  /// [editable] false: another player's group (no editing, can be removed).
  /// [inMyCategories] non-null shows the admin's "in my categories" switch.
  Widget _groupCard(BallWarsColors c, CustomGroup group, {bool editable = true, bool? inMyCategories}) {
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
                onSelected: (v) => switch (v) {
                  'share' => _share(group),
                  'rename' => _rename(group),
                  'remove' => _setSaved(group, false),
                  _ => _deleteGroup(group),
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'share', child: Text('Copy share link')),
                  if (editable) ...const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Delete group')),
                  ] else
                    const PopupMenuItem(value: 'remove', child: Text('Remove from my categories')),
                ],
              ),
            ],
          ),
          if (inMyCategories != null)
            Row(
              children: [
                Expanded(child: Text('In my categories', style: AppText.ui(13, FontWeight.w600, color: c.muted))),
                Switch(value: inMyCategories, onChanged: _busy ? null : (v) => _setSaved(group, v)),
                const SizedBox(width: 8),
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
                    onTap: _busy || !editable ? null : () => _editBall(group, ball),
                    onLongPress: _busy || !editable ? null : () => _deleteBall(ball),
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
              if (editable)
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
