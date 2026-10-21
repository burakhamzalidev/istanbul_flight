import 'dart:math' as math;
import 'dart:ui';

import '../day_cycle.dart';
import 'obstacle_kit_layout.g.dart';

/// Bir engel çiftinin sprite parçalarının yerleşimi (yerel koordinat: engelin sol üstü = 0,0).
///
/// Kurallar (docs/05 §Engeller):
/// * Gövde karoları tam olarak hitbox genişliğinde.
/// * Başlıklar her yandan en fazla [ObstacleKitLayout.overhang] taşar.
/// * Alt başlığın hitbox sınırı (`boundary`) geçidin alt kenarına, üst başlığın alt kenarı geçidin üst
///   kenarına hizalanır. Geçide sadece alt başlığın çarpışmasız süsleri (baca vb., ≤ boundary) girer.
class ObstaclePiecePlan {
  /// [visit] her parça için çağrılır: kaynak (atlas) ve hedef dikdörtgen.
  static void forEach({
    required ObstacleKitId kit,
    required int variant,
    required double width,
    required double worldHeight,
    required double gapTop,
    required double gapBottom,
    required void Function(Rect src, Rect dst) visit,
  }) {
    final sx =
        width /
        ObstacleKitLayout
            .bodyWidth; // gövde genişliği her zaman hitbox genişliği
    final ov = ObstacleKitLayout.overhang * sx,
        cw = ObstacleKitLayout.capWidth * sx;
    final boundary = ObstacleKitLayout.bottomCapBoundary[kit.name] ?? 0;

    // ---- Alt engel: gövde karoları → taban → başlık ----
    final bodySrcB = variant.isEven
        ? ObstacleKitLayout.bottomBodyA
        : ObstacleKitLayout.bottomBodyB;
    final capTopB = gapBottom - boundary;
    final bodyStartB = capTopB + ObstacleKitLayout.capHeight - 2;
    final baseTop = worldHeight - ObstacleKitLayout.baseHeight;
    final hasBase = baseTop > bodyStartB + 40;
    final bodyEndB = hasBase ? baseTop + 2 : worldHeight;
    for (var y = bodyStartB; y < bodyEndB; y += ObstacleKitLayout.tileHeight) {
      final h = math.min(ObstacleKitLayout.tileHeight, bodyEndB - y);
      visit(
        Rect.fromLTWH(bodySrcB.left, bodySrcB.top, bodySrcB.width, h),
        Rect.fromLTWH(0, y, width, h),
      );
    }
    if (hasBase) {
      visit(
        ObstacleKitLayout.bottomBase,
        Rect.fromLTWH(-ov, baseTop, cw, ObstacleKitLayout.baseHeight),
      );
    }
    visit(
      ObstacleKitLayout.bottomCap,
      Rect.fromLTWH(-ov, capTopB, cw, ObstacleKitLayout.capHeight),
    );

    // ---- Üst engel: başlığın üstünden yukarı karolar → başlık ----
    final bodySrcT = (variant ~/ 2).isEven
        ? ObstacleKitLayout.topBodyA
        : ObstacleKitLayout.topBodyB;
    // Vurgulu karo (ör. can simidi) sadece başlığa komşu karoda: tekrar eden "zincir" görüntüsü olmasın
    final accentOnce = kit == ObstacleKitId.kizkulesi;
    var tileIndex = 0;
    final capTopT = gapTop - ObstacleKitLayout.capHeight;
    for (var y = capTopT + 2; y > 0; y -= ObstacleKitLayout.tileHeight) {
      final h = math.min(ObstacleKitLayout.tileHeight, y);
      final src = accentOnce && tileIndex++ > 0
          ? ObstacleKitLayout.topBodyA
          : bodySrcT;
      // Karonun alt kısmı başlığa yapışık kalır → desen başlıkla hizalı
      visit(
        Rect.fromLTWH(src.left, src.bottom - h, src.width, h),
        Rect.fromLTWH(0, y - h, width, h),
      );
    }
    visit(
      ObstacleKitLayout.topCap,
      Rect.fromLTWH(-ov, capTopT, cw, ObstacleKitLayout.capHeight),
    );
  }
}

/// Engel sprite çizicisi (pixel art). Kitler bölgenin ışığında boyalı olarak üretildiğinden tint
/// uygulanmaz; atlas en yakın komşu örneklemeyle 4× büyütülür ([ObstacleKitLayout.atlasScale]).
/// Pencere ışıkları kitin içinde hazırdır; burada sadece hafif parıltı ve duman eklenir.
class ObstacleRenderer {
  final Paint _color = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;
  final Paint _fx = Paint()..isAntiAlias = false;
  Color _smoke = const Color(0xFFFFFFFF);

  void setPalette(PhasePalette p) {
    _smoke = Color.lerp(p.light, const Color(0xFFFFFFFF), 0.6)!;
  }

  static Rect _atlas(Rect r) {
    const s = ObstacleKitLayout.atlasScale;
    return Rect.fromLTWH(r.left * s, r.top * s, r.width * s, r.height * s);
  }

  void render(
    Canvas canvas, {
    required Image atlas,
    required ObstacleKitId kit,
    required int variant,
    required double width,
    required double worldHeight,
    required double gapTop,
    required double gapBottom,
    required double time,
    required int seed,
  }) {
    ObstaclePiecePlan.forEach(
      kit: kit,
      variant: variant,
      width: width,
      worldHeight: worldHeight,
      gapTop: gapTop,
      gapBottom: gapBottom,
      visit: (src, dst) =>
          canvas.drawImageRect(atlas, _atlas(src), dst, _color),
    );

    // Kız Kulesi vapur bacası: yükselen piksel duman (durumsuz, zamana bağlı → nesne üretmez)
    if (kit == ObstacleKitId.kizkulesi) {
      final capTop =
          gapBottom - (ObstacleKitLayout.bottomCapBoundary[kit.name] ?? 0);
      for (var k = 0; k < 4; k++) {
        final ph = (time * 0.45 + k / 4 + seed * 0.37) % 1.0;
        _fx.color = _smoke.withValues(alpha: (1 - ph) * 0.35);
        final s = ((12 + ph * 20) / 4).round() * 4.0;
        final x = ((width * 0.4 - ph * 150) / 4).round() * 4.0,
            y = ((capTop - 12 - ph * 80) / 4).round() * 4.0;
        canvas.drawRect(Rect.fromLTWH(x - s / 2, y - s / 2, s, s), _fx);
      }
    }
  }
}
