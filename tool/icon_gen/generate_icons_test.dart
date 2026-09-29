// Renders every app icon and logo asset from MomentumMarkPainter.
//
//   flutter test tool/icon_gen/generate_icons_test.dart
//
// Re-run after changing lib/theme/momentum_mark.dart.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasktrackr/theme/momentum_mark.dart';

Future<void> _render(
  String path,
  int px, {
  bool background = true,
  double scale = 1,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size.square(px.toDouble());
  MomentumMarkPainter(
    withBackground: background,
    scale: scale,
    glow: px * scale >= 40,
  ).paint(canvas, size);
  final image = await recorder.endRecording().toImage(px, px);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('generate icons', (tester) async {
    await tester.runAsync(() async {
      // iOS: files are named by pixel size; opaque, no rounding (iOS masks).
      final ios = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
      for (final f in ios.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        final px = int.tryParse(name.replaceAll('.png', ''));
        if (px != null) await _render(f.path, px);
      }

      // macOS
      for (final px in [16, 32, 64, 128, 256, 512, 1024]) {
        await _render(
            'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$px.png',
            px);
      }

      // Android legacy launcher icons (48dp).
      const densities = {
        'mdpi': 1.0,
        'hdpi': 1.5,
        'xhdpi': 2.0,
        'xxhdpi': 3.0,
        'xxxhdpi': 4.0,
      };
      const res = 'android/app/src/main/res';
      for (final e in densities.entries) {
        await _render('$res/mipmap-${e.key}/ic_launcher.png',
            (48 * e.value).round());
        // Adaptive foreground (108dp canvas, mark kept in the 66dp safe zone).
        await _render(
          '$res/mipmap-${e.key}/ic_launcher_foreground.png',
          (108 * e.value).round(),
          background: false,
          scale: .72,
        );
      }

      // Web
      await _render('web/icons/Icon-192.png', 192);
      await _render('web/icons/Icon-512.png', 512);
      await _render('web/icons/Icon-maskable-192.png', 192, scale: .8);
      await _render('web/icons/Icon-maskable-512.png', 512, scale: .8);
      await _render('web/favicon.png', 32);

      // In-repo logo assets: icon tile + transparent mark.
      await _render('assets/logo_icon.png', 1024);
      await _render('assets/logo_mark.png', 1024, background: false);
    });
  });
}
