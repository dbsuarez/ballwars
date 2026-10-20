import 'custom_ball.dart';

abstract class BallRepository {
  List<CustomBall> getAll();
  void add(CustomBall ball);
  void remove(String id);
}
