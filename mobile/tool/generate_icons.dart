// Генерує іконки MangoDota тим самим пензлем, що й логотип у застосунку.
// Запуск з mobile/:  flutter test tool/generate_icons.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dota_builds/core/theme/app_palette.dart';
import 'package:dota_builds/core/widgets/brand.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// [logoShare] — яку частку ширини займає манго. Для maskable-іконок менше,
/// щоб лаунчер не обрізав фрукт своєю маскою.
Future<List<int>> renderIcon(int size, {double logoShare = 0.72}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final side = size.toDouble();
  canvas.drawRect(Rect.fromLTWH(0, 0, side, side), Paint()..color = AppPalette.bg);
  final logo = side * logoShare;
  canvas.translate((side - logo) / 2, (side - logo) / 2);
  const MangoPainter(fruit: AppPalette.mango, leaf: AppPalette.tango).paint(canvas, Size.square(logo));
  final image = await recorder.endRecording().toImage(size, size);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

void main() {
  test('іконки Android і web', () async {
    const android = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
    for (final MapEntry(key: density, value: size) in android.entries) {
      File('android/app/src/main/res/mipmap-$density/ic_launcher.png').writeAsBytesSync(await renderIcon(size));
    }
    File('web/favicon.png').writeAsBytesSync(await renderIcon(32));
    for (final size in [192, 512]) {
      File('web/icons/Icon-$size.png').writeAsBytesSync(await renderIcon(size));
      File('web/icons/Icon-maskable-$size.png').writeAsBytesSync(await renderIcon(size, logoShare: 0.56));
    }
  });
}
