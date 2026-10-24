import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../challenge/daily_challenge.dart';
import '../../challenge/daily_state.dart';
import '../../data/score_repository.dart';
import '../../game/config.dart';
import '../../progression/achievements.dart';
import '../../progression/game_events.dart';
import '../progress.dart';
import 'game_center.dart';

// Phase 2.4: Game Center eşzamanlama katmanı (docs/16 §5–§7).
//
// Yerel sistemler (rekor, PlayerProgress, başarımlar) esas kaynaktır. Bu denetleyici yalnızca:
//   * geçerli tamamlanmış uçuşların skorunu Game Center'a gönderir (gönderilemezse güvenli kuyruk),
//   * önceki sürümlerin rekorunu (best_score_v1) bir kez tüm zamanlar tablosuna aktarır,
//   * yerel başarım durumunu Game Center'a yansıtır (ödül vermez).
// Hiçbir hata uçuşu, kaydı ya da arayüzü bloklamaz.
//
// Phase 2.5: Günün Uçuşu skorları YALNIZCA günlük tabloya gider (klasik tüm zamanlar / haftalık tablolara
// gitmez); antrenman uçuşları hiçbir tabloya gitmez. Günlük skor, challenge'ın gününe ait Apple dönemine
// gönderilir; o dönem kapandıysa ya da başka bir güne aitse gönderilmez (docs/17 §8).

/// Skor kabul kuralları: istemci tarafı makul tutarlılık kontrolü (sunucu doğrulaması değildir).
abstract final class GcScorePolicy {
  /// Liderlik tablosu üst sınırı (aşırı değerler reddedilir).
  static const maxScore = 9999;

  /// Engeller arası en kısa süre (en yüksek hızda) için tolerans: %10.
  static const timingTolerance = 0.9;

  /// Uçuşun Game Center'a gönderilmeme nedeni; uygunsa null.
  static String? rejectReason(
    RunResult r, {
    GameConfig config = const GameConfig(),
  }) {
    if (r.assisted) return 'assisted'; // otomatik pilot / koruma / başlangıç skoru (geliştirme modları)
    if (r.runId.isEmpty) return 'no_run_id';
    if (r.score <= 0) return 'zero';
    if (r.score > maxScore) return 'too_high';
    // Skor yalnızca gerçekten geçilen engellerden gelir
    if (r.score != r.obstaclesPassed) return 'score_mismatch';
    // n engeli geçmek için en az (n-1) aralık en yüksek hızda uçulmalı
    final minMs =
        (r.obstaclesPassed - 1) *
        config.obstacleSpacing /
        config.maxSpeed *
        1000;
    if (r.flightMs < minMs * timingTolerance) return 'too_fast';
    return null;
  }
}

/// Kalıcı Game Center kaydı: kimlik içermez (oyuncu adı, kimlik, avatar saklanmaz).
/// Günlük tabloya gönderilmeyi bekleyen skor.
@immutable
class GcDailyPending {
  const GcDailyPending({required this.score, required this.achievedAt});

  final int score;
  final DateTime achievedAt;
}

@immutable
class GcRecord {
  const GcRecord({
    this.pendingBest = 0,
    this.legacyExported = false,
    this.dailyPending = const {},
  });

  /// Henüz gönderilemeyen en iyi tüm zamanlar skoru (0 = yok). Daha düşük skorlar ayrıca tutulmaz.
  final int pendingBest;

  /// 1.0–1.3 rekoru (best_score_v1) tüm zamanlar tablosuna bir kez kuyruğa alındı mı.
  final bool legacyExported;

  /// challengeId → günün en iyi gönderilmemiş dereceli skoru (en fazla birkaç gün; eskiler düşer).
  final Map<String, GcDailyPending> dailyPending;

  GcRecord copyWith({
    int? pendingBest,
    bool? legacyExported,
    Map<String, GcDailyPending>? dailyPending,
  }) => GcRecord(
    pendingBest: pendingBest ?? this.pendingBest,
    legacyExported: legacyExported ?? this.legacyExported,
    dailyPending: dailyPending ?? this.dailyPending,
  );

  Map<String, Object> toJson() => {
    'v': 2,
    'pendingBest': pendingBest,
    'legacyExported': legacyExported,
    'dailyPending': {
      for (final e in dailyPending.entries)
        e.key: {
          'score': e.value.score,
          'achievedAt': e.value.achievedAt.toUtc().toIso8601String(),
        },
    },
  };

  factory GcRecord.fromJson(Object? j) {
    if (j is! Map) return const GcRecord();
    final best = j['pendingBest'];
    final daily = j['dailyPending'];
    final pending = <String, GcDailyPending>{};
    if (daily is Map) {
      for (final e in daily.entries) {
        final key = e.key, v = e.value;
        if (key is! String ||
            DailyChallengeDefinition.dayKeyOf(key) == null ||
            v is! Map) {
          continue;
        }
        final score = v['score'], at = v['achievedAt'];
        final when = at is String ? DateTime.tryParse(at) : null;
        if (score is int && score > 0 && when != null) {
          pending[key] = GcDailyPending(
            score: math.min(score, GcScorePolicy.maxScore),
            achievedAt: when,
          );
        }
      }
    }
    return GcRecord(
      pendingBest: best is int && best > 0
          ? math.min(best, GcScorePolicy.maxScore)
          : 0,
      legacyExported: j['legacyExported'] == true,
      dailyPending: pending,
    );
  }
}

abstract class GameCenterStore {
  Future<GcRecord> load();
  Future<void> save(GcRecord r);
}

class SharedPrefsGameCenterStore implements GameCenterStore {
  SharedPrefsGameCenterStore(this._prefs);

  static const key = 'game_center_v1';
  final SharedPreferences _prefs;

  @override
  Future<GcRecord> load() async {
    final raw = _prefs.getString(key);
    if (raw == null) return const GcRecord();
    try {
      return GcRecord.fromJson(jsonDecode(raw));
    } catch (e) {
      debugPrint('Game Center kaydı okunamadı, sıfırdan başlanıyor: $e');
      return const GcRecord();
    }
  }

  @override
  Future<void> save(GcRecord r) =>
      _prefs.setString(key, jsonEncode(r.toJson()));
}

class InMemoryGameCenterStore implements GameCenterStore {
  InMemoryGameCenterStore([this.record = const GcRecord()]);

  GcRecord record;
  int saves = 0;

  @override
  Future<GcRecord> load() async => record;

  @override
  Future<void> save(GcRecord r) async {
    record = r;
    saves++;
  }
}

enum GcConnection { unsupported, signedOut, connecting, signedIn }

@immutable
class GameCenterState {
  const GameCenterState({
    this.connection = GcConnection.unsupported,
    this.alias,
    this.restricted = false,
    this.lastError,
    this.pendingBest = 0,
    this.weeklyPending = false,
    this.dailyPending = 0,
  });

  final GcConnection connection;

  /// Görünen ad (yalnızca bellekte, ekranda gösterilir).
  final String? alias;
  final bool restricted;
  final String? lastError;
  final int pendingBest;
  final bool weeklyPending;

  /// Günlük tabloya gönderilmeyi bekleyen gün sayısı.
  final int dailyPending;

  bool get signedIn => connection == GcConnection.signedIn;
  int get pendingCount =>
      (pendingBest > 0 ? 1 : 0) + (weeklyPending ? 1 : 0) + dailyPending;

  GameCenterState copyWith({
    GcConnection? connection,
    String? alias,
    bool clearAlias = false,
    bool? restricted,
    String? lastError,
    bool clearError = false,
    int? pendingBest,
    bool? weeklyPending,
    int? dailyPending,
  }) => GameCenterState(
    connection: connection ?? this.connection,
    alias: clearAlias ? null : alias ?? this.alias,
    restricted: restricted ?? this.restricted,
    lastError: clearError ? null : lastError ?? this.lastError,
    pendingBest: pendingBest ?? this.pendingBest,
    weeklyPending: weeklyPending ?? this.weeklyPending,
    dailyPending: dailyPending ?? this.dailyPending,
  );
}

class GameCenterController extends ValueNotifier<GameCenterState>
    implements GameEventListener {
  GameCenterController({
    required this.api,
    required GameCenterStore store,
    required ValueListenable<PlayerProgress> progress,
    required ScoreRepository scores,
    this.config = const GameConfig(),
    DateTime Function()? clock,
  }) : _store = store, // ignore: prefer_initializing_formals
       _progress = progress, // ignore: prefer_initializing_formals
       _scores = scores, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now,
       super(const GameCenterState());

  /// Game Center'sız kurulum (testler, Android, web).
  factory GameCenterController.disabled() => GameCenterController(
    api: const UnavailableGameCenterApi(),
    store: InMemoryGameCenterStore(),
    progress: ValueNotifier(const PlayerProgress()),
    scores: InMemoryScoreRepository(),
  );

  final GameCenterApi api;
  final GameConfig config;
  final GameCenterStore _store;
  final ValueListenable<PlayerProgress> _progress;
  final ScoreRepository _scores;
  final DateTime Function() _clock;

  GcRecord _record = const GcRecord();

  /// Bu kurulumda bilinen en iyi skor (yerel rekor + gönderilen uçuşlar). Altındaki uçuşlar tüm zamanlar
  /// tablosuna gönderilmez (Game Center zaten en iyiyi tutar; gereksiz ağ isteği yok).
  int _knownBest = 0;

  /// Haftalık tabloya gönderilemeyen skor: yalnızca bellekte (uygulama kapanınca düşer; geçen haftanın
  /// skoru yeni haftaya taşınmaz, bkz. docs/16 §6).
  ({int score, DateTime at})? _weekly;

  /// Bu oturumda Game Center'a bildirilen başarım yüzdeleri (aynı değer tekrar gönderilmez).
  final Map<String, double> _reported = {};

  /// Günlük skorun durumu değişince (günlük kayda yazılır; GameServices bağlar).
  void Function(String challengeId, DailyGcStatus status)? onDailyStatus;

  /// Apple'ın günlük tablo dönemi okununca (saat denetimi; GameServices bağlar).
  void Function(GcOccurrence? occurrence)? onDailyOccurrence;

  bool _started = false;
  bool _flushing = false;
  bool _flushAgain = false;
  StreamSubscription<GcAuthStatus>? _sub;

  /// Açılışta bir kez: kayıt okunur, GameKit girişi başlatılır. Hata oyunu etkilemez.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      _record = await _store.load();
      _knownBest = math.max(_record.pendingBest, await _scores.loadBest());
    } catch (e) {
      debugPrint('Game Center kaydı yüklenemedi: $e');
    }
    value = value.copyWith(
      pendingBest: _record.pendingBest,
      dailyPending: _record.dailyPending.length,
    );
    if (!api.isSupported) return;
    _sub = api.statusChanges.listen(_applyStatus);
    _progress.addListener(_onProgress);
    await connect();
  }

  /// GameKit girişini ister. Oyuncu daha önce iptal ettiyse GameKit ekranı tekrar göstermez; arayüz
  /// Ayarlar > Game Center yönergesini gösterir.
  Future<void> connect() async {
    if (!api.isSupported) return;
    value = value.copyWith(
      connection: GcConnection.connecting,
      clearError: true,
    );
    try {
      _applyStatus(await api.authenticate());
    } on GameCenterException catch (e) {
      value = value.copyWith(
        connection: GcConnection.signedOut,
        lastError: e.code,
      );
    } catch (e) {
      value = value.copyWith(
        connection: GcConnection.signedOut,
        lastError: 'failed',
      );
    }
  }

  void _applyStatus(GcAuthStatus s) {
    final wasIn = value.signedIn;
    value = s.authenticated
        ? value.copyWith(
            connection: GcConnection.signedIn,
            alias: s.alias,
            restricted: s.restricted || s.underage,
            clearError: true,
          )
        : value.copyWith(
            connection: GcConnection.signedOut,
            clearAlias: true,
            lastError: s.error,
          );
    if (s.authenticated && !wasIn) {
      _reported.clear(); // hesap değişmiş olabilir: başarımlar baştan eşitlenir
      unawaited(_exportLegacyBest().then((_) => flush()));
      unawaited(refreshDailyOccurrence());
    } else if (!s.authenticated) {
      onDailyOccurrence?.call(null);
    }
  }

  /// Önceki sürümlerin rekoru (best_score_v1) tüm zamanlar tablosuna bir kez kuyruğa alınır. Uçuş
  /// geçmişi uydurulmaz; haftalık tabloya geçmişe dönük skor gönderilmez.
  Future<void> _exportLegacyBest() async {
    if (_record.legacyExported) return;
    try {
      final best = math.min(await _scores.loadBest(), GcScorePolicy.maxScore);
      _knownBest = math.max(_knownBest, best);
      await _save(
        _record.copyWith(
          legacyExported: true,
          pendingBest: math.max(_record.pendingBest, best),
        ),
      );
    } catch (e) {
      debugPrint('Eski rekor aktarılamadı: $e');
    }
  }

  @override
  void onGameEvent(GameEvent event) {
    if (event is RunFinished) unawaited(handleRun(event.result));
  }

  final Set<String> _handledRuns = {};

  /// Uçuş sonu: geçerliyse skor kuyruğa alınır ve gönderilir. Aynı uçuş iki kez işlenmez.
  Future<void> handleRun(RunResult r) async {
    if (!_handledRuns.add(r.runId)) return;
    if (_handledRuns.length > 50) _handledRuns.remove(_handledRuns.first);
    final reject = GcScorePolicy.rejectReason(r, config: config);
    switch (r.mode) {
      case RunMode.dailyPractice:
        return; // antrenman hiçbir tabloya gitmez
      case RunMode.dailyRanked:
        return _queueDaily(r, reject);
      case RunMode.classic:
        break;
    }
    if (reject != null) return;
    if (r.score > _knownBest) {
      _knownBest = r.score;
      await _save(
        _record.copyWith(pendingBest: math.max(_record.pendingBest, r.score)),
      );
    }
    final w = _weekly;
    if (w == null || r.score > w.score) {
      _weekly = (score: r.score, at: _clock());
      value = value.copyWith(weeklyPending: true);
    }
    await flush();
  }

  /// Dereceli günlük skor: yalnızca günlük tablo. Uygun değilse gönderilmez.
  Future<void> _queueDaily(RunResult r, String? reject) async {
    final id = r.challengeId;
    final day = id == null ? null : DailyChallengeDefinition.dayKeyOf(id);
    if (id == null || day == null) return;
    final had = _record.dailyPending[id];
    if (reject != null) {
      // daha önce bekleyen ya da gönderilen bir skor varsa onun durumu korunur
      if (had == null && !_dailySent.contains(id)) {
        onDailyStatus?.call(id, DailyGcStatus.notEligible);
      }
      return;
    }
    final now = _clock();
    // uçuş challenge'ın günü dışında bitti (gece yarısını geçen uçuş): o günün tablosu kapanmıştır
    if (utcDayKey(now) != day) {
      if (had == null && !_dailySent.contains(id)) {
        onDailyStatus?.call(id, DailyGcStatus.expired);
      }
      return;
    }
    if (had != null && had.score >= r.score) return;
    await _save(
      _record.copyWith(
        dailyPending: {
          ..._record.dailyPending,
          id: GcDailyPending(score: r.score, achievedAt: now),
        },
      ),
    );
    onDailyStatus?.call(id, DailyGcStatus.pending);
    await flush();
  }

  /// Bu oturumda günlük tabloya gönderilen challenge'lar.
  final Set<String> _dailySent = {};

  Future<void> _save(GcRecord r) async {
    _record = r;
    value = value.copyWith(
      pendingBest: r.pendingBest,
      dailyPending: r.dailyPending.length,
    );
    try {
      await _store.save(r);
    } catch (e) {
      debugPrint('Game Center kuyruğu kaydedilemedi: $e');
    }
  }

  /// Kuyruktaki skorları ve başarımları gönderir. Bağlı değilse ya da ağ yoksa sessizce bekler;
  /// tekrar deneme: girişte, her uçuş sonunda ve uygulama öne gelince.
  Future<void> flush() async {
    if (!value.signedIn) return;
    if (_flushing) {
      _flushAgain = true;
      return;
    }
    _flushing = true;
    try {
      do {
        _flushAgain = false;
        await _flushBest();
        await _flushWeekly();
        await _flushDaily();
        await _syncAchievements();
      } while (_flushAgain && value.signedIn);
    } finally {
      _flushing = false;
    }
  }

  Future<void> _flushBest() async {
    final best = _record.pendingBest;
    if (best <= 0) return;
    try {
      await api.submitScore(GcBoard.allTime, best);
      // gönderim sürerken daha iyi bir skor geldiyse o kalır
      if (_record.pendingBest == best) {
        await _save(_record.copyWith(pendingBest: 0));
      }
      value = value.copyWith(clearError: true);
    } on GameCenterException catch (e) {
      value = value.copyWith(lastError: e.code); // kuyrukta kalır
    } catch (e) {
      value = value.copyWith(lastError: 'failed');
    }
  }

  Future<void> _flushWeekly() async {
    final w = _weekly;
    if (w == null) return;
    var drop = false;
    try {
      await api.submitScore(GcBoard.weekly, w.score, achievedAt: w.at);
      drop = true;
    } on GameCenterException catch (e) {
      // dönem kapalı ya da skor önceki döneme ait: gönderilmez, kuyruktan çıkar
      drop = e.code == 'inactive' || e.code == 'expired';
      value = value.copyWith(lastError: drop ? null : e.code);
    } catch (e) {
      value = value.copyWith(lastError: 'failed');
    }
    if (drop && identical(_weekly, w)) {
      _weekly = null;
      value = value.copyWith(weeklyPending: false);
    }
  }

  /// Bekleyen günlük skorlar kendi günlerinin Apple dönemine gönderilir. Dönem kapandıysa (ya da Apple'ın
  /// açık dönemi başka bir güne aitse) skor düşer: eski skor yeni günün tablosuna gitmez.
  Future<void> _flushDaily() async {
    for (final e in _record.dailyPending.entries.toList()) {
      final id = e.key;
      final start = parseUtcDayKey(DailyChallengeDefinition.dayKeyOf(id)!)!;
      DailyGcStatus? outcome; // null: kuyrukta kalır, sonra tekrar denenir
      if (_clock().difference(start) > const Duration(days: 2)) {
        outcome = DailyGcStatus
            .expired; // çok eski: Apple'ın dönemi kesin kapanmıştır
      } else {
        try {
          await api.submitScore(
            GcBoard.daily,
            e.value.score,
            achievedAt: e.value.achievedAt,
            occurrenceStart: start,
          );
          outcome = DailyGcStatus.submitted;
          value = value.copyWith(clearError: true);
        } on GameCenterException catch (x) {
          if (x.code == 'inactive' || x.code == 'expired') {
            outcome = DailyGcStatus.expired;
          } else {
            value = value.copyWith(lastError: x.code);
          }
        } catch (_) {
          value = value.copyWith(lastError: 'failed');
        }
      }
      if (outcome == null) continue;
      // gönderim sürerken aynı gün için daha iyi bir skor geldiyse o kalır
      if (identical(_record.dailyPending[id], e.value)) {
        await _save(
          _record.copyWith(dailyPending: {..._record.dailyPending}..remove(id)),
        );
      }
      if (outcome == DailyGcStatus.submitted) _dailySent.add(id);
      onDailyStatus?.call(id, outcome);
    }
  }

  /// Apple'ın günlük tablo dönemini okur (saat denetimi için). Hata ya da oturum yok: bilinmiyor (null).
  Future<void> refreshDailyOccurrence() async {
    if (!value.signedIn) return onDailyOccurrence?.call(null);
    try {
      onDailyOccurrence?.call(await api.loadOccurrence(GcBoard.daily));
    } catch (_) {
      onDailyOccurrence?.call(null);
    }
  }

  void _onProgress() => unawaited(flush());

  /// Yerel başarımların Game Center yansıması: açılanlar %100, diğerleri ilerleme yüzdesi.
  Future<void> _syncAchievements() async {
    final p = _progress.value;
    final changed = <String, double>{};
    final banner = <String>{};
    for (final a in achievementDefs) {
      final id = GameCenterIds.achievements[a.id];
      if (id == null) continue;
      final pct = p.achievements.containsKey(a.id)
          ? 100.0
          : (a.fractionIn(p) * 100).floorToDouble().clamp(0.0, 99.0);
      final prev = _reported[id];
      if (prev == pct) continue;
      // Game Center yüzdesi geriye gitmez; düşük değer gönderilmez
      if (prev != null && pct < prev) continue;
      changed[id] = pct;
      // bildirim yalnızca bu oturumda açılan başarımda
      if (pct == 100 && prev != null) banner.add(id);
    }
    if (changed.isEmpty) return;
    try {
      await api.reportAchievements(changed, banner: banner);
      _reported.addAll(changed);
    } on GameCenterException catch (e) {
      value = value.copyWith(lastError: e.code);
    } catch (e) {
      value = value.copyWith(lastError: 'failed');
    }
  }

  Future<GcBoardPage> loadBoard(GcBoard board, GcScope scope) =>
      api.loadEntries(board, scope);

  @override
  void dispose() {
    _sub?.cancel();
    if (_started && api.isSupported) {
      _progress.removeListener(_onProgress);
    }
    super.dispose();
  }
}
