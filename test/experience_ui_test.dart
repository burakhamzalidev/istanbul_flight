import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/main.dart';
import 'package:istanbul_flight/services/share_service.dart';

import 'fakes.dart';

Future<(IstanbulFlightGame, TestServices)> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  int best = 0,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final t = TestServices();
  final game = IstanbulFlightGame(
    scores: InMemoryScoreRepository(best),
    random: Random(3),
    pickupRandom: Random(1),
    loadArt: false,
    services: t.services,
  );
  await tester.pumpWidget(MartiApp(game: game));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  return (game, t);
}

Future<void> _frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _dieAndShowCard(
  WidgetTester tester,
  IstanbulFlightGame game,
) async {
  await tester.tap(find.byKey(const Key('startButton')));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.tapAt(const Offset(195, 600));
  await _frames(tester, 260);
  expect(game.phase.value, GamePhase.gameOver);
}

void main() {
  testWidgets(
    'ana menü: kimlik, rekor, toplam simit, düğmeler; UÇMAYA BAŞLA → uçmak için dokun',
    (tester) async {
      final (game, t) = await _pumpApp(tester, best: 37);
      expect(find.text('MARTI'), findsOneWidget);
      expect(find.text('Rekor: Kız Kulesi · 37'), findsOneWidget);
      expect(find.byKey(const Key('totalSimits')), findsOneWidget);
      expect(
        find.text('UÇMAYA BAŞLA'),
        findsOneWidget,
        reason: 'Türkçe büyük harf: Ç, Ş korunur',
      );
      expect(find.byKey(const Key('muteButton')), findsOneWidget);

      // Menü arka planına dokunmak oyunu başlatmaz
      await tester.tapAt(const Offset(195, 400));
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.phase.value, GamePhase.ready);
      expect(game.menuOpen.value, isTrue);

      await tester.tap(find.byKey(const Key('startButton')));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('Uçmak için dokun'), findsOneWidget);
      expect(t.audio.sfx.map((s) => s.name), contains('button'));
      await tester.tapAt(const Offset(195, 600));
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.phase.value, GamePhase.playing);
      expect(find.byKey(const Key('simitCounter')), findsOneWidget);
      expect(find.byKey(const Key('scoreText')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
    },
  );

  testWidgets(
    'ayarlar: ses düzeyleri, titreşim ve animasyon ayarı kaydedilir; nasıl oynanır açılır',
    (tester) async {
      final (game, t) = await _pumpApp(tester);
      await tester.tap(find.byKey(const Key('settingsButton')));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('AYARLAR'), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('sfxSlider')),
        const Offset(-400, 0),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('hapticsSwitch')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('reduceMotionSwitch')));
      await tester.pump();
      final saved = await t.settingsRepo.load();
      expect(saved.sfxVolume, 0);
      expect(saved.haptics, isFalse);
      expect(saved.reduceMotion, isTrue);
      expect(game.reduceMotion, isTrue);
      expect(t.audio.sfxVolume, 0);

      await tester.tap(find.byKey(const Key('closeModal')));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('AYARLAR'), findsNothing);

      await tester.tap(find.byKey(const Key('howToButton')));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('NASIL OYNANIR'), findsOneWidget);
      await tester.tap(find.byKey(const Key('closeModal')));
      await tester.pump(const Duration(milliseconds: 16));

      // Hızlı sessiz anahtarı
      await tester.tap(find.byKey(const Key('muteButton')));
      await tester.pump();
      expect((await t.settingsRepo.load()).muted, isTrue);
      expect(find.text('Ses kapalı'), findsOneWidget);
    },
  );

  testWidgets('duraklatma menüsü: yeniden başlat ve ana menü', (tester) async {
    final (game, _) = await _pumpApp(tester);
    await tester.tap(find.byKey(const Key('startButton')));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tapAt(const Offset(195, 600));
    await _frames(tester, 10);
    await tester.tap(find.byKey(const Key('pauseButton')));
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      find.byKey(const Key('musicSlider')),
      findsOneWidget,
      reason: 'ses ayarları duraklatmada',
    );
    await tester.tap(find.byKey(const Key('restartFromPause')));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.phase.value, GamePhase.ready);
    expect(find.text('Uçmak için dokun'), findsOneWidget);

    await tester.tapAt(const Offset(195, 600));
    await _frames(tester, 10);
    await tester.tap(find.byKey(const Key('pauseButton')));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tap(find.byKey(const Key('menuFromPause')));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.menuOpen.value, isTrue);
    expect(find.byKey(const Key('startButton')), findsOneWidget);
  });

  testWidgets('devam geri sayımı: sayım bitene kadar oyun durur', (
    tester,
  ) async {
    final (game, _) = await _pumpApp(tester);
    await tester.tap(find.byKey(const Key('startButton')));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tapAt(const Offset(195, 600));
    await _frames(tester, 10);
    await tester.tap(find.byKey(const Key('pauseButton')));
    await tester.pump(const Duration(milliseconds: 16));
    final y = game.physics.y;
    await tester.tap(find.byKey(const Key('resumeButton')));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('3'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 460));
    expect(find.text('2'), findsOneWidget);
    expect(game.phase.value, GamePhase.paused);
    expect(game.physics.y, y);
    await tester.pump(const Duration(milliseconds: 460));
    await tester.pump(const Duration(milliseconds: 460));
    expect(game.phase.value, GamePhase.playing);
  });

  testWidgets('kartpostal: bölge, skor, rekor, simit; ana menüye dönüş', (
    tester,
  ) async {
    final (game, _) = await _pumpApp(tester, best: 3);
    await _dieAndShowCard(tester, game);
    expect(find.text("Haliç'ten selamlar!"), findsOneWidget);
    expect(find.byKey(const Key('reachedZone')), findsOneWidget);
    expect(find.byKey(const Key('finalScore')), findsOneWidget);
    expect(find.byKey(const Key('finalBest')), findsOneWidget);
    expect(find.byKey(const Key('finalSimits')), findsOneWidget);
    expect(find.text('TEKRAR UÇ'), findsOneWidget);
    expect(find.text('PAYLAŞ'), findsOneWidget);
    await tester.tap(find.byKey(const Key('menuButton')));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.menuOpen.value, isTrue);
    expect(find.byKey(const Key('startButton')), findsOneWidget);
  });

  testWidgets(
    'paylaş: kartpostal gerçekten PNG olarak üretilir ve sonuç bildirilir',
    (tester) async {
      final (game, t) = await _pumpApp(tester);
      await _dieAndShowCard(tester, game);
      for (final (outcome, message) in [
        (ShareOutcome.shared, 'Kartpostal paylaşıldı.'),
        (
          ShareOutcome.downloaded,
          'Bu tarayıcı paylaşımı desteklemiyor; kartpostal indirildi.',
        ),
        (
          ShareOutcome.failed,
          'Kartpostal paylaşılamadı. Lütfen tekrar deneyin.',
        ),
      ]) {
        t.share
          ..outcome = outcome
          ..lastPng = null;
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const Key('shareButton')));
          for (var i = 0; i < 50 && t.share.lastPng == null; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
        });
        await tester.pump(const Duration(milliseconds: 50));
        final png = t.share.lastPng!;
        expect(png.sublist(0, 8), [
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ], reason: 'PNG imzası');
        expect(png.length, greaterThan(10000));
        expect(t.share.lastText, contains('Haliç'));
        // iPad paylaşım menüsü için başlangıç noktası: Paylaş düğmesinin ekrandaki dikdörtgeni
        final origin = t.share.lastOrigin!;
        final button = tester.getRect(find.byKey(const Key('shareButton')));
        expect(origin.isEmpty, isFalse);
        expect(origin.contains(button.center), isTrue);
        expect(find.text(message), findsOneWidget);
        ScaffoldMessenger.of(tester.element(find.byType(Scaffold)))
            .removeCurrentSnackBar();
        await tester.pump(const Duration(milliseconds: 400));
      }
    },
  );

  for (final size in const [Size(320, 568), Size(360, 640)]) {
    testWidgets(
      'küçük ekran ${size.width.toInt()}×${size.height.toInt()}: menü, ayarlar, duraklatma, kartpostal taşmaz',
      (tester) async {
        final (game, _) = await _pumpApp(tester, size: size);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('settingsButton')));
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('closeModal')));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.tap(find.byKey(const Key('howToButton')));
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('closeModal')));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.tap(find.byKey(const Key('startButton')));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.tapAt(Offset(size.width / 2, size.height * 0.7));
        await _frames(tester, 10);
        await tester.tap(find.byKey(const Key('pauseButton')));
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('restartFromPause')));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.tapAt(Offset(size.width / 2, size.height * 0.7));
        await _frames(tester, 260);
        expect(game.phase.value, GamePhase.gameOver);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
