/// Rendering choices only: never change simulation inputs or live preferences.
enum VideoLayer {
  results('Results and finishers'),
  names('Ball names'),
  pictures('Profile pictures'),
  health('Health displays'),
  stats('Scores, timer and standings'),
  equipment('Equipped items'),
  callouts('Callouts'),
  arenaText('Arena text'),
  watermark('Bouncing watermark');

  const VideoLayer(this.label);
  final String label;
}

class VideoVisibility {
  const VideoVisibility({
    this.watchingLayout = false,
    this.layers = const {
      VideoLayer.results,
      VideoLayer.names,
      VideoLayer.pictures,
      VideoLayer.health,
      VideoLayer.callouts,
      VideoLayer.arenaText,
      VideoLayer.watermark,
    },
  });
  final bool watchingLayout;
  final Set<VideoLayer> layers;
  bool shows(VideoLayer layer) => layers.contains(layer);
  Map<String, Object> toJson() => {
    'watching': watchingLayout,
    'layers': layers.map((l) => l.name).toList(),
  };
  factory VideoVisibility.fromJson(Object? value) {
    if (value is! Map || value['layers'] is! List) {
      return const VideoVisibility();
    }
    final names = value['layers'] as List;
    return VideoVisibility(
      watchingLayout: value['watching'] == true,
      layers: Set.unmodifiable(
        VideoLayer.values.where((l) => names.contains(l.name)),
      ),
    );
  }
}
