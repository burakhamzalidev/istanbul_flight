import 'package:flutter/foundation.dart';

import '../challenge/daily_challenge.dart';
import '../challenge/daily_rng.dart';
import '../game/config.dart';
import '../game/logic/hazards.dart';
import 'event_definition.dart';

// Phase 2.7: etkinlik takvimi (docs/20 §10).
//
// Sunucu yok. Takvim uygulamayla gelir ve sürümlüdür ([EventCalendar.version]): hangi hafta hangi etkinlik
// olduğu yalnızca UTC tarihten hesaplanır, böylece her cihaz aynı haftada aynı etkinliği ve aynı parkuru
// görür. Uzaktan yeni etkinlik yayımlanamaz; [EventDefinition.toJson]/[EventDefinition.fromJson] ileride
// uzaktan yapılandırma eklenirse aynı veri modelinin taşınması için vardır.

/// Takvimdeki bir etkinliğin yeri (doğrulanmış parkur olmadan; listelerde ucuzca gösterilir).
@immutable
class EventSlot {
  const EventSlot({
    required this.eventId,
    required this.kind,
    required this.type,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.weekIndex,
  });

  final String eventId;
  final EventKind kind;
  final EventType type;
  final DateTime startAtUtc;
  final DateTime endAtUtc;

  /// Takvim başlangıcından bu yana hafta (0 = ilk kupa haftası).
  final int weekIndex;

  bool isActiveAt(DateTime t) {
    final u = t.toUtc();
    return !u.isBefore(startAtUtc) && u.isBefore(endAtUtc);
  }

  bool isUpcomingAt(DateTime t) => t.toUtc().isBefore(startAtUtc);
  bool isOverAt(DateTime t) => !t.toUtc().isBefore(endAtUtc);

  ScoringPolicy get scoring => EventPresets.scoringFor(type);
  EventRewardPolicy get rewards => EventPresets.rewardsFor(kind, scoring);
  String? get leaderboardId =>
      kind == EventKind.weeklyCup ? EventPresets.cupLeaderboardId : null;
  String get title => kind == EventKind.weeklyCup
      ? 'İstanbul Kupası · ${type.title}'
      : type.title;

  @override
  bool operator ==(Object other) =>
      other is EventSlot && other.eventId == eventId;

  @override
  int get hashCode => eventId.hashCode;
}

/// Sezon (4 hafta). Sezon puanı XP'den ayrıdır; ödüller kalıcıdır.
@immutable
class SeasonDefinition {
  const SeasonDefinition({
    required this.seasonId,
    required this.number,
    required this.startAtUtc,
    required this.endAtUtc,
    this.levels = SeasonRules.levelsV1,
  });

  /// `season_1`
  final String seasonId;
  final int number;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final List<SeasonLevel> levels;

  bool isActiveAt(DateTime t) {
    final u = t.toUtc();
    return !u.isBefore(startAtUtc) && u.isBefore(endAtUtc);
  }

  /// [points] puanla ulaşılan seviye (0..levels.length).
  int levelFor(int points) =>
      levels.where((l) => points >= l.points).length;
}

/// Sezon ödülü türü.
enum SeasonRewardKind { simits, badge, postcardFrame, cosmetic }

@immutable
class SeasonLevel {
  const SeasonLevel({
    required this.level,
    required this.points,
    required this.kind,
    this.simits = 0,
    this.itemId,
    this.duplicateSimits = 0,
  });

  final int level;

  /// Bu seviye için gereken toplam sezon puanı.
  final int points;
  final SeasonRewardKind kind;
  final int simits;

  /// Kozmetik / çerçeve kimliği.
  final String? itemId;

  /// Kalıcı ödül daha önceki bir sezonda zaten alındıysa yerine verilen simit (aynı ödül iki kez verilmez).
  final int duplicateSimits;
}

abstract final class SeasonRules {
  static const weeks = 4;

  /// İlk sezonun ödülleri (docs/20 §8). Kozmetik ödüller kalıcıdır; sezon bitince geri alınmaz.
  static const levelsV1 = <SeasonLevel>[
    SeasonLevel(level: 1, points: 40, kind: SeasonRewardKind.simits, simits: 20),
    SeasonLevel(level: 2, points: 100, kind: SeasonRewardKind.badge),
    SeasonLevel(level: 3, points: 180, kind: SeasonRewardKind.simits, simits: 40),
    SeasonLevel(
      level: 4,
      points: 280,
      kind: SeasonRewardKind.postcardFrame,
      itemId: 'kupa',
      duplicateSimits: 40,
    ),
    SeasonLevel(level: 5, points: 400, kind: SeasonRewardKind.simits, simits: 60),
    SeasonLevel(
      level: 6,
      points: 550,
      kind: SeasonRewardKind.cosmetic,
      itemId: 'kupa',
      duplicateSimits: 80,
    ),
  ];

  static String badgeId(String seasonId) => '${seasonId}_badge';
}

abstract final class EventCalendar {
  /// Takvim kuralları sürümü. Kural değişirse yeni sürüm yalnızca gelecekteki bir haftadan başlar.
  static const version = 1;

  /// İlk kupa haftasının pazartesisi (00:00 UTC). Öncesinde etkinlik yoktur.
  static final epoch = DateTime.utc(2026, 11, 9);

  /// Kupa türlerinin haftalık dönüşü; özel etkinlik aynı haftada iki adım ilerideki tür (kupadan farklı).
  static const rotation = [
    EventType.marathon,
    EventType.simitFestival,
    EventType.windMaster,
    EventType.nightFlight,
  ];

  /// Bu haftanın pazartesisi 00:00 UTC.
  static DateTime weekStart(DateTime t) {
    final u = t.toUtc();
    final day = DateTime.utc(u.year, u.month, u.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// Takvim haftası (epoch'tan önce negatif).
  static int weekIndex(DateTime t) {
    final days = weekStart(t).difference(epoch).inDays;
    return (days / 7).floor();
  }

  static DateTime weekStartOf(int index) =>
      epoch.add(Duration(days: 7 * index));

  /// ISO 8601 hafta anahtarı: `2026-W46`.
  static String weekKey(DateTime t) {
    final (year, week) = isoWeek(t);
    return '$year-W${week.toString().padLeft(2, '0')}';
  }

  static (int, int) isoWeek(DateTime t) {
    final u = t.toUtc();
    final day = DateTime.utc(u.year, u.month, u.day);
    // ISO: haftanın perşembesi hangi yıldaysa hafta o yılındır
    final thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
    final jan1 = DateTime.utc(thursday.year, 1, 1);
    final week = (thursday.difference(jan1).inDays ~/ 7) + 1;
    return (thursday.year, week);
  }

  /// ISO yılının [week]. haftasının pazartesisi.
  static DateTime isoWeekMonday(int year, int week) {
    final jan4 = DateTime.utc(year, 1, 4);
    final firstMonday = jan4.subtract(Duration(days: jan4.weekday - 1));
    return firstMonday.add(Duration(days: 7 * (week - 1)));
  }

  static String _idSuffix(DateTime monday) {
    final (y, w) = isoWeek(monday);
    return '${y}_w${w.toString().padLeft(2, '0')}';
  }

  static EventType cupType(int index) => rotation[index % rotation.length];
  static EventType specialType(int index) =>
      rotation[(index + 2) % rotation.length];

  /// [index]. haftanın kupası (pazartesi 00:00 → sonraki pazartesi 00:00 UTC). Takvimden önce null.
  static EventSlot? cupFor(int index) {
    if (index < 0) return null;
    final start = weekStartOf(index);
    return EventSlot(
      eventId: 'cup_${_idSuffix(start)}',
      kind: EventKind.weeklyCup,
      type: cupType(index),
      startAtUtc: start,
      endAtUtc: start.add(const Duration(days: 7)),
      weekIndex: index,
    );
  }

  /// [index]. haftanın hafta sonu etkinliği (cuma 00:00 → pazartesi 00:00 UTC).
  static EventSlot? specialFor(int index) {
    if (index < 0) return null;
    final monday = weekStartOf(index);
    return EventSlot(
      eventId: 'special_${_idSuffix(monday)}',
      kind: EventKind.special,
      type: specialType(index),
      startAtUtc: monday.add(const Duration(days: 4)),
      endAtUtc: monday.add(const Duration(days: 7)),
      weekIndex: index,
    );
  }

  /// `cup_2026_w46` → slot (tanınmayan ya da takvim dışı kimlik: null).
  static EventSlot? slotById(String id) {
    final m = RegExp(r'^(cup|special)_(\d{4})_w(\d{2})$').firstMatch(id);
    if (m == null) return null;
    final week = int.parse(m[3]!);
    if (week < 1 || week > 53) return null;
    final monday = isoWeekMonday(int.parse(m[2]!), week);
    if (_idSuffix(monday) != '${m[2]}_w${m[3]}') return null;
    final index = weekIndex(monday);
    return m[1] == 'cup' ? cupFor(index) : specialFor(index);
  }

  /// Ekranda: geçmiş [past] hafta, bu hafta ve gelecek [future] hafta (başlangıç zamanına göre sıralı).
  static List<EventSlot> slotsAround(
    DateTime now, {
    int past = 2,
    int future = 3,
  }) {
    final i = weekIndex(now);
    return [
      for (var k = i - past; k <= i + future; k++) ...[
        ?cupFor(k),
        ?specialFor(k),
      ],
    ]..sort((a, b) => a.startAtUtc.compareTo(b.startAtUtc));
  }

  static EventSlot? activeCup(DateTime now) {
    final s = cupFor(weekIndex(now));
    return s != null && s.isActiveAt(now) ? s : null;
  }

  static EventSlot? activeSpecial(DateTime now) {
    final s = specialFor(weekIndex(now));
    return s != null && s.isActiveAt(now) ? s : null;
  }

  // ---- Sezon ----

  static SeasonDefinition? seasonForWeek(int index) {
    if (index < 0) return null;
    final n = index ~/ SeasonRules.weeks;
    final start = weekStartOf(n * SeasonRules.weeks);
    return SeasonDefinition(
      seasonId: 'season_${n + 1}',
      number: n + 1,
      startAtUtc: start,
      endAtUtc: start.add(const Duration(days: 7 * SeasonRules.weeks)),
    );
  }

  static SeasonDefinition? seasonAt(DateTime t) => seasonForWeek(weekIndex(t));

  static SeasonDefinition? seasonById(String id) {
    final m = RegExp(r'^season_(\d+)$').firstMatch(id);
    if (m == null) return null;
    final n = int.parse(m[1]!);
    if (n < 1) return null;
    return seasonForWeek((n - 1) * SeasonRules.weeks);
  }
}

/// Bir etkinliğin oynanacak parkuru: günlük parkur üreticisi + etkinliğin dinamik engelleri. Hepsi
/// yalnızca tohuma ve engel sırasına bağlıdır (kare hızı, ekran, oyuncu skoru etkilemez).
class EventCourse {
  EventCourse(this.definition, {this.config = const GameConfig()})
    : course = DailyCourse(definition.course, config: config) {
    final profile = definition.modifiers.hazards;
    _planner = profile == null
        ? null
        : HazardPlanner(
            config,
            DailyRng(DailyRng.hash('hazards:${definition.seed}')).nextDouble,
            profile: profile,
          );
  }

  final EventDefinition definition;
  final GameConfig config;
  final DailyCourse course;
  HazardPlanner? _planner;
  final List<Hazard?> _hazards = [null]; // ilk engelin önünde koridor yok

  /// [i]. engelin önündeki koridorun tehlikesi ([i]-1 ile [i]. engel arası). Sırayla üretilir.
  Hazard? hazardAt(int i) {
    final p = _planner;
    if (p == null || i < 1) return null;
    while (_hazards.length <= i) {
      final n = _hazards.length;
      final a = course.at(n - 1), b = course.at(n);
      _hazards.add(
        p.next(
          corridor: n,
          score: n,
          previous: (center: a.gapCenter, height: a.gapHeight),
          gap: (center: b.gapCenter, height: b.gapHeight),
        ),
      );
    }
    return _hazards[i];
  }
}

/// Etkinlik tanımlarının tek kaynağı: takvimdeki yerden doğrulanmış parkur tohumu seçilir.
abstract final class EventGenerators {
  /// Sürüm takvimi: (bu haftanın pazartesisinden itibaren, sürüm). Yeni sürüm yalnızca yayından sonra
  /// başlayan bir haftadan eklenir; süren bir etkinliğin kuralları güncellemeyle değişmez.
  static const schedule = <(String, int)>[('2026-11-09', 1)];

  static const maxCandidates = 12;

  /// Doğrulama derinliği (günlük challenge ile aynı ölçüt).
  static const requiredDepth = CourseValidator.requiredDepth;

  static int versionFor(DateTime start) {
    final key = utcDayKey(start);
    var v = schedule.first.$2;
    for (final (from, version) in schedule) {
      if (key.compareTo(from) >= 0) v = version;
    }
    return v;
  }

  static final Map<String, EventDefinition> _cache = {};

  /// Adaylar sırayla denenir; dinamik engellerle birlikte doğrulamayı ilk geçen seçilir. Hiçbiri geçemezse
  /// en derine ulaşan (eşitlikte en geniş aralıklı) seçilir. Seçim deterministiktir.
  static EventDefinition build(
    EventSlot slot, {
    GameConfig config = const GameConfig(),
  }) {
    final standard = identical(config, const GameConfig());
    final cached = standard ? _cache[slot.eventId] : null;
    if (cached != null) return cached;
    final version = versionFor(slot.startAtUtc);
    EventDefinition? best;
    var bestDepth = -1;
    var bestTightest = -1.0;
    for (var k = 0; k < maxCandidates; k++) {
      final def = _definition(
        slot,
        version,
        seed: DailyRng.hash('istanbul_flight/event/v$version/${slot.eventId}/$k'),
        candidate: k,
      );
      final course = EventCourse(def, config: config);
      final check = CourseValidator.check(
        course.course,
        maxScore: requiredDepth,
        hazardAt: course.hazardAt,
      );
      final scored = _definition(
        slot,
        version,
        seed: def.seed,
        candidate: k,
        depth: check.depth,
      );
      if (check.passes) {
        best = scored;
        break;
      }
      if (check.problems.isEmpty &&
          (check.depth > bestDepth ||
              (check.depth == bestDepth && check.tightest > bestTightest))) {
        best = scored;
        bestDepth = check.depth;
        bestTightest = check.tightest;
      }
    }
    final result =
        best ?? _definition(slot, version, seed: DailyRng.hash(slot.eventId));
    if (standard) _cache[slot.eventId] = result;
    return result;
  }

  /// Tanımı arka planda (ayrı isolate) hazırlar; sonuç [build] ile aynıdır.
  static Future<EventDefinition> prepare(EventSlot slot) async {
    final cached = _cache[slot.eventId];
    if (cached != null) return cached;
    try {
      final def = await compute(_buildById, slot.eventId);
      return _cache.putIfAbsent(slot.eventId, () => def);
    } catch (e) {
      debugPrint('Etkinlik parkuru arka planda hazırlanamadı: $e');
      return build(slot);
    }
  }

  static EventDefinition _buildById(String id) =>
      build(EventCalendar.slotById(id)!);

  static EventDefinition _definition(
    EventSlot slot,
    int version, {
    required int seed,
    int candidate = 0,
    int depth = 0,
  }) {
    final scoring = EventPresets.scoringFor(slot.type);
    return EventDefinition(
      eventId: slot.eventId,
      kind: slot.kind,
      type: slot.type,
      title: slot.title,
      description: slot.type.description,
      startAtUtc: slot.startAtUtc,
      endAtUtc: slot.endAtUtc,
      seed: seed,
      generatorVersion: version,
      zoneSelection: EventPresets.zonesFor(slot.type),
      modifiers: EventPresets.modifiersFor(slot.type),
      scoring: scoring,
      rewards: EventPresets.rewardsFor(slot.kind, scoring),
      leaderboardId: slot.leaderboardId,
      candidate: candidate,
      validatedDepth: depth,
    );
  }

  /// Parkur (sürüme göre). Bilinmeyen sürüm: hata (eski uygulama yeni bir etkinliği yanlış oynamasın).
  static EventCourse course(
    EventDefinition def, {
    GameConfig config = const GameConfig(),
  }) => switch (def.generatorVersion) {
    1 => EventCourse(def, config: config),
    _ => throw UnsupportedError('event generator v${def.generatorVersion}'),
  };
}
