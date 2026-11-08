import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/config.dart';
import 'package:istanbul_flight/game/day_cycle.dart';
import 'package:istanbul_flight/game/logic/bird_physics.dart';
import 'package:istanbul_flight/game/logic/collision.dart';
import 'package:istanbul_flight/game/logic/gap_generator.dart';
import 'package:istanbul_flight/ui/overlays/hud_overlay.dart';
import 'package:istanbul_flight/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const config = GameConfig();

  group('BirdPhysics', () {
    test('kanat çırpma yukarı hız verir, yer çekimi düşürür', () {
      final p = BirdPhysics(config, y: 800)..flap();
      expect(p.velocity, config.flapVelocity);
      for (var i = 0; i < 120; i++) {
        p.step(config.physicsStep);
      }
      expect(p.velocity, greaterThan(0), reason: '1 sn sonra düşüyor olmalı');
    });

    test('düşüş hızı sınırlı', () {
      final p = BirdPhysics(config, y: 0);
      for (var i = 0; i < 1000; i++) {
        p.step(config.physicsStep);
      }
      expect(p.velocity, config.maxFallSpeed);
    });

    test('tavana çarpmak ölüm değil, karakter tavanda tutulur', () {
      final p = BirdPhysics(config, y: 50)..velocity = -3000;
      p.step(0.05);
      expect(p.y, config.birdHitRadius);
      expect(p.velocity, 0);
    });

    test('suya ulaşınca hitsWater', () {
      final p = BirdPhysics(
        config,
        y: config.worldHeight - config.birdHitRadius + 1,
      );
      expect(p.hitsWater, isTrue);
    });
  });

  group('circleIntersectsRect', () {
    const rect = Rect.fromLTWH(100, 100, 50, 200);
    test('içeride / kenara değiyor / uzakta', () {
      expect(circleIntersectsRect(const Offset(120, 150), 10, rect), isTrue);
      expect(circleIntersectsRect(const Offset(95, 150), 10, rect), isTrue);
      expect(circleIntersectsRect(const Offset(80, 150), 10, rect), isFalse);
    });
    test('köşede gerçek daire testi (kutu testi değil)', () {
      // Köşeye çapraz uzaklık ≈ 14,1 > 12 → kesişmez
      expect(circleIntersectsRect(const Offset(90, 90), 12, rect), isFalse);
      expect(circleIntersectsRect(const Offset(92, 92), 12, rect), isTrue);
    });
  });

  group('GapGenerator', () {
    test('geçitler güvenli bantta ve ardışık fark sınırlı', () {
      final g = GapGenerator(config, random: Random(1));
      double? last, lastShift;
      for (var score = 0; score < 2000; score++) {
        final gap = g.next(score % 150);
        expect(
          gap.center - gap.height / 2,
          greaterThanOrEqualTo(config.gapMarginTop - 1e-9),
        );
        expect(
          gap.center + gap.height / 2,
          lessThanOrEqualTo(config.worldHeight - config.gapMarginBottom + 1e-9),
        );
        if (last != null) {
          // yukarı (merkez küçülür) tırmanma, aşağı süzülme sınırı
          expect(
            last - gap.center,
            lessThanOrEqualTo(config.maxGapRise + 1e-9),
          );
          expect(
            gap.center - last,
            lessThanOrEqualTo(config.maxGapDrop + 1e-9),
          );
          if (lastShift != null && lastShift.abs() > config.bigShift) {
            final calm = config.afterBigShiftScale;
            expect(
              last - gap.center,
              lessThanOrEqualTo(config.maxGapRise * calm + 1e-9),
            );
            expect(
              gap.center - last,
              lessThanOrEqualTo(config.maxGapDrop * calm + 1e-9),
            );
          }
          lastShift = gap.center - last;
        }
        last = gap.center;
      }
    });

    test('art arda iki büyük sıçrama yok (zikzak)', () {
      final g = GapGenerator(config, random: Random(7));
      final centers = [for (var i = 0; i < 5000; i++) g.next(i % 150).center];
      final calmLimit = config.maxGapDrop * config.afterBigShiftScale;
      for (var i = 2; i < centers.length; i++) {
        final a = centers[i - 1] - centers[i - 2],
            b = centers[i] - centers[i - 1];
        if (a.abs() > config.bigShift) {
          expect(b.abs(), lessThanOrEqualTo(calmLimit + 1e-9));
        }
      }
    });

    test('geçit eğrisi: bölge sınırlarında tanımlı, monoton daralır, en dar geçit sabit', () {
      expect(config.gapForScore(0), config.startGap);
      expect(config.gapForScore(0), 370);
      expect(config.gapForScore(15), 350);
      expect(config.gapForScore(35), 330);
      expect(config.gapForScore(60), 310);
      expect(config.gapForScore(90), 300);
      expect(config.gapForScore(10000), config.minGap);
      expect(config.minGap, 300);
      var prev = double.infinity;
      for (var s = 0; s <= 200; s++) {
        final g = config.gapForScore(s);
        expect(g, lessThanOrEqualTo(prev));
        prev = g;
      }
      // en dar geçit bir çırpış yayından (zirve yüksekliği + kuş çapı) en az 70 birim geniş
      final arc =
          config.flapVelocity * config.flapVelocity / (2 * config.gravity);
      expect(
        config.minGap - (arc + 2 * config.birdHitRadius),
        greaterThanOrEqualTo(70),
      );
    });

    test('hız skorla artar ama sınırlı', () {
      expect(config.speedForScore(0), config.startSpeed);
      expect(config.speedForScore(10000), config.maxSpeed);
    });
  });

  group('DayCycle', () {
    test('bölge eşikleri', () {
      expect(zoneIndexForScore(0), 0);
      expect(zoneIndexForScore(14), 0);
      expect(zoneIndexForScore(15), 1);
      expect(zoneIndexForScore(35), 2);
      expect(zoneIndexForScore(60), 3);
      expect(zoneIndexForScore(90), 4);
      expect(zoneIndexForScore(119), 4);
      // Phase 2.6: rota Rumeli'den sonra ikinci günle devam eder
      expect(zoneIndexForScore(120), 5);
      expect(zoneIndexForScore(180), 7);
      expect(zoneIndexForScore(210), 8);
      expect(zoneIndexForScore(150), 6);
      expect(zoneIndexForScore(500), routeZones.last);
      // Günün Uçuşu v1/v2 rotası Rumeli'de biter
      expect(zoneIndexForScore(500, maxZone: firstRouteLastZone), 4);
    });

    test(
      'bölge kimlikleri kalıcı: ilk beş bölge yerinde, eşikler rotada artan',
      () {
        expect(
          [for (final z in zones.take(5)) z.name],
          ['Haliç', 'Galata', 'Kız Kulesi', 'Boğaz Köprüsü', 'Rumeli Hisarı'],
        );
        expect(
          [for (final z in zones) z.startScore],
          [0, 15, 35, 60, 90, 120, 150, 180, 210],
        );
        expect(routeZones.take(5), [0, 1, 2, 3, 4]);
        for (var i = 1; i < routeZones.length; i++) {
          expect(
            zones[routeZones[i]].startScore,
            greaterThan(zones[routeZones[i - 1]].startScore),
          );
        }
        expect(nextRouteZone(4), 5);
        expect(nextRouteZone(routeZones.last), isNull);
      },
    );

    test('Günün Uçuşu gün döngüsü Rumeli\'de kalır', () {
      final d = DayCycle();
      expect(d.updateScore(200, maxZone: firstRouteLastZone), isTrue);
      expect(d.zoneIndex, 4);
      expect(d.updateScore(250, maxZone: firstRouteLastZone), isFalse);
    });

    test('bölge değişince palet yumuşak geçer ve sonunda hedefe ulaşır', () {
      final d = DayCycle(transitionTime: 1);
      expect(d.updateScore(15), isTrue);
      expect(d.updateScore(16), isFalse);
      d.update(0.5);
      expect(d.palette.skyTop, isNot(zones[1].palette.skyTop));
      d.update(1);
      expect(d.palette.skyTop, zones[1].palette.skyTop);
      d.reset();
      expect(d.zoneIndex, 0);
      expect(d.palette.skyTop, zones[0].palette.skyTop);
    });
  });

  test('rota çubuğu ilerlemesi 0..1 ve monoton', () {
    var last = -1.0;
    for (var s = 0; s <= 260; s++) {
      final p = RouteBar.progressFor(s);
      expect(p, inInclusiveRange(0, 1));
      expect(p, greaterThanOrEqualTo(last));
      last = p;
    }
    expect(RouteBar.progressFor(zones[routeZones.last].startScore), 1);
    // her durak eşit aralıklı: Rumeli rotanın 5. durağı
    expect(
      RouteBar.progressFor(90),
      closeTo(4 / (routeZones.length - 1), 1e-9),
    );
  });

  group('SharedPrefsScoreRepository', () {
    test('kaydeder ve yeniden açılışta okur', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = await SharedPrefsScoreRepository.create();
      expect(await repo.loadBest(), 0);
      await repo.saveBest(42);
      final reopened = await SharedPrefsScoreRepository.create();
      expect(await reopened.loadBest(), 42);
    });
  });

  test('Türkçe büyük harf: bölge damgaları', () {
    expect(trUpper('Rumeli Hisarı'), 'RUMELİ HİSARI');
    expect(trUpper('Kız Kulesi'), 'KIZ KULESİ');
    expect(trUpper('Haliç'), 'HALİÇ');
    expect(trUpper('Boğaz Köprüsü'), 'BOĞAZ KÖPRÜSÜ');
  });
}
