import 'dart:ui';

/// Bir zaman fazının (şafak, öğle...) renkleri ve atmosfer değerleri.
/// Renkler docs/02 ve art/palette ile aynı. Bölge geçişinde hepsi birlikte yumuşakça karışır.
class PhasePalette {
  const PhasePalette({
    required this.skyTop,
    required this.skyMid,
    required this.skyHorizon,
    required this.sun,
    required this.sunY,
    required this.water,
    required this.waterDeep,
    required this.far,
    required this.shore,
    required this.landmark,
    required this.light,
    required this.obstacleBase,
    required this.obstacleDetail,
    required this.windowDark,
    required this.obstacleTint,
    required this.cloud,
    this.fog = 0,
    this.stars = 0,
    this.moon = 0,
    this.lights = 0,
  });

  final Color skyTop, skyMid, skyHorizon, sun;

  /// Güneş/ay diskinin dünya y konumu.
  final double sunY;
  final Color water, waterDeep;

  /// L2 uzak silüet, L4 kıyı, L3 simge maskelerinin boyası.
  final Color far, shore, landmark;

  /// Fazın ana ışık rengi: kenar ışığı, yansımalar, yanan pencereler.
  final Color light;

  /// Yedek (kodla çizilen) engel renkleri.
  final Color obstacleBase, obstacleDetail, windowDark;

  /// Engel sprite'larına çarpılarak (modulate) uygulanan faz tonu. Öğle = beyaz (orijinal renk).
  final Color obstacleTint;
  final Color cloud;

  /// 0..1 atmosfer değerleri: sis (Haliç), yıldız, ay (0 = güneş), kıyı/simge ışıkları.
  final double fog, stars, moon, lights;

  static PhasePalette lerp(PhasePalette a, PhasePalette b, double t) {
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    double d(double x, double y) => x + (y - x) * t;
    return PhasePalette(
      skyTop: c(a.skyTop, b.skyTop),
      skyMid: c(a.skyMid, b.skyMid),
      skyHorizon: c(a.skyHorizon, b.skyHorizon),
      sun: c(a.sun, b.sun),
      sunY: d(a.sunY, b.sunY),
      water: c(a.water, b.water),
      waterDeep: c(a.waterDeep, b.waterDeep),
      far: c(a.far, b.far),
      shore: c(a.shore, b.shore),
      landmark: c(a.landmark, b.landmark),
      light: c(a.light, b.light),
      obstacleBase: c(a.obstacleBase, b.obstacleBase),
      obstacleDetail: c(a.obstacleDetail, b.obstacleDetail),
      windowDark: c(a.windowDark, b.windowDark),
      obstacleTint: c(a.obstacleTint, b.obstacleTint),
      cloud: c(a.cloud, b.cloud),
      fog: d(a.fog, b.fog),
      stars: d(a.stars, b.stars),
      moon: d(a.moon, b.moon),
      lights: d(a.lights, b.lights),
    );
  }
}

/// Yedek çizici stilleri (sprite kiti yüklenemezse).
enum ObstacleStyle { house, ferry, bridge }

/// Bölgelerin engel sprite kitleri (assets/images/pixel_art/obstacles/kit_*.png).
enum ObstacleKitId {
  halic(ObstacleStyle.house),
  galata(ObstacleStyle.house),
  kizkulesi(ObstacleStyle.ferry),
  kopru(ObstacleStyle.bridge),
  rumeli(ObstacleStyle.bridge);

  const ObstacleKitId(this.fallbackStyle);
  final ObstacleStyle fallbackStyle;
}

/// L3 kahraman simgeler (assets/images/pixel_art/landmarks).
enum Landmark { suleymaniye, galata, kizKulesi, bridge, rumeliHisari }

/// L2 uzak silüet şeritleri.
enum FarSkyline { peninsula, uskudar, hills }

/// L4 kıyı şeritleri.
enum Shore { halic, galata, uskudar, ortakoy, rumeli }

/// Rota üzerindeki bölge = günün bir fazı + kendine özgü görsel set.
class Zone {
  const Zone({
    required this.name,
    required this.greeting,
    required this.startScore,
    required this.palette,
    required this.kit,
    required this.landmark,
    required this.far,
    required this.shore,
  });

  final String name;

  /// Kartpostal başlığı (Türkçe ayrılma hâli eki elle yazıldı).
  final String greeting;
  final int startScore;
  final PhasePalette palette;
  final ObstacleKitId kit;
  final Landmark landmark;
  final FarSkyline far;
  final Shore shore;

  ObstacleStyle get obstacleStyle => kit.fallbackStyle;
}

const zones = <Zone>[
  Zone(
    name: 'Haliç',
    greeting: "Haliç'ten selamlar!",
    startScore: 0,
    kit: ObstacleKitId.halic,
    landmark: Landmark.suleymaniye,
    far: FarSkyline.peninsula,
    shore: Shore.halic,
    palette: PhasePalette(
      skyTop: Color(0xFF3E4A7A),
      skyMid: Color(0xFFB98299),
      skyHorizon: Color(0xFFFCD9B8),
      sun: Color(0xFFFFE9C8),
      sunY: 1190,
      water: Color(0xFF6F7BA6),
      waterDeep: Color(0xFF4E5F8C),
      far: Color(0xFFA78AA6),
      shore: Color(0xFF6A577E),
      landmark: Color(0xFF8C7192),
      light: Color(0xFFFFD3A1),
      obstacleBase: Color(0xFF3A2E48),
      obstacleDetail: Color(0xFF5A2E36),
      windowDark: Color(0xFF4D4266),
      obstacleTint: Color(0xFFCDB8D2),
      cloud: Color(0xFFF2B7A6),
      fog: 0.45,
      lights: 0.55,
    ),
  ),
  Zone(
    name: 'Galata',
    greeting: "Galata'dan selamlar!",
    startScore: 15,
    kit: ObstacleKitId.galata,
    landmark: Landmark.galata,
    far: FarSkyline.peninsula,
    shore: Shore.galata,
    palette: PhasePalette(
      skyTop: Color(0xFF4FA3C7),
      skyMid: Color(0xFF86C4DA),
      skyHorizon: Color(0xFFBFE3EC),
      sun: Color(0xFFFFF6DA),
      sunY: 330,
      water: Color(0xFF2E8B99),
      waterDeep: Color(0xFF237482),
      far: Color(0xFF9DB8C6),
      shore: Color(0xFF6E8FA3),
      landmark: Color(0xFF3B4F63),
      light: Color(0xFFFFF6DA),
      obstacleBase: Color(0xFF3B2F2F),
      obstacleDetail: Color(0xFF8E3B2A),
      windowDark: Color(0xFF55484A),
      obstacleTint: Color(0xFFFFFFFF),
      cloud: Color(0xFFFFFFFF),
    ),
  ),
  Zone(
    name: 'Kız Kulesi',
    greeting: "Kız Kulesi'nden selamlar!",
    startScore: 35,
    kit: ObstacleKitId.kizkulesi,
    landmark: Landmark.kizKulesi,
    far: FarSkyline.uskudar,
    shore: Shore.uskudar,
    palette: PhasePalette(
      skyTop: Color(0xFF5B3A6E),
      skyMid: Color(0xFFE3684A),
      skyHorizon: Color(0xFFF7C35F),
      sun: Color(0xFFFFD98A),
      sunY: 1190,
      water: Color(0xFF7A4A63),
      waterDeep: Color(0xFF683E58),
      far: Color(0xFFC07070),
      shore: Color(0xFF8A4A62),
      landmark: Color(0xFF3A2340),
      light: Color(0xFFFFB25B),
      obstacleBase: Color(0xFF2A1A2E),
      obstacleDetail: Color(0xFFC9957F),
      windowDark: Color(0xFF3E2847),
      obstacleTint: Color(0xFFE9A894),
      cloud: Color(0xFFC25A6A),
      fog: 0.1,
      lights: 0.65,
    ),
  ),
  Zone(
    name: 'Boğaz Köprüsü',
    greeting: "Boğaz Köprüsü'nden selamlar!",
    startScore: 60,
    kit: ObstacleKitId.kopru,
    landmark: Landmark.bridge,
    far: FarSkyline.hills,
    shore: Shore.ortakoy,
    palette: PhasePalette(
      skyTop: Color(0xFF1E2556),
      skyMid: Color(0xFF4A3F7A),
      skyHorizon: Color(0xFFB0636A),
      sun: Color(0xFFF2E6D0),
      sunY: 360,
      water: Color(0xFF2A3266),
      waterDeep: Color(0xFF1B2450),
      far: Color(0xFF3A3466),
      shore: Color(0xFF221E48),
      landmark: Color(0xFF10163A),
      light: Color(0xFFFFC857),
      obstacleBase: Color(0xFF0E1230),
      obstacleDetail: Color(0xFF1E2750),
      windowDark: Color(0xFF1E2750),
      obstacleTint: Color(0xFF9A98C8),
      cloud: Color(0xFF4A3F7A),
      stars: 0.45,
      moon: 0.7,
      lights: 0.9,
    ),
  ),
  Zone(
    name: 'Rumeli Hisarı',
    greeting: "Rumeli Hisarı'ndan selamlar!",
    startScore: 90,
    kit: ObstacleKitId.rumeli,
    landmark: Landmark.rumeliHisari,
    far: FarSkyline.hills,
    shore: Shore.rumeli,
    palette: PhasePalette(
      skyTop: Color(0xFF0B1030),
      skyMid: Color(0xFF141B42),
      skyHorizon: Color(0xFF26305E),
      sun: Color(0xFFF2E6D0),
      sunY: 300,
      water: Color(0xFF141C40),
      waterDeep: Color(0xFF0C1230),
      far: Color(0xFF1C2452),
      shore: Color(0xFF080B1E),
      landmark: Color(0xFF04061A),
      light: Color(0xFFFFC857),
      obstacleBase: Color(0xFF0A0D1F),
      obstacleDetail: Color(0xFF1E2750),
      windowDark: Color(0xFF1E2750),
      obstacleTint: Color(0xFF6A74A6),
      cloud: Color(0xFF1E2556),
      fog: 0.12,
      stars: 1,
      moon: 1,
      lights: 1,
    ),
  ),
];

int zoneIndexForScore(int score) {
  var index = 0;
  for (var i = 0; i < zones.length; i++) {
    if (score >= zones[i].startScore) index = i;
  }
  return index;
}

/// Skora bağlı gün döngüsü: bölge değişince palet [transitionTime] sürede yumuşakça geçer.
class DayCycle {
  DayCycle({this.transitionTime = 3.0});

  final double transitionTime;
  int _zone = 0;
  PhasePalette _from = zones[0].palette;
  double _t = 1;
  PhasePalette _current = zones[0].palette;

  int get zoneIndex => _zone;
  Zone get zone => zones[_zone];
  PhasePalette get palette => _current;

  /// Geçiş sürüyor mu (sadece bu sırada palet her karede yeniden hesaplanır).
  bool get isTransitioning => _t < 1;

  /// Skor yeni bir bölgeye geçtiyse true döner.
  bool updateScore(int score) {
    final next = zoneIndexForScore(score);
    if (next == _zone) return false;
    _from = _current;
    _zone = next;
    _t = 0;
    return true;
  }

  void update(double dt) {
    if (_t >= 1) return;
    _t = (_t + dt / transitionTime).clamp(0, 1);
    final eased = _t * _t * (3 - 2 * _t);
    _current = PhasePalette.lerp(_from, zones[_zone].palette, eased);
  }

  void reset() {
    _zone = 0;
    _from = zones[0].palette;
    _current = zones[0].palette;
    _t = 1;
  }
}
