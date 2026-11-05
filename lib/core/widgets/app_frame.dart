import 'dart:math' as math;
import 'package:flutter/material.dart';

/// One viewport for Home, routes and modal overlays on every platform.
class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child});
  static const double maxWidth = 440;
  static const windowConstraints = BoxConstraints.tightFor(width: maxWidth);
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final width = math.min(maxWidth, bounds.maxWidth);
      final outside = (bounds.maxWidth - width) / 2;
      final media = MediaQuery.of(context);
      EdgeInsets local(EdgeInsets value) => value.copyWith(
        left: math.max(0, value.left - outside),
        right: math.max(0, value.right - outside),
      );
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: SizedBox(
            key: const ValueKey('app-frame'),
            width: width,
            height: bounds.maxHeight,
            child: MediaQuery(
              data: media.copyWith(
                size: Size(width, bounds.maxHeight),
                padding: local(media.padding),
                viewPadding: local(media.viewPadding),
                viewInsets: local(media.viewInsets),
              ),
              child: ClipRect(child: child),
            ),
          ),
        ),
      );
    },
  );
}
