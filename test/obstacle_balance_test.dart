import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/challenge/daily_challenge.dart';
import 'package:istanbul_flight/challenge/daily_rng.dart';
import 'package:istanbul_flight/game/config.dart';
import 'package:istanbul_flight/game/day_cycle.dart';
import 'package:istanbul_flight/game/game_art.dart';
import 'package:istanbul_flight/game/logic/gap_generator.dart';
import 'package:istanbul_flight/game/logic/pickup_rules.dart';
import 'package:istanbul_flight/game/visual/obstacle_kit_layout.g.dart';

// docs/18: engel görselleri (v3) ve geçit dengesi.

class _Atlas {
  _Atlas(this.w, this.h, this.data);
  final int w, h;
  final ByteData data;
  int alpha(int x, int y) => data.getUint8((y * w + x) * 4 + 3);
  int rgb(int x, int y) => data.getUint32((y * w + x) * 4) >> 8;
}

Future<_Atlas> _load(ObstacleKitId k) async {
  final codec = await ui.instantiateImageCodec(
    File('assets/images/${GameArt.kitPath(k)}').readAsBytesSync(),
  );
  final img = (await codec.getNextFrame()).image;
  final data = (await img.toByteData())!;
  return _Atlas(img.width, img.height, data);
}

/// Parça (dünya birimi) → atlas piksel aralığı.
({int x0, int y0, int w, int h}) _px(ui.Rect r) {
  const s = ObstacleKitLayout.atlasScale;
  return (
    x0: (r.left * s).round(),
    y0: (r.top * s).round(),
    w: (r.width * s).round(),
    h: (r.height * s).round(),
  );
}

DailyChallengeDefinition _v2(int k) => DailyChallengeDefinition(
  challengeId: 'x',
  dateUtc: DateTime.utc(2026, 11, 10),
  seed: DailyRng.hash('balance/$k'),
  generatorVersion: 2,
  candidate: 0,
  validatedDepth: 0,
);

DailyChallengeDefinition _v1(int k) => DailyChallengeDefinition(
  challengeId: 'x',
  dateUtc: DateTime.utc(2026, 10, 24),
  seed: DailyRng.hash('balance/$k'),
  generatorVersion: 1,
  candidate: 0,
  validatedDepth: 0,
);

void main() {
  group('Görsel ↔ hitbox (atlas pikselleri)', () {
    testWidgets(
      'gövde karoları hitbox genişliğinde tamamen opak; başlıklarda sınırın altındaki gövde sütunları boşluksuz',
      (tester) async {
        await tester.runAsync(() async {
          const s = ObstacleKitLayout.atlasScale;
          final ov = (ObstacleKitLayout.overhang * s).round();
          final bw = (ObstacleKitLayout.bodyWidth * s).round();
          for (final kit in ObstacleKitId.values) {
            final a = await _load(kit);
            for (final r in [
              ObstacleKitLayout.bottomBodyA,
              ObstacleKitLayout.bottomBodyB,
              ObstacleKitLayout.topBodyA,
              ObstacleKitLayout.topBodyB,
            ]) {
              final p = _px(r);
              for (var y = p.y0; y < p.y0 + p.h; y++) {
                for (var x = p.x0; x < p.x0 + p.w; x++) {
                  expect(a.alpha(x, y), 255, reason: '${kit.name} $r ($x,$y)');
                }
              }
            }
            // alt başlık: sınırın altındaki her satırda gövde sütunları opak (görselsiz hitbox yok)
            final boundary =
                (ObstacleKitLayout.bottomCapBoundary[kit.name]! * s).round();
            final bc = _px(ObstacleKitLayout.bottomCap);
            for (var y = bc.y0 + boundary; y < bc.y0 + bc.h; y++) {
              for (var x = bc.x0 + ov; x < bc.x0 + ov + bw; x++) {
                expect(
                  a.alpha(x, y),
                  255,
                  reason: '${kit.name} alt başlık ($x,$y)',
                );
              }
            }
            // sınır satırının hemen üstü gövde genişliğinin çoğunda boş: süs yalnızca küçük öğeler (baca, ışık)
            var deco = 0;
            for (var y = bc.y0; y < bc.y0 + boundary; y++) {
              for (var x = bc.x0 + ov; x < bc.x0 + ov + bw; x++) {
                if (a.alpha(x, y) > 0) deco++;
              }
            }
            expect(
              deco / (boundary * bw),
              lessThan(0.3),
              reason:
                  '${kit.name}: sınır üstü süs, hitbox gibi görünen geniş bir blok olmamalı',
            );
            // üst başlık: bütün satırlarda gövde sütunları opak (alt kenar = geçidin üst kenarı)
            final tc = _px(ObstacleKitLayout.topCap);
            for (var y = tc.y0; y < tc.y0 + tc.h; y++) {
              for (var x = tc.x0 + ov; x < tc.x0 + ov + bw; x++) {
                expect(
                  a.alpha(x, y),
                  255,
                  reason: '${kit.name} üst başlık ($x,$y)',
                );
              }
            }
            // taban: gövde sütunları opak
            final b = _px(ObstacleKitLayout.bottomBase);
            for (var y = b.y0; y < b.y0 + b.h; y++) {
              for (var x = b.x0 + ov; x < b.x0 + ov + bw; x++) {
                expect(a.alpha(x, y), 255, reason: '${kit.name} taban ($x,$y)');
              }
            }
          }
        });
      },
    );

    testWidgets(
      'gövde karoları dikey olarak dikişsiz döşenir (son satır → ilk satır geçişi iç geçişlerden sert değil)',
      (tester) async {
        await tester.runAsync(() async {
          for (final kit in ObstacleKitId.values) {
            final a = await _load(kit);
            for (final r in [
              ObstacleKitLayout.bottomBodyA,
              ObstacleKitLayout.bottomBodyB,
              ObstacleKitLayout.topBodyA,
              ObstacleKitLayout.topBodyB,
            ]) {
              final p = _px(r);
              int diff(int y1, int y2) {
                var n = 0;
                for (var x = p.x0; x < p.x0 + p.w; x++) {
                  if (a.rgb(x, y1) != a.rgb(x, y2)) n++;
                }
                return n;
              }

              var worst = 0;
              for (var y = p.y0; y < p.y0 + p.h - 1; y++) {
                worst = max(worst, diff(y, y + 1));
              }
              expect(
                diff(p.y0 + p.h - 1, p.y0),
                lessThanOrEqualTo(worst),
                reason: '${kit.name} $r',
              );
            }
          }
        });
      },
    );

    testWidgets(
      'bölgeler ve varyantlar birbirinden farklı (görsel çeşitlilik)',
      (tester) async {
        await tester.runAsync(() async {
          final signatures = <String>{};
          for (final kit in ObstacleKitId.values) {
            final a = await _load(kit);
            final bodies = <List<int>>[];
            for (final r in [
              ObstacleKitLayout.bottomBodyA,
              ObstacleKitLayout.bottomBodyB,
              ObstacleKitLayout.topBodyA,
              ObstacleKitLayout.topBodyB,
            ]) {
              final p = _px(r);
              bodies.add([
                for (var y = p.y0; y < p.y0 + p.h; y += 3)
                  for (var x = p.x0; x < p.x0 + p.w; x += 3) a.rgb(x, y),
              ]);
            }
            // A ve B varyantları ayırt edilebilir (en az %2 pikselde farklı: vurgu öğesi, bant, kapak vb.)
            for (final (i, j) in [(0, 1), (2, 3)]) {
              var d = 0;
              for (var k = 0; k < bodies[i].length; k++) {
                if (bodies[i][k] != bodies[j][k]) d++;
              }
              expect(d / bodies[i].length, greaterThan(0.02), reason: kit.name);
            }
            // renk zenginliği: bir gövde karosunda en az 12 farklı renk (kaba blok değil)
            for (final b in bodies) {
              expect(
                b.toSet().length,
                greaterThanOrEqualTo(12),
                reason: kit.name,
              );
            }
            signatures.add(bodies[0].take(400).join(','));
          }
          expect(signatures.length, ObstacleKitId.values.length);
        });
      },
    );
  });

  group('Geçit dengesi (erişilebilirlik simülasyonu)', () {
    // Oyunla aynı fizik ve çarpışma geometrisiyle kuşun ulaşabileceği tüm durumlar izlenir
    // (CourseValidator.explore). "Bant": engel yanında kuş merkezinin bulunabileceği yükseklik aralığı.
    test('yeni kurallar: 40 parkurun hepsi 100 engel boyunca geçilebilir, hiçbir engelde bant 80 birimden dar değil', () {
      for (var k = 0; k < 40; k++) {
        final bands = <double>[];
        final r = CourseValidator.explore(
          DailyCourse(_v2(k)),
          maxScore: 100,
          bands: bands,
        );
        expect(r.depth, 100, reason: 'parkur $k');
        expect(r.tightest, greaterThanOrEqualTo(80), reason: 'parkur $k');
      }
    });

    test('eski dengeye göre en dar anlar belirgin genişledi', () {
      double median(List<double> v) => (v..sort())[v.length ~/ 2];
      final oldWorst = <double>[], newWorst = <double>[];
      for (var k = 0; k < 24; k++) {
        oldWorst.add(
          CourseValidator.explore(DailyCourse(_v1(k)), maxScore: 100).tightest,
        );
        newWorst.add(
          CourseValidator.explore(DailyCourse(_v2(k)), maxScore: 100).tightest,
        );
      }
      expect(median(newWorst), greaterThan(median(oldWorst) + 30));
      expect(newWorst.reduce(min), greaterThan(oldWorst.reduce(min)));
    });

    test('klasik üretici aynı kurallarla: 3000 geçitte güvenli bant ve kayma sınırları', () {
      const c = GameConfig();
      final g = GapGenerator(c, random: Random(11));
      double? last;
      for (var i = 0; i < 3000; i++) {
        final score = i % 140;
        final gap = g.next(score);
        expect(gap.height, c.gapForScore(score));
        expect(gap.height, greaterThanOrEqualTo(c.minGap));
        expect(
          gap.center - gap.height / 2,
          greaterThanOrEqualTo(c.gapMarginTop - 1e-9),
        );
        expect(
          gap.center + gap.height / 2,
          lessThanOrEqualTo(c.worldHeight - c.gapMarginBottom + 1e-9),
        );
        if (last != null) {
          expect(last - gap.center, lessThanOrEqualTo(c.maxGapRise + 1e-9));
          expect(gap.center - last, lessThanOrEqualTo(c.maxGapDrop + 1e-9));
        }
        last = gap.center;
      }
    });

    test('bölge eğrisi: her bölge bir öncekinden dar ya da eşit, ilk bölge en geniş', () {
      const c = GameConfig();
      final starts = [
        for (final z in [0, 15, 35, 60, 90]) c.gapForScore(z),
      ];
      for (var i = 1; i < starts.length; i++) {
        expect(starts[i], lessThanOrEqualTo(starts[i - 1]));
      }
      expect(starts.first, c.startGap);
      expect(starts.last, c.minGap);
    });
  });

  group('Simit yerleşimi', () {
    test('büyük sıçramadan sonra simit, kuşun geldiği tarafa yakın yarıda', () {
      const c = GameConfig();
      final rnd = Random(5);
      for (var i = 0; i < 2000; i++) {
        final prev = 500.0 + rnd.nextDouble() * 900;
        final shift =
            (rnd.nextBool() ? 1 : -1) *
            (c.bigShift + 1 + rnd.nextDouble() * 100);
        final center = prev + shift;
        final band = PickupRules.reachableBand(
          config: c,
          gapCenter: center,
          gapHeight: c.minGap,
        )!;
        final y = PickupRules.positionInBand(
          config: c,
          band: band,
          roll: rnd.nextDouble(),
          gapCenter: center,
          previousCenter: prev,
        );
        expect(y, inInclusiveRange(band.top, band.bottom));
        final mid = (band.top + band.bottom) / 2;
        if (shift > 0) {
          expect(
            y,
            lessThanOrEqualTo(mid + 1e-9),
          ); // aşağı sıçrama: simit üst yarıda
        } else {
          expect(y, greaterThanOrEqualTo(mid - 1e-9));
        }
      }
    });

    test('küçük kaymada simit bandın orta %70\'inde (eski davranış)', () {
      const c = GameConfig();
      final band = PickupRules.reachableBand(
        config: c,
        gapCenter: 900,
        gapHeight: 330,
      )!;
      final span = band.bottom - band.top;
      for (final roll in [0.0, 0.25, 0.5, 0.75, 0.999]) {
        final y = PickupRules.positionInBand(
          config: c,
          band: band,
          roll: roll,
          gapCenter: 900,
          previousCenter: 900 + c.bigShift - 1,
        );
        expect(
          (y - (band.top + band.bottom) / 2).abs(),
          lessThanOrEqualTo(span * 0.35 + 1e-9),
        );
      }
    });
  });

  group('Küçük ekranlar', () {
    test('en dar ekranda bile kuş bir engelin içindeyken sıradaki engelin geçidi (en az yarısı) görünür', () {
      const c = GameConfig();
      // dünya yüksekliği her ekranda 1920: dar/uzun telefonlarda görünür genişlik azalır
      // desteklenen en uzun ekran: iPhone 9:19,5 (iPhone SE 1, SE 2, iPad de denenir)
      for (final aspect in [9 / 19.5, 320 / 568, 375 / 667, 3 / 4]) {
        final visible = c.worldHeight * aspect;
        final birdX = (visible * c.birdXFraction).clamp(c.birdMinX, c.birdMaxX);
        // kuş bir engelin ortasındayken sıradaki engelin sol yarısı (geçidin ağzı) görünür olmalı
        final nextRight = birdX + c.obstacleSpacing;
        expect(
          nextRight,
          lessThanOrEqualTo(visible + 1e-9),
          reason: 'oran $aspect',
        );
      }
    });

    test('geçit ve kuş ölçüleri ekrandan bağımsız (dünya birimi): en dar geçit kuş çapının 4 katından geniş', () {
      const c = GameConfig();
      expect(c.minGap / (2 * c.birdHitRadius), greaterThan(4));
    });
  });
}
