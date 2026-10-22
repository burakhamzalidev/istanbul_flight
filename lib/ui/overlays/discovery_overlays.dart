import 'package:flutter/material.dart';

import '../../game/day_cycle.dart';
import '../../game/game_art.dart';
import '../../game/istanbul_flight_game.dart';
import '../../progression/cosmetics.dart';
import '../../progression/discovery.dart';
import '../../services/progress.dart';
import '../pixel.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/simit_icon.dart';
import 'menu_overlays.dart';
import 'postcard_overlay.dart';
import 'progression_overlays.dart';
import 'shop_overlays.dart';

// Phase 2.3 arayüzü: İstanbul keşif haritası, kartpostal albümü ve bölge detayı (docs/15 §8).
// Tek pencere (Overlays.discovery), içinde sekme ve geri gezinmesi: ana menüye tek giriş noktası eklenir.
// Kartpostal görselleri oyunun zaten yüklü pixel art katmanlarından çizilir (ZonePostcardPainter);
// yalnızca harita görseli (160×160) bu ekran açılınca yüklenir.

/// Ana menüdeki tek giriş noktası: "İstanbul'u Keşfet" + albüm ilerlemesi.
class DiscoveryMenuButton extends StatelessWidget {
  const DiscoveryMenuButton({super.key, required this.game, this.compact});

  final IstanbulFlightGame game;

  /// Kısa etiket ("Keşfet"). null: ekran genişliğinden karar verilir.
  final bool? compact;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<PlayerProgress>(
    valueListenable: game.services.progress,
    builder: (context, p, _) {
      final cards = p.discoveredZones.length;
      final pct = (p.discovery.albumFraction * 100).floor();
      // dar ekranda kısa etiket (yanında Sıralama düğmesi var, Phase 2.4)
      final narrow = compact ?? MediaQuery.sizeOf(context).width < 400;
      return Pressable(
        key: const Key('discoveryButton'),
        game: game,
        semanticLabel:
            "İstanbul'u Keşfet, $cards / ${zones.length} kartpostal, albüm yüzde $pct",
        onTap: () => game.openModal(Overlays.discovery),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: pixelBox(
              color: UiColors.scrim,
              border: UiColors.mustard,
              steps: 3,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PixelIcon(
                  Icons.map_rounded,
                  color: UiColors.mustard,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    narrow ? 'Keşfet' : "İstanbul'u Keşfet",
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: UiColors.paper, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '%$pct',
                  key: const Key('discoveryMenuCount'),
                  style: const TextStyle(color: UiColors.mustard, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

enum _Tab { map, album }

class DiscoveryOverlay extends StatefulWidget {
  const DiscoveryOverlay({super.key, required this.game, this.initialZone});

  final IstanbulFlightGame game;

  /// Testler: doğrudan bir bölge detayıyla açılır.
  final int? initialZone;

  @override
  State<DiscoveryOverlay> createState() => _DiscoveryOverlayState();
}

class _DiscoveryOverlayState extends State<DiscoveryOverlay> {
  _Tab _tab = _Tab.map;
  late int? _zone = widget.initialZone;

  IstanbulFlightGame get g => widget.game;

  void _open(int zone) => setState(() => _zone = zone);

  @override
  Widget build(BuildContext context) => ModalCard(
    game: g,
    title: "İstanbul'u Keşfet",
    child: ValueListenableBuilder<PlayerProgress>(
      valueListenable: g.services.progress,
      builder: (context, p, _) {
        final zone = _zone;
        if (zone != null) {
          return _ZoneDetail(
            key: Key('zoneDetail_$zone'),
            game: g,
            progress: p,
            zone: zone,
            backLabel: _tab == _Tab.map ? 'Harita' : 'Albüm',
            onBack: () => setState(() => _zone = null),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AlbumHeader(progress: p),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TabChip(
                    key: const Key('discoveryTabMap'),
                    game: g,
                    icon: Icons.map_rounded,
                    label: 'Harita',
                    selected: _tab == _Tab.map,
                    onTap: () => setState(() => _tab = _Tab.map),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TabChip(
                    key: const Key('discoveryTabAlbum'),
                    game: g,
                    icon: Icons.military_tech_rounded,
                    label: 'Albüm',
                    selected: _tab == _Tab.album,
                    onTap: () => setState(() => _tab = _Tab.album),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_tab == _Tab.map) ...[
              IstanbulMap(game: g, progress: p, onZone: _open),
              const SizedBox(height: 6),
              const Text(
                'Kuzey yukarıda. Numaralar uçuş sırasını, konumlar gerçek '
                'yerleri gösterir.',
                key: Key('mapLegend'),
                textAlign: TextAlign.center,
                style: TextStyle(color: UiColors.navySoft, fontSize: 10),
              ),
              const SizedBox(height: 8),
              for (var z = 0; z < zones.length; z++)
                _ZoneRow(game: g, progress: p, zone: z, onTap: () => _open(z)),
            ] else ...[
              for (var z = 0; z < zones.length; z++) ...[
                _PostcardTile(
                  game: g,
                  progress: p,
                  zone: z,
                  onTap: () => _open(z),
                ),
                const SizedBox(height: 8),
              ],
              _AlbumReward(game: g, progress: p),
            ],
          ],
        );
      },
    ),
  );
}

/// Albüm özeti: tamamlanma yüzdesi, rozetler, hedefler.
class _AlbumHeader extends StatelessWidget {
  const _AlbumHeader({required this.progress});

  final PlayerProgress progress;

  @override
  Widget build(BuildContext context) {
    final d = progress.discovery;
    final pct = (d.albumFraction * 100).floor();
    return Container(
      key: const Key('albumProgress'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: pixelBox(
        color: UiColors.cream,
        border: UiColors.mustard,
        steps: 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Albüm %$pct',
                  key: const Key('albumPercent'),
                  style: const TextStyle(color: UiColors.navy),
                ),
              ),
              const PixelIcon(
                Icons.military_tech_rounded,
                color: UiColors.mustard,
                size: 24,
              ),
              const SizedBox(width: 4),
              Text(
                '${d.badges.length}/${discoveryZones.length}',
                key: const Key('albumBadges'),
                style: const TextStyle(color: UiColors.navy),
              ),
            ],
          ),
          const SizedBox(height: 6),
          XpBar(fraction: d.albumFraction, height: 12),
          const SizedBox(height: 4),
          Text(
            'Kartpostal ${progress.discoveredZones.length}/${zones.length} · '
            'Hedef ${d.goalsDone}/${DiscoveryState.goalsTotal}',
            style: const TextStyle(color: UiColors.navySoft, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    super.key,
    required this.game,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IstanbulFlightGame game;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: Pressable(
      game: game,
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pixelBox(
          color: selected ? UiColors.navy : UiColors.cream,
          border: selected ? UiColors.mustard : const Color(0xFFD8CDB6),
          steps: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PixelIcon(
              icon,
              color: selected ? UiColors.mustard : UiColors.navySoft,
              size: 24,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? UiColors.paper : UiColors.navy,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ======================= Harita =======================

/// Bölgenin albüm durumu (harita işareti ve kart rengi).
enum ZoneAlbumState { locked, discovered, badge }

ZoneAlbumState zoneAlbumState(PlayerProgress p, int zone) =>
    !p.discoveredZones.contains(zone)
    ? ZoneAlbumState.locked
    : p.discovery.badges.containsKey(zone)
    ? ZoneAlbumState.badge
    : ZoneAlbumState.discovered;

/// İstanbul pixel haritası: gerçek konumlarda bölge işaretleri, uçuş sırasında kesikli rota.
/// Ölçek, cihaz pikselinde tam sayı olacak şekilde seçilir (keskin pixel art).
class IstanbulMap extends StatelessWidget {
  const IstanbulMap({
    super.key,
    required this.game,
    required this.progress,
    required this.onZone,
  });

  final IstanbulFlightGame game;
  final PlayerProgress progress;
  final ValueChanged<int> onZone;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      const n = MapProjection.size;
      final devicePx = (c.maxWidth * dpr / n).floorToDouble().clamp(1.0, 12.0);
      final k = devicePx / dpr;
      final side = n * k;
      Offset at(int z) {
        final dz = discoveryZones[z];
        final m = MapProjection.toMap(dz.lat, dz.lon);
        return Offset(m.x * k, m.y * k);
      }

      return Center(
        child: Container(
          key: const Key('istanbulMap'),
          decoration: pixelBox(
            color: const Color(0xFF3A77A3),
            border: UiColors.navy,
            borderWidth: kUiPx,
            steps: 1,
          ),
          padding: const EdgeInsets.all(kUiPx),
          child: SizedBox.square(
            dimension: side,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    GameArt.mapPath,
                    width: side,
                    height: side,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.none,
                    isAntiAlias: false,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Color(0xFFE9DCBC)),
                  ),
                ),
                // Su ve kıta adları (gerçek coğrafya; dar sular için ad kıyıda)
                _mapLabel('MARMARA', 0.10, 0.94, k),
                _mapLabel('HALİÇ', 0.08, 0.35, k, land: true),
                _mapLabel('BOĞAZİÇİ', 0.50, 0.27, k, land: true),
                _mapLabel('AVRUPA', 0.24, 0.10, k, land: true),
                _mapLabel('ASYA', 0.72, 0.80, k, land: true),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RoutePainter(
                      [for (var z = 0; z < zones.length; z++) at(z)],
                      reached: progress.maxZone,
                      unit: k,
                    ),
                  ),
                ),
                for (var z = 0; z < zones.length; z++)
                  _MapMarker(
                    key: Key('mapMarker_$z'),
                    game: game,
                    zone: z,
                    state: zoneAlbumState(progress, z),
                    center: at(z),
                    onTap: () => onZone(z),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _mapLabel(
    String text,
    double fx,
    double fy,
    double k, {
    bool land = false,
  }) => Positioned(
    left: MapProjection.size * k * fx,
    top: MapProjection.size * k * fy,
    child: IgnorePointer(
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 1,
          color: land ? const Color(0xFF6E5236) : const Color(0xFFDDF0F6),
        ),
      ),
    ),
  );
}

/// Uçuş rotası: oyun sırasıyla bölgeleri birleştiren kesikli çizgi (gidilen kısım altın, kalanı soluk).
class _RoutePainter extends CustomPainter {
  _RoutePainter(this.points, {required this.reached, required this.unit});

  final List<Offset> points;
  final int reached;
  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    final dash = unit * 2;
    for (var i = 0; i + 1 < points.length; i++) {
      final a = points[i], b = points[i + 1];
      final done = i + 1 <= reached;
      final paint = Paint()
        ..isAntiAlias = false
        ..color = done ? const Color(0xFFE8B04B) : const Color(0x991F3A5F);
      final len = (b - a).distance;
      final steps = (len / (dash * 2)).floor();
      for (var s = 0; s < steps; s++) {
        final p = Offset.lerp(a, b, (s * 2 * dash) / len)!;
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(
              (p.dx / unit).roundToDouble() * unit,
              (p.dy / unit).roundToDouble() * unit,
            ),
            width: unit * 1.5,
            height: unit * 1.5,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.reached != reached || old.unit != unit || old.points != points;
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    super.key,
    required this.game,
    required this.zone,
    required this.state,
    required this.center,
    required this.onTap,
  });

  final IstanbulFlightGame game;
  final int zone;
  final ZoneAlbumState state;
  final Offset center;
  final VoidCallback onTap;

  static const size = 30.0;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (state) {
      ZoneAlbumState.locked => (const Color(0xFFBFB39B), UiColors.navySoft),
      ZoneAlbumState.discovered => (UiColors.navy, UiColors.paper),
      ZoneAlbumState.badge => (UiColors.mustard, UiColors.navy),
    };
    final status = switch (state) {
      ZoneAlbumState.locked => 'kilitli',
      ZoneAlbumState.discovered => 'keşfedildi',
      ZoneAlbumState.badge => 'rozet kazanıldı',
    };
    return Positioned(
      // dokunma alanı 44 pt; görünen işaret 30 pt
      left: center.dx - 22,
      top: center.dy - 22,
      width: 44,
      height: 44,
      child: Pressable(
        game: game,
        onTap: onTap,
        semanticLabel: '${zone + 1}. durak, ${zones[zone].name}, $status',
        child: Center(
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: pixelBox(
              color: bg,
              border: state == ZoneAlbumState.locked
                  ? UiColors.navySoft
                  : UiColors.paper,
              shadow: kUiPx,
              steps: 2,
            ),
            child: state == ZoneAlbumState.locked
                ? PixelIcon(Icons.lock_rounded, color: fg, size: 12)
                : Text(
                    '${zone + 1}',
                    style: TextStyle(color: fg, fontSize: 15, height: 1),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Harita altındaki bölge satırı: sıra, ad, tamamlanma.
class _ZoneRow extends StatelessWidget {
  const _ZoneRow({
    required this.game,
    required this.progress,
    required this.zone,
    required this.onTap,
  });

  final IstanbulFlightGame game;
  final PlayerProgress progress;
  final int zone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = zoneAlbumState(progress, zone);
    final locked = state == ZoneAlbumState.locked;
    final frac = progress.discovery.zoneFraction(zone);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Pressable(
        key: Key('zoneRow_$zone'),
        game: game,
        onTap: onTap,
        semanticLabel:
            '${zones[zone].name}, ${locked ? 'kilitli' : '%${(frac * 100).floor()} tamamlandı'}',
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pixelBox(
            color: UiColors.cream,
            border: state == ZoneAlbumState.badge
                ? UiColors.mustard
                : const Color(0xFFD8CDB6),
            steps: 2,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '${zone + 1}',
                  style: const TextStyle(color: UiColors.navySoft),
                ),
              ),
              Expanded(
                child: Text(
                  locked ? '???' : zones[zone].name,
                  style: TextStyle(
                    color: locked ? UiColors.navySoft : UiColors.navy,
                  ),
                ),
              ),
              if (locked)
                Text(
                  '${zones[zone].startScore} puanda açılır',
                  style: const TextStyle(
                    color: UiColors.navySoft,
                    fontSize: 10,
                  ),
                )
              else ...[
                SizedBox(width: 56, child: XpBar(fraction: frac, height: 10)),
                const SizedBox(width: 6),
                if (state == ZoneAlbumState.badge)
                  const PixelIcon(
                    Icons.military_tech_rounded,
                    color: UiColors.mustard,
                    size: 24,
                  )
                else
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${progress.discovery.doneInZone(zone)}/3',
                      style: const TextStyle(
                        color: UiColors.navySoft,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= Kartpostallar =======================

/// Bölge kartpostalının görseli: oyundaki pixel art katmanları (yüklü olanlar). Kilitliyse soluk ve gri.
class ZonePostcardImage extends StatelessWidget {
  const ZonePostcardImage({
    super.key,
    required this.game,
    required this.zone,
    required this.locked,
  });

  final IstanbulFlightGame game;
  final int zone;
  final bool locked;

  static const _grey = ColorFilter.matrix([
    0.2, 0.45, 0.1, 0, 10, //
    0.2, 0.45, 0.1, 0, 14,
    0.2, 0.45, 0.1, 0, 26,
    0, 0, 0, 0.55, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final z = zones[zone];
    Widget img = CustomPaint(
      painter: ZonePostcardPainter(
        zone: z,
        art: game.art.zones[z.kit.name],
        landmark: game.art.landmarks[z.landmark],
      ),
    );
    if (locked) img = ColorFiltered(colorFilter: _grey, child: img);
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: PixelBorder(steps: 1)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: UiColors.navySoft),
            img,
            if (locked)
              const Center(
                child: PixelIcon(
                  Icons.lock_rounded,
                  color: UiColors.paper,
                  size: 36,
                  shadows: [
                    Shadow(color: Color(0x991F3A5F), offset: Offset(0, 2)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PostcardTile extends StatelessWidget {
  const _PostcardTile({
    required this.game,
    required this.progress,
    required this.zone,
    required this.onTap,
  });

  final IstanbulFlightGame game;
  final PlayerProgress progress;
  final int zone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = zoneAlbumState(progress, zone);
    final locked = state == ZoneAlbumState.locked;
    final pct = (progress.discovery.zoneFraction(zone) * 100).floor();
    return Pressable(
      key: Key('postcardTile_$zone'),
      game: game,
      onTap: onTap,
      semanticLabel: locked
          ? '${zone + 1}. kartpostal, kilitli'
          : '${zones[zone].name} kartpostalı, yüzde $pct',
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: pixelBox(
          color: UiColors.paper,
          border: state == ZoneAlbumState.badge
              ? UiColors.mustard
              : const Color(0xFFD8CDB6),
          borderWidth: state == ZoneAlbumState.badge ? kUiPx * 2 : kUiPx,
          shadow: kUiPx * 2,
          steps: 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ZonePostcardImage(game: game, zone: zone, locked: locked),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    locked ? '${zone + 1}. kartpostal' : zones[zone].name,
                    style: const TextStyle(color: UiColors.navy),
                  ),
                ),
                if (state == ZoneAlbumState.badge) ...[
                  const PixelIcon(
                    Icons.military_tech_rounded,
                    color: UiColors.mustard,
                    size: 24,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  locked ? '${zones[zone].startScore} puanda açılır' : '%$pct',
                  style: const TextStyle(
                    color: UiColors.navySoft,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Albüm ödülü: beş rozet → İznik Martısı (mağazada satılmaz).
class _AlbumReward extends StatelessWidget {
  const _AlbumReward({required this.game, required this.progress});

  final IstanbulFlightGame game;
  final PlayerProgress progress;

  @override
  Widget build(BuildContext context) {
    final reward = cosmeticById(DiscoveryConfig.albumRewardCosmetic);
    if (reward == null) return const SizedBox.shrink();
    final owned = ownsCosmetic(progress, reward.id);
    return Container(
      key: const Key('albumReward'),
      padding: const EdgeInsets.all(8),
      decoration: pixelBox(
        color: const Color(0xFFF6EBC8),
        border: UiColors.mustard,
        steps: 2,
      ),
      child: Row(
        children: [
          Opacity(
            opacity: owned ? 1 : 0.6,
            child: SimitPreview(
              image: sheetOf(game, reward.id),
              scale: 2,
              animate: false,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reward.name, style: const TextStyle(color: UiColors.navy)),
                Text(
                  owned
                      ? 'Açıldı! Martı Görünümü’nden seçebilirsin.'
                      : 'Beş bölgenin rozetini topla, bu görünüm açılsın. '
                            'Mağazada satılmaz.',
                  key: const Key('albumRewardText'),
                  style: const TextStyle(
                    color: UiColors.navySoft,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ======================= Bölge detayı =======================

const _months = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

/// "23 Ekim 2026" (yerel tarih).
String formatDiscoveryDate(DateTime d) {
  final l = d.toLocal();
  return '${l.day} ${_months[l.month - 1]} ${l.year}';
}

class _ZoneDetail extends StatelessWidget {
  const _ZoneDetail({
    super.key,
    required this.game,
    required this.progress,
    required this.zone,
    required this.backLabel,
    required this.onBack,
  });

  final IstanbulFlightGame game;
  final PlayerProgress progress;
  final int zone;
  final String backLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final dz = discoveryZones[zone];
    final d = progress.discovery;
    final state = zoneAlbumState(progress, zone);
    final locked = state == ZoneAlbumState.locked;
    final seen = d.firstSeen[zone];
    final record = d.zoneRecords[zone];
    final firstSeenText = locked
        ? 'Henüz keşfedilmedi: tek uçuşta ${zones[zone].startScore} puana ulaş.'
        : seen != null
        ? 'İlk keşif: ${formatDiscoveryDate(seen)}'
        : 'Önceki bir sürümde keşfedildi (tarih kaydı yok).';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: MartiButton(
            key: const Key('discoveryBack'),
            game: game,
            label: backLabel,
            icon: Icons.arrow_back_rounded,
            style: MartiButtonStyle.secondary,
            height: 44,
            onPressed: onBack,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: pixelBox(
            color: UiColors.paper,
            border: state == ZoneAlbumState.badge
                ? UiColors.mustard
                : UiColors.navy,
            borderWidth: kUiPx * 2,
            shadow: kUiPx * 2,
            steps: 2,
          ),
          child: ZonePostcardImage(game: game, zone: zone, locked: locked),
        ),
        const SizedBox(height: 8),
        Text(
          '${zone + 1}. durak · ${locked ? '???' : zones[zone].name}',
          key: const Key('zoneDetailName'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: UiColors.navy, fontSize: 20),
        ),
        if (!locked)
          Text(
            dz.place,
            textAlign: TextAlign.center,
            style: const TextStyle(color: UiColors.navySoft, fontSize: 10),
          ),
        const SizedBox(height: 4),
        Text(
          locked ? 'Kartpostalı açmak için bölgeye uç.' : dz.summary,
          textAlign: TextAlign.center,
          style: const TextStyle(color: UiColors.navy, fontSize: 15),
        ),
        const SizedBox(height: 8),
        _InfoLine(
          key: const Key('zoneFirstSeen'),
          icon: Icons.flight_takeoff_rounded,
          text: firstSeenText,
        ),
        _InfoLine(
          key: const Key('zoneRecord'),
          icon: Icons.star_rounded,
          text: record == null || record == 0
              ? 'Bölge rekoru: henüz yok'
              : 'Bölge rekoru: tek uçuşta $record engel',
        ),
        _InfoLine(
          key: const Key('zoneCompletion'),
          icon: Icons.military_tech_rounded,
          text: state == ZoneAlbumState.badge
              ? 'Rozet kazanıldı · %100'
              : 'Tamamlanma %${(d.zoneFraction(zone) * 100).floor()} '
                    '(${d.doneInZone(zone)}/3 hedef)',
        ),
        const SizedBox(height: 4),
        XpBar(fraction: d.zoneFraction(zone), height: 12),
        const SizedBox(height: 10),
        const Text(
          'KEŞİF HEDEFLERİ',
          style: TextStyle(
            color: UiColors.navySoft,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        for (final goal in dz.goals) _GoalRow(goal: goal, state: d),
        const SizedBox(height: 10),
        const Text(
          'İSTANBUL NOTLARI',
          style: TextStyle(
            color: UiColors.navySoft,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        if (locked)
          const Text(
            'Bölgeyi keşfedince bu kartpostalın arkasındaki notlar açılır.',
            key: Key('zoneFactsLocked'),
            style: TextStyle(color: UiColors.navySoft, fontSize: 15),
          )
        else
          Column(
            key: const Key('zoneFacts'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final f in dz.facts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${f.label}: ',
                          style: const TextStyle(color: UiColors.tile),
                        ),
                        TextSpan(text: f.text),
                      ],
                    ),
                    style: const TextStyle(color: UiColors.navy, fontSize: 15),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        PixelIcon(icon, color: UiColors.mustard, size: 24),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: UiColors.navy, fontSize: 15),
          ),
        ),
      ],
    ),
  );
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal, required this.state});

  final DiscoveryGoal goal;
  final DiscoveryState state;

  @override
  Widget build(BuildContext context) {
    final done = state.isDone(goal);
    final value = state.progressOf(goal);
    return Container(
      key: Key('goalRow_${goal.id}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pixelBox(
        color: done ? const Color(0xFFF6EBC8) : UiColors.cream,
        border: done ? UiColors.mustard : const Color(0xFFD8CDB6),
        steps: 2,
      ),
      child: Row(
        children: [
          PixelIcon(
            done ? Icons.check_rounded : Icons.flight_takeoff_rounded,
            color: done ? UiColors.navy : UiColors.navySoft,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  goal.title,
                  style: const TextStyle(color: UiColors.navy, fontSize: 15),
                ),
                if (!done && goal.target > 1) ...[
                  const SizedBox(height: 4),
                  XpBar(fraction: value / goal.target, height: 8),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                done ? 'Tamam' : '$value/${goal.target}',
                key: Key('goalValue_${goal.id}'),
                style: const TextStyle(color: UiColors.navySoft, fontSize: 10),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SimitIcon(size: 18),
                  const SizedBox(width: 2),
                  Text(
                    '+${goal.rewardSimits}',
                    style: const TextStyle(color: UiColors.navy, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
