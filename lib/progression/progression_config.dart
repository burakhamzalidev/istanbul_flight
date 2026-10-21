/// İlerleme sisteminin ayarlanabilir değerleri (Phase 2.1, docs/12_phase2_player_progression.md).
///
/// XP yalnızca oyuncu profiline yazılır; oyun fiziğini, hızı ya da geçitleri etkilemez.
abstract final class ProgressionConfig {
  // ---- Uçuş XP'si ----
  static const xpPerObstacle = 2;
  static const xpPerSimit = 3;
  static const xpPerNearMiss = 5;

  /// Bir bölgenin ilk keşfi (Haliç başlangıç bölgesi olduğu için sayılmaz).
  static const xpPerNewZone = 25;

  /// Tek uçuştan alınabilecek en fazla XP (görev ve başarım ödülleri hariç). Anormal bir tur
  /// (ör. test/demo modu) profili şişirmesin.
  static const maxRunXp = 2000;

  // ---- Seviye ----
  static const maxLevel = 50;

  /// Toplam XP üst sınırı (taşma koruması).
  static const maxTotalXp = 100000000;

  /// [level] → [level] + 1 için gereken XP: 60, 80, 100, ... (ilk seviyeler 1–2 uçuşta gelir).
  static int xpToNext(int level) => 40 + 20 * level;

  /// 1. seviyeden [level]'a ulaşmak için gereken toplam XP.
  static int xpToReach(int level) {
    var total = 0;
    for (var l = 1; l < level; l++) {
      total += xpToNext(l);
    }
    return total;
  }

  // ---- Kayıt ----
  /// İdempotent uçuş hesabı için hatırlanan son uçuş kimlikleri.
  static const settledRunMemory = 50;

  /// Tekrar ödül vermemek için hatırlanan "gün:görev" kayıtları (~3 hafta).
  static const rewardLedgerMemory = 60;
}

/// Toplam XP'den türetilen seviye bilgisi.
class LevelInfo {
  const LevelInfo({
    required this.level,
    required this.xpIntoLevel,
    required this.xpForNext,
  });

  /// Toplam XP → seviye. Seviye [ProgressionConfig.maxLevel]'da durur; fazla XP birikir.
  factory LevelInfo.fromXp(int totalXp) {
    var xp = totalXp.clamp(0, ProgressionConfig.maxTotalXp);
    var level = 1;
    while (level < ProgressionConfig.maxLevel) {
      final need = ProgressionConfig.xpToNext(level);
      if (xp < need) break;
      xp -= need;
      level++;
    }
    final isMax = level >= ProgressionConfig.maxLevel;
    return LevelInfo(
      level: level,
      xpIntoLevel: isMax ? 0 : xp,
      xpForNext: isMax ? 0 : ProgressionConfig.xpToNext(level),
    );
  }

  final int level;
  final int xpIntoLevel;

  /// Sonraki seviye için gereken toplam (en üst seviyede 0).
  final int xpForNext;

  bool get isMax => xpForNext == 0;
  int get xpRemaining => isMax ? 0 : xpForNext - xpIntoLevel;

  /// 0..1 (en üst seviyede 1).
  double get fraction => isMax ? 1 : xpIntoLevel / xpForNext;
}
