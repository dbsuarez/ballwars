import 'package:flutter/material.dart';

import 'game_audio.dart';

enum AudioChannel { bgm, sfx, ux }

/// Compact, font-independent audio control used over the live arena.
/// Tap toggles the channel; long-press opens its volume slider.
class AudioChannelButton extends StatefulWidget {
  const AudioChannelButton({super.key, required this.channel});

  final AudioChannel channel;

  @override
  State<AudioChannelButton> createState() => _AudioChannelButtonState();
}

class _AudioChannelButtonState extends State<AudioChannelButton> {
  GameAudio get _audio => GameAudio.instance;

  String get _label => switch (widget.channel) {
    AudioChannel.bgm => 'BGM',
    AudioChannel.sfx => 'SFX',
    AudioChannel.ux => 'UX',
  };

  bool get _on => switch (widget.channel) {
    AudioChannel.bgm => _audio.musicOn,
    AudioChannel.sfx => _audio.effectsOn,
    AudioChannel.ux => _audio.uxOn,
  };

  Future<void> _toggle() async {
    final next = !_on;
    switch (widget.channel) {
      case AudioChannel.bgm:
        await _audio.setMusicOn(next);
        if (next) _audio.startMusic();
        break;
      case AudioChannel.sfx:
        await _audio.setEffectsOn(next);
        break;
      case AudioChannel.ux:
        await _audio.setUxOn(next);
        break;
    }
    if (next) _audio.click();
    if (mounted) setState(() {});
  }

  Future<void> _volume() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close audio settings',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (dialogContext, animation, secondaryAnimation) => Center(
        child: Material(
          key: const ValueKey('audio-popup'),
          color: Theme.of(dialogContext).colorScheme.surface,
          elevation: 12,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Audio',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close audio settings',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const _AudioChannelRow(channel: AudioChannel.bgm),
                  const _AudioChannelRow(channel: AudioChannel.sfx),
                  const _AudioChannelRow(channel: AudioChannel.ux),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$_label ${_on ? "on" : "off"}. Long press for volume.',
    child: Tooltip(
      message: '$_label: ${_on ? "on" : "off"}. Long press for volume.',
      child: Material(
        color: const Color(0xB3000000),
        shape: const CircleBorder(side: BorderSide(color: Colors.white54)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _toggle,
          onLongPress: _volume,
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: Text(
                _label,
                style: TextStyle(
                  color: _on ? Colors.white : Colors.white38,
                  fontSize: _label.length == 2 ? 11 : 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _AudioChannelRow extends StatefulWidget {
  const _AudioChannelRow({required this.channel});

  final AudioChannel channel;

  @override
  State<_AudioChannelRow> createState() => _AudioChannelRowState();
}

class _AudioChannelRowState extends State<_AudioChannelRow> {
  GameAudio get _audio => GameAudio.instance;

  String get _label => switch (widget.channel) {
    AudioChannel.bgm => 'BGM',
    AudioChannel.sfx => 'SFX',
    AudioChannel.ux => 'UX',
  };

  bool get _on => switch (widget.channel) {
    AudioChannel.bgm => _audio.musicOn,
    AudioChannel.sfx => _audio.effectsOn,
    AudioChannel.ux => _audio.uxOn,
  };

  double get _level => switch (widget.channel) {
    AudioChannel.bgm => _audio.musicLevel,
    AudioChannel.sfx => _audio.effectsLevel,
    AudioChannel.ux => _audio.uxLevel,
  };

  Future<void> _setOn(bool value) async {
    switch (widget.channel) {
      case AudioChannel.bgm:
        await _audio.setMusicOn(value);
        break;
      case AudioChannel.sfx:
        await _audio.setEffectsOn(value);
        break;
      case AudioChannel.ux:
        await _audio.setUxOn(value);
        break;
    }
    if (mounted) setState(() {});
  }

  Future<void> _setLevel(double value) async {
    switch (widget.channel) {
      case AudioChannel.bgm:
        await _audio.setMusicLevel(value);
        break;
      case AudioChannel.sfx:
        await _audio.setEffectsLevel(value);
        break;
      case AudioChannel.ux:
        await _audio.setUxLevel(value);
        break;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 38, child: Text(_label)),
      Switch(value: _on, onChanged: _setOn),
      Expanded(
        child: Slider(
          value: _level,
          onChanged: (value) {
            _setLevel(value);
            setState(() {});
          },
        ),
      ),
      SizedBox(
        width: 42,
        child: Text('${(_level * 100).round()}%', textAlign: TextAlign.right),
      ),
    ],
  );
}
