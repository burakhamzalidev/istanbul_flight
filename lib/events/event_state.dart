import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../challenge/daily_challenge.dart';
import '../challenge/daily_state.dart';
import '../progression/game_events.dart';
import '../services/progress.dart';
import 'event_calendar.dart';
import 'event_definition.dart';
import 'weekly_missions.dart';

// Phase 2.7: etkinlik ve sezon kaydı, uçuş sonu hesabı (docs/20 §7–§9, §13).
//
// Kayıt PlayerProgress içinde tutulur (`events` alanı): sezon puanı, etkinlik rekoru ve ödüller ile simit
// bakiyesi aynı tek yazmada diske gider. Fonksiyonlar saftır (zaman dışarıdan) ve idempotenttir: aynı uçuş
// (runId) ikinci kez sayılmaz; her ödülün kalıcı bir anahtarı vardır, cihaz saatini ileri ya da geri almak
// aynı ödülü ikinci kez vermez.

abstract final class EventRules {
  /// Saklanan etkinlik kaydı. Eskileri silinir (ödülleri profile işlenmiştir).
  static const keepRecords = 16;
  static const keepSeasons = 6;
  static const settledRunMemory = 50;
  static const ledgerMemory = 160;
}

@immutable
class EventRecord {
  const EventRecord({
    required this.eventId,
    this.seed = 0,
    this.generatorVersion = 0,
    this.flights = 0,
    this.bestScore = 0,
    this.bestRunId,
    this.claimed = const {},
    this.creditedSimits = 0,
    this.gcStatus = DailyGcStatus.none,
  });

  final String eventId;

  /// İlk dereceli uçuştaki tohum ve üretici (tanılama ve denetim için; sonradan değişmez).
  final int seed;
  final int generatorVersion;

  /// Dereceli, tamamlanmış uçuş sayısı (deneme sınırı yok).
  final int flights;

  /// Etkinliğin en iyi tek uçuş skoru (toplam değil).
  final int bestScore;
  final String? bestRunId;

  /// Alınmış tek seferlik ödüller ([EventRewardPolicy] anahtarları).
  final Set<String> claimed;

  /// Bu etkinlikte cüzdana geçen uçuş simidi (Simit Festivali sınırı için).
  final int creditedSimits;
  final DailyGcStatus gcStatus;

  EventRecord copyWith({
    int? seed,
    int? generatorVersion,
    int? flights,
    int? bestScore,
    String? bestRunId,
    Set<String>? claimed,
    int? creditedSimits,
    DailyGcStatus? gcStatus,
  }) => EventRecord(
    eventId: eventId,
    seed: seed ?? this.seed,
    generatorVersion: generatorVersion ?? this.generatorVersion,
    flights: flights ?? this.flights,
    bestScore: bestScore ?? this.bestScore,
    bestRunId: bestRunId ?? this.bestRunId,
    claimed: claimed ?? this.claimed,
    creditedSimits: creditedSimits ?? this.creditedSimits,
    gcStatus: gcStatus ?? this.gcStatus,
  );

  Map<String, Object> toJson() => {
    'eventId': eventId,
    'seed': seed,
    'generatorVersion': generatorVersion,
    'flights': flights,
    'bestScore': bestScore,
    'bestRunId': ?bestRunId,
    'claimed': claimed.toList()..sort(),
    'creditedSimits': creditedSimits,
    'gcStatus': gcStatus.name,
  };

  static EventRecord? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['eventId'];
    if (id is! String || EventCalendar.slotById(id) == null) return null;
    int count(Object? v, [int max = 99999]) =>
        v is int && v >= 0 ? math.min(v, max) : 0;
    final claimed = j['claimed'];
    final run = j['bestRunId'];
    return EventRecord(
      eventId: id,
      seed: j['seed'] is int ? j['seed'] as int : 0,
      generatorVersion: count(j['generatorVersion'], 100),
      flights: count(j['flights']),
      bestScore: count(j['bestScore']),
      bestRunId: run is String ? run : null,
      claimed: claimed is List ? claimed.whereType<String>().toSet() : const {},
      creditedSimits: count(j['creditedSimits']),
      gcStatus:
          DailyGcStatus.values.asNameMap()[j['gcStatus']] ?? DailyGcStatus.none,
    );
  }
}

@immutable
class SeasonProgress {
  const SeasonProgress({
    required this.seasonId,
    this.points = 0,
    this.claimedLevels = const {},
    this.completedEvents = const {},
  });

  final String seasonId;

  /// Sezon puanı (XP'den ayrı; yalnızca bu sezonun ilerlemesi).
  final int points;

  /// Ödülü verilmiş seviyeler.
  final Set<int> claimedLevels;

  /// Bu sezonda en az bir dereceli uçuş tamamlanan etkinlikler.
  final Set<String> completedEvents;

  SeasonProgress copyWith({
    int? points,
    Set<int>? claimedLevels,
    Set<String>? completedEvents,
  }) => SeasonProgress(
    seasonId: seasonId,
    points: points ?? this.points,
    claimedLevels: claimedLevels ?? this.claimedLevels,
    completedEvents: completedEvents ?? this.completedEvents,
  );

  Map<String, Object> toJson() => {
    'seasonId': seasonId,
    'points': points,
    'claimedLevels': claimedLevels.toList()..sort(),
    'completedEvents': completedEvents.toList()..sort(),
  };

  static SeasonProgress? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['seasonId'];
    if (id is! String || EventCalendar.seasonById(id) == null) return null;
    final pts = j['points'], lv = j['claimedLevels'], ev = j['completedEvents'];
    return SeasonProgress(
      seasonId: id,
      points: pts is int && pts >= 0 ? math.min(pts, 100000) : 0,
      claimedLevels: lv is List ? lv.whereType<int>().toSet() : const {},
      completedEvents: ev is List ? ev.whereType<String>().toSet() : const {},
    );
  }
}

/// Etkinliklerin ve sezonların kalıcı durumu.
@immutable
class EventProgressState {
  const EventProgressState({
    this.records = const {},
    this.seasons = const {},
    this.weekly,
    this.ledger = const [],
    this.badges = const {},
    this.frames = const {},
    this.selectedFrame,
    this.settledRuns = const [],
    this.highWaterWeek,
  });

  static const empty = EventProgressState();

  final Map<String, EventRecord> records;
  final Map<String, SeasonProgress> seasons;
  final WeeklyMissions? weekly;

  /// Verilmiş ödüllerin anahtarları (`week:2026-W46:cupFlights`, `season_1:level_3` ...).
  final List<String> ledger;

  /// Kalıcı rozetler (sezon rozeti): kimlik → kazanılma zamanı.
  final Map<String, DateTime> badges;

  /// Açılmış kartpostal çerçeveleri ve seçili olan (null: klasik çerçeve).
  final Set<String> frames;
  final String? selectedFrame;

  /// Hesabı yapılmış son etkinlik uçuşları.
  final List<String> settledRuns;

  /// Dereceli etkinlik oynanan en ileri takvim haftası (cihaz saati geri alınırsa dereceli oyun kapanır).
  final int? highWaterWeek;

  EventRecord? operator [](String eventId) => records[eventId];
  SeasonProgress season(String id) =>
      seasons[id] ?? SeasonProgress(seasonId: id);

  String? get effectiveFrame =>
      selectedFrame != null && frames.contains(selectedFrame)
      ? selectedFrame
      : null;

  EventProgressState copyWith({
    Map<String, EventRecord>? records,
    Map<String, SeasonProgress>? seasons,
    WeeklyMissions? weekly,
    List<String>? ledger,
    Map<String, DateTime>? badges,
    Set<String>? frames,
    String? selectedFrame,
    bool clearFrame = false,
    List<String>? settledRuns,
    int? highWaterWeek,
  }) => EventProgressState(
    records: records ?? this.records,
    seasons: seasons ?? this.seasons,
    weekly: weekly ?? this.weekly,
    ledger: ledger ?? this.ledger,
    badges: badges ?? this.badges,
    frames: frames ?? this.frames,
    selectedFrame: clearFrame ? null : selectedFrame ?? this.selectedFrame,
    settledRuns: settledRuns ?? this.settledRuns,
    highWaterWeek: highWaterWeek ?? this.highWaterWeek,
  );

  EventProgressState withRecord(EventRecord r) {
    final next = {...records, r.eventId: r};
    _trim(next, EventRules.keepRecords, (id) {
      final s = EventCalendar.slotById(id);
      return s?.startAtUtc.millisecondsSinceEpoch ?? 0;
    });
    return copyWith(records: next);
  }

  EventProgressState withSeason(SeasonProgress s) {
    final next = {...seasons, s.seasonId: s};
    _trim(next, EventRules.keepSeasons, (id) {
      final d = EventCalendar.seasonById(id);
      return d?.number ?? 0;
    });
    return copyWith(seasons: next);
  }

  static void _trim<T>(Map<String, T> m, int keep, int Function(String) order) {
    if (m.length <= keep) return;
    final keys = m.keys.toList()..sort((a, b) => order(a).compareTo(order(b)));
    for (final k in keys.take(m.length - keep)) {
      m.remove(k);
    }
  }

  Map<String, Object> toJson() => {
    'v': 1,
    'records': {for (final e in records.entries) e.key: e.value.toJson()},
    'seasons': {for (final e in seasons.entries) e.key: e.value.toJson()},
    'weekly': ?weekly?.toJson(),
    'ledger': ledger,
    'badges': {
      for (final e in badges.entries) e.key: e.value.toUtc().toIso8601String(),
    },
    'frames': frames.toList()..sort(),
    'selectedFrame': ?selectedFrame,
    'settledRuns': settledRuns,
    'highWaterWeek': ?highWaterWeek,
  };

  /// Bozuk bir alan diğerlerini etkilemez; tanınmayan kayıtlar atılır.
  factory EventProgressState.fromJson(Object? j) {
    if (j is! Map) return empty;
    final recRaw = j['records'], seaRaw = j['seasons'];
    final records = <String, EventRecord>{};
    if (recRaw is Map) {
      for (final v in recRaw.values) {
        final r = EventRecord.fromJson(v);
        if (r != null) records[r.eventId] = r;
      }
    }
    final seasons = <String, SeasonProgress>{};
    if (seaRaw is Map) {
      for (final v in seaRaw.values) {
        final s = SeasonProgress.fromJson(v);
        if (s != null) seasons[s.seasonId] = s;
      }
    }
    List<String> strings(Object? v) =>
        v is List ? v.whereType<String>().toList() : const [];
    final badges = j['badges'];
    final frames = j['frames'];
    final selected = j['selectedFrame'];
    final hw = j['highWaterWeek'];
    return EventProgressState(
      records: records,
      seasons: seasons,
      weekly: WeeklyMissions.fromJson(j['weekly']),
      ledger: strings(j['ledger']),
      badges: badges is Map
          ? {
              for (final e in badges.entries)
                if (e.key is String && e.value is String)
                  e.key as String: ?DateTime.tryParse(e.value as String),
            }
          : const {},
      frames: frames is List ? frames.whereType<String>().toSet() : const {},
      selectedFrame: selected is String ? selected : null,
      settledRuns: strings(j['settledRuns']),
      highWaterWeek: hw is int && hw >= 0 ? hw : null,
    );
  }
}

// ============================ Saat ============================

/// Cihaz saatinin güvenilirliği (sunucu yok; günlük challenge ile aynı yaklaşım, hafta ölçeğinde).
enum EventClockStatus {
  ok,

  /// Cihaz tarihi daha önce dereceli oynanan bir haftanın gerisinde.
  rolledBack,

  /// Game Center'ın kupa tablosu dönemi cihazın haftasından farklı.
  mismatch,
}

EventClockStatus checkEventClock(
  EventProgressState s,
  DateTime now, {
  int? trustedWeek,
}) {
  final week = EventCalendar.weekIndex(now);
  final hw = s.highWaterWeek;
  if (hw != null && week < hw) return EventClockStatus.rolledBack;
  if (trustedWeek != null && trustedWeek != week) {
    return EventClockStatus.mismatch;
  }
  return EventClockStatus.ok;
}

// ============================ Uçuş sonu ============================

/// Etkinlik uçuşunun oyun sonu özeti.
@immutable
class EventRunOutcome {
  const EventRunOutcome({
    required this.runId,
    required this.eventId,
    required this.kind,
    required this.type,
    required this.ranked,
    required this.score,
    required this.previousBest,
    required this.bestScore,
    required this.flights,
    this.seasonPoints = 0,
    this.simits = 0,
    this.rewards = const [],
    this.seasonLevels = const [],
    this.simitsCapped = false,
  });

  final String runId;
  final String eventId;
  final EventKind kind;
  final EventType type;
  final bool ranked;

  /// Etkinliğin skor kuralıyla (Simit Festivali: engel + 2 × simit).
  final int score;
  final int previousBest;
  final int bestScore;
  final int flights;

  /// Bu uçuşla kazanılan sezon puanı (etkinlik + haftalık görevler).
  final int seasonPoints;

  /// Etkinlik ödülü simitleri (uçuşta toplananlar hariç).
  final int simits;
  final List<String> rewards;

  /// Bu uçuşla ulaşılan sezon seviyeleri (ödülleri verildi).
  final List<SeasonLevel> seasonLevels;

  /// Festival cüzdan sınırına ulaşıldı (toplanan simitlerin bir kısmı cüzdana geçmedi).
  final bool simitsCapped;

  bool get newBest => ranked && score > previousBest;
}

/// Haftalık görevlerin bir uçuştaki sonucu.
@immutable
class WeeklyOutcome {
  const WeeklyOutcome({
    this.completed = const [],
    this.seasonPoints = 0,
    this.simits = 0,
    this.seasonLevels = const [],
  });

  static const none = WeeklyOutcome();

  final List<WeeklyMission> completed;
  final int seasonPoints;
  final int simits;
  final List<SeasonLevel> seasonLevels;
}

List<String> _remember(List<String> list, String item, int keep) {
  final next = [...list, item];
  return next.length > keep ? next.sublist(next.length - keep) : next;
}

/// Etkinliğin dereceli olup olamayacağı (uçuş başlarken): etkinlik o anda açık ve saat güvenilir olmalı.
bool canRankEvent(
  PlayerProgress p,
  EventSlot slot,
  DateTime now, {
  int? trustedWeek,
}) =>
    slot.isActiveAt(now) &&
    checkEventClock(p.events, now, trustedWeek: trustedWeek) ==
        EventClockStatus.ok;

/// Uçuşta toplanan simitlerden cüzdana geçecek miktar (Simit Festivali sınırı). Diğer etkinliklerde ve
/// modlarda uçuşun simitleri aynen geçer.
int eventWalletSimits(PlayerProgress p, RunResult r) {
  final id = r.eventId;
  if (r.mode != RunMode.event || id == null) return r.simits;
  final slot = EventCalendar.slotById(id);
  final cap = slot?.rewards.simitCap;
  if (cap == null) return r.simits;
  final used = p.events[id]?.creditedSimits ?? 0;
  return math.max(0, math.min(r.simits, cap - used));
}

/// Sezon puanı ekler ve yeni ulaşılan seviyelerin ödüllerini bir kez verir. Kozmetik ödüller mevcut
/// sahiplik sistemine yazılır ([PlayerProgress.unlockedCosmetics]); daha önce alınmış kalıcı bir ödül
/// tekrar verilmez, yerine [SeasonLevel.duplicateSimits] verilir.
(PlayerProgress, List<SeasonLevel>) addSeasonPoints(
  PlayerProgress p,
  String seasonId,
  int points,
  DateTime now,
) {
  final def = EventCalendar.seasonById(seasonId);
  if (def == null || points <= 0) return (p, const []);
  var s = p.events;
  var season = s.season(seasonId);
  season = season.copyWith(points: season.points + points);
  final reached = <SeasonLevel>[];
  var ledger = s.ledger;
  var bonus = 0;
  var badges = s.badges;
  var frames = s.frames;
  var cosmetics = p.unlockedCosmetics;
  final claimed = {...season.claimedLevels};
  for (final lv in def.levels) {
    final key = '$seasonId:level_${lv.level}';
    if (season.points < lv.points || claimed.contains(lv.level)) continue;
    if (ledger.contains(key)) {
      claimed.add(lv.level);
      continue;
    }
    claimed.add(lv.level);
    ledger = _remember(ledger, key, EventRules.ledgerMemory);
    reached.add(lv);
    switch (lv.kind) {
      case SeasonRewardKind.simits:
        bonus += lv.simits;
      case SeasonRewardKind.badge:
        badges = {...badges, SeasonRules.badgeId(seasonId): now};
      case SeasonRewardKind.postcardFrame:
        final id = lv.itemId!;
        if (frames.contains(id)) {
          bonus += lv.duplicateSimits;
        } else {
          frames = {...frames, id};
        }
      case SeasonRewardKind.cosmetic:
        final id = lv.itemId!;
        if (cosmetics.contains(id)) {
          bonus += lv.duplicateSimits;
        } else {
          cosmetics = {...cosmetics, id};
        }
    }
  }
  season = season.copyWith(claimedLevels: claimed);
  s = s
      .withSeason(season)
      .copyWith(ledger: ledger, badges: badges, frames: frames);
  return (
    p.copyWith(
      events: s,
      bonusSimits: p.bonusSimits + bonus,
      unlockedCosmetics: cosmetics,
    ),
    reached,
  );
}

/// Etkinlik uçuşunun hesabı: etkinlik rekoru (en iyi tek uçuş), tek seferlik ödüller, sezon puanı.
/// İdempotent: aynı uçuş ikinci kez gelirse hiçbir şey değişmez (null). Dereceli olmayan uçuş kaydı
/// değiştirmez, yalnızca özet döner.
///
/// [creditedSimits]: bu uçuşta cüzdana geçen simit ([eventWalletSimits]); Festival sınırı sayacı için.
(PlayerProgress, EventRunOutcome?) settleEventRun(
  PlayerProgress p,
  RunResult r,
  DateTime now, {
  int? creditedSimits,
  int? trustedWeek,
}) {
  final id = r.eventId;
  if (!r.mode.isEvent || id == null || r.runId.isEmpty) return (p, null);
  final slot = EventCalendar.slotById(id);
  if (slot == null) return (p, null);
  final s = p.events;
  if (s.settledRuns.contains(r.runId)) return (p, null);
  final score = slot.scoring.score(
    obstacles: math.max(0, r.obstaclesPassed),
    simits: math.max(0, r.simits),
  );
  final rec = s[id] ?? EventRecord(eventId: id);
  // Dereceli değil: oyuncu antrenmanda başladı, etkinlik uçuş sırasında bitti ya da saat güvenilmez
  final ranked =
      r.mode == RunMode.event &&
      !now.toUtc().isAfter(slot.endAtUtc.add(const Duration(minutes: 30))) &&
      checkEventClock(s, now, trustedWeek: trustedWeek) != EventClockStatus.rolledBack;
  if (!ranked) {
    return (
      p,
      EventRunOutcome(
        runId: r.runId,
        eventId: id,
        kind: slot.kind,
        type: slot.type,
        ranked: false,
        score: score,
        previousBest: rec.bestScore,
        bestScore: rec.bestScore,
        flights: rec.flights,
      ),
    );
  }

  // ---- tek seferlik etkinlik ödülleri ----
  final policy = slot.rewards;
  final claimed = {...rec.claimed};
  final rewards = <String>[];
  var points = 0, simits = 0;
  if (claimed.add(EventRewardPolicy.participationKey)) {
    rewards.add(EventRewardPolicy.participationKey);
    points += policy.participationPoints;
  }
  for (final m in policy.milestones) {
    final key = EventRewardPolicy.milestoneKey(m.score);
    if (score >= m.score && claimed.add(key)) {
      rewards.add(key);
      points += m.seasonPoints;
      simits += m.simits;
    }
  }
  final newBest = score > rec.bestScore;
  final credited = creditedSimits ?? r.simits;
  final next = rec.copyWith(
    flights: rec.flights + 1,
    bestScore: newBest ? score : rec.bestScore,
    bestRunId: newBest ? r.runId : rec.bestRunId,
    claimed: claimed,
    creditedSimits: rec.creditedSimits + math.max(0, credited),
  );
  final week = EventCalendar.weekIndex(now);
  final hw = s.highWaterWeek;
  var state = s.withRecord(next).copyWith(
    settledRuns: _remember(s.settledRuns, r.runId, EventRules.settledRunMemory),
    highWaterWeek: hw == null || week > hw ? week : hw,
  );
  final season = EventCalendar.seasonForWeek(slot.weekIndex);
  if (season != null) {
    final sp = state.season(season.seasonId);
    state = state.withSeason(
      sp.copyWith(completedEvents: {...sp.completedEvents, id}),
    );
  }
  var updated = p.copyWith(
    events: state,
    bonusSimits: p.bonusSimits + simits,
  );
  var levels = const <SeasonLevel>[];
  if (season != null) {
    (updated, levels) = addSeasonPoints(updated, season.seasonId, points, now);
  }
  final cap = policy.simitCap;
  return (
    updated,
    EventRunOutcome(
      runId: r.runId,
      eventId: id,
      kind: slot.kind,
      type: slot.type,
      ranked: true,
      score: score,
      previousBest: rec.bestScore,
      bestScore: next.bestScore,
      flights: next.flights,
      seasonPoints: points,
      simits: simits,
      rewards: rewards,
      seasonLevels: levels,
      simitsCapped: cap != null && credited < r.simits,
    ),
  );
}

/// Bu haftanın görevlerini hazırlar (yoksa ya da hafta değiştiyse üretir). Hafta aynıysa aynı nesne.
PlayerProgress ensureWeekly(PlayerProgress p, DateTime now) {
  final key = EventCalendar.weekKey(now);
  if (p.events.weekly?.weekKey == key) return p;
  return p.copyWith(
    events: p.events.copyWith(
      weekly: WeeklyMissions.generate(key, level: p.level),
    ),
  );
}

/// Haftalık görevler: her türden uçuş ilerletir (görev türüne göre). Saat geri alınmışsa ilerleme yok.
/// Ödüller tek seferlik (`week:<hafta>:<görev>`); eski haftanın ödülü yeni haftada verilmez.
///
/// [eventOutcome]: aynı uçuşun etkinlik özeti (kupa rekoru geliştirildi mi).
(PlayerProgress, WeeklyOutcome) settleWeekly(
  PlayerProgress p,
  RunResult r,
  DateTime now, {
  EventRunOutcome? eventOutcome,
  int? trustedWeek,
}) {
  if (r.runId.isEmpty || r.mode == RunMode.dailyPractice) {
    return (p, WeeklyOutcome.none);
  }
  if (r.mode == RunMode.eventPractice) return (p, WeeklyOutcome.none);
  if (checkEventClock(p.events, now, trustedWeek: trustedWeek) ==
      EventClockStatus.rolledBack) {
    return (p, WeeklyOutcome.none);
  }
  if (r.mode == RunMode.event && !(eventOutcome?.ranked ?? false)) {
    return (p, WeeklyOutcome.none);
  }
  p = ensureWeekly(p, now);
  final weekly = p.events.weekly!;
  final cup =
      eventOutcome != null &&
      eventOutcome.ranked &&
      eventOutcome.kind == EventKind.weeklyCup;
  final event = eventOutcome != null && eventOutcome.ranked;
  final improved = cup && eventOutcome.previousBest > 0 && eventOutcome.newBest;
  var ledger = p.events.ledger;
  final done = <WeeklyMission>[];
  final advanced = [
    for (final m in weekly.missions)
      m.advance(r, cup: cup, event: event, improvedCupBest: improved),
  ];
  for (final m in advanced) {
    final key = 'week:${weekly.weekKey}:${m.id}';
    if (m.completed && !ledger.contains(key)) {
      ledger = _remember(ledger, key, EventRules.ledgerMemory);
      done.add(m);
    }
  }
  final points = done.length * WeeklyMissionCatalog.seasonPoints;
  final simits = done.length * WeeklyMissionCatalog.simits;
  p = p.copyWith(
    events: p.events.copyWith(
      weekly: weekly.withMissions(advanced),
      ledger: ledger,
    ),
    bonusSimits: p.bonusSimits + simits,
  );
  var levels = const <SeasonLevel>[];
  final season = EventCalendar.seasonAt(now);
  if (season != null && points > 0) {
    (p, levels) = addSeasonPoints(p, season.seasonId, points, now);
  }
  return (
    p,
    WeeklyOutcome(
      completed: done,
      seasonPoints: points,
      simits: simits,
      seasonLevels: levels,
    ),
  );
}

PlayerProgress applyEventGcStatus(
  PlayerProgress p,
  String eventId,
  DailyGcStatus status,
) {
  final rec = p.events[eventId];
  if (rec == null || rec.gcStatus == status) return p;
  return p.copyWith(
    events: p.events.withRecord(rec.copyWith(gcStatus: status)),
  );
}

/// Kartpostal çerçevesi seçimi (sahip olunmayan çerçeve seçilemez; null = klasik).
PlayerProgress? selectPostcardFrame(PlayerProgress p, String? id) {
  if (id != null && !p.events.frames.contains(id)) return null;
  if (p.events.selectedFrame == id) return p;
  return p.copyWith(
    events: id == null
        ? p.events.copyWith(clearFrame: true)
        : p.events.copyWith(selectedFrame: id),
  );
}
