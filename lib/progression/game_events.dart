import '../challenge/daily_challenge.dart';

/// Oyun olayları: oyun (IstanbulFlightGame) bunları yayınlar, ilerleme sistemleri dinler.
///
/// Olay veriyolu ya da durum kütüphanesi yok: [GameServices.emit] olayı dinleyicilere
/// sırayla iletir. Uçuş sonu hesabı [RunFinished] içindeki özetle yapılır; diğer olaylar
/// canlı izleme ve testler içindir.
sealed class GameEvent {
  const GameEvent();
}

class RunStarted extends GameEvent {
  const RunStarted(this.runId, {this.mode = RunMode.classic, this.challengeId});
  final String runId;
  final RunMode mode;

  /// Günün Uçuşu'nda challenge kimliği (klasikte null).
  final String? challengeId;
}

/// Oyuncu uçuşu yarıda bıraktı (duraklatıp ana menüye döndü ya da yeniden başlattı). Uçuş hesabı
/// yapılmaz; Günün Uçuşu'nda dereceli hak harcanmış kalır.
class RunAbandoned extends GameEvent {
  const RunAbandoned(this.runId);
  final String runId;
}

class ObstaclePassed extends GameEvent {
  const ObstaclePassed(this.score);
  final int score;
}

class SimitCollected extends GameEvent {
  const SimitCollected(this.runTotal);
  final int runTotal;
}

class NearMissAchieved extends GameEvent {
  const NearMissAchieved(this.runTotal);
  final int runTotal;
}

class ZoneReached extends GameEvent {
  const ZoneReached(this.zoneIndex);
  final int zoneIndex;
}

class RunFinished extends GameEvent {
  const RunFinished(this.result);
  final RunResult result;
}

abstract interface class GameEventListener {
  void onGameEvent(GameEvent event);
}

/// Bir uçuşun özeti (oyunun ekranda gösterdiği sayaçlarla aynı kaynak).
class RunResult {
  const RunResult({
    required this.runId,
    required this.score,
    required this.obstaclesPassed,
    required this.simits,
    required this.nearMisses,
    required this.maxZone,
    required this.flightMs,
    this.zoneStats = const {},
    this.assisted = false,
    this.mode = RunMode.classic,
    this.challengeId,
  });

  /// Uçuşun benzersiz kimliği: aynı uçuş iki kez hesaplanmaz.
  final String runId;
  final int score;

  /// Gerçekten geçilen engel sayısı (demo modunun başlangıç skoru sayılmaz).
  final int obstaclesPassed;
  final int simits;
  final int nearMisses;

  /// Bu uçuşta ulaşılan en ileri bölge (0 = Haliç).
  final int maxZone;

  /// Simülasyon süresi (ms): kare hızından bağımsız, duraklatma sayılmaz.
  final int flightMs;

  /// Bölge sırası → o bölgede geçen engel / simit / kıl payı (Phase 2.3 keşif hedefleri).
  /// Toplamlar yukarıdaki sayaçlarla aynıdır; boş = bölge bazlı veri yok (ör. eski testler).
  final Map<int, ZoneRunStats> zoneStats;

  /// Geliştirme yardımı açıktı (otomatik pilot, çarpışmasızlık ya da başlangıç skoru): skor liderlik
  /// tablosuna gönderilmez (Phase 2.4). Normal derlemede hep false.
  final bool assisted;

  /// Oyun modu (Phase 2.5). Günlük uçuşlar klasik rekoru ve klasik Game Center tablolarını etkilemez.
  final RunMode mode;

  /// Günün Uçuşu challenge kimliği (`daily_2026_10_24`); klasikte null.
  final String? challengeId;
}

/// Bir uçuşun tek bölgedeki sayaçları.
class ZoneRunStats {
  const ZoneRunStats({
    this.obstacles = 0,
    this.simits = 0,
    this.nearMisses = 0,
  });

  final int obstacles;
  final int simits;
  final int nearMisses;

  ZoneRunStats add({int obstacles = 0, int simits = 0, int nearMisses = 0}) =>
      ZoneRunStats(
        obstacles: this.obstacles + obstacles,
        simits: this.simits + simits,
        nearMisses: this.nearMisses + nearMisses,
      );
}
