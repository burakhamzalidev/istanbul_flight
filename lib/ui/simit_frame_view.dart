import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/game_art.dart';
import '../game/istanbul_flight_game.dart';

/// Simit sprite sheet'inden tek bir kareyi Flutter arayüzünde gösterir (ör. kartpostal).
/// Görsel yüklenmediyse hiçbir şey çizmez.
class SimitFrameView extends StatelessWidget {
  const SimitFrameView({super.key, required this.image, required this.frame});

  final ui.Image? image;
  final int frame;

  @override
  Widget build(BuildContext context) => image == null
      ? const SizedBox.shrink()
      : CustomPaint(painter: _FramePainter(image!, frame));
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.image, this.frame);

  final ui.Image image;
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      GameArt.simitFrameRect(frame),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.image != image || old.frame != frame;
}

/// Geliştirme: FPS ve nesne sayıları (MARTI_STATS).
class StatsOverlay extends StatelessWidget {
  const StatsOverlay({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Align(
      alignment: Alignment.bottomLeft,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          color: const Color(0xAA000000),
          child: ValueListenableBuilder<String>(
            valueListenable: game.stats,
            builder: (_, s, _) => Text(
              s,
              key: const Key('statsText'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
