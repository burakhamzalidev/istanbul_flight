import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../game_art.dart';
import '../istanbul_flight_game.dart';

/// Toplanabilir simitleri çizer (engel çiftlerinin geçidinde), pixel art efekt atlasından.
///
/// Can simitlerinden (kırmızı-beyaz, koyu kazığa sabit, hareketsiz) açıkça ayrışır:
/// altın-kahve halka, susamlar, etrafında dönen parıltılar, hafif salınım ve 4 karelik dönme.
/// Çarpışma alanı = [GameConfig.pickupRadius] (30) = sprite halkasının dış yarıçapı (7,5 px × 4).
/// Salınım sadece görseldir (±1 piksel), toplama hitbox'ı sabit konumdadır.
class PickupLayer extends Component with HasGameReference<IstanbulFlightGame> {
  PickupLayer() : super(priority: 44);

  static const frameTime = 0.16;
  final Paint _paint = pixelPaint();
  final Paint _sparkle = pixelPaint();
  final Paint _fallback = Paint()..color = const Color(0xFFD08A40);

  @override
  void render(Canvas canvas) {
    final fx = game.art.fx;
    final t = game.time;
    final r = game.config.pickupRadius;
    for (final o in game.obstacles) {
      final py = o.pickupY;
      if (py == null || o.pickupTaken) continue;
      final bob = snapPx(math.sin(t * 3 + o.seed) * 5);
      final cx = o.pickupX, cy = py + bob;
      if (fx == null) {
        canvas.drawRect(
          Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.8),
          _fallback,
        );
        continue;
      }
      final frame = ((t + o.seed * 0.13) / frameTime).floor() % 4;
      final src = GameArt.pickupFrame(frame);
      canvas.drawImageRect(
        fx,
        src,
        Rect.fromCenter(center: Offset(cx, cy), width: 80, height: 80),
        _paint,
      );
      // Etrafında dönen iki parıltı (toplanabilir olduğunu söyler)
      for (var k = 0; k < 2; k++) {
        final a = t * 1.6 + o.seed + k * math.pi;
        final pulse = 0.5 + 0.5 * math.sin(t * 5 + k * 2 + o.seed);
        _sparkle.color = Color.fromRGBO(0, 0, 0, 0.35 + 0.65 * pulse);
        final s = pulse > 0.6 ? GameArt.sparkleBig : GameArt.sparkleSmall;
        final x = snapPx(cx + math.cos(a) * 52) - 14,
            y = snapPx(cy + math.sin(a) * 44) - 14;
        canvas.drawImageRect(fx, s, Rect.fromLTWH(x, y, 28, 28), _sparkle);
      }
    }
  }
}
