import 'package:flutter/material.dart';

class Thread {
  final String ownerBallId;
  Offset startPoint;
  Offset endPoint;
  bool isActive;

  Thread({
    required this.ownerBallId,
    required this.startPoint,
    required this.endPoint,
    this.isActive = true,
  });

  Thread copyWith({
    String? ownerBallId,
    Offset? startPoint,
    Offset? endPoint,
    bool? isActive,
  }) {
    return Thread(
      ownerBallId: ownerBallId ?? this.ownerBallId,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
      isActive: isActive ?? this.isActive,
    );
  }
}