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
    this.obstacleSpacing = 560,
    this.firstObstacleOffset = 260,
    this.startGap = 340,
    this.minGap = 265,
    this.gapShrinkPerPoint = 1.6,
    this.gapMarginTop = 230,
    this.gapMarginBottom = 230,
    this.maxGapShift = 430,
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
  final double obstacleSpacing;
  final double firstObstacleOffset;
  final double startGap;
  final double minGap;
  final double gapShrinkPerPoint;
  final double gapMarginTop;
  final double gapMarginBottom;

  /// Ardışık iki geçidin merkezleri arasındaki en büyük dikey fark (adil geçiş).
  final double maxGapShift;

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

  double gapForScore(int score) =>
      (startGap - score * gapShrinkPerPoint).clamp(minGap, startGap);
}
