import 'package:flutter/foundation.dart';

import '../progression/game_events.dart';
import '../progression/run_settlement.dart';
import '../services/audio_service.dart';
import '../services/haptics_service.dart';
import '../services/progress.dart';
import '../services/settings.dart';
import '../services/share_service.dart';

/// Oyuncu ilerlemesinin canlı kaynağı (profil, XP, görevler, başarımlar); değişince kaydedilir.
///
/// Oyun olaylarını dinler: [RunFinished] gelince uçuşun hesabını bir kez yapar ([settleRun]).
class ProgressController extends ValueNotifier<PlayerProgress>
    implements GameEventListener {
  ProgressController(this._repo, super.value, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ProgressRepository _repo;
  final DateTime Function() _clock;

  /// Son uçuşun özeti (oyun sonu ekranı). Yeni uçuş başlayınca temizlenir.
  final lastRun = ValueNotifier<RunSummary?>(null);

  Future<void> _saving = Future.value();

  DateTime now() => _clock();

  @override
  void onGameEvent(GameEvent event) {
    switch (event) {
      case RunStarted():
        lastRun.value = null;
      case RunFinished(:final result):
        settle(result);
      case ObstaclePassed() ||
          SimitCollected() ||
          NearMissAchieved() ||
          ZoneReached():
        break; // uçuş içinde ilerleme gösterilmez (oyun akışı bölünmez)
    }
  }

  /// Uçuşu hesaplar ve kaydeder. Aynı uçuş ikinci kez gelirse hiçbir şey yapmaz (null).
  RunSummary? settle(RunResult result) {
    final s = settleRun(value, result, _clock());
    if (s == null) return null;
    value = s.progress;
    lastRun.value = s.summary;
    _persist();
    return s.summary;
  }

  /// Gün değiştiyse görevleri yeniler (açılışta ve görev ekranında çağrılır).
  void refreshDay() {
    final next = ensureDaily(value, _clock());
    if (identical(next, value)) return;
    value = next;
    _persist();
  }

  /// Kayıtlar sırayla yazılır (eski bir yazma yenisinin üstüne geçemez).
  void _persist() {
    final snapshot = value;
    _saving = _saving.then((_) async {
      try {
        await _repo.save(snapshot);
      } catch (e) {
        debugPrint('İlerleme kaydedilemedi: $e');
      }
    });
  }

  /// Bekleyen kayıtlar bitince tamamlanır (testler).
  Future<void> flush() => _saving;

  @override
  void dispose() {
    lastRun.dispose();
    super.dispose();
  }
}

/// Oyunun dış servisleri. Oyun mantığı bunları arayüzleri üzerinden kullanır;
/// testlerde sessiz/sahte sürümler verilir.
class GameServices {
  GameServices({
    required this.audio,
    required this.haptics,
    required this.settings,
    required this.progress,
    required this.share,
  });

  /// Testler ve servislerin kurulamadığı durum: ses ve titreşim yok, kayıt bellekte.
  factory GameServices.silent({GameSettings settings = const GameSettings()}) =>
      GameServices(
        audio: const SilentAudioService(),
        haptics: NoHaptics(),
        settings: SettingsController(
          InMemorySettingsRepository(settings),
          settings,
        ),
        progress: ProgressController(
          InMemoryProgressRepository(),
          const PlayerProgress(),
        ),
        share: PlatformShareService(),
      );

  final AudioService audio;
  final HapticsService haptics;
  final SettingsController settings;
  final ProgressController progress;
  final ShareService share;

  /// Ek dinleyiciler (testler, ileride analitik olmayan yerel sistemler).
  final List<GameEventListener> listeners = [];

  /// Oyun olayını ilerleme sistemine ve ek dinleyicilere iletir. Bir dinleyicideki hata
  /// oyunu durdurmaz.
  void emit(GameEvent event) {
    for (final l in [progress, ...listeners]) {
      try {
        l.onGameEvent(event);
      } catch (e, st) {
        debugPrint('Oyun olayı işlenemedi ($event): $e\n$st');
      }
    }
  }
}
