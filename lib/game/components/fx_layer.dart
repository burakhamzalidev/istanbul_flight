import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../game_art.dart';
import '../istanbul_flight_game.dart';

enum _FxKind { feather, droplet, sparkle, ring }

class _Particle {
  bool active = false;
  _FxKind kind = _FxKind.feather;
  double x = 0,
      y = 0,
      vx = 0,
      vy = 0,
      rot = 0,
      vr = 0,
      life = 0,
      maxLife = 1,
      size = 1;
}

/// Ölçülü mikro efektler: kanat çırpınca kopan tek tük tüy, suya düşünce sıçrama.
/// Sabit boyutlu havuz (24): oyun boyunca yeni nesne üretilmez. Süreye bağlı, kare hızından bağımsız.
class FxLayer extends Component with HasGameReference<IstanbulFlightGame> {
  FxLayer() : super(priority: 45);

  static const poolSize = 24;
  final List<_Particle> _pool = List.generate(poolSize, (_) => _Particle());
  final math.Random _rnd = math.Random(5);
  final Paint _fill = Paint();
  final Paint _sprite = pixelPaint();

  int get activeCount => _pool.where((p) => p.active).length;

  _Particle? _take() {
    for (final p in _pool) {
      if (!p.active) return p;
    }
    return null; // havuz doluysa efekt atlanır (oyunu etkilemez)
  }

  /// Kanat çırpma: Simit'in sırtından geriye doğru süzülen bir tüy (her vuruşta değil).
  void feather(double x, double y) {
    if (_rnd.nextDouble() > 0.45) return;
    final p = _take();
    if (p == null) return;
    p
      ..active = true
      ..kind = _FxKind.feather
      ..x = x - 40
      ..y = y - 10
      ..vx = -120 - _rnd.nextDouble() * 80
      ..vy = -40 + _rnd.nextDouble() * 60
      ..rot = _rnd.nextDouble() * math.pi
      ..vr = (_rnd.nextDouble() - 0.5) * 6
      ..life = 0
      ..maxLife = 0.9 + _rnd.nextDouble() * 0.4
      ..size = 0.8 + _rnd.nextDouble() * 0.5;
  }

  /// Suya düşüş: kısa bir damla sıçraması.
  void splash(double x, double y) {
    for (var i = 0; i < 10; i++) {
      final p = _take();
      if (p == null) return;
      final a = -math.pi / 2 + (_rnd.nextDouble() - 0.5) * 1.6;
      final v = 380 + _rnd.nextDouble() * 320;
      p
        ..active = true
        ..kind = _FxKind.droplet
        ..x = x + (_rnd.nextDouble() - 0.5) * 50
        ..y = y
        ..vx = math.cos(a) * v
        ..vy = math.sin(a) * v
        ..life = 0
        ..maxLife = 0.55 + _rnd.nextDouble() * 0.3
        ..size = 5 + _rnd.nextDouble() * 6;
    }
  }

  /// Simit toplama: genişleyen altın halka + dışa saçılan susam parıltıları.
  void collect(double x, double y) {
    _ring(x, y, color: 0xFFE8B04B, maxLife: 0.35, size: 26);
    final n = game.reduceMotion ? 3 : 6;
    for (var i = 0; i < n; i++) {
      final p = _take();
      if (p == null) return;
      final a = i / n * math.pi * 2 + _rnd.nextDouble() * 0.4;
      p
        ..active = true
        ..kind = _FxKind.sparkle
        ..x = x
        ..y = y
        ..vx = math.cos(a) * 260
        ..vy = math.sin(a) * 260
        ..rot = a
        ..life = 0
        ..maxLife = 0.4
        ..size = 1;
    }
  }

  /// Kıl payı: Simit'in çevresinde kısa beyaz halka.
  void nearMiss(double x, double y) =>
      _ring(x, y, color: 0xFFFFFFFF, maxLife: 0.3, size: 40);

  void _ring(
    double x,
    double y, {
    required int color,
    required double maxLife,
    required double size,
  }) {
    final p = _take();
    if (p == null) return;
    p
      ..active = true
      ..kind = _FxKind.ring
      ..x = x
      ..y = y
      ..vx = 0
      ..vy = 0
      ..rot = color.toDouble()
      ..life = 0
      ..maxLife = maxLife
      ..size = size;
  }

  /// Çarpışma flaşı (0,15 sn). Azaltılmış hareket ayarında çağrılmaz.
  void flash() => _flash = 1;
  double _flash = 0;

  void clear() {
    for (final p in _pool) {
      p.active = false;
    }
    _flash = 0;
  }

  @override
  void update(double dt) {
    if (_flash > 0) _flash = math.max(0, _flash - dt / 0.15);
    final drift = game.frameScroll; // dünya kayarken efektler de geride kalır
    for (final p in _pool) {
      if (!p.active) continue;
      p.life += dt;
      if (p.life >= p.maxLife) {
        p.active = false;
        continue;
      }
      switch (p.kind) {
        case _FxKind.feather:
          p.vy += 160 * dt;
          p.vx *= math.pow(0.4, dt).toDouble();
          p.rot += p.vr * dt;
        case _FxKind.droplet:
          p.vy += 1800 * dt;
        case _FxKind.sparkle:
          p.vx *= math.pow(0.05, dt).toDouble();
          p.vy *= math.pow(0.05, dt).toDouble();
        case _FxKind.ring:
          break;
      }
      p.x += p.vx * dt - drift;
      p.y += p.vy * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final atlas = game.art.fx;
    for (final p in _pool) {
      if (!p.active) continue;
      final fade = 1 - p.life / p.maxLife;
      final x = snapPx(p.x), y = snapPx(p.y);
      if (p.kind == _FxKind.ring) {
        final t = p.life / p.maxLife;
        final color = Color(p.rot.toInt());
        if (atlas != null && color.toARGB32() != 0xFFFFFFFF) {
          // Altın toplama halkası: 4 karelik sprite
          _sprite.color = Color.fromRGBO(0, 0, 0, fade);
          final src = GameArt.ringFrame(
            (t * 4).floor().clamp(0, 3),
            gold: true,
          );
          canvas.drawImageRect(
            atlas,
            src,
            Rect.fromCenter(center: Offset(x, y), width: 128, height: 128),
            _sprite,
          );
        } else {
          // Kıl payı halkası: piksel ızgarasına oturan nokta halka (Simit'i çevreler)
          _fill.color = color.withValues(alpha: fade * 0.9);
          final rr = p.size * (1 + t * 1.6) + 40;
          final n = (rr * 0.25).round();
          for (var k = 0; k < n; k++) {
            final a = k / n * math.pi * 2;
            canvas.drawRect(
              Rect.fromLTWH(
                snapPx(x + math.cos(a) * rr),
                snapPx(y + math.sin(a) * rr),
                kArtPx,
                kArtPx,
              ),
              _fill,
            );
          }
        }
        continue;
      }
      if (atlas == null) {
        _fill.color = const Color(0xFFFFFFFF).withValues(alpha: fade);
        canvas.drawRect(Rect.fromLTWH(x, y, kArtPx * 2, kArtPx * 2), _fill);
        continue;
      }
      _sprite.color = Color.fromRGBO(0, 0, 0, fade);
      switch (p.kind) {
        case _FxKind.sparkle:
          canvas.drawImageRect(
            atlas,
            GameArt.sparkleBig,
            Rect.fromCenter(center: Offset(x, y), width: 28, height: 28),
            _sprite,
          );
        case _FxKind.feather:
          // Dönme 45° adımlarla: küçük sprite'ta piksel titremesi olmaz
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(
            (p.rot / (math.pi / 4)).roundToDouble() * (math.pi / 4),
          );
          canvas.drawImageRect(
            atlas,
            GameArt.featherRect,
            const Rect.fromLTWH(-12, -20, 24, 40),
            _sprite,
          );
          canvas.restore();
        case _FxKind.droplet:
          final s = p.size > 8 ? 12.0 : 8.0;
          canvas.drawImageRect(
            atlas,
            GameArt.dropRect,
            Rect.fromLTWH(x, y, s, s),
            _sprite,
          );
        case _FxKind.ring:
          break;
      }
    }
    if (_flash > 0) {
      _fill.color = const Color(0xFFFFFFFF).withValues(alpha: _flash * 0.55);
      canvas.drawRect(
        Rect.fromLTWH(
          -40,
          -40,
          game.visibleWidth + 80,
          game.config.worldHeight + 80,
        ),
        _fill,
      );
    }
  }
}
