import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/challenge/daily_challenge.dart';
import 'package:istanbul_flight/challenge/daily_rng.dart';
import 'package:istanbul_flight/game/components/weather_layer.dart';
import 'package:istanbul_flight/game/config.dart';
import 'package:istanbul_flight/game/logic/hazards.dart';
import 'package:istanbul_flight/game/weather.dart';
import 'package:istanbul_flight/services/audio_service.dart';

// Phase 2.6.3 (docs/19 §6): dinamik engeller (martı sürüsü, rüzgâr kuşağı) ve hava durumu.

DailyChallengeDefinition _course(int k) => DailyChallengeDefinition(
  challengeId: 'x',
  dateUtc: DateTime.utc(2026, 11, 10),
  seed: DailyRng.hash('hazard/$k'),
  generatorVersion: 2,
  candidate: 0,
  validatedDepth: 0,
);

/// Oyunla aynı kural: i. koridor (i-1 ile i. engel arası) için planlayıcı sırayla çağrılır.
Hazard? Function(int) _hazardsFor(DailyCourse course, int seed) {
  const c = GameConfig();
  final r = Random(seed);
  final planner = HazardPlanner(c, r.nextDouble);
  final cache = <Hazard?>[null];
  return (int i) {
    while (cache.length <= i) {
      final n = cache.length;
      final prev = course.at(n - 1), gap = course.at(n);
      cache.add(
        planner.next(
          corridor: n,
          score: n,
          previous: (center: prev.gapCenter, height: prev.gapHeight),
          gap: (center: gap.gapCenter, height: gap.gapHeight),
        ),
      );
    }
    return i < 0 ? null : cache[i];
  };
}

void main() {
  const c = GameConfig();
  const g = (center: 900.0, height: 320.0);

  group('HazardPlanner', () {
    test('aynı tohum → aynı dinamik engel dizisi; her çağrı tam 3 sayı çeker', () {
      List<String> seq(int seed) {
        var draws = 0;
        final r = Random(seed);
        final p = HazardPlanner(c, () {
          draws++;
          return r.nextDouble();
        });
        final out = <String>[];
        for (var i = 1; i <= 300; i++) {
          final h = p.next(corridor: i, score: i, previous: g, gap: g);
          out.add(h == null ? '-' : '${h.kind.name}:${h.baseY}:${h.accel}');
          expect(draws, 3 * i);
        }
        return out;
      }

      expect(seq(5), seq(5));
      expect(seq(5), isNot(seq(6)));
    });

    test('skor 120 öncesinde hiç dinamik engel yok; sonrasında ikisi de çıkar, ardışık değil', () {
      final p = HazardPlanner(c, Random(3).nextDouble);
      final kinds = <HazardKind>[];
      var lastHazard = -100;
      for (var i = 1; i <= 2000; i++) {
        final score = i < 1000 ? i % c.hazardsFromScore : c.hazardsFromScore + i;
        final h = p.next(corridor: i, score: score, previous: g, gap: g);
        if (score < c.hazardsFromScore) {
          expect(h, isNull);
          continue;
        }
        if (h != null) {
          expect(i - lastHazard, greaterThan(c.hazardCooldown));
          lastHazard = i;
          kinds.add(h.kind);
        }
      }
      expect(kinds, contains(HazardKind.flock));
      expect(kinds, contains(HazardKind.gust));
    });

    test('belirgin kaymada sürü kuşun terk ettiği tarafta durur', () {
      for (var seed = 0; seed < 50; seed++) {
        final p = HazardPlanner(c, Random(seed).nextDouble);
        for (var i = 0; i < 40; i++) {
          // iniş (geçit aşağı kayıyor): sürü üstte
          final down = p.next(
            corridor: i,
            score: 200,
            previous: (center: 700, height: 320),
            gap: (center: 950, height: 320),
          );
          if (down?.kind == HazardKind.flock) {
            expect(down!.baseY, lessThan(825), reason: 'iniş, tohum $seed');
          }
          final up = p.next(
            corridor: i,
            score: 200,
            previous: (center: 950, height: 320),
            gap: (center: 700, height: 320),
          );
          if (up?.kind == HazardKind.flock) {
            expect(up!.baseY, greaterThan(825), reason: 'tırmanış, tohum $seed');
          }
        }
      }
    });

    test('sürü çarpışma kutusu görselinden küçük; salınım zamana bağlı ve sınırlı', () {
      const h = Hazard.flock(corridor: 1, baseY: 800, phase: 0.25);
      final rect = h.flockRect(c, 500, 0);
      expect(rect.width, lessThan(c.flockWidth));
      expect(rect.height, lessThan(c.flockHeight));
      for (var t = 0.0; t < 6; t += 0.05) {
        expect((h.flockY(c, t) - 800).abs(), lessThanOrEqualTo(c.flockBob + 1e-9));
      }
      expect(h.flockY(c, 0), closeTo(h.flockY(c, c.flockBobPeriod), 1e-9));
    });

    test('sürü kuşa doğru kaydırmadan hızlı uçar ve kuşun hizasına koridor ortasında gelir', () {
      const birdX = 300.0;
      expect(HazardRules.flockCenterX(c, birdX, birdX), birdX);
      // koridor 100 birim yaklaşınca sürü 100'den fazla yaklaşır
      final far = HazardRules.flockCenterX(c, birdX + 600, birdX);
      final near = HazardRules.flockCenterX(c, birdX + 500, birdX);
      expect(far - near, closeTo(100 * (1 + c.flockApproach), 1e-9));
      expect(far, greaterThan(birdX + 600));
    });

    test('hava akımı yumuşak: koridor kenarlarında 0, ortasında tam, arada sürekli', () {
      const spacing = 600.0, birdX = 300.0;
      final w = spacing - c.obstacleWidth;
      double f(double u) => HazardRules.gustFactor(
        c,
        birdX,
        birdX + (1 - u) * w, // kuş koridorun u konumunda
        spacing,
      );
      expect(f(0), 0);
      expect(f(1), 0);
      expect(f(-0.1), 0);
      expect(f(1.1), 0);
      expect(f(0.5), closeTo(1, 1e-9));
      for (var u = 0.0; u < 1; u += 0.01) {
        expect((f(u + 0.01) - f(u)).abs(), lessThan(0.04)); // ani sıçrama yok
      }
    });
  });

  group('Adalet (erişilebilirlik simülasyonu, dinamik engellerle)', () {
    test('hazardAt verilmezse sonuç önceki sürümle aynı', () {
      for (var k = 0; k < 6; k++) {
        final a = CourseValidator.explore(DailyCourse(_course(k)), maxScore: 120);
        final b = CourseValidator.explore(
          DailyCourse(_course(k)),
          maxScore: 120,
          hazardAt: (_) => null,
        );
        expect(b.depth, a.depth);
        expect(b.tightest, a.tightest);
      }
    });

    // Keşif her 6 (ve 4) adımda bir karar verir ve hız kutularını budar: tek ölçüm gerçek bandın gürültülü bir
    // alt sınırıdır. Her keşfedilen durum gerçekten ulaşılabilir olduğundan engel başına iki ölçümün büyüğü de
    // geçerli bir alt sınırdır (80 parkurda ölçülen: dinamik engelsiz en dar 120, sürü+rüzgârla en dar 101).
    test('30 parkur 230 engele kadar sürü ve rüzgârla geçilebilir, en dar bant ≥ 90', () {
      var hazardCount = 0;
      for (var k = 0; k < 30; k++) {
        final course = DailyCourse(_course(k));
        final at = _hazardsFor(course, k);
        final a = <double>[], b = <double>[];
        final r = CourseValidator.explore(
          course,
          maxScore: 230,
          hazardAt: at,
          bands: a,
        );
        final r4 = CourseValidator.explore(
          course,
          maxScore: 230,
          hazardAt: at,
          bands: b,
          decisionSteps: 4,
        );
        for (var i = 0; i <= 230; i++) {
          if (at(i) != null) hazardCount++;
        }
        expect(r.depth, 230, reason: 'parkur $k');
        expect(r4.depth, 230, reason: 'parkur $k');
        var worst = double.infinity;
        for (var i = 0; i < min(a.length, b.length); i++) {
          worst = min(worst, max(a[i], b[i]));
        }
        expect(worst, greaterThanOrEqualTo(90), reason: 'parkur $k');
      }
      // tarama gerçekten dinamik engel içeriyor (ortalama ≥ 10 / parkur)
      expect(hazardCount, greaterThan(300));
    });
  });

  group('Hava durumu (yalnızca görsel)', () {
    test('seçim bölge seçeneklerine bağlı; açık hava olasılığı korunur', () {
      expect(WeatherRules.options.length, 9);
      for (var z = 0; z < 9; z++) {
        expect(WeatherRules.pick(z, 0.99, 0.5), Weather.clear);
        final w = WeatherRules.pick(z, 0.0, 0.5);
        if (WeatherRules.options[z].isEmpty) {
          expect(w, Weather.clear);
        } else {
          expect(WeatherRules.options[z], contains(w));
        }
      }
      expect(WeatherRules.pick(99, 0, 0), Weather.clear);
      expect(WeatherRules.pick(-1, 0, 0), Weather.clear);
    });

    test('hava katmanı engellerin arkasında çizilir (öncelik 39 < 40)', () {
      expect(WeatherLayer().priority, lessThan(40));
    });

    test('yağmur ortam sesi dosyası var ve kayıtlı', () {
      expect(Ambience.rain.file, 'amb_rain.wav');
      expect(File('assets/audio/amb_rain.wav').existsSync(), isTrue);
    });
  });
}
