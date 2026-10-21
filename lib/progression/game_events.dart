/// Oyun olayları: oyun (IstanbulFlightGame) bunları yayınlar, ilerleme sistemleri dinler.
///
/// Olay veriyolu ya da durum kütüphanesi yok: [GameServices.emit] olayı dinleyicilere
/// sırayla iletir. Uçuş sonu hesabı [RunFinished] içindeki özetle yapılır; diğer olaylar
/// canlı izleme ve testler içindir.
sealed class GameEvent {
  const GameEvent();
}

class RunStarted extends GameEvent {
  const RunStarted(this.runId);
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
}
