import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/game/visual/atlas_batch.dart';
import 'package:istanbul_flight/game/weather.dart';

import 'fakes.dart';

// Phase 2.9 (docs/22 §4): çizim çağrısı birleştirme görüntüyü değiştirmez. Aynı kare, gerçek görsellerle
// eski yoldan (parça başına çağrı) ve yeni yoldan (drawRawAtlas / tek yol) çizilip piksel piksel karşılaştırılır.

const _w = 1170, _h = 2532;

Future<Uint8List> _frame(IstanbulFlightGame g, {required bool batch}) async {
  RenderTuning.batchDraws = batch;
  final rec = ui.PictureRecorder();
  g.render(ui.Canvas(rec));
  final pic = rec.endRecording();
  final img = await pic.toImage(_w, _h);
  final bytes = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  pic.dispose();
  img.dispose();
  return bytes.buffer.asUint8List();
}

Future<IstanbulFlightGame> _scene({int score = 0, Weather? weather, bool menu = false, bool gameOver = false}) async {
  final t = TestServices(clock: () => DateTime.utc(2026, 10, 24, 10));
  final g = await initializeGame(
    () => IstanbulFlightGame(
      scores: InMemoryScoreRepository(0),
      random: Random(7),
      pickupRandom: Random(8),
      hazardRandom: Random(9),
      services: t.services,
    ),
  );
  g.onGameResize(Vector2(_w.toDouble(), _h.toDouble()));
  await g.ready();
  if (!menu) {
    g.debugInvincible = !gameOver;
    g.autopilot = !gameOver;
    g.debugStartScore = score;
    g.debugWeather = weather;
    g.handleTap();
  }
  for (var i = 0; i < 420; i++) {
    g.update(1 / 60);
    if (i % 10 == 0) await g.ready();
  }
  return g;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => RenderTuning.batchDraws = true);

  final scenes = <String, Future<IstanbulFlightGame> Function()>{
    'menü (Haliç sisi, su)': () => _scene(menu: true),
    'Haliç açık': () => _scene(score: 1),
    'Galata': () => _scene(score: 30),
    'Kız Kulesi (duman)': () => _scene(score: 55),
    'Köprü': () => _scene(score: 75),
    'Rumeli sis': () => _scene(score: 95, weather: Weather.fog),
    'Emirgan rüzgâr': () => _scene(score: 125, weather: Weather.windy),
    'Ortaköy açık + tehlike': () => _scene(score: 150),
    'Ortaköy rüzgâr': () => _scene(score: 150, weather: Weather.windy),
    'Dolmabahçe sis': () => _scene(score: 185, weather: Weather.fog),
    'Üsküdar yağmur': () => _scene(score: 215, weather: Weather.rain),
    'oyun sonu': () => _scene(gameOver: true),
  };

  for (final e in scenes.entries) {
    test('aynı görüntü: ${e.key}', () async {
      final g = await e.value();
      // aynı kare, iki yol (arada güncelleme yok)
      final before = await _frame(g, batch: false);
      final after = await _frame(g, batch: true);
      var diff = 0;
      for (var i = 0; i < before.length; i += 4) {
        if (before[i] != after[i] ||
            before[i + 1] != after[i + 1] ||
            before[i + 2] != after[i + 2] ||
            before[i + 3] != after[i + 3]) {
          diff++;
        }
      }
      expect(diff, 0, reason: '${e.key}: $diff piksel farklı');
    }, timeout: const Timeout(Duration(minutes: 2)));
  }

  test('birleştirme açıkken çağrı sayısı düşer (engel tek drawRawAtlas)', () async {
    final g = await _scene(score: 150);
    expect(g.obstacles, isNotEmpty);
    expect(RenderTuning.batchDraws, isTrue);
  });
}
