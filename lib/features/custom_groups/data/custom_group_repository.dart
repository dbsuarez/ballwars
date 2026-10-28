import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/offline/offline_store.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../domain/custom_group.dart';

/// User-made ball groups.
abstract class CustomGroupRepository {
  /// Groups owned by the active account, balls included.
  Future<List<CustomGroup>> myGroups();

  /// Every user's groups (admin only; others get just the public ones).
  Future<List<CustomGroup>> allGroups();

  /// Other players' groups this user added to their categories (from a
  /// share link, or the admin's pick in Everyone's groups).
  Future<List<CustomGroup>> savedGroups();

  /// One group by id (for a share link), or null when it doesn't exist.
  Future<CustomGroup?> group(String groupId);

  /// Adds another player's group to this user's categories.
  Future<void> saveGroup(String groupId);

  /// Takes it out again (the group itself stays).
  Future<void> unsaveGroup(String groupId);

  /// The active account's user id, once signed in (null before).
  String? get userId;

  /// Groups the admin added to a built-in category ([CustomGroup.packId]);
  /// their balls show up inside it for everyone.
  Future<List<CustomGroup>> packExtras();

  /// Admin: adds the group's balls to the built-in category [packId], or
  /// takes them out again (null).
  Future<void> linkToPack(String groupId, String? packId);

  /// Ids of groups their makers submitted for the main categories.
  Future<Set<String>> submittedGroupIds();

  /// The owner submits their group for the main categories (or withdraws it).
  Future<void> setSubmitted(String groupId, bool submitted);

  /// Admin: deletes uploaded images no ball uses any more (left behind when
  /// a delete's storage cleanup failed). Returns how many were removed.
  Future<int> cleanUpUnusedImages();

  Future<CustomGroup> createGroup(String name);

  Future<void> renameGroup(String groupId, String name);

  /// Deletes the group, its balls and their images.
  Future<void> deleteGroup(CustomGroup group);

  /// Uploads [png] (already prepared, see ImagePrep) and adds the ball.
  Future<CustomBall> addBall({
    required String groupId,
    required String name,
    required Uint8List? png,
    required BallImageStyle style,
    required Color color,
    BallGender gender = BallGender.none,
  });

  /// Changes a ball's name, style, color and gender, and its picture when
  /// [png] is given (the old picture is then deleted).
  Future<CustomBall> updateBall(
    CustomBall ball, {
    required String name,
    required BallImageStyle style,
    required Color color,
    BallGender gender = BallGender.none,
    Uint8List? png,
  });

  Future<void> deleteBall(CustomBall ball);

  /// Group balls by id, for opening shared replay links. Missing or private
  /// ones are left out.
  Future<List<CustomBall>> ballsById(List<String> ballIds);
}

class SupabaseCustomGroupRepository implements CustomGroupRepository {
  final SupabaseClient _client;

  SupabaseCustomGroupRepository(this._client);

  static const String _baseBallColumns =
      'id, name, image_path, image_style, color, position';

  /// `gender` comes with migration 022. Until it has run, queries and saves
  /// that name it fail once and are retried (and from then on sent) without
  /// it, so the app keeps working; balls then read as [BallGender.none].
  final OptionalColumn _gender = OptionalColumn('gender');

  static String _ballColumns(bool withGender) =>
      withGender ? '$_baseBallColumns, gender' : _baseBallColumns;
  static String _groupColumns(bool withGender) =>
      'id, name, is_public, owner, group_balls(${_ballColumns(withGender)})';

  /// The `gender` column's value for [gender].
  static String genderValue(BallGender gender) => gender.name;

  /// A row's gender; missing (before migration 022) or unknown is none.
  static BallGender genderOf(Map<String, dynamic> row) {
    final value = row['gender'];
    for (final g in BallGender.values) {
      if (g.name == value) return g;
    }
    return BallGender.none;
  }

  StorageFileApi get _images =>
      _client.storage.from(SupabaseConfig.imageBucket);

  /// Every device gets an anonymous account the first time it needs one.
  Future<String> _userId() async {
    final user =
        _client.auth.currentUser ??
        (await _client.auth.signInAnonymously()).user;
    if (user == null) throw StateError('Could not sign in');
    return user.id;
  }

  @override
  Future<List<CustomGroup>> myGroups() async {
    // Cached per account, so another account's groups never show up here.
    final uid = _client.auth.currentUser?.id ?? await _userId();
    final rows = await _offline('groups:mine:$uid', () async {
      return _gender.run(
        (withGender) => _client
            .from('ball_groups')
            .select(_groupColumns(withGender))
            .eq('owner', uid)
            .order('created_at')
            .order('position', referencedTable: 'group_balls')
            .retry(enabled: false),
      );
    });
    return [for (final row in rows) _group(row)];
  }

  @override
  Future<List<CustomGroup>> allGroups() async {
    final rows = await _offline('groups:all', () async {
      await _userId();
      return _gender.run(
        (withGender) => _client
            .from('ball_groups')
            .select(_groupColumns(withGender))
            .order('created_at', ascending: false)
            .order('position', referencedTable: 'group_balls')
            .retry(enabled: false),
      );
    });
    return [for (final row in rows) _group(row)];
  }

  @override
  Future<List<CustomGroup>> savedGroups() async {
    final uid = _client.auth.currentUser?.id ?? await _userId();
    final rows = await _offline('groups:saved:$uid', () async {
      // RLS limits saved_groups to this user's rows; !inner keeps only the
      // groups that have one.
      return _gender.run(
        (withGender) => _client
            .from('ball_groups')
            .select(
              '${_groupColumns(withGender)}, saved_groups!inner(group_id)',
            )
            .order('name')
            .order('position', referencedTable: 'group_balls')
            .retry(enabled: false),
      );
    });
    return [for (final row in rows) _group(row)];
  }

  @override
  Future<CustomGroup?> group(String groupId) async {
    await _userId();
    final row = await _gender.run(
      (withGender) => _client
          .from('ball_groups')
          .select(_groupColumns(withGender))
          .eq('id', groupId)
          .order('position', referencedTable: 'group_balls')
          .maybeSingle(),
    );
    return row == null ? null : _group(row);
  }

  @override
  Future<void> saveGroup(String groupId) async {
    await _userId();
    await _client.from('saved_groups').upsert({
      'group_id': groupId,
    }, ignoreDuplicates: true);
  }

  @override
  Future<void> unsaveGroup(String groupId) async {
    await _userId();
    await _client.from('saved_groups').delete().eq('group_id', groupId);
  }

  @override
  String? get userId => _client.auth.currentUser?.id;

  /// Admin-only: moves groups made by this device's anonymous account to the
  /// signed-in account. Ball rows and image paths deliberately stay where
  /// they are; admin storage access keeps those existing images editable.
  Future<int> adoptGroupsFrom(String sourceOwner) async {
    final targetOwner = await _userId();
    if (sourceOwner == targetOwner) return 0;
    final rows = await _client
        .from('ball_groups')
        .update({'owner': targetOwner})
        .eq('owner', sourceOwner)
        .select('id');
    return rows.length;
  }

  /// Runs [query] (without retries) and keeps its rows in [OfflineStore]
  /// under [key]; offline, the rows from the last successful run are
  /// returned instead.
  static Future<List<Map<String, dynamic>>> _offline(
    String key,
    Future<List<Map<String, dynamic>>> Function() query,
  ) async {
    try {
      final rows = await query().timeout(const Duration(seconds: 10));
      await OfflineStore.instance.write(key, utf8.encode(jsonEncode(rows)));
      return rows;
    } catch (_) {
      final saved = await OfflineStore.instance.read(key);
      if (saved == null) rethrow;
      return (jsonDecode(utf8.decode(saved)) as List)
          .cast<Map<String, dynamic>>();
    }
  }

  @override
  Future<CustomGroup> createGroup(String name) async {
    await _userId();
    final row = await _client
        .from('ball_groups')
        .insert({'name': name.trim()})
        .select('id, name, is_public')
        .single();
    return _group({...row, 'group_balls': const []});
  }

  @override
  Future<void> renameGroup(String groupId, String name) async {
    await _client
        .from('ball_groups')
        .update({'name': name.trim()})
        .eq('id', groupId);
  }

  @override
  Future<void> deleteGroup(CustomGroup group) async {
    final paths = [for (final b in group.balls) ?_pathOf(b)];
    await _client.from('ball_groups').delete().eq('id', group.id);
    if (paths.isNotEmpty) await _images.remove(paths);
  }

  @override
  Future<CustomBall> addBall({
    required String groupId,
    required String name,
    required Uint8List? png,
    required BallImageStyle style,
    required Color color,
    BallGender gender = BallGender.none,
  }) async {
    final path = png == null ? null : await _upload(png);
    try {
      final position = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final row = await _gender.run(
        (withGender) => _client
            .from('group_balls')
            .insert({
              'group_id': groupId,
              ..._fields(name, style, color),
              if (withGender) 'gender': genderValue(gender),
              'image_path': path,
              'position': position,
            })
            .select(_ballColumns(withGender))
            .single(),
      );
      return _ball(row);
    } catch (_) {
      if (path != null) await _images.remove([path]);
      rethrow;
    }
  }

  @override
  Future<CustomBall> updateBall(
    CustomBall ball, {
    required String name,
    required BallImageStyle style,
    required Color color,
    BallGender gender = BallGender.none,
    Uint8List? png,
  }) async {
    final oldPath = _pathOf(ball);
    // The picture goes in the ball owner's folder (the admin may be editing
    // someone else's ball).
    String? newPath;
    if (png != null) {
      final row = await _client
          .from('group_balls')
          .select('owner')
          .eq('id', CustomGroup.uuidOf(ball))
          .single();
      newPath = await _upload(png, folder: row['owner'] as String);
    }
    try {
      final row = await _gender.run(
        (withGender) => _client
            .from('group_balls')
            .update({
              ..._fields(name, style, color),
              if (withGender) 'gender': genderValue(gender),
              'image_path': ?newPath,
            })
            .eq('id', CustomGroup.uuidOf(ball))
            .select(_ballColumns(withGender))
            .single(),
      );
      if (newPath != null && oldPath != null) await _images.remove([oldPath]);
      return _ball(row);
    } catch (_) {
      if (newPath != null) await _images.remove([newPath]);
      rethrow;
    }
  }

  Map<String, Object> _fields(
    String name,
    BallImageStyle style,
    Color color,
  ) => {
    'name': name.trim(),
    'image_style': style == BallImageStyle.logo ? 'logo' : 'cover',
    'color':
        '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
  };

  /// Uploads a prepared PNG into [folder] (default: this user's) and
  /// returns its path.
  Future<String> _upload(Uint8List png, {String? folder}) async {
    final uid = folder ?? await _userId();
    // 0x7FFFFFFF, not 1 << 32: on web 1 << 32 is 0 and nextInt(0) throws.
    final path =
        '$uid/${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(0x7FFFFFFF).toRadixString(16)}.png';
    await _images.uploadBinary(
      path,
      png,
      fileOptions: const FileOptions(contentType: 'image/png'),
    );
    return path;
  }

  @override
  Future<List<CustomGroup>> packExtras() async {
    // pack_id comes with migration 008; until then this fails and callers
    // carry on without extras. It's left out of the other queries for that
    // reason.
    final rows = await _offline('groups:packs', () async {
      return _gender.run(
        (withGender) => _client
            .from('ball_groups')
            .select('${_groupColumns(withGender)}, pack_id')
            .not('pack_id', 'is', null)
            .order('name')
            .order('position', referencedTable: 'group_balls')
            .retry(enabled: false),
      );
    });
    return [for (final row in rows) _group(row)];
  }

  @override
  Future<void> linkToPack(String groupId, String? packId) async {
    await _client
        .from('ball_groups')
        .update({'pack_id': packId})
        .eq('id', groupId);
  }

  @override
  Future<Set<String>> submittedGroupIds() async {
    // submitted_at comes with migration 008 (see [packExtras]).
    final rows = await _client
        .from('ball_groups')
        .select('id')
        .not('submitted_at', 'is', null)
        .retry(enabled: false);
    return {for (final row in rows) row['id'] as String};
  }

  @override
  Future<void> setSubmitted(String groupId, bool submitted) async {
    await _userId();
    await _client
        .from('ball_groups')
        .update({
          'submitted_at': submitted
              ? DateTime.now().toUtc().toIso8601String()
              : null,
        })
        .eq('id', groupId);
  }

  @override
  Future<int> cleanUpUnusedImages() async {
    // Listed by the database (migration 007, admin only), deleted through the
    // Storage API: storage files can't be removed from SQL.
    final names = [
      for (final name in await _client.rpc('orphan_ball_images') as List)
        name as String,
    ];
    for (var i = 0; i < names.length; i += 100) {
      await _images.remove(names.sublist(i, math.min(i + 100, names.length)));
    }
    return names.length;
  }

  @override
  Future<void> deleteBall(CustomBall ball) async {
    await _client
        .from('group_balls')
        .delete()
        .eq('id', CustomGroup.uuidOf(ball));
    final path = _pathOf(ball);
    if (path != null) await _images.remove([path]);
  }

  @override
  Future<List<CustomBall>> ballsById(List<String> ballIds) async {
    if (ballIds.isEmpty) return const [];
    final rows = await _gender.run(
      (withGender) => _client
          .from('group_balls')
          .select(_ballColumns(withGender))
          .inFilter('id', [
            for (final id in ballIds)
              id.replaceFirst(CustomGroup.ballIdPrefix, ''),
          ]),
    );
    return [for (final row in rows) _ball(row)];
  }

  CustomGroup _group(Map<String, dynamic> row) => CustomGroup(
    id: row['id'] as String,
    name: row['name'] as String,
    isPublic: row['is_public'] as bool? ?? true,
    ownerId: row['owner'] as String?,
    packId: row['pack_id'] as String?,
    balls: [
      for (final b in (row['group_balls'] as List? ?? const []))
        _ball(b as Map<String, dynamic>),
    ],
  );

  CustomBall _ball(Map<String, dynamic> row) {
    final color = Color(
      0xFF000000 | int.parse((row['color'] as String).substring(1), radix: 16),
    );
    final path = row['image_path'] as String?;
    return CustomBall(
      id: CustomGroup.ballId(row['id'] as String),
      name: row['name'] as String,
      imageUrl: path == null ? null : _images.getPublicUrl(path),
      imageStyle: row['image_style'] == 'cover'
          ? BallImageStyle.cover
          : BallImageStyle.logo,
      primaryColor: color,
      glowColor: Color.lerp(color, const Color(0xFFFFFFFF), 0.35)!,
      gender: genderOf(row),
    );
  }

  /// Storage path of a ball's image, from its public URL.
  String? _pathOf(CustomBall ball) {
    final url = ball.imageUrl;
    if (url == null) return null;
    final marker = '/${SupabaseConfig.imageBucket}/';
    final i = url.indexOf(marker);
    return i < 0 ? null : Uri.decodeComponent(url.substring(i + marker.length));
  }
}

/// A column that may not exist yet (its migration not run). [run] sends a
/// query with it; if the database says the column is missing, the query is
/// sent again without it, and from then on always without it.
class OptionalColumn {
  final String name;

  /// False once the database said the column is missing.
  bool available = true;

  OptionalColumn(this.name);

  Future<T> run<T>(Future<T> Function(bool withColumn) query) async {
    if (!available) return query(false);
    try {
      return await query(true);
    } on PostgrestException catch (e) {
      // 42703: undefined column (selects); PGRST204: a written column not in
      // PostgREST's schema cache (inserts and updates).
      final missing =
          (e.code == '42703' || e.code == 'PGRST204') &&
          e.message.contains(name);
      if (!missing) rethrow;
      available = false;
      return query(false);
    }
  }
}

/// Uses the signed-in account for groups on every device, while retaining the
/// anonymous repository for players who have not signed in as an admin.
/// Existing groups from the current device are adopted once per session.
class AccountAwareCustomGroupRepository implements CustomGroupRepository {
  final CustomGroupRepository device;
  final CustomGroupRepository account;
  final Future<bool> Function() isAccountActive;
  final Future<int> Function(String sourceOwner) adoptGroupsFrom;
  Future<void>? _adoption;

  AccountAwareCustomGroupRepository({
    required this.device,
    required this.account,
    required this.isAccountActive,
    required this.adoptGroupsFrom,
  });

  Future<CustomGroupRepository> _active() async {
    if (!await isAccountActive()) return device;
    _adoption ??= _adoptDeviceGroups();
    await _adoption;
    return account;
  }

  Future<void> _adoptDeviceGroups() async {
    final sourceOwner = device.userId;
    if (sourceOwner != null) await adoptGroupsFrom(sourceOwner);
  }

  @override
  String? get userId => account.userId ?? device.userId;

  @override
  Future<List<CustomGroup>> myGroups() async => (await _active()).myGroups();
  @override
  Future<List<CustomGroup>> allGroups() async => (await _active()).allGroups();
  @override
  Future<List<CustomGroup>> savedGroups() async =>
      (await _active()).savedGroups();
  @override
  Future<CustomGroup?> group(String groupId) async =>
      (await _active()).group(groupId);
  @override
  Future<void> saveGroup(String groupId) async =>
      (await _active()).saveGroup(groupId);
  @override
  Future<void> unsaveGroup(String groupId) async =>
      (await _active()).unsaveGroup(groupId);
  @override
  Future<List<CustomGroup>> packExtras() async =>
      (await _active()).packExtras();
  @override
  Future<void> linkToPack(String groupId, String? packId) async =>
      (await _active()).linkToPack(groupId, packId);
  @override
  Future<Set<String>> submittedGroupIds() async =>
      (await _active()).submittedGroupIds();
  @override
  Future<void> setSubmitted(String groupId, bool submitted) async =>
      (await _active()).setSubmitted(groupId, submitted);
  @override
  Future<int> cleanUpUnusedImages() async =>
      (await _active()).cleanUpUnusedImages();
  @override
  Future<CustomGroup> createGroup(String name) async =>
      (await _active()).createGroup(name);
  @override
  Future<void> renameGroup(String groupId, String name) async =>
      (await _active()).renameGroup(groupId, name);
  @override
  Future<void> deleteGroup(CustomGroup group) async =>
      (await _active()).deleteGroup(group);
  @override
  Future<CustomBall> addBall({
    required String groupId,
    required String name,
    required Uint8List? png,
    required BallImageStyle style,
    required Color color,
    BallGender gender = BallGender.none,
  }) async => (await _active()).addBall(
    groupId: groupId,
    name: name,
    png: png,
    style: style,
    color: color,
    gender: gender,
  );
  @override
  Future<CustomBall> updateBall(
    CustomBall ball, {
    required String name,
    required BallImageStyle style,
    required Color color,
    BallGender gender = BallGender.none,
    Uint8List? png,
  }) async => (await _active()).updateBall(
    ball,
    name: name,
    style: style,
    color: color,
    gender: gender,
    png: png,
  );
  @override
  Future<void> deleteBall(CustomBall ball) async =>
      (await _active()).deleteBall(ball);
  @override
  Future<List<CustomBall>> ballsById(List<String> ballIds) async =>
      (await _active()).ballsById(ballIds);
}
