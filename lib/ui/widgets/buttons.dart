import 'package:flutter/material.dart';

import '../../game/istanbul_flight_game.dart';
import '../../services/audio_service.dart';
import '../theme.dart';
import '../pixel.dart';

/// Basınca hafifçe küçülen sarmalayıcı + buton sesi + hafif titreşim.
/// Animasyonları azalt açıkken ölçek animasyonu yapılmaz.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.game,
    required this.child,
    required this.onTap,
    this.semanticLabel,
  });

  final IstanbulFlightGame game;
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = widget.game.reduceMotion;
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: widget.onTap == null
            ? null
            : () {
                widget.game.services.audio.playSfx(Sfx.button);
                widget.game.services.haptics.light();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _down && !reduce ? 0.94 : 1,
          duration: const Duration(milliseconds: 90),
          child: widget.child,
        ),
      ),
    );
  }
}

enum MartiButtonStyle { primary, secondary, ghost }

/// Oyunun düğmesi: büyük dokunma alanı (≥ 56 dp), Türkçe büyük harf etiket.
class MartiButton extends StatelessWidget {
  const MartiButton({
    super.key,
    required this.game,
    required this.label,
    required this.onPressed,
    this.style = MartiButtonStyle.primary,
    this.icon,
    this.width,
    this.height,
  });

  final IstanbulFlightGame game;
  final String label;
  final VoidCallback? onPressed;
  final MartiButtonStyle style;
  final IconData? icon;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final (bg, fg, border) = switch (style) {
      MartiButtonStyle.primary => (
        UiColors.action,
        UiColors.paper,
        UiColors.actionPressed,
      ),
      MartiButtonStyle.secondary => (
        UiColors.paper,
        UiColors.navy,
        UiColors.navy,
      ),
      MartiButtonStyle.ghost => (
        Colors.transparent,
        UiColors.paper,
        Colors.transparent,
      ),
    };
    final h = height ?? (style == MartiButtonStyle.primary ? 68.0 : 56.0);
    return Pressable(
      game: game,
      onTap: onPressed,
      semanticLabel: label,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.5,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: width,
          height: h,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          // Pixel düğme: basamaklı köşe, 2 nokta çerçeve, sert alt gölge (bulanıklık yok)
          decoration: style == MartiButtonStyle.ghost
              ? null
              : pixelBox(
                  color: bg,
                  border: border,
                  borderWidth: kUiPx * 2,
                  shadow: style == MartiButtonStyle.primary ? kUiPx * 3 : kUiPx,
                  steps: 3,
                ),
          alignment: Alignment.center,
          // Dar ekranda etiket kesilmez, sığacak kadar küçülür ("ANA MENÜ" tam okunur)
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  PixelIcon(icon!, color: fg, size: h * 0.36),
                  const SizedBox(width: 8),
                ],
                Text(
                  trUpper(label),
                  maxLines: 1,
                  style: TextStyle(
                    color: fg,
                    fontSize: style == MartiButtonStyle.primary ? 22 : 17,
                    letterSpacing: 1.2,
                    shadows: style == MartiButtonStyle.ghost
                        ? kSceneTextShadow
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pixel ikon düğmesi + altında etiket (menü). Dokunma alanı 64×64.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.game,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IstanbulFlightGame game;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
    game: game,
    onTap: onPressed,
    semanticLabel: label,
    child: SizedBox(
      width: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: pixelBox(
              color: UiColors.paper,
              border: UiColors.navy,
              borderWidth: kUiPx * 2,
              shadow: kUiPx * 2,
              steps: 4,
            ),
            child: PixelIcon(icon, color: UiColors.navy, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2, // pixel font geniş: uzun etiket iki satıra iner ("Nasıl / oynanır")
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: UiColors.paper,
              fontSize: 15,
              shadows: kSceneTextShadow,
            ),
          ),
        ],
      ),
    ),
  );
}
