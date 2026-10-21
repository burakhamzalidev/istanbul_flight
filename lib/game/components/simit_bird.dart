import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../game_art.dart';
import '../istanbul_flight_game.dart';
import '../visual/simit_animator.dart';

/// Simit'in görseli: kare seçimi [SimitAnimator]'da, burada eğim, suda salınım ve çizim.
/// Fizik [IstanbulFlightGame] içinde sabit adımla işlenir; bu bileşen sadece gösterir.
///
/// Pixel art kuralları (docs/08): kare 48×42 px, 4× ölçek (192×168 dünya birimi), en yakın komşu
/// örnekleme. Konum piksel ızgarasına, eğim [tiltStep] adımlarına oturtulur → döndürülmüş
/// sprite'ta kare kare titreme (shimmer) olmaz.
class SimitBird extends PositionComponent
    with HasGameReference<IstanbulFlightGame> {
  SimitBird({required this.art, required double displayWidth})
    : super(
        size: Vector2(
          displayWidth,
          displayWidth *
              GameArt.simitFrameSize.height /
              GameArt.simitFrameSize.width,
        ),
        anchor: Anchor(
          GameArt.simitPivot.dx / GameArt.simitFrameSize.width,
          GameArt.simitPivot.dy / GameArt.simitFrameSize.height,
        ),
        priority: 50,
      );

  /// Eğim adımı (radyan, ≈ 7,5°).
  static const tiltStep = math.pi / 24;

  final GameArt art;
  final SimitAnimator animator = SimitAnimator();
  int frame = SimitAnimator.glide;
  double _landedT = 0;
  double _velocity = 0;
  double _tilt = 0;

  final Paint _paint = pixelPaint();

  void onFlap() => animator.flap();
  void onHit() => animator.onHit();
  void onLanded() {
    animator.onLanded();
    _landedT = 0;
  }

  void reset() {
    animator.reset();
    angle = 0;
    _tilt = 0;
    _landedT = 0;
  }

  /// Fizikten konum ve eğimi alır. Yükselişte burun hafif yukarı, düşüşte giderek aşağı,
  /// suya düşünce düzelir ve dalgayla salınır.
  void sync({
    required double x,
    required double y,
    required double velocity,
    required double maxFall,
    required bool idle,
  }) {
    _velocity = velocity;
    if (animator.isLanded) {
      position.setValues(snapPx(x), snapPx(y + math.sin(_landedT * 2.4) * 6));
      _tilt += (math.sin(_landedT * 1.8) * 0.08 - _tilt) * 0.15;
    } else {
      position.setValues(snapPx(x), snapPx(y));
      final double target;
      if (idle) {
        target = 0;
      } else if (velocity < 0) {
        target = -0.32;
      } else {
        target = (velocity / maxFall * 1.35).clamp(
          0.0,
          frame == SimitAnimator.hit ? 1.5 : 1.15,
        );
      }
      _tilt += (target - _tilt) * (idle ? 1 : 0.22);
    }
    angle = (_tilt / tiltStep).roundToDouble() * tiltStep;
  }

  @override
  void update(double dt) {
    animator.update(dt);
    if (animator.isLanded) _landedT += dt;
    frame = animator.frame(phase: game.phase.value, velocity: _velocity);
  }

  @override
  void render(Canvas canvas) {
    final sheet = art.simitSheet;
    if (sheet == null) {
      _renderPlaceholder(canvas);
      return;
    }
    canvas.drawImageRect(
      sheet,
      GameArt.simitFrameRect(frame),
      size.toRect(),
      _paint,
    );
  }

  /// Asset yoksa: aynı oranlarda basit, köşeli Simit (gövde, gaga, simit halkası).
  void _renderPlaceholder(Canvas canvas) {
    final c = Offset(size.x * anchor.x, size.y * anchor.y);
    final r = size.x * 0.29;
    canvas.drawRect(
      Rect.fromCircle(center: c, radius: r),
      Paint()..color = const Color(0xFFF7F3EA),
    );
    canvas.drawRect(
      Rect.fromLTWH(c.dx + r, c.dy - r * 0.3, r * 0.6, r * 0.35),
      Paint()..color = const Color(0xFFF2C23B),
    );
    canvas.drawRect(
      Rect.fromLTWH(c.dx, c.dy + r * 0.2, r * 0.7, r * 0.5),
      Paint()..color = const Color(0xFFC8803A),
    );
  }
}
