import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/day_cycle.dart';
import '../../game/istanbul_flight_game.dart';
import '../../progression/achievements.dart';
import '../../progression/missions.dart';
import '../../progression/run_settlement.dart';
import '../../services/progress.dart';
import '../pixel.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/simit_icon.dart';
import 'menu_overlays.dart';

// Phase 2.1 arayüzü: profil, günlük görevler, başarımlar ve oyun sonu özeti.
// Mevcut pixel kimliği kullanılır (pixelBox, PixelIcon atlası, MartiPixel fontu; boyutlar 5'in katı).

/// Pixel ilerleme çubuğu: basamaklı çerçeve, düz dolgu, tam piksele yuvarlanmış genişlik.
class XpBar extends StatelessWidget {
  const XpBar({
    super.key,
    required this.fraction,
    this.height = 12,
    this.fill = UiColors.mustard,
    this.track = const Color(0xFFD8CDB6),
  });

  final double fraction;
  final double height;
  final Color fill;
  final Color track;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final inner = c.maxWidth - kUiPx * 2;
      final w =
          ((inner * fraction.clamp(0.0, 1.0)) / kUiPx).floorToDouble() * kUiPx;
      return Container(
        height: height,
        padding: const EdgeInsets.all(kUiPx),
        decoration: pixelBox(color: track, steps: 1),
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: w,
          height: height - kUiPx * 2,
          child: ColoredBox(color: fill),
        ),
      );
    },
  );
}

/// Ana menüde rekor rozetinin altındaki ilerleme şeridi: seviye, günlük görevler, başarımlar.
class MenuProgressStrip extends StatelessWidget {
  const MenuProgressStrip({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<PlayerProgress>(
    valueListenable: game.services.progress,
    builder: (context, p, _) {
      // Dar ekranda (iPhone SE, 320 pt) tek satıra sığsın: kısa etiket, kısa çubuk
      final narrow = MediaQuery.sizeOf(context).width < 360;
      final info = p.levelInfo;
      final done = p.daily?.completedCount ?? 0;
      final total = p.daily?.missions.length ?? MissionCatalog.perDay;
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          _StripChip(
            key: const Key('profileButton'),
            game: game,
            semantic: 'Profil, seviye ${info.level}',
            onTap: () => game.openModal(Overlays.profile),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('SV ${info.level}', key: const Key('menuLevel')),
                const SizedBox(width: 8),
                SizedBox(
                  width: narrow ? 36 : 56,
                  child: XpBar(fraction: info.fraction),
                ),
              ],
            ),
          ),
          _StripChip(
            key: const Key('missionsButton'),
            game: game,
            semantic: 'Günlük görevler, $done / $total tamamlandı',
            onTap: () => game.openModal(Overlays.missions),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PixelIcon(
                  Icons.wb_twilight_rounded,
                  color: UiColors.mustard,
                  size: 24,
                ),
                const SizedBox(width: 6),
                Text(narrow ? '$done/$total' : 'Görev $done/$total'),
              ],
            ),
          ),
          _StripChip(
            key: const Key('achievementsButton'),
            game: game,
            semantic: 'Başarımlar',
            onTap: () => game.openModal(Overlays.achievements),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PixelIcon(
                  Icons.star_rounded,
                  color: UiColors.mustard,
                  size: 24,
                ),
                const SizedBox(width: 6),
                Text('${p.achievements.length}/${achievementDefs.length}'),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _StripChip extends StatelessWidget {
  const _StripChip({
    super.key,
    required this.game,
    required this.child,
    required this.onTap,
    required this.semantic,
  });

  final IstanbulFlightGame game;
  final Widget child;
  final VoidCallback onTap;
  final String semantic;

  @override
  Widget build(BuildContext context) => Pressable(
    game: game,
    onTap: onTap,
    semanticLabel: semantic,
    child: ConstrainedBox(
      // dokunma hedefi ≥ 44 pt (iOS)
      constraints: const BoxConstraints(minHeight: 44),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pixelBox(
          color: UiColors.scrim,
          border: const Color(0x66FBF7EE),
          steps: 3,
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: UiColors.paper, fontSize: 15),
          child: child,
        ),
      ),
    ),
  );
}

// ======================= Profil =======================

class ProfileOverlay extends StatelessWidget {
  const ProfileOverlay({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) => ModalCard(
    game: game,
    title: 'Profil',
    child: ValueListenableBuilder<PlayerProgress>(
      valueListenable: game.services.progress,
      builder: (_, p, _) {
        final info = p.levelInfo;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _LevelBadge(level: info.level),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.isMax
                            ? 'En üst seviye'
                            : '${info.xpIntoLevel} / ${info.xpForNext} XP',
                        key: const Key('profileXp'),
                        style: const TextStyle(color: UiColors.navy),
                      ),
                      const SizedBox(height: 6),
                      XpBar(fraction: info.fraction, height: 16),
                      const SizedBox(height: 4),
                      Text(
                        info.isMax
                            ? 'Toplam ${p.xp} XP'
                            : 'Sonraki seviyeye ${info.xpRemaining} XP',
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: pixelBox(
                color: UiColors.cream,
                border: UiColors.mustard,
                steps: 2,
              ),
              child: Row(
                children: [
                  const SimitIcon(size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Simit bakiyesi',
                      style: TextStyle(color: UiColors.navy),
                    ),
                  ),
                  Text(
                    '${p.simitBalance}',
                    key: const Key('profileBalance'),
                    style: const TextStyle(color: UiColors.navy, fontSize: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<int>(
              valueListenable: game.best,
              builder: (_, best, _) => _StatTable(
                rows: [
                  ('Toplam uçuş', '${p.flights}'),
                  ('En yüksek skor', '$best'),
                  ('Toplam skor', '${p.totalScore}'),
                  ('En uzun uçuş', formatFlight(p.longestFlightMs)),
                  ('Toplanan simit', '${p.totalSimits}'),
                  ('Kıl payı geçiş', '${p.totalNearMisses}'),
                  (
                    'Keşfedilen bölge',
                    '${p.discoveredZones.length}/${zones.length}',
                  ),
                  ('Tamamlanan görev', '${p.missionsCompleted}'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _ZoneTrail(discovered: p.discoveredZones),
            const SizedBox(height: 12),
            MartiButton(
              key: const Key('openWardrobe'),
              game: game,
              label: 'Martı görünümü',
              icon: Icons.flight_takeoff_rounded,
              style: MartiButtonStyle.secondary,
              height: 52,
              onPressed: () => game.openModal(Overlays.wardrobe),
            ),
            const SizedBox(height: 8),
            MartiButton(
              key: const Key('openAchievements'),
              game: game,
              label:
                  'Başarımlar ${p.achievements.length}/${achievementDefs.length}',
              icon: Icons.star_rounded,
              style: MartiButtonStyle.secondary,
              height: 52,
              onPressed: () => game.openModal(Overlays.achievements),
            ),
          ],
        );
      },
    ),
  );
}

/// "1 dk 05 sn" / "42 sn".
String formatFlight(int ms) {
  final s = (ms / 1000).floor();
  if (s < 60) return '$s sn';
  return '${s ~/ 60} dk ${(s % 60).toString().padLeft(2, '0')} sn';
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 72, minHeight: 64),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    decoration: pixelBox(
      color: UiColors.navy,
      border: UiColors.mustard,
      borderWidth: kUiPx * 2,
      shadow: kUiPx * 2,
      steps: 2,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'SEVİYE',
          style: TextStyle(
            color: UiColors.mustard,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        Text(
          '$level',
          key: const Key('profileLevel'),
          style: const TextStyle(
            color: UiColors.paper,
            fontSize: 30,
            height: 1,
          ),
        ),
      ],
    ),
  );
}

class _StatTable extends StatelessWidget {
  const _StatTable({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final (label, value) in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: UiColors.navySoft),
                ),
              ),
              Text(value, style: const TextStyle(color: UiColors.navy)),
            ],
          ),
        ),
    ],
  );
}

/// Rota üzerinde keşfedilen bölgeler: keşfedilen dolu, diğerleri boş kare.
class _ZoneTrail extends StatelessWidget {
  const _ZoneTrail({required this.discovered});

  final Set<int> discovered;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 4,
    children: [
      for (var i = 0; i < zones.length; i++)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: pixelBox(
            color: discovered.contains(i)
                ? UiColors.navy
                : const Color(0xFFE6DCC6),
            steps: 1,
          ),
          child: Text(
            discovered.contains(i) ? zones[i].name : '???',
            style: TextStyle(
              fontSize: 10,
              color: discovered.contains(i)
                  ? UiColors.paper
                  : UiColors.navySoft,
            ),
          ),
        ),
    ],
  );
}

// ======================= Günlük görevler =======================

class MissionsOverlay extends StatefulWidget {
  const MissionsOverlay({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  State<MissionsOverlay> createState() => _MissionsOverlayState();
}

class _MissionsOverlayState extends State<MissionsOverlay> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    widget.game.services.progress.refreshDay();
    // Kalan süre dakikada bir güncellenir; gece yarısı geçerse görevler yenilenir
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      widget.game.services.progress.refreshDay();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.game.services.progress;
    return ModalCard(
      game: widget.game,
      title: 'Günlük görevler',
      child: ValueListenableBuilder<PlayerProgress>(
        valueListenable: progress,
        builder: (_, p, _) {
          final missions = p.daily?.missions ?? const <DailyMission>[];
          final left = untilNextDay(progress.now());
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Uçtukça kendiliğinden ilerler. Ödül, görev biter bitmez verilir.',
                textAlign: TextAlign.center,
                style: TextStyle(color: UiColors.navySoft, fontSize: 10),
              ),
              const SizedBox(height: 10),
              for (final (i, m) in missions.indexed) ...[
                _MissionTile(mission: m, index: i),
                const SizedBox(height: 8),
              ],
              Text(
                'Yeni görevlere: ${_formatLeft(left)}',
                key: const Key('missionsRefresh'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: UiColors.navySoft),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _formatLeft(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  return h > 0 ? '$h sa $m dk' : '${m < 1 ? 1 : m} dk';
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.mission, required this.index});

  final DailyMission mission;
  final int index;

  @override
  Widget build(BuildContext context) {
    final m = mission;
    final zoneMission = m.kind == MissionKind.reachZone;
    return Container(
      key: Key('mission$index'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: pixelBox(
        color: m.completed ? const Color(0xFFF6EBC8) : UiColors.cream,
        border: m.completed ? UiColors.mustard : const Color(0xFFD8CDB6),
        steps: 2,
      ),
      child: Row(
        children: [
          PixelIcon(
            m.completed ? Icons.star_rounded : Icons.wb_twilight_rounded,
            color: m.completed ? UiColors.mustard : UiColors.navySoft,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.title, style: const TextStyle(color: UiColors.navy)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: XpBar(fraction: m.fraction)),
                    const SizedBox(width: 8),
                    Text(
                      m.completed
                          ? 'TAMAM'
                          : zoneMission
                          ? '–'
                          : '${m.progress}/${m.target}',
                      key: Key('missionProgress$index'),
                      style: TextStyle(
                        fontSize: 10,
                        color: m.completed
                            ? UiColors.action
                            : UiColors.navySoft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '+${m.rewardXp} XP · +${m.rewardSimits} simit',
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

// ======================= Başarımlar =======================

class AchievementsOverlay extends StatelessWidget {
  const AchievementsOverlay({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) => ModalCard(
    game: game,
    title: 'Başarımlar',
    child: ValueListenableBuilder<PlayerProgress>(
      valueListenable: game.services.progress,
      builder: (_, p, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${p.achievements.length} / ${achievementDefs.length} rozet',
            key: const Key('achievementCount'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: UiColors.navySoft),
          ),
          const SizedBox(height: 8),
          for (final a in achievementDefs) ...[
            _AchievementTile(def: a, progress: p),
            const SizedBox(height: 6),
          ],
        ],
      ),
    ),
  );
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.def, required this.progress});

  final AchievementDef def;
  final PlayerProgress progress;

  @override
  Widget build(BuildContext context) {
    final at = progress.achievements[def.id];
    final open = at != null;
    return Container(
      key: Key('achievement_${def.id}'),
      padding: const EdgeInsets.all(8),
      decoration: pixelBox(
        color: open ? const Color(0xFFF6EBC8) : const Color(0xFFEDE4D2),
        border: open ? UiColors.mustard : const Color(0xFFD8CDB6),
        steps: 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Badge(open: open),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  def.title,
                  style: TextStyle(
                    color: open ? UiColors.navy : UiColors.navySoft,
                  ),
                ),
                Text(
                  def.description,
                  style: const TextStyle(
                    color: UiColors.navySoft,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                if (open)
                  Text(
                    'Kazanıldı: ${formatDate(at)} · +${def.rewardXp} XP · +${def.rewardSimits} simit',
                    style: const TextStyle(
                      color: UiColors.action,
                      fontSize: 10,
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: XpBar(
                          fraction: def.fractionIn(progress),
                          height: 10,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '%${(def.fractionIn(progress) * 100).floor()}',
                        style: const TextStyle(
                          color: UiColors.navySoft,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    def.metric == AchievementMetric.maxZone
                        ? 'Ödül: +${def.rewardXp} XP · +${def.rewardSimits} simit'
                        : '${def.progressIn(progress)}/${def.target} · Ödül: +${def.rewardXp} XP · +${def.rewardSimits} simit',
                    style: const TextStyle(
                      color: UiColors.navySoft,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String formatDate(DateTime t) {
  final l = t.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(l.day)}.${two(l.month)}.${l.year}';
}

/// Rozet: açıkken hardal zeminde lacivert yıldız, kilitliyken soluk.
class _Badge extends StatelessWidget {
  const _Badge({required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: pixelBox(
      color: open ? UiColors.mustard : const Color(0xFFD8CDB6),
      border: open ? UiColors.navy : const Color(0xFFBFB39B),
      borderWidth: kUiPx,
      steps: 2,
    ),
    child: PixelIcon(
      Icons.star_rounded,
      color: open ? UiColors.navy : const Color(0xFFA89C86),
      size: 24,
    ),
  );
}

// ======================= Oyun sonu özeti =======================

/// Kartpostalın altında, paylaşılan görselin dışında: kazanılan XP, seviye, simit, görev ve
/// başarımlar. Tek bir sakin panel; ayrı açılır pencere yok.
class RunSummaryPanel extends StatelessWidget {
  const RunSummaryPanel({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<RunSummary?>(
    valueListenable: game.services.progress.lastRun,
    builder: (_, s, _) {
      if (s == null) return const SizedBox.shrink();
      final info = game.services.progress.value.levelInfo;
      const small = TextStyle(color: UiColors.paper, fontSize: 15);
      const accent = TextStyle(color: UiColors.mustard, fontSize: 15);
      return Container(
        key: const Key('runSummary'),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: pixelBox(
          color: UiColors.scrim,
          border: const Color(0x66FBF7EE),
          steps: 3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  '+${s.xpTotal} XP',
                  key: const Key('runXp'),
                  style: const TextStyle(color: UiColors.mustard, fontSize: 20),
                ),
                const SizedBox(width: 10),
                // Küçük ekranda (320 pt) alt satıra iner; taşmaz
                Expanded(
                  child: Text(
                    s.leveledUp
                        ? 'Seviye ${s.levelBefore} → ${s.levelAfter}!'
                        : 'Seviye ${info.level}',
                    key: const Key('runLevel'),
                    style: s.leveledUp ? accent : small,
                  ),
                ),
                if (s.simitsTotal > 0) ...[
                  const SimitIcon(size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '+${s.simitsTotal}',
                    key: const Key('runSimitsEarned'),
                    style: small,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            XpBar(fraction: info.fraction, height: 10),
            for (final z in s.newZones)
              _line(
                Icons.flight_takeoff_rounded,
                'Yeni bölge: ${zones[z].name}',
              ),
            for (final m in s.completedMissions)
              _line(Icons.wb_twilight_rounded, 'Görev tamam: ${m.title}'),
            for (final a in s.unlockedAchievements)
              _line(Icons.star_rounded, 'Başarım: ${a.title}'),
          ],
        ),
      );
    },
  );

  Widget _line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        PixelIcon(icon, color: UiColors.mustard, size: 24),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: UiColors.paper, fontSize: 15),
          ),
        ),
      ],
    ),
  );
}
