import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/day_cycle.dart';
import '../progression/missions.dart';
import '../progression/progression_config.dart';

/// Oyuncunun kalıcı ilerlemesi.
///
/// Sürüm 1 (`progress_v1`, TestFlight 1.0.0): toplanan simitler ve kozmetik yer tutucuları.
/// Sürüm 2 (`progress_v2`, Phase 2.1): profil sayaçları, XP, günlük görevler, başarımlar ve
/// idempotent uçuş hesabı. Rekor ayrı anahtarda kalır (`best_score_v1`) ve burada tekrar saklanmaz.
@immutable
class PlayerProgress {
  const PlayerProgress({
    this.totalSimits = 0,
    this.bestRunSimits = 0,
    this.unlockedCosmetics = const {'classic'},
    this.selectedCosmetic = 'classic',
    this.xp = 0,
    this.flights = 0,
    this.totalScore = 0,
    this.totalObstacles = 0,
    this.totalNearMisses = 0,
    this.bonusSimits = 0,
    this.spentSimits = 0,
    this.discoveredZones = const {},
    this.longestFlightMs = 0,
    this.missionsCompleted = 0,
    this.daily,
    this.rewardedMissions = const [],
    this.achievements = const {},
    this.settledRuns = const [],
  });

  static const version = 2;

  /// Uçuşlarda toplanan simit (tüm zamanlar). Ödül simitleri [bonusSimits]'te ayrı tutulur.
  final int totalSimits;
  final int bestRunSimits;

  /// Açılmış görünüm kimlikleri (ör. 'classic', ileride 'kaptan_sapkasi'). Mağaza Phase 2.2'de.
  final Set<String> unlockedCosmetics;
  final String selectedCosmetic;

  /// Toplam XP (seviye bundan türetilir: [levelInfo]).
  final int xp;

  /// Tamamlanan (çarpışmayla biten) uçuş sayısı.
  final int flights;
  final int totalScore;
  final int totalObstacles;
  final int totalNearMisses;

  /// Görev ve başarım ödülü olarak kazanılan simit.
  final int bonusSimits;

  /// Harcanan simit (Phase 2.2 mağazası için; şu an hep 0).
  final int spentSimits;

  /// Ulaşılmış bölge sıraları (0 Haliç ... 4 Rumeli Hisarı).
  final Set<int> discoveredZones;
  final int longestFlightMs;
  final int missionsCompleted;

  /// Bugünün görevleri (ilk açılışta ya da gün değişince üretilir).
  final DailyMissions? daily;

  /// Ödülü verilmiş görevler: "gün:görev". Cihaz tarihi geri alınsa da aynı ödül iki kez verilmez.
  final List<String> rewardedMissions;

  /// Açılan başarımlar: kimlik → açılma zamanı.
  final Map<String, DateTime> achievements;

  /// Hesabı yapılmış son uçuş kimlikleri (aynı uçuş iki kez sayılmaz).
  final List<String> settledRuns;

  LevelInfo get levelInfo => LevelInfo.fromXp(xp);
  int get level => levelInfo.level;

  /// Harcanabilir simit. Hiçbir durumda negatif olmaz.
  int get simitBalance => math.max(0, totalSimits + bonusSimits - spentSimits);

  /// Ulaşılan en ileri bölge (hiç uçulmadıysa 0).
  int get maxZone =>
      discoveredZones.isEmpty ? 0 : discoveredZones.reduce(math.max);

  /// Eski API (1.0.0): sadece simit sayaçları. Uçuş hesabı artık `settleRun` ile yapılır.
  PlayerProgress addRun({required int simits}) => copyWith(
    totalSimits: totalSimits + simits,
    bestRunSimits: simits > bestRunSimits ? simits : bestRunSimits,
  );

  /// Simit harcar; bakiye yetmezse null döner (bakiye negatife düşmez).
  PlayerProgress? trySpend(int amount) {
    if (amount < 0 || amount > simitBalance) return null;
    return copyWith(spentSimits: spentSimits + amount);
  }

  PlayerProgress copyWith({
    int? totalSimits,
    int? bestRunSimits,
    Set<String>? unlockedCosmetics,
    String? selectedCosmetic,
    int? xp,
    int? flights,
    int? totalScore,
    int? totalObstacles,
    int? totalNearMisses,
    int? bonusSimits,
    int? spentSimits,
    Set<int>? discoveredZones,
    int? longestFlightMs,
    int? missionsCompleted,
    DailyMissions? daily,
    List<String>? rewardedMissions,
    Map<String, DateTime>? achievements,
    List<String>? settledRuns,
  }) => PlayerProgress(
    totalSimits: totalSimits ?? this.totalSimits,
    bestRunSimits: bestRunSimits ?? this.bestRunSimits,
    unlockedCosmetics: unlockedCosmetics ?? this.unlockedCosmetics,
    selectedCosmetic: selectedCosmetic ?? this.selectedCosmetic,
    xp: xp ?? this.xp,
    flights: flights ?? this.flights,
    totalScore: totalScore ?? this.totalScore,
    totalObstacles: totalObstacles ?? this.totalObstacles,
    totalNearMisses: totalNearMisses ?? this.totalNearMisses,
    bonusSimits: bonusSimits ?? this.bonusSimits,
    spentSimits: spentSimits ?? this.spentSimits,
    discoveredZones: discoveredZones ?? this.discoveredZones,
    longestFlightMs: longestFlightMs ?? this.longestFlightMs,
    missionsCompleted: missionsCompleted ?? this.missionsCompleted,
    daily: daily ?? this.daily,
    rewardedMissions: rewardedMissions ?? this.rewardedMissions,
    achievements: achievements ?? this.achievements,
    settledRuns: settledRuns ?? this.settledRuns,
  );

  Map<String, Object> toJson() => {
    'v': version,
    'totalSimits': totalSimits,
    'bestRunSimits': bestRunSimits,
    'unlockedCosmetics': unlockedCosmetics.toList()..sort(),
    'selectedCosmetic': selectedCosmetic,
    'xp': xp,
    'flights': flights,
    'totalScore': totalScore,
    'totalObstacles': totalObstacles,
    'totalNearMisses': totalNearMisses,
    'bonusSimits': bonusSimits,
    'spentSimits': spentSimits,
    'discoveredZones': discoveredZones.toList()..sort(),
    'longestFlightMs': longestFlightMs,
    'missionsCompleted': missionsCompleted,
    'daily': ?daily?.toJson(),
    'rewardedMissions': rewardedMissions,
    'achievements': {
      for (final e in achievements.entries)
        e.key: e.value.toUtc().toIso8601String(),
    },
    'settledRuns': settledRuns,
  };

  /// Sürüm 1 ve 2 kayıtlarını okur. Eksik, yanlış türde ya da negatif alanlar varsayılana düşer;
  /// bozuk bir alan diğerlerini etkilemez.
  factory PlayerProgress.fromJson(Map<String, Object?> j) {
    int count(Object? v) =>
        v is int && v >= 0 ? math.min(v, ProgressionConfig.maxTotalXp) : 0;
    List<String> strings(Object? v) =>
        v is List ? v.whereType<String>().toList() : const [];
    final unlocked = j['unlockedCosmetics'];
    final set = unlocked is List
        ? unlocked.whereType<String>().toSet()
        : <String>{};
    set.add('classic');
    final selected = j['selectedCosmetic'];
    final zonesRaw = j['discoveredZones'];
    final ach = j['achievements'];
    return PlayerProgress(
      totalSimits: count(j['totalSimits']),
      bestRunSimits: count(j['bestRunSimits']),
      unlockedCosmetics: set,
      selectedCosmetic: selected is String && set.contains(selected)
          ? selected
          : 'classic',
      xp: count(j['xp']),
      flights: count(j['flights']),
      totalScore: count(j['totalScore']),
      totalObstacles: count(j['totalObstacles']),
      totalNearMisses: count(j['totalNearMisses']),
      bonusSimits: count(j['bonusSimits']),
      spentSimits: count(j['spentSimits']),
      discoveredZones: zonesRaw is List
          ? zonesRaw
                .whereType<int>()
                .where((z) => z >= 0 && z < zones.length)
                .toSet()
          : const {},
      longestFlightMs: count(j['longestFlightMs']),
      missionsCompleted: count(j['missionsCompleted']),
      daily: DailyMissions.fromJson(j['daily']),
      rewardedMissions: strings(j['rewardedMissions']),
      achievements: ach is Map
          ? {
              for (final e in ach.entries)
                if (e.key is String && e.value is String)
                  e.key as String: ?DateTime.tryParse(e.value as String),
            }
          : const {},
      settledRuns: strings(j['settledRuns']),
    );
  }

  /// Sürüm 1 → 2 geçişi. 1.0.0'da uçuş sayısı ve skor toplamı tutulmuyordu; bunlar 0'dan başlar.
  /// Rekordan (`best_score_v1`) geçilmiş bölgeler türetilir ve ilk keşif XP'si verilir: TestFlight
  /// oyuncuları zaten gördükleri bölgeler için geride kalmaz.
  factory PlayerProgress.migrateFromV1(PlayerProgress v1, {required int best}) {
    final reached = best > 0 || v1.totalSimits > 0
        ? zoneIndexForScore(best)
        : -1;
    final discovered = {for (var z = 0; z <= reached; z++) z};
    return v1.copyWith(
      discoveredZones: discovered,
      xp: math.max(0, reached) * ProgressionConfig.xpPerNewZone,
    );
  }
}

abstract class ProgressRepository {
  Future<PlayerProgress> load();
  Future<void> save(PlayerProgress p);
}

class SharedPrefsProgressRepository implements ProgressRepository {
  SharedPrefsProgressRepository(this._prefs);

  static const key = 'progress_v2';

  /// 1.0.0 kaydı: okunur, hiç değiştirilmez ve silinmez (eski sürüme dönüşte de durur).
  static const legacyKey = 'progress_v1';

  /// Okunamayan v2 kaydının ham kopyası (veri asla sessizce silinmez).
  static const corruptBackupKey = 'progress_v2_corrupt';
  static const bestScoreKey = 'best_score_v1';

  final SharedPreferences _prefs;

  @override
  Future<PlayerProgress> load() async {
    final raw = _prefs.getString(key);
    if (raw != null) {
      final p = _decode(raw);
      if (p != null) return p;
      debugPrint(
        'İlerleme (v2) okunamadı; yedeklenip eski kayıttan kuruluyor.',
      );
      await _try(() => _prefs.setString(corruptBackupKey, raw));
    }
    final legacyRaw = _prefs.getString(legacyKey);
    final legacy = legacyRaw == null
        ? const PlayerProgress()
        : _decode(legacyRaw) ?? const PlayerProgress();
    final best = _prefs.getInt(bestScoreKey) ?? 0;
    final migrated = PlayerProgress.migrateFromV1(legacy, best: best);
    if (legacyRaw != null || best > 0) await _try(() => save(migrated));
    return migrated;
  }

  PlayerProgress? _decode(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is Map<String, Object?>) return PlayerProgress.fromJson(j);
    } catch (e) {
      debugPrint('İlerleme kaydı çözümlenemedi: $e');
    }
    return null;
  }

  Future<void> _try(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      debugPrint('İlerleme kaydedilemedi: $e');
    }
  }

  /// Tek anahtar, tek yazma: kayıt sırasında uygulama kapanırsa ya eski ya yeni kayıt kalır.
  @override
  Future<void> save(PlayerProgress p) =>
      _prefs.setString(key, jsonEncode(p.toJson()));
}

class InMemoryProgressRepository implements ProgressRepository {
  InMemoryProgressRepository([this._p = const PlayerProgress()]);

  PlayerProgress _p;
  int saveCount = 0;

  @override
  Future<PlayerProgress> load() async => _p;

  @override
  Future<void> save(PlayerProgress p) async {
    _p = p;
    saveCount++;
  }
}
