import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Phase 2.4: Apple Game Center adaptörü (docs/16_phase2_4_game_center.md).
//
// Oyun yalnızca [GameCenterApi] arayüzünü bilir. iOS'ta [MethodChannelGameCenterApi] (ios/Runner/
// AppDelegate.swift, GameKit), diğer platformlarda ve testlerde [UnavailableGameCenterApi] ya da sahte
// uygulama kullanılır. Game Center hiçbir zaman oynamak için zorunlu değildir.

/// App Store Connect'teki Game Center kimlikleri. Kimlikler Apple tarafında oluşturulup doğrulanana kadar
/// GameKit bunları tanımaz (`not_configured`); oyun bundan etkilenmez.
abstract final class GameCenterIds {
  /// Klasik tablo: tüm zamanların en iyi skoru ("High Score", en iyi skor tutulur).
  static const bestScore = 'istanbul_flight_best_score';

  /// Tekrarlayan tablo: haftalık (7 gün süre, 7 gün yeniden başlama). Dönem Apple sunucusunda belirlenir.
  static const weeklyScore = 'istanbul_flight_weekly_score';

  /// Yerel başarım kimliği → Game Center başarım kimliği. Yerel sistem esas kaynaktır.
  static const achievements = <String, String>{
    'first_flap': 'istanbul_flight_first_flap',
    'galata_explorer': 'istanbul_flight_galata_explorer',
    'simit_hunter': 'istanbul_flight_simit_hunter',
    'loyal_gull': 'istanbul_flight_loyal_gull',
    'bosphorus_traveler': 'istanbul_flight_bosphorus_traveler',
    'near_miss_master': 'istanbul_flight_near_miss_master',
    'daily_wanderer': 'istanbul_flight_daily_wanderer',
    'night_flight': 'istanbul_flight_night_flight',
    'istanbul_conqueror': 'istanbul_flight_istanbul_conqueror',
  };
}

enum GcBoard {
  allTime(GameCenterIds.bestScore, recurring: false),
  weekly(GameCenterIds.weeklyScore, recurring: true);

  const GcBoard(this.id, {required this.recurring});
  final String id;
  final bool recurring;
}

enum GcScope { global, friends }

/// GameKit'ten gelen oturum durumu (oyuncu kimliği içermez).
@immutable
class GcAuthStatus {
  const GcAuthStatus({
    required this.authenticated,
    this.alias,
    this.underage = false,
    this.restricted = false,
    this.error,
  });

  static const signedOut = GcAuthStatus(authenticated: false);

  final bool authenticated;

  /// Görünen ad: yalnızca ekranda gösterilir, saklanmaz.
  final String? alias;
  final bool underage;
  final bool restricted;

  /// Son kimlik doğrulama hatası kodu (`cancelled`, `network`, `not_configured` ...).
  final String? error;

  factory GcAuthStatus.fromMap(Object? raw) {
    if (raw is! Map) return signedOut;
    return GcAuthStatus(
      authenticated: raw['authenticated'] == true,
      alias: raw['alias'] is String ? raw['alias'] as String : null,
      underage: raw['underage'] == true,
      restricted: raw['restricted'] == true,
      error: raw['error'] is String ? raw['error'] as String : null,
    );
  }
}

/// Sıralama satırı (yalnızca ekranda).
@immutable
class GcEntry {
  const GcEntry({
    required this.rank,
    required this.alias,
    required this.score,
    this.isLocal = false,
  });

  final int rank;
  final String alias;
  final int score;
  final bool isLocal;

  static GcEntry? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final rank = raw['rank'], score = raw['score'];
    if (rank is! int || score is! int) return null;
    return GcEntry(
      rank: rank,
      alias: raw['alias'] is String ? raw['alias'] as String : '?',
      score: score,
      isLocal: raw['isLocal'] == true,
    );
  }
}

@immutable
class GcBoardPage {
  const GcBoardPage({
    this.entries = const [],
    this.local,
    this.total = 0,
    this.occurrenceEnd,
  });

  final List<GcEntry> entries;
  final GcEntry? local;
  final int total;

  /// Haftalık tablonun bu döneminin bitişi (Apple sunucusundan).
  final DateTime? occurrenceEnd;

  factory GcBoardPage.fromMap(Object? raw) {
    if (raw is! Map) return const GcBoardPage();
    final list = raw['entries'];
    final end = raw['occurrenceEndMs'];
    return GcBoardPage(
      entries: list is List
          ? list.map(GcEntry.fromMap).whereType<GcEntry>().toList()
          : const [],
      local: GcEntry.fromMap(raw['local']),
      total: raw['total'] is int ? raw['total'] as int : 0,
      occurrenceEnd: end is num
          ? DateTime.fromMillisecondsSinceEpoch(end.round())
          : null,
    );
  }
}

/// GameKit hatası: [code] tekrar deneme kararını verir.
class GameCenterException implements Exception {
  const GameCenterException(this.code, [this.message]);

  final String code;
  final String? message;

  /// Ağ hatası: skor kuyrukta kalır, sonra tekrar denenir.
  bool get retryable => code == 'network' || code == 'failed';

  @override
  String toString() =>
      'GameCenterException($code${message == null ? '' : ': $message'})';
}

/// Test edilebilir Game Center adaptörü.
abstract class GameCenterApi {
  /// Bu platformda Game Center var mı (iOS).
  bool get isSupported;

  /// Oturum değişiklikleri (oyuncu Ayarlar'dan girip çıkınca GameKit bildirir).
  Stream<GcAuthStatus> get statusChanges;

  Future<GcAuthStatus> authenticate();

  /// Klasik tabloya ya da tekrarlayan tablonun açık dönemine skor gönderir. Hata: [GameCenterException].
  Future<void> submitScore(GcBoard board, int score, {DateTime? achievedAt});

  /// Başarım yüzdeleri (0..100); [banner] ilk tamamlanışta Apple bildirimini gösterir.
  Future<void> reportAchievements(
    Map<String, double> percents, {
    Set<String> banner = const {},
  });

  Future<GcBoardPage> loadEntries(GcBoard board, GcScope scope, {int limit});

  Future<void> showLeaderboard(GcBoard board, GcScope scope);
  Future<void> showAchievements();
}

/// iOS: ios/Runner/AppDelegate.swift → GameCenterPlugin.
class MethodChannelGameCenterApi implements GameCenterApi {
  MethodChannelGameCenterApi({MethodChannel? channel, bool? supported})
    : _channel = channel ?? const MethodChannel('istanbul_flight/game_center'),
      isSupported =
          supported ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'statusChanged') {
        _status.add(GcAuthStatus.fromMap(call.arguments));
      }
    });
  }

  final MethodChannel _channel;
  final _status = StreamController<GcAuthStatus>.broadcast();

  @override
  final bool isSupported;

  @override
  Stream<GcAuthStatus> get statusChanges => _status.stream;

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw GameCenterException(e.code, e.message);
    } on MissingPluginException {
      throw const GameCenterException('unavailable');
    }
  }

  @override
  Future<GcAuthStatus> authenticate() async =>
      GcAuthStatus.fromMap(await _call<Object?>('authenticate'));

  @override
  Future<void> submitScore(GcBoard board, int score, {DateTime? achievedAt}) =>
      _call<void>('submitScore', {
        'leaderboardId': board.id,
        'score': score,
        'recurring': board.recurring,
        if (achievedAt != null)
          'achievedAtMs': achievedAt.millisecondsSinceEpoch.toDouble(),
      });

  @override
  Future<void> reportAchievements(
    Map<String, double> percents, {
    Set<String> banner = const {},
  }) => _call<void>('reportAchievements', {
    'items': [
      for (final e in percents.entries)
        {'id': e.key, 'percent': e.value, 'banner': banner.contains(e.key)},
    ],
  });

  @override
  Future<GcBoardPage> loadEntries(
    GcBoard board,
    GcScope scope, {
    int limit = 25,
  }) async => GcBoardPage.fromMap(
    await _call<Object?>('loadEntries', {
      'leaderboardId': board.id,
      'scope': scope.name,
      'limit': limit,
    }),
  );

  @override
  Future<void> showLeaderboard(GcBoard board, GcScope scope) => _call<void>(
    'showLeaderboard',
    {'leaderboardId': board.id, 'scope': scope.name},
  );

  @override
  Future<void> showAchievements() => _call<void>('showAchievements');
}

/// Game Center olmayan platformlar (Android, web) ve testler.
class UnavailableGameCenterApi implements GameCenterApi {
  const UnavailableGameCenterApi();

  @override
  bool get isSupported => false;

  @override
  Stream<GcAuthStatus> get statusChanges => const Stream.empty();

  static const _no = GameCenterException('unavailable');

  @override
  Future<GcAuthStatus> authenticate() async => GcAuthStatus.signedOut;

  @override
  Future<void> submitScore(GcBoard board, int score, {DateTime? achievedAt}) =>
      Future.error(_no);

  @override
  Future<void> reportAchievements(
    Map<String, double> percents, {
    Set<String> banner = const {},
  }) => Future.error(_no);

  @override
  Future<GcBoardPage> loadEntries(
    GcBoard board,
    GcScope scope, {
    int limit = 25,
  }) => Future.error(_no);

  @override
  Future<void> showLeaderboard(GcBoard board, GcScope scope) =>
      Future.error(_no);

  @override
  Future<void> showAchievements() => Future.error(_no);
}
