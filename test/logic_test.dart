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
      double? last;
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
          expect(
            (gap.center - last).abs(),
            lessThanOrEqualTo(config.maxGapShift + 1e-9),
          );
        }
        last = gap.center;
      }
    });

    test('geçit skorla daralır ama minGap altına inmez', () {
      expect(config.gapForScore(0), config.startGap);
      expect(config.gapForScore(10), lessThan(config.startGap));
      expect(config.gapForScore(10000), config.minGap);
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
      expect(zoneIndexForScore(500), 4);
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
    for (var s = 0; s <= 120; s++) {
      final p = RouteBar.progressFor(s);
      expect(p, inInclusiveRange(0, 1));
      expect(p, greaterThanOrEqualTo(last));
      last = p;
    }
    expect(RouteBar.progressFor(90), 1);
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
