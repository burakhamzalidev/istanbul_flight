// Boşta iş ölçümü (docs/22 §6). Çalıştırma: flutter test tool/idle_probe_test.dart
// Her durumda: Flame motoru çalışıyor mu, Flutter yeni kare istiyor mu (bekleyen kare = CPU/GPU uyanık kalır).
// ignore_for_file: avoid_print

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/main.dart';

import '../test/fakes.dart';

void main() {
  testWidgets('boşta iş', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
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

    Future<void> report(String label, {Duration wait = const Duration(seconds: 2)}) async {
      final end = tester.binding.clock.now().add(wait);
      var frames = 0;
      while (tester.binding.clock.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
      }
      // bir kare daha: bekleyen kare isteği var mı
      await tester.pump(const Duration(milliseconds: 16));
      print('$label: motor ${game.paused ? 'DURDU' : 'çalışıyor'} · bekleyen kare ${tester.binding.hasScheduledFrame ? 'VAR' : 'yok'} ($frames kare izlendi)');
    }

    await report('Menü (yeni açılmış)');
    await report('Menü (60 sn dokunulmadı)', wait: const Duration(seconds: 60));
    for (final m in [Overlays.shop, Overlays.profile, Overlays.discovery, Overlays.events, Overlays.leaderboard]) {
      game.noteActivity(); // gerçekte ekran bir dokunuşla açılır
      game.openModal(m);
      await report('Modal: $m');
      game.closeModal();
      await tester.pump(const Duration(milliseconds: 16));
    }
    game.noteActivity();
    game.startFromMenu();
    await tester.pump(const Duration(milliseconds: 16));
    await report('Hazır ("uçmak için dokun")');
    await report('Hazır (35 sn dokunulmadı)', wait: const Duration(seconds: 35));
    game.handleTap();
    await tester.pump(const Duration(milliseconds: 16));
    game.pauseGame();
    await report('Duraklatıldı');
    game.resumeGame();
    for (var i = 0; i < 600 && game.phase.value == GamePhase.playing; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await report('Oyun sonu (kart yeni)');
    await report('Oyun sonu (30 sn sonra)', wait: const Duration(seconds: 30));
  });
}
