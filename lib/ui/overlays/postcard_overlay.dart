import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../challenge/daily_state.dart';
import '../../game/components/landmark_layer.dart';
import '../../game/day_cycle.dart';
import '../../game/game_art.dart';
import '../../game/istanbul_flight_game.dart';
import '../../game/visual/simit_animator.dart';
import '../../services/share_service.dart';
import '../pixel.dart';
import '../simit_frame_view.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/simit_icon.dart';
import 'daily_overlays.dart';
import 'progression_overlays.dart';

/// Oyun sonu: düşülen bölgenin kartpostalı (yolculuğun hatırası) + Tekrar uç / Paylaş / Ana menü.
class GameOverOverlay extends StatefulWidget {
  const GameOverOverlay({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> {
  final _cardKey = GlobalKey();
  final _shareAnchor = GlobalKey(); // iPad paylaşım menüsünün başlangıç noktası
  bool _sharing = false;

  Future<void> _share() async {
    final g = widget.game;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _sharing = true);
    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    final png = boundary == null ? null : await captureBoundaryPng(boundary);
    final zone = zones[g.zoneIndex.value];
    final anchor =
        _shareAnchor.currentContext?.findRenderObject() as RenderBox?;
    final origin = anchor != null && anchor.hasSize
        ? anchor.localToGlobal(Offset.zero) & anchor.size
        : null;
    final outcome = png == null
        ? ShareOutcome.failed
        : await g.services.share.sharePostcard(
            png,
            shareText(
              zoneName: zone.name,
              score: g.score.value,
              simits: g.runSimits.value,
              dailyDate: g.runMode.value.isDaily
                  ? g.dailyDefinition.value?.dateUtc
                  : null,
            ),
            origin: origin,
          );
    if (!mounted) return;
    setState(() => _sharing = false);
    final msg = switch (outcome) {
      ShareOutcome.shared => 'Kartpostal paylaşıldı.',
      ShareOutcome.downloaded =>
        'Bu tarayıcı paylaşımı desteklemiyor; kartpostal indirildi.',
      ShareOutcome.dismissed => null,
      ShareOutcome.failed => 'Kartpostal paylaşılamadı. Lütfen tekrar deneyin.',
    };
    if (msg != null) {
      messenger?.showSnackBar(
        SnackBar(content: Text(msg), key: const Key('shareResult')),
      );
    }
  }

  /// Günün Uçuşu'nda "Tekrar uç" yerine: dereceli hak varsa yeniden dene, yoksa antrenman.
  Widget _dailyAgain(IstanbulFlightGame g, bool ok) {
    final p = g.services.progress.value;
    final id = g.dailyDefinition.value?.challengeId;
    final remaining = id == null
        ? 0
        : (p.dailyChallenge[id]?.remaining ?? DailyRules.rankedAttempts);
    final canRank =
        remaining > 0 && g.services.daily.clockStatus(p) == DailyClockStatus.ok;
    return MartiButton(
      key: Key(canRank ? 'dailyRetry' : 'dailyPracticeAgain'),
      game: g,
      label: canRank ? 'Yeniden dene · $remaining hak' : 'Antrenman yap',
      icon: Icons.replay_rounded,
      width: double.infinity,
      onPressed: ok ? () => g.startDaily(ranked: canRank) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final reduce = g.reduceMotion;
    final daily = g.runMode.value.isDaily;
    final dailyBest = g.services.progress.lastDaily.value?.newBest ?? false;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ColoredBox(
        color: const Color(0x80000000),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduce ? 1 : 0, end: 1),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutBack,
                  builder: (context, t, child) => Transform.translate(
                    offset: Offset(0, (1 - t) * 140),
                    child: Opacity(opacity: t.clamp(0, 1), child: child),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          RepaintBoundary(
                            key: _cardKey,
                            child: Postcard(game: g),
                          ),
                          if ((g.isNewRecord.value || dailyBest) && !reduce)
                            const Positioned.fill(
                              child: IgnorePointer(child: SesameConfetti()),
                            ),
                        ],
                      ),
                      // Uçuş özeti paylaşılan kartpostalın dışında: kart kompozisyonu değişmez
                      const SizedBox(height: 12),
                      if (daily) ...[
                        DailyResultPanel(game: g),
                        const SizedBox(height: 8),
                      ],
                      RunSummaryPanel(game: g),
                      const SizedBox(height: 16),
                      ValueListenableBuilder<bool>(
                        valueListenable: g.canRestart,
                        builder: (_, ok, _) => daily
                            ? _dailyAgain(g, ok)
                            : MartiButton(
                                key: const Key('restartButton'),
                                game: g,
                                label: 'Tekrar uç',
                                icon: Icons.replay_rounded,
                                width: double.infinity,
                                onPressed: ok ? g.restart : null,
                              ),
                      ),
                      const SizedBox(height: 12),
                      // Esnek genişlik: 320 px'lik ekranlarda da taşmaz
                      Row(
                        children: [
                          Expanded(
                            child: KeyedSubtree(
                              key: _shareAnchor,
                              child: MartiButton(
                                key: const Key('shareButton'),
                                game: g,
                                label: _sharing ? 'Hazırlanıyor' : 'Paylaş',
                                icon: Icons.ios_share_rounded,
                                style: MartiButtonStyle.secondary,
                                onPressed: _sharing ? null : _share,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MartiButton(
                              key: const Key('menuButton'),
                              game: g,
                              label: 'Ana menü',
                              icon: Icons.home_rounded,
                              style: MartiButtonStyle.secondary,
                              onPressed: g.openMenu,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartpostal (paylaşılan görselin kendisi). Ön yüz: bölge illüstrasyonu + selam + pul.
/// Alt kısım: yolculuk özeti. Sabit tasarım; paylaşımda 1080 px genişliğe ölçeklenir.
class Postcard extends StatelessWidget {
  const Postcard({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) {
    final zone = zones[game.zoneIndex.value];
    // Günün Uçuşu: rekor yerine günün en iyisi; damga günlük rekor için (klasik rekor değişmez)
    final daily = game.runMode.value.isDaily
        ? game.services.progress.lastDaily.value
        : null;
    final dailyDate = game.runMode.value.isDaily
        ? game.dailyDefinition.value?.dateUtc
        : null;
    final newRecord = daily != null ? daily.newBest : game.isNewRecord.value;
    return Container(
      decoration: pixelBox(
        color: UiColors.paper,
        shadow: kUiPx * 4,
        shadowColor: const Color(0x66000000),
        steps: 3,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---- Ön yüz: bölgenin illüstrasyonu ----
          AspectRatio(
            aspectRatio: 16 / 10,
            child: ClipPath(
              clipper: const ShapeBorderClipper(shape: PixelBorder(steps: 1)),
              // Simit kart genişliğine göre 2× ya da 3× (tam sayı ölçek)
              child: LayoutBuilder(
                builder: (context, c) {
                  final k = c.maxWidth < 300 ? 2.0 : 3.0;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: ZonePostcardPainter(
                            zone: zone,
                            art: game.art.zones[zone.kit.name],
                            landmark: game.art.landmarks[zone.landmark],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 2,
                        width: 48 * k,
                        height: 42 * k,
                        child: SimitFrameView(
                          key: const Key('postcardSimit'),
                          image: game.birdSheet,
                          frame: SimitAnimator.landed,
                        ),
                      ),
                      Positioned(
                        left: 10,
                        top: 10,
                        child: _PostStamp(zone: zone),
                      ),
                      Positioned(
                        left: 12,
                        right: 48 * k - 20,
                        bottom: 10,
                        child: Text(
                          zone.greeting,
                          key: const Key('greetingText'),
                          style: const TextStyle(
                            color: UiColors.paper,
                            fontSize: 20,
                            height: 1.1,
                            shadows: [
                              Shadow(
                                color: Color(0xCC000000),
                                offset: Offset(kUiPx, kUiPx),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ---- Yolculuk özeti ----
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Ulaşılan bölge: ',
                  style: TextStyle(color: UiColors.navySoft),
                ),
                TextSpan(
                  text: zone.name,
                  style: const TextStyle(color: UiColors.navy),
                ),
                TextSpan(
                  text: '  ·  ${game.zoneIndex.value + 1}/${zones.length}',
                  style: const TextStyle(color: UiColors.navySoft),
                ),
              ],
            ),
            key: const Key('reachedZone'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'SKOR',
                    value: game.score.value,
                    valueKey: const Key('finalScore'),
                  ),
                ),
                const VerticalDivider(color: Color(0xFFD8CDB6), thickness: 1),
                Expanded(
                  child: _Stat(
                    label: dailyDate != null ? 'EN İYİ' : 'REKOR',
                    value: dailyDate != null
                        ? daily?.bestScore ?? 0
                        : game.best.value,
                    valueKey: const Key('finalBest'),
                  ),
                ),
                const VerticalDivider(color: Color(0xFFD8CDB6), thickness: 1),
                Expanded(
                  child: _Stat(
                    label: 'SİMİT',
                    value: game.runSimits.value,
                    valueKey: const Key('finalSimits'),
                    leading: const SimitIcon(size: 20),
                  ),
                ),
              ],
            ),
          ),
          if (game.nearMisses.value > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Kıl payı geçiş: ${game.nearMisses.value}',
              key: const Key('finalNearMisses'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: UiColors.action),
            ),
          ],
          if (newRecord) ...[
            const SizedBox(height: 8),
            Center(
              child: _RecordStamp(
                child: Container(
                  key: const Key('newRecordStamp'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: pixelBox(
                    color: UiColors.paper,
                    border: UiColors.action,
                    borderWidth: kUiPx * 2,
                    steps: 1,
                  ),
                  child: Text(
                    dailyDate != null ? 'GÜNÜN REKORU!' : 'YENİ REKOR!',
                    style: const TextStyle(
                      color: UiColors.action,
                      letterSpacing: 2,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            dailyDate != null
                ? 'Martı: Istanbul Flight – Günün Uçuşu · ${formatDailyDate(dailyDate)}'
                : 'Martı: Istanbul Flight',
            key: const Key('postcardFooter'),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: UiColors.navySoft,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.valueKey,
    this.leading,
  });

  final String label;
  final int value;
  final Key valueKey;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          letterSpacing: 2,
          color: UiColors.navySoft,
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 4)],
          Text(
            '$value',
            key: valueKey,
            style: const TextStyle(
              fontSize: 30,
              color: UiColors.navy,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ],
  );
}

/// Kartpostal pulu: tırtıklı kenar, bölge adı.
class _PostStamp extends StatelessWidget {
  const _PostStamp({required this.zone});

  final Zone zone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: pixelBox(
      color: UiColors.paper,
      border: UiColors.navy,
      shadow: kUiPx,
      steps: 1,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          trUpper(zone.name),
          style: const TextStyle(
            color: UiColors.navy,
            fontSize: 15,
            letterSpacing: 1,
          ),
        ),
        const Text(
          'İSTANBUL',
          style: TextStyle(
            color: UiColors.action,
            fontSize: 10,
            letterSpacing: 2,
          ),
        ),
      ],
    ),
  );
}

/// "YENİ REKOR!" damgası: pixel "basılma" animasyonu. Büyükten küçüğe 3 sabit adımda iner
/// (ara ölçekler yok → bitmap font bulanıklaşmaz), sonra yerinde 2 kez yanıp söner.
class _RecordStamp extends StatefulWidget {
  const _RecordStamp({required this.child});

  final Widget child;

  @override
  State<_RecordStamp> createState() => _RecordStampState();
}

class _RecordStampState extends State<_RecordStamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (_, child) {
      final t = _c.value;
      final scale = t < 0.12
          ? 2.0
          : t < 0.24
          ? 1.5
          : 1.0;
      final visible = t < 0.5 || t >= 0.9 || (t * 10).floor().isEven;
      return Opacity(
        opacity: visible ? 1 : 0.35,
        child: Transform.scale(scale: scale, child: child),
      );
    },
  );
}

/// Bölgenin kartpostal illüstrasyonu: oyundaki pixel art katmanlarının sabit bir kompozisyonu
/// (gök, güneş/ay, bulut, uzak şehir, simge, orta plan, su, kıyı). Oyun sahnesinin ufuk çevresindeki
/// 592×370 piksellik kesiti, en yakın komşu örneklemeyle kart boyutuna ölçeklenir.
/// Görseller yüklenmemişse bölge paletinden düz renkli yedek çizim yapılır.
class ZonePostcardPainter extends CustomPainter {
  ZonePostcardPainter({
    required this.zone,
    required this.art,
    required this.landmark,
  });

  final Zone zone;
  final ZoneArt? art;
  final ui.Image? landmark;

  /// Kesit (art pikseli): genişlik 592, oyun sahnesinin 40–410. satırları.
  static const viewW = 592.0, viewH = 370.0, cropTop = 40.0, horizon = 298.0;

  static const _sunAt = {
    // halic: güneş kameranın arkasında (docs/11)
    'galata': (0.8, 70.0),
    // kizkulesi: güneş kameranın arkasında (docs/10)
    'kopru': (0.82, 64.0),
    'rumeli': (0.8, 58.0),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final p = zone.palette, a = art;
    final px = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / viewW, size.height / viewH);
    canvas.translate(0, -cropTop);

    void strip(ui.Image? img, double top) {
      if (img == null) return;
      for (var x = 0.0; x < viewW; x += img.width) {
        canvas.drawImage(img, Offset(x, top), px);
      }
    }

    if (a?.sky == null) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, viewW, horizon),
        Paint()..color = p.skyMid,
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, horizon, viewW, 200),
        Paint()..color = p.water,
      );
    }
    strip(a?.sky, 0);
    // Yıldızlar (gece bölgeleri): tek piksel
    if (p.stars > 0.1) {
      final rnd = math.Random(4);
      final star = Paint()
        ..color = const Color(0xFFFFF4DC).withValues(alpha: p.stars * 0.8);
      for (var i = 0; i < 40; i++) {
        final x = (rnd.nextDouble() * viewW).floorToDouble();
        final y = (cropTop + rnd.nextDouble() * 150).floorToDouble();
        canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), star);
      }
    }
    final sunAt = _sunAt[zone.kit.name];
    if (a?.sun != null && sunAt != null) {
      canvas.drawImage(
        a!.sun!,
        Offset((viewW * sunAt.$1).roundToDouble() - 48, sunAt.$2 - 48),
        px,
      );
    }
    if (a?.clouds != null) {
      for (final (i, x, y) in [(0, 30.0, 70.0), (2, 380.0, 120.0)]) {
        final src = ZoneArt.cloudRects[i];
        canvas.drawImageRect(
          a!.clouds!,
          src,
          Rect.fromLTWH(x, y, src.width, src.height),
          px,
        );
      }
    }
    strip(a?.distant, horizon - (a?.distant?.height ?? 0) + 1);
    // Simge: odak noktası kartın %44'ünde (sağdaki Simit'in solunda), oyundaki yerleşimin piksel karşılığı (1/kArtPx)
    // Simge: odak noktası kartın %62'sinde, oyundaki yerleşimin piksel karşılığı (1/kArtPx)
    final img = landmark;
    final lay = LandmarkLayer.layout(zone.landmark);
    final front = LandmarkLayer.isFront(zone.landmark);
    void drawLandmark() {
      if (img == null) return;
      final w = lay.w / kArtPx, h = lay.h / kArtPx;
      final left = (viewW * 0.44 - w * lay.focus).roundToDouble();
      final base = horizon + lay.baseOffset / kArtPx;
      if (front) {
        // soluk su yansıması
        canvas.save();
        canvas.translate(0, base * 2);
        canvas.scale(1, -1);
        canvas.drawImage(
          img,
          Offset(left, base - h),
          Paint()
            ..filterQuality = FilterQuality.none
            ..color = const Color(0x40000000),
        );
        canvas.restore();
      }
      canvas.drawImage(img, Offset(left, base - h), px);
    }

    if (!front) drawLandmark();
    strip(a?.midground, horizon - (a?.midground?.height ?? 0) + 1);
    strip(a?.water, horizon);
    strip(a?.waterHi, horizon);
    strip(a?.waterfront, horizon - ZoneArt.waterfrontHorizonRow);
    if (front) drawLandmark();
    canvas.restore();

    // Baskı dokusu hissi: ince kenar çerçevesi (keskin)
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..isAntiAlias = false
        ..color = const Color(0x22000000),
    );
  }

  @override
  bool shouldRepaint(ZonePostcardPainter old) =>
      old.zone != zone || old.art != art || old.landmark != landmark;
}

/// Yeni rekorda kartpostalın üstünden süzülen pixel susamlar (kısa, tek seferlik).
class SesameConfetti extends StatefulWidget {
  const SesameConfetti({super.key});

  @override
  State<SesameConfetti> createState() => _SesameConfettiState();
}

class _SesameConfettiState extends State<SesameConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => CustomPaint(painter: _ConfettiPainter(_c.value)),
  );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final rnd = math.Random(9);
    final paint = Paint();
    const colors = [
      Color(0xFFFBF2D0),
      Color(0xFFE8B04B),
      Color(0xFFC8803A),
      Color(0xFFB84A26),
    ];
    for (var i = 0; i < 36; i++) {
      final x = rnd.nextDouble() * size.width;
      final speed = 0.6 + rnd.nextDouble() * 0.6;
      final y =
          -20 + (size.height * 0.9) * (t * speed) + math.sin(t * 8 + i) * 8;
      paint.color = colors[i % colors.length].withValues(
        alpha: (1 - t).clamp(0, 1),
      );
      // Pixel susam: ızgaraya oturan 3×2 / 2×3 piksel (dönme yerine yön değiştirir)
      final gx = (x / kUiPx).roundToDouble() * kUiPx,
          gy = (y / kUiPx).roundToDouble() * kUiPx;
      final flip = ((t * 10).floor() + i).isEven;
      canvas.drawRect(
        Rect.fromLTWH(gx, gy, kUiPx * (flip ? 3 : 2), kUiPx * (flip ? 2 : 3)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
