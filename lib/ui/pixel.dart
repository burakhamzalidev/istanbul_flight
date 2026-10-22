import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game_art.dart';

/// Pixel art arayüz yapı taşları (docs/08 §Arayüz):
/// * [PixelBorder]: basamaklı köşeli çerçeve (yuvarlak köşe yerine piksel merdiven).
/// * [pixelBox]: dolgu + çerçeve + sert (bulanıksız) gölge.
/// * [PixelIcon]: assets/images/pixel_art/ui/icons.png ikon atlası; atlas yoksa Material ikona düşer.
///
/// Arayüz pikseli: 1 px = [kUiPx] mantıksal nokta (Marti Pixel fontunda 20 punto = 2 nokta/piksel).
const double kUiPx = 2;

/// Basamaklı köşeli kenarlık. [steps] köşe başına basamak, [step] basamak boyu.
class PixelBorder extends OutlinedBorder {
  const PixelBorder({super.side, this.step = kUiPx * 2, this.steps = 2});

  final double step;
  final int steps;

  /// Merdiven köşeli dikdörtgen: her köşede [steps] basamak (1 basamak = köşedeki tek pikselin kesilmesi).
  static Path stairs(Rect r, double step, int steps) {
    final c = step * steps;
    final p = Path()..moveTo(r.left, r.top + c);
    void corner(
      double x,
      double y,
      double dx1,
      double dy1,
      double dx2,
      double dy2,
    ) {
      for (var i = 0; i < steps; i++) {
        x += dx1;
        y += dy1;
        p.lineTo(x, y);
        x += dx2;
        y += dy2;
        p.lineTo(x, y);
      }
    }

    corner(r.left, r.top + c, 0, -step, step, 0); // sol üst
    p.lineTo(r.right - c, r.top);
    corner(r.right - c, r.top, step, 0, 0, step); // sağ üst
    p.lineTo(r.right, r.bottom - c);
    corner(r.right, r.bottom - c, 0, step, -step, 0); // sağ alt
    p.lineTo(r.left + c, r.bottom);
    corner(r.left + c, r.bottom, -step, 0, 0, -step); // sol alt
    return p..close();
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      stairs(rect.deflate(side.width), step, steps);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      stairs(rect, step, steps);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0) return;
    // Çerçeve halkası: dış ve iç merdiven, even-odd dolgu (Path.combine web'de güvenilir değil)
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero)
      ..addPath(getInnerPath(rect), Offset.zero);
    canvas.drawPath(
      ring,
      Paint()
        ..color = side.color
        ..isAntiAlias = false,
    );
  }

  @override
  ShapeBorder scale(double t) =>
      PixelBorder(side: side.scale(t), step: step * t, steps: steps);

  @override
  OutlinedBorder copyWith({BorderSide? side}) =>
      PixelBorder(side: side ?? this.side, step: step, steps: steps);

  @override
  bool operator ==(Object other) =>
      other is PixelBorder &&
      other.side == side &&
      other.step == step &&
      other.steps == steps;

  @override
  int get hashCode => Object.hash(side, step, steps);
}

/// Pixel panel / düğme dekorasyonu: düz dolgu, 2 nokta çerçeve, bulanıksız alt gölge.
ShapeDecoration pixelBox({
  required Color color,
  Color? border,
  double borderWidth = kUiPx,
  double shadow = 0,
  Color shadowColor = const Color(0x66000000),
  int steps = 2,
}) => ShapeDecoration(
  color: color,
  shape: PixelBorder(
    side: border == null
        ? BorderSide.none
        : BorderSide(color: border, width: borderWidth),
    steps: steps,
  ),
  shadows: shadow > 0
      ? [BoxShadow(color: shadowColor, offset: Offset(0, shadow))]
      : null,
);

/// Pixel arayüz ikon atlası. Uygulama açılışında bir kez yüklenir ([load]).
abstract final class PixelIcons {
  static ui.Image? image;

  /// Efekt atlası (arayüzdeki simit ikonu, parıltılar).
  static ui.Image? fx;

  static Future<void> load() async {
    Future<ui.Image?> get(String path) async {
      try {
        final data = await rootBundle.load('assets/images/$path');
        return await decodeImageFromList(data.buffer.asUint8List());
      } catch (e) {
        debugPrint(
          'Pixel arayüz görseli yüklenemedi ($path), yedek çizim kullanılacak: $e',
        );
        return null;
      }
    }

    image = await get(GameArt.iconsPath);
    fx = await get(GameArt.fxPath);
  }

  /// Material ikon → atlas adı (aynı anlam).
  static final _names = <IconData, String>{
    Icons.pause_rounded: 'pause',
    Icons.play_arrow_rounded: 'play',
    Icons.replay_rounded: 'replay',
    Icons.home_rounded: 'home',
    Icons.ios_share_rounded: 'share',
    Icons.volume_up_rounded: 'soundOn',
    Icons.volume_off_rounded: 'soundOff',
    Icons.tune_rounded: 'settings',
    Icons.help_outline_rounded: 'help',
    Icons.music_note_rounded: 'music',
    Icons.graphic_eq_rounded: 'sfx',
    Icons.vibration_rounded: 'vibrate',
    Icons.touch_app_rounded: 'touch',
    Icons.star_rounded: 'star',
    Icons.flight_takeoff_rounded: 'flight',
    Icons.view_column_rounded: 'pillars',
    Icons.bolt_rounded: 'bolt',
    Icons.wb_twilight_rounded: 'sunset',
    Icons.arrow_back_rounded: 'back',
    Icons.map_rounded: 'map',
    Icons.lock_rounded: 'lock',
    Icons.check_rounded: 'check',
    Icons.military_tech_rounded: 'badge',
    Icons.emoji_events_rounded: 'trophy',
  };

  static String? nameFor(IconData icon) => _names[icon];
}

/// Atlas ikonu (16×16 hücre, 12×12 çizim, beyaz maske → [color]). Boyut 12 pikselin katına
/// yuvarlanır (bulanıklaşmaz). Atlas yoksa veya ikon atlasta yoksa Material ikon çizilir.
class PixelIcon extends StatelessWidget {
  const PixelIcon(
    this.icon, {
    super.key,
    this.color,
    this.size = 24,
    this.shadows,
  });

  final IconData icon;
  final Color? color;
  final double size;

  /// Sert gölgeler (bulanıklık yok sayılır: pixel art'ta gölge de piksel).
  final List<Shadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final img = PixelIcons.image, name = PixelIcons.nameFor(icon);
    final c = color ?? IconTheme.of(context).color ?? Colors.white;
    if (img == null || name == null) {
      return Icon(icon, color: c, size: size, shadows: shadows);
    }
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _IconPainter(
          size,
          img,
          GameArt.iconRect(name),
          c,
          shadows ?? const [],
        ),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.iconSize, this.img, this.src, this.color, this.shadows);

  /// İstenen ikon boyutu (yerleşim ikona daha büyük alan verse de ikon bu boyutta çizilir).
  final double iconSize;
  final ui.Image img;
  final Rect src;
  final Color color;
  final List<Shadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    // Hücrenin 2 px boş kenarı kırpılır; 12 px çizim tam sayı ölçekle ortalanır
    final inner = Rect.fromLTWH(src.left + 2, src.top + 2, 12, 12);
    final scale = (iconSize / 12).floorToDouble().clamp(1.0, 64.0);
    final d = 12 * scale;
    final dst = Rect.fromLTWH(
      ((size.width - d) / 2).roundToDouble(),
      ((size.height - d) / 2).roundToDouble(),
      d,
      d,
    );
    void draw(Rect r, Color c) => canvas.drawImageRect(
      img,
      inner,
      r,
      Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = ColorFilter.mode(c, BlendMode.srcIn),
    );
    for (final s in shadows) {
      draw(
        dst.shift(
          Offset(s.offset.dx.roundToDouble(), s.offset.dy.roundToDouble()),
        ),
        s.color,
      );
    }
    draw(dst, color);
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.iconSize != iconSize ||
      old.img != img ||
      old.src != src ||
      old.color != color ||
      old.shadows != shadows;
}

/// Ölçeklenen yazı boyutunu pixel fontun keskin kaldığı boyuta (10'un katı) yuvarlar.
double pixelFont(double v) => v < 15 ? 10 : (v / 10).roundToDouble() * 10;

/// Pixel açma/kapama satırı ([SwitchListTile] karşılığı): bütün satır dokunulabilir,
/// sağda basamaklı köşeli ray ve kare tutamaç. Erişilebilirlik: toggled semantiği.
class PixelSwitchTile extends StatelessWidget {
  const PixelSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.activeThumbColor = const Color(0xFFB84A26),
    this.contentPadding = EdgeInsets.zero,
  });

  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeThumbColor;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final muted =
        DefaultTextStyle.of(context).style.color ?? const Color(0xFF4C6280);
    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Padding(
          padding: contentPadding.add(const EdgeInsets.symmetric(vertical: 8)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    title,
                    if (subtitle != null)
                      DefaultTextStyle.merge(
                        style: TextStyle(
                          fontSize: 10,
                          color: muted,
                          height: 1.4,
                        ),
                        child: subtitle!,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _PixelToggle(value: value, color: activeThumbColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _PixelToggle extends StatelessWidget {
  const _PixelToggle({required this.value, required this.color});

  final bool value;
  final Color color;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 120),
    width: 48,
    height: 26,
    padding: const EdgeInsets.all(kUiPx * 2),
    alignment: value ? Alignment.centerRight : Alignment.centerLeft,
    decoration: pixelBox(
      color: value ? color.withValues(alpha: 0.35) : const Color(0xFFE6DCC8),
      border: value ? color : const Color(0xFF4C6280),
      steps: 1,
    ),
    child: Container(
      width: 18,
      height: 18,
      decoration: pixelBox(
        color: value ? color : const Color(0xFF4C6280),
        shadow: kUiPx,
        shadowColor: const Color(0x44000000),
        steps: 1,
      ),
    ),
  );
}

/// Kaydırıcı için kare pixel tutamaç (yuvarlak Material tutamaç yerine).
class PixelSliderThumb extends SliderComponentShape {
  const PixelSliderThumb({this.size = 16});

  final double size;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size.square(size);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final c = Offset(center.dx.roundToDouble(), center.dy.roundToDouble());
    final r = Rect.fromCenter(center: c, width: size, height: size);
    final canvas = context.canvas;
    final paint = Paint()..isAntiAlias = false;
    canvas.drawPath(
      PixelBorder.stairs(r.shift(const Offset(0, kUiPx)), kUiPx, 1),
      paint..color = const Color(0x44000000),
    );
    canvas.drawPath(
      PixelBorder.stairs(r, kUiPx, 1),
      paint..color = const Color(0xFF2B2B3A),
    );
    canvas.drawPath(
      PixelBorder.stairs(r.deflate(kUiPx), kUiPx, 1),
      paint..color = sliderTheme.thumbColor ?? const Color(0xFFB84A26),
    );
  }
}

/// Pixel kaydırıcı teması: köşeli ray, kare tutamaç. Hale görünmez ama dokunma alanını (40 nokta) korur.
SliderThemeData pixelSliderTheme(BuildContext context) =>
    SliderTheme.of(context).copyWith(
      trackHeight: 6,
      trackShape: const RectangularSliderTrackShape(),
      thumbShape: const PixelSliderThumb(),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      overlayColor: const Color(0x00000000),
      tickMarkShape: SliderTickMarkShape.noTickMark,
      valueIndicatorShape: const RectangularSliderValueIndicatorShape(),
    );
