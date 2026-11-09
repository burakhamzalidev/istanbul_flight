import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/game/day_cycle.dart';
import 'package:istanbul_flight/game/game_art.dart';
import 'package:istanbul_flight/progression/discovery.dart';
import 'package:istanbul_flight/progression/game_events.dart';
import 'package:istanbul_flight/progression/missions.dart';
import 'package:istanbul_flight/progression/run_settlement.dart';
import 'package:istanbul_flight/services/progress.dart';

// Phase 2.6.1: yeni bölge altyapısı ve Ortaköy (docs/19).

final _now = DateTime(2026, 11, 8, 15);
const _day = '2026-11-08';

RunResult _run(
  String id, {
  required int score,
  required int zone,
  Map<int, int> obstacles = const {},
}) => RunResult(
  runId: id,
  score: score,
  obstaclesPassed: score,
  simits: 0,
  nearMisses: 0,
  maxZone: zone,
  flightMs: score * 1400,
  zoneStats: {
    for (final e in obstacles.entries) e.key: ZoneRunStats(obstacles: e.value),
  },
);

/// İlk rotanın albümünü bitirmiş, İznik görünümünü almış eski (Phase 2.5) oyuncu.
PlayerProgress _veteran() {
  final seen = DateTime(2026, 10, 20);
  final firstRoute = discoveryZones.where((d) => d.zone <= firstRouteLastZone);
  return PlayerProgress(
    discoveredZones: const {0, 1, 2, 3, 4},
    xp: 4321,
    bonusSimits: 77,
    unlockedCosmetics: const {'classic', 'pilot', 'iznik'},
    selectedCosmetic: 'pilot',
    achievements: {
      'first_flap': seen,
      'night_flight': seen,
      'bosphorus_traveler': seen,
    },
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
    discovery: DiscoveryState(
      firstSeen: {for (var z = 0; z <= 4; z++) z: seen},
      completed: {
        for (final g in firstRoute.expand((d) => d.goals)) g.id: seen,
      },
      badges: {for (var z = 0; z <= 4; z++) z: seen},
      albumCompletedAt: seen,
    ),
  );
}

void main() {
  group('Eski oyuncu verisi (migration)', () {
    test('kayıt JSON üzerinden aynen okunur: rozetler, albüm ödülü, görünümler, XP', () {
      final v = _veteran();
      final back = PlayerProgress.fromJson(
        jsonDecode(jsonEncode(v.toJson())) as Map<String, Object?>,
      );
      expect(back.discovery.badges.keys.toSet(), {0, 1, 2, 3, 4});
      expect(
        back.discovery.albumCompletedAt!.isAtSameMomentAs(
          v.discovery.albumCompletedAt!,
        ),
        isTrue,
      ); // kayıt UTC yazar: aynı an
      expect(back.unlockedCosmetics, {'classic', 'pilot', 'iznik'});
      expect(back.selectedCosmetic, 'pilot');
      expect(back.xp, 4321);
      expect(back.discoveredZones, {0, 1, 2, 3, 4});
    });

    test('albüm yüzdesi yeni toplamla hesaplanır (5/9), kazanılmış hiçbir şey geri alınmaz', () {
      final d = _veteran().discovery;
      expect(d.albumFraction, closeTo(5 / routeZones.length, 1e-9));
      expect(d.badges.length, 5);
      expect(d.albumCompletedAt, isNotNull);
    });

    test('Ortaköy\'e ulaşan eski oyuncu: yalnızca yeni bölgelerin (Emirgan, Ortaköy) kartı ve ödülü; eski ödüller tekrar verilmez', () {
      final v = _veteran();
      final s = settleRun(
        v,
        _run('o1', score: 160, zone: 6, obstacles: {4: 60, 6: 10}),
        _now,
      )!;
      final p = s.progress;
      expect(s.summary.discovery.newPostcards, [5, 6]);
      expect(
        p.discoveredZones,
        {0, 1, 2, 3, 4, 5, 6},
        reason: 'yolda geçilen Emirgan da keşfedilir; ilerideki Dolmabahçe ve Üsküdar keşfedilmez',
      );
      expect(s.summary.discovery.completedGoals.map((g) => g.id), [
        'emirgan_reach',
        'ortakoy_reach',
      ]);
      expect(
        s.summary.discovery.albumCompleted,
        isFalse,
        reason: 'albüm ödülü zaten verildi',
      );
      expect(s.summary.discovery.rewardCosmetic, isNull);
      expect(p.discovery.albumCompletedAt, v.discovery.albumCompletedAt);
      expect(p.unlockedCosmetics, v.unlockedCosmetics);
      expect(p.selectedCosmetic, 'pilot');
      // eski başarımlar korunur, tekrar açılmaz
      expect(
        s.summary.unlockedAchievements.where(
          (a) => v.achievements.containsKey(a.id),
        ),
        isEmpty,
      );
      for (final e in v.achievements.entries) {
        expect(p.achievements[e.key], e.value);
      }
      // ilk keşif XP'si yalnızca iki yeni bölge için
      expect(s.summary.xpZones, 50);
      // aynı uçuş ikinci kez işlenmez
      expect(settleRun(p, _run('o1', score: 160, zone: 6), _now), isNull);
    });

    test('yeni oyuncu albüm ödülünü yine ilk rotanın beş rozetiyle alır (Ortaköy gerekmez)', () {
      final first = discoveryZones.where((d) => d.zone <= firstRouteLastZone);
      final p = PlayerProgress(
        discoveredZones: const {0, 1, 2, 3, 4},
        discovery: DiscoveryState(
          firstSeen: {for (var z = 0; z <= 4; z++) z: _now},
          completed: {for (final g in first.expand((d) => d.goals)) g.id: _now},
        ),
      );
      final r = reconcileDiscovery(p, _now);
      expect(r.discovery.albumCompletedAt, _now);
      expect(
        r.unlockedCosmetics,
        contains(DiscoveryConfig.albumRewardCosmetic),
      );
    });

    test('1.0.0 kaydı: rekordan yalnızca ilk rotanın bölgeleri türetilir', () {
      final v2 = PlayerProgress.migrateFromV1(
        const PlayerProgress(),
        best: 300,
      );
      expect(v2.discoveredZones, {0, 1, 2, 3, 4});
    });

    test('bozuk uçuş değeri rotanın son durağına kırpılır', () {
      final s = settleRun(
        const PlayerProgress(),
        _run('x', score: 999, zone: 99),
        _now,
      )!;
      expect(s.progress.discoveredZones, routeZones.toSet());
    });
  });

  group('Bölge rotası', () {
    test('ikinci gün rotası tamam: Emirgan, Ortaköy, Dolmabahçe, Üsküdar rotada (sıra ve eşikler sabit)', () {
      expect(
        [for (final z in zones.skip(5)) z.name],
        ['Emirgan', 'Ortaköy', 'Dolmabahçe', 'Üsküdar'],
      );
      expect(zones.every((z) => z.available), isTrue);
      expect(routeZones, [0, 1, 2, 3, 4, 5, 6, 7, 8]);
      expect(routeZoneList.last.name, 'Üsküdar');
    });

    test('harita işaretleri parmakla ayrı seçilebilir: her çift en az 14 harita pikseli uzakta', () {
      Offset at(int z) {
        final d = discoveryZoneOf(z);
        final m = MapProjection.toMap(d.lat, d.lon);
        return Offset(m.x + d.markerDx, m.y + d.markerDy);
      }

      for (final a in routeZones) {
        for (final b in routeZones) {
          if (a >= b) continue;
          expect(
            (at(a) - at(b)).distance,
            greaterThanOrEqualTo(14),
            reason: '${zones[a].name} – ${zones[b].name}',
          );
        }
      }
    });

    test('her rota bölgesinin keşif kartı, simgesi ve engel kiti var', () {
      for (final z in routeZoneList) {
        expect(GameArt.routeKits, contains(z.kit));
        expect(GameArt.routeLandmarks, contains(z.landmark));
      }
      for (final i in routeZones) {
        expect(discoveryZoneOf(i).zone, i);
      }
    });
  });

  group('Asset yükleme', () {
    test(
      'rotadaki her bölgenin arka plan klasörü pubspec\'te (pakete girer)',
      () {
        final pubspec = File('pubspec.yaml').readAsStringSync();
        for (final k in GameArt.routeKits) {
          expect(
            pubspec.contains(
              '- assets/images/pixel_art/backgrounds/${k.name}/',
            ),
            isTrue,
            reason: k.name,
          );
        }
        for (final dir in ['obstacles', 'landmarks']) {
          expect(pubspec.contains('- assets/images/pixel_art/$dir/'), isTrue);
        }
      },
    );

    testWidgets(
      'eksik asset: oyun yüklenir, eksik kit ve katman null kalır (yedek çizim), diğerleri yüklenir',
      (tester) async {
        await tester.runAsync(() async {
          final images = _MissingImages({
            GameArt.kitPath(ObstacleKitId.ortakoy),
            GameArt.zonePath('ortakoy', 'midground'),
          });
          final art = await GameArt.load(images);
          expect(art.kits.containsKey(ObstacleKitId.ortakoy), isFalse);
          expect(art.kits.containsKey(ObstacleKitId.halic), isTrue);
          expect(art.zones['ortakoy']!.midground, isNull);
          expect(art.zones['ortakoy']!.sky, isNotNull);
          expect(art.landmarks.containsKey(Landmark.ortakoy), isTrue);
          // yalnızca asset listesindeki (rotadaki bölgelerin) dosyalar istenir
          for (final p in images.requested) {
            expect(GameArt.allPaths, contains(p));
          }
        });
      },
    );
  });
}

/// Belirli yollarda hata veren (eksik dosya), diğerlerinde 1×1 görsel döndüren önbellek.
class _MissingImages extends Images {
  _MissingImages(this.missing) : super(prefix: '');
  final Set<String> missing;
  final requested = <String>[];
  ui.Image? _px;

  @override
  Future<ui.Image> load(String fileName, {String? key, String? package}) async {
    requested.add(fileName);
    if (missing.contains(fileName)) throw StateError('yok: $fileName');
    if (_px != null) return _px!;
    final rec = ui.PictureRecorder();
    ui.Canvas(rec).drawRect(const ui.Rect.fromLTWH(0, 0, 1, 1), ui.Paint());
    return _px = await rec.endRecording().toImage(1, 1);
  }
}
