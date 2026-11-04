import 'package:flutter/material.dart';
import '../../../core/offline/device_prefs.dart';
import '../domain/admin_guide.dart';

Future<void> openAdminGuide(
  BuildContext context, {
  String? topic,
  String? highlight,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => AdminGuideScreen(initialTopic: topic, highlight: highlight),
  ),
);

/// Read-only help. Never reads or writes the skill/settings draft beneath it.
class AdminGuideScreen extends StatefulWidget {
  const AdminGuideScreen({super.key, this.initialTopic, this.highlight});
  final String? initialTopic, highlight;
  @override
  State<AdminGuideScreen> createState() => _AdminGuideScreenState();
}

class _AdminGuideScreenState extends State<AdminGuideScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: GuideTab.values.length,
    vsync: this,
  );
  late Future<List<GuideArticle>> _catalog = AdminGuide.load();
  late String? _topic = widget.initialTopic;
  final _search = TextEditingController();
  final _scroll = ScrollController(keepScrollOffset: false);
  bool _fromList = false, _tabTouched = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialTopic == null && widget.highlight != null) {
      _search.text = widget.highlight!;
    }
    _tabs.addListener(_tabChanged);
    _restoreTab();
  }

  Future<void> _restoreTab() async {
    final index = int.tryParse(await DevicePrefs.read('admin-guide-tab') ?? '');
    if (mounted &&
        !_tabTouched &&
        index != null &&
        index >= 0 &&
        index < GuideTab.values.length) {
      _tabs.index = index;
    }
  }

  void _tabChanged() {
    if (_tab == _tabs.index) return;
    setState(() {
      _tab = _tabs.index;
    });
    DevicePrefs.write('admin-guide-tab', _tab);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _canPop =>
      _topic == null || (widget.initialTopic != null && !_fromList);
  void _back() {
    if (_canPop) {
      Navigator.maybePop(context);
    } else {
      setState(() {
        _topic = null;
      });
    }
  }

  void _open(String id) {
    setState(() {
      _topic = id;
      _fromList = true;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _allTopics() => setState(() {
    _topic = null;
    _fromList = true;
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<List<GuideArticle>>(
    future: _catalog,
    builder: (context, snapshot) {
      final articles = snapshot.data;
      final article = articles?.where((a) => a.id == _topic).firstOrNull;
      return PopScope<Object?>(
        canPop: _canPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: _back),
            title: Text(
              article?.title ?? 'Admin Guide',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18),
            ),
            actions: [
              if (_topic != null)
                IconButton(
                  tooltip: 'All guide topics',
                  onPressed: _allTopics,
                  icon: const Icon(Icons.list_alt_outlined),
                ),
            ],
          ),
          body: snapshot.hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'The guide could not be loaded. Your edits are unchanged.',
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _catalog = AdminGuide.load();
                        }),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : articles == null
              ? const Center(child: CircularProgressIndicator())
              : _topic != null && article == null
              ? Center(
                  child: TextButton(
                    onPressed: _allTopics,
                    child: const Text('Topic unavailable. Browse all topics.'),
                  ),
                )
              : article != null
              ? _article(article, articles)
              : _index(articles),
        ),
      );
    },
  );

  Widget _index(List<GuideArticle> articles) {
    final searching = _search.text.trim().isNotEmpty;
    final visible = articles
        .where((a) => searching ? a.matches(_search.text) : a.tab.index == _tab)
        .toList();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                key: const ValueKey('admin-guide-search'),
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search skills, effects, parameters...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searching
                      ? IconButton(
                          tooltip: 'Clear guide search',
                          onPressed: () => setState(_search.clear),
                          icon: const Icon(Icons.close),
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            TabBar(
              controller: _tabs,
              isScrollable: false,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              onTap: (_) {
                _tabTouched = true;
              },
              tabs: [for (final tab in GuideTab.values) Tab(text: tab.label)],
            ),
            if (searching)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('${visible.length} results across all tabs'),
              ),
            Expanded(
              child: visible.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No matching topics. Try a setting name such as grip, DoT or opacity.',
                        ),
                      ),
                    )
                  : ListView.separated(
                      key: ValueKey('guide-list-$_tab-$searching'),
                      padding: const EdgeInsets.all(16),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final article = visible[index];
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Icon(switch (article.tab) {
                              GuideTab.tutorials => Icons.school_outlined,
                              GuideTab.how => Icons.account_tree_outlined,
                              GuideTab.parameters => Icons.tune,
                            }),
                            title: Text(
                              article.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                searching
                                    ? '${article.tab.label} / ${_snippet(article)}'
                                    : article.summary,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _open(article.id),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _snippet(GuideArticle article) {
    final query = _search.text.trim().toLowerCase();
    return article.sections
            .where((s) => s.searchText.contains(query))
            .firstOrNull
            ?.title ??
        article.summary;
  }

  Widget _article(GuideArticle article, List<GuideArticle> all) {
    final term =
        (_search.text.trim().isNotEmpty ? _search.text : widget.highlight ?? '')
            .toLowerCase();
    final matched = term.isEmpty
        ? null
        : article.sections
                  .where((s) => s.title.toLowerCase().contains(term))
                  .firstOrNull ??
              article.sections
                  .where((s) => s.searchText.contains(term))
                  .firstOrNull;
    final sections = matched != null && article.tab != GuideTab.tutorials
        ? [matched, ...article.sections.where((s) => !identical(s, matched))]
        : article.sections;
    return SelectionArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            key: ValueKey('guide-article-${article.id}'),
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text(
                article.tab.label,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Text(
                article.summary,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              if (article.diagram) const _SkillFlow(),
              if (matched != null && article.tab != GuideTab.tutorials)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Matching explanation first',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              for (var index = 0; index < sections.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _section(
                    sections[index],
                    article.tab == GuideTab.tutorials ? index + 1 : null,
                  ),
                ),
              if (article.related.isNotEmpty) ...[
                Text(
                  'Related topics',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final id in article.related)
                      ActionChip(
                        label: Text(all.firstWhere((a) => a.id == id).title),
                        onPressed: () => _open(id),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(GuideSection section, int? step) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (step != null) ...[
                CircleAvatar(radius: 17, child: Text('$step')),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  step == null
                      ? section.title
                      : section.title.replaceFirst(RegExp(r'^\d+\.\s*'), ''),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (section.where != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Where: ${section.where}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          const SizedBox(height: 10),
          Text(section.body, style: const TextStyle(height: 1.5)),
          if (section.example != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Example: ${section.example}',
                style: const TextStyle(height: 1.5),
              ),
            ),
          if (section.check != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'What to check: ${section.check}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Native Flutter diagram: no generated raster artwork or downloaded assets.
class _SkillFlow extends StatelessWidget {
  const _SkillFlow();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'One action, several stages',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final stage in const [
                ('Held item', Icons.front_hand_outlined),
                ('Casting', Icons.auto_awesome_outlined),
                ('Projectile', Icons.north_east),
                ('Impact / zone', Icons.flare_outlined),
              ])
                Chip(avatar: Icon(stage.$2, size: 18), label: Text(stage.$1)),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Example: a projectile attack. Other deliveries may skip stages. Mechanics decide what happens; artwork makes it visible.',
            style: TextStyle(height: 1.4),
          ),
        ],
      ),
    ),
  );
}
