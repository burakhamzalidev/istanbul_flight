import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../services/audio_service.dart';
import '../game_art.dart';
import '../istanbul_flight_game.dart';
import '../logic/hazards.dart';
import 'obstacle_pair.dart';

/// Bir koridordaki dinamik engelin görünümü (Phase 2.6.3). Konumu bağlı olduğu engel çiftinden ([anchor])
/// hesaplanır: engelle birlikte kayar, kare hızından ve ekran genişliğinden bağımsızdır. Çarpışma ve rüzgâr
/// etkisi oyunun sabit fizik adımında hesaplanır; burada yalnızca çizim (ve sürünün bir kez çığlığı) var.
class HazardView extends Component with HasGameReference<IstanbulFlightGame> {
  HazardView(this.hazard, {required this.anchor}) : super(priority: 41);

  final Hazard hazard;

  /// Koridorun sonundaki engel çifti (koridor bunun hemen solunda).
  final ObstaclePair anchor;

  final Paint _p = Paint()..isAntiAlias = false;
  bool _announced = false;

  double get centerX => HazardRules.corridorCenterX(
    game.config,
    anchor.position.x,
    game.config.obstacleSpacing,
  );

  /// Sürünün o anki yatay merkezi (kuşa doğru uçar; çarpışmayla aynı kural).
  double get flockX =>
      HazardRules.flockCenterX(game.config, centerX, game.birdX);

  @override
  void update(double dt) {
    // sürü ekrana girerken bir kez çığlık atar (sesle de haber verir)
    if (!_announced &&
        hazard.kind == HazardKind.flock &&
        flockX - game.config.flockWidth / 2 < game.visibleWidth) {
      _announced = true;
      game.services.audio.playCue(AmbientCue.gull);
    }
  }

  @override
  void render(Canvas canvas) {
    switch (hazard.kind) {
      case HazardKind.flock:
        _renderFlock(canvas);
      case HazardKind.gust:
        _renderGust(canvas);
    }
  }

  /// Üç koyu sırtlı martı, Simit'e dönük ve ona doğru uçuyor (arkalarında hız çizgileri). Oyuncunun beyaz
  /// martısından ayrılsın diye sırt ve kanatlar koyu. Görsel ≈ [GameConfig.flockWidth] ×
  /// [GameConfig.flockHeight]; çarpışma kutusu bundan küçüktür (kanat uçlarına sürtmek affedilir).
  void _renderFlock(Canvas canvas) {
    final c = game.config;
    final cy = hazard.flockY(c, game.runTime);
    final cx = flockX;
    if (cx < -200 || cx > game.visibleWidth + 200) return;
    const offsets = [(-44.0, -18.0), (46.0, -22.0), (2.0, 20.0)];
    for (var i = 0; i < offsets.length; i++) {
      final (dx, dy) = offsets[i];
      final frame = ((game.time * 7 + i * 0.9) % 3).floor(); // kanat: yukarı, orta, aşağı
      _gull(canvas, snapPx(cx + dx), snapPx(cy + dy), frame, i);
    }
  }

  // 12×7 hücre (hücre 8 birim → 96×56), sola (Simit'e) dönük.
  // B gaga, E göz, H baş/gövde (beyaz), L karın gölgesi, G koyu sırt/kanat, T kanat ucu (siyah).
  static const _frames = [
    [
      '.......TT...',
      '......GGT...',
      '.HH..GGG....',
      'BEHHHGGHHTT.',
      '..LHHHHHHL..',
      '....LLLL....',
      '............',
    ],
    [
      '............',
      '............',
      '.HH.........',
      'BEHHGGGGGGTT',
      '..LHHHHHHLT.',
      '....LLLL....',
      '............',
    ],
    [
      '............',
      '............',
      '.HH.........',
      'BEHHHGGHHTT.',
      '..LHHGGGHL..',
      '.....GGT....',
      '......TT....',
    ],
  ];

  static const _colors = {
    'B': Color(0xFFF2B830),
    'E': Color(0xFF1E2228),
    'H': Color(0xFFF6F2EA),
    'L': Color(0xFFA8B0BC),
    'G': Color(0xFF3E4656),
    'T': Color(0xFF16191F),
  };

  void _gull(Canvas canvas, double x, double y, int frame, int i) {
    const px = kArtPx * 2;
    // hız çizgileri (arkada, sağda): sürünün kaydırmadan hızlı geldiğini anlatır
    final light = game.palette.light;
    final t = game.time;
    for (var k = 0; k < 3; k++) {
      final len = 18.0 + ((t * 9 + k * 2 + i) % 3) * 8;
      _p.color = light.withValues(alpha: 0.55 - k * 0.12);
      canvas.drawRect(
        Rect.fromLTWH(
          snapPx(x + 6.5 * px + k * 6),
          snapPx(y + (k - 1) * px * 1.5),
          snapPx(len),
          kArtPx,
        ),
        _p,
      );
    }
    final rows = _frames[frame];
    for (var r = 0; r < rows.length; r++) {
      for (var k = 0; k < rows[r].length; k++) {
        final col = _colors[rows[r][k]];
        if (col == null) continue;
        _p.color = col;
        canvas.drawRect(
          Rect.fromLTWH(x + (k - 6) * px, y + (r - 3.5) * px, px, px),
          _p,
        );
      }
    }
  }

  /// Hava akımı: koridor boyunca akan rüzgâr şeritleri, akımın yönünde kavislenir (yükselen akımda yukarı
  /// kemer, alçalan akımda aşağı). Kavis, kuşa uygulanan ivmeyle aynı sin² eğrisini izler: en güçlü yer en
  /// çok bükülen yer. Şeritlerde akan kesikler ve savrulan yapraklar.
  void _renderGust(Canvas canvas) {
    final c = game.config;
    final width = c.obstacleSpacing - c.obstacleWidth;
    final left = anchor.position.x - width;
    if (left > game.visibleWidth + 40 || left + width < -40) return;
    final dir = hazard.accel < 0 ? -1.0 : 1.0; // − yukarı, + aşağı
    final light = game.palette.light;
    const px = kArtPx;
    final t = game.time;
    const arch = 150.0; // şeridin ortadaki bükülmesi
    double yAt(double y0, double u) {
      final s = math.sin(math.pi * u);
      return y0 + dir * arch * s * s;
    }

    const ribbons = 7;
    for (var k = 0; k < ribbons; k++) {
      final y0 = 220 + k * (c.worldHeight - 440) / (ribbons - 1);
      // şeridin kendisi: çok soluk sürekli iz
      _p.color = light.withValues(alpha: 0.16);
      for (var u = 0.0; u <= 1.0; u += 0.02) {
        canvas.drawRect(
          Rect.fromLTWH(
            snapPx(left + u * width),
            snapPx(yAt(y0, u)),
            px * 3,
            px,
          ),
          _p,
        );
      }
      // akan kesikler: sağdan sola (kuşa doğru) akar
      for (var d = 0; d < 2; d++) {
        final head = 1 - ((t * 0.55 + k * 0.37 + d * 0.5) % 1.0);
        for (var j = 0; j < 10; j++) {
          final u = head + j * 0.012;
          if (u < 0 || u > 1) continue;
          _p.color = light.withValues(alpha: 0.75 * (1 - j / 10));
          canvas.drawRect(
            Rect.fromLTWH(
              snapPx(left + u * width),
              snapPx(yAt(y0, u)),
              px * 2,
              px,
            ),
            _p,
          );
        }
      }
      // savrulan yaprak: şeridi kesiklerden hızlı izler
      if (k.isOdd) {
        final u = 1 - ((t * 0.8 + k * 0.21) % 1.0);
        final flip = ((t * 6 + k) % 2) < 1;
        _p.color = const Color(0xFF8ABA5A);
        canvas.drawRect(
          Rect.fromLTWH(
            snapPx(left + u * width),
            snapPx(yAt(y0, u) - px),
            px * 2,
            px * 2,
          ),
          _p,
        );
        _p.color = const Color(0xFF5E8E3A);
        canvas.drawRect(
          Rect.fromLTWH(
            snapPx(left + u * width + (flip ? px * 2 : -px)),
            snapPx(yAt(y0, u) + (flip ? -px : px)),
            px,
            px,
          ),
          _p,
        );
      }
    }
  }
}
