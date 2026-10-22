import 'dart:convert';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/day_cycle.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/game_services.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/progression/cosmetics.dart';
import 'package:istanbul_flight/progression/discovery.dart';
import 'package:istanbul_flight/progression/game_events.dart';
import 'package:istanbul_flight/progression/missions.dart';
import 'package:istanbul_flight/progression/run_settlement.dart';
import 'package:istanbul_flight/services/progress.dart';
import 'package:istanbul_flight/ui/overlays/discovery_overlays.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

final _now = DateTime(2026, 10, 23, 15);
const _day = '2026-10-23';

/// Bölge istatistikli uçuş. [stats]: bölge → (engel, simit, kıl payı).
RunResult _run({
  String id = 'r1',
  int score = 0,
  int zone = 0,
  Map<int, (int, int, int)> stats = const {},
}) {
  final zs = {
    for (final e in stats.entries)
      e.key: ZoneRunStats(
        obstacles: e.value.$1,
        simits: e.value.$2,
        nearMisses: e.value.$3,
      ),
  };
  return RunResult(
    runId: id,
    score: score,
    obstaclesPassed: zs.values.fold(0, (a, s) => a + s.obstacles),
    simits: zs.values.fold(0, (a, s) => a + s.simits),
    nearMisses: zs.values.fold(0, (a, s) => a + s.nearMisses),
    maxZone: zone,
    flightMs: 5000,
    zoneStats: zs,
  );
}

/// Günlük görevleri ve başarımları sabitler: keşif ödüllerini izole etmek için.
PlayerProgress _quiet([PlayerProgress p = const PlayerProgress()]) =>
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
      achievements: {
        for (final id in [
          'first_flap',
          'galata_explorer',
          'simit_hunter',
          'loyal_gull',
          'bosphorus_traveler',
          'near_miss_master',
          'daily_wanderer',
          'night_flight',
          'istanbul_conqueror',
        ])
          id: _now,
      },
    );

Settlement _settle(PlayerProgress p, RunResult r, [DateTime? at]) =>
    settleRun(p, r, at ?? _now)!;

int _reward(String id) => discoveryGoalById(id)!.rewardSimits;

/// Bütün hedefleri tamamlayan tek uçuş (rozetler + albüm ödülü).
RunResult _perfectRun(String id) => _run(
  id: id,
  score: 120,
  zone: 4,
  stats: {
    0: (15, 6, 0),
    1: (20, 3, 4),
    2: (25, 12, 0),
    3: (30, 2, 6),
    4: (30, 9, 0),
  },
);

void main() {
  group('İçerik', () {
    test(
      'beş bölge, her birinde üç hedef ve dört kısa bilgi; kimlikler benzersiz',
      () {
        expect(discoveryZones.length, zones.length);
        final ids = <String>{};
        for (var z = 0; z < discoveryZones.length; z++) {
          final dz = discoveryZones[z];
          expect(dz.zone, z);
          expect(dz.goals.length, 3, reason: zones[z].name);
          expect(dz.facts.length, 4, reason: zones[z].name);
          expect(
            dz.goals.where((g) => g.kind == DiscoveryGoalKind.reach).length,
            1,
          );
          for (final g in dz.goals) {
            expect(g.zone, z);
            expect(g.target, greaterThan(0));
            expect(g.rewardSimits, greaterThan(0));
            expect(ids.add(g.id), isTrue, reason: 'tekrarlanan kimlik ${g.id}');
            expect(g.title, isNotEmpty);
          }
          for (final f in dz.facts) {
            // kısa: ansiklopedi değil
            expect(f.text.length, lessThanOrEqualTo(160), reason: f.text);
          }
          expect(dz.summary.length, lessThanOrEqualTo(90), reason: dz.summary);
        }
      },
    );

    test('puan hedefleri bölgenin puan aralığında; tek uçuşluk engel hedefi bölgeye sığar', () {
      for (final g in discoveryZones.expand((z) => z.goals)) {
        final start = zones[g.zone].startScore;
        final end = g.zone + 1 < zones.length
            ? zones[g.zone + 1].startScore
            : 1 << 30;
        if (g.kind == DiscoveryGoalKind.runScore) {
          expect(g.target, inInclusiveRange(start, end - 1), reason: g.id);
        }
        if (g.kind == DiscoveryGoalKind.obstaclesInZoneRun) {
          expect(g.target, lessThanOrEqualTo(end - start), reason: g.id);
        }
      }
    });

    test(
      'ödül dengesi: toplam 210 simit, mağazanın toplamından (900) çok az',
      () {
        expect(DiscoveryConfig.totalGoalSimits, 210);
        final shop = ShopConfig.prices.values.fold(0, (a, b) => a + b);
        expect(DiscoveryConfig.totalGoalSimits, lessThan(shop ~/ 4));
      },
    );

    test(
      'harita: işaretler kutunun içinde ve gerçek coğrafyaya göre sıralı',
      () {
        final pos = [
          for (final z in discoveryZones) MapProjection.toMap(z.lat, z.lon),
        ];
        for (final p in pos) {
          expect(p.x, inInclusiveRange(0, MapProjection.size));
          expect(p.y, inInclusiveRange(0, MapProjection.size));
        }
        // Galata, Haliç'in doğusunda; Kız Kulesi Galata'nın doğusunda (Asya yakası açıkları)
        expect(pos[1].x, greaterThan(pos[0].x));
        expect(pos[2].x, greaterThan(pos[1].x));
        // Köprü ve Rumeli Hisarı Boğaz'ın kuzeyinde; Rumeli Hisarı en kuzeyde
        expect(pos[3].y, lessThan(pos[1].y));
        expect(pos[4].y, lessThan(pos[3].y));
      },
    );
  });

  group('Bölge keşfi ve ilk keşif kaydı', () {
    test('ilk uçuş Haliç kartpostalını açar; tarih kaydedilir, sonraki uçuşta değişmez', () {
      final s1 = _settle(_quiet(), _run(stats: {0: (3, 0, 0)}, score: 3));
      expect(s1.summary.discovery.newPostcards, [0]);
      expect(s1.progress.discovery.firstSeen[0], _now);
      final later = _now.add(const Duration(days: 2));
      final s2 = _settle(
        s1.progress,
        _run(
          id: 'r2',
          score: 16,
          zone: 1,
          stats: {0: (15, 0, 0), 1: (1, 0, 0)},
        ),
        later,
      );
      expect(s2.summary.discovery.newPostcards, [1]);
      expect(s2.progress.discovery.firstSeen[0], _now);
      expect(s2.progress.discovery.firstSeen[1], later);
    });

    test('bölge rekoru: tek uçuşta bölgede geçilen en çok engel', () {
      var p = _settle(_quiet(), _run(stats: {0: (8, 0, 0)}, score: 8)).progress;
      p = _settle(p, _run(id: 'r2', stats: {0: (5, 0, 0)}, score: 5)).progress;
      expect(p.discovery.zoneRecords[0], 8);
      p = _settle(
        p,
        _run(id: 'r3', stats: {0: (12, 0, 0)}, score: 12),
      ).progress;
      expect(p.discovery.zoneRecords[0], 12);
    });

    test('kilitli / açık / rozet durumları', () {
      final p = _settle(_quiet(), _perfectRun('x')).progress;
      expect(zoneAlbumState(const PlayerProgress(), 0), ZoneAlbumState.locked);
      expect(
        zoneAlbumState(const PlayerProgress(discoveredZones: {0, 1}), 1),
        ZoneAlbumState.discovered,
      );
      expect(
        zoneAlbumState(const PlayerProgress(discoveredZones: {0}), 3),
        ZoneAlbumState.locked,
      );
      expect(zoneAlbumState(p, 4), ZoneAlbumState.badge);
    });
  });

  group('Bölge hedefleri', () {
    test('biriken hedef uçuşlar boyunca toplanır; tek uçuşluk hedef en iyiyi tutar', () {
      var p = _quiet();
      p = _settle(p, _run(id: 'a', score: 4, stats: {0: (4, 2, 0)})).progress;
      final simits = discoveryGoalById('halic_simits')!;
      final obstacles = discoveryGoalById('halic_obstacles')!;
      expect(p.discovery.progressOf(simits), 2);
      expect(p.discovery.progressOf(obstacles), 4);
      p = _settle(p, _run(id: 'b', score: 3, stats: {0: (3, 2, 0)})).progress;
      expect(p.discovery.progressOf(simits), 4, reason: 'birikir');
      expect(p.discovery.progressOf(obstacles), 4, reason: 'en iyi tek uçuş');
      expect(p.discovery.isDone(simits), isFalse);
      final s = _settle(p, _run(id: 'c', score: 10, stats: {0: (10, 1, 0)}));
      expect(s.summary.discovery.completedGoals.map((g) => g.id), [
        'halic_simits',
        'halic_obstacles',
      ]);
      expect(s.progress.discovery.isDone(simits), isTrue);
      expect(s.progress.discovery.badges.containsKey(0), isTrue);
      expect(s.summary.discovery.newBadges, [0]);
    });

    test('başka bölgede toplanan simit o bölgenin hedefini ilerletmez', () {
      final p = _settle(
        _quiet(),
        _run(score: 20, zone: 1, stats: {0: (15, 0, 0), 1: (5, 4, 0)}),
      ).progress;
      expect(p.discovery.progressOf(discoveryGoalById('halic_simits')!), 0);
      expect(
        p.discovery.progressOf(discoveryGoalById('galata_near')!),
        0,
        reason: 'kıl payı yok',
      );
    });

    test('puan hedefi tek uçuşun puanına bakar', () {
      var p = _settle(
        _quiet(),
        _run(score: 24, zone: 1, stats: {0: (15, 0, 0), 1: (9, 0, 0)}),
      ).progress;
      final g = discoveryGoalById('galata_score')!;
      expect(p.discovery.isDone(g), isFalse);
      expect(p.discovery.progressOf(g), 24);
      p = _settle(
        p,
        _run(
          id: 'b',
          score: 25,
          zone: 1,
          stats: {0: (15, 0, 0), 1: (10, 0, 0)},
        ),
      ).progress;
      expect(p.discovery.isDone(g), isTrue);
    });

    test('tamamlanma yüzdesi kısmi ilerlemeyi sayar', () {
      final p = _settle(
        _quiet(),
        _run(score: 5, stats: {0: (5, 0, 0)}),
      ).progress;
      // ulaş 1/1 + simit 0/5 + engel 5/10 → (1 + 0 + 0.5) / 3
      expect(p.discovery.zoneFraction(0), closeTo(1.5 / 3, 1e-9));
      expect(p.discovery.zoneFraction(1), 0);
    });
  });

  group('Tek seferlik ödüller ve çift kayıt', () {
    test('her hedefin simidi bir kez verilir; XP verilmez', () {
      final base = _quiet();
      final s1 = _settle(base, _run(score: 10, stats: {0: (10, 5, 0)}));
      final expected =
          _reward('halic_reach') +
          _reward('halic_simits') +
          _reward('halic_obstacles');
      expect(s1.summary.discovery.simits, expected);
      expect(s1.progress.bonusSimits - base.bonusSimits, expected);
      // XP yalnızca uçuştan (engel 2, simit 3 XP) — keşif XP eklemez
      expect(s1.summary.xpTotal, 10 * 2 + 5 * 3);
      final s2 = _settle(
        s1.progress,
        _run(id: 'r2', score: 10, stats: {0: (10, 5, 0)}),
      );
      expect(s2.summary.discovery.completedGoals, isEmpty);
      expect(s2.progress.bonusSimits, s1.progress.bonusSimits);
    });

    test('aynı uçuş iki kez gelirse hiçbir şey değişmez', () {
      final r = _run(score: 10, stats: {0: (10, 5, 0)});
      final s1 = _settle(_quiet(), r);
      expect(settleRun(s1.progress, r, _now), isNull);
      // ProgressController üzerinden de: ikinci RunFinished yok sayılır
      final c = ProgressController(InMemoryProgressRepository(), _quiet());
      c.onGameEvent(RunFinished(r));
      final once = c.value;
      c.onGameEvent(RunFinished(r));
      expect(identical(c.value, once), isTrue);
      expect(c.value.discovery.completed.length, 3);
    });

    test(
      'ilk keşif XP’si (Phase 2.1) yalnızca bir kez; keşif albümü XP eklemez',
      () {
        final s = _settle(
          _quiet(),
          _run(score: 16, zone: 1, stats: {0: (15, 0, 0), 1: (1, 0, 0)}),
        );
        expect(s.summary.xpZones, 25);
        final again = _settle(
          s.progress,
          _run(
            id: 'r2',
            score: 16,
            zone: 1,
            stats: {0: (15, 0, 0), 1: (1, 0, 0)},
          ),
        );
        expect(again.summary.xpZones, 0);
        expect(again.summary.discovery.newPostcards, isEmpty);
      },
    );

    test('özette simit toplamı profildeki artışla tutarlı', () {
      final base = _quiet();
      final s = _settle(base, _perfectRun('p'));
      expect(
        s.progress.simitBalance - base.simitBalance,
        s.summary.simitsTotal,
      );
      expect(s.summary.discovery.simits, DiscoveryConfig.totalGoalSimits);
    });
  });

  group('Albüm ödülü ve kozmetik sahipliği', () {
    test('beş rozet → İznik Martısı bir kez açılır; seçili görünüm ve satın alınanlar korunur', () {
      final base = _quiet(
        const PlayerProgress(
          unlockedCosmetics: {'classic', 'pilot', 'gece'},
          selectedCosmetic: 'pilot',
        ),
      );
      final s = _settle(base, _perfectRun('p'));
      final d = s.progress.discovery;
      expect(d.badges.length, 5);
      expect(d.albumCompletedAt, _now);
      expect(s.summary.discovery.albumCompleted, isTrue);
      expect(s.summary.discovery.rewardCosmetic, 'iznik');
      expect(s.progress.unlockedCosmetics, {
        'classic',
        'pilot',
        'gece',
        'iznik',
      });
      expect(s.progress.selectedCosmetic, 'pilot');
      expect(s.progress.spentSimits, base.spentSimits);
      final again = _settle(s.progress, _perfectRun('q'));
      expect(again.summary.discovery.albumCompleted, isFalse);
      expect(again.summary.discovery.rewardCosmetic, isNull);
      expect(again.progress.bonusSimits, s.progress.bonusSimits);
    });

    test('İznik Martısı satılmaz; açılınca seçilebilir', () {
      final rich = const PlayerProgress(totalSimits: 5000, xp: 100000);
      final iznik = cosmeticById('iznik')!;
      expect(iznik.rewardOnly, isTrue);
      expect(cosmeticStatus(rich, iznik), CosmeticStatus.rewardLocked);
      final (after, result) = purchaseCosmetic(rich, 'iznik');
      expect(result, PurchaseResult.notForSale);
      expect(after.simitBalance, rich.simitBalance);
      expect(equipCosmetic(rich, 'iznik'), isNull);
      final owner = rich.copyWith(
        unlockedCosmetics: {...rich.unlockedCosmetics, 'iznik'},
      );
      expect(equipCosmetic(owner, 'iznik')!.selectedCosmetic, 'iznik');
      expect(
        effectiveCosmetic(owner.copyWith(selectedCosmetic: 'iznik')).id,
        'iznik',
      );
    });
  });

  group('Kalıcı kayıt', () {
    test('keşif durumu JSON’da kayıpsız gidip gelir', () {
      final s = _settle(_quiet(), _perfectRun('p'));
      final json = jsonDecode(jsonEncode(s.progress.toJson()));
      final back = PlayerProgress.fromJson(json as Map<String, Object?>);
      final a = s.progress.discovery, b = back.discovery;
      expect(b.firstSeen, a.firstSeen.map((k, v) => MapEntry(k, v.toUtc())));
      expect(b.zoneRecords, a.zoneRecords);
      expect(b.completed.keys.toSet(), a.completed.keys.toSet());
      expect(b.badges.keys.toSet(), a.badges.keys.toSet());
      expect(b.albumCompletedAt, a.albumCompletedAt!.toUtc());
      expect(back.toJson()['v'], 3);
    });

    test(
      'albüm uygulama yeniden açılınca korunur (SharedPreferences)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = SharedPrefsProgressRepository(prefs, clock: () => _now);
        final c = ProgressController(repo, _quiet(), clock: () => _now);
        c.settle(
          _run(score: 16, zone: 1, stats: {0: (15, 5, 0), 1: (1, 0, 0)}),
        );
        await c.flush();
        final again = await SharedPrefsProgressRepository(prefs).load();
        expect(again.discoveredZones, {0, 1});
        expect(again.discovery.firstSeen.keys, containsAll([0, 1]));
        expect(again.discovery.completed.keys, contains('halic_simits'));
        expect(again.bonusSimits, c.value.bonusSimits);
      },
    );
  });

  group('Geçiş (migration)', () {
    Map<String, Object> v2Save() => {
      'v': 2,
      'totalSimits': 140,
      'bestRunSimits': 12,
      'unlockedCosmetics': ['classic', 'denizci', 'pilot'],
      'selectedCosmetic': 'pilot',
      'xp': 640,
      'flights': 31,
      'totalScore': 900,
      'totalObstacles': 880,
      'totalNearMisses': 40,
      'bonusSimits': 75,
      'spentSimits': 150,
      'discoveredZones': [0, 1, 2],
      'longestFlightMs': 61000,
      'missionsCompleted': 9,
      'daily': {
        'day': _day,
        'missions': [
          {
            'kind': 'flights',
            'target': 3,
            'rewardXp': 30,
            'rewardSimits': 5,
            'progress': 2,
          },
        ],
      },
      'rewardedMissions': ['2026-10-22:flights'],
      'achievements': {'first_flap': '2026-10-20T10:00:00.000Z'},
      'settledRuns': ['old-1'],
    };

    test(
      '1.2.0 (v2) kaydı: her şey korunur, keşfedilmiş bölgeler kartpostal olur',
      () async {
        SharedPreferences.setMockInitialValues({
          'progress_v2': jsonEncode(v2Save()),
          'best_score_v1': 42,
        });
        final prefs = await SharedPreferences.getInstance();
        final p = await SharedPrefsProgressRepository(
          prefs,
          clock: () => _now,
        ).load();
        // korunanlar
        expect(prefs.getInt('best_score_v1'), 42);
        expect(p.xp, 640);
        expect(p.level, PlayerProgress(xp: 640).level);
        expect(p.totalSimits, 140);
        expect(p.spentSimits, 150);
        expect(p.unlockedCosmetics, {'classic', 'denizci', 'pilot'});
        expect(p.selectedCosmetic, 'pilot');
        expect(p.flights, 31);
        expect(p.missionsCompleted, 9);
        expect(p.achievements.keys, ['first_flap']);
        expect(p.daily?.dayKey, _day);
        expect(p.daily?.missions.single.progress, 2);
        expect(p.settledRuns, ['old-1']);
        expect(p.rewardedMissions, ['2026-10-22:flights']);
        // keşif: tarih uydurulmaz, bölge istatistiği uydurulmaz
        final d = p.discovery;
        expect(d.legacyZones, {0, 1, 2});
        expect(d.firstSeen, isEmpty);
        expect(d.zoneRecords, isEmpty);
        expect(d.completed.keys.toSet(), {
          'halic_reach',
          'galata_reach',
          'kizkulesi_reach',
        });
        expect(d.progress, isEmpty);
        // ulaşma hedeflerinin simidi bir kez eklenir; XP eklenmez
        expect(
          p.bonusSimits,
          75 +
              _reward('halic_reach') +
              _reward('galata_reach') +
              _reward('kizkulesi_reach'),
        );
        // geçiş kaydedildi: tekrar açılışta yeniden ödül yok
        final again = await SharedPrefsProgressRepository(
          prefs,
          clock: () => _now,
        ).load();
        expect(again.bonusSimits, p.bonusSimits);
        expect((jsonDecode(prefs.getString('progress_v2')!) as Map)['v'], 3);
        // eski anahtar silinmedi (v1 ya da v2 kaydı asla silinmez)
        expect(prefs.getString('progress_v2'), isNotNull);
      },
    );

    test(
      '1.0.0 (v1) kaydı: rekordan bölgeler türetilir, albüm kurulur',
      () async {
        SharedPreferences.setMockInitialValues({
          'progress_v1': '{"v":1,"totalSimits":30,"unlockedCosmetics":["classic"],"selectedCosmetic":"classic"}',
          'best_score_v1': 40,
        });
        final prefs = await SharedPreferences.getInstance();
        final p = await SharedPrefsProgressRepository(
          prefs,
          clock: () => _now,
        ).load();
        expect(p.discoveredZones, {0, 1, 2});
        expect(p.discovery.legacyZones, {0, 1, 2});
        expect(prefs.getString('progress_v1'), isNotNull);
      },
    );

    test('eski sürüm albüm alanını düşürürse yedekten geri gelir; ödül ikinci kez verilmez', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsProgressRepository(prefs, clock: () => _now);
      final s = _settle(_quiet(), _perfectRun('p'));
      await repo.save(s.progress);
      // 1.2.0'ın kaydı: aynı profil, `discovery` alanı yok; arada bir uçuş daha oynanmış
      final old = s.progress.toJson()
        ..remove('discovery')
        ..['v'] = 2
        ..['flights'] = s.progress.flights + 1;
      await prefs.setString('progress_v2', jsonEncode(old));
      final back = await SharedPrefsProgressRepository(
        prefs,
        clock: () => _now,
      ).load();
      expect(back.flights, s.progress.flights + 1);
      expect(back.bonusSimits, s.progress.bonusSimits, reason: 'çift ödül yok');
      expect(back.discovery.badges.length, 5);
      expect(back.discovery.firstSeen.keys.toSet(), {0, 1, 2, 3, 4});
      expect(back.unlockedCosmetics, contains('iznik'));
    });

    test('yedekten sonra eski sürümde keşfedilen bölge de albüme eklenir', () {
      final p = _settle(
        _quiet(),
        _run(score: 3, stats: {0: (3, 0, 0)}),
      ).progress.copyWith(discoveredZones: {0, 1});
      final r = reconcileDiscovery(p, _now);
      expect(r.discovery.legacyZones, {1});
      expect(r.discovery.isDone(discoveryGoalById('galata_reach')!), isTrue);
      expect(r.bonusSimits, p.bonusSimits + _reward('galata_reach'));
      // idempotent
      expect(reconcileDiscovery(r, _now).bonusSimits, r.bonusSimits);
    });
  });

  group('Bozuk kayıt kurtarma', () {
    test('bozuk alanlar atlanır, sağlam alanlar okunur', () {
      final d = DiscoveryState.fromJson({
        'firstSeen': {
          '0': 'dün',
          '1': '2026-10-20T10:00:00.000Z',
          '9': '2026-10-20T10:00:00.000Z',
        },
        'legacyZones': [2, 'x', -1, 7],
        'zoneRecords': {'0': -5, '1': 12, 'a': 3},
        'progress': {'halic_simits': 3, 'galata_near': 'çok'},
        'completed': {'halic_reach': '2026-10-20T10:00:00.000Z', 'x': 5},
        'badges': 'bozuk',
        'albumCompletedAt': 42,
      });
      expect(d.firstSeen.keys, [1]);
      expect(d.legacyZones, {2});
      expect(d.zoneRecords, {1: 12});
      expect(d.progress, {'halic_simits': 3});
      expect(d.completed.keys, ['halic_reach']);
      expect(d.badges, isEmpty);
      expect(d.albumCompletedAt, isNull);
    });

    test('albüm alanı tamamen bozuksa (Map değil) geçiş yeniden kurar; diğer alanlar korunur', () async {
      SharedPreferences.setMockInitialValues({
        'progress_v2': jsonEncode({
          'v': 3,
          'totalSimits': 20,
          'discoveredZones': [0],
          'discovery': 'bozuk',
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final p = await SharedPrefsProgressRepository(
        prefs,
        clock: () => _now,
      ).load();
      expect(p.totalSimits, 20);
      expect(p.discovery.legacyZones, {0});
      expect(p.discovery.isDone(discoveryGoalById('halic_reach')!), isTrue);
    });

    test('geçersiz bölge ve negatif sayılar uçuş hesabını bozmaz', () {
      final s = _settle(
        _quiet(),
        _run(score: 5, stats: {0: (-3, -1, -2), 9: (5, 5, 5)}),
      );
      expect(s.progress.discovery.zoneRecords.containsKey(9), isFalse);
      expect(s.progress.discovery.zoneRecords[0] ?? 0, 0);
      expect(
        s.progress.discovery.progressOf(discoveryGoalById('halic_simits')!),
        0,
      );
    });
  });

  group('Oyun: bölge bazlı sayaçlar', () {
    test(
      'engel, simit ve kıl payı geçildiği bölgeye yazılır; toplamlar tutarlı',
      () async {
        final t = TestServices(progress: _quiet());
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
        RunResult? result;
        t.services.listeners.add(_Capture((r) => result = r));
        g.debugInvincible = true;
        g.autopilot = true;
        g.handleTap();
        while (g.score.value < 17) {
          g.update(1 / 60);
        }
        g.debugInvincible = false;
        g.autopilot = false;
        g.physics.y = g.config.worldHeight;
        for (var i = 0; i < 30; i++) {
          g.update(1 / 60);
        }
        expect(g.phase.value, GamePhase.gameOver);
        final r = result!;
        expect(r.zoneStats[0]!.obstacles, 15, reason: '0–14 → Haliç');
        expect(
          r.zoneStats[1]!.obstacles,
          2,
          reason: '15. puandan sonra Galata',
        );
        expect(
          r.zoneStats.values.fold(0, (a, s) => a + s.obstacles),
          r.obstaclesPassed,
        );
        expect(r.zoneStats.values.fold(0, (a, s) => a + s.simits), r.simits);
        expect(
          r.zoneStats.values.fold(0, (a, s) => a + s.nearMisses),
          r.nearMisses,
        );
        final p = t.services.progress.value;
        expect(p.discovery.firstSeen.keys, containsAll([0, 1]));
        expect(p.discovery.zoneRecords[0], 15);
        expect(
          p.discovery.isDone(discoveryGoalById('halic_obstacles')!),
          isTrue,
        );
        // yeni uçuşta sayaçlar sıfırlanır
        g.restart();
        g.handleTap();
        g.physics.y = g.config.worldHeight;
        g.update(1 / 60);
        expect(result!.zoneStats, isEmpty);
        g.onRemove();
      },
    );
  });
}

class _Capture implements GameEventListener {
  _Capture(this.onRun);
  final void Function(RunResult) onRun;

  @override
  void onGameEvent(GameEvent event) {
    if (event is RunFinished) onRun(event.result);
  }
}
