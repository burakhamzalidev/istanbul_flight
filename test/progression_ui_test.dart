import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/main.dart';
import 'package:istanbul_flight/services/progress.dart';
import 'package:istanbul_flight/ui/overlays/postcard_overlay.dart';

import 'fakes.dart';

Future<(IstanbulFlightGame, TestServices)> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  PlayerProgress progress = const PlayerProgress(),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final t = TestServices(progress: progress);
  t.services.progress.refreshDay();
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

Future<void> _open(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> _close(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('closeModal')));
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('ana menü: seviye, görev ve başarım şeridi; bakiye', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      progress: const PlayerProgress(xp: 70, totalSimits: 10, bonusSimits: 5),
    );
    expect(find.text('SV 2'), findsOneWidget);
    expect(find.text('Görev 0/3'), findsOneWidget);
    expect(find.text('0/9'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('totalSimits'))).data,
      '15',
      reason: 'menüdeki simit = harcanabilir bakiye (uçuş + ödül)',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'profil: seviye, XP çubuğu, bakiye, istatistikler; başarımlara geçiş',
    (tester) async {
      final (game, _) = await _pumpApp(
        tester,
        progress: const PlayerProgress(
          xp: 150,
          flights: 12,
          totalScore: 210,
          totalSimits: 40,
          totalNearMisses: 9,
          discoveredZones: {0, 1, 2},
          longestFlightMs: 65000,
          missionsCompleted: 2,
        ),
      );
      await _open(tester, 'profileButton');
      expect(game.modal.value, Overlays.profile);
      expect(
        tester.widget<Text>(find.byKey(const Key('profileLevel'))).data,
        '3',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('profileXp'))).data,
        '10 / 100 XP',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('profileBalance'))).data,
        '40',
      );
      expect(find.text('1 dk 05 sn'), findsOneWidget);
      expect(find.text('3/5'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('openAchievements')));
      await tester.tap(find.byKey(const Key('openAchievements')));
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.modal.value, Overlays.achievements);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'günlük görevler: üç görev, ilerleme, yenilenme süresi; geri tuşu kapatır',
    (tester) async {
      final (game, _) = await _pumpApp(tester);
      await _open(tester, 'missionsButton');
      expect(find.byKey(const Key('mission0')), findsOneWidget);
      expect(find.byKey(const Key('mission1')), findsOneWidget);
      expect(find.byKey(const Key('mission2')), findsOneWidget);
      expect(find.byKey(const Key('missionsRefresh')), findsOneWidget);
      expect(game.handleBack(), isTrue);
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.modal.value, isNull);
      expect(find.byKey(const Key('mission0')), findsNothing);
    },
  );

  testWidgets('başarımlar: kilitli ve açık rozetler, sayaç', (tester) async {
    await _pumpApp(
      tester,
      progress: PlayerProgress(
        flights: 1,
        achievements: {'first_flap': DateTime(2026, 10, 21, 12)},
      ),
    );
    await _open(tester, 'achievementsButton');
    expect(
      tester.widget<Text>(find.byKey(const Key('achievementCount'))).data,
      '1 / 9 rozet',
    );
    expect(find.textContaining('Kazanıldı: 21.10.2026'), findsOneWidget);
    expect(
      find.byKey(const Key('achievement_istanbul_conqueror')),
      findsOneWidget,
    );
    await _close(tester);
  });

  testWidgets(
    'oyun sonu: XP özeti kartpostalın dışında; kartpostal kompozisyonu aynı',
    (tester) async {
      final (game, t) = await _pumpApp(tester);
      await tester.tap(find.byKey(const Key('startButton')));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tapAt(const Offset(195, 600));
      for (var i = 0; i < 260; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(game.phase.value, GamePhase.gameOver);
      expect(find.byKey(const Key('runSummary')), findsOneWidget);
      expect(find.byKey(const Key('runXp')), findsOneWidget);
      expect(find.textContaining('Başarım: İlk Kanat Çırpışı'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Postcard),
          matching: find.byKey(const Key('runSummary')),
        ),
        findsNothing,
        reason: 'paylaşılan görsel değişmez',
      );
      expect(t.services.progress.value.flights, 1);
      // Tekrar uç → özet gizlenir
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.byKey(const Key('restartButton')));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tapAt(const Offset(195, 600));
      await tester.pump(const Duration(milliseconds: 16));
      expect(t.services.progress.lastRun.value, isNull);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 100));
    },
  );

  for (final size in const [Size(320, 568), Size(375, 667), Size(430, 932)]) {
    testWidgets(
      'küçük/büyük iPhone ${size.width.toInt()}×${size.height.toInt()}: yeni ekranlar taşmaz',
      (tester) async {
        await _pumpApp(
          tester,
          size: size,
          progress: const PlayerProgress(
            xp: 99999,
            flights: 9999,
            totalScore: 999999,
            totalSimits: 99999,
            discoveredZones: {0, 1, 2, 3, 4},
            longestFlightMs: 3599000,
          ),
        );
        expect(tester.takeException(), isNull);
        for (final key in [
          'profileButton',
          'missionsButton',
          'achievementsButton',
        ]) {
          await _open(tester, key);
          expect(tester.takeException(), isNull, reason: key);
          await _close(tester);
        }
      },
    );
  }
}
