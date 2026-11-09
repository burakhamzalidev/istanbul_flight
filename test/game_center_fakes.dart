import 'dart:async';

import 'package:istanbul_flight/services/game_center/game_center.dart';

/// GameKit'i taklit eden sahte adaptör: Apple sunucusuna bağlanmaz.
///
/// Klasik tablo en iyi skoru tutar; haftalık tablo bir "dönem" taklidiyle en iyi skoru tutar
/// ([weekStart]'tan önce yapılmış skorlar `expired`, dönem kapalıysa `inactive`).
class FakeGameCenterApi implements GameCenterApi {
  FakeGameCenterApi({
    this.isSupported = true,
    this.authResult = const GcAuthStatus(authenticated: true, alias: 'Simit42'),
  });

  @override
  final bool isSupported;

  /// authenticate() bunu döndürür (ör. iptal: authenticated false, error 'cancelled').
  GcAuthStatus authResult;

  /// true: her ağ çağrısı `network` hatası verir (internet yok).
  bool offline = false;

  /// Belirli bir işlem için zorla hata kodu (ör. 'not_configured', 'friends_denied').
  String? failCode;

  /// Haftalık dönemin başlangıcı (sunucu saati taklidi); null = dönem kapalı.
  DateTime? weekStart = DateTime(2026, 10, 19);

  final submissions = <(GcBoard, int)>[];
  final reports = <Map<String, double>>[];
  final banners = <Set<String>>[];
  final achievements = <String, double>{};
  final best = <GcBoard, int>{};
  int authCalls = 0;
  int loadCalls = 0;
  GcBoardPage page = const GcBoardPage();

  final _status = StreamController<GcAuthStatus>.broadcast();

  @override
  Stream<GcAuthStatus> get statusChanges => _status.stream;

  /// Oyuncunun Ayarlar'dan giriş/çıkış yapması.
  void emitStatus(GcAuthStatus s) {
    authResult = s;
    _status.add(s);
  }

  void _check() {
    if (offline) throw const GameCenterException('network');
    if (!authResult.authenticated) {
      throw const GameCenterException('not_authenticated');
    }
    final f = failCode;
    if (f != null) throw GameCenterException(f);
  }

  @override
  Future<GcAuthStatus> authenticate() async {
    authCalls++;
    return authResult;
  }

  /// Günlük tablonun açık döneminin başlangıcı (sunucu saati taklidi, 00:00 UTC); null = dönem kapalı.
  DateTime? dayStart;

  /// Günlük tablonun dönem süresi (yanlış kurulmuş tablo taklidi için değiştirilebilir).
  Duration dayLength = const Duration(days: 1);

  final submittedOccurrences = <DateTime?>[];

  DateTime? _startOf(GcBoard board) =>
      board == GcBoard.daily ? dayStart : weekStart;

  @override
  Future<void> submitScore(
    GcBoard board,
    int score, {
    DateTime? achievedAt,
    DateTime? occurrenceStart,
  }) async {
    _check();
    if (board.recurring) {
      final start = _startOf(board);
      if (start == null) throw const GameCenterException('inactive');
      // native: açık dönem beklenen anda başlamadıysa skor başka bir güne aittir
      if (occurrenceStart != null &&
          start.difference(occurrenceStart).inSeconds.abs() > 120) {
        throw const GameCenterException('expired');
      }
      if (achievedAt != null && achievedAt.isBefore(start)) {
        throw const GameCenterException('expired');
      }
    }
    submittedOccurrences.add(occurrenceStart);
    submissions.add((board, score));
    final prev = best[board];
    if (prev == null || score > prev) best[board] = score;
  }

  @override
  Future<void> reportAchievements(
    Map<String, double> percents, {
    Set<String> banner = const {},
  }) async {
    _check();
    reports.add(Map.of(percents));
    banners.add(Set.of(banner));
    for (final e in percents.entries) {
      final prev = achievements[e.key] ?? 0;
      if (e.value > prev) achievements[e.key] = e.value;
    }
  }

  @override
  Future<GcBoardPage> loadEntries(
    GcBoard board,
    GcScope scope, {
    int limit = 25,
  }) async {
    loadCalls++;
    _check();
    return page;
  }

  int occurrenceCalls = 0;

  @override
  Future<GcOccurrence?> loadOccurrence(GcBoard board) async {
    occurrenceCalls++;
    _check();
    final start = _startOf(board);
    if (start == null) return null;
    return GcOccurrence(
      start: start,
      end: start.add(
        board == GcBoard.daily ? dayLength : const Duration(days: 7),
      ),
    );
  }

  int nativeOpens = 0;

  @override
  Future<void> showLeaderboard(GcBoard board, GcScope scope) async {
    _check();
    nativeOpens++;
  }

  @override
  Future<void> showAchievements() async {
    _check();
    nativeOpens++;
  }
}
