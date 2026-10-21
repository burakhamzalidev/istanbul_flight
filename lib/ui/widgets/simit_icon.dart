import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../game/game_art.dart';
import '../pixel.dart';

/// Toplanabilir simit ikonu (HUD sayacı, kartpostal, nasıl oynanır): oyundaki pixel sprite'ın
/// ilk karesi (efekt atlası). Atlas yüklenmediyse aynı renklerde köşeli yedek çizim.
class SimitIcon extends StatelessWidget {
  const SimitIcon({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _SimitPainter(PixelIcons.fx)),
  );
}

class _SimitPainter extends CustomPainter {
  _SimitPainter(this.fx);
  final ui.Image? fx;

  @override
  void paint(Canvas canvas, Size size) {
    final img = fx;
    if (img != null) {
      // 20 px kare tam sayı ölçekle (bulanıklık yok)
      final s = (size.shortestSide / 20).floorToDouble().clamp(1.0, 16.0),
          d = 20 * s;
      final dst = Rect.fromLTWH(
        ((size.width - d) / 2).roundToDouble(),
        ((size.height - d) / 2).roundToDouble(),
        d,
        d,
      );
      canvas.drawImageRect(
        img,
        GameArt.pickupFrame(0),
        dst,
        Paint()..filterQuality = FilterQuality.none,
      );
      return;
    }
    final c = size.center(Offset.zero),
        r = size.width * 0.34,
        u = size.width / 10;
    final ink = Paint()..color = const Color(0xFF2B2B3A),
        dough = Paint()..color = const Color(0xFFC8803A);
    canvas.drawRect(Rect.fromCircle(center: c, radius: r + u), ink);
    canvas.drawRect(Rect.fromCircle(center: c, radius: r), dough);
    canvas.drawRect(Rect.fromCircle(center: c, radius: r * 0.4), ink);
  }

  @override
  bool shouldRepaint(_SimitPainter old) => old.fx != fx;
}
