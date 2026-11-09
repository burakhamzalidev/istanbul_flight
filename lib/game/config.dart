/// Oyunun ayarlanabilir değerleri.
///
/// Dünya birimi: dünya yüksekliği her ekranda [worldHeight] birimdir. Genişlik
/// ekran oranına göre değişir (uzun telefonlarda daha dar, tablette daha geniş).
/// Böylece dikey oynanış, yani geçitler ve zıplama yüksekliği, her cihazda aynı kalır.
class GameConfig {
  const GameConfig({
    this.worldHeight = 1920,
    this.horizonY = 1190,
    this.gravity = 2600,
    this.flapVelocity = -880,
    this.maxFallSpeed = 1500,
    this.physicsStep = 1 / 120,
    this.maxFrameDt = 1 / 20,
    this.birdXFraction = 0.30,
    this.birdMinX = 170,
    this.birdMaxX = 420,
    this.birdHitRadius = 34,
    this.birdDisplayWidth = 192,
    this.startSpeed = 340,
    this.maxSpeed = 440,
    this.speedPerPoint = 2.5,
    this.obstacleWidth = 196,
    this.obstacleSpacing = 600,
    this.firstObstacleOffset = 260,
    this.gapCurve = defaultGapCurve,
    this.gapMarginTop = 230,
    this.gapMarginBottom = 230,
    this.maxGapRise = 330,
    this.maxGapDrop = 390,
    this.bigShift = 260,
    this.afterBigShiftScale = 0.6,
    this.hazardsFromScore = 120,
    this.flockChance = 0.2,
    this.gustChance = 0.16,
    this.hazardCooldown = 2,
    this.flockWidth = 180,
    this.flockHeight = 88,
    this.flockApproach = 0.35,
    this.flockBob = 22,
    this.flockBobPeriod = 2.6,
    this.flockOverlap = 80,
    this.gustAccel = 400,
    this.gameOverCardDelay = 0.7,
    this.restartLockTime = 0.6,
    this.pickupChance = 0.45,
    this.pickupRadius = 30,
    this.pickupSafetyMargin = 16,
    this.nearMissClearance = 18,
    this.hitStop = 0.08,
    this.shakeTime = 0.28,
    this.shakeAmplitude = 14,
  });

  final double worldHeight;
  final double horizonY;

  // Fizik (birim/s, birim/s²)
  final double gravity;
  final double flapVelocity;
  final double maxFallSpeed;

  /// Sabit fizik adımı. Kare hızından bağımsız ve deterministik simülasyon sağlar.
  final double physicsStep;

  /// Tek karede işlenecek en uzun süre (takılma ve arka plandan dönüşte büyük sıçramayı önler).
  final double maxFrameDt;

  // Karakter
  final double birdXFraction;
  final double birdMinX;
  final double birdMaxX;

  /// Çarpışma yarıçapı: görsel gövdeden küçük, kanat, gaga ve kuyruk dışarıda (oyuncu lehine).
  final double birdHitRadius;
  final double birdDisplayWidth;

  // Akış hızı
  final double startSpeed;
  final double maxSpeed;
  final double speedPerPoint;

  // Engeller
  final double obstacleWidth;

  /// Ardışık iki engelin sol kenarları arası (560 → 600, docs/18 §2). Üst sınır: kuş bir engelin
  /// ortasındayken sıradaki engelin ağzı en uzun iPhone ekranında (9:19,5) görünmeli (~620).
  final double obstacleSpacing;
  final double firstObstacleOffset;

  /// Geçit yüksekliği eğrisi: (skor, yükseklik) noktaları, aralarda doğrusal; son noktadan sonra sabit.
  /// Noktalar bölge sınırlarında (Haliç 0, Galata 15, Kız Kulesi 35, Boğaz 60, Rumeli 90): her bölge
  /// kendi daralma hızıyla gelir, en dar geçit (300) bile bir çırpış yayından (~217 birim) belirgin geniştir.
  final List<(int, double)> gapCurve;
  final double gapMarginTop;
  final double gapMarginBottom;

  /// Ardışık iki geçit arasında yukarı (çırparak tırmanma) ve aşağı (süzülme) en büyük merkez farkı.
  /// Tırmanma düşmekten zordur, bu yüzden yukarı sınır daha küçüktür.
  final double maxGapRise;
  final double maxGapDrop;

  /// Bu değerden büyük bir sıçramadan sonraki geçidin kayma sınırları [afterBigShiftScale] ile küçülür:
  /// art arda iki büyük zikzak (yukarı-aşağı-yukarı) üretilmez.
  final double bigShift;
  final double afterBigShiftScale;

  // Dinamik engeller (Phase 2.6.3, docs/19 §5a; yalnızca klasik mod)
  /// Bu skordan itibaren (ikinci gün bölgeleri) koridorlara tehlike konabilir.
  final int hazardsFromScore;

  /// Bir koridorda martı sürüsü / rüzgâr kuşağı olasılığı.
  final double flockChance, gustChance;

  /// Bir tehlikeden sonra en az bu kadar koridor tehlikesiz kalır.
  final int hazardCooldown;

  /// Martı sürüsünün görsel boyu; çarpışma kutusu bunun %80 × %70'i.
  final double flockWidth, flockHeight;

  /// Sürü kuşa doğru uçar: kaydırma hızına göre bu oranda daha hızlı yaklaşır. Kuşun hizasına koridorun
  /// ortasında gelir (konumu yalnızca koridorun kuşa uzaklığına bağlı; zamandan ve kare hızından bağımsız).
  final double flockApproach;

  /// Sürünün dikey salınım genliği ve periyodu (sn): yavaş ve tahmin edilebilir.
  final double flockBob, flockBobPeriod;

  /// Sürünün (salınımın en uç anında) iki geçidi birleştiren yol zarfına en fazla girebileceği derinlik.
  final double flockOverlap;

  /// Hava akımının koridor ortasındaki en büyük dikey ivmesi (yer çekimi 2600; ~%15). Koridorun kenarlarında
  /// sıfırdan başlar ve sin² eğrisiyle yumuşakça artıp azalır (ortalama bunun yarısı).
  final double gustAccel;

  /// Varsayılan geçit eğrisi (docs/18 §4).
  static const defaultGapCurve = <(int, double)>[
    (0, 370),
    (15, 350),
    (35, 330),
    (60, 310),
    (90, 300),
  ];

  /// Eğrinin en geniş ve en dar geçidi.
  double get startGap => gapCurve.first.$2;
  double get minGap =>
      gapCurve.fold(double.infinity, (m, p) => p.$2 < m ? p.$2 : m);

  // Oyun sonu
  final double gameOverCardDelay;
  final double restartLockTime;

  // Toplanabilir simit
  /// Bir engel çiftinin geçidinde simit bulunma olasılığı.
  final double pickupChance;

  /// Toplama yarıçapı (görsel halkanın dış yarıçapıyla aynı).
  final double pickupRadius;

  /// Simidin geçit kenarına olan en küçük mesafesi (kuş yarıçapına ek).
  final double pickupSafetyMargin;

  // Kıl payı
  /// Engelin yanından geçerken kuş kenarı ile engel arasındaki en küçük boşluk bu değerin
  /// altındaysa (ve çarpışma yoksa) "kıl payı" sayılır.
  final double nearMissClearance;

  // Game feel
  /// Çarpışma anında simülasyonun kısa donması (sn).
  final double hitStop;
  final double shakeTime;
  final double shakeAmplitude;

  double speedForScore(int score) =>
      (startSpeed + score * speedPerPoint).clamp(startSpeed, maxSpeed);

  double gapForScore(int score) {
    final c = gapCurve;
    if (score <= c.first.$1) return c.first.$2;
    for (var i = 1; i < c.length; i++) {
      final (s1, g1) = c[i];
      if (score <= s1) {
        final (s0, g0) = c[i - 1];
        return g0 + (g1 - g0) * (score - s0) / (s1 - s0);
      }
    }
    return c.last.$2;
  }
}
