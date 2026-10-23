import '../../ball_management/domain/custom_ball.dart';

/// A ball group made by a user (stored in Supabase). Its balls have ids
/// `group:<uuid>` and online images, so they work in links on any device.
class CustomGroup {
  final String id;
  final String name;
  final bool isPublic;
  final List<CustomBall> balls;

  /// The user who made it (null where unknown, e.g. in tests).
  final String? ownerId;

  /// The built-in category (pack id) the admin added this group's balls to,
  /// if any; its balls also show up inside that category for everyone.
  final String? packId;

  const CustomGroup({
    required this.id,
    required this.name,
    required this.isPublic,
    required this.balls,
    this.ownerId,
    this.packId,
  });

  static const String ballIdPrefix = 'group:';

  static String ballId(String uuid) => '$ballIdPrefix$uuid';

  static bool isGroupBall(String id) => id.startsWith(ballIdPrefix);

  /// The database id of a group ball.
  static String uuidOf(CustomBall ball) => ball.id.substring(ballIdPrefix.length);
}
