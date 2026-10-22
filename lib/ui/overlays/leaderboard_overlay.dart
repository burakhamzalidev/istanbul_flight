import 'package:flutter/material.dart';

import '../../game/day_cycle.dart';
import '../../game/istanbul_flight_game.dart';
import '../../services/game_center/game_center.dart';
import '../../services/game_center/game_center_controller.dart';
import '../pixel.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import 'menu_overlays.dart';

// Phase 2.4 arayüzü: Sıralama (Apple Game Center). docs/16 §8.
// Oyuncu adları ve sıralama satırları yalnızca ekranda gösterilir, saklanmaz. Game Center'a bağlı olmayan
// oyuncu anlaşılır bir boş durum görür; oyun her durumda çevrimdışı oynanır.

/// Ana menüde "İstanbul'u Keşfet"in yanındaki giriş noktası.
class LeaderboardMenuButton extends StatelessWidget {
  const LeaderboardMenuButton({super.key, required this.game, this.compact});

  final IstanbulFlightGame game;

  /// Yalnızca ikon (dar menü). null: ekran genişliğinden karar verilir.
  final bool? compact;

  @override
  Widget build(BuildContext context) {
    final narrow = compact ?? MediaQuery.sizeOf(context).width < 360;
    return Pressable(
      key: const Key('leaderboardButton'),
      game: game,
      semanticLabel: 'Sıralama',
      onTap: () => game.openModal(Overlays.leaderboard),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: narrow ? 8 : 12,
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
              const PixelIcon(
                Icons.emoji_events_rounded,
                color: UiColors.mustard,
                size: 24,
              ),
              if (!narrow) ...[
                const SizedBox(width: 6),
                const Text(
                  'Sıralama',
                  style: TextStyle(color: UiColors.paper, fontSize: 15),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LeaderboardOverlay extends StatefulWidget {
  const LeaderboardOverlay({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  State<LeaderboardOverlay> createState() => _LeaderboardOverlayState();
}

class _LeaderboardOverlayState extends State<LeaderboardOverlay> {
  GcBoard _board = GcBoard.allTime;
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
    final f = gc.loadBoard(_board, _scope);
    f.ignore(); // hata FutureBuilder'da gösterilir
    if (!mounted) return;
    setState(() {
      _page = f;
    });
  }

  void _select({GcBoard? board, GcScope? scope}) {
    _board = board ?? _board;
    _scope = scope ?? _scope;
    _reload();
  }

  Future<void> _native(Future<void> Function() open) async {
    try {
      await open();
    } catch (_) {
      // Game Center ekranı açılamazsa sessiz: durum kartı zaten nedeni gösterir
    }
  }

  @override
  Widget build(BuildContext context) => ModalCard(
    game: widget.game,
    title: 'Sıralama',
    child: ValueListenableBuilder<GameCenterState>(
      valueListenable: gc,
      builder: (context, s, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OwnRecord(game: widget.game),
          const SizedBox(height: 10),
          _StatusCard(game: widget.game, state: s, onConnect: gc.connect),
          if (s.signedIn) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Toggle(
                    key: const Key('boardAllTime'),
                    game: widget.game,
                    label: 'Tüm zamanlar',
                    selected: _board == GcBoard.allTime,
                    onTap: () => _select(board: GcBoard.allTime),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _Toggle(
                    key: const Key('boardWeekly'),
                    game: widget.game,
                    label: 'Haftalık',
                    selected: _board == GcBoard.weekly,
                    onTap: () => _select(board: GcBoard.weekly),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _Toggle(
                    key: const Key('scopeGlobal'),
                    game: widget.game,
                    label: 'Dünya',
                    selected: _scope == GcScope.global,
                    onTap: () => _select(scope: GcScope.global),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _Toggle(
                    key: const Key('scopeFriends'),
                    game: widget.game,
                    label: 'Arkadaşlar',
                    selected: _scope == GcScope.friends,
                    onTap: () => _select(scope: GcScope.friends),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<GcBoardPage>(
              future: _page,
              builder: (context, snap) => _BoardList(
                game: widget.game,
                snap: snap,
                board: _board,
                scope: _scope,
                onRetry: _reload,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: MartiButton(
                    key: const Key('openGameCenter'),
                    game: widget.game,
                    label: 'Game Center',
                    icon: Icons.emoji_events_rounded,
                    style: MartiButtonStyle.secondary,
                    height: 48,
                    onPressed: () =>
                        _native(() => gc.api.showLeaderboard(_board, _scope)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: MartiButton(
                    key: const Key('openGcAchievements'),
                    game: widget.game,
                    label: 'Başarımlar',
                    icon: Icons.star_rounded,
                    style: MartiButtonStyle.secondary,
                    height: 48,
                    onPressed: () => _native(gc.api.showAchievements),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Skorlar yalnızca Game Center’a giriş yaptıysan Apple’a gönderilir. '
            'Görünümler, XP ve simitler skoru etkilemez.',
            textAlign: TextAlign.center,
            style: TextStyle(color: UiColors.navySoft, fontSize: 10),
          ),
        ],
      ),
    ),
  );
}

/// Oyuncunun yerel rekoru (Game Center'dan bağımsız, her zaman görünür).
class _OwnRecord extends StatelessWidget {
  const _OwnRecord({required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: game.best,
    builder: (_, best, _) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pixelBox(
        color: UiColors.cream,
        border: UiColors.mustard,
        steps: 2,
      ),
      child: Row(
        children: [
          const PixelIcon(
            Icons.emoji_events_rounded,
            color: UiColors.mustard,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              best == 0
                  ? 'Henüz rekorun yok'
                  : 'Rekorun · ${zones[zoneIndexForScore(best)].name}',
              style: const TextStyle(color: UiColors.navy),
            ),
          ),
          Text(
            '$best',
            key: const Key('ownBest'),
            style: const TextStyle(color: UiColors.navy, fontSize: 20),
          ),
        ],
      ),
    ),
  );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.game,
    required this.state,
    required this.onConnect,
  });

  final IstanbulFlightGame game;
  final GameCenterState state;
  final Future<void> Function() onConnect;

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (state.connection) {
      GcConnection.unsupported => (
        'Game Center bu cihazda yok',
        'Game Center yalnızca iPhone ve iPad’de çalışır. Oyun her yerde çevrimdışı oynanır; '
            'rekorun bu cihazda saklanır.',
      ),
      GcConnection.connecting => ('Game Center’a bağlanılıyor…', null),
      GcConnection.signedOut => (
        'Game Center’a bağlı değilsin',
        state.lastError == 'cancelled'
            ? 'Giriş penceresini kapattıysan iPhone Ayarlar > Game Center’dan giriş yapabilirsin. '
                  'Oyun bağlantısız da aynen oynanır.'
            : 'Bağlanınca dünya ve arkadaş sıralamasını görür, haftalık yarışa katılırsın. '
                  'Oyun bağlantısız da aynen oynanır.',
      ),
      GcConnection.signedIn => (
        'Game Center: ${state.alias ?? 'bağlı'}',
        _signedInNote(state),
      ),
    };
    return Container(
      key: Key('gcStatus_${state.connection.name}'),
      padding: const EdgeInsets.all(10),
      decoration: pixelBox(
        color: state.signedIn ? const Color(0xFFF6EBC8) : UiColors.cream,
        border: state.signedIn ? UiColors.mustard : const Color(0xFFD8CDB6),
        steps: 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            key: const Key('gcStatusTitle'),
            style: const TextStyle(color: UiColors.navy, fontSize: 15),
          ),
          if (body != null) ...[
            const SizedBox(height: 4),
            Text(
              body,
              key: const Key('gcStatusBody'),
              style: const TextStyle(color: UiColors.navySoft, fontSize: 10),
            ),
          ],
          if (state.connection == GcConnection.signedOut) ...[
            const SizedBox(height: 8),
            MartiButton(
              key: const Key('gcConnect'),
              game: game,
              label: 'Game Center’a bağlan',
              height: 48,
              onPressed: onConnect,
            ),
          ],
        ],
      ),
    );
  }

  static String? _signedInNote(GameCenterState s) {
    final notes = <String>[
      if (s.pendingCount > 0)
        'Gönderilmeyi bekleyen skor var; bağlantı gelince gönderilir.',
      if (s.restricted) 'Hesap kısıtlı: arkadaş sıralaması kullanılamayabilir.',
    ];
    return notes.isEmpty ? null : notes.join(' ');
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    super.key,
    required this.game,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IstanbulFlightGame game;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: Pressable(
      game: game,
      semanticLabel: label,
      onTap: selected ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: pixelBox(
          color: selected ? UiColors.navy : UiColors.cream,
          border: selected ? UiColors.mustard : const Color(0xFFD8CDB6),
          steps: 2,
        ),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? UiColors.paper : UiColors.navy,
            fontSize: 15,
          ),
        ),
      ),
    ),
  );
}

/// Sıralama satırları: yükleniyor, hata, boş ve liste durumları.
class _BoardList extends StatelessWidget {
  const _BoardList({
    required this.game,
    required this.snap,
    required this.board,
    required this.scope,
    required this.onRetry,
  });

  final IstanbulFlightGame game;
  final AsyncSnapshot<GcBoardPage> snap;
  final GcBoard board;
  final GcScope scope;
  final VoidCallback onRetry;

  static String errorText(Object? e) {
    final code = e is GameCenterException ? e.code : 'failed';
    return switch (code) {
      'network' =>
        'Sıralama yüklenemedi: internet bağlantısı yok gibi görünüyor.',
      'friends_denied' => 'Arkadaş listesine izin verilmedi. iPhone Ayarlar > Game Center’dan izin verebilirsin.',
      'not_configured' ||
      'unknown_leaderboard' => 'Bu sıralama Apple tarafında henüz etkin değil.',
      'not_authenticated' => 'Game Center oturumu kapalı.',
      _ => 'Sıralama şu an yüklenemedi.',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (snap.connectionState != ConnectionState.done) {
      return const _Message(key: Key('boardLoading'), text: 'Yükleniyor…');
    }
    if (snap.hasError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Message(key: const Key('boardError'), text: errorText(snap.error)),
          const SizedBox(height: 6),
          MartiButton(
            key: const Key('boardRetry'),
            game: game,
            label: 'Tekrar dene',
            style: MartiButtonStyle.secondary,
            height: 44,
            onPressed: onRetry,
          ),
        ],
      );
    }
    final page = snap.data ?? const GcBoardPage();
    final end = page.occurrenceEnd;
    final local = page.local;
    final showLocalBelow = local != null && !page.entries.any((e) => e.isLocal);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (board == GcBoard.weekly && end != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Bu haftanın yarışı ${end.toLocal().day}.${end.toLocal().month.toString().padLeft(2, '0')} '
              '${end.toLocal().hour.toString().padLeft(2, '0')}:${end.toLocal().minute.toString().padLeft(2, '0')}’de biter.',
              key: const Key('weeklyEnds'),
              style: const TextStyle(color: UiColors.navySoft, fontSize: 10),
            ),
          ),
        if (page.entries.isEmpty)
          _Message(
            key: const Key('boardEmpty'),
            text: scope == GcScope.friends
                ? 'Arkadaşların bu sıralamada henüz yok.'
                : 'Henüz skor yok. İlk sen ol!',
          )
        else
          for (final e in page.entries) _Row(entry: e),
        if (showLocalBelow) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '···',
              textAlign: TextAlign.center,
              style: TextStyle(color: UiColors.navySoft),
            ),
          ),
          _Row(entry: local),
        ],
        if (page.total > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${page.total} oyuncu',
              textAlign: TextAlign.right,
              style: const TextStyle(color: UiColors.navySoft, fontSize: 10),
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry});

  final GcEntry entry;

  @override
  Widget build(BuildContext context) => Container(
    key: Key(entry.isLocal ? 'boardRowLocal' : 'boardRow_${entry.rank}'),
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: pixelBox(
      color: entry.isLocal ? const Color(0xFFF6EBC8) : UiColors.cream,
      border: entry.isLocal ? UiColors.mustard : const Color(0xFFD8CDB6),
      steps: 1,
    ),
    child: Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            '${entry.rank}.',
            style: const TextStyle(color: UiColors.navySoft),
          ),
        ),
        Expanded(
          child: Text(
            entry.isLocal ? '${entry.alias} (sen)' : entry.alias,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: UiColors.navy),
          ),
        ),
        Text('${entry.score}', style: const TextStyle(color: UiColors.navy)),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: UiColors.navySoft, fontSize: 15),
    ),
  );
}
