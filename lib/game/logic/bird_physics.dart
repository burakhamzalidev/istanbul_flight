import '../config.dart';

/// Simit'in dikey fiziği. Flame'den bağımsız, sabit adımla ilerletilir.
class BirdPhysics {
  BirdPhysics(this.config, {required this.y});

  final GameConfig config;
  double y;
  double velocity = 0;

  void flap() => velocity = config.flapVelocity;

  /// [dt] saniye ilerletir. Tavana çarpmak ölüm değildir, karakter tavanda tutulur.
  void step(double dt) {
    velocity = (velocity + config.gravity * dt).clamp(
      -double.infinity,
      config.maxFallSpeed,
    );
    y += velocity * dt;
    final top = config.birdHitRadius;
    if (y < top) {
      y = top;
      if (velocity < 0) velocity = 0;
    }
  }

  /// Karakter suya (dünyanın alt kenarına) ulaştı mı?
  bool get hitsWater => y + config.birdHitRadius >= config.worldHeight;

  void reset(double startY) {
    y = startY;
    velocity = 0;
  }
}
