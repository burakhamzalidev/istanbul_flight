import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../game/config.dart';
import '../game/day_cycle.dart';
import '../game/logic/gap_generator.dart';
import '../game/logic/hazards.dart';
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
  dailyPractice,

  /// Etkinlik uçuşu (Phase 2.7: İstanbul Kupası ya da özel etkinlik): sınırsız deneme, etkinliğin en iyi tek
  /// uçuşu sayılır; etkinlik ödülleri, sezon puanı ve (kupada) haftalık sıralama.
  event,

  /// Etkinlik parkurunda dereceye girmeyen uçuş (cihaz saati güvenilmez): ödül ve sıralama yok.
  eventPractice,

  /// İlk uçuş eğitimi (Phase 2.8): gerçek uçuş değildir; hiçbir olay yayınlanmaz, hiçbir şey kaydedilmez.
  tutorial;

  bool get isDaily => this == dailyRanked || this == dailyPractice;
  bool get isEvent => this == event || this == eventPractice;

  /// Parkur deterministik bir tanımdan gelir (günlük ya da etkinlik): kuşun yatay konumu sabit.
  bool get usesCourse => isDaily || isEvent;
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

  /// n. engelin geçidi (üretici v2: [GameConfig.gapCurve]).
  double gapHeight(GameConfig c, int index) =>
      c.gapForScore(index + gapScoreOffset);

  /// n. engelin geçidi, üretici v1'in dondurulmuş eğrisiyle ([LegacyGapBalanceV1]).
  double gapHeightV1(int index) =>
      LegacyGapBalanceV1.gapForScore(index + gapScoreOffset);
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

/// Üretici v1'in geçit dengesi (1.5.0 (7) ile yayımlanan): parkurlar değişmesin diye dondurulmuştur.
/// Klasik mod ve v2 artık [GameConfig.gapCurve] ve [GapRules] kullanır (docs/18 §4).
abstract final class LegacyGapBalanceV1 {
  static const startGap = 340.0;
  static const minGap = 265.0;
  static const gapShrinkPerPoint = 1.6;
  static const gapMarginTop = 230.0;
  static const gapMarginBottom = 230.0;
  static const maxGapShift = 430.0;
  static const obstacleSpacing = 560.0;

  static double gapForScore(int score) =>
      (startGap - score * gapShrinkPerPoint).clamp(minGap, startGap);
}

/// Günlük parkur: n. engel yalnızca tohuma, üretici sürümüne ve n'ye bağlıdır. Kare hızı, ekran
/// genişliği, oyuncunun skoru ya da görsel efektlerin rastgeleliği sonucu değiştirmez.
class DailyCourse {
  DailyCourse(this.definition, {this.config = const GameConfig()})
    : assert(
        definition.generatorVersion == 1 || definition.generatorVersion == 2,
      ),
      _gaps = DailyRng(DailyRng.hash('gaps:${definition.seed}')),
      _pickups = DailyRng(DailyRng.hash('pickups:${definition.seed}'));

  final DailyChallengeDefinition definition;
  final GameConfig config;
  final DailyRng _gaps;
  final DailyRng _pickups;
  final List<ObstacleSpec> _specs = [];

  int get version => definition.generatorVersion;

  /// Engeller arası yatay mesafe (v2: klasikle aynı; v1: dondurulmuş).
  double get spacing => version == 1
      ? LegacyGapBalanceV1.obstacleSpacing
      : config.obstacleSpacing;

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

  /// n. engelin geçit merkezinin seçilebileceği aralık (üretim ve doğrulama aynı kuralı kullanır).
  ({double low, double high}) centerRange(int i, double height) {
    if (version == 1) {
      var low = LegacyGapBalanceV1.gapMarginTop + height / 2;
      var high =
          config.worldHeight - LegacyGapBalanceV1.gapMarginBottom - height / 2;
      if (i > 0) {
        final last = at(i - 1).gapCenter;
        low = math.max(low, last - LegacyGapBalanceV1.maxGapShift);
        high = math.min(high, last + LegacyGapBalanceV1.maxGapShift);
      }
      return (low: low, high: high);
    }
    return GapRules.centerRange(
      config,
      height,
      lastCenter: i > 0 ? at(i - 1).gapCenter : null,
      lastShift: i > 1 ? at(i - 1).gapCenter - at(i - 2).gapCenter : null,
    );
  }

  /// v2: klasik modun kendi üreticisi, günün tohumuyla (ikinci bir üretici yok).
  late final GapGenerator _classic = GapGenerator.seeded(
    config,
    _gaps.nextDouble,
  );

  // Bir sürümün çıktısı değişirse yeni bir üretici sürümü açılmalıdır (DailyGenerators). v1 dondurulmuş
  // dengeyle üretir; v2 klasik modun [GapGenerator]'ını tohumlu kaynakla kullanır. Tohum akışı ikisinde aynı.
  ObstacleSpec _generate(int i) {
    final c = config;
    final p = definition.difficultyProfile;
    final double height, center;
    if (version == 1) {
      height = p.gapHeightV1(i);
      final range = centerRange(i, height);
      center = range.low + _gaps.nextDouble() * (range.high - range.low);
    } else {
      final gap = _classic.next(i + p.gapScoreOffset);
      height = gap.height;
      center = gap.center;
    }
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
        pickupY = version == 1
            ? (band.top + band.bottom) / 2 +
                  (pos - 0.5) * (band.bottom - band.top) * 0.7
            : PickupRules.positionInBand(
                config: c,
                band: band,
                roll: pos,
                gapCenter: center,
                previousCenter: _specs[i - 1].gapCenter,
              );
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

  /// [hazardAt] verilirse (Phase 2.7 etkinlikleri) dinamik engellerle birlikte sınanır.
  static CourseCheck check(
    DailyCourse course, {
    int maxScore = requiredDepth,
    Hazard? Function(int corridor)? hazardAt,
  }) {
    final c = course.config;
    final problems = <String>[];
    for (var i = 0; i < maxScore + 2; i++) {
      final s = course.at(i);
      final range = course.centerRange(i, s.gapHeight);
      if (s.gapCenter < range.low - 0.001 || s.gapCenter > range.high + 0.001) {
        problems.add(i == 0 ? 'gap_out_of_band@$i' : 'gap_shift@$i');
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
    final (:depth, :tightest) = explore(
      course,
      maxScore: maxScore,
      hazardAt: hazardAt,
    );
    return CourseCheck(depth: depth, tightest: tightest, problems: problems);
  }

  /// Erişilebilirlik simülasyonu: kuşun ulaşabileceği tüm (yükseklik, hız) durumları sabit adımla, oyunla
  /// aynı fizikle ilerletilir. Her [_decisionSteps] adımda (saniyede 20 karar) her durum için "çırp" ve
  /// "çırpma" denenir; engele ya da suya değen durumlar elenir. Hiç durum kalmazsa parkur o engelde
  /// fiziksel olarak geçilemez demektir. Dönen değer: geçilebildiği kanıtlanan engel sayısı (en fazla
  /// [maxScore]) ve engel yanındaki en dar güvenli yükseklik aralığı. Aynı 4 birimlik yükseklik kutusunda yalnızca en küçük ve en büyük hızlı durum tutulur; bu yalnızca
  /// temkinli yönde hata yapabilir (çok nadiren geçilebilir bir parkuru reddetmek).
  ///
  /// [bands] verilirse her engelin yanındaki en dar güvenli aralık sırayla eklenir (denge ölçümü).
  ///
  /// [hazardAt] verilirse (Phase 2.6.3, klasik mod doğrulaması) koridorlardaki dinamik engeller de oyunla
  /// aynı kurallarla hesaba katılır: rüzgâr ivmesi fiziğe eklenir, martı sürüsü zamana bağlı konumuyla
  /// durumları eler. Sürü aralığı bölerse "en dar aralık", deliğin üstünde ve altında kalan parçalardan büyüğüdür
  /// (kuş en az birinden geçmek zorunda). Verilmezse sonuç önceki sürümle birebir aynıdır.
  ///
  /// [decisionSteps] karar aralığıdır (varsayılan: günlük doğrulamayla aynı). Keşfedilen her durum gerçek bir
  /// dokunuş dizisiyle ulaşılabilir olduğundan farklı aralıklarla bulunan bantların engel başına büyüğü de
  /// geçerli bir alt sınırdır (ölçüm gürültüsünü azaltmak için; docs/19 §6).
  static ({int depth, double tightest}) explore(
    DailyCourse course, {
    int maxScore = requiredDepth,
    List<double>? bands,
    Hazard? Function(int corridor)? hazardAt,
    int decisionSteps = _decisionSteps,
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
      if (step > 0 && step % decisionSteps == 0) {
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
      final time = (step + 1) * dt; // oyun saati (ilk dokunuş = 0)
      var gust = 0.0;
      Rect? flock;
      if (hazardAt != null) {
        for (var i = score; i <= score + 1; i++) {
          final h = hazardAt(i);
          if (h == null) continue;
          final nextLeft = first + i * course.spacing - scroll;
          if (h.kind == HazardKind.gust) {
            gust +=
                h.accel *
                HazardRules.gustFactor(c, birdX, nextLeft, course.spacing);
          } else if (h.kind == HazardKind.flock) {
            flock = h.flockRect(
              c,
              HazardRules.flockCenterX(
                c,
                HazardRules.corridorCenterX(c, nextLeft, course.spacing),
                birdX,
              ),
              time,
            );
          }
        }
      }
      // sürünün kuş merkezine yasakladığı açık aralık (daire–dikdörtgen kesişimi)
      var fLo = 1.0, fHi = 0.0;
      final fr = flock;
      if (fr != null) {
        final dx = birdX < fr.left
            ? fr.left - birdX
            : (birdX > fr.right ? birdX - fr.right : 0.0);
        if (dx < r) {
          final reach = math.sqrt(r * r - dx * dx);
          fLo = fr.top - reach;
          fHi = fr.bottom + reach;
        }
      }
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
        var v = vs[i] + (c.gravity + gust) * dt;
        if (v > c.maxFallSpeed) v = c.maxFallSpeed;
        var y = ys[i] + v * dt;
        if (y < r) {
          y = r;
          if (v < 0) v = 0;
        }
        // çarpışma kesin eşitsizlikle (oyundaki daire–dikdörtgen testi: < r²); su: y + r >= yükseklik
        if (y < lo || y > hi || y + r >= c.worldHeight) continue;
        if (y > fLo && y < fHi) continue; // martı sürüsü
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
        var band = maxY - minY;
        if (fHi > fLo && fLo < maxY && fHi > minY) {
          // sürü aralığı ikiye böler: kuşun kullanabileceği büyük parça (üstü ya da altı)
          final above = fLo > minY ? math.min(fLo, maxY) - minY : 0.0;
          final below = fHi < maxY ? maxY - math.max(fHi, minY) : 0.0;
          band = math.max(above, below);
        }
        tightest = math.min(tightest, band);
        if (bands != null) {
          while (bands.length <= score) {
            bands.add(double.infinity);
          }
          bands[score] = math.min(bands[score], band);
        }
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
  ///
  /// v2 (docs/18): klasik modun yeni geçit dengesi. 1.5.0 (7) yalnızca TestFlight'ta olduğu için
  /// başlangıcı bu sürümün hazırlandığı günden sonraki ilk gündür.
  static const schedule = <(String, int)>[('2026-01-01', 1), ('2026-11-10', 2)];

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
    1 || 2 => DailyCourse(def, config: config),
    _ => throw UnsupportedError('generator v${def.generatorVersion}'),
  };

  /// Bölge adı dizisi (ekran için).
  static List<String> zoneNames(DailyChallengeDefinition def) => [
    for (final z in def.zoneSequence) zones[z].name,
  ];
}
