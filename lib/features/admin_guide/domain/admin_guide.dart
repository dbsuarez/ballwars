import 'dart:convert';
import 'package:flutter/services.dart';

enum GuideTab {
  tutorials('Tutorials'),
  how('How it works'),
  parameters('Parameters');

  const GuideTab(this.label);
  final String label;
}

class GuideSection {
  const GuideSection({
    required this.title,
    required this.body,
    this.example,
    this.where,
    this.check,
  });
  final String title, body;
  final String? example, where, check;
  String get searchText => [
    title,
    body,
    example,
    where,
    check,
  ].whereType<String>().join(' ').toLowerCase();
}

class GuideArticle {
  const GuideArticle({
    required this.id,
    required this.tab,
    required this.title,
    required this.summary,
    required this.sections,
    this.related = const [],
    this.keywords = const [],
    this.diagram = false,
  });
  final String id, title, summary;
  final GuideTab tab;
  final List<GuideSection> sections;
  final List<String> related, keywords;
  final bool diagram;
  String get searchText => [
    title,
    summary,
    ...keywords,
    ...sections.map((s) => s.searchText),
  ].join(' ').toLowerCase();
  bool matches(String query) => query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .every(searchText.contains);
}

class AdminGuide {
  static const asset = 'assets/help/admin_guide.json';
  static Future<List<GuideArticle>> load() async =>
      decode(await rootBundle.loadString(asset, cache: false));

  static List<GuideArticle> decode(String source) {
    final data = jsonDecode(source);
    if (data is! Map || data['version'] != 1 || data['articles'] is! List) {
      throw const FormatException('Unsupported admin guide.');
    }
    String text(Map value, String key) {
      final result = value[key];
      if (result is! String || result.trim().isEmpty) {
        throw FormatException('Missing guide $key.');
      }
      return result;
    }

    final articles = <GuideArticle>[];
    for (final value in data['articles'] as List) {
      if (value is! Map || value['sections'] is! List) {
        throw const FormatException('Invalid guide topic.');
      }
      final tabName = text(value, 'tab');
      final tab = GuideTab.values.where((t) => t.name == tabName).firstOrNull;
      if (tab == null) throw const FormatException('Invalid guide tab.');
      final sections = <GuideSection>[];
      for (final section in value['sections'] as List) {
        if (section is! Map) {
          throw const FormatException('Invalid guide section.');
        }
        sections.add(
          GuideSection(
            title: text(section, 'title'),
            body: text(section, 'body'),
            example: section['example'] as String?,
            where: section['where'] as String?,
            check: section['check'] as String?,
          ),
        );
      }
      if (sections.isEmpty) throw const FormatException('Empty guide topic.');
      articles.add(
        GuideArticle(
          id: text(value, 'id'),
          tab: tab,
          title: text(value, 'title'),
          summary: text(value, 'summary'),
          sections: List.unmodifiable(sections),
          related: List<String>.from(value['related'] as List? ?? const []),
          keywords: List<String>.from(value['keywords'] as List? ?? const []),
          diagram: value['diagram'] == true,
        ),
      );
    }
    final ids = articles.map((a) => a.id).toSet();
    if (ids.length != articles.length ||
        articles.any((a) => a.related.any((id) => !ids.contains(id)))) {
      throw const FormatException('Invalid guide topic links.');
    }
    return List.unmodifiable(articles);
  }
}

/// Mirrors the actual six editor sections and seven appearance subsections.
String guideTopicForEditor(int section, int appearance) => switch (section) {
  0 => 'identity',
  1 => 'mechanics',
  2 => 'timing',
  3 => switch (appearance) {
    0 => 'sprite-reference',
    1 => 'held-artwork',
    2 => 'projectiles',
    3 => 'visual-events',
    4 => 'area',
    5 => 'shells',
    _ => 'legacy',
  },
  4 => 'audio',
  _ => 'testing-saving',
};

String guideTopicForNumber(String key) {
  if ({
    'startDelay',
    'repeatCount',
    'repeatInterval',
    'cooldown',
    'tickInterval',
    'duration',
    'triggerInterval',
    'shadowAppear',
    'shadowStrike',
    'shadowVanish',
    'omegaSlamOffset',
    'omegaSlamVelocity',
  }.contains(key)) {
    return 'timing';
  }
  if ({
    'weaponDisplayScale',
    'weaponGripInset',
    'weaponGripSide',
    'weaponGripRotation',
    'pickupDisplayScale',
    'heldOffsetX',
    'heldOffsetY',
    'effectOffsetX',
    'effectOffsetY',
    'handEffectScale',
    'handEffectDuration',
  }.contains(key)) {
    return 'held-artwork';
  }
  if ({'originForward', 'originSide', 'projectileSize'}.contains(key)) {
    return 'projectiles';
  }
  if (key == 'areaRadius') return 'area';
  if (key == 'shellSize' || key == 'shellCount') return 'shells';
  if (key == 'bubbleDuration') return 'audio';
  if ({
    'screenShake',
    'effectDisplayScale',
    'castingDuration',
    'castingScale',
  }.contains(key)) {
    return 'effect-placement';
  }
  return 'mechanics';
}

String? guideTopicForField(String label) => const {
  'Name': 'identity',
  'Description': 'identity',
  'Category': 'identity',
  'Rarity': 'identity',
  'Trigger': 'identity',
  'Targeting': 'identity',
  'Opponent priority': 'identity',
  'Delivery': 'identity',
  'Weapon class': 'identity',
  'Attack delivery': 'identity',
  'Handedness': 'identity',
  'Primary effect': 'mechanical-steps',
  'Secondary effect': 'mechanical-steps',
  'Artwork tint': 'effect-placement',
  'Icon artwork': 'sprite-reference',
  'Held artwork': 'held-artwork',
  'Artwork Facing': 'held-artwork',
  'Projectile artwork': 'projectiles',
  'Effect artwork': 'visual-events',
  'Effect color': 'effect-placement',
  'Yell': 'audio',
  'Callout style': 'audio',
  'Bubble shape': 'audio',
  'Sound cue': 'audio',
}[label];
