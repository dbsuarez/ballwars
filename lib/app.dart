import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';

class BallWarsApp extends StatelessWidget {
  const BallWarsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ball Wars',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const Scaffold(
        body: Center(child: Text('Ball Wars')),
      ),
    );
  }
}
