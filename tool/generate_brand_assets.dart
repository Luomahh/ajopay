// Run explicitly: flutter test tool/generate_brand_assets.dart
// Exports the same code-native mark used in the application; no external images.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ajopay/core/widgets/ajo_ui.dart';
import 'package:ajopay/app/theme.dart';

void main() {
  testWidgets('export AjoPay launcher assets', (tester) async {
    final paths = <String, int>{
      'web/favicon.png': 32,
      'web/icons/Icon-192.png': 192,
      'web/icons/Icon-512.png': 512,
      'web/icons/Icon-maskable-192.png': 192,
      'web/icons/Icon-maskable-512.png': 512,
    };
    for (final e in {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    }.entries) {
      paths['android/app/src/main/res/mipmap-${e.key}/ic_launcher.png'] =
          e.value;
    }
    final contents =
        jsonDecode(
              File(
                'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
              ).readAsStringSync(),
            )
            as Map;
    for (final item in contents['images'] as List) {
      final size = double.parse((item['size'] as String).split('x').first);
      final scale = int.parse((item['scale'] as String).replaceAll('x', ''));
      paths['ios/Runner/Assets.xcassets/AppIcon.appiconset/${item['filename']}'] =
          (size * scale).round();
    }
    for (final e in paths.entries) {
      tester.view.physicalSize = Size.square(e.value.toDouble());
      tester.view.devicePixelRatio = 1;
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: AjoColors.forest,
              child: Center(child: AjoMark(size: e.value * .58)),
            ),
          ),
        ),
      );
      await tester.pump();
      final image = await tester.runAsync(
        () => (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(),
      );
      final bytes = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.png),
      );
      File(e.key).writeAsBytesSync(bytes!.buffer.asUint8List());
      image!.dispose();
    }
    tester.view.reset();
  });
}
