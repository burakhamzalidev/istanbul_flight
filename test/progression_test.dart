import 'dart:convert';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/game_services.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/progression/achievements.dart';
import 'package:istanbul_flight/progression/game_events.dart';
import 'package:istanbul_flight/progression/missions.dart';
import 'package:istanbul_flight/progression/progression_config.dart';
import 'package:istanbul_flight/progression/run_settlement.dart';
import 'package:istanbul_flight/services/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

final _now = DateTime(2026, 10, 22, 14);
const _day = '2026-10-22';

RunResult _run({
  String id = 'r1',
  int score = 0,
  int? obstacles,
  int simits = 0,
  int near = 0,
  int zone = 0,
  int ms = 5000,
}) => RunResult(
  runId: id,
  score: score,
  obstaclesPassed: obstacles ?? score,
  simits: simits,
  nearMisses: near,
  maxZone: zone,
  flightMs: ms,
);

/// Bugünün görevleri tamamlanamayacak hedeflerle sabitlenmiş profil (XP'yi izole etmek için).
PlayerProgress _quietDay([PlayerProgress p = const PlayerProgress()]) =>
    p.copyWith(
      daily: const DailyMissions(
        dayKey: _day,
        missions: [
          DailyMission(
            kind: MissionKind.totalScore,
            target: 100000,
            rewardXp: 30,
            rewardSimits: 5,
          ),
        ],
      ),
    );

class _RecordingListener implements GameEventListener {
  final events = <GameEvent>[];
  @override
  void onGameEvent(GameEvent event) => events.add(event);
}

class _FlakyRepo implements ProgressRepository {
  int failuresLeft = 1;
  PlayerProgress? saved;

  @override
  Future<PlayerProgress> load() async => saved ?? const PlayerProgress();

  @override
  Future<void> save(PlayerProgress p) async {
    if (failuresLeft > 0) {
      failuresLeft--;
      throw Exception('disk dolu');
    }
    saved = p;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Seviye eğrisi', () {
    test('sınırlar: 60 XP ile 2. seviye, sonra 80, 100...', () {
      expect(LevelInfo.fromXp(0).level, 1);
      final a = LevelInfo.fromXp(59);
      expect(
        (a.level, a.xpIntoLevel, a.xpForNext, a.xpRemaining),
        (1, 59, 60, 1),
      );
      final b = LevelInfo.fromXp(60);
      expect((b.level, b.xpIntoLevel, b.xpForNext), (2, 0, 80));
      expect(ProgressionConfig.xpToReach(3), 140);
      expect(LevelInfo.fromXp(ProgressionConfig.xpToReach(10)).level, 10);
      expect(LevelInfo.fromXp(-10).level, 1, reason: 'negatif XP 1. seviye');
    });

    test('en üst seviye ve taşma: seviye 50\'de durur, çubuk dolu', () {
      final max = LevelInfo.fromXp(ProgressionConfig.maxTotalXp * 10);
      expect(max.level, ProgressionConfig.maxLevel);
      expect(max.isMax, isTrue);
      expect(max.fraction, 1);
      expect(max.xpRemaining, 0);
    });
  });

  group('Uçuş XP hesabı', () {
    test('engel 2, simit 3, kıl payı 5, yeni bölge 25 XP', () {
      final s = settleRun(
        _quietDay(),
        _run(score: 16, simits: 4, near: 2, zone: 1),
        _now,
      )!;
      expect(s.summary.xpObstacles, 32);
      expect(s.summary.xpSimits, 12);
      expect(s.summary.xpNearMisses, 10);
      expect(s.summary.xpZones, 25, reason: 'Galata ilk keşif; Haliç sayılmaz');
      expect(s.summary.xpRun, 79);
      expect(
        s.progress.xp,
        s.summary.xpTotal,
        reason: 'profil XP = özetteki toplam (başarımlar dahil)',
      );
      expect(s.summary.newZones, [1]);
    });

    test('demo başlangıç skoru XP vermez: XP geçilen engelden hesaplanır', () {
      final s = settleRun(_quietDay(), _run(score: 60, obstacles: 2), _now)!;
      expect(s.summary.xpObstacles, 4);
    });

    test('tek uçuş XP üst sınırı ve toplam XP taşma koruması', () {
      final s = settleRun(
        _quietDay(),
        _run(score: 100000, simits: 100000, near: 100000),
        _now,
      )!;
      expect(s.summary.xpRun, ProgressionConfig.maxRunXp);
      final nearMax = _quietDay(
        const PlayerProgress(xp: ProgressionConfig.maxTotalXp - 5),
      );
      final t = settleRun(nearMax, _run(score: 50), _now)!;
      expect(t.progress.xp, ProgressionConfig.maxTotalXp);
      expect(t.progress.level, ProgressionConfig.maxLevel);
    });

    test('negatif / bozuk uçuş değerleri sıfıra düşer', () {
      final s = settleRun(
        _quietDay(),
        _run(score: -5, obstacles: -1, simits: -3, near: -2, zone: 99, ms: -1),
        _now,
      )!;
      expect(s.progress.totalScore, 0);
      expect(s.progress.totalSimits, 0);
      expect(s.progress.longestFlightMs, 0);
      expect(s.progress.maxZone, 4, reason: 'bölge sırası sınırlanır');
    });

    test('XP oyun fiziğini değiştirmez (ayarlar sabit)', () async {
      final t = TestServices(progress: const PlayerProgress(xp: 999999));
      final g = IstanbulFlightGame(
        scores: InMemoryScoreRepository(),
        loadArt: false,
        services: t.services,
      );
      expect(g.config.gravity, 2600);
      expect(g.config.speedForScore(10), g.config.startSpeed + 25);
    });
  });

  group('Uçuş istatistikleri ve bölge keşfi', () {
    test('sayaçlar toplanır, en uzun uçuş tutulur, bölge XP\'si yalnızca ilk keşifte', () {
      var p = _quietDay();
      p = settleRun(
        p,
        _run(id: 'a', score: 20, simits: 3, near: 1, zone: 1, ms: 9000),
        _now,
      )!.progress;
      final s2 = settleRun(
        p,
        _run(id: 'b', score: 5, simits: 2, zone: 1, ms: 4000),
        _now,
      )!;
      p = s2.progress;
      expect(s2.summary.xpZones, 0, reason: 'Galata zaten keşfedildi');
      expect(p.flights, 2);
      expect(p.totalScore, 25);
      expect(p.totalObstacles, 25);
      expect(p.totalSimits, 5);
      expect(p.bestRunSimits, 3);
      expect(p.totalNearMisses, 1);
      expect(p.longestFlightMs, 9000);
      expect(p.discoveredZones, {0, 1});
      final s3 = settleRun(p, _run(id: 'c', score: 95, zone: 4), _now)!;
      expect(s3.summary.newZones, [2, 3, 4]);
      expect(s3.summary.xpZones, 75);
    });
  });

  group('Çift kayıt engelleme (idempotent hesap)', () {
    test('aynı runId ikinci kez hesaplanmaz', () {
      final s = settleRun(_quietDay(), _run(score: 10, simits: 2), _now)!;
      expect(settleRun(s.progress, _run(score: 10, simits: 2), _now), isNull);
    });

    test('kimliksiz uçuş hesaplanmaz', () {
      expect(settleRun(_quietDay(), _run(id: ''), _now), isNull);
    });

    test('hatırlanan uçuş listesi sınırlı kalır', () {
      var p = _quietDay();
      for (var i = 0; i < ProgressionConfig.settledRunMemory + 20; i++) {
        p = settleRun(p, _run(id: 'run$i'), _now)!.progress;
      }
      expect(p.settledRuns.length, ProgressionConfig.settledRunMemory);
      expect(
        p.settledRuns.last,
        'run${ProgressionConfig.settledRunMemory + 19}',
      );
    });

    test('ProgressController: tekrar gelen RunFinished profil ve kaydı değiştirmez', () async {
      final repo = InMemoryProgressRepository();
      final c = ProgressController(repo, _quietDay(), clock: () => _now);
      c.onGameEvent(RunFinished(_run(score: 10, simits: 2)));
      c.onGameEvent(RunFinished(_run(score: 10, simits: 2)));
      await c.flush();
      expect(c.value.flights, 1);
      expect(c.value.totalSimits, 2);
      expect(repo.saveCount, 1);
      expect(c.lastRun.value, isNotNull);
      c.onGameEvent(const RunStarted('r2'));
      expect(c.lastRun.value, isNull, reason: 'yeni uçuşta eski özet gizlenir');
    });

    test('oyun: bir uçuşta tek RunFinished; olaylar sırayla gelir', () async {
      final t = TestServices();
      final rec = _RecordingListener();
      t.services.listeners.add(rec);
      final g = await initializeGame(
        () => IstanbulFlightGame(
          scores: InMemoryScoreRepository(),
          random: Random(7),
          pickupRandom: Random(3),
          loadArt: false,
          services: t.services,
        ),
      );
      g.onGameResize(Vector2(1080, 1920));
      await g.ready();
      g.debugInvincible = true;
      g.autopilot = true;
      g.handleTap();
      while (g.score.value < 16) {
        g.update(1 / 60);
      }
      g.debugInvincible = false;
      g.autopilot = false;
      g.physics.y = g.config.worldHeight;
      for (var i = 0; i < 200; i++) {
        g.update(1 / 60); // oyun sonu animasyonu: tekrar hesap olmamalı
      }
      expect(g.phase.value, GamePhase.gameOver);
      final e = rec.events;
      expect(e.first, isA<RunStarted>());
      expect(e.last, isA<RunFinished>());
      expect(e.whereType<RunFinished>().length, 1);
      expect(e.whereType<ObstaclePassed>().length, 16);
      expect(e.whereType<ZoneReached>().map((z) => z.zoneIndex), [
        1,
      ], reason: '15 puanda Galata');
      final r = e.whereType<RunFinished>().single.result;
      expect(r.score, 16);
      expect(r.maxZone, 1);
      expect(r.flightMs, greaterThan(0));
      await t.services.progress.flush();
      final p = t.services.progress.value;
      expect(p.flights, 1);
      expect(p.discoveredZones, {0, 1});
      expect((await t.progressRepo.load()).flights, 1);
      expect(
        p.achievements.keys,
        containsAll(['first_flap', 'galata_explorer']),
      );
      g.onRemove();
    });
  });

  group('Günlük görevler', () {
    test(
      'günde 3 farklı görev; aynı gün aynı görevler; gün değişince yenilenir',
      () {
        final a = DailyMissions.generate(_day, level: 5);
        final b = DailyMissions.generate(_day, level: 5);
        expect(a.missions.length, 3);
        expect(a.missions.map((m) => m.kind).toSet().length, 3);
        expect(a.missions.map((m) => m.kind), b.missions.map((m) => m.kind));
        final p = ensureDaily(const PlayerProgress(), _now);
        expect(p.daily!.dayKey, _day);
        expect(
          identical(ensureDaily(p, _now.add(const Duration(hours: 9))), p),
          isTrue,
        );
        final next = ensureDaily(p, DateTime(2026, 10, 23, 0, 1));
        expect(next.daily!.dayKey, '2026-10-23');
      },
    );

    test('yeni oyuncu: kolay hedefler, bölge görevi yok', () {
      for (var d = 1; d <= 28; d++) {
        final m = DailyMissions.generate(
          '2026-11-${d.toString().padLeft(2, '0')}',
          level: 1,
        );
        expect(m.missions.any((x) => x.kind == MissionKind.reachZone), isFalse);
        for (final x in m.missions) {
          final t = MissionCatalog.templates.firstWhere(
            (t) => t.kind == x.kind,
          );
          expect(x.target, t.targets[0]);
        }
      }
    });

    test('ilerleme türe göre: toplam, en iyi tur, bölge; hedefte durur', () {
      const r = RunResult(
        runId: 'x',
        score: 12,
        obstaclesPassed: 12,
        simits: 4,
        nearMisses: 3,
        maxZone: 1,
        flightMs: 1,
      );
      DailyMission m(MissionKind k, int target, [int progress = 0]) =>
          DailyMission(
            kind: k,
            target: target,
            rewardXp: 1,
            rewardSimits: 1,
            progress: progress,
          ).advance(r);
      expect(m(MissionKind.collectSimits, 10, 3).progress, 7);
      expect(m(MissionKind.nearMisses, 2).progress, 2, reason: 'hedefte durur');
      expect(m(MissionKind.flights, 3, 1).progress, 2);
      expect(
        m(MissionKind.singleRunScore, 20, 15).progress,
        15,
        reason: 'en iyi tur',
      );
      expect(m(MissionKind.reachZone, 2).completed, isFalse);
      expect(m(MissionKind.reachZone, 1).completed, isTrue);
      expect(m(MissionKind.totalScore, 100, 50).progress, 62);
    });

    test('ödül bir kez: tamamlanan görev sonraki uçuşlarda ve tarih geri alınınca tekrar ödül vermez', () {
      const day = DailyMissions(
        dayKey: _day,
        missions: [
          DailyMission(
            kind: MissionKind.flights,
            target: 2,
            rewardXp: 30,
            rewardSimits: 5,
          ),
        ],
      );
      var p = const PlayerProgress().copyWith(daily: day);
      p = settleRun(p, _run(id: '1'), _now)!.progress;
      expect(p.missionsCompleted, 0);
      final s2 = settleRun(p, _run(id: '2'), _now)!;
      expect(s2.summary.completedMissions.single.kind, MissionKind.flights);
      expect(s2.summary.xpMissions, 30);
      p = s2.progress;
      final bonus = p.bonusSimits;
      final s3 = settleRun(p, _run(id: '3'), _now)!;
      expect(s3.summary.completedMissions, isEmpty);
      expect(s3.progress.missionsCompleted, 1);
      expect(s3.progress.bonusSimits, bonus);

      // Cihaz tarihi ertesi güne alınıp geri getirilir: aynı gün aynı görev yeniden ödül vermez
      p = ensureDaily(s3.progress, DateTime(2026, 10, 23, 9));
      p = p.copyWith(
        daily: day,
      ); // 22 Ekim'in görevleri sıfır ilerlemeyle yeniden kuruldu
      p = settleRun(p, _run(id: '4'), _now)!.progress;
      final s5 = settleRun(p, _run(id: '5'), _now)!;
      expect(
        s5.summary.completedMissions,
        isEmpty,
        reason: 'ödül defteri: $_day:flights',
      );
      expect(s5.progress.missionsCompleted, 1);
    });

    test('gün anahtarı ve yenilenmeye kalan süre (yerel saat)', () {
      expect(dayKeyFor(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
      expect(dayKeyFor(DateTime(2026, 1, 6, 0, 0)), '2026-01-06');
      expect(untilNextDay(DateTime(2026, 1, 5, 23)), const Duration(hours: 1));
      expect(isDayKey('2026-01-05'), isTrue);
      expect(isDayKey('dün'), isFalse);
    });

    test('ProgressController.refreshDay: aynı gün kayıt yok, gece yarısından sonra yeni görevler', () async {
      var clock = DateTime(2026, 10, 22, 23, 50);
      final repo = InMemoryProgressRepository();
      final c = ProgressController(
        repo,
        const PlayerProgress(),
        clock: () => clock,
      );
      c.refreshDay();
      c.refreshDay();
      await c.flush();
      expect(repo.saveCount, 1);
      expect(c.value.daily!.dayKey, '2026-10-22');
      clock = DateTime(2026, 10, 23, 0, 5);
      c.refreshDay();
      await c.flush();
      expect(c.value.daily!.dayKey, '2026-10-23');
      expect(repo.saveCount, 2);
    });
  });

  group('Başarımlar', () {
    test('veri odaklı tanımlar: benzersiz kimlik, pozitif hedef', () {
      expect(
        achievementDefs.map((a) => a.id).toSet().length,
        achievementDefs.length,
      );
      expect(achievementDefs.every((a) => a.target > 0), isTrue);
      expect(achievementById('first_flap')!.title, 'İlk Kanat Çırpışı');
      expect(achievementById('yok'), isNull);
    });

    test('ilk uçuşta açılır, ödül bir kez verilir, tarih kaydedilir', () {
      final s1 = settleRun(_quietDay(), _run(id: 'a'), _now)!;
      expect(s1.summary.unlockedAchievements.map((a) => a.id), ['first_flap']);
      expect(s1.summary.xpAchievements, 10);
      expect(s1.progress.achievements['first_flap'], _now);
      expect(s1.progress.bonusSimits, 5);
      final s2 = settleRun(s1.progress, _run(id: 'b'), _now)!;
      expect(s2.summary.unlockedAchievements, isEmpty);
      expect(s2.progress.bonusSimits, 5);
    });

    test('ilerleme hedefte durur; kademeli başarımlar ayrı ayrı açılır', () {
      const p = PlayerProgress(totalSimits: 250, flights: 3);
      final hunter = achievementById('simit_hunter')!;
      expect(hunter.progressIn(p), 100);
      expect(hunter.fractionIn(p), 1);
      final loyal = achievementById('loyal_gull')!;
      expect(loyal.fractionIn(p), closeTo(3 / 25, 1e-9));
      final (after, unlocked) = unlockAchievements(p, _now);
      expect(
        unlocked.map((a) => a.id),
        containsAll(['first_flap', 'simit_hunter']),
      );
      expect(unlocked.map((a) => a.id), isNot(contains('loyal_gull')));
      final (_, again) = unlockAchievements(after, _now);
      expect(again, isEmpty);
    });
  });

  group('Simit bakiyesi', () {
    test('negatife düşmez; yetersiz bakiyede harcama reddedilir', () {
      final p = PlayerProgress.fromJson({
        'totalSimits': 10,
        'spentSimits': 999,
      });
      expect(p.simitBalance, 0);
      const q = PlayerProgress(totalSimits: 2, bonusSimits: 1);
      expect(q.simitBalance, 3);
      expect(q.trySpend(4), isNull);
      expect(q.trySpend(-1), isNull);
      expect(q.trySpend(3)!.simitBalance, 0);
    });
  });

  group('Kayıt: geçiş, bozuk veri, yarıda kalan kayıt', () {
    test(
      '1.0.0 kaydı (progress_v1 + best_score_v1) korunarak v2\'ye geçer',
      () async {
        final v1 = jsonEncode({
          'v': 1,
          'totalSimits': 37,
          'bestRunSimits': 6,
          'unlockedCosmetics': ['classic'],
          'selectedCosmetic': 'classic',
        });
        SharedPreferences.setMockInitialValues({
          'progress_v1': v1,
          'best_score_v1': 40,
          'settings_v1': '{"muted":true}',
        });
        final prefs = await SharedPreferences.getInstance();
        final p = await SharedPrefsProgressRepository(prefs).load();
        expect(p.totalSimits, 37, reason: 'simitler korunur');
        expect(p.bestRunSimits, 6);
        expect(p.discoveredZones, {
          0,
          1,
          2,
        }, reason: 'rekor 40 → Kız Kulesi\'ne ulaşılmış');
        expect(p.xp, 50, reason: 'iki bölgenin keşif XP\'si');
        expect(p.flights, 0);
        expect(
          prefs.getString('progress_v1'),
          v1,
          reason: 'eski kayıt değişmez',
        );
        expect(
          prefs.getInt('best_score_v1'),
          40,
          reason: 'rekor aynı anahtarda',
        );
        expect(prefs.getString('settings_v1'), '{"muted":true}');
        expect(prefs.getString(SharedPrefsProgressRepository.key), isNotNull);
        // ikinci açılış v2'den okur, geçiş tekrar yapılmaz
        final again = await SharedPrefsProgressRepository(prefs).load();
        expect(again.toJson(), p.toJson());
      },
    );

    test('yeni kurulum: kayıt yok → boş profil, gereksiz yazma yok', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final p = await SharedPrefsProgressRepository(prefs).load();
      expect(p.xp, 0);
      expect(p.discoveredZones, isEmpty);
      expect(prefs.getString(SharedPrefsProgressRepository.key), isNull);
    });

    test('bozuk v2 → ham kopya yedeklenir, v1\'den kurtarılır', () async {
      SharedPreferences.setMockInitialValues({
        'progress_v2': '{bozuk json',
        'progress_v1': '{"v":1,"totalSimits":12}',
        'best_score_v1': 3,
      });
      final prefs = await SharedPreferences.getInstance();
      final p = await SharedPrefsProgressRepository(prefs).load();
      expect(p.totalSimits, 12);
      expect(
        prefs.getString(SharedPrefsProgressRepository.corruptBackupKey),
        '{bozuk json',
      );
    });

    test(
      'eksik / yanlış türde alanlar varsayılana düşer, sağlam alanlar korunur',
      () {
        final p = PlayerProgress.fromJson({
          'v': 2,
          'totalSimits': 8,
          'xp': 'çok',
          'flights': -3,
          'discoveredZones': [0, 1, 'iki', 9, -1],
          'daily': {'day': 'dün', 'missions': []},
          'achievements': {
            'first_flap': 'tarih değil',
            'galata_explorer': '2026-10-21T10:00:00.000Z',
            'x': 5,
          },
          'rewardedMissions': ['2026-10-21:flights', 3],
          'settledRuns': 'liste değil',
        });
        expect(p.totalSimits, 8);
        expect(p.xp, 0);
        expect(p.flights, 0);
        expect(p.discoveredZones, {0, 1});
        expect(p.daily, isNull);
        expect(p.achievements.keys, ['galata_explorer']);
        expect(p.rewardedMissions, ['2026-10-21:flights']);
        expect(p.settledRuns, isEmpty);
      },
    );

    test('bozuk görev kaydı: tanınmayan görev atlanır, diğerleri kalır', () {
      final d = DailyMissions.fromJson({
        'day': _day,
        'missions': [
          {'kind': 'uçan_halı', 'target': 3},
          {
            'kind': 'flights',
            'target': 3,
            'progress': 9,
            'rewardXp': 30,
            'rewardSimits': 5,
          },
        ],
      })!;
      expect(d.missions.single.kind, MissionKind.flights);
      expect(d.missions.single.progress, 3, reason: 'ilerleme hedefle sınırlı');
    });

    test('tam tur: toJson → fromJson aynı profili verir', () {
      final s = settleRun(
        const PlayerProgress(totalSimits: 4),
        _run(score: 40, simits: 5, near: 3, zone: 2),
        _now,
      )!;
      final back = PlayerProgress.fromJson(
        jsonDecode(jsonEncode(s.progress.toJson())) as Map<String, Object?>,
      );
      expect(back.toJson(), s.progress.toJson());
    });

    test('kayıt sırasında hata (ör. uygulama kapanması / disk): oyun durmaz, sonraki kayıt güncel durumu yazar', () async {
      final repo = _FlakyRepo();
      final c = ProgressController(repo, _quietDay(), clock: () => _now);
      c.settle(_run(id: 'a', simits: 2));
      await c.flush();
      expect(
        repo.saved,
        isNull,
        reason: 'ilk yazma başarısız; eski kayıt geçerli kalır',
      );
      expect(c.value.totalSimits, 2);
      c.settle(_run(id: 'b', simits: 1));
      await c.flush();
      expect(repo.saved!.totalSimits, 3);
      expect(repo.saved!.settledRuns, ['a', 'b']);
    });
  });
}
