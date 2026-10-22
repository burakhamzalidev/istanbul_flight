import 'dart:math' as math;

import '../game/day_cycle.dart';
import '../services/progress.dart';
import 'achievements.dart';
import 'discovery.dart';
import 'game_events.dart';
import 'missions.dart';
import 'progression_config.dart';

/// Bir uçuşun oyuncuya kazandırdıkları (oyun sonu özeti).
class RunSummary {
  const RunSummary({
    required this.runId,
    required this.xpObstacles,
    required this.xpSimits,
    required this.xpNearMisses,
    required this.xpZones,
    required this.xpMissions,
    required this.xpAchievements,
    required this.runSimits,
    required this.bonusSimits,
    required this.levelBefore,
    required this.levelAfter,
    required this.newZones,
    required this.completedMissions,
    required this.unlockedAchievements,
    this.discovery = DiscoveryOutcome.none,
  });

  final String runId;
  final int xpObstacles;
  final int xpSimits;
  final int xpNearMisses;
  final int xpZones;
  final int xpMissions;
  final int xpAchievements;
  final int runSimits;
  final int bonusSimits;
  final int levelBefore;
  final int levelAfter;
  final List<int> newZones;
  final List<DailyMission> completedMissions;
  final List<AchievementDef> unlockedAchievements;

  /// Keşif albümü: yeni kartpostallar, tamamlanan bölge hedefleri, rozetler (simitleri [bonusSimits]'te).
  final DiscoveryOutcome discovery;

  /// Uçuşun kendi XP'si (üst sınır uygulanmış).
  int get xpRun => math.min(
    ProgressionConfig.maxRunXp,
    xpObstacles + xpSimits + xpNearMisses + xpZones,
  );
  int get xpTotal => xpRun + xpMissions + xpAchievements;
  int get simitsTotal => runSimits + bonusSimits;
  bool get leveledUp => levelAfter > levelBefore;
}

class Settlement {
  const Settlement(this.progress, this.summary);
  final PlayerProgress progress;
  final RunSummary summary;
}

int _addXp(int xp, int gain) =>
    math.min(ProgressionConfig.maxTotalXp, xp + math.max(0, gain));

int _nonNeg(int v) => math.max(0, v);

List<String> _remember(List<String> list, String item, int keep) {
  final next = [...list, item];
  return next.length > keep ? next.sublist(next.length - keep) : next;
}

/// Bugünün görevlerini hazırlar: kayıt yoksa ya da yerel gün değiştiyse yenisini üretir.
/// Gün aynıysa aynı nesneyi döndürür (gereksiz kayıt olmaz).
PlayerProgress ensureDaily(PlayerProgress p, DateTime now) {
  final day = dayKeyFor(now);
  if (p.daily?.dayKey == day) return p;
  return p.copyWith(daily: DailyMissions.generate(day, level: p.level));
}

/// Hedefe ulaşmış ama henüz açılmamış başarımları açar ve ödüllerini verir. Ödüller seviyeyi
/// değiştirebileceği için yeni açılış kalmayana kadar tekrarlanır.
(PlayerProgress, List<AchievementDef>) unlockAchievements(
  PlayerProgress p,
  DateTime now,
) {
  final unlocked = <AchievementDef>[];
  var changed = true;
  while (changed) {
    changed = false;
    for (final a in achievementDefs) {
      if (p.achievements.containsKey(a.id) || !a.reachedIn(p)) continue;
      p = p.copyWith(
        achievements: {...p.achievements, a.id: now},
        xp: _addXp(p.xp, a.rewardXp),
        bonusSimits: p.bonusSimits + a.rewardSimits,
      );
      unlocked.add(a);
      changed = true;
    }
  }
  return (p, unlocked);
}

/// Uçuşun hesabı: profil sayaçları, XP, bölge keşfi, günlük görevler ve başarımlar.
///
/// İdempotent: aynı [RunResult.runId] ikinci kez gelirse null döner, hiçbir şey değişmez.
/// Saf fonksiyondur (kayıt ve zaman dışarıdan): test edilebilir, yarıda kalırsa eski kayıt geçerlidir.
Settlement? settleRun(PlayerProgress p, RunResult r, DateTime now) {
  if (r.runId.isEmpty || p.settledRuns.contains(r.runId)) return null;
  final score = _nonNeg(r.score);
  final obstacles = _nonNeg(r.obstaclesPassed);
  final simits = _nonNeg(r.simits);
  final near = _nonNeg(r.nearMisses);
  final maxZone = r.maxZone.clamp(0, zones.length - 1);
  final levelBefore = p.level;

  // ---- Bölge keşfi (Haliç başlangıç: keşif XP'si yok) ----
  final newZones = [
    for (var z = 0; z <= maxZone; z++)
      if (!p.discoveredZones.contains(z)) z,
  ];
  final paidZones = newZones.where((z) => z > 0).length;

  final xpObstacles = obstacles * ProgressionConfig.xpPerObstacle;
  final xpSimits = simits * ProgressionConfig.xpPerSimit;
  final xpNear = near * ProgressionConfig.xpPerNearMiss;
  final xpZones = paidZones * ProgressionConfig.xpPerNewZone;
  final xpRun = math.min(
    ProgressionConfig.maxRunXp,
    xpObstacles + xpSimits + xpNear + xpZones,
  );

  p = p.copyWith(
    flights: p.flights + 1,
    totalScore: p.totalScore + score,
    totalObstacles: p.totalObstacles + obstacles,
    totalSimits: p.totalSimits + simits,
    bestRunSimits: math.max(p.bestRunSimits, simits),
    totalNearMisses: p.totalNearMisses + near,
    longestFlightMs: math.max(p.longestFlightMs, _nonNeg(r.flightMs)),
    discoveredZones: {...p.discoveredZones, ...newZones},
    xp: _addXp(p.xp, xpRun),
  );

  // ---- Keşif albümü (Phase 2.3): bölge keşfi yazıldıktan sonra; XP vermez, yalnızca simit ----
  final (afterDiscovery, discovery) = settleDiscovery(p, r, newZones, now);
  p = afterDiscovery;

  // ---- Günlük görevler ----
  p = ensureDaily(p, now);
  final daily = p.daily!;
  final completed = <DailyMission>[];
  var ledger = p.rewardedMissions;
  var xpMissions = 0, bonus = 0;
  final advanced = <DailyMission>[];
  for (final m in daily.missions) {
    final next = m.advance(r);
    advanced.add(next);
    final ledgerKey = '${daily.dayKey}:${m.id}';
    if (next.completed && !ledger.contains(ledgerKey)) {
      ledger = _remember(
        ledger,
        ledgerKey,
        ProgressionConfig.rewardLedgerMemory,
      );
      completed.add(next);
      xpMissions += next.rewardXp;
      bonus += next.rewardSimits;
    }
  }
  p = p.copyWith(
    daily: daily.withMissions(advanced),
    rewardedMissions: ledger,
    missionsCompleted: p.missionsCompleted + completed.length,
    xp: _addXp(p.xp, xpMissions),
    bonusSimits: p.bonusSimits + bonus,
  );

  // ---- Başarımlar ----
  final xpBeforeAch = p.xp, bonusBeforeAch = p.bonusSimits;
  final (afterAch, unlocked) = unlockAchievements(p, now);
  p = afterAch;

  p = p.copyWith(
    settledRuns: _remember(
      p.settledRuns,
      r.runId,
      ProgressionConfig.settledRunMemory,
    ),
  );

  return Settlement(
    p,
    RunSummary(
      runId: r.runId,
      xpObstacles: xpObstacles,
      xpSimits: xpSimits,
      xpNearMisses: xpNear,
      xpZones: xpZones,
      xpMissions: xpMissions,
      xpAchievements: p.xp - xpBeforeAch,
      runSimits: simits,
      bonusSimits: bonus + discovery.simits + (p.bonusSimits - bonusBeforeAch),
      levelBefore: levelBefore,
      levelAfter: p.level,
      newZones: newZones.where((z) => z > 0).toList(),
      completedMissions: completed,
      unlockedAchievements: unlocked,
      discovery: discovery,
    ),
  );
}
