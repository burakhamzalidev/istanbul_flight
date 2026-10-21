import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/main.dart';

/// Görev 5: oyun ana menüyle açılır. "UÇMAYA BAŞLA" → "uçmak için dokun" ekranı.
Future<void> _leaveMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('startButton')));
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('arayüz akışı: hazır → oyun → kartpostal → tekrar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = IstanbulFlightGame(
      scores: InMemoryScoreRepository(),
      random: Random(3),
      loadArt: false,
    );
    await tester.pumpWidget(MartiApp(game: game));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await _leaveMenu(tester);

    expect(find.text('Uçmak için dokun'), findsOneWidget);

    await tester.tapAt(const Offset(195, 600));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.phase.value, GamePhase.playing);
    expect(find.byKey(const Key('scoreText')), findsOneWidget);

    // Dokunmadan bekle: Simit suya düşer, kartpostal açılır
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.phase.value, GamePhase.gameOver);
    expect(find.text("Haliç'ten selamlar!"), findsOneWidget);
    expect(find.byKey(const Key('finalScore')), findsOneWidget);

    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.canRestart.value, isTrue);
    await tester.tap(find.byKey(const Key('restartButton')));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.phase.value, GamePhase.ready);
    expect(find.text('Uçmak için dokun'), findsOneWidget);
  });

  testWidgets('duraklat butonu PAUSED açar, Devam oyunu sürdürür', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = IstanbulFlightGame(
      scores: InMemoryScoreRepository(),
      loadArt: false,
    );
    await tester.pumpWidget(MartiApp(game: game));
    await tester.pump(const Duration(milliseconds: 100));
    await _leaveMenu(tester);
    await tester.tapAt(const Offset(195, 600));
    await tester.pump(const Duration(milliseconds: 16));

    await tester.tap(find.byKey(const Key('pauseButton')));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.phase.value, GamePhase.paused);
    expect(find.text('Duraklatıldı'), findsOneWidget);

    await tester.tap(find.byKey(const Key('resumeButton')));
    await tester.pump(const Duration(milliseconds: 16));
    // Görev 5: Devam, 3-2-1 geri sayımından sonra oyunu sürdürür
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 460));
    }
    expect(game.phase.value, GamePhase.playing);
  });

  for (final size in const [
    Size(320, 568),
    Size(360, 640),
    Size(390, 844),
    Size(412, 915),
    Size(768, 1024),
    Size(1024, 768),
  ]) {
    testWidgets(
      'ekran ${size.width.toInt()}×${size.height.toInt()}: taşma yok, oyun alanı doğru',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final game = IstanbulFlightGame(
          scores: InMemoryScoreRepository(5),
          loadArt: false,
        );
        await tester.pumpWidget(MartiApp(game: game));
        await tester.pump(const Duration(milliseconds: 100));
        // Oyun alanı: tam yükseklik, genişlik en fazla 3:4 (yatay ekranda ortalanmış sütun)
        final gameSize = tester.getSize(find.byType(GameScreen).first);
        expect(gameSize.height, size.height);
        expect(game.size.y, closeTo(size.height, 0.5));
        expect(
          game.size.x,
          closeTo(
            size.width > size.height * 0.75 ? size.height * 0.75 : size.width,
            0.5,
          ),
        );
        expect(
          game.visibleWidth,
          closeTo(game.size.x / (game.size.y / 1920), 0.5),
        );
        expect(tester.takeException(), isNull);

        // Oyun → kartpostal: hiçbir aşamada yerleşim hatası yok
        await _leaveMenu(tester);
        expect(tester.takeException(), isNull);
        await tester.tapAt(Offset(size.width / 2, size.height * 0.7));
        for (var i = 0; i < 220; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(game.phase.value, GamePhase.gameOver);
        expect(find.byKey(const Key('restartButton')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
