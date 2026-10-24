import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../game/config.dart';
import '../game/day_cycle.dart';
import '../game/logic/pickup_rules.dart';
import 'daily_rng.dart';

// Phase 2.5: Günün Uçuşu (docs/17_phase2_5_daily_challenge.md).
//
// Bu dosya saf mantıktır (Flame'e bağlı değil): oyun modları, günlük challenge tanımı, deterministik
// parkur üreticisi ve parkurun oynanabilirliğini önceden sınayan simülasyon.

/// Uçuşun oyun modu. Tek motor: fark yalnızca parkur kaynağında ve uçuş sonu hesabında.
enum RunMode {
  /// Sonsuz uçuş (1.0'dan beri): mevcut rekor, mevcut zorluk ve mevcut Game Center tabloları.
  classic,

  /// Günün Uçuşu, dereceli deneme: günlük hak harcar, günlük rekor/ödül/sıralama.
  dailyRanked,

  /// Günün Uçuşu, antrenman: aynı parkur; hak, günlük ödül ve günlük sıralama yok.
  dailyPractice;

  bool get isDaily => this != classic;
}

/// UTC gün anahtarı (`2026-10-24`). Günlük challenge bütün dünyada aynı anda başlar ve biter.
String utcDayKey(DateTime t) {
  final u = t.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}';
}

DateTime utcDayStart(DateTime t) {
  final u = t.toUtc();
  return DateTime.utc(u.year, u.month, u.day);
}

/// `2026-10-24` → 2026-10-24 00:00 UTC (geçersizse null).
DateTime? parseUtcDayKey(String key) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  if (m == null) return null;
  final d = DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  return utcDayKey(d) == key ? d : null;
}

/// Zorluk profili: geçit yüksekliği ve simit sıklığı. Hız ve fizik klasik modla aynıdır.
@immutable
class DailyDifficultyProfile {
  const DailyDifficultyProfile({
    required this.id,
    this.gapScoreOffset = 0,
    this.pickupChanceScale = 1,
  });

  /// Klasik eğri: n. engelin geçidi, oyuncu ona ulaştığında sahip olduğu skorun (n) klasik geçidi.
  static const standard = DailyDifficultyProfile(id: 'standard');

  final String id;

  /// Geçit eğrisine eklenen skor kayması (0: klasik eğri).
  final int gapScoreOffset;
  final double pickupChanceScale;

  double gapHeight(GameConfig c, int index) =>
      c.gapForScore(index + gapScoreOffset);
  double pickupChance(GameConfig c) =>
      (c.pickupChance * pickupChanceScale).clamp(0.0, 1.0);
}

/// Günlük ödül politikası (tek seferlik; docs/17 §9).
@immutable
class DailyRewardPolicy {
  const DailyRewardPolicy({
    required this.firstFlightXp,
    required this.scoreRewards,
  });

  /// Eşikler bölge sınırlarıyla aynı (Galata 15, Kız Kulesi 35, Boğaz 60): oyuncu hedefi haritadan tanır.
  static const v1 = DailyRewardPolicy(
    firstFlightXp: 5,
    scoreRewards: [(15, 10), (35, 15), (60, 20)],
  );

  final int firstFlightXp;

  /// (skor eşiği, simit). Her eşik challenge başına bir kez.
  final List<(int, int)> scoreRewards;

  static const firstFlightKey = 'first_flight';
  static String scoreKey(int threshold) => 'score_$threshold';

  int get maxSimits => scoreRewards.fold(0, (s, r) => s + r.$2);
}

/// Bir günün challenge tanımı. Aynı gün için her cihazda aynıdır ve gün başladıktan sonra değişmez.
@immutable
class DailyChallengeDefinition {
  const DailyChallengeDefinition({
    required this.challengeId,
    required this.dateUtc,
    required this.seed,
    required this.generatorVersion,
    required this.candidate,
    required this.validatedDepth,
    this.difficultyProfile = DailyDifficultyProfile.standard,
    this.zoneSequence = const [0, 1, 2, 3, 4],
    this.rewardPolicy = DailyRewardPolicy.v1,
  });

  /// `daily_2026_10_24`
  final String challengeId;

  /// Günün başlangıcı (00:00 UTC).
  final DateTime dateUtc;
  final int seed;

  /// Parkur üreticisinin sürümü ([DailyGenerators]).
  final int generatorVersion;

  /// Seçilen aday tohumun sırası (0 = ilk aday doğrulamayı geçti).
  final int candidate;

  /// Doğrulama simülasyonunun bu parkurda ulaştığı skor.
  final int validatedDepth;
  final DailyDifficultyProfile difficultyProfile;

  /// Bölgelerin sırası (v1: Haliç → Rumeli Hisarı, klasik modla aynı skor sınırları).
  final List<int> zoneSequence;
  final DailyRewardPolicy rewardPolicy;

  String get dayKey => utcDayKey(dateUtc);
  DateTime get endsUtc => dateUtc.add(const Duration(days: 1));

  static String idFor(String dayKey) => 'daily_${dayKey.replaceAll('-', '_')}';

  /// `daily_2026_10_24` → `2026-10-24` (geçersizse null).
  static String? dayKeyOf(String challengeId) {
    final m = RegExp(r'^daily_(\d{4})_(\d{2})_(\d{2})$')
        .firstMatch(challengeId);
    if (m == null) return null;
    final key = '${m[1]}-${m[2]}-${m[3]}';
    return parseUtcDayKey(key) == null ? null : key;
  }
}

/// Parkurdaki bir engel çifti.
@immutable
class ObstacleSpec {
  const ObstacleSpec({
    required this.gapCenter,
    required this.gapHeight,
    this.pickupY,
  });

  final double gapCenter;
  final double gapHeight;

  /// Geçitteki simidin dikey konumu (yoksa null).
  final double? pickupY;
}

/// Günlük parkur: n. engel yalnızca tohuma, üretici sürümüne ve n'ye bağlıdır. Kare hızı, ekran
/// genişliği, oyuncunun skoru ya da görsel efektlerin rastgeleliği sonucu değiştirmez.
class DailyCourse {
  DailyCourse(this.definition, {this.config = const GameConfig()})
    : assert(definition.generatorVersion == 1),
      _gaps = DailyRng(DailyRng.hash('gaps:${definition.seed}')),
      _pickups = DailyRng(DailyRng.hash('pickups:${definition.seed}'));

  final DailyChallengeDefinition definition;
  final GameConfig config;
  final DailyRng _gaps;
  final DailyRng _pickups;
  final List<ObstacleSpec> _specs = [];

  /// Engeller arası yatay mesafe (klasikle aynı).
  double get spacing => config.obstacleSpacing;

  /// İlk engelin kuşa uzaklığı: her ekranda aynı (klasikte ekran genişliğine bağlıdır). En geniş
  /// desteklenen ekranda (3:4) bile engel görünür alanın dışında doğar.
  static const firstObstacleDistance = 1100.0;

  /// Günün Uçuşu'nda kuşun yatay konumu: her ekranda aynı (klasikte ekran genişliğinin %30'u).
  /// Böylece engel konumları ve tüm sınır kararları cihazdan cihaza bit düzeyinde aynıdır.
  static const birdX = 300.0;

  /// n. engelin sol kenarı, parkur başından beri kayılan mesafe [scroll] sonrasında.
  double leftOf(int i, double scroll) =>
      birdX + firstObstacleDistance + i * spacing - scroll;

  ObstacleSpec at(int index) {
    while (_specs.length <= index) {
      _specs.add(_generate(_specs.length));
    }
    return _specs[index];
  }

  // Üretici v1. Bu fonksiyonun çıktısı değişirse yeni bir üretici sürümü açılmalıdır (DailyGenerators).
  ObstacleSpec _generate(int i) {
    final c = config;
    final p = definition.difficultyProfile;
    final height = p.gapHeight(c, i);
    final minCenter = c.gapMarginTop + height / 2;
    final maxCenter = c.worldHeight - c.gapMarginBottom - height / 2;
    var low = minCenter, high = maxCenter;
    if (i > 0) {
      final last = _specs[i - 1].gapCenter;
      low = math.max(low, last - c.maxGapShift);
      high = math.min(high, last + c.maxGapShift);
    }
    final center = low + _gaps.nextDouble() * (high - low);
    // Her engel için iki sayı her zaman çekilir: simit olsa da olmasa da akış hizalı kalır
    final roll = _pickups.nextDouble();
    final pos = _pickups.nextDouble();
    double? pickupY;
    if (i > 0 && roll < p.pickupChance(c)) {
      final band = PickupRules.reachableBand(
        config: c,
        gapCenter: center,
        gapHeight: height,
      );
      if (band != null) {
        final mid = (band.top + band.bottom) / 2;
        pickupY = mid + (pos - 0.5) * (band.bottom - band.top) * 0.7;
      }
    }
    return ObstacleSpec(gapCenter: center, gapHeight: height, pickupY: pickupY);
  }
}

/// Doğrulama sonucu.
@immutable
class CourseCheck {
  const CourseCheck({
    required this.depth,
    required this.tightest,
    required this.problems,
  });

  /// Geçilebildiği kanıtlanan engel sayısı.
  final int depth;

  /// En dar anda kuşun bulunabileceği yükseklik aralığı (dünya birimi). Küçükse parkur o noktada piksel
  /// hassasiyeti ister.
  final double tightest;

  /// Kural ihlalleri (boş = kurallara uygun).
  final List<String> problems;

  bool get passes =>
      problems.isEmpty &&
      depth >= CourseValidator.requiredDepth &&
      tightest >= CourseValidator.minSafeBand;
}

/// Parkurun adil ve oynanabilir olduğunu önceden sınar:
///  1. kurallar: geçit güvenli bantta, ardışık kayma sınırlı, simit ulaşılabilir bantta;
///  2. erişilebilirlik: oyunla aynı fizik ve çarpışma geometrisiyle, kuşun ulaşabileceği bütün durumlar
///     izlenir. [requiredDepth] engelin hepsi geçilebilir olmalı ve hiçbir anda kuşun güvenli yükseklik
///     aralığı [minSafeBand]'den dar olmamalı (piksel hassasiyeti isteyen geçiş yok).
abstract final class CourseValidator {
  /// Son bölgenin (Rumeli Hisarı, 90) da ötesi: oyuncuların gerçekçi olarak ulaşacağı her yer sınanır.
  static const requiredDepth = 100;

  /// Kuş çapının ~üçte biri.
  static const minSafeBand = 24.0;

  static CourseCheck check(DailyCourse course, {int maxScore = requiredDepth}) {
    final c = course.config;
    final problems = <String>[];
    for (var i = 0; i < maxScore + 2; i++) {
      final s = course.at(i);
      if (s.gapCenter - s.gapHeight / 2 < c.gapMarginTop - 0.001 ||
          s.gapCenter + s.gapHeight / 2 >
              c.worldHeight - c.gapMarginBottom + 0.001) {
        problems.add('gap_out_of_band@$i');
      }
      if (i > 0 &&
          (s.gapCenter - course.at(i - 1).gapCenter).abs() >
              c.maxGapShift + 0.001) {
        problems.add('gap_shift@$i');
      }
      final py = s.pickupY;
      if (py != null) {
        final band = PickupRules.reachableBand(
          config: c,
          gapCenter: s.gapCenter,
          gapHeight: s.gapHeight,
        );
        if (band == null || py < band.top || py > band.bottom) {
          problems.add('pickup@$i');
        }
      }
    }
    final (:depth, :tightest) = explore(course, maxScore: maxScore);
    return CourseCheck(depth: depth, tightest: tightest, problems: problems);
  }

  /// Erişilebilirlik simülasyonu: kuşun ulaşabileceği tüm (yükseklik, hız) durumları sabit adımla, oyunla
  /// aynı fizikle ilerletilir. Her [_decisionSteps] adımda (saniyede 20 karar) her durum için "çırp" ve
  /// "çırpma" denenir; engele ya da suya değen durumlar elenir. Hiç durum kalmazsa parkur o engelde
  /// fiziksel olarak geçilemez demektir. Dönen değer: geçilebildiği kanıtlanan engel sayısı (en fazla
  /// [maxScore]) ve engel yanındaki en dar güvenli yükseklik aralığı. Aynı 4 birimlik yükseklik kutusunda yalnızca en küçük ve en büyük hızlı durum tutulur; bu yalnızca
  /// temkinli yönde hata yapabilir (çok nadiren geçilebilir bir parkuru reddetmek).
  static ({int depth, double tightest}) explore(
    DailyCourse course, {
    int maxScore = requiredDepth,
  }) {
    final c = course.config;
    final r = c.birdHitRadius;
    final dt = c.physicsStep;
    const birdX = DailyCourse.birdX;
    final first = birdX + DailyCourse.firstObstacleDistance;
    // ilk dokunuş oyunu başlatır ve çırptırır
    var ys = <double>[c.worldHeight * 0.42];
    var vs = <double>[c.flapVelocity];
    var scroll = 0.0;
    var score = 0;
    var tightest = double.infinity;
    for (var step = 0; step < 120 * 600; step++) {
      if (step > 0 && step % _decisionSteps == 0) {
        // karar: her durum için çırpmayan ve çırpan kopya. Aynı yükseklik kutusundaki durumlardan yalnızca
        // en küçük ve en büyük hızlı olanlar tutulur (aradaki hızlar bu ikisinin arasında kalan yollar izler)
        final minV = <int, int>{}, maxV = <int, int>{};
        final cy = <double>[], cv = <double>[];
        void add(double y, double v) {
          final key = (y / _yBin).floor();
          final lo = minV[key], hi = maxV[key];
          if (lo == null) {
            minV[key] = maxV[key] = cy.length;
            cy.add(y);
            cv.add(v);
          } else if (v < cv[lo]) {
            if (lo == hi) {
              minV[key] = cy.length;
              cy.add(y);
              cv.add(v);
            } else {
              cy[lo] = y;
              cv[lo] = v;
            }
          } else if (v > cv[hi!]) {
            if (lo == hi) {
              maxV[key] = cy.length;
              cy.add(y);
              cv.add(v);
            } else {
              cy[hi] = y;
              cv[hi] = v;
            }
          }
        }

        for (var i = 0; i < ys.length; i++) {
          add(ys[i], c.flapVelocity);
          add(ys[i], vs[i]);
        }
        ys = cy;
        vs = cv;
      }
      scroll += c.speedForScore(score) * dt;
      // bu adımda kuş merkezinin bulunabileceği aralık (tüm durumlar için aynı yatay konum)
      var lo = -double.infinity,
          hi = c.worldHeight - r; // su: y + r >= yükseklik → çarpma
      for (var i = math.max(0, score - 1); i <= score + 1; i++) {
        final left = first + i * course.spacing - scroll;
        final right = left + c.obstacleWidth;
        final dx = birdX < left
            ? left - birdX
            : (birdX > right ? birdX - right : 0.0);
        if (dx >= r) continue;
        final s = course.at(i);
        final reach = math.sqrt(r * r - dx * dx);
        lo = math.max(lo, s.gapCenter - s.gapHeight / 2 + reach);
        hi = math.min(hi, s.gapCenter + s.gapHeight / 2 - reach);
      }
      final ny = <double>[], nv = <double>[];
      for (var i = 0; i < ys.length; i++) {
        var v = vs[i] + c.gravity * dt;
        if (v > c.maxFallSpeed) v = c.maxFallSpeed;
        var y = ys[i] + v * dt;
        if (y < r) {
          y = r;
          if (v < 0) v = 0;
        }
        // çarpışma kesin eşitsizlikle (oyundaki daire–dikdörtgen testi: < r²); su: y + r >= yükseklik
        if (y < lo || y > hi || y + r >= c.worldHeight) continue;
        ny.add(y);
        nv.add(v);
      }
      ys = ny;
      vs = nv;
      if (ys.isEmpty) return (depth: score, tightest: 0.0);
      if (lo > -double.infinity) {
        // engel yanında: güvenli aralığın genişliği
        var minY = ys[0], maxY = ys[0];
        for (final y in ys) {
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
        tightest = math.min(tightest, maxY - minY);
      }
      if (first + score * course.spacing - scroll + c.obstacleWidth < birdX) {
        score++;
        if (score >= maxScore) return (depth: score, tightest: tightest);
      }
    }
    return (depth: score, tightest: tightest);
  }

  /// Saniyede 20 karar (oyuncunun dokunuş zamanlaması 50 ms çözünürlükle).
  static const _decisionSteps = 6;
  static const _yBin = 4.0;
}

/// Parkur üreticisi sürümleri ve günlük challenge tanımlarının tek kaynağı.
abstract final class DailyGenerators {
  /// Sürüm takvimi: (bu UTC gününden itibaren, sürüm). Yeni bir sürüm yalnızca uygulamanın yayımlandığı
  /// günden SONRA başlayan bir günden itibaren eklenir; böylece süren bir günün yarışı uygulama
  /// güncellense de değişmez. Eski sürümlerin kodu silinmez.
  static const schedule = <(String, int)>[('2026-01-01', 1)];

  /// Aynı gün için denenecek en fazla aday tohum.
  static const maxCandidates = 16;

  static int versionFor(String dayKey) {
    var v = schedule.first.$2;
    for (final (from, version) in schedule) {
      if (dayKey.compareTo(from) >= 0) v = version;
    }
    return v;
  }

  static final Map<String, DailyChallengeDefinition> _cache = {};

  /// [day] gününün (UTC) challenge'ı. Aday tohumlar sırayla denenir; doğrulamayı ilk geçen seçilir.
  /// Hiçbiri geçemezse en derine ulaşan (eşitlikte ilk) seçilir. Seçim kuralı deterministiktir.
  static DailyChallengeDefinition forDay(
    DateTime day, {
    GameConfig config = const GameConfig(),
  }) {
    final key = utcDayKey(day);
    final cached = identical(config, const GameConfig()) ? _cache[key] : null;
    if (cached != null) return cached;
    final version = versionFor(key);
    DailyChallengeDefinition? best;
    var bestTightest = -1.0;
    for (var k = 0; k < maxCandidates; k++) {
      final def = DailyChallengeDefinition(
        challengeId: DailyChallengeDefinition.idFor(key),
        dateUtc: parseUtcDayKey(key)!,
        seed: DailyRng.hash('istanbul_flight/daily/v$version/$key/$k'),
        generatorVersion: version,
        candidate: k,
        validatedDepth: 0,
      );
      final check = CourseValidator.check(DailyCourse(def, config: config));
      final scored = DailyChallengeDefinition(
        challengeId: def.challengeId,
        dateUtc: def.dateUtc,
        seed: def.seed,
        generatorVersion: version,
        candidate: k,
        validatedDepth: check.depth,
      );
      if (check.passes) {
        best = scored;
        break;
      }
      // hiçbiri geçemezse yedek: kurallara uyan, en derine (eşitlikte en geniş aralıklı) ulaşan ilk aday
      if (check.problems.isEmpty &&
          (best == null ||
              check.depth > best.validatedDepth ||
              (check.depth == best.validatedDepth &&
                  check.tightest > bestTightest))) {
        best = scored;
        bestTightest = check.tightest;
      }
    }
    final result = best!;
    if (identical(config, const GameConfig())) _cache[key] = result;
    return result;
  }

  /// Günün tanımını arka planda (ayrı isolate) hesaplayıp belleğe alır: ilk "Günün Uçuşu" ekranı beklemez.
  /// Sonuç [forDay] ile aynıdır (aynı saf hesap).
  static Future<DailyChallengeDefinition> prepare(DateTime day) async {
    final key = utcDayKey(day);
    final cached = _cache[key];
    if (cached != null) return cached;
    try {
      final def = await compute(_forDayKey, key);
      return _cache.putIfAbsent(key, () => def);
    } catch (e) {
      debugPrint('Günün parkuru arka planda hazırlanamadı: $e');
      return forDay(day);
    }
  }

  static DailyChallengeDefinition _forDayKey(String key) =>
      forDay(parseUtcDayKey(key)!);

  /// Tanımdan parkur (sürüme göre üretici).
  static DailyCourse course(
    DailyChallengeDefinition def, {
    GameConfig config = const GameConfig(),
  }) => switch (def.generatorVersion) {
    1 => DailyCourse(def, config: config),
    _ => throw UnsupportedError('generator v${def.generatorVersion}'),
  };

  /// Bölge adı dizisi (ekran için).
  static List<String> zoneNames(DailyChallengeDefinition def) => [
    for (final z in def.zoneSequence) zones[z].name,
  ];
}
