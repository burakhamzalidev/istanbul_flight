import '../game_phase.dart';

/// Simit'in kare seçimi. Saf mantık, kare hızından bağımsız (sadece geçen süreye bakar).
///
/// Sprite sheet (art/_source/build_game_assets.js):
///  0–5  kanat döngüsü (yukarı → tam aşağı → toparlanma)
///  6    süzülme · 7 yükselme · 8 düşüş · 9 çarpışma · 10 göz kırpma · 11 oyun sonu (simit başında)
class SimitAnimator {
  static const flapCycle = [0, 1, 2, 3, 4, 5];
  static const flapFrameTime = 0.045; // dokunuşta hızlı tek vuruş (0,27 sn)
  static const idleFrameTime = 0.09; // menüde sakin, sürekli kanat
  static const glide = 6, rise = 7, fall = 8, hit = 9, blink = 10, landed = 11;

  /// Yükselme / düşüş karesine geçiş eşikleri (birim/s).
  static const riseVelocity = -250.0;
  static const fallVelocity = 700.0;

  static const blinkEvery = 3.2;
  static const blinkLength = 0.14;

  double _flapT = double.infinity;
  double _idleT = 0;
  double _blinkClock = 0;
  double _blinkT = -1;
  bool _hit = false;
  bool _landed = false;

  bool get isFlapping => _flapT < flapCycle.length * flapFrameTime;
  bool get isLanded => _landed;

  void flap() => _flapT = 0;
  void onHit() => _hit = true;
  void onLanded() => _landed = true;

  void reset() {
    _flapT = double.infinity;
    _idleT = 0;
    _blinkClock = 0;
    _blinkT = -1;
    _hit = false;
    _landed = false;
  }

  void update(double dt) {
    if (isFlapping) _flapT += dt;
    if (_blinkT >= 0) {
      _blinkT += dt;
      if (_blinkT >= blinkLength) _blinkT = -1;
    } else {
      _idleT += dt;
      _blinkClock += dt;
    }
  }

  int frame({required GamePhase phase, required double velocity}) {
    if (_landed) return landed;
    if (_hit) return hit;
    if (isFlapping) {
      return flapCycle[(_flapT / flapFrameTime).floor().clamp(
        0,
        flapCycle.length - 1,
      )];
    }
    if (phase == GamePhase.ready) {
      if (_blinkT >= 0) return blink;
      final f = flapCycle[(_idleT / idleFrameTime).floor() % flapCycle.length];
      // Göz kırpma, kanadı aynı konumda olan karede başlar (kare 2 ≈ kare 10): sıçrama olmaz
      if (f == 2 && _blinkClock >= blinkEvery) {
        _blinkClock = 0;
        _blinkT = 0;
        return blink;
      }
      return f;
    }
    if (velocity < riseVelocity) return rise;
    if (velocity > fallVelocity) return fall;
    return glide;
  }
}
