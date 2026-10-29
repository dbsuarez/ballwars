import 'dart:convert';
import 'package:flutter/material.dart';
import 'profile_support.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: _Profile()));
}

class _Profile extends StatefulWidget {
  const _Profile();
  @override
  State<_Profile> createState() => _ProfileState();
}

class _ProfileState extends State<_Profile> {
  late final Future<Map<String, Object>> report = Future.delayed(
    const Duration(milliseconds: 300),
    runSixBallProfile,
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    body: FutureBuilder<Map<String, Object>>(
      future: report,
      builder: (_, s) {
        if (s.hasError) return SelectableText('PROFILE_ERROR ${s.error}');
        if (!s.hasData) {
          return const Center(child: Text('Running six-ball profile'));
        }
        final text = jsonEncode(s.data);
        debugPrint('BALLWARS_PROFILE $text');
        return SingleChildScrollView(
          child: SelectableText('BALLWARS_PROFILE $text'),
        );
      },
    ),
  );
}
