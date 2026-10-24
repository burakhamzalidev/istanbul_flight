import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/challenge/daily_challenge.dart';
import 'package:istanbul_flight/challenge/daily_state.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/progression/game_events.dart';

import 'fakes.dart';

// Phase 2.5: Günün Uçuşu oyun motorunda (tek motor, iki mod; docs/17 §2–§5).

final _day = DateTime.utc(2026, 10, 24, 10);

class _Recorder implements GameEventListener {
  final events = <String>[];
  @override
  void onGameEvent(GameEvent e) {
    switch (e) {
      case RunStarted(:final mode, :final challengeId):
        events.add('start:${mode.name}:$challengeId');
      case ObstaclePassed(:final score):
        events.add('pass:$score');
      case SimitCollected(:final runTotal):
        events.add('simit:$runTotal');
      case NearMissAchieved(:final runTotal):
        events.add('near:$runTotal');
      case ZoneReached(:final zoneIndex):
        events.add('zone:$zoneIndex');
      case RunFinished(:final result):
        events.add(
          'end:${result.score}:${result.flightMs}:${result.mode.name}:${result.challengeId}',
        );
      case RunAbandoned(:final runId):
        events.add('abandon:${runId.isNotEmpty}');
    }
  }
}

Future<(IstanbulFlightGame, TestServices, _Recorder, InMemoryScoreRepository)>
_make({int best = 0, int classicSeed = 7}) async {
  final t = TestServices(clock: () => _day);
  final rec = _Recorder();
  t.services.listeners.add(rec);
  final scores = InMemoryScoreRepository(best);
  final g = await initializeGame(
    () => IstanbulFlightGame(
      scores: scores,
      random: Random(classicSeed),
      pickupRandom: Random(classicSeed + 1),
      loadArt: false,
      services: t.services,
    ),
  );
  return (g, t, rec, scores);
}

Future<void> _ready(IstanbulFlightGame g, {Vector2? size}) async {
  g.onGameResize(size ?? Vector2(1080, 1920));
  await g.ready();
}

/// Otomatik pilotla (adım içinde karar verir: kare hızından bağımsız) çarpana kadar uçar.
void _flyUntilCrash(
  IstanbulFlightGame g, {
  double dt = 1 / 60,
  double max = 400,
}) {
  for (var t = 0.0; t < max && g.phase.value == GamePhase.playing; t += dt) {
    g.update(dt);
  }
}

/// Engel üretim sırası (yalnızca oynanış verisi).
List<String> _specs(IstanbulFlightGame g) => [
  for (final o in g.obstacles)
    '${o.gapCenter.toStringAsFixed(3)}/${o.gapHeight}/${o.pickupY?.toStringAsFixed(3)}',
];

Future<List<String>> _dailyRun({
  double dt = 1 / 60,
  Vector2? size,
  int classicSeed = 7,
}) async {
  final (g, _, rec, _) = await _make(classicSeed: classicSeed);
  await _ready(g, size: size);
  g.autopilot = true;
  g.startDaily(ranked: false);
  g.handleTap();
  final spawned = <String>[];
  for (var t = 0.0; t < 400 && g.phase.value == GamePhase.playing; t += dt) {
    g.update(dt);
    for (final s in _specs(g)) {
      if (!spawned.contains(s)) spawned.add(s);
    }
  }
  // dar ekranda öndeki engel daha geç doğar: karşılaştırma ulaşılan engellerle sınırlı
  return [...rec.events, 'specs:${spawned.take(12).join(',')}'];
}

void main() {
  group('Determinizm (oyun motoru)', () {
    test('30/60/120 FPS: aynı oynanış olayları (geçiş, simit, kıl payı, bölge, bitiş)', () async {
      final a = await _dailyRun(dt: 1 / 30);
      final b = await _dailyRun(dt: 1 / 60);
      final c = await _dailyRun(dt: 1 / 120);
      expect(a.where((e) => e.startsWith('pass:')).length, greaterThan(10));
      expect(b, a);
      expect(c, a);
    });

    test('ekran genişliği parkuru ve olayları değiştirmez (telefon, dar telefon, iPad)', () async {
      final phone = await _dailyRun(size: Vector2(1080, 1920));
      final narrow = await _dailyRun(size: Vector2(390, 844));
      final tablet = await _dailyRun(size: Vector2(1536, 2048));
      expect(narrow, phone);
      expect(tablet, phone);
    });

    test('görsel ve klasik rastgelelik günlük parkuru değiştirmez', () async {
      final a = await _dailyRun(classicSeed: 1);
      final b = await _dailyRun(classicSeed: 999);
      expect(b, a);
    });

    test(
      'oyundaki parkur tanımdaki parkurla aynı ve ilk engel mesafesi sabit',
      () async {
        final (g, t, _, _) = await _make();
        await _ready(g);
        g.debugInvincible = true;
        g.startDaily(ranked: false);
        g.handleTap();
        // kuş her ekranda aynı yerde; ilk engel 1,2 sn sonra doğar (sabit mesafe 1100, hız 340)
        expect(g.birdX, DailyCourse.birdX);
        var steps = 0;
        while (g.obstacles.isEmpty) {
          g.update(1 / 120);
          steps++;
        }
        final def = t.services.daily.today();
        final course = DailyCourse(def);
        expect(
          g.obstacles.first.position.x - g.birdX,
          closeTo(
            DailyCourse.firstObstacleDistance -
                steps * g.config.startSpeed / 120,
            0.01,
          ),
        );
        g.update(3);
        expect(g.obstacles.first.courseIndex, 0);
        for (final o in g.obstacles) {
          expect(o.gapCenter, course.at(o.courseIndex).gapCenter);
          expect(o.pickupY, course.at(o.courseIndex).pickupY);
          // konum parkur koordinatından: engeller tam aralıkla dizilir
          expect(
            o.position.x - g.obstacles.first.position.x,
            closeTo(o.courseIndex * course.spacing, 0.01),
          );
        }
      },
    );
  });

  group('Dereceli akış', () {
    test(
      'hak "Uçuşa başla"da değil, uçuş gerçekten başlayınca harcanır',
      () async {
        final (g, t, rec, _) = await _make();
        await _ready(g);
        g.startDaily(ranked: true);
        expect(g.phase.value, GamePhase.ready);
        expect(t.services.progress.value.dailyChallenge.records, isEmpty);
        g.openMenu(); // vazgeçti: hak harcanmadı
        expect(t.services.progress.value.dailyChallenge.records, isEmpty);
        g.startDaily(ranked: true);
        g.handleTap();
        final id = t.services.daily.today().challengeId;
        expect(t.services.progress.value.dailyChallenge[id]!.remaining, 2);
        expect(rec.events.first, 'start:dailyRanked:$id');
      },
    );

    test(
      'günlük uçuş klasik rekoru değiştirmez; günlük rekor ayrı tutulur',
      () async {
        final (g, t, rec, scores) = await _make(best: 3);
        await _ready(g);
        g.autopilot = true;
        g.startDaily(ranked: true);
        g.handleTap();
        _flyUntilCrash(g);
        expect(g.phase.value, GamePhase.gameOver);
        expect(g.score.value, greaterThan(3));
        expect(g.best.value, 3);
        expect(await scores.loadBest(), 3);
        expect(g.isNewRecord.value, isFalse);
        final o = t.services.progress.lastDaily.value!;
        expect(o.ranked, isTrue);
        expect(o.bestScore, g.score.value);
        expect(rec.events.last, startsWith('end:${g.score.value}:'));
        expect(rec.events.last, contains(':dailyRanked:daily_2026_10_24'));
      },
    );

    test(
      'duraklatıp ana menüye dönmek denemeyi "yarıda bırakıldı" yapar',
      () async {
        final (g, t, rec, _) = await _make();
        await _ready(g);
        g.debugInvincible = true;
        g.startDaily(ranked: true);
        g.handleTap();
        g.update(1);
        g.pauseGame();
        g.openMenu();
        final r = t.services.progress.value.dailyChallenge['daily_2026_10_24']!;
        expect(r.attempts.single.status, DailyAttemptStatus.abandoned);
        expect(rec.events, contains('abandon:true'));
        expect(g.runMode.value, RunMode.classic);
      },
    );

    test(
      'hak bitince dereceli başlatma antrenmana döner ve nedeni bildirilir',
      () async {
        final (g, t, _, _) = await _make();
        await _ready(g);
        for (var i = 0; i < 3; i++) {
          g.debugInvincible = false;
          g.startDaily(ranked: true);
          g.handleTap();
          _flyUntilCrash(g, max: 30);
          for (var k = 0; k < 120; k++) {
            g.update(1 / 60); // kart ve kilit süresi
          }
        }
        final id = t.services.daily.today().challengeId;
        expect(t.services.progress.value.dailyChallenge[id]!.remaining, 0);
        g.startDaily(ranked: true);
        g.handleTap();
        expect(g.runMode.value, RunMode.dailyPractice);
        expect(g.dailyNotice.value, DailyBeginResult.noAttempts);
        expect(t.services.progress.value.dailyChallenge[id]!.used, 3);
      },
    );

    test(
      'klasik mod: menüden "Uçmaya başla" her zaman klasik; davranış aynen',
      () async {
        final (g, _, rec, _) = await _make();
        await _ready(g);
        g.startDaily(ranked: false);
        g.openMenu();
        g.startFromMenu();
        g.handleTap();
        expect(g.runMode.value, RunMode.classic);
        expect(rec.events.first, 'start:classic:null');
      },
    );
  });
}
