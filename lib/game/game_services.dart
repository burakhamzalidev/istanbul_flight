import 'dart:async';

import 'package:flutter/foundation.dart';

import '../challenge/daily_challenge.dart';
import '../challenge/daily_service.dart';
import '../challenge/daily_state.dart';
import '../progression/cosmetics.dart';
import '../progression/game_events.dart';
import '../progression/run_settlement.dart';
import '../services/audio_service.dart';
import '../services/haptics_service.dart';
import '../services/game_center/game_center_controller.dart';
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

  /// Son günlük uçuşun özeti (Günün Uçuşu oyun sonu ekranı; klasik uçuşta null).
  final lastDaily = ValueNotifier<DailyRunOutcome?>(null);

  Future<void> _saving = Future.value();

  DateTime now() => _clock();

  @override
  void onGameEvent(GameEvent event) {
    switch (event) {
      case RunStarted():
        lastRun.value = null;
        lastDaily.value = null;
      case RunAbandoned(:final runId):
        _closeDaily(runId, DailyAttemptStatus.abandoned);
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
    final now = _clock();
    final s = settleRun(value, result, now);
    if (s == null) return null;
    // Günün Uçuşu: denemenin kapanışı, günlük rekor ve tek seferlik günlük ödüller (aynı kayıtta)
    final (progress, daily) = settleDailyRun(s.progress, result, now);
    value = progress;
    lastDaily.value = daily;
    lastRun.value = s.summary;
    _persist();
    return s.summary;
  }

  /// Dereceli günlük denemeyi başlatır; başladıysa hak harcanmıştır ve hemen kaydedilir.
  DailyBeginResult beginDailyAttempt(
    DailyChallengeDefinition def,
    String runId, {
    String? trustedDay,
  }) {
    final (next, result) = applyDailyBegin(
      value,
      def,
      runId,
      _clock(),
      trustedDay: trustedDay,
    );
    if (result == DailyBeginResult.started) {
      value = next;
      _persist();
    }
    return result;
  }

  /// Açılışta: önceki oturumda yarıda kalan günlük denemeler "kesildi" olarak kapanır.
  void recoverDaily() {
    final next = recoverInterruptedDaily(value, _clock());
    if (identical(next, value)) return;
    value = next;
    _persist();
  }

  void _closeDaily(String runId, DailyAttemptStatus to) {
    final next = closeDailyAttempt(value, runId, to, _clock());
    if (identical(next, value)) return;
    value = next;
    _persist();
  }

  /// Game Center gönderim durumunu günlük kayda yazar.
  void markDailyGc(String challengeId, DailyGcStatus status) {
    final next = applyDailyGcStatus(value, challengeId, status);
    if (identical(next, value)) return;
    value = next;
    _persist();
  }

  /// Gün değiştiyse görevleri yeniler (açılışta ve görev ekranında çağrılır).
  void refreshDay() {
    final next = ensureDaily(value, _clock());
    if (identical(next, value)) return;
    value = next;
    _persist();
  }

  final Set<String> _purchasing = {};

  /// Kozmetik satın alma: tek tutarlı işlem. Yeni durum önce diske yazılır, ancak yazma başarılıysa
  /// ekrana yansır; yazılamazsa hiçbir şey değişmez (simit düşülmez). Aynı ürün için eşzamanlı
  /// ikinci istek (çift dokunma) [PurchaseResult.busy] döner.
  Future<PurchaseResult> purchase(String id) async {
    if (!_purchasing.add(id)) return PurchaseResult.busy;
    try {
      final done = Completer<PurchaseResult>();
      _saving = _saving.then((_) async {
        // Sıradaki yazmalar bittikten sonra güncel profilden hesaplanır
        final (next, result) = purchaseCosmetic(value, id);
        if (result != PurchaseResult.purchased) return done.complete(result);
        try {
          await _repo.save(next);
        } catch (e) {
          debugPrint('Satın alma kaydedilemedi: $e');
          return done.complete(PurchaseResult.saveFailed);
        }
        value = next;
        done.complete(PurchaseResult.purchased);
      });
      return await done.future;
    } finally {
      _purchasing.remove(id);
    }
  }

  /// Görünüm seçimi; sahip olunmayan ya da bilinmeyen görünümde false. Seçim bir sonraki uçuşta geçerli.
  bool equip(String id) {
    final next = equipCosmetic(value, id);
    if (next == null) return false;
    if (!identical(next, value)) {
      value = next;
      _persist();
    }
    return true;
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
    lastDaily.dispose();
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
    GameCenterController? gameCenter,
    DailyChallengeService? daily,
  }) : gameCenter = gameCenter ?? GameCenterController.disabled(),
       daily = daily ?? DailyChallengeService(clock: progress.now) {
    // Günlük skorların Game Center durumu günlük kayda yazılır; Apple'ın günlük dönemi saat denetimine girer
    this.gameCenter.onDailyStatus = progress.markDailyGc;
    this.gameCenter.onDailyOccurrence = this.daily.setOccurrence;
  }

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

  /// Apple Game Center eşzamanlaması (Phase 2.4). İsteğe bağlı: yoksa devre dışı (Android, web, testler).
  final GameCenterController gameCenter;

  /// Günün Uçuşu: bugünün challenge tanımı, saat denetimi (Phase 2.5).
  final DailyChallengeService daily;

  /// Ek dinleyiciler (testler, ileride analitik olmayan yerel sistemler).
  final List<GameEventListener> listeners = [];

  /// Oyun olayını ilerleme sistemine ve ek dinleyicilere iletir. Bir dinleyicideki hata
  /// oyunu durdurmaz.
  void emit(GameEvent event) {
    // Sıra önemli: önce ilerleme hesabı (başarımlar), sonra Game Center yansıması
    for (final l in <GameEventListener>[progress, gameCenter, ...listeners]) {
      try {
        l.onGameEvent(event);
      } catch (e, st) {
        debugPrint('Oyun olayı işlenemedi ($event): $e\n$st');
      }
    }
  }
}
