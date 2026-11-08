import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/game/weather.dart';

import 'fakes.dart';

// Phase 2.6.3 (docs/19 §6): dinamik engeller ve hava durumu oyun içinde.

Future<IstanbulFlightGame> _game() async {
  final t = TestServices(clock: () => DateTime.utc(2026, 10, 24, 10));
  final g = await initializeGame(
    () => IstanbulFlightGame(
      scores: InMemoryScoreRepository(0),
      random: Random(7),
      pickupRandom: Random(8),
      hazardRandom: Random(9),
      loadArt: false,
      services: t.services,
    ),
  );
  g.onGameResize(Vector2(1080, 1920));
  await g.ready();
  return g;
}

/// Klasik uçuş (çarpışmasız), skor 120'den başlar. Görülen dinamik engeller (koridor:tür) ve havalar döner.
Future<(List<String>, Set<Weather>)> _classic({double dt = 1 / 60}) async {
  final g = await _game();
  g.debugInvincible = true;
  g.debugStartScore = 120;
  g.handleTap();
  final seen = <String>{};
  final weathers = <Weather>{};
  for (var i = 0, n = (90 / dt).round(); i < n; i++) {
    final target = g.obstacles
            .where((o) => o.right > g.birdX - 40)
            .firstOrNull
            ?.gapCenter ??
        900;
    if (g.physics.y > target + 40 && g.physics.velocity > -200) g.handleTap();
    g.update(dt);
    for (final h in g.hazardViews) {
      seen.add('${h.hazard.corridor}:${h.hazard.kind.name}');
    }
    weathers.add(g.weatherLayer.weather);
  }
  expect(g.phase.value, GamePhase.playing);
  return (seen.toList()..sort(), weathers);
}

void main() {
  test('klasik, skor 120 sonrası: sürü ve rüzgâr çıkar; dizi kare hızından bağımsız', () async {
    final (a, _) = await _classic(dt: 1 / 60);
    final (b, _) = await _classic(dt: 1 / 30);
    final (c, _) = await _classic(dt: 1 / 120);
    expect(a, isNotEmpty);
    expect(a.any((s) => s.endsWith('flock')), isTrue);
    expect(a.any((s) => s.endsWith('gust')), isTrue);
    // uçuş süresi aynı; son karedeki farklar dışında aynı koridorlar
    final common = a.toSet().intersection(b.toSet()).intersection(c.toSet());
    expect(common.length, greaterThanOrEqualTo(a.length - 1));
  });

  test("Günün Uçuşu: dinamik engel yok, hava hep açık", () async {
    final g = await _game();
    g.debugInvincible = true;
    g.startDaily(ranked: false);
    g.handleTap();
    for (var i = 0; i < 60 * 200 && g.score.value < 140; i++) {
      final target = g.obstacles
              .where((o) => o.right > g.birdX - 40)
              .firstOrNull
              ?.gapCenter ??
          900;
      if (g.physics.y > target + 40 && g.physics.velocity > -200) {
        g.handleTap();
      }
      g.update(1 / 60);
      expect(g.hazardViews, isEmpty);
      expect(g.weatherLayer.weather, Weather.clear);
    }
    expect(g.score.value, greaterThanOrEqualTo(130));
  });

  // Performans regresyonu (docs/19 §8): uzun uçuşta bileşen sayısı sınırlı kalır, dinamik engel görünümleri
  // geri dönüştürülür (birikme yok).
  test('uzun uçuş: dünya bileşenleri ve tehlike görünümleri birikmez', () async {
    final g = await _game();
    g.debugInvincible = true;
    g.autopilot = true;
    g.debugStartScore = 120;
    g.debugWeather = Weather.rain;
    g.handleTap();
    var maxChildren = 0, maxHazards = 0, seen = 0;
    final ids = <int>{};
    for (var i = 0; i < 60 * 180; i++) {
      g.update(1 / 60);
      if (i % 30 == 0) await g.ready();
      maxChildren = max(maxChildren, g.world.children.length);
      maxHazards = max(maxHazards, g.hazardViews.length);
      for (final h in g.hazardViews) {
        if (ids.add(h.hazard.corridor)) seen++;
      }
    }
    expect(g.score.value, greaterThan(200));
    expect(seen, greaterThan(15)); // çok sayıda tehlike geldi ve gitti
    expect(maxHazards, lessThanOrEqualTo(3));
    expect(maxChildren, lessThanOrEqualTo(30));
  });
}
