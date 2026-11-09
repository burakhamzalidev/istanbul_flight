import 'package:flutter/material.dart';

import '../../game/istanbul_flight_game.dart';
import '../../game/tutorial.dart';
import '../pixel.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/simit_icon.dart';
import 'hud_overlay.dart';

// Phase 2.8: ilk uçuş eğitiminin arayüzü (docs/21 §4). Uzun metin yok: her aşamada bir başlık ve tek
// satır yönerge. "Uçmak için dokun" ekranında aşama şeridi ve "Eğitimi atla"; uçuşta küçük ipuçları.

String tutorialInstruction(
  TutorialStage s,
  TutorialHint h, {
  required bool flying,
}) {
  if (h == TutorialHint.crashed && !flying) {
    return switch (s) {
      TutorialStage.fly => 'Suya değdin. Biraz daha sık dokun!',
      _ => 'Neredeyse! Boşluğa gelince dokun.',
    };
  }
  if (h == TutorialHint.missedSimit) {
    return 'Simidi kaçırdın. Bir tane daha geliyor!';
  }
  return switch (s) {
    TutorialStage.fly =>
      flying
          ? 'Dokundukça yükselirsin. Havada kal!'
          : 'Her dokunuşta Simit kanat çırpar.',
    TutorialStage.obstacle => 'Engellerin arasındaki boşluktan geç.',
    TutorialStage.simit => 'Geçitteki altın simidi topla.',
    TutorialStage.done => 'Harika! Hazırsın.',
  };
}

/// Aşama rozeti: "1/3 · Uçmayı öğren" ve üç kutu (tamamlananlar dolu).
class TutorialStagePill extends StatelessWidget {
  const TutorialStagePill({super.key, required this.stage});

  final TutorialStage stage;

  @override
  Widget build(BuildContext context) {
    final n = stage.number;
    return Semantics(
      label: 'Eğitim, aşama $n / 3: ${stage.title}',
      child: Container(
        key: const Key('tutorialStage'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: pixelBox(
          color: UiColors.scrim,
          border: UiColors.mustard,
          steps: 3,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 3; i++) ...[
              Container(
                width: 12,
                height: 12,
                decoration: pixelBox(
                  color: i < n || stage == TutorialStage.done
                      ? UiColors.mustard
                      : i == n
                      ? UiColors.paper
                      : const Color(0x55FBF7EE),
                  border: UiColors.navy,
                  steps: 1,
                ),
              ),
              const SizedBox(width: 4),
            ],
            const SizedBox(width: 4),
            // dar ekranda / büyük metinde taşmasın: gerekirse iki satır
            Flexible(
              child: ExcludeSemantics(
                child: Text(
                  '$n/3 · ${stage.title}',
                  style: const TextStyle(color: UiColors.paper, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Uçmak için dokun" ekranının eğitim şeridi.
class TutorialReadyBanner extends StatelessWidget {
  const TutorialReadyBanner({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<TutorialStage?>(
    valueListenable: game.tutorialStage,
    builder: (context, stage, _) {
      if (stage == null) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TutorialStagePill(stage: stage),
          const SizedBox(height: 8),
          ValueListenableBuilder<TutorialHint>(
            valueListenable: game.tutorialHint,
            builder: (context, hint, _) => Text(
              tutorialInstruction(stage, hint, flying: false),
              key: const Key('tutorialInstruction'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: UiColors.paper,
                fontSize: 20,
                shadows: kSceneTextShadow,
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Eğitimden sonra ilk "uçmak için dokun" ekranı: kısa kutlama.
class TutorialDoneBanner extends StatelessWidget {
  const TutorialDoneBanner({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: game.tutorialJustCompleted,
    builder: (context, done, _) => !done
        ? const SizedBox.shrink()
        : Container(
            key: const Key('tutorialDone'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: pixelBox(
              color: UiColors.scrim,
              border: UiColors.mustard,
              steps: 3,
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'EĞİTİM TAMAM!',
                  style: TextStyle(
                    color: UiColors.mustard,
                    fontSize: 20,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'Şimdi gerçek uçuş: rekorunu kır.',
                  style: TextStyle(color: UiColors.paper, fontSize: 15),
                ),
              ],
            ),
          ),
  );
}

/// "Eğitimi atla" (yalnızca eğitimin "uçmak için dokun" ekranında; dokunuşu oyuna geçirmez).
class TutorialSkipButton extends StatelessWidget {
  const TutorialSkipButton({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<TutorialStage?>(
    valueListenable: game.tutorialStage,
    builder: (context, stage, _) => stage == null
        ? const SizedBox.shrink()
        : Pressable(
            key: const Key('tutorialSkip'),
            game: game,
            semanticLabel: 'Eğitimi atla',
            onTap: game.skipTutorial,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: pixelBox(
                  color: UiColors.scrim,
                  border: const Color(0x66FBF7EE),
                  steps: 3,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Eğitimi atla',
                      style: TextStyle(color: UiColors.paper, fontSize: 15),
                    ),
                    SizedBox(width: 4),
                    PixelIcon(
                      Icons.skip_next_rounded,
                      color: UiColors.paper,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
  );
}

/// Dokunma hareketi: parmak ikonu ekrana iner ve bir halka yayılır (azaltılmış harekette sabit).
class TapHint extends StatefulWidget {
  const TapHint({super.key, required this.reduce});

  final bool reduce;

  @override
  State<TapHint> createState() => _TapHintState();
}

class _TapHintState extends State<TapHint> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduce) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const icon = PixelIcon(
      Icons.touch_app_rounded,
      color: UiColors.paper,
      size: 44,
      shadows: kSceneTextShadow,
    );
    if (widget.reduce) {
      return const SizedBox(height: 64, child: Center(child: icon));
    }
    return SizedBox(
      height: 64,
      width: 120,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          // 0–0,3: iner, 0,3–0,6: halka, sonra bekler
          final press = t < 0.3
              ? t / 0.3
              : (t < 0.45 ? 1 - (t - 0.3) / 0.15 : 0.0);
          final ring = t >= 0.3 && t < 0.8 ? (t - 0.3) / 0.5 : -1.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (ring >= 0)
                Positioned(
                  top: 6,
                  child: Opacity(
                    opacity: (1 - ring).clamp(0.0, 1.0),
                    child: Container(
                      width: 16 + 40 * ring,
                      height: 8 + 16 * ring,
                      decoration: pixelBox(
                        color: const Color(0x00000000),
                        border: UiColors.paper,
                        borderWidth: kUiPx,
                        steps: 2,
                      ),
                    ),
                  ),
                ),
              Positioned(top: 8 + 8 * press, child: child!),
            ],
          );
        },
        child: icon,
      ),
    );
  }
}

/// Uçuş sırasında eğitim ipuçları (skor ve rota çubuğunun yerinde): aşama, tek satır yönerge,
/// Aşama 1'de havada kalma çubuğu ve ilk kanat çırpışında "Güzel!".
class TutorialHud extends StatelessWidget {
  const TutorialHud({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<TutorialStage?>(
    valueListenable: game.tutorialStage,
    builder: (context, stage, _) {
      if (stage == null) return const SizedBox.shrink();
      // Uçuşta oyun alanını kapatmasın: üstte yalnızca küçük aşama etiketi; yönerge, çubuk ve
      // "Güzel!" ekranın alt kısmında (su). Geçitlerin bulunduğu orta bant boş kalır.
      return Column(
        children: [
          TutorialStagePill(stage: stage),
          const Spacer(),
          EventPopup(
            key: const Key('tutorialNice'),
            trigger: game.tutorialFlaps,
            reduceMotion: game.reduceMotion,
            child: const Text(
              'Güzel!',
              style: TextStyle(
                color: UiColors.mustard,
                fontSize: 25,
                shadows: kSceneTextShadow,
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (stage == TutorialStage.simit)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: SimitIcon(size: 30),
            ),
          ValueListenableBuilder<TutorialHint>(
            valueListenable: game.tutorialHint,
            builder: (context, hint, _) => Text(
              tutorialInstruction(stage, hint, flying: true),
              key: const Key('tutorialHudText'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: UiColors.paper,
                fontSize: 20,
                shadows: kSceneTextShadow,
              ),
            ),
          ),
          if (stage == TutorialStage.fly) ...[
            const SizedBox(height: 8),
            SizedBox(width: 160, child: _FlyMeter(game: game)),
          ],
        ],
      );
    },
  );
}

/// Aşama 1: havada kalma süresi (oyun saatiyle; kare başına küçük bir çubuk).
class _FlyMeter extends StatefulWidget {
  const _FlyMeter({required this.game});

  final IstanbulFlightGame game;

  @override
  State<_FlyMeter> createState() => _FlyMeterState();
}

class _FlyMeterState extends State<_FlyMeter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(days: 1),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      final f = widget.game.tutorialFlow.flyProgress;
      return Container(
        height: 10,
        padding: const EdgeInsets.all(kUiPx),
        decoration: pixelBox(color: const Color(0x55FBF7EE), steps: 1),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: f,
          child: const ColoredBox(color: UiColors.mustard),
        ),
      );
    },
  );
}
