import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../game_art.dart';
import '../istanbul_flight_game.dart';
import '../weather.dart';

/// Hava durumu katmanı (Phase 2.6.3): yağmur, sis, rüzgâr. Engellerin ARKASINDA çizilir (öncelik 39 < 40):
/// hiçbir efekt engeli örtmez. Nesne üretmez: bütün parçacıklar sıradan ve zamandan hesaplanır (sabit sayıda
/// dikdörtgen). Hava değişince yoğunluk [fadeTime] saniyede yumuşakça geçer.
class WeatherLayer extends Component with HasGameReference<IstanbulFlightGame> {
  WeatherLayer() : super(priority: 39);

  static const fadeTime = 2.0;
  static const rainDrops = 48, windBits = 24;

  Weather _current = Weather.clear;
  Weather _target = Weather.clear;
  double _level = 0; // 0..1 (mevcut havanın yoğunluğu)
  final Paint _p = Paint()..isAntiAlias = false;
  final List<Path> _rainPaths = [Path(), Path(), Path()];

  Weather get weather => _target;

  /// Yeni hava: önce mevcut sönümlenir, sonra yenisi belirir.
  void setWeather(Weather w) => _target = w;

  void snap(Weather w) {
    _current = _target = w;
    _level = w == Weather.clear ? 0 : 1;
  }

  @override
  void update(double dt) {
    if (_current != _target) {
      _level = math.max(0, _level - dt / fadeTime);
      if (_level == 0) _current = _target;
    } else if (_current != Weather.clear) {
      _level = math.min(1, _level + dt / fadeTime);
    }
  }

  @override
  void render(Canvas canvas) {
    if (_level <= 0 || _current == Weather.clear) return;
    switch (_current) {
      case Weather.rain:
        _rain(canvas);
      case Weather.fog:
        _fog(canvas);
      case Weather.windy:
        _wind(canvas);
      case Weather.clear:
        break;
    }
  }

  double get _w => game.visibleWidth;
  double get _h => game.config.worldHeight;

  void _rain(Canvas canvas) {
    final t = game.time;
    final col = Color.lerp(
      game.palette.skyHorizon,
      const Color(0xFFFFFFFF),
      0.6,
    )!;
    const px = kArtPx;
    // kapalı hava: hafif gri ton (engellerin arkasında; yalnızca arka planı soluklaştırır)
    _p.color = const Color(0xFF4A5A70).withValues(alpha: 0.14 * _level);
    canvas.drawRect(Rect.fromLTWH(0, 0, _w, _h), _p);
    // üç saydamlık grubu → üç yol (kare başına 144 yerine 3 çizim çağrısı; docs/19 §8)
    for (final p in _rainPaths) {
      p.reset();
    }
    for (var k = 0; k < rainDrops; k++) {
      final speed = 1500 + (k % 5) * 160;
      final x0 = ((k * 7919) % 1000) / 1000 * (_w + 300);
      final y = ((t * speed + k * 397) % (_h + 200)) - 100;
      final x =
          (x0 - (y * 0.25) - t * 120) % (_w + 300) -
          150; // hafif eğik düşüş, akışla birlikte
      for (var s = 0; s < 3; s++) {
        _rainPaths[k % 3].addRect(
          Rect.fromLTWH(
            snapPx(x - s * px * 0.75),
            snapPx(y + s * px * 3),
            px,
            px * 3,
          ),
        );
      }
    }
    for (var g = 0; g < 3; g++) {
      _p.color = col.withValues(alpha: (0.3 + g * 0.08) * _level);
      canvas.drawPath(_rainPaths[g], _p);
    }
  }

  void _fog(Canvas canvas) {
    final col = Color.lerp(
      game.palette.skyHorizon,
      const Color(0xFFFFFFFF),
      0.45,
    )!;
    final drift = game.scrollDistance * 0.15 + game.time * 10;
    final horizon = game.config.horizonY;
    // ufukta genel pus, üstünde kayan sis bantları (hepsi engellerin arkasında)
    _p.color = col.withValues(alpha: 0.12 * _level);
    canvas.drawRect(
      Rect.fromLTWH(0, snapPx(horizon - 360), _w, 640),
      _p,
    );
    for (var i = 0; i < 8; i++) {
      final y = snapPx(horizon - 320 + i * 72);
      const seg = 720.0;
      final off = (drift * (1 + i * 0.2)) % seg;
      _p.color = col.withValues(alpha: (0.3 - (i - 3.5).abs() * 0.04) * _level);
      for (var x = -off - seg; x < _w + seg; x += seg) {
        final bx = x + i * 110;
        canvas.drawRect(
          Rect.fromLTWH(snapPx(bx), y, snapPx(seg * 0.7), 12 * kArtPx),
          _p,
        );
        // yumuşak kenar: bandın ucunda daha kısa bir basamak
        canvas.drawRect(
          Rect.fromLTWH(
            snapPx(bx + seg * 0.1),
            y - 3 * kArtPx,
            snapPx(seg * 0.45),
            3 * kArtPx,
          ),
          _p,
        );
      }
    }
  }

  void _wind(Canvas canvas) {
    final t = game.time;
    final zone = game.dayCycle.zoneIndex;
    // Emirgan: erguvan yaprakları; diğerleri: taze yapraklar ve beyaz çiçek
    final colors = zone == 5
        ? const [Color(0xFFE88AB4), Color(0xFFF6D0E0)]
        : const [Color(0xFF8ABA5A), Color(0xFFF6F2EA)];
    const px = kArtPx;
    for (var k = 0; k < windBits; k++) {
      final speed = 260 + (k % 4) * 70;
      final x =
          _w -
          ((t * speed + k * 311) % (_w + 200)) +
          100; // sağdan sola, akışla aynı yönde
      final y =
          (k * 1237 % 1000) / 1000 * _h * 0.8 + 80 + math.sin(t * 2 + k) * 40;
      _p.color = colors[k % 2].withValues(alpha: 0.85 * _level);
      // 2×2 yaprak, kanat çırpar gibi dönen tek uç pikseli
      canvas.drawRect(
        Rect.fromLTWH(snapPx(x), snapPx(y), px * 2, px * 2),
        _p,
      );
      final flip = ((t * 3 + k) % 2) < 1;
      canvas.drawRect(
        Rect.fromLTWH(
          snapPx(x + (flip ? px * 2 : -px)),
          snapPx(y + (flip ? -px : px * 2)),
          px,
          px,
        ),
        _p,
      );
    }
    // ince rüzgâr çizgileri
    final line = game.palette.light;
    for (var k = 0; k < 6; k++) {
      final x = _w - ((t * 520 + k * 523) % (_w + 400)) + 200;
      final y = 160 + k * _h * 0.13;
      _p.color = line.withValues(alpha: 0.3 * _level);
      canvas.drawRect(Rect.fromLTWH(snapPx(x), snapPx(y), px * 24, px), _p);
      canvas.drawRect(
        Rect.fromLTWH(snapPx(x + px * 30), snapPx(y), px * 6, px),
        _p,
      );
    }
  }
}
