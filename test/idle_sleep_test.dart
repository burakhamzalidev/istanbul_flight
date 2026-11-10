import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/main.dart';

import 'fakes.dart';

// Phase 2.9 (docs/22 §6): oyun dışında kimse bakmıyorken sahne uyur (pil / ısınma); uçuşa hiç dokunmaz.

const _f = Duration(milliseconds: 16);

Future<(IstanbulFlightGame, TestServices)> _app(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final t = TestServices(clock: () => DateTime.utc(2026, 11, 11, 12));
  final game = IstanbulFlightGame(
    scores: InMemoryScoreRepository(),
    random: Random(3),
    pickupRandom: Random(1),
    loadArt: false,
    services: t.services,
  );
  await tester.pumpWidget(MartiApp(game: game));
  await tester.pump(const Duration(milliseconds: 100));
  return (game, t);
}

Future<void> _pumpFor(WidgetTester tester, Duration d) async {
  final end = tester.binding.clock.now().add(d);
  while (tester.binding.clock.now().isBefore(end)) {
    await tester.pump(_f);
  }
}

Future<void> _crash(WidgetTester tester, IstanbulFlightGame game) async {
  game.startFromMenu();
  await tester.pump(_f);
  game.handleTap();
  for (var i = 0; i < 600 && game.phase.value == GamePhase.playing; i++) {
    await tester.pump(_f);
  }
}

void main() {
  testWidgets('modal ekran açılınca sahne uyur, kapanınca uyanır', (tester) async {
    final (game, _) = await _app(tester);
    expect(game.paused, isFalse);
    await tester.tap(find.byKey(const Key('shopButton')));
    await tester.pump(_f);
    expect(game.modal.value, isNotNull);
    expect(game.sceneAsleep.value, isTrue);
    expect(game.paused, isTrue);
    game.closeModal();
    await tester.pump(_f);
    expect(game.sceneAsleep.value, isFalse);
    expect(game.paused, isFalse);
  });

  testWidgets('oyun sonu yerleşince uyur; "Tekrar uç" tek dokunuşla uçuşa döner', (tester) async {
    final (game, _) = await _app(tester);
    await _crash(tester, game);
    await _pumpFor(tester, const Duration(seconds: 4));
    expect(game.phase.value, GamePhase.gameOver);
    expect(game.canRestart.value, isTrue);
    expect(game.sceneAsleep.value, isTrue);
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'kart yerleşti, kare istenmemeli');
    await tester.tap(find.byKey(const Key('restartButton')));
    await tester.pump(_f);
    expect(game.phase.value, GamePhase.ready);
    expect(game.paused, isFalse);
  });

  testWidgets('30 sn dokunulmazsa derin uyku (arayüz animasyonları da durur); dokununca uyanır', (tester) async {
    final (game, _) = await _app(tester);
    await _pumpFor(tester, const Duration(seconds: 10));
    expect(game.sceneAsleep.value, isFalse);
    await _pumpFor(tester, IstanbulFlightGame.idleTimeout);
    expect(game.deepIdle.value, isTrue);
    expect(game.paused, isTrue);
    await tester.pump(_f);
    expect(tester.binding.hasScheduledFrame, isFalse);
    // ilk dokunuş hem uyandırır hem de normal işini yapar
    await tester.tap(find.byKey(const Key('startButton')));
    await tester.pump(_f);
    expect(game.deepIdle.value, isFalse);
    expect(game.paused, isFalse);
    expect(game.menuOpen.value, isFalse);
  });

  testWidgets('uçuş sırasında asla uyumaz (dokunulmasa da)', (tester) async {
    final (game, _) = await _app(tester);
    game.debugInvincible = true;
    game.autopilot = true;
    game.startFromMenu();
    await tester.pump(_f);
    game.handleTap();
    await _pumpFor(tester, const Duration(seconds: 45));
    expect(game.phase.value, GamePhase.playing);
    expect(game.paused, isFalse);
    expect(game.sceneAsleep.value, isFalse);
    expect(game.deepIdle.value, isFalse);
  });

  testWidgets('uykudayken arka plana alınıp dönünce uykuda kalır; dokununca uyanır', (tester) async {
    final (game, _) = await _app(tester);
    game.openModal(Overlays.profile);
    await tester.pump(_f);
    expect(game.paused, isTrue);
    game.lifecycleStateChange(AppLifecycleState.paused);
    game.lifecycleStateChange(AppLifecycleState.inactive);
    game.lifecycleStateChange(AppLifecycleState.resumed);
    await tester.pump(_f);
    expect(game.paused, isTrue, reason: 'pencere hâlâ açık');
    game.closeModal();
    await tester.pump(_f);
    expect(game.paused, isFalse);
  });

  testWidgets('uçarken arka plana alınırsa duraklar, dönüşte "Devam" bekler (değişmedi)', (tester) async {
    final (game, _) = await _app(tester);
    game.startFromMenu();
    await tester.pump(_f);
    game.handleTap();
    await tester.pump(_f);
    game.lifecycleStateChange(AppLifecycleState.inactive);
    game.lifecycleStateChange(AppLifecycleState.paused);
    game.lifecycleStateChange(AppLifecycleState.resumed);
    await tester.pump(_f);
    expect(game.phase.value, GamePhase.paused);
    expect(game.paused, isTrue);
    expect(game.sceneAsleep.value, isFalse);
  });

  testWidgets('uyku Günün Uçuşu parkurunu değiştirmez (aynı tohum, aynı engeller)', (tester) async {
    Future<List<double>> course({required bool idleFirst}) async {
      final (game, _) = await _app(tester);
      if (idleFirst) {
        await _pumpFor(tester, const Duration(seconds: 40));
        expect(game.deepIdle.value, isTrue);
        game.noteActivity();
      }
      game.debugInvincible = true;
      game.startDaily(ranked: false);
      await tester.pump(_f);
      game.handleTap();
      final gaps = <double>[];
      for (var i = 0; i < 900 && gaps.length < 8; i++) {
        await tester.pump(_f);
        for (final o in game.obstacles) {
          if (!gaps.contains(o.gapTop)) gaps.add(o.gapTop);
        }
      }
      await tester.pumpWidget(const SizedBox());
      return gaps.take(8).toList();
    }

    final a = await course(idleFirst: false);
    final b = await course(idleFirst: true);
    expect(a.length, 8);
    expect(b, a);
  });
}
