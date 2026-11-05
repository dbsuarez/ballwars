import 'arena_image_crop.dart';
import '../domain/arena_background_style.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/sprites/sprite_atlas.dart';
import '../../../core/sprites/sprite_registry.dart';
import '../../settings/presentation/app_settings_scope.dart';

/// Source-pixel square crop; shared by the preview and uploaded result.
Rect arenaBackgroundCrop(Size source, double zoom, double x, double y) {
  return ArenaBackgroundStyle(zoom: zoom, x: x, y: y).crop(source);
}

class ArenaBackgroundImport extends StatefulWidget {
  const ArenaBackgroundImport({super.key, this.pickImage});
  final Future<Uint8List?> Function()? pickImage;
  @override
  State<ArenaBackgroundImport> createState() => _ArenaBackgroundImportState();
}

class _ArenaBackgroundImportState extends State<ArenaBackgroundImport> {
  ui.Image? image;
  double zoom = 1, x = .5, y = .5;
  bool busy = false;
  String? error;
  int output = 1024;
  final name = TextEditingController(text: "Arena background");
  @override
  void dispose() {
    image?.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> choose() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final bytes = widget.pickImage != null
          ? await widget.pickImage!()
          : (await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
              withData: true,
            ))?.files.single.bytes;
      if (bytes == null) return;
      if (bytes.isEmpty || bytes.length > 16 * 1024 * 1024) {
        throw const FormatException('Choose an image no larger than 16 MB.');
      }
      final codec = await ui.instantiateImageCodec(bytes);
      ui.Image? decoded;
      try {
        if (codec.frameCount != 1) {
          throw const FormatException('Choose a static image.');
        }
        decoded = (await codec.getNextFrame()).image;
        if (decoded.width > 8192 ||
            decoded.height > 8192 ||
            decoded.width * decoded.height > 16777216) {
          throw const FormatException(
            'Choose an image up to 8192 pixels per side and 16 megapixels.',
          );
        }
        if (!mounted) return;
        image?.dispose();
        image = decoded;
        decoded = null;
        setState(() {
          zoom = 1;
          x = .5;
          y = .5;
        });
      } finally {
        decoded?.dispose();
        codec.dispose();
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> upload() async {
    final source = image;
    final repository = AppSettingsScope.maybeScope(context)?.sprites;
    if (source == null || repository == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    ui.Image? normalized;
    try {
      final crop = arenaBackgroundCrop(
        Size(source.width.toDouble(), source.height.toDouble()),
        zoom,
        x,
        y,
      );
      final side = math.min(output, crop.width.floor()).clamp(1, 1024);
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        source,
        crop,
        Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      try {
        normalized = await picture.toImage(side, side);
      } finally {
        picture.dispose();
      }
      final data = await normalized.toByteData(format: ui.ImageByteFormat.png);
      if (data == null || data.lengthInBytes > 4 * 1024 * 1024) {
        throw const FormatException(
          'Optimized image exceeds 4 MB. Choose 512px.',
        );
      }
      final atlas = SpriteAtlas(
        sheet: 'background.png',
        sheetSize: Size(side.toDouble(), side.toDouble()),
        sprites: {
          'background': SpriteDef(
            id: 'background',
            label: 'Arena background',
            frames: [Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble())],
            output: side,
            padding: 0,
            fit: SpriteFit.fill,
            bleedOk: true,
            bleedNote: 'One complete background image; no neighboring frames.',
          ),
        },
      );
      final saved = await repository.save(
        name: name.text.trim(),
        sheet: data.buffer.asUint8List(),
        contentType: 'image/png',
        atlas: atlas,
      );
      await SpriteRegistry.register(
        saved.atlas,
        normalized,
        idPrefix: 'custom.${saved.id}',
        label: saved.name,
      );
      final revision = saved.sheetPath.split('/').last.split('.').first;
      if (RegExp(r'^[a-f0-9-]{36}$').hasMatch(revision)) {
        final source = 'custom.${saved.id}.background',
            frozen = 'custom.${saved.id}~$revision.background';
        SpriteRegistry.alias(source, frozen, 'custom.${saved.id}~$revision');
        SpriteRegistry.frozenIds[source] = frozen;
      }
      if (mounted) Navigator.pop(context, 'custom.${saved.id}.background');
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Upload failed. Your crop is kept; retry.\n$e');
      }
    } finally {
      normalized?.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Arena background')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Uploads are stored in the sprite library; save the arena afterward to publish its selection. Crop a square image. The arena masks it to a circle or square during play. Your original file stays unchanged.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : choose,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose image'),
          ),
          const Text('Library name'),
          TextField(
            controller: name,
            maxLength: 80,
            enabled: !busy,
            decoration: const InputDecoration(
              hintText: 'Name in sprite library',
            ),
          ),
          if (image case final source?) ...[
            const SizedBox(height: 12),
            ArenaImageCrop(
              image: source,
              style: ArenaBackgroundStyle(zoom: zoom, x: x, y: y),
              enabled: !busy,
              onChanged: (value) => setState(() {
                zoom = value.zoom;
                x = value.x;
                y = value.y;
              }),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Drag the image to move it. Pinch to zoom.'),
            ),
            for (final field in ['Zoom', 'Horizontal', 'Vertical']) ...[
              Text(field),
              Slider(
                value: field == 'Zoom'
                    ? zoom
                    : field == 'Horizontal'
                    ? x
                    : y,
                min: field == 'Zoom' ? 1 : 0,
                max: field == 'Zoom' ? 4 : 1,
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                        if (field == 'Zoom') {
                          zoom = v;
                        } else if (field == 'Horizontal') {
                          x = v;
                        } else {
                          y = v;
                        }
                      }),
              ),
            ],
            Row(
              children: [
                const Expanded(child: Text('Maximum upload size')),
                DropdownButton<int>(
                  value: output,
                  items: [
                    for (final n in [512, 1024])
                      DropdownMenuItem(value: n, child: Text('$n × $n')),
                  ],
                  onChanged: busy ? null : (v) => setState(() => output = v!),
                ),
              ],
            ),
            Text(
              'Source: ${source.width} × ${source.height}. Cropped, resized PNG only is uploaded; smaller images are not enlarged. Maximum 4 MB.',
            ),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed:
                busy ||
                    image == null ||
                    AppSettingsScope.maybeScope(context)?.sprites == null
                ? null
                : upload,
            icon: Icon(
              busy ? Icons.hourglass_top : Icons.cloud_upload_outlined,
            ),
            label: Text(busy ? 'Saving…' : 'Upload background'),
          ),
        ),
      ),
    ),
  );
}
