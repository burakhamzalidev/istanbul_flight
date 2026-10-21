import 'package:flutter/foundation.dart';

import '../services/audio_service.dart';
import '../services/haptics_service.dart';
import '../services/progress.dart';
import '../services/settings.dart';
import '../services/share_service.dart';

/// Oyuncu ilerlemesinin canlı kaynağı (toplam simit vb.), değişince kaydedilir.
class ProgressController extends ValueNotifier<PlayerProgress> {
  ProgressController(this._repo, super.value);

  final ProgressRepository _repo;

  Future<void> addRun({required int simits}) async {
    if (simits <= 0) return;
    value = value.addRun(simits: simits);
    try {
      await _repo.save(value);
    } catch (e) {
      debugPrint('İlerleme kaydedilemedi: $e');
    }
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
}
