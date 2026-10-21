import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/day_cycle.dart';
import '../../game/istanbul_flight_game.dart';
import '../../services/settings.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/simit_icon.dart';
import '../pixel.dart';
import 'progression_overlays.dart';

/// Logo pulu: kartpostal pulu biçiminde, hafifçe süzülür (azaltılmış harekette sabit).
class LogoStamp extends StatefulWidget {
  const LogoStamp({super.key, required this.reduceMotion, this.scale = 1});

  final bool reduceMotion;
  final double scale;

  @override
  State<LogoStamp> createState() => _LogoStampState();
}

class _LogoStampState extends State<LogoStamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stamp = Container(
      padding: EdgeInsets.fromLTRB(
        22 * widget.scale,
        12 * widget.scale,
        22 * widget.scale,
        14 * widget.scale,
      ),
      // Pixel kartpostal pulu: basamaklı köşe, kalın çerçeve, sert gölge
      decoration: pixelBox(
        color: UiColors.paper,
        border: UiColors.navy,
        borderWidth: kUiPx * 2,
        shadow: kUiPx * 4,
        shadowColor: const Color(0x55000000),
        steps: 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'MARTI',
            style: TextStyle(
              fontSize: pixelFont(50 * widget.scale),
              color: UiColors.navy,
              letterSpacing: 4,
              height: 1,
              shadows: const [
                Shadow(
                  color: Color(0x40D9643A),
                  offset: Offset(kUiPx * 2, kUiPx * 2),
                ),
              ],
            ),
          ),
          SizedBox(height: 4 * widget.scale),
          Text(
            'ISTANBUL FLIGHT',
            style: TextStyle(
              fontSize: pixelFont(20 * widget.scale),
              color: UiColors.action,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
    if (widget.reduceMotion) return stamp;
    // Pixel art: döndürme yok; süzülme 2 noktalık adımlarla (yarım piksel kayması olmaz)
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          ((-4 + 8 * Curves.easeInOut.transform(_c.value)) / kUiPx)
                  .roundToDouble() *
              kUiPx,
        ),
        child: child,
      ),
      child: stamp,
    );
  }
}

/// Sahne üstündeki küçük bilgi rozeti (rekor, toplam simit).
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: pixelBox(color: UiColors.scrim, steps: 3),
    // merge: tema fontu (MartiPixel) korunur
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: UiColors.paper, fontSize: 15),
      child: child,
    ),
  );
}

/// Ana menü: canlı İstanbul sahnesinin (oyun READY'de süzülen Simit + akan şehir) üstünde.
/// Tam ekran dokunuşu tutar: sadece düğmeler çalışır.
class MainMenuOverlay extends StatelessWidget {
  const MainMenuOverlay({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) {
    final reduce = game.reduceMotion;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: SizedBox.expand(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxHeight < 600;
              return Column(
                children: [
                  SizedBox(height: compact ? 16 : 48),
                  LogoStamp(reduceMotion: reduce, scale: compact ? 0.8 : 1),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: game.best,
                        builder: (_, b, _) => InfoChip(
                          child: Text(
                            b == 0
                                ? 'Henüz rekor yok'
                                : 'Rekor: ${zones[zoneIndexForScore(b)].name} · $b',
                            key: const Key('bestText'),
                          ),
                        ),
                      ),
                      ValueListenableBuilder(
                        valueListenable: game.services.progress,
                        builder: (_, p, _) => InfoChip(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SimitIcon(size: 18),
                              const SizedBox(width: 6),
                              Text(
                                '${p.simitBalance}',
                                key: const Key('totalSimits'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  MenuProgressStrip(game: game),
                  const Spacer(),
                  MartiButton(
                    key: const Key('startButton'),
                    game: game,
                    label: 'Uçmaya başla',
                    icon: Icons.flight_takeoff_rounded,
                    width: (c.maxWidth - 48).clamp(220, 340),
                    height: 72,
                    onPressed: game.startFromMenu,
                  ),
                  SizedBox(height: compact ? 14 : 22),
                  ValueListenableBuilder<GameSettings>(
                    valueListenable: game.services.settings,
                    builder: (_, s, _) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RoundIconButton(
                          key: const Key('muteButton'),
                          game: game,
                          icon: s.muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          label: s.muted ? 'Ses kapalı' : 'Ses açık',
                          onPressed: () => game.services.settings.update(
                            (v) => v.copyWith(muted: !v.muted),
                          ),
                        ),
                        RoundIconButton(
                          key: const Key('settingsButton'),
                          game: game,
                          icon: Icons.tune_rounded,
                          label: 'Ayarlar',
                          onPressed: () => game.openModal(Overlays.settings),
                        ),
                        RoundIconButton(
                          key: const Key('howToButton'),
                          game: game,
                          icon: Icons.help_outline_rounded,
                          label: 'Nasıl oynanır',
                          onPressed: () => game.openModal(Overlays.howTo),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 16 : 36),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// "Uçmak için dokun": dokunuşlar oyuna geçer (IgnorePointer).
class ReadyOverlay extends StatelessWidget {
  const ReadyOverlay({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              LogoStamp(reduceMotion: true, scale: 0.7),
              const Spacer(),
              _Pulse(
                reduce: game.reduceMotion,
                child: const Column(
                  children: [
                    PixelIcon(
                      Icons.touch_app_rounded,
                      color: UiColors.paper,
                      size: 44,
                      shadows: kSceneTextShadow,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Uçmak için dokun',
                      style: TextStyle(
                        color: UiColors.paper,
                        fontSize: 25,
                        shadows: kSceneTextShadow,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Altın simitleri topla · Engellere kıl payı yaklaş',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: UiColors.paper,
                  fontSize: 15,
                  shadows: kSceneTextShadow,
                ),
              ),
              const SizedBox(height: 110),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child, required this.reduce});

  final Widget child;
  final bool reduce;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.reduce
      ? widget.child
      : FadeTransition(
          opacity: Tween(begin: 0.55, end: 1.0).animate(_c),
          child: widget.child,
        );
}

/// Ses düzeyleri (duraklatma ve ayarlar ekranında ortak).
class AudioSliders extends StatelessWidget {
  const AudioSliders({super.key, required this.game, this.dark = false});

  final IstanbulFlightGame game;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? UiColors.navy : UiColors.paper;
    return ValueListenableBuilder<GameSettings>(
      valueListenable: game.services.settings,
      builder: (_, s, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SliderRow(
            sliderKey: const Key('musicSlider'),
            icon: Icons.music_note_rounded,
            label: 'Müzik',
            value: s.musicVolume,
            color: fg,
            onChanged: (v) => game.services.settings.update(
              (x) => x.copyWith(musicVolume: v, muted: false),
            ),
          ),
          _SliderRow(
            sliderKey: const Key('sfxSlider'),
            icon: Icons.graphic_eq_rounded,
            label: 'Efektler',
            value: s.sfxVolume,
            color: fg,
            onChanged: (v) => game.services.settings.update(
              (x) => x.copyWith(sfxVolume: v, muted: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.sliderKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final Key sliderKey;
  final IconData icon;
  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      PixelIcon(icon, color: color, size: 22),
      const SizedBox(width: 8),
      SizedBox(
        width: 72,
        child: Text(label, style: TextStyle(color: color, fontSize: 15)),
      ),
      Expanded(
        child: SliderTheme(
          data: pixelSliderTheme(context),
          child: Slider(
            key: sliderKey,
            value: value,
            divisions: 10,
            label: '${(value * 100).round()}%',
            activeColor: UiColors.action,
            inactiveColor: color.withValues(alpha: 0.3),
            semanticFormatterCallback: (v) =>
                '$label ${(v * 100).round()} yüzde',
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );
}

/// PAUSED: Devam (3-2-1 geri sayımla), Yeniden başlat, Ana menü, ses düzeyleri.
/// Geri sayım bitene kadar simülasyon durur → dönüşte ani çarpışma olmaz.
class PauseOverlay extends StatefulWidget {
  const PauseOverlay({super.key, required this.game});

  final IstanbulFlightGame game;

  static const countdownStep = Duration(milliseconds: 450);

  @override
  State<PauseOverlay> createState() => _PauseOverlayState();
}

class _PauseOverlayState extends State<PauseOverlay> {
  int? _count;
  Timer? _timer;

  void _resume() {
    if (_count != null) return;
    setState(() => _count = 3);
    _timer = Timer.periodic(PauseOverlay.countdownStep, (t) {
      if (!mounted) return t.cancel();
      if (_count! <= 1) {
        t.cancel();
        widget.game.resumeGame();
      } else {
        setState(() => _count = _count! - 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final count = _count;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ColoredBox(
        color: const Color(0xA61F3A5F),
        child: SafeArea(
          child: Center(
            child: count != null
                ? Text(
                    '$count',
                    key: const Key('resumeCountdown'),
                    style: const TextStyle(
                      fontSize: 120,
                      color: UiColors.paper,
                      shadows: kSceneTextShadow,
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Duraklatıldı',
                            style: TextStyle(
                              color: UiColors.paper,
                              fontSize: 30,
                              shadows: kSceneTextShadow,
                            ),
                          ),
                          const SizedBox(height: 22),
                          MartiButton(
                            key: const Key('resumeButton'),
                            game: g,
                            label: 'Devam et',
                            icon: Icons.play_arrow_rounded,
                            width: double.infinity,
                            onPressed: _resume,
                          ),
                          const SizedBox(height: 12),
                          MartiButton(
                            key: const Key('restartFromPause'),
                            game: g,
                            label: 'Yeniden başlat',
                            icon: Icons.replay_rounded,
                            style: MartiButtonStyle.secondary,
                            width: double.infinity,
                            onPressed: g.restart,
                          ),
                          const SizedBox(height: 12),
                          MartiButton(
                            key: const Key('menuFromPause'),
                            game: g,
                            label: 'Ana menü',
                            icon: Icons.home_rounded,
                            style: MartiButtonStyle.secondary,
                            width: double.infinity,
                            onPressed: g.openMenu,
                          ),
                          const SizedBox(height: 22),
                          AudioSliders(game: g),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Modal kart iskeleti (ayarlar, nasıl oynanır, profil, görevler, başarımlar). Başlık ve "Tamam" her zaman görünür;
/// küçük ekranlarda sadece içerik kayar.
class ModalCard extends StatelessWidget {
  const ModalCard({
    super.key,
    required this.game,
    required this.title,
    required this.child,
  });

  final IstanbulFlightGame game;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {},
    child: ColoredBox(
      color: const Color(0x991F3A5F),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              // Material yüzey: içindeki anahtarların dokunma dalgası görünür olsun
              child: Material(
                color: UiColors.paper,
                shape: const PixelBorder(
                  side: BorderSide(color: UiColors.navy, width: kUiPx * 2),
                  steps: 3,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        trUpper(title),
                        style: UiText.stamp,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Flexible(child: SingleChildScrollView(child: child)),
                      const SizedBox(height: 12),
                      Center(
                        child: MartiButton(
                          key: const Key('closeModal'),
                          game: game,
                          label: 'Tamam',
                          width: 200,
                          height: 56,
                          onPressed: game.closeModal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class SettingsOverlay extends StatelessWidget {
  const SettingsOverlay({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) => ModalCard(
    game: game,
    title: 'Ayarlar',
    child: ValueListenableBuilder<GameSettings>(
      valueListenable: game.services.settings,
      builder: (_, s, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AudioSliders(game: game, dark: true),
          PixelSwitchTile(
            key: const Key('mutedSwitch'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Tüm sesi kapat',
              style: TextStyle(color: UiColors.navy),
            ),
            value: s.muted,
            activeThumbColor: UiColors.action,
            onChanged: (v) =>
                game.services.settings.update((x) => x.copyWith(muted: v)),
          ),
          PixelSwitchTile(
            key: const Key('hapticsSwitch'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Titreşim',
              style: TextStyle(color: UiColors.navy),
            ),
            subtitle: const Text('Destekleyen cihazlarda'),
            value: s.haptics,
            activeThumbColor: UiColors.action,
            onChanged: (v) =>
                game.services.settings.update((x) => x.copyWith(haptics: v)),
          ),
          PixelSwitchTile(
            key: const Key('reduceMotionSwitch'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Animasyonları azalt',
              style: TextStyle(color: UiColors.navy),
            ),
            subtitle: const Text('Sarsıntı, flaş ve büyük efektler kapanır'),
            value: s.reduceMotion,
            activeThumbColor: UiColors.action,
            onChanged: (v) => game.services.settings.update(
              (x) => x.copyWith(reduceMotion: v),
            ),
          ),
        ],
      ),
    ),
  );
}

class HowToOverlay extends StatelessWidget {
  const HowToOverlay({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) => ModalCard(
    game: game,
    title: 'Nasıl oynanır',
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Tip(
          icon: PixelIcon(
            Icons.touch_app_rounded,
            color: UiColors.navy,
            size: 32,
          ),
          title: 'Dokun',
          text: 'Her dokunuşta Simit kanat çırpar ve yükselir. Bıraktığında yavaşça alçalır.',
        ),
        _Tip(
          icon: PixelIcon(
            Icons.view_column_rounded,
            color: UiColors.navy,
            size: 32,
          ),
          title: 'Geç',
          text: 'Engellerin arasındaki boşluktan geç. Her geçiş 1 puan.',
        ),
        _Tip(
          icon: SimitIcon(size: 32),
          title: 'Topla',
          text: 'Geçitlerdeki altın simitleri topla. Kırmızı-beyaz can simitleri sadece süs.',
        ),
        _Tip(
          icon: PixelIcon(Icons.bolt_rounded, color: UiColors.action, size: 32),
          title: 'Kıl payı',
          text: 'Bir engelin çok yakınından çarpmadan geç: "KIL PAYI!"',
        ),
        _Tip(
          icon: PixelIcon(
            Icons.wb_twilight_rounded,
            color: UiColors.navy,
            size: 32,
          ),
          title: 'Gün ilerler',
          text: 'Haliç\'te şafakta başla, Rumeli Hisarı\'nda geceye uç.',
        ),
      ],
    ),
  );
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.title, required this.text});

  final Widget icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 40, child: Center(child: icon)),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$title  ',
                  style: const TextStyle(color: UiColors.navy),
                ),
                TextSpan(
                  text: text,
                  style: const TextStyle(color: UiColors.navySoft),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 15, height: 1.3),
          ),
        ),
      ],
    ),
  );
}
