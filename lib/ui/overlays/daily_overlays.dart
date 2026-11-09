import 'dart:async';

import 'package:flutter/material.dart';

import '../../challenge/daily_challenge.dart';
import '../../challenge/daily_state.dart';
import '../../game/istanbul_flight_game.dart';
import '../../services/game_center/game_center.dart';
import '../../services/game_center/game_center_controller.dart';
import '../../services/progress.dart';
import '../pixel.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/simit_icon.dart';
import 'leaderboard_overlay.dart';
import 'menu_overlays.dart';

// Phase 2.5: Günün Uçuşu arayüzü (docs/17 §10–§11): menü girişi, günlük ekran, "uçmak için dokun" şeridi
// ve oyun sonu paneli. Sıralama yalnızca Game Center'dan gelen gerçek veriyle gösterilir.

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

/// Challenge günü (UTC tarih; her yerde aynı): "24 Ekim 2026".
String formatDailyDate(DateTime utcDay) {
  final d = utcDay.toUtc();
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// "5 sa 12 dk", "12 dk", "45 sn".
String formatCountdown(Duration d) {
  if (d.isNegative) return '0 sn';
  final h = d.inHours, m = d.inMinutes % 60;
  if (h > 0) return '$h sa $m dk';
  if (m > 0) return '$m dk';
  return '${d.inSeconds} sn';
}

/// Ödül anahtarının ekrandaki adı ve miktarı.
(String, String) dailyRewardText(String key) {
  final p = DailyRewardPolicy.v1;
  if (key == DailyRewardPolicy.firstFlightKey) {
    return ('Günün ilk dereceli uçuşu', '+${p.firstFlightXp} XP');
  }
  for (final (threshold, simits) in p.scoreRewards) {
    if (key == DailyRewardPolicy.scoreKey(threshold)) {
      return ('Bir uçuşta $threshold skor', '+$simits simit');
    }
  }
  return (key, '');
}

String _clockText(DailyClockStatus s) => switch (s) {
  DailyClockStatus.ok => '',
  DailyClockStatus.rolledBack =>
    'Cihazın tarihi daha önce oynadığın bir günün gerisinde görünüyor. Tarih ve saat otomatik '
        'ayarlanınca dereceli uçuş yeniden açılır; antrenman her zaman açık.',
  DailyClockStatus.mismatch =>
    'Cihazın tarihi Game Center’ın gününden farklı. Ayarlar > Genel > Tarih ve Saat’ten '
        '“Otomatik Ayarla”yı aç; antrenman her zaman açık.',
};

DailyChallengeRecord? _todayRecord(IstanbulFlightGame game, PlayerProgress p) {
  final id = DailyChallengeDefinition.idFor(
    utcDayKey(game.services.daily.now()),
  );
  return p.dailyChallenge[id];
}

/// Ana menü girişi: takvim ikonu, "Günün Uçuşu" ve kalan dereceli hak.
class DailyMenuButton extends StatelessWidget {
  const DailyMenuButton({super.key, required this.game, this.compact});

  final IstanbulFlightGame game;

  /// Kısa etiket ("Günlük"). null: ekran genişliğinden karar verilir.
  final bool? compact;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<PlayerProgress>(
    valueListenable: game.services.progress,
    builder: (context, p, _) {
      final remaining =
          _todayRecord(game, p)?.remaining ?? DailyRules.rankedAttempts;
      final narrow = compact ?? MediaQuery.sizeOf(context).width < 360;
      return Pressable(
        key: const Key('dailyButton'),
        game: game,
        semanticLabel:
            'Günün Uçuşu, $remaining / ${DailyRules.rankedAttempts} dereceli hak',
        onTap: () => game.openModal(Overlays.daily),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pixelBox(
              color: UiColors.scrim,
              border: UiColors.mustard,
              steps: 3,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PixelIcon(
                  Icons.calendar_month_rounded,
                  color: UiColors.mustard,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    narrow ? 'Günlük' : 'Günün Uçuşu',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: UiColors.paper, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$remaining/${DailyRules.rankedAttempts}',
                  key: const Key('dailyMenuRemaining'),
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

/// Günün Uçuşu ekranı.
class DailyOverlay extends StatefulWidget {
  const DailyOverlay({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  State<DailyOverlay> createState() => _DailyOverlayState();
}

class _DailyOverlayState extends State<DailyOverlay> {
  late DailyChallengeDefinition _def;
  Timer? _tick;

  IstanbulFlightGame get game => widget.game;

  @override
  void initState() {
    super.initState();
    _def = game.services.daily.today();
    // Apple'ın günlük dönemi tazelenir (saat denetimi); hata oyunu etkilemez
    unawaited(game.services.gameCenter.refreshDailyOccurrence());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        // gün döndüyse yeni challenge gösterilir
        final now = game.services.daily.today();
        if (now.challengeId != _def.challengeId) _def = now;
      });
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ModalCard(
    game: game,
    title: 'Günün Uçuşu',
    child: ValueListenableBuilder<PlayerProgress>(
      valueListenable: game.services.progress,
      builder: (context, p, _) {
        final rec = p.dailyChallenge[_def.challengeId];
        final remaining = rec?.remaining ?? DailyRules.rankedAttempts;
        final best = rec?.bestScore ?? 0;
        final clock = game.services.daily.clockStatus(p);
        final canRank = remaining > 0 && clock == DailyClockStatus.ok;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(game: game, def: _def),
            const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Fact(
                      label: 'Dereceli hak',
                      value: '$remaining/${DailyRules.rankedAttempts}',
                      valueKey: const Key('dailyRemaining'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _Fact(
                      label: 'Bugünün en iyisi',
                      value: '$best',
                      valueKey: const Key('dailyBest'),
                    ),
                  ),
                ],
              ),
            ),
            if (clock != DailyClockStatus.ok) ...[
              const SizedBox(height: 8),
              _Note(
                key: const Key('dailyClockWarning'),
                text: _clockText(clock),
              ),
            ],
            const SizedBox(height: 10),
            _Rewards(claimed: rec?.claimed ?? const {}),
            const SizedBox(height: 10),
            _DailyBoard(game: game, record: rec),
            const SizedBox(height: 12),
            if (canRank)
              MartiButton(
                key: const Key('dailyStart'),
                game: game,
                label: 'Uçuşa başla',
                icon: Icons.flight_takeoff_rounded,
                width: double.infinity,
                height: 60,
                onPressed: () => game.startDaily(ranked: true),
              )
            else ...[
              if (remaining == 0)
                const _Note(
                  key: Key('dailyDone'),
                  text: 'Bugünün dereceli hakları bitti. Yarın yeni parkur!',
                ),
              const SizedBox(height: 6),
              MartiButton(
                key: const Key('dailyPractice'),
                game: game,
                label: 'Antrenman yap',
                icon: Icons.replay_rounded,
                width: double.infinity,
                height: 60,
                onPressed: () => game.startDaily(ranked: false),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              canRank
                  ? 'Hak, uçuş başladığında kullanılır. Yarıda bırakılan uçuş da hak sayılır.'
                  : 'Antrenman aynı parkurda uçar; sıralamaya ve günlük ödüllere sayılmaz.',
              key: const Key('dailyRuleNote'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: UiColors.navySoft, fontSize: 10),
            ),
          ],
        );
      },
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.game, required this.def});

  final IstanbulFlightGame game;
  final DailyChallengeDefinition def;

  @override
  Widget build(BuildContext context) {
    final names = DailyGenerators.zoneNames(def);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: pixelBox(
        color: const Color(0xFFF6EBC8),
        border: UiColors.mustard,
        steps: 2,
      ),
      child: Row(
        children: [
          const PixelIcon(
            Icons.calendar_month_rounded,
            color: UiColors.action,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDailyDate(def.dateUtc),
                  key: const Key('dailyDate'),
                  style: const TextStyle(color: UiColors.navy, fontSize: 20),
                ),
                const SizedBox(height: 2),
                Text(
                  'Herkes aynı parkurda: ${names.first} – ${names.last}',
                  style: const TextStyle(
                    color: UiColors.navySoft,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Yeni parkur: ${formatCountdown(game.services.daily.timeToReset())} sonra',
                  key: const Key('dailyCountdown'),
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

class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final Key valueKey;

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
          style: const TextStyle(color: UiColors.navySoft, fontSize: 10),
        ),
      ],
    ),
  );
}

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
      style: const TextStyle(color: UiColors.navy, fontSize: 10),
    ),
  );
}

/// Günlük ödüller (tek seferlik); alınanlar işaretli.
class _Rewards extends StatelessWidget {
  const _Rewards({required this.claimed});

  final Set<String> claimed;

  @override
  Widget build(BuildContext context) {
    final keys = [
      DailyRewardPolicy.firstFlightKey,
      for (final (t, _) in DailyRewardPolicy.v1.scoreRewards)
        DailyRewardPolicy.scoreKey(t),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'GÜNLÜK ÖDÜLLER',
          style: TextStyle(color: UiColors.navy, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        for (final k in keys)
          Padding(
            key: Key('dailyReward_$k'),
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: claimed.contains(k)
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
                    dailyRewardText(k).$1,
                    style: TextStyle(
                      color: claimed.contains(k)
                          ? UiColors.navySoft
                          : UiColors.navy,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  dailyRewardText(k).$2,
                  style: const TextStyle(color: UiColors.action, fontSize: 15),
                ),
                if (k != DailyRewardPolicy.firstFlightKey) ...[
                  const SizedBox(width: 4),
                  const SimitIcon(size: 16),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Günlük sıralama: Game Center bağlıysa dünya/arkadaşlar; değilse yalnızca durum (uydurma sıra yok).
class _DailyBoard extends StatefulWidget {
  const _DailyBoard({required this.game, required this.record});

  final IstanbulFlightGame game;
  final DailyChallengeRecord? record;

  @override
  State<_DailyBoard> createState() => _DailyBoardState();
}

class _DailyBoardState extends State<_DailyBoard> {
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
    final f = gc.loadBoard(GcBoard.daily, _scope);
    f.ignore(); // hata listede gösterilir
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
          const Text(
            'GÜNLÜK SIRALAMA',
            style: TextStyle(color: UiColors.navy, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          if (!s.signedIn)
            Text(
              s.connection == GcConnection.unsupported
                  ? 'Günlük sıralama Game Center ile çalışır (iPhone ve iPad). Günlük rekorun bu cihazda saklanır.'
                  : 'Game Center’a bağlanınca dünya ve arkadaşlarınla aynı parkurda yarışırsın. '
                        'Bağlantısız da oynayabilirsin; skorun bu cihazda kalır.',
              key: const Key('dailyBoardOffline'),
              style: const TextStyle(color: UiColors.navySoft, fontSize: 10),
            )
          else ...[
            if (status != DailyGcStatus.none)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  dailyGcStatusText(status),
                  key: const Key('dailyGcStatus'),
                  style: const TextStyle(
                    color: UiColors.navySoft,
                    fontSize: 10,
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: BoardToggle(
                    key: const Key('dailyScopeGlobal'),
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
                    key: const Key('dailyScopeFriends'),
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
                board: GcBoard.daily,
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

String dailyGcStatusText(DailyGcStatus s) => switch (s) {
  DailyGcStatus.none => '',
  DailyGcStatus.pending => 'Günlük skorun Game Center’a gönderilmeyi bekliyor; bağlantı gelince gönderilir.',
  DailyGcStatus.submitted => 'Günlük skorun Game Center’a gönderildi.',
  DailyGcStatus.expired => 'Bu skor günün sıralaması kapandıktan sonra gönderilebildiği için sıralamaya girmedi.',
  DailyGcStatus.notEligible => 'Bu uçuş sıralamaya uygun değildi.',
};

/// "Uçmak için dokun" ekranındaki şerit: dereceli deneme numarası ya da antrenman.
class DailyReadyBanner extends StatelessWidget {
  const DailyReadyBanner({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<RunMode>(
    valueListenable: game.runMode,
    builder: (context, mode, _) {
      if (!mode.isDaily) return const SizedBox.shrink();
      final p = game.services.progress.value;
      final used = _todayRecord(game, p)?.used ?? 0;
      final ranked =
          mode == RunMode.dailyRanked &&
          used < DailyRules.rankedAttempts &&
          game.services.daily.clockStatus(p) == DailyClockStatus.ok;
      return Container(
        key: const Key('dailyReadyBanner'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: pixelBox(
          color: UiColors.scrim,
          border: UiColors.mustard,
          steps: 3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'GÜNÜN UÇUŞU',
              style: TextStyle(
                color: UiColors.mustard,
                fontSize: 15,
                letterSpacing: 2,
              ),
            ),
            Text(
              ranked
                  ? 'Dereceli deneme ${used + 1}/${DailyRules.rankedAttempts}'
                  : 'Antrenman · sıralamaya sayılmaz',
              key: const Key('dailyReadyText'),
              style: const TextStyle(color: UiColors.paper, fontSize: 15),
            ),
          ],
        ),
      );
    },
  );
}

/// Günlük oyun sonu paneli (kartpostalın dışında; paylaşılan görsel değişmez).
class DailyResultPanel extends StatelessWidget {
  const DailyResultPanel({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<DailyRunOutcome?>(
    valueListenable: game.services.progress.lastDaily,
    builder: (context, o, _) {
      if (o == null) return const SizedBox.shrink();
      const small = TextStyle(color: UiColors.paper, fontSize: 15);
      const accent = TextStyle(color: UiColors.mustard, fontSize: 15);
      final diff = o.diffFromPrevious;
      final notice = game.dailyNotice.value;
      return Container(
        key: const Key('dailyResult'),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: pixelBox(
          color: UiColors.scrim,
          border: UiColors.mustard,
          steps: 3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              o.ranked
                  ? 'GÜNÜN UÇUŞU · DERECELİ ${o.attemptNumber}/${DailyRules.rankedAttempts}'
                  : 'GÜNÜN UÇUŞU · ANTRENMAN',
              style: const TextStyle(
                color: UiColors.mustard,
                fontSize: 15,
                letterSpacing: 1,
              ),
            ),
            if (notice != null && !o.ranked) ...[
              const SizedBox(height: 4),
              Text(
                notice == DailyBeginResult.noAttempts
                    ? 'Dereceli hakkın kalmadığı için bu uçuş antrenman sayıldı.'
                    : 'Cihaz saati doğrulanamadığı için bu uçuş antrenman sayıldı.',
                key: const Key('dailyNotice'),
                style: small,
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bugünün en iyisi: ${o.bestScore}',
                    key: const Key('dailyResultBest'),
                    style: small,
                  ),
                ),
                if (o.ranked)
                  Text(
                    'Kalan hak: ${o.remaining}',
                    key: const Key('dailyResultRemaining'),
                    style: small,
                  ),
              ],
            ),
            if (o.ranked && diff != null) ...[
              const SizedBox(height: 2),
              Text(
                diff == 0
                    ? 'Önceki denemeyle aynı'
                    : 'Önceki denemeye göre ${diff > 0 ? '+' : ''}$diff',
                key: const Key('dailyResultDiff'),
                style: diff > 0 ? accent : small,
              ),
            ],
            if (o.rewards.isNotEmpty) ...[
              const SizedBox(height: 4),
              for (final k in o.rewards)
                Text(
                  '${dailyRewardText(k).$1}: ${dailyRewardText(k).$2}',
                  key: Key('dailyResultReward_$k'),
                  style: accent,
                ),
            ],
            if (o.ranked) ...[
              const SizedBox(height: 4),
              _ResultRank(game: game, challengeId: o.challengeId),
            ],
          ],
        ),
      );
    },
  );
}

/// Oyun sonundaki sıralama satırı: yalnızca Game Center'dan gerçekten yüklenen sıra gösterilir.
class _ResultRank extends StatefulWidget {
  const _ResultRank({required this.game, required this.challengeId});

  final IstanbulFlightGame game;
  final String challengeId;

  @override
  State<_ResultRank> createState() => _ResultRankState();
}

class _ResultRankState extends State<_ResultRank> {
  Future<GcBoardPage>? _page;
  DailyGcStatus? _loadedFor;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<PlayerProgress>(
    valueListenable: widget.game.services.progress,
    builder: (context, p, _) {
      final gc = widget.game.services.gameCenter;
      final status =
          p.dailyChallenge[widget.challengeId]?.gcStatus ?? DailyGcStatus.none;
      const style = TextStyle(color: UiColors.paper, fontSize: 10);
      if (!gc.value.signedIn) {
        return const Text(
          'Game Center bağlı değil: skor yalnızca bu cihazda.',
          key: Key('dailyResultRank'),
          style: style,
        );
      }
      if (status != DailyGcStatus.submitted) {
        return Text(
          dailyGcStatusText(status),
          key: const Key('dailyResultRank'),
          style: style,
        );
      }
      if (_loadedFor != status) {
        _loadedFor = status;
        _page = gc.loadBoard(GcBoard.daily, GcScope.global)..ignore();
      }
      return FutureBuilder<GcBoardPage>(
        future: _page,
        builder: (context, snap) {
          final local = snap.data?.local;
          final total = snap.data?.total ?? 0;
          return Text(
            local == null
                ? 'Günlük skorun Game Center’a gönderildi.'
                : 'Günlük sıralaman: ${local.rank}.${total > 0 ? ' / $total' : ''}',
            key: const Key('dailyResultRank'),
            style: style,
          );
        },
      );
    },
  );
}
