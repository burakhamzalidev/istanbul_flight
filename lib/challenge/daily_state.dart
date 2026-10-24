import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../progression/game_events.dart';
import '../progression/progression_config.dart';
import '../services/progress.dart';
import 'daily_challenge.dart';

// Phase 2.5: Günün Uçuşu kaydı ve kuralları (docs/17 §5–§9, §12).
//
// Kayıt PlayerProgress içinde tutulur (`dailyChallenge` alanı): günlük ödüller (XP, simit) ile deneme
// kaydı aynı tek yazmada diske gider; yarıda kalan yazmada ya ikisi birden ya hiçbiri olur. Buradaki
// fonksiyonlar saftır (zaman ve kimlik dışarıdan): test edilebilir ve idempotenttir.

abstract final class DailyRules {
  /// Günlük dereceli deneme hakkı.
  static const rankedAttempts = 3;

  /// Saklanan challenge kaydı (gün). Daha eskiler silinir; ödüller zaten profile işlenmiştir.
  static const keepRecords = 30;
}

enum DailyAttemptStatus {
  /// Uçuş başladı; hak harcandı. Uygulama bu durumda kapanırsa açılışta [interrupted] olur.
  started,
  finished,

  /// Oyuncu uçuşu yarıda bıraktı (duraklatıp ana menüye döndü). Skor sayılmaz.
  abandoned,

  /// Uygulama uçuş sırasında kapandı. Hak geri verilmez (kapatıp yeniden deneme açığı yok).
  interrupted,
}

@immutable
class DailyAttempt {
  const DailyAttempt({
    required this.runId,
    required this.status,
    this.score = 0,
    this.startedAt,
  });

  final String runId;
  final DailyAttemptStatus status;
  final int score;
  final DateTime? startedAt;

  DailyAttempt copyWith({DailyAttemptStatus? status, int? score}) =>
      DailyAttempt(
        runId: runId,
        status: status ?? this.status,
        score: score ?? this.score,
        startedAt: startedAt,
      );

  Map<String, Object> toJson() => {
    'runId': runId,
    'status': status.name,
    'score': score,
    'startedAt': ?startedAt?.toUtc().toIso8601String(),
  };

  static DailyAttempt? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['runId'];
    if (id is! String || id.isEmpty) return null;
    final status = DailyAttemptStatus.values.asNameMap()[j['status']];
    final score = j['score'];
    final at = j['startedAt'];
    return DailyAttempt(
      runId: id,
      // bilinmeyen durum: harcanmış sayılır (hak geri verilmez)
      status: status ?? DailyAttemptStatus.interrupted,
      score: score is int ? score.clamp(0, 99999) : 0,
      startedAt: at is String ? DateTime.tryParse(at) : null,
    );
  }
}

/// Günlük skorun Game Center durumu.
enum DailyGcStatus {
  /// Henüz dereceli skor yok ya da Game Center'a gönderilecek bir şey yok.
  none,

  /// Gönderilmeyi bekliyor (bağlantı yok / oturum kapalı).
  pending,
  submitted,

  /// Günün tablosu kapandı (ya da tarih Apple'ın dönemiyle eşleşmedi); gönderilmedi.
  expired,

  /// Uygun değil (geliştirme yardımı, tutarsız skor ya da cihaz saati sorunu).
  notEligible,
}

@immutable
class DailyChallengeRecord {
  const DailyChallengeRecord({
    required this.challengeId,
    required this.seed,
    required this.generatorVersion,
    this.attempts = const [],
    this.bestScore = 0,
    this.bestRunId,
    this.completedAt,
    this.claimed = const {},
    this.gcStatus = DailyGcStatus.none,
  });

  factory DailyChallengeRecord.forDefinition(DailyChallengeDefinition d) =>
      DailyChallengeRecord(
        challengeId: d.challengeId,
        seed: d.seed,
        generatorVersion: d.generatorVersion,
      );

  final String challengeId;

  /// İlk dereceli denemede kullanılan tohum ve üretici (sonradan değişmez; tanılama ve denetim için).
  final int seed;
  final int generatorVersion;
  final List<DailyAttempt> attempts;
  final int bestScore;
  final String? bestRunId;

  /// Son dereceli hak kullanılıp uçuş bittiğinde.
  final DateTime? completedAt;

  /// Alınmış tek seferlik ödüller ([DailyRewardPolicy] anahtarları).
  final Set<String> claimed;
  final DailyGcStatus gcStatus;

  int get used => attempts.length;
  int get remaining => math.max(0, DailyRules.rankedAttempts - used);
  bool get hasFinished =>
      attempts.any((a) => a.status == DailyAttemptStatus.finished);

  DailyChallengeRecord copyWith({
    List<DailyAttempt>? attempts,
    int? bestScore,
    String? bestRunId,
    DateTime? completedAt,
    Set<String>? claimed,
    DailyGcStatus? gcStatus,
  }) => DailyChallengeRecord(
    challengeId: challengeId,
    seed: seed,
    generatorVersion: generatorVersion,
    attempts: attempts ?? this.attempts,
    bestScore: bestScore ?? this.bestScore,
    bestRunId: bestRunId ?? this.bestRunId,
    completedAt: completedAt ?? this.completedAt,
    claimed: claimed ?? this.claimed,
    gcStatus: gcStatus ?? this.gcStatus,
  );

  Map<String, Object> toJson() => {
    'challengeId': challengeId,
    'seed': seed,
    'generatorVersion': generatorVersion,
    'attempts': [for (final a in attempts) a.toJson()],
    'bestScore': bestScore,
    'bestRunId': ?bestRunId,
    'completedAt': ?completedAt?.toUtc().toIso8601String(),
    'claimed': claimed.toList()..sort(),
    'gcStatus': gcStatus.name,
  };

  static DailyChallengeRecord? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['challengeId'];
    if (id is! String || DailyChallengeDefinition.dayKeyOf(id) == null) {
      return null;
    }
    final seed = j['seed'], gen = j['generatorVersion'];
    final list = j['attempts'];
    final attempts = list is List
        ? list.map(DailyAttempt.fromJson).whereType<DailyAttempt>().toList()
        : <DailyAttempt>[];
    final best = j['bestScore'];
    final bestRun = j['bestRunId'];
    final done = j['completedAt'];
    final claimed = j['claimed'];
    return DailyChallengeRecord(
      challengeId: id,
      seed: seed is int ? seed : 0,
      generatorVersion: gen is int ? gen : 1,
      // bozuk bir kayıtta fazladan deneme olsa da hak sayısı aşılmaz (fazlası harcanmış sayılır)
      attempts: attempts,
      bestScore: best is int ? best.clamp(0, 99999) : 0,
      bestRunId: bestRun is String ? bestRun : null,
      completedAt: done is String ? DateTime.tryParse(done) : null,
      claimed: claimed is List ? claimed.whereType<String>().toSet() : const {},
      gcStatus:
          DailyGcStatus.values.asNameMap()[j['gcStatus']] ?? DailyGcStatus.none,
    );
  }
}

/// Günün Uçuşu'nun kalıcı durumu.
@immutable
class DailyChallengeState {
  const DailyChallengeState({this.records = const {}, this.highWaterDay});

  static const empty = DailyChallengeState();

  /// challengeId → kayıt (en fazla [DailyRules.keepRecords]).
  final Map<String, DailyChallengeRecord> records;

  /// Dereceli oynanan en ileri UTC günü. Cihaz tarihi bunun gerisine alınırsa dereceli oyun kapanır.
  final String? highWaterDay;

  DailyChallengeRecord? operator [](String challengeId) => records[challengeId];

  DailyChallengeState withRecord(DailyChallengeRecord r, {String? day}) {
    final next = {...records, r.challengeId: r};
    if (next.length > DailyRules.keepRecords) {
      final keys = next.keys.toList()..sort();
      for (final k in keys.take(next.length - DailyRules.keepRecords)) {
        next.remove(k);
      }
    }
    final hw = highWaterDay;
    return DailyChallengeState(
      records: next,
      highWaterDay: day != null && (hw == null || day.compareTo(hw) > 0)
          ? day
          : hw,
    );
  }

  Map<String, Object> toJson() => {
    'v': 1,
    'records': {for (final e in records.entries) e.key: e.value.toJson()},
    'highWaterDay': ?highWaterDay,
  };

  factory DailyChallengeState.fromJson(Object? j) {
    if (j is! Map) return empty;
    final raw = j['records'];
    final records = <String, DailyChallengeRecord>{};
    if (raw is Map) {
      for (final v in raw.values) {
        final r = DailyChallengeRecord.fromJson(v);
        if (r != null) records[r.challengeId] = r;
      }
    }
    final hw = j['highWaterDay'];
    return DailyChallengeState(
      records: records,
      highWaterDay: hw is String && parseUtcDayKey(hw) != null ? hw : null,
    );
  }
}

/// Cihaz saatinin güvenilirliği (sunucu yok: docs/17 §6).
enum DailyClockStatus {
  ok,

  /// Cihaz tarihi daha önce dereceli oynanan bir günün gerisinde: saat geri alınmış.
  rolledBack,

  /// Apple'ın (Game Center günlük tablo dönemi) bildirdiği gün cihazınkinden farklı.
  mismatch,
}

DailyClockStatus checkDailyClock(
  DailyChallengeState s,
  DateTime now, {
  String? trustedDay,
}) {
  final day = utcDayKey(now);
  final hw = s.highWaterDay;
  if (hw != null && day.compareTo(hw) < 0) return DailyClockStatus.rolledBack;
  if (trustedDay != null && trustedDay != day) return DailyClockStatus.mismatch;
  return DailyClockStatus.ok;
}

enum DailyBeginResult { started, noAttempts, clockProblem, notToday, duplicate }

/// Dereceli denemeyi başlatır: hak hemen harcanır ve kaydedilir (uçuş bitmeden uygulama kapansa da).
(PlayerProgress, DailyBeginResult) applyDailyBegin(
  PlayerProgress p,
  DailyChallengeDefinition def,
  String runId,
  DateTime now, {
  String? trustedDay,
}) {
  final s = p.dailyChallenge;
  if (checkDailyClock(s, now, trustedDay: trustedDay) != DailyClockStatus.ok) {
    return (p, DailyBeginResult.clockProblem);
  }
  if (def.dayKey != utcDayKey(now)) return (p, DailyBeginResult.notToday);
  final rec = s[def.challengeId] ?? DailyChallengeRecord.forDefinition(def);
  if (rec.attempts.any((a) => a.runId == runId)) {
    return (p, DailyBeginResult.duplicate);
  }
  if (rec.remaining <= 0) return (p, DailyBeginResult.noAttempts);
  final next = rec.copyWith(
    attempts: [
      ...rec.attempts,
      DailyAttempt(
        runId: runId,
        status: DailyAttemptStatus.started,
        startedAt: now.toUtc(),
      ),
    ],
  );
  return (
    p.copyWith(dailyChallenge: s.withRecord(next, day: def.dayKey)),
    DailyBeginResult.started,
  );
}

/// Günlük uçuşun oyun sonu özeti.
@immutable
class DailyRunOutcome {
  const DailyRunOutcome({
    required this.runId,
    required this.challengeId,
    required this.ranked,
    required this.score,
    required this.bestScore,
    required this.previousBest,
    required this.remaining,
    this.attemptNumber = 0,
    this.previousAttemptScore,
    this.xp = 0,
    this.simits = 0,
    this.rewards = const [],
  });

  final String runId;
  final String challengeId;
  final bool ranked;
  final int score;

  /// Bu uçuştan sonra günün en iyi dereceli skoru.
  final int bestScore;
  final int previousBest;
  final int remaining;

  /// 1..3 (antrenmanda 0).
  final int attemptNumber;

  /// Bir önceki tamamlanmış dereceli denemenin skoru (yoksa null).
  final int? previousAttemptScore;
  final int xp;
  final int simits;

  /// Bu uçuşta alınan ödül anahtarları.
  final List<String> rewards;

  bool get newBest => ranked && score > previousBest;
  int? get diffFromPrevious {
    final prev = previousAttemptScore;
    return prev == null ? null : score - prev;
  }
}

/// Günlük uçuşun hesabı: dereceli denemeyi kapatır, günlük rekoru ve tek seferlik ödülleri işler.
/// İdempotent: aynı uçuş (runId) ikinci kez gelirse ya da başlatılmış bir deneme değilse hiçbir şey
/// değişmez. Antrenman uçuşu kaydı değiştirmez, yalnızca özet döner.
(PlayerProgress, DailyRunOutcome?) settleDailyRun(
  PlayerProgress p,
  RunResult r,
  DateTime now,
) {
  final id = r.challengeId;
  if (!r.mode.isDaily || id == null) return (p, null);
  final rec = p.dailyChallenge[id];
  if (r.mode == RunMode.dailyPractice) {
    return (
      p,
      DailyRunOutcome(
        runId: r.runId,
        challengeId: id,
        ranked: false,
        score: r.score,
        bestScore: rec?.bestScore ?? 0,
        previousBest: rec?.bestScore ?? 0,
        remaining: rec?.remaining ?? DailyRules.rankedAttempts,
      ),
    );
  }
  if (rec == null) return (p, null);
  final index = rec.attempts.indexWhere((a) => a.runId == r.runId);
  if (index < 0 || rec.attempts[index].status != DailyAttemptStatus.started) {
    return (p, null); // aynı uçuş ikinci kez ya da başlatılmamış uçuş
  }
  final score = math.max(0, r.score);
  final attempts = [...rec.attempts];
  attempts[index] = attempts[index].copyWith(
    status: DailyAttemptStatus.finished,
    score: score,
  );
  int? previousAttempt;
  for (var i = index - 1; i >= 0; i--) {
    if (attempts[i].status == DailyAttemptStatus.finished) {
      previousAttempt = attempts[i].score;
      break;
    }
  }

  // ---- tek seferlik ödüller ----
  final policy = DailyRewardPolicy.v1;
  final claimed = {...rec.claimed};
  final rewards = <String>[];
  var xp = 0, simits = 0;
  if (claimed.add(DailyRewardPolicy.firstFlightKey)) {
    rewards.add(DailyRewardPolicy.firstFlightKey);
    xp += policy.firstFlightXp;
  }
  for (final (threshold, amount) in policy.scoreRewards) {
    final key = DailyRewardPolicy.scoreKey(threshold);
    if (score >= threshold && claimed.add(key)) {
      rewards.add(key);
      simits += amount;
    }
  }

  final newBest = score > rec.bestScore;
  final exhausted =
      attempts.length >= DailyRules.rankedAttempts &&
      !attempts.any((a) => a.status == DailyAttemptStatus.started);
  final next = rec.copyWith(
    attempts: attempts,
    bestScore: newBest ? score : rec.bestScore,
    bestRunId: newBest ? r.runId : rec.bestRunId,
    completedAt: exhausted ? now.toUtc() : null,
    claimed: claimed,
  );
  final day = DailyChallengeDefinition.dayKeyOf(id);
  final updated = p.copyWith(
    dailyChallenge: p.dailyChallenge.withRecord(next, day: day),
    xp: math.min(ProgressionConfig.maxTotalXp, p.xp + xp),
    bonusSimits: p.bonusSimits + simits,
  );
  return (
    updated,
    DailyRunOutcome(
      runId: r.runId,
      challengeId: id,
      ranked: true,
      score: score,
      bestScore: next.bestScore,
      previousBest: rec.bestScore,
      remaining: next.remaining,
      attemptNumber: index + 1,
      previousAttemptScore: previousAttempt,
      xp: xp,
      simits: simits,
      rewards: rewards,
    ),
  );
}

/// Bir durumdaki denemeyi [to] yapar (yarıda bırakma / kapanma). Hak geri verilmez.
PlayerProgress closeDailyAttempt(
  PlayerProgress p,
  String runId,
  DailyAttemptStatus to,
  DateTime now,
) {
  var s = p.dailyChallenge;
  var changed = false;
  for (final rec in s.records.values) {
    final i = rec.attempts.indexWhere(
      (a) => a.runId == runId && a.status == DailyAttemptStatus.started,
    );
    if (i < 0) continue;
    final attempts = [...rec.attempts];
    attempts[i] = attempts[i].copyWith(status: to);
    final exhausted =
        attempts.length >= DailyRules.rankedAttempts &&
        !attempts.any((a) => a.status == DailyAttemptStatus.started);
    s = s.withRecord(
      rec.copyWith(
        attempts: attempts,
        completedAt: exhausted ? now.toUtc() : null,
      ),
    );
    changed = true;
  }
  return changed ? p.copyWith(dailyChallenge: s) : p;
}

/// Açılışta: önceki oturumda bitmeden kalan denemeler "kesildi" olur (hak harcanmış kalır).
PlayerProgress recoverInterruptedDaily(PlayerProgress p, DateTime now) {
  var next = p;
  for (final rec in p.dailyChallenge.records.values) {
    for (final a in rec.attempts) {
      if (a.status == DailyAttemptStatus.started) {
        next = closeDailyAttempt(
          next,
          a.runId,
          DailyAttemptStatus.interrupted,
          now,
        );
      }
    }
  }
  return next;
}

PlayerProgress applyDailyGcStatus(
  PlayerProgress p,
  String challengeId,
  DailyGcStatus status,
) {
  final rec = p.dailyChallenge[challengeId];
  if (rec == null || rec.gcStatus == status) return p;
  return p.copyWith(
    dailyChallenge: p.dailyChallenge.withRecord(rec.copyWith(gcStatus: status)),
  );
}
