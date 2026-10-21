import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Oyuncunun kalıcı ilerlemesi (`progress_v1`).
///
/// Bu aşamada sadece toplanan simitler sayılır. Kozmetik alanları gelecekteki görünüm
/// açma sistemi için yer tutucudur; mağaza veya ekonomi kurulmadı.
@immutable
class PlayerProgress {
  const PlayerProgress({
    this.totalSimits = 0,
    this.bestRunSimits = 0,
    this.unlockedCosmetics = const {'classic'},
    this.selectedCosmetic = 'classic',
  });

  /// Tüm zamanlarda toplanan simit (gelecekte kozmetik açmak için harcanabilir).
  final int totalSimits;
  final int bestRunSimits;

  /// Açılmış görünüm kimlikleri (ör. 'classic', ileride 'kaptan_sapkasi').
  final Set<String> unlockedCosmetics;
  final String selectedCosmetic;

  PlayerProgress addRun({required int simits}) => PlayerProgress(
    totalSimits: totalSimits + simits,
    bestRunSimits: simits > bestRunSimits ? simits : bestRunSimits,
    unlockedCosmetics: unlockedCosmetics,
    selectedCosmetic: selectedCosmetic,
  );

  Map<String, Object> toJson() => {
    'v': 1,
    'totalSimits': totalSimits,
    'bestRunSimits': bestRunSimits,
    'unlockedCosmetics': unlockedCosmetics.toList()..sort(),
    'selectedCosmetic': selectedCosmetic,
  };

  factory PlayerProgress.fromJson(Map<String, Object?> j) {
    int count(Object? v) => v is int && v >= 0 ? v : 0;
    final unlocked = j['unlockedCosmetics'];
    final set = unlocked is List
        ? unlocked.whereType<String>().toSet()
        : <String>{};
    set.add('classic');
    final selected = j['selectedCosmetic'];
    return PlayerProgress(
      totalSimits: count(j['totalSimits']),
      bestRunSimits: count(j['bestRunSimits']),
      unlockedCosmetics: set,
      selectedCosmetic: selected is String && set.contains(selected)
          ? selected
          : 'classic',
    );
  }
}

abstract class ProgressRepository {
  Future<PlayerProgress> load();
  Future<void> save(PlayerProgress p);
}

class SharedPrefsProgressRepository implements ProgressRepository {
  SharedPrefsProgressRepository(this._prefs);

  static const key = 'progress_v1';
  final SharedPreferences _prefs;

  @override
  Future<PlayerProgress> load() async {
    final raw = _prefs.getString(key);
    if (raw == null) return const PlayerProgress();
    try {
      final j = jsonDecode(raw);
      if (j is Map<String, Object?>) return PlayerProgress.fromJson(j);
    } catch (e) {
      debugPrint('İlerleme okunamadı, sıfırdan başlanıyor: $e');
    }
    return const PlayerProgress();
  }

  @override
  Future<void> save(PlayerProgress p) =>
      _prefs.setString(key, jsonEncode(p.toJson()));
}

class InMemoryProgressRepository implements ProgressRepository {
  InMemoryProgressRepository([this._p = const PlayerProgress()]);

  PlayerProgress _p;

  @override
  Future<PlayerProgress> load() async => _p;

  @override
  Future<void> save(PlayerProgress p) async => _p = p;
}
