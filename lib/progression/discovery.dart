import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../game/day_cycle.dart';
import '../services/progress.dart';
import 'game_events.dart';
import 'progression_config.dart';

// Phase 2.3: İstanbul Keşif Albümü (docs/15_phase2_3_istanbul_discovery.md).
//
// Bölge kartpostalları, bölgeye özgü keşif hedefleri, rozetler ve albüm ödülü. Bölge keşfinin tek
// kaynağı [PlayerProgress.discoveredZones]'dur (Phase 2.1); ilk keşif XP'si orada verilir ve burada
// tekrar verilmez. Keşif ödülleri yalnızca simittir; albüm tamamlanınca mağazada satılmayan bir görünüm açılır.

/// Keşif hedefi türleri. Hepsi uçuş sonunda [RunResult.zoneStats] ile hesaplanır.
enum DiscoveryGoalKind {
  /// Bölgeye ulaş (bölge keşfedilince tamamlanır).
  reach,

  /// Bölgede toplam N simit topla (uçuşlar boyunca birikir).
  simitsInZone,

  /// Bölgede toplam N kıl payı geçiş yap (uçuşlar boyunca birikir).
  nearMissesInZone,

  /// Tek uçuşta bölgede N engel geç.
  obstaclesInZoneRun,

  /// Tek uçuşta N puana ulaş (hedef bölgenin puan aralığında).
  runScore,
}

/// Veri odaklı keşif hedefi. Kimlik kalıcıdır (kayıtta tutulur).
class DiscoveryGoal {
  const DiscoveryGoal({
    required this.id,
    required this.zone,
    required this.kind,
    required this.target,
    required this.rewardSimits,
  });

  final String id;

  /// Bölge sırası (0 Haliç ... 4 Rumeli Hisarı).
  final int zone;
  final DiscoveryGoalKind kind;
  final int target;
  final int rewardSimits;

  /// İlerleme uçuşlar boyunca birikir mi (yoksa tek uçuşun en iyisi mi)?
  bool get cumulative =>
      kind == DiscoveryGoalKind.simitsInZone ||
      kind == DiscoveryGoalKind.nearMissesInZone;

  String get title {
    final name = zones[zone].name;
    final loc = discoveryZones[zone].locative;
    return switch (kind) {
      DiscoveryGoalKind.reach => discoveryZones[zone].reachTitle,
      DiscoveryGoalKind.simitsInZone => '$loc $target simit topla',
      DiscoveryGoalKind.nearMissesInZone => '$loc $target kıl payı geçiş yap',
      DiscoveryGoalKind.obstaclesInZoneRun =>
        'Tek uçuşta $loc $target engel geç',
      DiscoveryGoalKind.runScore =>
        '$name rotasında tek uçuşta $target puana ulaş',
    };
  }
}

/// Kısa, doğrulanmış bilgi (kaynaklar: docs/15 §6).
class ZoneFact {
  const ZoneFact(this.label, this.text);

  /// "Tarih", "Mimari", "İstanbul için", "Az bilinen".
  final String label;
  final String text;
}

/// Bir bölgenin albüm sayfası: gerçek konum, kısa açıklama, bilgiler ve üç hedef.
class DiscoveryZone {
  const DiscoveryZone({
    required this.zone,
    required this.place,
    required this.lat,
    required this.lon,
    required this.locative,
    required this.reachTitle,
    required this.summary,
    required this.facts,
    required this.goals,
  });

  final int zone;

  /// Haritada işaretlenen gerçek yer (ör. "Galata Kulesi, Beyoğlu").
  final String place;

  /// Gerçek konum (WGS84). Harita işareti bundan hesaplanır ([MapProjection]).
  final double lat, lon;

  /// Bulunma hâli: "Haliç'te", "Galata'da" (Türkçe ek elle yazıldı).
  final String locative;
  final String reachTitle;

  /// Kartpostal arkasındaki kısa açıklama (bir cümle).
  final String summary;
  final List<ZoneFact> facts;
  final List<DiscoveryGoal> goals;
}

/// Ödül ve albüm ayarları (denge gerekçesi: docs/15 §7).
abstract final class DiscoveryConfig {
  /// Beş bölgenin rozetleri toplanınca açılan görünüm (mağazada satılmaz).
  static const albumRewardCosmetic = 'iznik';

  /// Bütün keşif hedeflerinin toplam simit ödülü (test: ekonomi dengesi).
  static int get totalGoalSimits => discoveryZones
      .expand((z) => z.goals)
      .fold(0, (a, g) => a + g.rewardSimits);
}

const discoveryZones = <DiscoveryZone>[
  DiscoveryZone(
    zone: 0,
    place: 'Haliç ve Süleymaniye',
    lat: 41.0315,
    lon: 28.9555,
    locative: "Haliç'te",
    reachTitle: "Haliç'e ulaş",
    summary:
        'Yolculuk, Süleymaniye’nin gölgesinde Haliç’in sakin sularında başlar.',
    facts: [
      ZoneFact(
        'Tarih',
        'Haliç, Alibey ve Kağıthane derelerinin denize ulaştığı yaklaşık 7,5 km uzunluğunda bir haliçtir; adı da "nehir ağzı" demektir.',
      ),
      ZoneFact(
        'Mimari',
        'Kartpostaldaki Süleymaniye Camii’ni Mimar Sinan, Kanuni Sultan Süleyman için yaptı: temeli 1550’de atıldı, 1557’de açıldı.',
      ),
      ZoneFact(
        'İstanbul için',
        'Bizans, Haliç’in ağzını Galata’ya uzanan büyük bir zincirle kapatıp düşman gemilerini dışarıda tutardı.',
      ),
      ZoneFact(
        'Az bilinen',
        '1453’te II. Mehmed zinciri aşmak için gemilerini Galata sırtlarından karadan yürütüp Haliç’e indirdi.',
      ),
    ],
    goals: [
      DiscoveryGoal(
        id: 'halic_reach',
        zone: 0,
        kind: DiscoveryGoalKind.reach,
        target: 1,
        rewardSimits: 5,
      ),
      DiscoveryGoal(
        id: 'halic_simits',
        zone: 0,
        kind: DiscoveryGoalKind.simitsInZone,
        target: 5,
        rewardSimits: 10,
      ),
      DiscoveryGoal(
        id: 'halic_obstacles',
        zone: 0,
        kind: DiscoveryGoalKind.obstaclesInZoneRun,
        target: 10,
        rewardSimits: 10,
      ),
    ],
  ),
  DiscoveryZone(
    zone: 1,
    place: 'Galata Kulesi, Beyoğlu',
    lat: 41.0256,
    lon: 28.9742,
    locative: "Galata'da",
    reachTitle: "Galata'ya ulaş",
    summary:
        'Ceneviz’den kalma taş kule, Haliç’in ve Boğaz’ın ağzını gözetler.',
    facts: [
      ZoneFact('Tarih', 'Galata Kulesi’ni Cenevizliler 1348’de inşa etti.'),
      ZoneFact(
        'Mimari',
        'İlk adı, tepesindeki haçtan ötürü "Kutsal Haç Kulesi"ydi.',
      ),
      ZoneFact(
        'İstanbul için',
        '18. yüzyıldan itibaren şehrin yangın gözetleme kulesi olarak kullanıldı.',
      ),
      ZoneFact(
        'Az bilinen',
        'Kule, sergi alanı ve müze olarak düzenlenip 6 Ekim 2020’de yeniden açıldı.',
      ),
    ],
    goals: [
      DiscoveryGoal(
        id: 'galata_reach',
        zone: 1,
        kind: DiscoveryGoalKind.reach,
        target: 1,
        rewardSimits: 10,
      ),
      DiscoveryGoal(
        id: 'galata_near',
        zone: 1,
        kind: DiscoveryGoalKind.nearMissesInZone,
        target: 3,
        rewardSimits: 10,
      ),
      DiscoveryGoal(
        id: 'galata_score',
        zone: 1,
        kind: DiscoveryGoalKind.runScore,
        target: 25,
        rewardSimits: 15,
      ),
    ],
  ),
  DiscoveryZone(
    zone: 2,
    place: 'Kız Kulesi, Üsküdar açıkları',
    lat: 41.0211,
    lon: 29.0041,
    locative: "Kız Kulesi'nde",
    reachTitle: "Kız Kulesi'ne ulaş",
    summary: 'Üsküdar kıyısının hemen açığında, küçük bir adacıkta gün batımını bekler.',
    facts: [
      ZoneFact(
        'Tarih',
        '1110’da Bizans İmparatoru I. Aleksios Komnenos, adacığa taş surla korunan ahşap bir kule yaptırdı.',
      ),
      ZoneFact(
        'Mimari',
        'Kule, Üsküdar kıyısına yaklaşık 200 metre uzaklıktaki küçük bir adacığın üstündedir.',
      ),
      ZoneFact(
        'İstanbul için',
        '1721 yangınından sonra yeniden yapılan kule deniz feneri olarak kullanıldı.',
      ),
      ZoneFact(
        'Az bilinen',
        '2021–2023 restorasyonunda adanın çevresine yaklaşık 25 metre derinlikte 201 kazık çakıldı.',
      ),
    ],
    goals: [
      DiscoveryGoal(
        id: 'kizkulesi_reach',
        zone: 2,
        kind: DiscoveryGoalKind.reach,
        target: 1,
        rewardSimits: 10,
      ),
      DiscoveryGoal(
        id: 'kizkulesi_simits',
        zone: 2,
        kind: DiscoveryGoalKind.simitsInZone,
        target: 10,
        rewardSimits: 15,
      ),
      DiscoveryGoal(
        id: 'kizkulesi_obstacles',
        zone: 2,
        kind: DiscoveryGoalKind.obstaclesInZoneRun,
        target: 15,
        rewardSimits: 15,
      ),
    ],
  ),
  DiscoveryZone(
    zone: 3,
    place: 'Boğaziçi Köprüsü, Ortaköy–Beylerbeyi',
    lat: 41.0458,
    lon: 29.0335,
    locative: "Köprü'de",
    reachTitle: "Boğaz Köprüsü'ne ulaş",
    summary: 'Avrupa ile Asya’yı birleştiren çelik köprü, akşam ışıklarıyla.',
    facts: [
      ZoneFact(
        'Tarih',
        'Köprü, Cumhuriyet’in 50. yılının ertesi günü, 30 Ekim 1973’te açıldı; 2016’dan beri adı 15 Temmuz Şehitler Köprüsü.',
      ),
      ZoneFact(
        'Mimari',
        'Bir asma köprüdür: iki kulesi arasındaki ana açıklık 1.074 metre, kuleler 165 metre yüksekliktedir.',
      ),
      ZoneFact(
        'İstanbul için',
        'Avrupa yakasında Ortaköy’ü Asya yakasında Beylerbeyi’ne bağlar.',
      ),
      ZoneFact(
        'Az bilinen',
        'Köprü 2007’den beri geceleri renk ve desen değiştiren LED ışıklarla aydınlatılıyor.',
      ),
    ],
    goals: [
      DiscoveryGoal(
        id: 'kopru_reach',
        zone: 3,
        kind: DiscoveryGoalKind.reach,
        target: 1,
        rewardSimits: 15,
      ),
      DiscoveryGoal(
        id: 'kopru_near',
        zone: 3,
        kind: DiscoveryGoalKind.nearMissesInZone,
        target: 5,
        rewardSimits: 15,
      ),
      DiscoveryGoal(
        id: 'kopru_score',
        zone: 3,
        kind: DiscoveryGoalKind.runScore,
        target: 75,
        rewardSimits: 20,
      ),
    ],
  ),
  DiscoveryZone(
    zone: 4,
    place: 'Rumeli Hisarı, Sarıyer',
    lat: 41.0847,
    lon: 29.0564,
    locative: "Rumeli Hisarı'nda",
    reachTitle: "Rumeli Hisarı'na ulaş",
    summary: 'Boğaz’ın en dar yerinde, gece yıldızların altında taş surlar.',
    facts: [
      ZoneFact(
        'Tarih',
        'II. Mehmed hisarı 1452’de, İstanbul’un fethinden bir yıl önce, birkaç ay içinde yaptırdı.',
      ),
      ZoneFact(
        'Mimari',
        'Üç büyük kulesi, yapımını yöneten paşaların adını taşır: Halil Paşa, Zağanos Paşa ve Sarıca Paşa.',
      ),
      ZoneFact(
        'İstanbul için',
        'Boğaz’ın en dar yerinde, yaklaşık 660 metre ötedeki Anadolu Hisarı’nın tam karşısındadır.',
      ),
      ZoneFact(
        'Az bilinen',
        'Diğer adı "Boğazkesen"dir; 1960’tan beri müze olarak ziyaret edilir.',
      ),
    ],
    goals: [
      DiscoveryGoal(
        id: 'rumeli_reach',
        zone: 4,
        kind: DiscoveryGoalKind.reach,
        target: 1,
        rewardSimits: 15,
      ),
      DiscoveryGoal(
        id: 'rumeli_simits',
        zone: 4,
        kind: DiscoveryGoalKind.simitsInZone,
        target: 8,
        rewardSimits: 20,
      ),
      DiscoveryGoal(
        id: 'rumeli_score',
        zone: 4,
        kind: DiscoveryGoalKind.runScore,
        target: 100,
        rewardSimits: 25,
      ),
    ],
  ),
];

DiscoveryGoal? discoveryGoalById(String id) {
  for (final z in discoveryZones) {
    for (final g in z.goals) {
      if (g.id == id) return g;
    }
  }
  return null;
}

/// Haritanın izdüşümü (art/_source/pixel/map.js ile aynı kutu): enlem/boylam → harita pikseli.
abstract final class MapProjection {
  static const size = 160.0;
  static const lon0 = 28.925, lon1 = 29.085, lat0 = 40.990, lat1 = 41.110;

  /// 0..[size] aralığında harita pikseli (kuzey yukarıda).
  static ({double x, double y}) toMap(double lat, double lon) => (
    x: (lon - lon0) / (lon1 - lon0) * size,
    y: (lat1 - lat) / (lat1 - lat0) * size,
  );
}

/// Keşif albümünün kalıcı durumu ([PlayerProgress.discovery], kayıt anahtarı `discovery`).
@immutable
class DiscoveryState {
  const DiscoveryState({
    this.firstSeen = const {},
    this.legacyZones = const {},
    this.zoneRecords = const {},
    this.progress = const {},
    this.completed = const {},
    this.badges = const {},
    this.albumCompletedAt,
  });

  static const empty = DiscoveryState();

  /// Bölgenin ilk keşif zamanı (bu sürümden itibaren tutulur).
  final Map<int, DateTime> firstSeen;

  /// Albümden önce (1.0.0–1.2.0) keşfedilmiş bölgeler: keşif tarihi bilinmiyor, uydurulmaz.
  final Set<int> legacyZones;

  /// Tek uçuşta bölgede geçilen en çok engel (bölge rekoru).
  final Map<int, int> zoneRecords;

  /// Hedef → ilerleme (biriken hedeflerde toplam, tek uçuşluk hedeflerde en iyi değer; hedefte durur).
  final Map<String, int> progress;

  /// Tamamlanan hedefler → zaman. Ödül defteridir: burada olan hedefin ödülü bir daha verilmez.
  final Map<String, DateTime> completed;

  /// Üç hedefi de tamamlanan bölgelerin rozetleri → zaman.
  final Map<int, DateTime> badges;

  /// Beş rozetin tamamlandığı an (albüm ödülü bir kez verilir).
  final DateTime? albumCompletedAt;

  int progressOf(DiscoveryGoal g) =>
      completed.containsKey(g.id) ? g.target : (progress[g.id] ?? 0);

  bool isDone(DiscoveryGoal g) => completed.containsKey(g.id);

  int doneInZone(int zone) => discoveryZones[zone].goals.where(isDone).length;

  /// Bölgenin tamamlanma oranı: 0..1 (üç hedef eşit ağırlıkta, kısmi ilerleme sayılır).
  double zoneFraction(int zone) {
    final goals = discoveryZones[zone].goals;
    var sum = 0.0;
    for (final g in goals) {
      sum += (progressOf(g) / g.target).clamp(0.0, 1.0);
    }
    return sum / goals.length;
  }

  /// Albümün tamamlanma oranı (bütün hedefler).
  double get albumFraction {
    var sum = 0.0;
    for (var z = 0; z < discoveryZones.length; z++) {
      sum += zoneFraction(z);
    }
    return sum / discoveryZones.length;
  }

  int get goalsDone =>
      completed.keys.where((id) => discoveryGoalById(id) != null).length;
  static int get goalsTotal =>
      discoveryZones.fold(0, (a, z) => a + z.goals.length);

  DiscoveryState copyWith({
    Map<int, DateTime>? firstSeen,
    Set<int>? legacyZones,
    Map<int, int>? zoneRecords,
    Map<String, int>? progress,
    Map<String, DateTime>? completed,
    Map<int, DateTime>? badges,
    DateTime? albumCompletedAt,
  }) => DiscoveryState(
    firstSeen: firstSeen ?? this.firstSeen,
    legacyZones: legacyZones ?? this.legacyZones,
    zoneRecords: zoneRecords ?? this.zoneRecords,
    progress: progress ?? this.progress,
    completed: completed ?? this.completed,
    badges: badges ?? this.badges,
    albumCompletedAt: albumCompletedAt ?? this.albumCompletedAt,
  );

  Map<String, Object> toJson() {
    String t(DateTime d) => d.toUtc().toIso8601String();
    Map<String, Object> zoneMap<V>(Map<int, V> m, Object Function(V) f) => {
      for (final e in m.entries) '${e.key}': f(e.value),
    };
    return {
      'firstSeen': zoneMap(firstSeen, t),
      'legacyZones': legacyZones.toList()..sort(),
      'zoneRecords': zoneMap(zoneRecords, (v) => v),
      'progress': progress,
      'completed': {for (final e in completed.entries) e.key: t(e.value)},
      'badges': zoneMap(badges, t),
      if (albumCompletedAt != null) 'albumCompletedAt': t(albumCompletedAt!),
    };
  }

  /// Toleranslı okuma: bozuk bir alan yalnızca kendisini etkiler; geçersiz bölge ve sayılar atlanır.
  factory DiscoveryState.fromJson(Map<Object?, Object?> j) {
    bool validZone(int z) => z >= 0 && z < zones.length;
    int? zoneKey(Object? k) {
      final z = k is String ? int.tryParse(k) : null;
      return z != null && validZone(z) ? z : null;
    }

    DateTime? time(Object? v) => v is String ? DateTime.tryParse(v) : null;
    int? count(Object? v) =>
        v is int && v >= 0 ? math.min(v, ProgressionConfig.maxTotalXp) : null;
    Map<int, V> zoneMap<V>(Object? raw, V? Function(Object?) f) {
      if (raw is! Map) return const {};
      return {
        for (final e in raw.entries)
          if (zoneKey(e.key) != null && f(e.value) != null)
            zoneKey(e.key)!: f(e.value) as V,
      };
    }

    final prog = j['progress'],
        done = j['completed'],
        legacy = j['legacyZones'];
    return DiscoveryState(
      firstSeen: zoneMap(j['firstSeen'], time),
      legacyZones: legacy is List
          ? legacy.whereType<int>().where(validZone).toSet()
          : const {},
      zoneRecords: zoneMap(j['zoneRecords'], count),
      progress: prog is Map
          ? {
              for (final e in prog.entries)
                if (e.key is String && count(e.value) != null)
                  e.key as String: count(e.value)!,
            }
          : const {},
      completed: done is Map
          ? {
              for (final e in done.entries)
                if (e.key is String && time(e.value) != null)
                  e.key as String: time(e.value)!,
            }
          : const {},
      badges: zoneMap(j['badges'], time),
      albumCompletedAt: time(j['albumCompletedAt']),
    );
  }
}

/// Bir uçuşun keşif sonuçları (oyun sonu özeti).
class DiscoveryOutcome {
  const DiscoveryOutcome({
    this.newPostcards = const [],
    this.completedGoals = const [],
    this.newBadges = const [],
    this.albumCompleted = false,
    this.rewardCosmetic,
  });

  static const none = DiscoveryOutcome();

  /// Bu uçuşta ilk kez açılan kartpostallar (bölge sırası).
  final List<int> newPostcards;
  final List<DiscoveryGoal> completedGoals;
  final List<int> newBadges;
  final bool albumCompleted;

  /// Albüm ödülü olarak açılan görünüm (zaten sahip olunuyorsa null).
  final String? rewardCosmetic;

  int get simits => completedGoals.fold(0, (a, g) => a + g.rewardSimits);
  bool get isEmpty =>
      newPostcards.isEmpty && completedGoals.isEmpty && newBadges.isEmpty;
}

/// Hedef değerlendirmesi: uçuşun bölge istatistiklerinden yeni ilerleme. Ulaşma hedefleri
/// [PlayerProgress.discoveredZones]'a bakar (bölge keşfi zaten yazılmış olmalı).
int _goalValue(DiscoveryGoal g, PlayerProgress p, RunResult r) {
  final s = r.zoneStats[g.zone] ?? const ZoneRunStats();
  return switch (g.kind) {
    DiscoveryGoalKind.reach => p.discoveredZones.contains(g.zone) ? 1 : 0,
    DiscoveryGoalKind.simitsInZone => s.simits,
    DiscoveryGoalKind.nearMissesInZone => s.nearMisses,
    DiscoveryGoalKind.obstaclesInZoneRun => s.obstacles,
    DiscoveryGoalKind.runScore => math.max(0, r.score),
  };
}

/// Uçuşun keşif hesabı (saf). [p]'de bu uçuşun bölge keşfi yazılmış olmalı ([settleRun] sırası).
/// İdempotentlik [settleRun]'ın runId kontrolündedir; ayrıca her hedefin ödülü [DiscoveryState.completed]
/// defteriyle tek seferliktir, rozet ve albüm ödülü de kayıtlı oldukları için tekrar verilmez.
(PlayerProgress, DiscoveryOutcome) settleDiscovery(
  PlayerProgress p,
  RunResult r,
  List<int> newZones,
  DateTime now,
) {
  var d = p.discovery;
  final firstSeen = {...d.firstSeen};
  final postcards = <int>[];
  for (final z in newZones) {
    if (!firstSeen.containsKey(z) && !d.legacyZones.contains(z)) {
      firstSeen[z] = now;
      postcards.add(z);
    }
  }
  final records = {...d.zoneRecords};
  for (final e in r.zoneStats.entries) {
    if (e.key < 0 || e.key >= zones.length) continue;
    final o = math.max(0, e.value.obstacles);
    if (o > (records[e.key] ?? 0)) records[e.key] = o;
  }

  final progress = {...d.progress};
  final completed = {...d.completed};
  final done = <DiscoveryGoal>[];
  for (final zone in discoveryZones) {
    for (final g in zone.goals) {
      // keşfedilmemiş bölgenin hedefleri ilerlemez (kilitli kart %0 kalır)
      if (completed.containsKey(g.id) || !p.discoveredZones.contains(g.zone)) {
        continue;
      }
      final v = math.max(0, _goalValue(g, p, r));
      final prev = progress[g.id] ?? 0;
      final next = math.min(
        g.target,
        g.cumulative ? prev + v : math.max(prev, v),
      );
      if (next >= g.target) {
        completed[g.id] = now;
        progress.remove(g.id);
        done.add(g);
      } else if (next != prev) {
        progress[g.id] = next;
      }
    }
  }

  d = d.copyWith(
    firstSeen: firstSeen,
    zoneRecords: records,
    progress: progress,
    completed: completed,
  );
  final (withBadges, badges, album, cosmetic) = _awardBadges(p, d, now);
  return (
    withBadges.copyWith(
      bonusSimits:
          withBadges.bonusSimits + done.fold(0, (a, g) => a + g.rewardSimits),
    ),
    DiscoveryOutcome(
      newPostcards: postcards,
      completedGoals: done,
      newBadges: badges,
      albumCompleted: album,
      rewardCosmetic: cosmetic,
    ),
  );
}

/// Rozetler ve albüm ödülü (tek seferlik). Albüm ödülü görünümü mevcut sahiplik kümesine eklenir;
/// Phase 2.2 sahiplik kuralları aynen geçerlidir (seçim yine oyuncunun).
(PlayerProgress, List<int>, bool, String?) _awardBadges(
  PlayerProgress p,
  DiscoveryState d,
  DateTime now,
) {
  final badges = {...d.badges};
  final fresh = <int>[];
  for (final z in discoveryZones) {
    if (badges.containsKey(z.zone)) continue;
    if (z.goals.every((g) => d.completed.containsKey(g.id))) {
      badges[z.zone] = now;
      fresh.add(z.zone);
    }
  }
  d = d.copyWith(badges: badges);
  var albumNow = false;
  String? cosmetic;
  var unlocked = p.unlockedCosmetics;
  if (d.albumCompletedAt == null && badges.length == discoveryZones.length) {
    d = d.copyWith(albumCompletedAt: now);
    albumNow = true;
    const id = DiscoveryConfig.albumRewardCosmetic;
    if (!unlocked.contains(id)) {
      unlocked = {...unlocked, id};
      cosmetic = id;
    }
  }
  return (
    p.copyWith(discovery: d, unlockedCosmetics: unlocked),
    fresh,
    albumNow,
    cosmetic,
  );
}

/// Albümden önceki kayıtlar (v1/v2) için tek seferlik geçiş: [reconcileDiscovery] boş albümle.
PlayerProgress migrateDiscovery(PlayerProgress p, DateTime now) =>
    reconcileDiscovery(p.copyWith(discovery: DiscoveryState.empty), now);

/// Albümü profildeki bölge keşfiyle uzlaştırır. Albüm kaydı olmadan keşfedilmiş bölgeler (eski sürümler
/// ya da albüm alanını tanımayan bir sürümle oynanan uçuşlar) kartpostal olarak açılır ("önceki sürümde
/// keşfedildi"; tarih uydurulmaz) ve "ulaş" hedefleri tamamlanır (simit ödülüyle; ilk keşif XP'si zaten
/// verildiği için XP verilmez). Bölge bazlı istatistik eski sürümlerde tutulmadığı için diğer hedefler
/// kaldıkları yerden (yoksa sıfırdan) devam eder. Zaten tamamlanmış hedefe dokunmaz (idempotent).
PlayerProgress reconcileDiscovery(PlayerProgress p, DateTime now) {
  final d = p.discovery;
  final legacy = {...d.legacyZones};
  final completed = {...d.completed};
  final progress = {...d.progress};
  var reward = 0;
  for (final z in discoveryZones) {
    if (!p.discoveredZones.contains(z.zone)) continue;
    if (!d.firstSeen.containsKey(z.zone)) legacy.add(z.zone);
    for (final g in z.goals) {
      if (g.kind != DiscoveryGoalKind.reach || completed.containsKey(g.id)) {
        continue;
      }
      completed[g.id] = now;
      progress.remove(g.id);
      reward += g.rewardSimits;
    }
  }
  final next = d.copyWith(
    legacyZones: legacy,
    completed: completed,
    progress: progress,
  );
  final (withBadges, _, _, _) = _awardBadges(p, next, now);
  return withBadges.copyWith(bonusSimits: withBadges.bonusSimits + reward);
}
