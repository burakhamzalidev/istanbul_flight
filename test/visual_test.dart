import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/game/day_cycle.dart';
import 'package:istanbul_flight/game/game_art.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/components/landmark_layer.dart';
import 'package:istanbul_flight/game/visual/crossfade.dart';
import 'package:istanbul_flight/game/visual/obstacle_kit_layout.g.dart';
import 'package:istanbul_flight/game/visual/obstacle_renderer.dart';
import 'package:istanbul_flight/game/visual/simit_animator.dart';

/// PNG başlığından genişlik/yükseklik.
(int, int) _pngSize(String path) {
  final b = File(path).readAsBytesSync();
  final d = ByteData.sublistView(b);
  return (d.getUint32(16), d.getUint32(20));
}

void main() {
  group('Crossfade', () {
    test('geçiş, süre sonunda tamamlanır ve öncekini bırakır', () {
      final f = Crossfade<int>(1, duration: 2);
      expect(f.isActive, isFalse);
      f.set(2);
      expect(f.current, 2);
      expect(f.previous, 1);
      expect(f.alpha, 0);
      f.update(1);
      expect(f.alpha, closeTo(0.5, 1e-9));
      expect(f.previousAlpha, closeTo(0.5, 1e-9));
      f.update(1.01);
      expect(f.isActive, isFalse);
      expect(f.alpha, 1);
    });

    test('kare hızından bağımsız', () {
      final a = Crossfade<int>(0, duration: 2.5)..set(1);
      final b = Crossfade<int>(0, duration: 2.5)..set(1);
      for (var i = 0; i < 30; i++) {
        a.update(1 / 30);
      }
      for (var i = 0; i < 144; i++) {
        b.update(1 / 144);
      }
      expect(a.alpha, closeTo(b.alpha, 1e-9));
    });

    test('geçiş sırasında yeni hedef: aynı anda en fazla iki katman', () {
      final f = Crossfade<int>(0, duration: 2)..set(1);
      f.update(0.2);
      f.set(2); // 1 henüz baskın değil → önceki 0 kalır, hedef 2 olur
      expect(f.previous, 0);
      expect(f.current, 2);
      f.snap(4);
      expect(f.isActive, isFalse);
      expect(f.current, 4);
    });
  });

  group('SimitAnimator', () {
    test('dokunuşta 6 farklı kanat karesi, sonra süzülme', () {
      final a = SimitAnimator()..flap();
      final seen = <int>{};
      for (var i = 0; i < 40; i++) {
        seen.add(a.frame(phase: GamePhase.playing, velocity: 0));
        a.update(1 / 120);
      }
      expect(seen, containsAll(SimitAnimator.flapCycle));
      expect(
        a.frame(phase: GamePhase.playing, velocity: 0),
        SimitAnimator.glide,
      );
    });

    test('kare hızından bağımsız: aynı anda aynı kare', () {
      List<int> sample(int fps) {
        final a = SimitAnimator()..flap();
        final out = <int>[];
        var t = 0.0;
        var next = 0.0;
        for (var i = 0; i < fps; i++) {
          if (t >= next - 1e-9) {
            out.add(a.frame(phase: GamePhase.playing, velocity: 0));
            next += 0.1;
          }
          a.update(1 / fps);
          t += 1 / fps;
        }
        return out;
      }

      expect(sample(30), sample(120));
    });

    test(
      'yükselme / düşüş / süzülme eşikleri, çarpışma ve oyun sonu önceliği',
      () {
        final a = SimitAnimator();
        expect(
          a.frame(phase: GamePhase.playing, velocity: -600),
          SimitAnimator.rise,
        );
        expect(
          a.frame(phase: GamePhase.playing, velocity: 900),
          SimitAnimator.fall,
        );
        expect(
          a.frame(phase: GamePhase.playing, velocity: 100),
          SimitAnimator.glide,
        );
        a.onHit();
        expect(
          a.frame(phase: GamePhase.gameOver, velocity: 900),
          SimitAnimator.hit,
        );
        a.onLanded();
        expect(
          a.frame(phase: GamePhase.gameOver, velocity: 0),
          SimitAnimator.landed,
        );
        a.reset();
        expect(
          a.frame(phase: GamePhase.playing, velocity: 0),
          SimitAnimator.glide,
        );
      },
    );

    test(
      'menüde göz kırpar, kırpma sadece kanat kare 2 konumundayken başlar',
      () {
        final a = SimitAnimator();
        var blinked = false;
        var previous = -1;
        for (var i = 0; i < 60 * 5; i++) {
          final f = a.frame(phase: GamePhase.ready, velocity: 0);
          if (f == SimitAnimator.blink && previous != SimitAnimator.blink) {
            blinked = true;
            expect(
              previous,
              anyOf(1, 2),
              reason: 'kırpma kanat orta konumdayken başlamalı',
            );
          }
          previous = f;
          a.update(1 / 60);
        }
        expect(blinked, isTrue);
      },
    );
  });

  group('Engel sprite yerleşimi hitbox ile uyumlu', () {
    const width = 196.0, worldH = 1920.0;
    for (final kit in ObstacleKitId.values) {
      for (final gap in [
        (top: 230.0, bottom: 570.0),
        (top: 900.0, bottom: 1200.0),
        (top: 1400.0, bottom: 1690.0),
      ]) {
        test('${kit.name} geçit ${gap.top.toInt()}–${gap.bottom.toInt()}', () {
          for (var variant = 0; variant < 4; variant++) {
            final rects = <(ui.Rect, ui.Rect)>[];
            ObstaclePiecePlan.forEach(
              kit: kit,
              variant: variant,
              width: width,
              worldHeight: worldH,
              gapTop: gap.top,
              gapBottom: gap.bottom,
              visit: (s, d) => rects.add((s, d)),
            );
            final boundary = ObstacleKitLayout.bottomCapBoundary[kit.name]!;
            for (final (src, dst) in rects) {
              // Taşma sınırı
              expect(
                dst.left,
                greaterThanOrEqualTo(-ObstacleKitLayout.overhang - 1e-9),
              );
              expect(
                dst.right,
                lessThanOrEqualTo(width + ObstacleKitLayout.overhang + 1e-9),
              );
              // Geçide sadece alt başlığın çarpışmasız süsü girebilir (≤ boundary)
              final intrusion =
                  (dst.bottom.clamp(gap.top, gap.bottom) -
                  dst.top.clamp(gap.top, gap.bottom));
              if (intrusion > 0) {
                expect(src, ObstacleKitLayout.bottomCap);
                expect(gap.bottom - dst.top, closeTo(boundary, 1e-9));
              }
              // Kaynak, atlas satır 0 içinde
              expect(src.top, greaterThanOrEqualTo(0));
              expect(
                src.bottom,
                lessThanOrEqualTo(ObstacleKitLayout.lightsOffsetY),
              );
            }
            // Başlık hizası
            final top = rects
                .firstWhere((r) => r.$1 == ObstacleKitLayout.topCap)
                .$2;
            expect(top.bottom, closeTo(gap.top, 1e-9));
            // Kesintisiz kaplama: [0, gapTop] ve [gapBottom, H]
            double covered(double a, double b) {
              final ivs =
                  rects
                      .map(
                        (r) => (r.$2.top.clamp(a, b), r.$2.bottom.clamp(a, b)),
                      )
                      .where((iv) => iv.$2 > iv.$1)
                      .toList()
                    ..sort((x, y) => x.$1.compareTo(y.$1));
              var end = a, sum = 0.0;
              for (final (s, e) in ivs) {
                if (e <= end) continue;
                sum += e - (s > end ? s : end);
                end = e;
              }
              return sum;
            }

            expect(covered(0, gap.top), closeTo(gap.top, 0.5));
            expect(
              covered(gap.bottom, worldH),
              closeTo(worldH - gap.bottom, 0.5),
            );
          }
        });
      }
    }
  });

  group('Bölgeler', () {
    test('beş bölgenin her biri kendine özgü simge, kit ve kıyıya sahip', () {
      expect(zones.map((z) => z.landmark).toSet().length, 5);
      expect(zones.map((z) => z.kit).toSet().length, 5);
      expect(zones.map((z) => z.shore).toSet().length, 5);
      expect(
        zones.last.landmark,
        Landmark.rumeliHisari,
        reason: '5. bölge köprüyü tekrar kullanmamalı',
      );
    });

    test('palet geçişinde atmosfer değerleri de karışır', () {
      final mid = PhasePalette.lerp(zones[3].palette, zones[4].palette, 0.5);
      expect(
        mid.stars,
        closeTo((zones[3].palette.stars + zones[4].palette.stars) / 2, 1e-9),
      );
      expect(mid.moon, inInclusiveRange(0, 1));
    });
  });

  group('Asset dosyaları', () {
    test('bütün asset yolları mevcut', () {
      for (final p in GameArt.allPaths) {
        expect(File('assets/images/$p').existsSync(), isTrue, reason: p);
      }
    });

    // Görev 6 (docs/08): asset seti pixel art'a geçti. Boyutlar artık art pikseli cinsinden;
    // oyunda 4× (kArtPx) en yakın komşu ölçekle çizilir.
    test('pixel art boyutları yerleşimle uyumlu (1 px = 4 dünya birimi, ≤ 512 px)', () {
      final f = GameArt.simitFrameSize;
      expect(_pngSize('assets/images/${GameArt.simitPath}'), (
        (f.width * 6).toInt(),
        (f.height * 2).toInt(),
      ));
      for (final k in ObstacleKitId.values) {
        final (w, h) = _pngSize('assets/images/${GameArt.kitPath(k)}');
        // Atlas = yerleşim × atlasScale: en sağdaki parça (taban) ve en uzun parça sığmalı
        expect(w * 4, greaterThanOrEqualTo(ObstacleKitLayout.bottomBase.right));
        expect(h * 4, greaterThanOrEqualTo(ObstacleKitLayout.baseHeight));
        expect(ObstacleKitLayout.atlasScale, 1 / kArtPx);
      }
      for (final l in Landmark.values) {
        final (w, h) = _pngSize('assets/images/${GameArt.landmarkPath(l)}');
        final lay = LandmarkLayer.layout(l);
        expect((w * kArtPx, h * kArtPx), (lay.w, lay.h), reason: l.name);
      }
      for (final k in ObstacleKitId.values) {
        // Bütün bölgelerde aynı şerit yükseklikleri (piksel yoğunluğu tutarlı)
        expect(
          _pngSize('assets/images/${GameArt.zonePath(k.name, 'water')}').$2 *
              kArtPx,
          closeTo(1920 - 1190, 4),
        );
        expect(
          _pngSize('assets/images/${GameArt.zonePath(k.name, 'sky')}').$2 *
              kArtPx,
          closeTo(1190, 4),
        );
      }
      for (final p in GameArt.allPaths) {
        final (w, h) = _pngSize('assets/images/$p');
        expect(w, lessThanOrEqualTo(512), reason: p);
        expect(h, lessThanOrEqualTo(512), reason: p);
      }
    });

    testWidgets(
      'döşenebilir şeritler dikişsiz: kenar geçişi iç geçişlerden sert değil',
      (tester) async {
        await tester.runAsync(() async {
          final paths = [
            for (final k in ObstacleKitId.values)
              for (final l in ['distant', 'midground', 'waterfront', 'water'])
                GameArt.zonePath(k.name, l),
          ];
          for (final p in paths) {
            final codec = await ui.instantiateImageCodec(
              File('assets/images/$p').readAsBytesSync(),
            );
            final img = (await codec.getNextFrame()).image;
            final data = (await img.toByteData())!;
            final w = img.width;
            final h = img.height;
            bool opaque(int x, int y) =>
                data.getUint8((y * w + x) * 4 + 3) > 127;
            int diff(int x1, int x2) {
              var n = 0;
              for (var y = 0; y < h; y++) {
                if (opaque(x1, y) != opaque(x2, y)) n++;
              }
              return n;
            }

            // Dikiş (son sütun → ilk sütun), şeridin içindeki en sert komşu sütun geçişinden
            // daha sert olmamalı: binalar arası doğal aralar sayılmaz, gerçek kopukluk yakalanır.
            var worstInterior = 0;
            for (var x = 0; x < w - 1; x++) {
              final d = diff(x, x + 1);
              if (d > worstInterior) worstInterior = d;
            }
            final seam = diff(w - 1, 0);
            expect(
              seam,
              lessThanOrEqualTo(worstInterior),
              reason: '$p dikiş farkı $seam satır, iç en kötü $worstInterior',
            );
          }
        });
      },
    );
  });
}
