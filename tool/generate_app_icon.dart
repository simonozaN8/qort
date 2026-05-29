import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sporto_projektas/core/theme/qort_design_system.dart';

const _size = 1024;
const _fontFamily = 'Anton';

Future<void> generateAppIcons() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadAntonFont();

  final outDir = Directory('assets/icons');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  await _writeIcon(
    path: 'assets/icons/app_icon.png',
    background: QortDesignSystem.bgBase,
  );
  await _writeIcon(
    path: 'assets/icons/app_icon_foreground.png',
    background: null,
  );
}

Future<void> _loadAntonFont() async {
  final loader = FontLoader(_fontFamily)
    ..addFont(rootBundle.load('assets/fonts/Anton-Regular.ttf'));
  await loader.load();
}

Future<void> _writeIcon({
  required String path,
  required Color? background,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  if (background != null) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _size.toDouble(), _size.toDouble()),
      Paint()..color = background,
    );
  }

  final fontSize = _size * 0.68;
  final textPainter = TextPainter(
    text: TextSpan(
      text: 'Q',
      style: TextStyle(
        fontFamily: _fontFamily,
        fontSize: fontSize,
        color: QortDesignSystem.competition,
        letterSpacing: fontSize * 0.02,
        height: 1.0,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  textPainter.paint(
    canvas,
    Offset(
      (_size - textPainter.width) / 2,
      (_size - textPainter.height) / 2 - _size * 0.02,
    ),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(_size, _size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    throw StateError('Nepavyko užkoduoti PNG: $path');
  }

  await File(path).writeAsBytes(bytes.buffer.asUint8List());
}

Future<void> main() async {
  await generateAppIcons();
  stdout.writeln('Generated assets/icons/app_icon.png');
  stdout.writeln('Generated assets/icons/app_icon_foreground.png');
}
