import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../domain/custom_group.dart';

/// User-made ball groups.
abstract class CustomGroupRepository {
  /// Groups created on this device (its anonymous account), balls included.
  Future<List<CustomGroup>> myGroups();

  Future<CustomGroup> createGroup(String name);

  Future<void> renameGroup(String groupId, String name);

  /// Deletes the group, its balls and their images.
  Future<void> deleteGroup(CustomGroup group);

  /// Uploads [png] (already prepared, see ImagePrep) and adds the ball.
  Future<CustomBall> addBall({
    required String groupId,
    required String name,
    required Uint8List png,
    required BallImageStyle style,
    required Color color,
  });

  /// Changes a ball's name, style and color, and its picture when [png] is
  /// given (the old picture is then deleted).
  Future<CustomBall> updateBall(
    CustomBall ball, {
    required String name,
    required BallImageStyle style,
    required Color color,
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

  static const String _ballColumns = 'id, name, image_path, image_style, color, position';

  StorageFileApi get _images => _client.storage.from(SupabaseConfig.imageBucket);

  /// Every device gets an anonymous account the first time it needs one.
  Future<String> _userId() async {
    final user = _client.auth.currentUser ?? (await _client.auth.signInAnonymously()).user;
    if (user == null) throw StateError('Could not sign in');
    return user.id;
  }

  @override
  Future<List<CustomGroup>> myGroups() async {
    final uid = await _userId();
    final rows = await _client
        .from('ball_groups')
        .select('id, name, is_public, group_balls($_ballColumns)')
        .eq('owner', uid)
        .order('created_at')
        .order('position', referencedTable: 'group_balls');
    return [for (final row in rows) _group(row)];
  }

  @override
  Future<CustomGroup> createGroup(String name) async {
    await _userId();
    final row = await _client.from('ball_groups').insert({'name': name.trim()}).select('id, name, is_public').single();
    return _group({...row, 'group_balls': const []});
  }

  @override
  Future<void> renameGroup(String groupId, String name) async {
    await _client.from('ball_groups').update({'name': name.trim()}).eq('id', groupId);
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
    required Uint8List png,
    required BallImageStyle style,
    required Color color,
  }) async {
    final path = await _upload(png);
    try {
      final row = await _client
          .from('group_balls')
          .insert({
            'group_id': groupId,
            ..._fields(name, style, color),
            'image_path': path,
            'position': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          })
          .select(_ballColumns)
          .single();
      return _ball(row);
    } catch (_) {
      await _images.remove([path]);
      rethrow;
    }
  }

  @override
  Future<CustomBall> updateBall(
    CustomBall ball, {
    required String name,
    required BallImageStyle style,
    required Color color,
    Uint8List? png,
  }) async {
    final oldPath = _pathOf(ball);
    final newPath = png == null ? null : await _upload(png);
    try {
      final row = await _client
          .from('group_balls')
          .update({..._fields(name, style, color), 'image_path': ?newPath})
          .eq('id', CustomGroup.uuidOf(ball))
          .select(_ballColumns)
          .single();
      if (newPath != null && oldPath != null) await _images.remove([oldPath]);
      return _ball(row);
    } catch (_) {
      if (newPath != null) await _images.remove([newPath]);
      rethrow;
    }
  }

  Map<String, Object> _fields(String name, BallImageStyle style, Color color) => {
        'name': name.trim(),
        'image_style': style == BallImageStyle.logo ? 'logo' : 'cover',
        'color': '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
      };

  /// Uploads a prepared PNG into this user's folder and returns its path.
  Future<String> _upload(Uint8List png) async {
    final uid = await _userId();
    // 0x7FFFFFFF, not 1 << 32: on web 1 << 32 is 0 and nextInt(0) throws.
    final path = '$uid/${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(0x7FFFFFFF).toRadixString(16)}.png';
    await _images.uploadBinary(path, png, fileOptions: const FileOptions(contentType: 'image/png'));
    return path;
  }

  @override
  Future<void> deleteBall(CustomBall ball) async {
    await _client.from('group_balls').delete().eq('id', CustomGroup.uuidOf(ball));
    final path = _pathOf(ball);
    if (path != null) await _images.remove([path]);
  }

  @override
  Future<List<CustomBall>> ballsById(List<String> ballIds) async {
    if (ballIds.isEmpty) return const [];
    final rows = await _client
        .from('group_balls')
        .select(_ballColumns)
        .inFilter('id', [for (final id in ballIds) id.replaceFirst(CustomGroup.ballIdPrefix, '')]);
    return [for (final row in rows) _ball(row)];
  }

  CustomGroup _group(Map<String, dynamic> row) => CustomGroup(
        id: row['id'] as String,
        name: row['name'] as String,
        isPublic: row['is_public'] as bool? ?? true,
        balls: [for (final b in (row['group_balls'] as List? ?? const [])) _ball(b as Map<String, dynamic>)],
      );

  CustomBall _ball(Map<String, dynamic> row) {
    final color = Color(0xFF000000 | int.parse((row['color'] as String).substring(1), radix: 16));
    final path = row['image_path'] as String?;
    return CustomBall(
      id: CustomGroup.ballId(row['id'] as String),
      name: row['name'] as String,
      imageUrl: path == null ? null : _images.getPublicUrl(path),
      imageStyle: row['image_style'] == 'cover' ? BallImageStyle.cover : BallImageStyle.logo,
      primaryColor: color,
      glowColor: Color.lerp(color, const Color(0xFFFFFFFF), 0.35)!,
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
