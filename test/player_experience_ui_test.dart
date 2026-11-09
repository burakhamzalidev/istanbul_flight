import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/main.dart';
import 'package:istanbul_flight/progression/discovery.dart';
import 'package:istanbul_flight/services/progress.dart';
import 'package:istanbul_flight/services/ux_state.dart';
import 'package:istanbul_flight/ui/overlays/menu_overlays.dart';

import 'fakes.dart';

// Phase 2.8 (docs/21): ilk açılış, menü hiyerarşisi, oyun sonu, "yeni" işaretleri, erişilebilirlik.

final _now = DateTime.utc(2026, 11, 11, 12);

Future<(IstanbulFlightGame, TestServices)> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  PlayerProgress progress = const PlayerProgress(),
  UxState ux = const UxState(tutorial: TutorialStatus.legacy),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final t = TestServices(
    progress: progress,
    clock: () => _now,
    ux: UxController(InMemoryUxRepository(ux), ux),
  );
  final game = IstanbulFlightGame(
    scores: InMemoryScoreRepository(),
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

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pump();
  await tester.tap(find.byKey(Key(key)));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> _crashToGameOver(WidgetTester tester, IstanbulFlightGame game) async {
  game.startFromMenu();
  await tester.pump(const Duration(milliseconds: 16));
  game.handleTap();
  for (var i = 0; i < 400 && game.phase.value == GamePhase.playing; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  for (var i = 0; i < 200; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  sweepTests();
  testWidgets('ilk açılış: eğitim ekranı (1/3, yönerge, dokunma animasyonu), atla → menü', (tester) async {
    final (game, t) = await _pumpApp(tester, ux: const UxState());
    expect(find.byKey(const Key('tutorialStage')), findsOneWidget);
    expect(find.text('1/3 · Uçmayı öğren'), findsOneWidget);
    expect(find.text('Uçmak için ekrana dokun'), findsOneWidget);
    expect(find.byKey(const Key('tutorialSkip')), findsOneWidget);
    expect(find.byKey(const Key('startButton')), findsNothing);
    await _tap(tester, 'tutorialSkip');
    expect(t.services.ux.value.tutorial, TutorialStatus.skipped);
    expect(find.byKey(const Key('startButton')), findsOneWidget);
    expect(game.runMode.value.name, 'classic');
  });

  testWidgets('eğitim uçuşu: HUD skor yerine aşama ve yönerge gösterir', (tester) async {
    final (game, _) = await _pumpApp(tester, ux: const UxState());
    game.handleTap();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byKey(const Key('tutorialHudText')), findsOneWidget);
    expect(find.byKey(const Key('scoreText')), findsNothing);
    expect(find.text('Dokundukça yükselirsin. Havada kal!'), findsOneWidget);
    // HUD oyun alanını kapatmaz: geçitlerin bulunduğu orta bant (%25–60) boş
    const h = 844.0;
    expect(tester.getRect(find.byKey(const Key('tutorialStage'))).bottom, lessThan(h * 0.2));
    expect(tester.getRect(find.byKey(const Key('tutorialHudText'))).top, greaterThan(h * 0.6));
  });

  testWidgets('"Nasıl oynanır" → "Eğitimi oyna" eğitimi yeniden başlatır', (tester) async {
    final (game, _) = await _pumpApp(tester);
    await _tap(tester, 'howToButton');
    await _tap(tester, 'replayTutorial');
    expect(game.runMode.value.name, 'tutorial');
    expect(find.byKey(const Key('tutorialStage')), findsOneWidget);
  });

  testWidgets('menü: tek birincil eylem; her özellik tek dokunuşla açılır', (tester) async {
    final (game, _) = await _pumpApp(tester);
    expect(find.text('UÇUŞA BAŞLA'), findsOneWidget);
    for (final (key, modal) in [
      ('profileButton', Overlays.profile),
      ('shopButton', Overlays.shop),
      ('discoveryButton', Overlays.discovery),
      ('leaderboardButton', Overlays.leaderboard),
      ('dailyButton', Overlays.daily),
      ('eventsButton', Overlays.events),
      ('missionsButton', Overlays.missions),
      ('achievementsButton', Overlays.achievements),
      ('settingsButton', Overlays.settings),
      ('howToButton', Overlays.howTo),
    ]) {
      await _tap(tester, key);
      expect(game.modal.value, modal, reason: key);
      game.closeModal();
      await tester.pump(const Duration(milliseconds: 16));
    }
    // birincil eylem: menüden tek dokunuş → "uçmak için dokun"; ilk dokunuş uçuşu başlatır
    await _tap(tester, 'startButton');
    expect(game.phase.value, GamePhase.ready);
    expect(game.menuOpen.value, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(320, 568), Size(375, 667), Size(430, 932)]) {
    testWidgets('oyun sonu: "Tekrar uç" kaydırmadan görünür, tek dokunuşla yeniden uçuş (${size.width.toInt()}×${size.height.toInt()})', (tester) async {
      final (game, _) = await _pumpApp(tester, size: size);
      await _crashToGameOver(tester, game);
      expect(game.phase.value, GamePhase.gameOver);
      final r = tester.getRect(find.byKey(const Key('restartButton')));
      expect(r.bottom, lessThanOrEqualTo(size.height));
      expect(r.top, greaterThanOrEqualTo(0));
      expect(find.byKey(const Key('postcardFrame')), findsOneWidget);
      await tester.tap(find.byKey(const Key('restartButton')));
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.phase.value, GamePhase.ready);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('"yeni" işaretleri: görülmemiş görünüm, kartpostal ve etkinlik; açınca söner', (tester) async {
    final p = PlayerProgress(
      unlockedCosmetics: const {'classic', 'iznik'},
      discoveredZones: const {0},
      discovery: DiscoveryState(firstSeen: {0: _now}),
      flights: 3,
    );
    final (game, t) = await _pumpApp(
      tester,
      progress: p,
      ux: const UxState(tutorial: TutorialStatus.legacy),
    );
    Finder dotIn(String key) => find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byKey(const ValueKey('newDot')),
    );
    expect(dotIn('shopButton'), findsOneWidget);
    expect(dotIn('discoveryButton'), findsOneWidget);
    expect(find.byKey(const Key('eventsNewDot')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('yeni görünüm var')),
      findsOneWidget,
    );
    for (final (key, _) in [('shopButton', 0), ('discoveryButton', 0), ('eventsButton', 0)]) {
      await _tap(tester, key);
      await tester.pump(const Duration(milliseconds: 16));
      game.closeModal();
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(dotIn('shopButton'), findsNothing);
    expect(dotIn('discoveryButton'), findsNothing);
    expect(find.byKey(const Key('eventsNewDot')), findsNothing);
    expect(t.services.ux.value.seenCosmetics, contains('iznik'));
  });

  testWidgets('erişilebilirlik: menüde dokunma hedefleri etiketli ve ≥ 44 pt', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpApp(tester);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    expect(find.bySemanticsLabel(RegExp('Profil, seviye')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Simit mağazası')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp("İstanbul'u Keşfet")), findsOneWidget);
    handle.dispose();
  });

  testWidgets('erişilebilirlik: eğitim ekranı etiketli', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpApp(tester, ux: const UxState());
    expect(find.bySemanticsLabel(RegExp('Eğitim, aşama 1 / 3')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Eğitimi atla')), findsWidgets);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('büyük metin (1,3×): menü ve oyun sonu küçük ekranda taşmaz', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final (game, _) = await _pumpApp(tester, size: const Size(375, 667));
    expect(tester.takeException(), isNull);
    await _crashToGameOver(tester, game);
    expect(find.byKey(const Key('restartButton')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS "Hareketi Azalt" oyunun azaltılmış hareketine eşlenir (varsayılan oyun değişmez)', (tester) async {
    final (plain, _) = await _pumpApp(tester);
    expect(plain.reduceMotion, isFalse);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final (game, _) = await _pumpApp(tester);
    expect(game.reduceMotion, isTrue);
    expect(game.config.gravity, plain.config.gravity); // fizik aynı
  });
}

// Kalan maddeler (docs/21 §8): bütün ekranlarda taşma ve metin kontrastı.
const _modals = [
  'profileButton', 'shopButton', 'discoveryButton', 'leaderboardButton', 'dailyButton',
  'eventsButton', 'missionsButton', 'achievementsButton', 'settingsButton', 'howToButton',
];

void sweepTests() {
  for (final (size, scale) in const [(Size(320, 568), 1.0), (Size(375, 667), 1.3)]) {
    testWidgets('ekran taraması: bütün ekranlar ${size.width.toInt()}×${size.height.toInt()} @$scale× taşmadan açılır', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (game, _) = await _pumpApp(tester, size: size);
      expect(tester.takeException(), isNull, reason: 'menü');
      for (final key in _modals) {
        await _tap(tester, key);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: key);
        if (key == 'eventsButton') {
          for (final tab in ['eventsTab_events', 'eventsTab_season']) {
            await _tap(tester, tab);
            await tester.pump(const Duration(milliseconds: 100));
            expect(tester.takeException(), isNull, reason: tab);
          }
        }
        game.closeModal();
        await tester.pump(const Duration(milliseconds: 16));
      }
      await _crashToGameOver(tester, game);
      expect(tester.takeException(), isNull, reason: 'oyun sonu');
    });
  }

  for (final size in const [Size(320, 568), Size(375, 667), Size(430, 932)]) {
    testWidgets('eğitim ekranı: "Eğitimi atla" logoya binmez, taşma yok (${size.width.toInt()}×${size.height.toInt()})', (tester) async {
      await _pumpApp(tester, size: size, ux: const UxState());
      final skip = tester.getRect(find.byKey(const Key('tutorialSkip')));
      final logo = tester.getRect(find.byType(LogoStamp).first);
      expect(skip.overlaps(logo), isFalse, reason: '$skip / $logo');
      expect(tester.getRect(find.byKey(const Key('readyPrompt'))).bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('kontrast: menü, eğitim ve oyun sonu metinleri WCAG eşiğini geçer', (tester) async {
    final handle = tester.ensureSemantics();
    final (game, _) = await _pumpApp(tester, ux: const UxState());
    await expectLater(tester, meetsGuideline(textContrastGuideline), reason: 'eğitim');
    game.skipTutorial();
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(tester, meetsGuideline(textContrastGuideline), reason: 'menü');
    await _crashToGameOver(tester, game);
    await expectLater(tester, meetsGuideline(textContrastGuideline), reason: 'oyun sonu');
    handle.dispose();
  });
}
