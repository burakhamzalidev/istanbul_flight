// HUD yeniden kurulum ölçümü (docs/21 §9). Çalıştırma: flutter test tool/hud_rebuild_bench_test.dart
// Uçuş sırasında Flutter katmanında (HUD ve overlay'ler) her karede kaç widget'ın yeniden kurulduğunu sayar.
// Test ortamı (debug, masaüstü); mutlak süre değil, önce/sonra karşılaştırması içindir. FPS ölçmez.
// ignore_for_file: avoid_print

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/main.dart';

import '../test/fakes.dart';

const _frame = Duration(microseconds: 16667);

Future<void> _bench(
  WidgetTester tester,
  String label,
  void Function(IstanbulFlightGame g) start, {
  int frames = 1200,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  final t = TestServices(clock: () => DateTime.utc(2026, 11, 11, 12));
  final game = IstanbulFlightGame(
    scores: InMemoryScoreRepository(),
    random: Random(7),
    pickupRandom: Random(8),
    loadArt: false,
    services: t.services,
  );
  await tester.pumpWidget(MartiApp(game: game));
  await tester.pump(const Duration(milliseconds: 100));
  game.debugInvincible = true;
  game.autopilot = true;
  start(game);
  await tester.pump(_frame);
  game.handleTap();
  for (var i = 0; i < 120; i++) {
    await tester.pump(_frame); // ısınma
  }
  final byType = <String, int>{};
  var total = 0;
  debugOnRebuildDirtyWidget = (e, _) {
    total++;
    final k = e.widget.runtimeType.toString();
    byType[k] = (byType[k] ?? 0) + 1;
  };
  final sw = Stopwatch()..start();
  for (var i = 0; i < frames; i++) {
    await tester.pump(_frame);
  }
  sw.stop();
  debugOnRebuildDirtyWidget = null;
  final top = (byType.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
      .take(6)
      .map((e) => '${e.key} ${(e.value / frames).toStringAsFixed(2)}')
      .join(', ');
  print('$label: kare başına yeniden kurulum ${(total / frames).toStringAsFixed(2)} '
      '(toplam $total / $frames kare, skor ${game.score.value}) · pump ort. ${(sw.elapsedMicroseconds / 1000 / frames).toStringAsFixed(3)} ms\n'
      '    en çok: $top');
  await tester.pumpWidget(const SizedBox());
  await tester.binding.setSurfaceSize(null);
}

void main() {
  testWidgets('HUD rebuild: klasik', (tester) => _bench(tester, 'Klasik   ', (g) => g.startFromMenu()));
  testWidgets('HUD rebuild: günlük', (tester) => _bench(tester, 'Günlük   ', (g) => g.startDaily(ranked: true)));
  testWidgets('HUD rebuild: eğitim', (tester) => _bench(tester, 'Eğitim   ', (g) => g.startTutorial())); // TUTORIAL
}
