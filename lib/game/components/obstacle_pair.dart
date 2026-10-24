import 'dart:ui';

import 'package:flame/components.dart';

import '../day_cycle.dart';
import '../istanbul_flight_game.dart';
import 'obstacle_painter.dart';

/// Bir engel çifti: üstten sarkan + alttan yükselen, arada geçit.
/// Hitbox'lar iki dikdörtgendir ve çizimden bağımsız tanımlanır (çizim değişse de geometri aynı).
class ObstaclePair extends PositionComponent
    with HasGameReference<IstanbulFlightGame> {
  ObstaclePair({
    required double x,
    required this.gapCenter,
    required this.gapHeight,
    required double width,
    required double worldHeight,
    required this.kit,
    required this.seed,
  }) : super(
         position: Vector2(x, 0),
         size: Vector2(width, worldHeight),
         priority: 40,
       );

  final double gapCenter;
  final double gapHeight;

  /// Engelin üretildiği bölgenin sprite kiti (bölge değişse de engel kendi görünümünü korur).
  final ObstacleKitId kit;
  final int seed;

  /// Bu engel için puan verildi mi (bir kez).
  bool scored = false;

  /// Geçitteki toplanabilir simidin dikey konumu (yoksa null). Yatayda engelin ortasında durur.
  double? pickupY;

  /// Simit toplandı mı (bir kez).
  bool pickupTaken = false;

  double get pickupX => position.x + size.x / 2;
  bool get hasPickup => pickupY != null && !pickupTaken;

  /// Kuş bu engelin yanından geçerken ölçülen en küçük boşluk (kıl payı için).
  double minClearance = double.infinity;

  /// Kıl payı değerlendirmesi yapıldı mı (bir kez).
  bool nearMissChecked = false;

  /// Günün Uçuşu'nda parkurdaki sırası (klasikte -1). Konumu her adımda parkur koordinatından hesaplanır.
  int courseIndex = -1;

  double get gapTop => gapCenter - gapHeight / 2;
  double get gapBottom => gapCenter + gapHeight / 2;
  double get right => position.x + size.x;

  Rect get topRect => Rect.fromLTRB(position.x, -10000, right, gapTop);
  Rect get bottomRect =>
      Rect.fromLTRB(position.x, gapBottom, right, size.y + 10000);

  /// Görsel varyant (gövde karoları): 0..3.
  int get variant => (seed * 7 + 3) % 4;

  @override
  void render(Canvas canvas) {
    final atlas = game.art.kits[kit];
    if (atlas == null) {
      ObstaclePainter.paint(
        canvas,
        kit.fallbackStyle,
        game.palette,
        size.x,
        size.y,
        gapTop,
        gapBottom,
        seed,
      );
      return;
    }
    game.obstacleRenderer.render(
      canvas,
      atlas: atlas,
      kit: kit,
      variant: variant,
      width: size.x,
      worldHeight: size.y,
      gapTop: gapTop,
      gapBottom: gapBottom,
      time: game.time,
      seed: seed,
    );
  }
}
