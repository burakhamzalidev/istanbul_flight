import 'package:flutter/foundation.dart';

import '../challenge/daily_challenge.dart';
import '../game/day_cycle.dart';
import '../game/logic/hazards.dart';
import '../services/game_center/game_center.dart';

// Phase 2.7: Haftalık İstanbul Kupası, özel etkinlikler ve sezon (docs/20_phase2_7_weekly_events.md).
//
// Bu dosya saf veridir: bir etkinliğin bütün kuralları [EventDefinition] içinde. Oyun motoru etkinlik
// türüne göre dallanmaz; tanımdaki bölge dizisini, oynanış değiştiricilerini ve skor kuralını uygular.
// Yeni bir etkinlik türü = yeni bir [EventPresets] satırı (motor kodu değişmez).

/// Etkinliğin yeri takvimde: haftalık kupa (pazartesi–pazartesi, Game Center tablosu) ya da hafta sonu
/// özel etkinliği (cuma–pazartesi, yalnızca yerel en iyi skor).
enum EventKind {
  weeklyCup('İstanbul Kupası'),
  special('Özel Etkinlik');

  const EventKind(this.label);
  final String label;
}

/// Etkinlik türleri (ilk sürüm). Her biri mevcut oyunun kontrollü bir varyasyonu.
enum EventType {
  marathon(
    'Boğaz Maratonu',
    'Haliç’ten Üsküdar’a dokuz bölgenin hepsinden geçen uzun uçuş. Zorluk giderek artar.',
  ),
  simitFestival(
    'Simit Festivali',
    'Neredeyse her geçitte simit! Puan = geçilen engel + her simit için 2.',
  ),
  nightFlight(
    'Gece Uçuşu',
    'Işıklı Rumeli Hisarı’nın önünde, ay ışığında bir uçuş. Engeller her zaman net.',
  ),
  windMaster(
    'Rüzgâr Ustası',
    'Emirgan ve Ortaköy’de sık hava akımları. Rüzgâr şeritleri itişi önceden gösterir.',
  );

  const EventType(this.title, this.description);
  final String title;
  final String description;
}

/// Bölge dizisinin bir adımı: [fromScore] skordan itibaren [zone] ([zones] sırası).
@immutable
class ZoneStage {
  const ZoneStage(this.zone, this.fromScore);

  final int zone;
  final int fromScore;

  @override
  bool operator ==(Object other) =>
      other is ZoneStage && other.zone == zone && other.fromScore == fromScore;

  @override
  int get hashCode => Object.hash(zone, fromScore);
}

/// Bir uçuşun geçeceği bölgeler. Klasik rota yerine kullanılır (ör. Gece Uçuşu: yalnızca Rumeli Hisarı).
@immutable
class ZoneSelection {
  const ZoneSelection(this.stages);

  /// Skora göre artan, ilki 0'dan başlayan adımlar.
  final List<ZoneStage> stages;

  /// Klasik rota: rotadaki bütün bölgeler, kendi skor eşikleriyle.
  static ZoneSelection route() => ZoneSelection([
    for (final z in routeZones) ZoneStage(z, zones[z].startScore),
  ]);

  int get first => stages.first.zone;
  int get last => stages.last.zone;
  List<int> get zoneList => [for (final s in stages) s.zone];

  int zoneForScore(int score) {
    var z = stages.first.zone;
    for (final s in stages) {
      if (score >= s.fromScore) z = s.zone;
    }
    return z;
  }

  /// Geçerli mi: boş değil, ilk adım 0'da, skorlar artan, bölgeler rotada.
  bool get isValid {
    if (stages.isEmpty || stages.first.fromScore != 0) return false;
    for (var i = 0; i < stages.length; i++) {
      if (!routeZones.contains(stages[i].zone)) return false;
      if (i > 0 && stages[i].fromScore <= stages[i - 1].fromScore) return false;
    }
    return true;
  }

  List<List<int>> toJson() => [
    for (final s in stages) [s.zone, s.fromScore],
  ];

  static ZoneSelection? fromJson(Object? j) {
    if (j is! List) return null;
    final stages = <ZoneStage>[];
    for (final e in j) {
      if (e is! List || e.length != 2 || e[0] is! int || e[1] is! int) {
        return null;
      }
      stages.add(ZoneStage(e[0] as int, e[1] as int));
    }
    final sel = ZoneSelection(stages);
    return sel.isValid ? sel : null;
  }
}

/// Oynanış değiştiricileri: mevcut motorun parametreleri. Fizik, hız ve çarpışma geometrisi her zaman
/// klasik modla aynıdır; yalnızca geçit eğrisi kayması, simit sıklığı ve dinamik engeller değişir.
@immutable
class GameplayModifiers {
  const GameplayModifiers({
    this.gapScoreOffset = 0,
    this.pickupChanceScale = 1,
    this.hazards,
  });

  /// Geçit eğrisine eklenen skor kayması (negatif: başlangıç geçitleri daha geniş; eğri aynı).
  final int gapScoreOffset;

  /// Simit olasılığının katsayısı (1: klasik).
  final double pickupChanceScale;

  /// Dinamik engeller (null: yok).
  final HazardProfile? hazards;

  Map<String, Object> toJson() => {
    'gapScoreOffset': gapScoreOffset,
    'pickupChanceScale': pickupChanceScale,
    'hazards': ?hazards?.toJson(),
  };

  static GameplayModifiers? fromJson(Object? j) {
    if (j is! Map) return null;
    final gap = j['gapScoreOffset'], pick = j['pickupChanceScale'];
    if (gap is! int || pick is! num) return null;
    return GameplayModifiers(
      gapScoreOffset: gap.clamp(-30, 30),
      pickupChanceScale: pick.toDouble().clamp(0, 3),
      hazards: HazardProfile.fromJson(j['hazards']),
    );
  }
}

/// Sıralama skoru. Bir etkinliğin bütün uçuşları aynı kuralla puanlanır; farklı kurallı etkinlikler
/// aynı tablo döneminde karşılaştırılmaz (docs/20 §6).
@immutable
class ScoringPolicy {
  const ScoringPolicy({
    required this.id,
    required this.simitWeight,
    required this.label,
  });

  /// Geçilen engel sayısı (klasik skorla aynı).
  static const obstacles = ScoringPolicy(
    id: 'obstacles_v1',
    simitWeight: 0,
    label: 'Geçilen engel',
  );

  /// Simit Festivali: engel + 2 × simit.
  static const festival = ScoringPolicy(
    id: 'festival_v1',
    simitWeight: 2,
    label: 'Engel + 2 × simit',
  );

  static const all = [obstacles, festival];

  final String id;
  final int simitWeight;
  final String label;

  int score({required int obstacles, required int simits}) =>
      obstacles + simitWeight * simits;

  static ScoringPolicy? byId(String? id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// Etkinlikte bir skor eşiği: bir kez sezon puanı ve simit.
@immutable
class EventMilestone {
  const EventMilestone(this.score, this.seasonPoints, this.simits);

  final int score;
  final int seasonPoints;
  final int simits;
}

/// Etkinliğin tek seferlik ödülleri. Hiçbiri sıralamadaki yere bağlı değil (sunucu doğrulaması yok).
@immutable
class EventRewardPolicy {
  const EventRewardPolicy({
    required this.participationPoints,
    required this.milestones,
    this.simitCap,
  });

  /// Etkinlikteki ilk tamamlanan uçuş.
  final int participationPoints;
  final List<EventMilestone> milestones;

  /// Bu etkinlikte uçuşta toplanan simitlerden cüzdana geçebilecek en fazla miktar (Simit Festivali).
  /// null: sınır yok (klasik simit sıklığı).
  final int? simitCap;

  static const participationKey = 'participation';
  static String milestoneKey(int score) => 'score_$score';

  int get maxSeasonPoints =>
      participationPoints + milestones.fold(0, (s, m) => s + m.seasonPoints);
  int get maxSimits => milestones.fold(0, (s, m) => s + m.simits);
}

/// Bir etkinliğin bütün kuralları. Etkinlik başladıktan sonra değişmez: oynanış değişirse yeni bir
/// [generatorVersion] (ve gerekiyorsa yeni bir tablo) açılır.
@immutable
class EventDefinition {
  const EventDefinition({
    required this.eventId,
    required this.kind,
    required this.type,
    required this.title,
    required this.description,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.seed,
    required this.generatorVersion,
    required this.zoneSelection,
    required this.modifiers,
    required this.scoring,
    required this.rewards,
    this.leaderboardId,
    this.enabled = true,
    this.candidate = 0,
    this.validatedDepth = 0,
  });

  /// `cup_2026_w46`, `special_2026_w46`
  final String eventId;
  final EventKind kind;
  final EventType type;
  final String title;
  final String description;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final int seed;

  /// Etkinlik üreticisinin sürümü ([EventGenerators]).
  final int generatorVersion;
  final ZoneSelection zoneSelection;
  final GameplayModifiers modifiers;
  final ScoringPolicy scoring;
  final EventRewardPolicy rewards;

  /// Game Center tablosu (yalnızca kupa; özel etkinlikte null).
  final String? leaderboardId;
  final bool enabled;

  /// Seçilen aday tohumun sırası ve doğrulamanın ulaştığı derinlik (tanılama).
  final int candidate;
  final int validatedDepth;

  bool isActiveAt(DateTime t) {
    final u = t.toUtc();
    return enabled && !u.isBefore(startAtUtc) && u.isBefore(endAtUtc);
  }

  /// Parkurun deterministik tanımı: günlük parkur üreticisi (v2, klasik [GapGenerator]) aynı tohum
  /// akışıyla, bu etkinliğin geçit kayması ve simit sıklığıyla.
  DailyChallengeDefinition get course => DailyChallengeDefinition(
    challengeId: eventId,
    dateUtc: startAtUtc,
    seed: seed,
    generatorVersion: 2,
    candidate: candidate,
    validatedDepth: validatedDepth,
    difficultyProfile: DailyDifficultyProfile(
      id: '${type.name}_v$generatorVersion',
      gapScoreOffset: modifiers.gapScoreOffset,
      pickupChanceScale: modifiers.pickupChanceScale,
    ),
    zoneSequence: zoneSelection.zoneList,
  );

  /// Uzaktan yapılandırma için (henüz sunucu yok; uygulamayla gelen takvim kullanılır).
  Map<String, Object> toJson() => {
    'v': 1,
    'eventId': eventId,
    'kind': kind.name,
    'type': type.name,
    'title': title,
    'description': description,
    'startAtUtc': startAtUtc.toUtc().toIso8601String(),
    'endAtUtc': endAtUtc.toUtc().toIso8601String(),
    'seed': seed,
    'generatorVersion': generatorVersion,
    'zoneSelection': zoneSelection.toJson(),
    'modifiers': modifiers.toJson(),
    'scoring': scoring.id,
    'leaderboardId': ?leaderboardId,
    'enabled': enabled,
    'candidate': candidate,
    'validatedDepth': validatedDepth,
  };

  /// Bozuk ya da tanınmayan alanlı tanım null döner (oyun onu göstermez). Ödül politikası türden gelir
  /// (uzaktan ödül miktarı değiştirilemez).
  static EventDefinition? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['eventId'];
    final kind = EventKind.values.asNameMap()[j['kind']];
    final type = EventType.values.asNameMap()[j['type']];
    final start = j['startAtUtc'], end = j['endAtUtc'];
    final seed = j['seed'], gen = j['generatorVersion'];
    final zonesSel = ZoneSelection.fromJson(j['zoneSelection']);
    final mods = GameplayModifiers.fromJson(j['modifiers']);
    final scoring = ScoringPolicy.byId(j['scoring'] as String?);
    if (id is! String || id.isEmpty || kind == null || type == null) {
      return null;
    }
    if (start is! String || end is! String || seed is! int || gen is! int) {
      return null;
    }
    final s = DateTime.tryParse(start)?.toUtc();
    final e = DateTime.tryParse(end)?.toUtc();
    if (s == null || e == null || !e.isAfter(s)) return null;
    if (zonesSel == null || mods == null || scoring == null) return null;
    final title = j['title'], desc = j['description'], lb = j['leaderboardId'];
    final cand = j['candidate'], depth = j['validatedDepth'];
    return EventDefinition(
      eventId: id,
      kind: kind,
      type: type,
      title: title is String ? title : type.title,
      description: desc is String ? desc : type.description,
      startAtUtc: s,
      endAtUtc: e,
      seed: seed,
      generatorVersion: gen,
      zoneSelection: zonesSel,
      modifiers: mods,
      scoring: scoring,
      rewards: EventPresets.rewardsFor(kind, scoring),
      leaderboardId: lb is String ? lb : null,
      enabled: j['enabled'] != false,
      candidate: cand is int ? cand : 0,
      validatedDepth: depth is int ? depth : 0,
    );
  }
}

/// Etkinlik türlerinin kuralları (üretici sürümü 1). Değerlerin gerekçesi: docs/20 §4 ve §8.
abstract final class EventPresets {
  /// Kupa tablosu (App Store Connect'te tekrarlayan tablo olarak kurulmalı; docs/20 §6).
  static const cupLeaderboardId = GameCenterIds.weeklyCup;

  static ZoneSelection zonesFor(EventType t) => switch (t) {
    EventType.marathon => ZoneSelection.route(),
    // gündüzün en canlı kıyıları
    EventType.simitFestival => const ZoneSelection([
      ZoneStage(1, 0), // Galata
      ZoneStage(2, 15), // Kız Kulesi
      ZoneStage(7, 35), // Dolmabahçe
      ZoneStage(6, 60), // Ortaköy
    ]),
    // yalnızca gece bölgesi: ışıklı hisar ve fenerler
    EventType.nightFlight => const ZoneSelection([ZoneStage(4, 0)]),
    // rüzgârlı, açık kıyılar
    EventType.windMaster => const ZoneSelection([
      ZoneStage(5, 0), // Emirgan
      ZoneStage(6, 30), // Ortaköy
      ZoneStage(3, 60), // Boğaz Köprüsü
    ]),
  };

  static GameplayModifiers modifiersFor(EventType t) => switch (t) {
    // klasik dinamik engel kuralları (skor 120'den sonra), dondurulmuş değerlerle
    EventType.marathon => const GameplayModifiers(
      hazards: HazardProfile(
        fromScore: 120,
        flockChance: 0.2,
        gustChance: 0.16,
        cooldown: 2,
        gustAccel: 400,
      ),
    ),
    // simit neredeyse her geçitte; başlangıç geçitleri biraz geniş
    EventType.simitFestival => const GameplayModifiers(
      gapScoreOffset: -10,
      pickupChanceScale: 2.2,
    ),
    EventType.nightFlight => const GameplayModifiers(),
    // yalnızca hava akımı (sürü yok), erken ve sık; geçitler bunu dengelemek için biraz geniş
    EventType.windMaster => const GameplayModifiers(
      gapScoreOffset: -6,
      hazards: HazardProfile(
        fromScore: 3,
        flockChance: 0,
        gustChance: 0.4,
        cooldown: 1,
        gustAccel: 400,
      ),
    ),
  };

  static ScoringPolicy scoringFor(EventType t) => t == EventType.simitFestival
      ? ScoringPolicy.festival
      : ScoringPolicy.obstacles;

  /// Festival skoru engel sayısının kabaca 2,5 katı: eşikler buna göre ölçeklenir.
  static EventRewardPolicy rewardsFor(EventKind k, ScoringPolicy s) {
    final f = s.simitWeight > 0;
    int t(int v) => f ? (v * 2.5).round() : v;
    return switch (k) {
      EventKind.weeklyCup => EventRewardPolicy(
        participationPoints: 20,
        milestones: [
          EventMilestone(t(25), 15, 10),
          EventMilestone(t(50), 25, 15),
          EventMilestone(t(100), 40, 20),
        ],
        simitCap: f ? 100 : null,
      ),
      EventKind.special => EventRewardPolicy(
        participationPoints: 15,
        milestones: [
          EventMilestone(t(20), 10, 5),
          EventMilestone(t(40), 20, 10),
          EventMilestone(t(80), 30, 15),
        ],
        simitCap: f ? 60 : null,
      ),
    };
  }
}
