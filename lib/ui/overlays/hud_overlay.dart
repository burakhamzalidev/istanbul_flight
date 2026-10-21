import 'package:flutter/material.dart';

import '../../game/day_cycle.dart';
import '../../game/istanbul_flight_game.dart';
import '../theme.dart';
import '../widgets/simit_icon.dart';
import '../pixel.dart';

/// Oyun içi HUD: duraklat (sol üst), rota çubuğu, skor (orta), simit sayacı (sağ üst),
/// bölge damgası, KIL PAYI! ve rekor rozeti. Tümü üst bölgede ve güvenli alan içinde:
/// parmağın bulunduğu alt üçte birlik alanda hiçbir öğe yok (docs/01 §6.2).
class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) {
    final reduce = game.reduceMotion;
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            left: 6,
            top: 4,
            child: Material(
              color: UiColors.scrim,
              shape: const PixelBorder(steps: 4),
              child: IconButton(
                key: const Key('pauseButton'),
                tooltip: 'Duraklat',
                onPressed: game.pauseGame,
                iconSize: 30,
                constraints: const BoxConstraints.tightFor(
                  width: 52,
                  height: 52,
                ),
                color: UiColors.paper,
                icon: const PixelIcon(Icons.pause_rounded),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 10,
            child: IgnorePointer(
              child: ValueListenableBuilder<int>(
                valueListenable: game.runSimits,
                builder: (_, n, _) => Bump(
                  value: n,
                  enabled: !reduce,
                  child: Container(
                    key: const Key('simitCounter'),
                    padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
                    decoration: pixelBox(color: UiColors.scrim, steps: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SimitIcon(size: 30),
                        const SizedBox(width: 4),
                        Text(
                          '$n',
                          key: const Key('simitCount'),
                          style: const TextStyle(
                            color: UiColors.paper,
                            fontSize: 20,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 70,
            right: 100,
            top: 24,
            child: IgnorePointer(
              child: ValueListenableBuilder<int>(
                valueListenable: game.score,
                builder: (_, s, _) => RouteBar(score: s),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 60,
            child: IgnorePointer(
              child: ValueListenableBuilder<int>(
                valueListenable: game.score,
                builder: (_, s, _) => Bump(
                  value: s,
                  enabled: !reduce,
                  scale: 1.18,
                  child: Text(
                    '$s',
                    key: const Key('scoreText'),
                    textAlign: TextAlign.center,
                    style: UiText.score,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 170,
            child: IgnorePointer(child: ZoneStamp(zone: game.zoneIndex)),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 236,
            child: IgnorePointer(
              child: EventPopup(
                key: const Key('nearMissPopup'),
                trigger: game.nearMisses,
                reduceMotion: reduce,
                child: const Text(
                  'KIL PAYI!',
                  style: TextStyle(
                    fontSize: 30,
                    color: UiColors.mustard,
                    letterSpacing: 2,
                    shadows: kSceneTextShadow,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 140,
            child: IgnorePointer(
              child: ValueListenableBuilder<bool>(
                valueListenable: game.recordPassed,
                builder: (_, passed, _) => passed
                    ? OneShotFade(
                        key: const Key('recordBadge'),
                        duration: const Duration(milliseconds: 1800),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 3,
                            ),
                            decoration: pixelBox(
                              color: UiColors.action,
                              border: UiColors.actionPressed,
                              shadow: kUiPx,
                            ),
                            child: const Text(
                              'REKOR GEÇİLDİ!',
                              style: TextStyle(
                                color: UiColors.paper,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Değer artınca kısa bir büyüme (skor, simit sayacı). Azaltılmış harekette sabit.
class Bump extends StatelessWidget {
  const Bump({
    super.key,
    required this.value,
    required this.child,
    this.enabled = true,
    this.scale = 1.3,
  });

  final int value;
  final Widget child;
  final bool enabled;
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (!enabled || value == 0) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(value),
      tween: Tween(begin: scale, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (_, s, c) => Transform.scale(scale: s, child: c),
      child: child,
    );
  }
}

/// Bir sayaç her arttığında kısa süre görünen ve solan vurgu (KIL PAYI!).
class EventPopup extends StatefulWidget {
  const EventPopup({
    super.key,
    required this.trigger,
    required this.child,
    this.reduceMotion = false,
  });

  final ValueNotifier<int> trigger;
  final Widget child;
  final bool reduceMotion;

  @override
  State<EventPopup> createState() => _EventPopupState();
}

class _EventPopupState extends State<EventPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  late int _last = widget.trigger.value;

  @override
  void initState() {
    super.initState();
    widget.trigger.addListener(_on);
  }

  void _on() {
    final v = widget.trigger.value;
    if (v > _last) _c.forward(from: 0);
    _last = v;
  }

  @override
  void dispose() {
    widget.trigger.removeListener(_on);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) {
      final t = _c.value;
      if (t == 0 || t == 1) return const SizedBox.shrink();
      final opacity = t < 0.15 ? t / 0.15 : (t > 0.7 ? (1 - t) / 0.3 : 1.0);
      final s = widget.reduceMotion
          ? 1.0
          : (t < 0.15 ? 0.6 + t / 0.15 * 0.5 : 1.1 - (t - 0.15) * 0.1);
      return Opacity(
        opacity: opacity.clamp(0, 1),
        child: Transform.scale(
          scale: s,
          child: Center(child: child),
        ),
      );
    },
    child: widget.child,
  );
}

/// Bir kez görünüp solan öğe.
class OneShotFade extends StatelessWidget {
  const OneShotFade({super.key, required this.child, required this.duration});

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: duration,
    builder: (_, t, c) => Opacity(
      opacity: t < 0.1 ? t / 0.1 : (t > 0.75 ? (1 - t) / 0.25 : 1),
      child: c,
    ),
    child: child,
  );
}

/// Rotadaki 5 durak ve ilerleme (bölge eşiklerine göre).
class RouteBar extends StatelessWidget {
  const RouteBar({super.key, required this.score});

  final int score;

  static double progressFor(int score) {
    final last = zones.last.startScore;
    if (score >= last) return 1;
    final i = zoneIndexForScore(score);
    final a = zones[i].startScore, b = zones[i + 1].startScore;
    return (i + (score - a) / (b - a)) / (zones.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final p = progressFor(score);
    return SizedBox(
      height: 22,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 4,
                color: UiColors.paper.withValues(alpha: 0.35),
              ),
              Container(height: 4, width: w * p, color: UiColors.mustard),
              for (var i = 0; i < zones.length; i++)
                Positioned(
                  left: w * i / (zones.length - 1) - 6,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: pixelBox(
                      color: p * (zones.length - 1) >= i - 0.001
                          ? UiColors.mustard
                          : UiColors.paper,
                      border: UiColors.navy,
                      steps: 1,
                    ),
                  ),
                ),
              Positioned(
                left: w * p - 10,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: pixelBox(
                    color: const Color(0xFFF7F3EA),
                    border: UiColors.ink,
                    borderWidth: kUiPx * 2,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Bölge değişince 1,6 sn görünen mürekkep damgası ("GALATA"). Oyunu durdurmaz.
class ZoneStamp extends StatefulWidget {
  const ZoneStamp({super.key, required this.zone});

  final ValueNotifier<int> zone;

  @override
  State<ZoneStamp> createState() => _ZoneStampState();
}

class _ZoneStampState extends State<ZoneStamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    _shown = widget.zone.value;
    widget.zone.addListener(_onZone);
  }

  void _onZone() {
    if (widget.zone.value == 0 || widget.zone.value == _shown) return;
    setState(() => _shown = widget.zone.value);
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    widget.zone.removeListener(_onZone);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        if (t == 0 || t == 1) return const SizedBox.shrink();
        final opacity = t < 0.15 ? t / 0.15 : (t > 0.8 ? (1 - t) / 0.2 : 1.0);
        final scale = t < 0.15 ? 1.4 - (t / 0.15) * 0.4 : 1.0;
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Center(
              // Pixel damga: döndürülmez (döndürülmüş bitmap font bulanıklaşır)
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: pixelBox(
                  color: UiColors.paper.withValues(alpha: 0.94),
                  border: UiColors.navy,
                  borderWidth: kUiPx * 2,
                  shadow: kUiPx * 2,
                  steps: 1,
                ),
                child: Text(trUpper(zones[_shown].name), style: UiText.stamp),
              ),
            ),
          ),
        );
      },
    );
  }
}
