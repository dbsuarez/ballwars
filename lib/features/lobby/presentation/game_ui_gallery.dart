import 'package:flutter/material.dart';
import '../../../core/theme/game_ui.dart';
import '../../arena_simulation/domain/power_up.dart';

/// Standalone visual workbench; never invents player progression or game data.
class GameUiGallery extends StatefulWidget {
  const GameUiGallery({super.key});
  @override
  State<GameUiGallery> createState() => _GameUiGalleryState();
}

class _GameUiGalleryState extends State<GameUiGallery> {
  bool _effects = true;
  int _tab = 0;
  double _volume = .7;
  String _tier = 'Normal';
  @override
  Widget build(BuildContext context) => GameTheme(
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Game UI workbench')),
        body: GameBackdrop(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const GameSectionHeader(
                title: 'Primary actions',
                icon: Icons.touch_app_outlined,
              ),
              GameActionButton(label: 'Play', onPressed: () {}),
              const SizedBox(height: 12),
              const GameActionButton(label: 'Pick your balls', onPressed: null),
              const GameSectionHeader(
                title: 'Modes & selection',
                icon: Icons.sports_esports,
              ),
              SizedBox(
                height: 96,
                child: Row(
                  children: [
                    Expanded(
                      child: GameModeTile(
                        title: 'Arsenal',
                        subtitle: 'Weapon battles',
                        icon: Icons.gps_fixed,
                        accent: GameUi.cyan,
                        selected: _tab == 0,
                        onTap: () => setState(() => _tab = 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GameModeTile(
                        title: 'Mayhem',
                        subtitle: '6-8 ball chaos',
                        icon: Icons.cyclone,
                        accent: GameUi.purple,
                        selected: _tab == 1,
                        onTap: () => setState(() => _tab = 1),
                      ),
                    ),
                  ],
                ),
              ),
              const GameSectionHeader(
                title: 'Rarity tiers',
                icon: Icons.auto_awesome,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final rarity in PowerUpRarity.values)
                    GamePanel(
                      accent: rarity.color,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        rarity.label,
                        style: TextStyle(
                          color: rarity.color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const GameSectionHeader(
                title: 'Accessible controls',
                icon: Icons.tune,
              ),
              GamePanel(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Effects'),
                      value: _effects,
                      onChanged: (v) => setState(() => _effects = v),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Expanded(child: Text('Tier')),
                        SizedBox(
                          width: 150,
                          child: DropdownButtonFormField<String>(
                            initialValue: _tier,
                            isExpanded: true,
                            items: [
                              for (final rarity in PowerUpRarity.values)
                                DropdownMenuItem(
                                  value: rarity.label,
                                  child: Text(rarity.label),
                                ),
                            ],
                            onChanged: (v) => setState(() => _tier = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Preset name',
                        prefixIcon: Icon(Icons.edit_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Slider(
                      semanticFormatterCallback: (v) =>
                          '${(v * 100).round()} percent',
                      value: _volume,
                      onChanged: (v) => setState(() => _volume = v),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GameIconButton(
                          icon: Icons.settings,
                          tooltip: 'Settings',
                          onPressed: () {},
                        ),
                        const GameIconButton(
                          icon: Icons.lock_outline,
                          tooltip: 'Unavailable',
                          onPressed: null,
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const GameSectionHeader(
                title: 'Feedback',
                icon: Icons.info_outline,
              ),
              GamePanel(
                accent: GameUi.orange,
                child: const Text(
                  'Could not save. Your draft is still here. Retry when ready.',
                ),
              ),
              const SizedBox(height: 12),
              GamePanel(
                child: Row(
                  children: [
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        value: .65,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Loading your library...')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const GamePanel(
                child: Text('No saved presets yet. Create one to get started.'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
