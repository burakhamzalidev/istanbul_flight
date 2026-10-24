import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/challenge/daily_challenge.dart';
import 'package:istanbul_flight/challenge/daily_state.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/main.dart';
import 'package:istanbul_flight/services/game_center/game_center.dart';
import 'package:istanbul_flight/services/game_center/game_center_controller.dart';
import 'package:istanbul_flight/services/progress.dart';

import 'fakes.dart';
import 'game_center_fakes.dart';

// Phase 2.5: Günün Uçuşu arayüzü (docs/17 §10–§11).

final _day = DateTime.utc(2026, 10, 24, 9, 30);
final _id = DailyChallengeDefinition.idFor('2026-10-24');

Future<(IstanbulFlightGame, TestServices)> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  PlayerProgress progress = const PlayerProgress(),
  FakeGameCenterApi? api,
  DateTime? now,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final t = TestServices(
    progress: progress,
    clock: () => now ?? _day,
    gameCenter: api == null
        ? null
        : (p) => GameCenterController(
            api: api,
            store: InMemoryGameCenterStore(
              const GcRecord(legacyExported: true),
            ),
            progress: p,
            scores: InMemoryScoreRepository(),
            clock: () => now ?? _day,
          ),
  );
  final game = IstanbulFlightGame(
    scores: InMemoryScoreRepository(),
    random: Random(3),
    pickupRandom: Random(1),
    loadArt: false,
    services: t.services,
  );
  await tester.pumpWidget(MartiApp(game: game));
  if (api != null) await tester.runAsync(() => t.services.gameCenter.start());
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

String _text(WidgetTester tester, String key) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(Text),
        matchRoot: true,
      ),
    )
    .data!;

/// Bugünün dereceli haklarını tüketmiş profil.
PlayerProgress _exhausted({int best = 41}) => PlayerProgress(
  dailyChallenge: DailyChallengeState(
    records: {
      _id: DailyChallengeRecord(
        challengeId: _id,
        seed: 1,
        generatorVersion: 1,
        attempts: [
          const DailyAttempt(
            runId: 'a',
            status: DailyAttemptStatus.finished,
            score: 12,
          ),
          DailyAttempt(
            runId: 'b',
            status: DailyAttemptStatus.finished,
            score: best,
          ),
          const DailyAttempt(runId: 'c', status: DailyAttemptStatus.abandoned),
        ],
        bestScore: best,
        bestRunId: 'b',
        claimed: {
          DailyRewardPolicy.firstFlightKey,
          DailyRewardPolicy.scoreKey(15),
          DailyRewardPolicy.scoreKey(35),
        },
      ),
    },
    highWaterDay: '2026-10-24',
  ),
);

void main() {
  testWidgets(
    'menüde Günün Uçuşu girişi; ekran tarih, haklar, ödüller ve geri sayımı gösterir',
    (tester) async {
      final (game, _) = await _pumpApp(tester);
      expect(_text(tester, 'dailyMenuRemaining'), '3/3');
      await _tap(tester, 'dailyButton');
      expect(game.modal.value, Overlays.daily);
      expect(_text(tester, 'dailyDate'), '24 Ekim 2026');
      expect(_text(tester, 'dailyRemaining'), '3/3');
      expect(_text(tester, 'dailyBest'), '0');
      expect(_text(tester, 'dailyCountdown'), 'Yeni parkur: 14 sa 30 dk sonra');
      expect(find.byKey(const Key('dailyReward_first_flight')), findsOneWidget);
      expect(find.byKey(const Key('dailyReward_score_60')), findsOneWidget);
      expect(find.byKey(const Key('dailyStart')), findsOneWidget);
      expect(find.byKey(const Key('dailyBoardOffline')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Uçuşa başla: "uçmak için dokun" ekranında dereceli deneme 1/3; hak dokununca harcanır',
    (tester) async {
      final (game, t) = await _pumpApp(tester);
      await _tap(tester, 'dailyButton');
      await _tap(tester, 'dailyStart');
      expect(game.modal.value, isNull);
      expect(game.runMode.value, RunMode.dailyRanked);
      expect(_text(tester, 'dailyReadyText'), 'Dereceli deneme 1/3');
      expect(t.services.progress.value.dailyChallenge[_id], isNull);
      await tester.tapAt(const Offset(195, 600));
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.phase.value, GamePhase.playing);
      expect(t.services.progress.value.dailyChallenge[_id]!.remaining, 2);
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('haklar bitince: 0/3, bugünün en iyisi, Antrenman yap', (
    tester,
  ) async {
    final (game, _) = await _pumpApp(tester, progress: _exhausted());
    expect(_text(tester, 'dailyMenuRemaining'), '0/3');
    await _tap(tester, 'dailyButton');
    expect(_text(tester, 'dailyRemaining'), '0/3');
    expect(_text(tester, 'dailyBest'), '41');
    expect(find.byKey(const Key('dailyStart')), findsNothing);
    expect(find.byKey(const Key('dailyDone')), findsOneWidget);
    await _tap(tester, 'dailyPractice');
    expect(game.runMode.value, RunMode.dailyPractice);
    expect(_text(tester, 'dailyReadyText'), 'Antrenman · sıralamaya sayılmaz');
  });

  testWidgets('cihaz tarihi geri alınmışsa uyarı ve yalnızca antrenman', (
    tester,
  ) async {
    final p = PlayerProgress(
      dailyChallenge: const DailyChallengeState(highWaterDay: '2026-10-26'),
    );
    await _pumpApp(tester, progress: p);
    await _tap(tester, 'dailyButton');
    expect(find.byKey(const Key('dailyClockWarning')), findsOneWidget);
    expect(find.byKey(const Key('dailyStart')), findsNothing);
    expect(find.byKey(const Key('dailyPractice')), findsOneWidget);
  });

  testWidgets(
    'Game Center bağlı: günlük dünya sıralaması; internet yoksa anlaşılır hata',
    (tester) async {
      final api = FakeGameCenterApi()
        ..dayStart = DateTime.utc(2026, 10, 24)
        ..page = GcBoardPage(
          total: 87,
          entries: const [
            GcEntry(rank: 1, alias: 'Martı Kaptan', score: 64),
            GcEntry(rank: 2, alias: 'Simit42', score: 41, isLocal: true),
          ],
          local: const GcEntry(
            rank: 2,
            alias: 'Simit42',
            score: 41,
            isLocal: true,
          ),
          occurrenceEnd: DateTime.utc(2026, 10, 25),
        );
      final (_, t) = await _pumpApp(tester, api: api);
      await _tap(tester, 'dailyButton');
      await tester.runAsync(() async {});
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Simit42 (sen)'), findsOneWidget);
      expect(find.text('87 oyuncu'), findsOneWidget);
      expect(find.byKey(const Key('dailyBoardEnds')), findsOneWidget);
      expect(t.services.daily.trustedDay, '2026-10-24');
      api.offline = true;
      await _tap(tester, 'dailyScopeFriends');
      await tester.runAsync(() async {});
      await tester.pump(const Duration(milliseconds: 50));
      expect(_text(tester, 'boardError').contains('internet'), isTrue);
    },
  );

  testWidgets('VoiceOver: giriş ve haklar okunur', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpApp(tester);
    expect(
      find.bySemanticsLabel(RegExp(r'Günün Uçuşu, 3 / 3 dereceli hak')),
      findsOneWidget,
    );
    await _tap(tester, 'dailyButton');
    expect(
      find.bySemanticsLabel(RegExp('UÇUŞA BAŞLA', caseSensitive: false)),
      findsWidgets,
    );
    handle.dispose();
  });

  testWidgets(
    'günlük oyun sonu: günlük skor paneli, kalan hak, yeniden dene; kartpostal Günün Uçuşu',
    (tester) async {
      final (game, t) = await _pumpApp(tester);
      await _tap(tester, 'dailyButton');
      await _tap(tester, 'dailyStart');
      await tester.tapAt(const Offset(195, 600));
      for (var i = 0; i < 260; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(game.phase.value, GamePhase.gameOver);
      expect(find.byKey(const Key('dailyResult')), findsOneWidget);
      expect(_text(tester, 'dailyResultRemaining'), 'Kalan hak: 2');
      expect(find.byKey(const Key('dailyRetry')), findsOneWidget);
      expect(
        _text(tester, 'postcardFooter'),
        contains('Günün Uçuşu · 24 Ekim 2026'),
      );
      expect(
        find.text('EN İYİ'),
        findsOneWidget,
      ); // günün en iyisi (dar sütunda tek satır)
      expect(
        _text(tester, 'dailyResultRank'),
        contains('Game Center bağlı değil'),
      );
      // yeniden dene: yine dereceli, ikinci deneme
      await _tap(tester, 'dailyRetry');
      expect(game.runMode.value, RunMode.dailyRanked);
      expect(_text(tester, 'dailyReadyText'), 'Dereceli deneme 2/3');
      expect(t.services.progress.value.dailyChallenge[_id]!.used, 1);
    },
  );

  for (final size in const [Size(320, 568), Size(375, 667), Size(430, 932)]) {
    testWidgets(
      'iPhone ${size.width.toInt()}×${size.height.toInt()}: menü, günlük ekran ve oyun sonu taşmaz',
      (tester) async {
        final (game, _) = await _pumpApp(
          tester,
          size: size,
          progress: _exhausted(),
        );
        expect(tester.takeException(), isNull, reason: 'menü');
        await _tap(tester, 'dailyButton');
        await tester.ensureVisible(find.byKey(const Key('dailyRuleNote')));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'günlük ekran');
        await _tap(tester, 'dailyPractice');
        await tester.tapAt(Offset(size.width / 2, size.height * 0.7));
        for (var i = 0; i < 260; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(game.phase.value, GamePhase.gameOver);
        expect(find.byKey(const Key('dailyResult')), findsOneWidget);
        expect(find.byKey(const Key('dailyPracticeAgain')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'oyun sonu');
      },
    );
  }
}
