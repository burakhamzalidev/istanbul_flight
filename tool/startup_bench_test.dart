// Açılış ölçümü (docs/22 §7). Çalıştırma: flutter test tool/startup_bench_test.dart
// Oyunun yüklenmesi (onLoad: 109 görselin çözülmesi + dünya bileşenleri) ve ilk karenin kaydı. Masaüstü, JIT.
// ignore_for_file: avoid_print

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';

import '../test/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('açılış', () async {
    for (var rep = 0; rep < 4; rep++) {
      final sw = Stopwatch()..start();
      final t = TestServices(clock: () => DateTime.utc(2026, 11, 11, 12));
      final g = await initializeGame(
        () => IstanbulFlightGame(scores: InMemoryScoreRepository(0), random: Random(7), services: t.services),
      );
      final load = sw.elapsedMicroseconds / 1000;
      g.onGameResize(Vector2(1170, 2532));
      await g.ready();
      sw.reset();
      g.update(1 / 60);
      final rec = ui.PictureRecorder();
      g.render(ui.Canvas(rec));
      rec.endRecording().dispose();
      final first = sw.elapsedMicroseconds / 1000;
      print('${rep == 0 ? 'ilk (soğuk)' : 'tekrar $rep    '}: yükleme ${load.toStringAsFixed(0)} ms · ilk kare ${first.toStringAsFixed(1)} ms');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
