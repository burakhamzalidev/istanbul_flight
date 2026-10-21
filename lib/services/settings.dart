import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcı ayarları. Kalıcı olarak saklanır (JSON, `settings_v1`).
/// En iyi skor ayrı bir anahtarda kalır (`best_score_v1`), bu dosya ona dokunmaz.
@immutable
class GameSettings {
  const GameSettings({
    this.musicVolume = 0.7,
    this.sfxVolume = 0.9,
    this.muted = false,
    this.haptics = true,
    this.reduceMotion = false,
  });

  /// 0..1
  final double musicVolume;

  /// 0..1 (oyun ve ortam sesleri)
  final double sfxVolume;

  /// Hızlı "sessiz" anahtarı (menüdeki hoparlör). Ses düzeylerini bozmadan susturur.
  final bool muted;
  final bool haptics;

  /// Ekran sarsıntısı, flaş, konfeti ve büyük ölçek animasyonlarını kapatır.
  final bool reduceMotion;

  double get effectiveMusic => muted ? 0 : musicVolume;
  double get effectiveSfx => muted ? 0 : sfxVolume;

  GameSettings copyWith({
    double? musicVolume,
    double? sfxVolume,
    bool? muted,
    bool? haptics,
    bool? reduceMotion,
  }) => GameSettings(
    musicVolume: musicVolume ?? this.musicVolume,
    sfxVolume: sfxVolume ?? this.sfxVolume,
    muted: muted ?? this.muted,
    haptics: haptics ?? this.haptics,
    reduceMotion: reduceMotion ?? this.reduceMotion,
  );

  Map<String, Object> toJson() => {
    'v': 1,
    'musicVolume': musicVolume,
    'sfxVolume': sfxVolume,
    'muted': muted,
    'haptics': haptics,
    'reduceMotion': reduceMotion,
  };

  /// Bozuk ya da eksik alanlar varsayılana düşer; değerler sınırlanır.
  factory GameSettings.fromJson(Map<String, Object?> j) {
    const d = GameSettings();
    double vol(Object? v, double def) =>
        v is num ? v.toDouble().clamp(0.0, 1.0) : def;
    bool flag(Object? v, bool def) => v is bool ? v : def;
    return GameSettings(
      musicVolume: vol(j['musicVolume'], d.musicVolume),
      sfxVolume: vol(j['sfxVolume'], d.sfxVolume),
      muted: flag(j['muted'], d.muted),
      haptics: flag(j['haptics'], d.haptics),
      reduceMotion: flag(j['reduceMotion'], d.reduceMotion),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameSettings &&
      other.musicVolume == musicVolume &&
      other.sfxVolume == sfxVolume &&
      other.muted == muted &&
      other.haptics == haptics &&
      other.reduceMotion == reduceMotion;

  @override
  int get hashCode =>
      Object.hash(musicVolume, sfxVolume, muted, haptics, reduceMotion);
}

abstract class SettingsRepository {
  Future<GameSettings> load();
  Future<void> save(GameSettings s);
}

class SharedPrefsSettingsRepository implements SettingsRepository {
  SharedPrefsSettingsRepository(this._prefs);

  static const key = 'settings_v1';
  final SharedPreferences _prefs;

  @override
  Future<GameSettings> load() async {
    final raw = _prefs.getString(key);
    if (raw == null) return const GameSettings();
    try {
      final j = jsonDecode(raw);
      if (j is Map<String, Object?>) return GameSettings.fromJson(j);
    } catch (e) {
      debugPrint('Ayarlar okunamadı, varsayılanlar kullanılıyor: $e');
    }
    return const GameSettings();
  }

  @override
  Future<void> save(GameSettings s) =>
      _prefs.setString(key, jsonEncode(s.toJson()));
}

class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository([this._s = const GameSettings()]);

  GameSettings _s;
  int saveCount = 0;

  @override
  Future<GameSettings> load() async => _s;

  @override
  Future<void> save(GameSettings s) async {
    _s = s;
    saveCount++;
  }
}

/// Ayarların canlı kaynağı: değişince hemen uygulanır, arka planda kaydedilir.
class SettingsController extends ValueNotifier<GameSettings> {
  SettingsController(this._repo, super.value);

  final SettingsRepository _repo;

  void update(GameSettings Function(GameSettings) change) {
    final next = change(value);
    if (next == value) return;
    value = next;
    _repo
        .save(next)
        .catchError((Object e) => debugPrint('Ayarlar kaydedilemedi: $e'));
  }
}
