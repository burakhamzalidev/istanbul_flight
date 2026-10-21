import 'dart:math' as math;
import 'dart:ui';

import '../day_cycle.dart';

/// Engellerin GEÇİCİ grafikleri (kodla çizilir, faz paletine göre renklenir).
/// Final sprite'lar gelince sadece bu dosya değişir. Hitbox [ObstaclePair] içindedir.
///
/// Kurallar (docs/01 §9.7, docs/02 §2.4):
/// * Geçidin sınırı her zaman açık renkli bir kenar çizgisiyle belirtilir.
/// * Başlıklar hitbox'tan en fazla 12–14 birim taşar (taşan kısım oyuncu lehine).
/// * Sağ kenarda fazın ışık renginde kenar ışığı bulunur.
class ObstaclePainter {
  static final Paint _p = Paint();

  static void paint(
    Canvas c,
    ObstacleStyle style,
    PhasePalette pal,
    double w,
    double h,
    double gt,
    double gb,
    int seed,
  ) {
    switch (style) {
      case ObstacleStyle.house:
        _cumbaTop(c, pal, w, gt, seed);
        _houseBottom(c, pal, w, h, gb, seed);
      case ObstacleStyle.ferry:
        _pierTop(c, pal, w, gt);
        _funnelBottom(c, pal, w, h, gb);
      case ObstacleStyle.bridge:
        _cableTop(c, pal, w, gt);
        _mastBottom(c, pal, w, h, gb);
    }
  }

  static void _rect(Canvas c, Rect r, Color color, [double opacity = 1]) {
    _p
      ..color = color.withValues(alpha: color.a * opacity)
      ..style = PaintingStyle.fill;
    c.drawRect(r, _p);
  }

  static Color _shade(Color c, double t) =>
      Color.lerp(c, const Color(0xFF000000), t)!;
  static Color _tint(Color c, double t) =>
      Color.lerp(c, const Color(0xFFFFFFFF), t)!;

  static void _windows(
    Canvas c,
    PhasePalette pal,
    double w,
    double top,
    double bottom,
    int seed,
  ) {
    var s = seed * 7919 + 13;
    double rnd() => ((s = (s * 16807) % 2147483647) / 2147483647);
    for (var y = top + 28; y + 58 < bottom - 12; y += 96) {
      for (final x in [24.0, w - 68]) {
        _rect(
          c,
          Rect.fromLTWH(x, y, 44, 58),
          rnd() > 0.68 ? pal.light : pal.windowDark,
        );
        _rect(c, Rect.fromLTWH(x, y + 26, 44, 4), pal.obstacleBase);
      }
    }
  }

  // ---------- Haliç / Galata: ahşap ev ve cumbalı cephe ----------
  static void _houseBottom(
    Canvas c,
    PhasePalette pal,
    double w,
    double h,
    double gb,
    int seed,
  ) {
    const roofH = 46.0;
    final body = Rect.fromLTRB(0, gb + roofH, w, h);
    _rect(c, body, pal.obstacleBase);
    for (var y = body.top + 10; y < h; y += 22) {
      _rect(c, Rect.fromLTWH(0, y, w, 2), const Color(0xFF000000), 0.12);
    }
    _windows(c, pal, w, body.top, h, seed);
    // Mansard çatı: üst kenar düz ve hitbox ile aynı hizada
    final roof = Path()
      ..moveTo(0, gb)
      ..lineTo(w, gb)
      ..lineTo(w + 12, gb + roofH)
      ..lineTo(-12, gb + roofH)
      ..close();
    c.drawPath(roof, _p..color = pal.obstacleDetail);
    _rect(
      c,
      Rect.fromLTWH(-12, gb + roofH - 6, w + 24, 8),
      _shade(pal.obstacleBase, 0.25),
    );
    _rect(c, Rect.fromLTWH(0, gb, w, 5), pal.light, 0.9);
    _rect(c, Rect.fromLTWH(w - 7, body.top, 7, h - body.top), pal.light, 0.7);
  }

  static void _cumbaTop(
    Canvas c,
    PhasePalette pal,
    double w,
    double gt,
    int seed,
  ) {
    const cumbaH = 64.0;
    final bodyBottom = gt - cumbaH;
    final base = Color.lerp(pal.obstacleBase, const Color(0xFF33405A), 0.35)!;
    _rect(c, Rect.fromLTRB(0, -2000, w, bodyBottom), base);
    _windows(c, pal, w, math.max(0, bodyBottom - 96 * 6), bodyBottom, seed + 1);
    // Cumba kutusu
    final box = Rect.fromLTRB(-12, bodyBottom, w + 12, gt);
    _rect(c, box, _shade(base, 0.15));
    for (var i = 0; i < 3; i++) {
      _rect(
        c,
        Rect.fromLTWH(4 + i * (w / 3), bodyBottom + 8, w / 3 - 16, 26),
        i == 1 ? pal.light : pal.windowDark,
      );
    }
    // Asılı çamaşırlar (başlığın parçası, sınırın içinde)
    const laundry = [
      Color(0xFFD9643A),
      Color(0xFF2E8B99),
      Color(0xFFF2E6D0),
      Color(0xFFE8B04B),
    ];
    for (var i = 0; i < 4; i++) {
      _rect(
        c,
        Rect.fromLTWH(8 + i * (w - 16) / 4, gt - 22, (w - 16) / 4 - 10, 16),
        laundry[i],
        0.9,
      );
    }
    _rect(c, Rect.fromLTWH(-12, gt - 5, w + 24, 5), pal.light, 0.9);
    _rect(c, Rect.fromLTRB(w - 7, -2000, w, bodyBottom), pal.light, 0.6);
  }

  // ---------- Kız Kulesi: vapur bacası ve iskele kazığı ----------
  static void _funnelBottom(
    Canvas c,
    PhasePalette pal,
    double w,
    double h,
    double gb,
  ) {
    const band = 44.0;
    final hullTop = h - 210;
    final cabinTop = math.max(gb + band, h - 400);
    // Baca gövdesi (tanınırlık için açık renk: docs/02 §2.4)
    if (cabinTop > gb + band) {
      final funnel = Rect.fromLTRB(0, gb + band, w, cabinTop);
      _rect(c, funnel, pal.obstacleDetail);
      _rect(
        c,
        Rect.fromLTWH(0, funnel.top, 36, funnel.height),
        _shade(pal.obstacleDetail, 0.18),
      );
      if (funnel.height > 150) {
        final center = Offset(w / 2 + 8, funnel.top + 90);
        final stroke = Paint()
          ..color = pal.obstacleBase
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round;
        c.drawCircle(center, 42, stroke);
        c.drawLine(
          center + const Offset(0, -24),
          center + const Offset(0, 26),
          stroke,
        );
        c.drawLine(
          center + const Offset(-15, -8),
          center + const Offset(15, -8),
          stroke,
        );
        c.drawArc(
          Rect.fromCircle(center: center + const Offset(0, 6), radius: 22),
          0.2,
          math.pi - 0.4,
          false,
          stroke,
        );
      }
    }
    // Kabin
    _rect(
      c,
      Rect.fromLTRB(0, cabinTop, w, hullTop),
      _tint(pal.obstacleDetail, 0.45),
    );
    for (var i = 0; i < 4; i++) {
      _rect(
        c,
        Rect.fromLTWH(
          18 + i * (w - 36) / 4,
          cabinTop + 36,
          (w - 36) / 4 - 16,
          36,
        ),
        pal.light,
      );
    }
    // Gövde
    _rect(c, Rect.fromLTRB(0, hullTop, w, h), pal.obstacleBase);
    _rect(c, Rect.fromLTWH(0, hullTop + 10, w, 8), const Color(0xFFD9643A));
    // Başlık bandı ve sınır
    _rect(c, Rect.fromLTWH(0, gb, w, band), pal.obstacleBase);
    _rect(c, Rect.fromLTWH(0, gb, w, 5), pal.light, 0.9);
    _rect(c, Rect.fromLTWH(w - 8, gb, 8, h - gb), pal.light, 0.7);
  }

  static void _pierTop(Canvas c, PhasePalette pal, double w, double gt) {
    const capH = 48.0;
    final bodyBottom = gt - capH;
    _rect(c, Rect.fromLTRB(0, -2000, w, bodyBottom), pal.obstacleBase);
    for (var i = 1; i < 5; i++) {
      _rect(
        c,
        Rect.fromLTRB(i * w / 5, -2000, i * w / 5 + 3, bodyBottom),
        pal.windowDark,
      );
    }
    final rope = Paint()
      ..color = const Color(0xFF8C6A5A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    for (var y = bodyBottom - 60.0; y > -200; y -= 170) {
      c.drawPath(
        Path()
          ..moveTo(10, y - 40)
          ..quadraticBezierTo(w / 2, y + 30, w - 10, y - 40),
        rope,
      );
    }
    // Can simitleri: kırmızı-beyaz, koyu kolonun içinde. Toplanabilir simitle karışmaması için
    // sadece dekor; MVP'de toplanabilir nesne yok (docs/02 §2.3).
    for (var y = bodyBottom - 150.0, i = 0; y > -100; y -= 190, i++) {
      final center = Offset(i.isEven ? w * 0.33 : w * 0.67, y);
      c.drawCircle(
        center,
        26,
        Paint()
          ..color = pal.obstacleBase
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18,
      );
      c.drawCircle(
        center,
        26,
        Paint()
          ..color = const Color(0xFFF2E6D0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12,
      );
      for (var k = 0; k < 4; k++) {
        c.drawArc(
          Rect.fromCircle(center: center, radius: 26),
          k * math.pi / 2,
          math.pi / 4,
          false,
          Paint()
            ..color = const Color(0xFFD9643A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 12,
        );
      }
    }
    _rect(
      c,
      Rect.fromLTRB(-14, bodyBottom, w + 14, gt),
      _tint(pal.obstacleBase, 0.08),
    );
    _rect(c, Rect.fromLTWH(w / 2 - 16, bodyBottom + 8, 32, 28), pal.light);
    _rect(c, Rect.fromLTWH(-14, gt - 6, w + 28, 6), pal.light, 0.9);
    _rect(c, Rect.fromLTRB(w - 7, -2000, w, bodyBottom), pal.light, 0.7);
  }

  // ---------- Boğaz Köprüsü / gece: askı kablosu ve balıkçı direği ----------
  static void _cableTop(Canvas c, PhasePalette pal, double w, double gt) {
    const capH = 56.0;
    final bodyBottom = gt - capH;
    _rect(c, Rect.fromLTRB(0, -2000, w, bodyBottom), pal.obstacleBase);
    for (final x in [w * 0.3, w * 0.7]) {
      _rect(
        c,
        Rect.fromLTRB(x - 4, -2000, x + 4, bodyBottom),
        pal.obstacleDetail,
      );
      for (var y = bodyBottom - 30; y > -60; y -= 46) {
        c.drawCircle(
          Offset(x, y),
          10,
          _p..color = pal.light.withValues(alpha: 0.15),
        );
        c.drawCircle(Offset(x, y), 4, _p..color = pal.light);
      }
    }
    _rect(
      c,
      Rect.fromLTRB(-12, bodyBottom, w + 12, gt),
      _tint(pal.obstacleBase, 0.1),
    );
    for (var i = 0; i < 4; i++) {
      c.drawCircle(
        Offset(22 + i * (w - 44) / 3, bodyBottom + 26),
        7,
        _p..color = _shade(pal.obstacleBase, 0.5),
      );
    }
    _rect(c, Rect.fromLTWH(-12, gt - 6, w + 24, 6), pal.light);
    _rect(
      c,
      Rect.fromLTRB(w - 7, -2000, w, bodyBottom),
      const Color(0xFF00E5FF),
      0.4,
    );
  }

  static void _mastBottom(
    Canvas c,
    PhasePalette pal,
    double w,
    double h,
    double gb,
  ) {
    const capH = 66.0;
    c.drawCircle(
      Offset(w / 2, gb + 34),
      120,
      _p..color = pal.light.withValues(alpha: 0.10),
    );
    final hullTop = h - 240;
    _rect(c, Rect.fromLTRB(0, gb + capH, w, hullTop), pal.obstacleBase);
    final rig = Paint()
      ..color = pal.obstacleDetail
      ..strokeWidth = 3;
    for (var y = gb + capH + 30; y < hullTop; y += 46) {
      c.drawLine(Offset(0, y), Offset(w, y + 30), rig);
    }
    _rect(
      c,
      Rect.fromLTRB(w / 2 - 12, gb + capH, w / 2 + 12, hullTop),
      pal.obstacleDetail,
    );
    // Tekne gövdesi
    _rect(
      c,
      Rect.fromLTRB(0, hullTop, w, hullTop + 40),
      _tint(pal.obstacleBase, 0.08),
    );
    _rect(c, Rect.fromLTWH(w / 2 - 25, hullTop + 8, 50, 22), pal.light);
    _rect(
      c,
      Rect.fromLTRB(0, hullTop + 40, w, h),
      _shade(pal.obstacleBase, 0.2),
    );
    // Fener başlığı
    _rect(
      c,
      Rect.fromLTRB(-10, gb, w + 10, gb + capH),
      _tint(pal.obstacleBase, 0.1),
    );
    _rect(c, Rect.fromLTRB(22, gb + 12, w - 22, gb + capH - 12), pal.light);
    for (var i = 1; i < 4; i++) {
      _rect(
        c,
        Rect.fromLTWH(22 + i * (w - 44) / 4 - 2.5, gb + 12, 5, capH - 24),
        _tint(pal.obstacleBase, 0.1),
      );
    }
    _rect(c, Rect.fromLTWH(-10, gb, w + 20, 6), _tint(pal.light, 0.4));
    _rect(c, Rect.fromLTRB(w - 7, gb + capH, w, hullTop), pal.light, 0.5);
  }
}
