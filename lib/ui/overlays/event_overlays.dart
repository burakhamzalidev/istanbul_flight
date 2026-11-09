import 'dart:async';

import 'package:flutter/material.dart';

import '../../challenge/daily_challenge.dart';
import '../../challenge/daily_state.dart';
import '../../events/event_calendar.dart';
import '../../events/event_definition.dart';
import '../../events/event_state.dart';
import '../../events/weekly_missions.dart';
import '../../game/day_cycle.dart';
import '../../game/istanbul_flight_game.dart';
import '../../progression/cosmetics.dart';
import '../../services/game_center/game_center.dart';
import '../../services/game_center/game_center_controller.dart';
import '../../services/progress.dart';
import '../../game/visual/simit_animator.dart';
import '../pixel.dart';
import '../simit_frame_view.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/simit_icon.dart';
import 'daily_overlays.dart';
import 'leaderboard_overlay.dart';
import 'menu_overlays.dart';

// Phase 2.7: Etkinlik Merkezi (docs/20 §10–§12). Ana menüde tek giriş noktası; içinde üç sekme:
// İstanbul Kupası, Etkinlikler (özel etkinlik, yaklaşan ve tamamlanan), Sezon. Sıralama yalnızca Game
// Center'dan gelen gerçek veriyle gösterilir; bağlantı yoksa uydurma sıra yok.

/// Etkinlik türünün renkleri (ayrı paletler; mevcut arayüz renkleriyle uyumlu, koyu yazıyla okunur).
({Color bg, Color border, Color ink, IconData icon}) eventStyle(EventType t) =>
    switch (t) {
      EventType.marathon => (
        bg: const Color(0xFFD6E6F2),
        border: const Color(0xFF2F6FA8),
        ink: const Color(0xFF1F3A5F),
        icon: Icons.flag_rounded,
      ),
      EventType.simitFestival => (
        bg: const Color(0xFFF6E2C4),
        border: const Color(0xFFC8803A),
        ink: const Color(0xFF6E3A12),
        icon: Icons.bakery_dining_rounded,
      ),
      EventType.nightFlight => (
        bg: const Color(0xFFD7DAEE),
        border: const Color(0xFF3D4675),
        ink: const Color(0xFF1C2142),
        icon: Icons.nightlight_round,
      ),
      EventType.windMaster => (
        bg: const Color(0xFFD2EEE6),
        border: const Color(0xFF2F8F7A),
        ink: const Color(0xFF1B4F44),
        icon: Icons.air_rounded,
      ),
    };

/// "3 gün 4 sa", "5 sa 12 dk", "12 dk".
String formatLongCountdown(Duration d) {
  if (d.inDays > 0) return '${d.inDays} gün ${d.inHours % 24} sa';
  return formatCountdown(d);
}

String eventRewardText(EventRewardPolicy p, String key) {
  if (key == EventRewardPolicy.participationKey) return 'İlk uçuş';
  for (final m in p.milestones) {
    if (key == EventRewardPolicy.milestoneKey(m.score)) {
      return 'Bir uçuşta ${m.score} puan';
    }
  }
  return key;
}

String _zonesText(ZoneSelection z) {
  final names = [for (final s in z.stages) zones[s.zone].name];
  return names.length == 1 ? names.first : '${names.first} – ${names.last}';
}

String _clockText(EventClockStatus s) => switch (s) {
  EventClockStatus.ok => '',
  EventClockStatus.rolledBack =>
    'Cihazın tarihi daha önce oynadığın bir haftanın gerisinde. Tarih ve saat otomatik ayarlanınca '
        'dereceli uçuş yeniden açılır; şimdilik uçuşlar ödül ve sıralamaya sayılmaz.',
  EventClockStatus.mismatch =>
    'Cihazın tarihi Game Center’ın haftasından farklı. Ayarlar > Genel > Tarih ve Saat’ten '
        '“Otomatik Ayarla”yı aç; şimdilik uçuşlar ödül ve sıralamaya sayılmaz.',
};

/// Ana menü girişi: kupa ikonu, "Etkinlikler" ve sezon seviyesi.
class EventsMenuButton extends StatelessWidget {
  const EventsMenuButton({super.key, required this.game, this.compact});

  final IstanbulFlightGame game;
  final bool? compact;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([game.services.progress, game.services.ux]),
    builder: (context, _) {
      final p = game.services.progress.value;
      final season = game.services.events.season();
      // Phase 2.8: açık bir etkinlik henüz Etkinlik Merkezi'nde görülmediyse küçük "yeni" işareti
      final seen = game.services.ux.value.seenEvents;
      final newEvent = [
        ?game.services.events.activeCup(),
        ?game.services.events.activeSpecial(),
      ].any((s) => !seen.contains(s.eventId));
      final sp = season == null ? null : p.events.season(season.seasonId);
      final level = season == null || sp == null
          ? null
          : season.levelFor(sp.points);
      final narrow = compact ?? MediaQuery.sizeOf(context).width < 360;
      return Pressable(
        key: const Key('eventsButton'),
        game: game,
        semanticLabel:
            '${level == null ? 'Etkinlikler' : 'Etkinlikler, sezon seviyesi $level / ${season!.levels.length}'}'
            '${newEvent ? ', yeni etkinlik var' : ''}',
        onTap: () => game.openModal(Overlays.events),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: pixelBox(
                  color: UiColors.scrim,
                  border: UiColors.mustard,
                  steps: 3,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sıralama düğmesinin kupa ikonundan ayrı: etkinlik / kutlama
                    const PixelIcon(
                      Icons.celebration_rounded,
                      color: UiColors.mustard,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        narrow ? 'Kupa' : 'Etkinlikler',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: UiColors.paper,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    // sezon seviyesi yalnızca ilk ödülden sonra ("S0" anlaşılmıyordu)
                    if (level != null && level > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '$level/${season!.levels.length}',
                        key: const Key('eventsMenuLevel'),
                        style: const TextStyle(
                          color: UiColors.mustard,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (newEvent)
                const Positioned(
                  right: -2,
                  top: -2,
                  child: NewDot(key: Key('eventsNewDot')),
                ),
            ],
          ),
        ),
      );
    },
  );
}

enum _Tab { cup, events, season }

/// Etkinlik Merkezi.
class EventsOverlay extends StatefulWidget {
  const EventsOverlay({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  State<EventsOverlay> createState() => _EventsOverlayState();
}

class _EventsOverlayState extends State<EventsOverlay> {
  _Tab _tab = _Tab.cup;
  Timer? _tick;

  IstanbulFlightGame get game => widget.game;

  @override
  void initState() {
    super.initState();
    // hafta döndüyse görevler yenilenir (oluşturma bittikten sonra: dinleyiciler build sırasında uyarılmasın)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      game.services.progress.refreshWeek();
      // Phase 2.8: açık etkinlikler görüldü (menüdeki "yeni" işareti söner)
      game.services.ux.markEventsSeen([
        for (final s in [
          ?game.services.events.activeCup(),
          ?game.services.events.activeSpecial(),
        ])
          s.eventId,
      ]);
    });
    unawaited(game.services.gameCenter.refreshCupOccurrence());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Widget _tabButton(_Tab t, String label) => Expanded(
    child: BoardToggle(
      key: Key('eventsTab_${t.name}'),
      game: game,
      label: label,
      selected: _tab == t,
      onTap: () => setState(() => _tab = t),
    ),
  );

  @override
  Widget build(BuildContext context) => ModalCard(
    game: game,
    title: 'Etkinlikler',
    child: ValueListenableBuilder<PlayerProgress>(
      valueListenable: game.services.progress,
      builder: (context, p, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _tabButton(_Tab.cup, 'Kupa'),
              const SizedBox(width: 6),
              _tabButton(_Tab.events, 'Etkinlik'),
              const SizedBox(width: 6),
              _tabButton(_Tab.season, 'Sezon'),
            ],
          ),
          const SizedBox(height: 10),
          switch (_tab) {
            _Tab.cup => _CupTab(game: game, progress: p),
            _Tab.events => _EventsTab(game: game, progress: p),
            _Tab.season => _SeasonTab(game: game, progress: p),
          },
        ],
      ),
    ),
  );
}

// ============================ Ortak parçalar ============================

class _Note extends StatelessWidget {
  const _Note({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: pixelBox(
      color: UiColors.cream,
      border: UiColors.action,
      steps: 2,
    ),
    child: Text(
      text,
      style: const TextStyle(color: UiColors.navy, fontSize: 11),
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.valueKey});

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: pixelBox(
      color: UiColors.cream,
      border: const Color(0xFFD8CDB6),
      steps: 2,
    ),
    child: Column(
      children: [
        Text(
          value,
          key: valueKey,
          style: const TextStyle(color: UiColors.navy, fontSize: 25),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: UiColors.navySoft, fontSize: 11),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      trUpper(text),
      style: const TextStyle(color: UiColors.navy, letterSpacing: 1),
    ),
  );
}

/// Etkinlik başlık kartı: türün paleti ve ikonu, başlık, süre.
class _EventHeader extends StatelessWidget {
  const _EventHeader({
    super.key,
    required this.slot,
    required this.subtitle,
    required this.timeText,
  });

  final EventSlot slot;
  final String subtitle;
  final String timeText;

  @override
  Widget build(BuildContext context) {
    final st = eventStyle(slot.type);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: pixelBox(color: st.bg, border: st.border, steps: 2),
      child: Row(
        children: [
          slot.type == EventType.simitFestival
              ? const SimitIcon(size: 36)
              : PixelIcon(st.icon, color: st.border, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.type.title,
                  key: Key('eventTitle_${slot.eventId}'),
                  style: TextStyle(color: st.ink, fontSize: 20),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: st.ink, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  timeText,
                  key: Key('eventTime_${slot.eventId}'),
                  style: TextStyle(color: st.ink, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Etkinliğin tek seferlik ödülleri; alınanlar işaretli.
class _EventRewards extends StatelessWidget {
  const _EventRewards({required this.slot, required this.claimed});

  final EventSlot slot;
  final Set<String> claimed;

  @override
  Widget build(BuildContext context) {
    final p = slot.rewards;
    Widget row(String key, String amount, {bool simit = false}) {
      final done = claimed.contains(key);
      return Padding(
        key: Key('eventReward_$key'),
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: done
                  ? const PixelIcon(
                      Icons.check_rounded,
                      color: Color(0xFF3E8E5A),
                      size: 24,
                    )
                  : null,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                eventRewardText(p, key),
                style: TextStyle(
                  color: done ? UiColors.navySoft : UiColors.navy,
                  fontSize: 15,
                ),
              ),
            ),
            Text(
              amount,
              style: const TextStyle(color: UiColors.action, fontSize: 15),
            ),
            if (simit) ...[const SizedBox(width: 4), const SimitIcon(size: 16)],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Ödüller'),
        row(EventRewardPolicy.participationKey, '+${p.participationPoints} SP'),
        for (final m in p.milestones)
          row(
            EventRewardPolicy.milestoneKey(m.score),
            '+${m.seasonPoints} SP · +${m.simits}',
            simit: true,
          ),
        const SizedBox(height: 2),
        const Text(
          'SP: sezon puanı. Ödüller sıralamadaki yere bağlı değildir; her etkinlikte bir kez verilir.',
          style: TextStyle(color: UiColors.navySoft, fontSize: 11),
        ),
      ],
    );
  }
}

/// Bir etkinliğin başlatılabilir kartı (kupa ve özel etkinlik aynı düzende).
class _ActiveEvent extends StatelessWidget {
  const _ActiveEvent({
    required this.game,
    required this.progress,
    required this.slot,
  });

  final IstanbulFlightGame game;
  final PlayerProgress progress;
  final EventSlot slot;

  @override
  Widget build(BuildContext context) {
    final svc = game.services.events;
    final rec = progress.events[slot.eventId];
    final clock = svc.clockStatus(progress);
    final cup = slot.kind == EventKind.weeklyCup;
    final zonesSel = EventPresets.zonesFor(slot.type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _EventHeader(
          key: Key('activeEvent_${slot.eventId}'),
          slot: slot,
          subtitle: cup
              ? 'İstanbul Kupası · herkes aynı parkurda'
              : 'Hafta sonu etkinliği · herkes aynı parkurda',
          timeText: 'Bitiş: ${formatLongCountdown(svc.timeLeft(slot))} sonra',
        ),
        const SizedBox(height: 6),
        Text(
          slot.type.description,
          style: const TextStyle(color: UiColors.navy, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          'Parkur: ${_zonesText(zonesSel)} · Skor: ${slot.scoring.label.toLowerCase()}',
          key: Key('eventCourse_${slot.eventId}'),
          style: const TextStyle(color: UiColors.navySoft, fontSize: 11),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Fact(
                  label: cup ? 'Haftalık en iyi' : 'En iyi',
                  value: '${rec?.bestScore ?? 0}',
                  valueKey: Key('eventBest_${slot.eventId}'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _Fact(
                  label: 'Uçuş',
                  value: '${rec?.flights ?? 0}',
                  valueKey: Key('eventFlights_${slot.eventId}'),
                ),
              ),
            ],
          ),
        ),
        if (clock != EventClockStatus.ok) ...[
          const SizedBox(height: 8),
          _Note(key: const Key('eventClockWarning'), text: _clockText(clock)),
        ],
        const SizedBox(height: 10),
        _EventRewards(slot: slot, claimed: rec?.claimed ?? const {}),
        if (cup) ...[
          const SizedBox(height: 10),
          _CupBoard(game: game, record: rec),
        ],
        const SizedBox(height: 12),
        MartiButton(
          key: Key('eventStart_${slot.eventId}'),
          game: game,
          label: 'Uçuşa başla',
          icon: Icons.flight_takeoff_rounded,
          width: double.infinity,
          height: 60,
          onPressed: () => game.startEvent(svc.definition(slot)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Deneme sınırı yok: haftanın en iyi tek uçuşu sayılır.',
          textAlign: TextAlign.center,
          style: TextStyle(color: UiColors.navySoft, fontSize: 11),
        ),
      ],
    );
  }
}

// ============================ Kupa ============================

class _CupTab extends StatelessWidget {
  const _CupTab({required this.game, required this.progress});

  final IstanbulFlightGame game;
  final PlayerProgress progress;

  @override
  Widget build(BuildContext context) {
    final svc = game.services.events;
    final cup = svc.activeCup();
    if (cup == null) {
      final next = EventCalendar.cupFor(EventCalendar.weekIndex(svc.now()) + 1);
      return _Note(
        key: const Key('cupNone'),
        text: next == null
            ? 'Şu anda açık bir kupa yok.'
            : 'İlk İstanbul Kupası ${formatLongCountdown(svc.timeToStart(next))} sonra başlıyor.',
      );
    }
    return _ActiveEvent(game: game, progress: progress, slot: cup);
  }
}

/// Kupa sıralaması: Game Center bağlıysa dünya / arkadaşlar ve kendi derecen; değilse yalnızca durum.
class _CupBoard extends StatefulWidget {
  const _CupBoard({required this.game, required this.record});

  final IstanbulFlightGame game;
  final EventRecord? record;

  @override
  State<_CupBoard> createState() => _CupBoardState();
}

class _CupBoardState extends State<_CupBoard> {
  GcScope _scope = GcScope.global;
  Future<GcBoardPage>? _page;
  bool _wasSignedIn = false;

  GameCenterController get gc => widget.game.services.gameCenter;

  @override
  void initState() {
    super.initState();
    gc.addListener(_onGc);
    _onGc();
  }

  @override
  void dispose() {
    gc.removeListener(_onGc);
    super.dispose();
  }

  void _onGc() {
    final signedIn = gc.value.signedIn;
    if (signedIn && !_wasSignedIn) _reload();
    _wasSignedIn = signedIn;
  }

  void _reload() {
    final f = gc.loadBoard(GcBoard.weeklyCup, _scope);
    f.ignore();
    if (!mounted) return;
    setState(() {
      _page = f;
    });
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<GameCenterState>(
    valueListenable: gc,
    builder: (context, s, _) {
      final status = widget.record?.gcStatus ?? DailyGcStatus.none;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle('Haftalık sıralama'),
          if (!s.signedIn)
            Text(
              s.connection == GcConnection.unsupported
                  ? 'Kupa sıralaması Game Center ile çalışır (iPhone ve iPad). Haftalık en iyin bu cihazda saklanır.'
                  : 'Game Center’a bağlanınca dünya ve arkadaşlarınla aynı parkurda yarışırsın. '
                        'Bağlantısız da oynayabilirsin; skorun bu cihazda kalır.',
              key: const Key('cupBoardOffline'),
              style: const TextStyle(color: UiColors.navySoft, fontSize: 11),
            )
          else ...[
            if (status != DailyGcStatus.none)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  cupGcStatusText(status),
                  key: const Key('cupGcStatus'),
                  style: const TextStyle(
                    color: UiColors.navySoft,
                    fontSize: 11,
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: BoardToggle(
                    key: const Key('cupScopeGlobal'),
                    game: widget.game,
                    label: 'Dünya',
                    selected: _scope == GcScope.global,
                    onTap: () {
                      _scope = GcScope.global;
                      _reload();
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: BoardToggle(
                    key: const Key('cupScopeFriends'),
                    game: widget.game,
                    label: 'Arkadaşlar',
                    selected: _scope == GcScope.friends,
                    onTap: () {
                      _scope = GcScope.friends;
                      _reload();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FutureBuilder<GcBoardPage>(
              future: _page,
              builder: (context, snap) => BoardList(
                game: widget.game,
                snap: snap,
                board: GcBoard.weeklyCup,
                scope: _scope,
                onRetry: _reload,
              ),
            ),
          ],
        ],
      );
    },
  );
}

String cupGcStatusText(DailyGcStatus s) => switch (s) {
  DailyGcStatus.none => '',
  DailyGcStatus.pending => 'Kupa skorun Game Center’a gönderilmeyi bekliyor; bağlantı gelince gönderilir.',
  DailyGcStatus.submitted => 'Kupa skorun Game Center’a gönderildi.',
  DailyGcStatus.expired => 'Bu skor haftanın sıralaması kapandıktan sonra gönderilebildiği için sıralamaya girmedi.',
  DailyGcStatus.notEligible => 'Bu uçuş sıralamaya uygun değildi.',
};

// ============================ Etkinlikler ============================

class _EventsTab extends StatelessWidget {
  const _EventsTab({required this.game, required this.progress});

  final IstanbulFlightGame game;
  final PlayerProgress progress;

  @override
  Widget build(BuildContext context) {
    final svc = game.services.events;
    final now = svc.now();
    final special = svc.activeSpecial();
    final all = EventCalendar.slotsAround(now, past: 3, future: 2);
    final upcoming = all.where((s) => s.isUpcomingAt(now)).take(4).toList();
    final done = all
        .where((s) => s.isOverAt(now) && progress.events[s.eventId] != null)
        .toList()
        .reversed
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (special != null)
          _ActiveEvent(game: game, progress: progress, slot: special)
        else
          const _Note(
            key: Key('specialNone'),
            text: 'Özel etkinlikler hafta sonu açılır (cuma 00:00 – pazartesi 00:00 UTC). Kupa her hafta açık.',
          ),
        const SizedBox(height: 12),
        const _SectionTitle('Yaklaşan'),
        for (final s in upcoming)
          _SlotRow(
            key: Key('upcoming_${s.eventId}'),
            slot: s,
            trailing: '${formatLongCountdown(svc.timeToStart(s))} sonra',
          ),
        if (done.isNotEmpty) ...[
          const SizedBox(height: 10),
          const _SectionTitle('Tamamlanan'),
          for (final s in done)
            _SlotRow(
              key: Key('done_${s.eventId}'),
              slot: s,
              trailing: 'En iyi ${progress.events[s.eventId]!.bestScore}',
            ),
        ],
        const SizedBox(height: 6),
        const Text(
          'Takvim uygulamayla gelir ve UTC haftasına göre herkes için aynıdır.',
          style: TextStyle(color: UiColors.navySoft, fontSize: 11),
        ),
      ],
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({super.key, required this.slot, required this.trailing});

  final EventSlot slot;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final st = eventStyle(slot.type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pixelBox(color: st.bg, border: st.border, steps: 1),
        // küçük ekranda süre ("4 gün 12 sa sonra") başlığı itmesin: satırın %40'ıyla sınırlı, gerekirse iki satır
        child: LayoutBuilder(
          builder: (context, c) => Row(
            children: [
              slot.type == EventType.simitFestival
                  ? const SimitIcon(size: 20)
                  : PixelIcon(st.icon, color: st.border, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  slot.kind == EventKind.weeklyCup
                      ? 'Kupa · ${slot.type.title}'
                      : slot.type.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: st.ink, fontSize: 15),
                ),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: c.maxWidth * 0.4),
                child: Text(
                  trailing,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: st.ink, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================ Sezon ============================

class _SeasonTab extends StatelessWidget {
  const _SeasonTab({required this.game, required this.progress});

  final IstanbulFlightGame game;
  final PlayerProgress progress;

  @override
  Widget build(BuildContext context) {
    final svc = game.services.events;
    final season = svc.season();
    if (season == null) {
      return const _Note(
        key: Key('seasonNone'),
        text: 'İlk sezon, ilk İstanbul Kupası ile başlar.',
      );
    }
    final sp = progress.events.season(season.seasonId);
    final level = season.levelFor(sp.points);
    final next = level < season.levels.length ? season.levels[level] : null;
    final prevPts = level == 0 ? 0 : season.levels[level - 1].points;
    final frac = next == null
        ? 1.0
        : ((sp.points - prevPts) / (next.points - prevPts)).clamp(0.0, 1.0);
    final left = season.endAtUtc.difference(svc.now().toUtc());
    final weekly = progress.events.weekly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: pixelBox(
            color: const Color(0xFFF6EBC8),
            border: UiColors.mustard,
            steps: 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const PixelIcon(
                    Icons.emoji_events_rounded,
                    color: UiColors.action,
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sezon ${season.number} · Seviye $level/${season.levels.length}',
                      key: const Key('seasonLevel'),
                      style: const TextStyle(
                        color: UiColors.navy,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                height: 10,
                decoration: pixelBox(
                  color: UiColors.cream,
                  border: UiColors.navy,
                  steps: 1,
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: frac,
                  child: Container(color: UiColors.mustard),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                next == null
                    ? '${sp.points} SP · bütün ödüller açıldı'
                    : '${sp.points} / ${next.points} SP · sonraki ödül: ${_levelText(next)}',
                key: const Key('seasonPoints'),
                style: const TextStyle(color: UiColors.navySoft, fontSize: 11),
              ),
              Text(
                'Sezonun bitişi: ${formatLongCountdown(left.isNegative ? Duration.zero : left)} sonra',
                key: const Key('seasonTime'),
                style: const TextStyle(color: UiColors.navySoft, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const _SectionTitle('Ödüller'),
        for (final lv in season.levels)
          _SeasonRewardRow(
            game: game,
            level: lv,
            reached: sp.claimedLevels.contains(lv.level),
          ),
        const SizedBox(height: 2),
        const Text(
          'Ödüller ücretsizdir ve kalıcıdır; sezon bitince geri alınmaz. Sezon puanı XP’den ayrıdır.',
          style: TextStyle(color: UiColors.navySoft, fontSize: 11),
        ),
        if (progress.events.frames.contains('kupa')) ...[
          const SizedBox(height: 10),
          _FrameToggle(game: game, progress: progress),
        ],
        const SizedBox(height: 12),
        const _SectionTitle('Haftalık görevler'),
        if (weekly != null)
          for (final m in weekly.missions) _WeeklyRow(mission: m),
        const SizedBox(height: 2),
        Text(
          'Her görev bir kez: +${WeeklyMissionCatalog.seasonPoints} SP ve +${WeeklyMissionCatalog.simits} simit. '
          'Görevler pazartesi 00:00 UTC’de yenilenir.',
          style: const TextStyle(color: UiColors.navySoft, fontSize: 11),
        ),
      ],
    );
  }
}

String _levelText(SeasonLevel l) => switch (l.kind) {
  SeasonRewardKind.simits => '${l.simits} simit',
  SeasonRewardKind.badge => 'İstanbul Kupası rozeti',
  SeasonRewardKind.postcardFrame => 'Kupa kartpostal çerçevesi',
  SeasonRewardKind.cosmetic =>
    cosmeticById(l.itemId ?? '')?.name ?? 'Özel görünüm',
};

class _SeasonRewardRow extends StatelessWidget {
  const _SeasonRewardRow({
    required this.game,
    required this.level,
    required this.reached,
  });

  final IstanbulFlightGame game;
  final SeasonLevel level;
  final bool reached;

  Widget _icon() => switch (level.kind) {
    SeasonRewardKind.simits => const SimitIcon(size: 28),
    SeasonRewardKind.badge => const CupBadge(size: 28),
    SeasonRewardKind.postcardFrame => const PixelIcon(
      Icons.photo_rounded,
      color: Color(0xFFC98F26),
      size: 28,
    ),
    SeasonRewardKind.cosmetic => SizedBox(
      width: 34,
      height: 30,
      child: SimitFrameView(
        image: game.art.sheetFor(level.itemId ?? ''),
        frame: SimitAnimator.glide,
      ),
    ),
  };

  @override
  Widget build(BuildContext context) => Padding(
    key: Key('seasonReward_${level.level}'),
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pixelBox(
        color: reached ? const Color(0xFFF6EBC8) : UiColors.cream,
        border: reached ? UiColors.mustard : const Color(0xFFD8CDB6),
        steps: 1,
      ),
      child: Row(
        children: [
          SizedBox(width: 36, child: Center(child: _icon())),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _levelText(level),
                  style: const TextStyle(color: UiColors.navy, fontSize: 15),
                ),
                Text(
                  'Seviye ${level.level} · ${level.points} SP',
                  style: const TextStyle(
                    color: UiColors.navySoft,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (reached)
            const PixelIcon(
              Icons.check_rounded,
              color: Color(0xFF3E8E5A),
              size: 24,
            ),
        ],
      ),
    ),
  );
}

class _FrameToggle extends StatelessWidget {
  const _FrameToggle({required this.game, required this.progress});

  final IstanbulFlightGame game;
  final PlayerProgress progress;

  @override
  Widget build(BuildContext context) {
    final on = progress.events.effectiveFrame == 'kupa';
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Kartpostalda kupa çerçevesi',
            style: TextStyle(color: UiColors.navy, fontSize: 15),
          ),
        ),
        Switch(
          key: const Key('kupaFrameSwitch'),
          value: on,
          activeThumbColor: UiColors.mustard,
          onChanged: (v) =>
              game.services.progress.selectFrame(v ? 'kupa' : null),
        ),
      ],
    );
  }
}

class _WeeklyRow extends StatelessWidget {
  const _WeeklyRow({required this.mission});

  final WeeklyMission mission;

  @override
  Widget build(BuildContext context) => Padding(
    key: Key('weekly_${mission.id}'),
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                mission.title,
                style: TextStyle(
                  color: mission.completed ? UiColors.navySoft : UiColors.navy,
                  fontSize: 15,
                ),
              ),
            ),
            Text(
              mission.completed
                  ? 'Tamam'
                  : '${mission.progress}/${mission.target}',
              style: const TextStyle(color: UiColors.action, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          height: 6,
          color: const Color(0xFFE6DCC8),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: mission.fraction,
            child: Container(color: const Color(0xFF3E8E5A)),
          ),
        ),
      ],
    ),
  );
}

/// İstanbul Kupası rozeti: piksel kupa (özgün çizim, oyunun UI piksel ölçeğinde).
class CupBadge extends StatelessWidget {
  const CupBadge({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _CupPainter()),
  );
}

class _CupPainter extends CustomPainter {
  // 12×12; G altın, D koyu altın, L parlak, R kırmızı kurdele, B kaide
  static const _rows = [
    '..GGGGGGGG..',
    'DGLLGGGGGGGD',
    'D.GLGGGGGG.D',
    'D.GLGGGGGG.D',
    '.DGGGGGGGGD.',
    '..DGGGGGGD..',
    '...DGGGGD...',
    '....DGGD....',
    '.....GG.....',
    '...RRRRRR...',
    '..BBBBBBBB..',
    '..DDDDDDDD..',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 12;
    final p = Paint()..isAntiAlias = false;
    const colors = {
      'G': Color(0xFFF2C23A),
      'D': Color(0xFFB07B18),
      'L': Color(0xFFFFF3B0),
      'R': Color(0xFFC42F36),
      'B': Color(0xFF6E4426),
    };
    for (var y = 0; y < _rows.length; y++) {
      for (var x = 0; x < _rows[y].length; x++) {
        final c = colors[_rows[y][x]];
        if (c == null) continue;
        p.color = c;
        canvas.drawRect(Rect.fromLTWH(x * k, y * k, k, k), p);
      }
    }
  }

  @override
  bool shouldRepaint(_CupPainter old) => false;
}

// ============================ Uçuş öncesi ve sonrası ============================

/// "Uçmak için dokun" şeridi: etkinlik adı ve dereceli / antrenman bilgisi.
class EventReadyBanner extends StatelessWidget {
  const EventReadyBanner({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<RunMode>(
    valueListenable: game.runMode,
    builder: (context, mode, _) {
      final def = game.eventDefinition.value;
      if (!mode.isEvent || def == null) return const SizedBox.shrink();
      final slot = EventCalendar.slotById(def.eventId);
      final ranked =
          slot != null &&
          game.services.events.canRank(game.services.progress.value, slot);
      final st = eventStyle(def.type);
      return Container(
        key: const Key('eventReadyBanner'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: pixelBox(
          color: UiColors.scrim,
          border: st.border,
          steps: 3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              trUpper(
                def.kind == EventKind.weeklyCup
                    ? 'İstanbul Kupası'
                    : def.type.title,
              ),
              style: const TextStyle(
                color: UiColors.mustard,
                fontSize: 15,
                letterSpacing: 2,
              ),
            ),
            Text(
              ranked
                  ? (def.kind == EventKind.weeklyCup
                        ? def.type.title
                        : 'En iyi tek uçuş sayılır')
                  : 'Antrenman · ödül ve sıralamaya sayılmaz',
              key: const Key('eventReadyText'),
              style: const TextStyle(color: UiColors.paper, fontSize: 15),
            ),
          ],
        ),
      );
    },
  );
}

/// Etkinlik oyun sonu paneli (kartpostalın dışında).
class EventResultPanel extends StatelessWidget {
  const EventResultPanel({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<EventRunOutcome?>(
    valueListenable: game.services.progress.lastEvent,
    builder: (context, o, _) {
      if (o == null) return const SizedBox.shrink();
      final weekly = game.services.progress.lastWeekly.value;
      const small = TextStyle(color: UiColors.paper, fontSize: 15);
      const accent = TextStyle(color: UiColors.mustard, fontSize: 15);
      final slot = EventCalendar.slotById(o.eventId);
      final levels = [...o.seasonLevels, ...?weekly?.seasonLevels];
      final points = o.seasonPoints + (weekly?.seasonPoints ?? 0);
      return Container(
        key: const Key('eventResult'),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: pixelBox(
          color: UiColors.scrim,
          border: eventStyle(o.type).border,
          steps: 3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              trUpper(
                o.kind == EventKind.weeklyCup
                    ? 'İstanbul Kupası · ${o.type.title}'
                    : o.type.title,
              ),
              style: const TextStyle(
                color: UiColors.mustard,
                fontSize: 15,
                letterSpacing: 1,
              ),
            ),
            if (!o.ranked) ...[
              const SizedBox(height: 4),
              const Text(
                'Bu uçuş antrenman sayıldı (etkinlik bitti ya da cihaz saati doğrulanamadı).',
                key: Key('eventPracticeNote'),
                style: small,
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Puan: ${o.score}',
                    key: const Key('eventResultScore'),
                    style: o.newBest ? accent : small,
                  ),
                ),
                Text(
                  o.kind == EventKind.weeklyCup
                      ? 'Haftalık en iyi: ${o.bestScore}'
                      : 'En iyi: ${o.bestScore}',
                  key: const Key('eventResultBest'),
                  style: small,
                ),
              ],
            ),
            if (o.newBest && o.previousBest > 0)
              Text(
                'Yeni en iyi! (+${o.score - o.previousBest})',
                key: const Key('eventResultImproved'),
                style: accent,
              ),
            for (final k in o.rewards)
              Text(
                '${eventRewardText(slot?.rewards ?? EventPresets.rewardsFor(o.kind, ScoringPolicy.obstacles), k)}: ödül alındı',
                key: Key('eventResultReward_$k'),
                style: accent,
              ),
            if (points > 0)
              Text(
                '+$points sezon puanı${o.simits + (weekly?.simits ?? 0) > 0 ? ' · +${o.simits + (weekly?.simits ?? 0)} simit' : ''}',
                key: const Key('eventResultPoints'),
                style: accent,
              ),
            for (final m in weekly?.completed ?? const <WeeklyMission>[])
              Text(
                'Haftalık görev: ${m.title}',
                key: Key('eventResultWeekly_${m.id}'),
                style: small,
              ),
            for (final l in levels)
              Text(
                'Sezon seviyesi ${l.level}: ${_levelText(l)}',
                key: Key('eventResultLevel_${l.level}'),
                style: accent,
              ),
            if (o.simitsCapped)
              const Text(
                'Festival simit sınırına ulaştın; fazlası cüzdana geçmedi.',
                key: Key('eventResultCapped'),
                style: small,
              ),
            if (o.ranked && o.kind == EventKind.weeklyCup) ...[
              const SizedBox(height: 4),
              _CupResultRank(game: game, eventId: o.eventId),
            ],
          ],
        ),
      );
    },
  );
}

/// Oyun sonundaki kupa sırası: yalnızca Game Center'dan gerçekten yüklenen sıra gösterilir.
class _CupResultRank extends StatefulWidget {
  const _CupResultRank({required this.game, required this.eventId});

  final IstanbulFlightGame game;
  final String eventId;

  @override
  State<_CupResultRank> createState() => _CupResultRankState();
}

class _CupResultRankState extends State<_CupResultRank> {
  Future<GcBoardPage>? _page;
  DailyGcStatus? _loadedFor;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<PlayerProgress>(
    valueListenable: widget.game.services.progress,
    builder: (context, p, _) {
      final gc = widget.game.services.gameCenter;
      final status = p.events[widget.eventId]?.gcStatus ?? DailyGcStatus.none;
      const style = TextStyle(color: UiColors.paper, fontSize: 11);
      if (!gc.value.signedIn) {
        return const Text(
          'Game Center bağlı değil: skor yalnızca bu cihazda.',
          key: Key('cupResultRank'),
          style: style,
        );
      }
      if (status != DailyGcStatus.submitted) {
        return Text(
          cupGcStatusText(status),
          key: const Key('cupResultRank'),
          style: style,
        );
      }
      if (_loadedFor != status) {
        _loadedFor = status;
        _page = gc.loadBoard(GcBoard.weeklyCup, GcScope.global)..ignore();
      }
      return FutureBuilder<GcBoardPage>(
        future: _page,
        builder: (context, snap) {
          final local = snap.data?.local;
          final total = snap.data?.total ?? 0;
          return Text(
            local == null
                ? 'Kupa skorun Game Center’a gönderildi.'
                : 'Haftalık sıralaman: ${local.rank}.${total > 0 ? ' / $total' : ''}',
            key: const Key('cupResultRank'),
            style: style,
          );
        },
      );
    },
  );
}
