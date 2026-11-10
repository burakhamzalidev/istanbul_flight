import 'dart:math';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/components/fx_layer.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';

import 'fakes.dart';

// Phase 2.9 (docs/22 §9): uzun uçuşta nesne birikmez; kare hızı değişse de oyun aynı sonucu verir.

Future<IstanbulFlightGame> _game() async {
  final t = TestServices(clock: () => DateTime.utc(2026, 11, 11, 12));
  return initializeGame(
    () => IstanbulFlightGame(
      scores: InMemoryScoreRepository(0),
      random: Random(7),
      pickupRandom: Random(8),
      hazardRandom: Random(9),
      loadArt: false,
      services: t.services,
    ),
  );
}

void main() {
  test('10.000 karelik kesintisiz uçuş: bileşen, engel, tehlike ve efekt sayısı sınırlı', () async {
    final g = await _game();
    g.debugInvincible = true;
    g.autopilot = true;
    g.handleTap();
    var maxWorld = 0, maxObs = 0, maxHaz = 0, maxFx = 0;
    for (var i = 0; i < 10000; i++) {
      g.update(1 / 60);
      if (i % 50 == 0) await g.ready();
      maxWorld = max(maxWorld, g.world.children.length);
      maxObs = max(maxObs, g.obstacles.length);
      maxHaz = max(maxHaz, g.hazardViews.length);
      maxFx = max(maxFx, g.fx.activeCount);
    }
    expect(g.phase.value, GamePhase.playing);
    expect(g.score.value, greaterThan(100), reason: 'uzun bir rota gerçekten uçuldu');
    expect(maxWorld, lessThanOrEqualTo(30));
    expect(maxObs, lessThanOrEqualTo(6));
    expect(maxHaz, lessThanOrEqualTo(3));
    expect(maxFx, lessThanOrEqualTo(FxLayer.poolSize));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('20 dakikalık uçuş (72.000 kare): sayılar başta ve sonda aynı aralıkta', () async {
    final g = await _game();
    g.debugInvincible = true;
    g.autopilot = true;
    g.handleTap();
    late int worldAt5Min;
    for (var i = 0; i < 72000; i++) {
      g.update(1 / 60);
      if (i % 200 == 0) await g.ready();
      if (i == 18000) worldAt5Min = g.world.children.length;
    }
    expect(g.world.children.length, lessThanOrEqualTo(worldAt5Min + 4));
    expect(g.obstacles.length, lessThanOrEqualTo(6));
    expect(g.hazardViews.length, lessThanOrEqualTo(3));
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('kare hızından bağımsız: aynı Günün Uçuşu 30 / 60 / 120 Hz\'de aynı engeller ve aynı skor', () async {
    Future<(int, List<double>)> run(int hz) async {
      final g = await _game();
      g.autopilot = true;
      g.debugInvincible = true;
      g.startDaily(ranked: false);
      g.handleTap();
      final gaps = <double>[];
      final frames = 40 * hz; // 40 sn oyun zamanı
      for (var i = 0; i < frames; i++) {
        g.update(1 / hz);
        if (i % 30 == 0) await g.ready();
        for (final o in g.obstacles) {
          if (!gaps.contains(o.gapTop)) gaps.add(o.gapTop);
        }
      }
      return (g.score.value, gaps);
    }

    final (s60, g60) = await run(60);
    final (s120, g120) = await run(120);
    final (s30, g30) = await run(30);
    expect(g60.length, greaterThan(10));
    expect(g120, g60);
    expect(g30, g60);
    expect(s120, s60);
    expect(s30, s60);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
