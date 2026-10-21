import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

import '../day_cycle.dart';
import '../game_art.dart';
import '../istanbul_flight_game.dart';
import '../visual/crossfade.dart';

/// Pixel art arka plan katmanları (docs/08). Her bölgenin kendi görselleri vardır
/// (`assets/images/pixel_art/backgrounds/<bölge>`); bölge değişince [Crossfade] ile karışır.
///
/// | Öncelik | Katman              | Parallax |
/// |---------|---------------------|----------|
/// | 0       | [SkyLayer] gök + güneş/ay + yıldız | 0 |
/// | 1       | [CloudLayer]        | 0,03 + rüzgâr |
/// | 2       | [FarLayer] uzak şehir | 0,06 |
/// | 3       | LandmarkLayer (karadaki simgeler) | 0,16 |
/// | 4       | [ShoreLayer] orta plan binalar | 0,14 |
/// | 5       | [WaterLayer] su + parıltı + güneş/ay yansıması | 0,5 |
/// | 6       | [WaterfrontLayer] rıhtım, iskele, tekneler | 0,3 |
/// | 7       | [FerryLayer] geçen vapur (ön plan ayrıntısı) | 0,45 + kendi hızı |
/// | 8       | LandmarkFrontLayer (suyun içindeki simgeler + yansıma) | 0,16 |
/// | 9       | [FogLayer] sis | 0,1 |
///
/// Bütün görseller 1 px = 4 dünya birimi ölçeğinde, en yakın komşu örneklemeyle ve piksel
/// ızgarasına oturtularak çizilir.
mixin LayerContext on Component, HasGameReference<IstanbulFlightGame> {
  PhasePalette get pal => game.palette;
  double get width => game.visibleWidth;
  double get horizon => game.config.horizonY;
  double get worldH => game.config.worldHeight;
  String get zoneKey => game.dayCycle.zone.kit.name;
  ZoneArt? zoneArt(String key) => game.art.zones[key];
}

/// Beyaz maskeyi faz rengine boyayan, rengi sadece değişince yenileyen paint (yedek çizimler için).
class TintPaint {
  final Paint paint = pixelPaint();
  int _argb = -1;

  Paint tinted(Color color, double opacity) {
    final argb = color.toARGB32();
    if (argb != _argb) {
      _argb = argb;
      paint.colorFilter = ColorFilter.mode(color, BlendMode.srcIn);
    }
    paint.color = Color.fromRGBO(0, 0, 0, opacity.clamp(0, 1));
    return paint;
  }
}

/// Saydamlığı değişen pixel paint (çapraz geçiş).
class AlphaPaint {
  final Paint paint = pixelPaint();
  Paint at(double a) => paint..color = Color.fromRGBO(0, 0, 0, a.clamp(0, 1));
}

/// Yatay döşenen pixel şeridi: 4× büyütülür, kaydırma piksel ızgarasına oturtulur, +1 birim bindirme dikişi önler.
void drawPixelStrip(
  Canvas canvas,
  Image img,
  double scroll,
  double viewWidth,
  double top,
  Paint paint, {
  Rect? src,
}) {
  final s =
      src ?? Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
  final w = s.width * kArtPx, h = s.height * kArtPx;
  final start = -snapPx(scroll % w);
  for (var x = start; x < viewWidth; x += w) {
    canvas.drawImageRect(img, s, Rect.fromLTWH(x, top, w + 1, h), paint);
  }
}

/// Bölge geçişini izleyen yardımcı: aynı anda en fazla iki bölge görseli çizilir.
class ZoneFade {
  ZoneFade(String key, {double duration = 2.5})
    : fade = Crossfade<String>(key, duration: duration);
  final Crossfade<String> fade;
  final AlphaPaint _cur = AlphaPaint(), _prev = AlphaPaint();

  void update(String key, double dt) {
    fade.set(key);
    fade.update(dt);
  }

  void snap(String key) => fade.snap(key);

  /// [draw] her görünür bölge için (anahtar, paint) ile çağrılır: önce solan, sonra baskın.
  void each(void Function(String key, Paint paint) draw) {
    final p = fade.previous;
    if (p != null) draw(p, _prev.at(fade.previousAlpha));
    draw(fade.current, _cur.at(p == null ? 1 : fade.alpha));
  }
}

abstract class ZoneLayer extends Component
    with HasGameReference<IstanbulFlightGame>, LayerContext {
  ZoneLayer({required super.priority});

  late final ZoneFade zf = ZoneFade(zones[0].kit.name);

  void reset() => zf.snap(zones[0].kit.name);

  @override
  void update(double dt) => zf.update(zoneKey, dt);
}

// ======================= L0 =======================

/// Bölgenin güneş/ay konumu (x oran, y px). Listede olmayan bölgede gökte disk ve suda yansıma sütunu çizilmez.
const _sunPos = {
  // halic yok: kamera güneybatıya bakıyor, şafakta güneş arkada (docs/11)
  'galata': (0.82, 70.0),
  // kizkulesi yok: kamera doğuya bakıyor, güneş arkada (docs/10)
  'kopru': (0.8, 64.0),
  'rumeli': (0.78, 58.0),
};

class SkyLayer extends ZoneLayer {
  SkyLayer() : super(priority: 0);

  final Paint _fallback = Paint();
  final Paint _star = Paint()
    ..strokeCap = StrokeCap.square
    ..strokeWidth = kArtPx;
  late final Float32List _starsA = _stars(1, 46), _starsB = _stars(2, 36);
  late final Float32List _scaledA = Float32List(_starsA.length),
      _scaledB = Float32List(_starsB.length);

  Float32List _stars(int seed, int count) {
    final r = math.Random(seed), list = Float32List(count * 2);
    for (var i = 0; i < count; i++) {
      list[i * 2] = r.nextDouble();
      list[i * 2 + 1] = r.nextDouble() * 0.55;
    }
    return list;
  }

  @override
  void render(Canvas canvas) {
    zf.each((key, paint) {
      final z = zoneArt(key), sky = z?.sky;
      if (sky == null) {
        _fallback.color = pal.skyMid;
        canvas.drawRect(Rect.fromLTWH(0, 0, width, horizon), _fallback);
        return;
      }
      drawPixelStrip(canvas, sky, 0, width, 0, paint);
      final sun = z!.sun, pos = _sunPos[key];
      if (sun != null && pos != null) {
        final cx = snapPx(width * pos.$1), cy = pos.$2 * kArtPx;
        canvas.drawImageRect(
          sun,
          Rect.fromLTWH(0, 0, 96, 96),
          Rect.fromLTWH(
            cx - 48 * kArtPx,
            cy - 48 * kArtPx,
            96 * kArtPx,
            96 * kArtPx,
          ),
          paint,
        );
      }
    });
    // Yıldızlar: tek piksel kareler, iki grup ters fazda titreşir (ızgaraya oturtulmuş)
    if (pal.stars > 0.01) {
      for (final (src, dst, ph) in [
        (_starsA, _scaledA, 0.0),
        (_starsB, _scaledB, math.pi),
      ]) {
        for (var i = 0; i < src.length; i += 2) {
          dst[i] = snapPx(src[i] * width) + kArtPx / 2;
          dst[i + 1] = snapPx(src[i + 1] * horizon) + kArtPx / 2;
        }
        _star.color = const Color(0xFFFFF4DC).withValues(
          alpha: pal.stars * (0.55 + 0.4 * math.sin(game.time * 1.3 + ph)),
        );
        canvas.drawRawPoints(PointMode.points, dst, _star);
      }
    }
  }
}

// ======================= L1 =======================

class CloudLayer extends ZoneLayer {
  CloudLayer() : super(priority: 1);

  // (x oranı, y dünya, sprite, rüzgâr)
  static const _clouds = [
    (0.06, 300.0, 0, 9.0),
    (0.62, 560.0, 1, 14.0),
    (0.3, 820.0, 2, 6.0),
    (0.88, 200.0, 2, 11.0),
  ];

  @override
  void render(Canvas canvas) {
    final span = width + 520;
    final dist = game.scrollDistance * 0.03;
    zf.each((key, paint) {
      final img = zoneArt(key)?.clouds;
      if (img == null) return;
      for (final (fx, y, sprite, wind) in _clouds) {
        final src = ZoneArt.cloudRects[sprite];
        final x = snapPx(
          ((fx * span - dist - game.time * wind) % span + span) % span - 260,
        );
        canvas.drawImageRect(
          img,
          src,
          Rect.fromLTWH(x, y, src.width * kArtPx, src.height * kArtPx),
          paint,
        );
      }
    });
  }
}

// ======================= L2 / L4 =======================

/// Uzak şehir silüeti (tarihi yarımada, Üsküdar tepeleri, Boğaz korusu).
class FarLayer extends ZoneLayer {
  FarLayer() : super(priority: 2);

  static const parallax = 0.06;

  @override
  void render(Canvas canvas) {
    zf.each((key, paint) {
      final img = zoneArt(key)?.distant;
      if (img != null) {
        drawPixelStrip(
          canvas,
          img,
          game.scrollDistance * parallax,
          width,
          horizon - img.height * kArtPx + 4,
          paint,
        );
      }
    });
  }
}

/// Orta plan binalar (ahşap evler, Beyoğlu apartmanları, yalılar, korular).
class ShoreLayer extends ZoneLayer {
  ShoreLayer() : super(priority: 4);

  static const parallax = 0.14;

  @override
  void render(Canvas canvas) {
    zf.each((key, paint) {
      final img = zoneArt(key)?.midground;
      if (img != null) {
        drawPixelStrip(
          canvas,
          img,
          game.scrollDistance * parallax,
          width,
          horizon - img.height * kArtPx + 4,
          paint,
        );
      }
    });
  }
}

// ======================= L5 =======================

class WaterLayer extends ZoneLayer {
  WaterLayer() : super(priority: 5);

  static const parallax = 0.5;
  final AlphaPaint _hi = AlphaPaint();
  final Paint _rect = Paint();

  @override
  void render(Canvas canvas) {
    final scroll = game.scrollDistance * parallax;
    zf.each((key, paint) {
      final z = zoneArt(key);
      final water = z?.water;
      if (water == null) {
        _rect.color = pal.water;
        canvas.drawRect(Rect.fromLTRB(0, horizon, width, worldH), _rect);
        return;
      }
      drawPixelStrip(canvas, water, scroll, width, horizon, paint);
      final hi = z!.waterHi;
      if (hi != null) {
        // İki parıltı katmanı farklı hızlarda kayar ve ters fazda solar → hafif, ucuz su hareketi
        final a = paint.color.a, pulse = 0.5 + 0.5 * math.sin(game.time * 1.4);
        drawPixelStrip(
          canvas,
          hi,
          scroll + game.time * 10,
          width,
          horizon,
          _hi.at(a * pulse),
        );
        drawPixelStrip(
          canvas,
          hi,
          scroll - game.time * 7 + 256,
          width,
          horizon,
          _hi.at(a * (1 - pulse)),
        );
      }
      // Güneş / ay yansıma sütunu (piksel çizgiler, dalgayla kayar)
      final pos = _sunPos[key];
      if (pos != null) {
        final nearHorizon = pos.$2 > 180;
        final strength = (nearHorizon ? 0.9 : 0.45) * paint.color.a;
        final cx = snapPx(width * pos.$1);
        _rect.color = (nearHorizon ? pal.sun : const Color(0xFFFFF0D0))
            .withValues(alpha: strength);
        for (var i = 0; i < 10; i++) {
          final w = snapPx(
            (nearHorizon ? 120.0 : 60.0) - i * (nearHorizon ? 10 : 5),
          );
          if (w <= 0) break;
          final wob = snapPx(math.sin(game.time * 2 + i * 1.7) * 8);
          canvas.drawRect(
            Rect.fromLTWH(cx - w / 2 + wob, horizon + 12 + i * 24, w, kArtPx),
            _rect,
          );
        }
      }
    });
  }
}

// ======================= kıyı / vapur =======================

class WaterfrontLayer extends ZoneLayer {
  WaterfrontLayer() : super(priority: 6);

  static const parallax = 0.3;

  @override
  void render(Canvas canvas) {
    zf.each((key, paint) {
      final img = zoneArt(key)?.waterfront;
      if (img != null) {
        drawPixelStrip(
          canvas,
          img,
          game.scrollDistance * parallax,
          width,
          horizon - ZoneArt.waterfrontHorizonRow * kArtPx,
          paint,
        );
      }
    });
  }
}

/// Ara sıra Boğaz'dan geçen vapur (ön plan ayrıntısı). Bölgenin vapuru (gece pencereleri yanık).
/// Oynanışı etkilemez: suyun üst bandında, engellerin arkasında.
class FerryLayer extends Component
    with HasGameReference<IstanbulFlightGame>, LayerContext {
  FerryLayer() : super(priority: 7);

  final Paint _paint = pixelPaint();
  final Paint _smoke = Paint();
  double _x = -1e9, _wait = 3;
  bool _leftward = true;
  String _key = 'halic';
  final math.Random _r = math.Random(21);

  void reset() {
    _x = -1e9;
    _wait = 3;
  }

  @override
  void update(double dt) {
    final img = zoneArt(zoneKey)?.ferry;
    if (_x < -1e8) {
      _wait -= dt;
      if (_wait <= 0 && img != null) {
        _key = zoneKey;
        _leftward = _r.nextBool();
        _x = _leftward ? width + 40 : -img.width * kArtPx - 40;
      }
      return;
    }
    final ferry = zoneArt(_key)?.ferry;
    final speed = 36.0; // kendi hızı (dünya/sn)
    _x += (_leftward ? -speed : speed) * dt - game.frameScroll * 0.45;
    final w = (ferry?.width ?? 72) * kArtPx;
    if (_x < -w - 80 || _x > width + 80) {
      _x = -1e9;
      _wait = 14 + _r.nextDouble() * 14;
    }
  }

  @override
  void render(Canvas canvas) {
    if (_x < -1e8) return;
    final img = zoneArt(_key)?.ferry;
    if (img == null) return;
    final w = img.width * kArtPx, h = img.height * kArtPx, y = horizon + 40;
    final x = snapPx(_x);
    canvas.save();
    if (!_leftward) {
      canvas.translate(x + w, 0);
      canvas.scale(-1, 1);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(0, y, w, h),
        _paint,
      );
    } else {
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(x, y, w, h),
        _paint,
      );
    }
    canvas.restore();
    // baca dumanı: geriye doğru yükselen piksel kareler
    // Baca konumu (px): Şehir Hatları vapurunda (96 px, Galata) 55, eski 72 px vapurlarda 35
    final funnel = img.width >= 90 ? 55 : 35;
    final funnelX = _leftward
        ? x + funnel * kArtPx
        : x + w - (funnel + 2) * kArtPx;
    for (var k = 0; k < 4; k++) {
      final ph = (game.time * 0.5 + k / 4) % 1.0;
      _smoke.color = const Color(0xFFE8E4EC).withValues(alpha: (1 - ph) * 0.5);
      final s = snapPx(8 + ph * 12);
      canvas.drawRect(
        Rect.fromLTWH(
          snapPx(funnelX + (_leftward ? 1 : -1) * ph * 60),
          snapPx(y - 8 - ph * 70),
          s,
          s,
        ),
        _smoke,
      );
    }
  }
}

// ======================= sis =======================

class FogLayer extends Component
    with HasGameReference<IstanbulFlightGame>, LayerContext {
  FogLayer() : super(priority: 9);

  final Paint _paint = Paint();

  @override
  void render(Canvas canvas) {
    final f = pal.fog;
    if (f < 0.01) return;
    final color = Color.lerp(pal.skyHorizon, const Color(0xFFFFFFFF), 0.35)!;
    final drift = game.scrollDistance * 0.1 + game.time * 8;
    for (var i = 0; i < 4; i++) {
      final y = snapPx(horizon - 72 + i * 32);
      const seg = 520.0;
      final off = (drift * (1 + i * 0.25)) % seg;
      _paint.color = color.withValues(alpha: f * (0.2 - i * 0.03));
      for (var x = -off - seg; x < width + seg; x += seg) {
        canvas.drawRect(
          Rect.fromLTWH(snapPx(x + i * 60), y, snapPx(seg * 0.75), 3 * kArtPx),
          _paint,
        );
      }
    }
  }
}
