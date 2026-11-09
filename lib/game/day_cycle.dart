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
  rumeli(ObstacleStyle.bridge),
  // Phase 2.6 (docs/19): ikinci gün rotası
  emirgan(ObstacleStyle.house),
  ortakoy(ObstacleStyle.house),
  dolmabahce(ObstacleStyle.house),
  uskudar(ObstacleStyle.ferry);

  const ObstacleKitId(this.fallbackStyle);
  final ObstacleStyle fallbackStyle;
}

/// L3 kahraman simgeler (assets/images/pixel_art/landmarks).
enum Landmark {
  suleymaniye,
  galata,
  kizKulesi,
  bridge,
  rumeliHisari,
  emirgan,
  ortakoy,
  dolmabahce,
  uskudar,
}

/// L2 uzak silüet şeritleri.
enum FarSkyline { peninsula, uskudar, hills }

/// L4 kıyı şeritleri.
enum Shore { halic, galata, uskudar, ortakoy, rumeli, emirgan, dolmabahce }

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
    this.available = true,
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

  /// Rotada mı. Kalıcı kayıtlar bölgeyi [zones] içindeki sırasıyla tanır (keşif, rozet, rekor), bu yüzden
  /// sıra hiç değişmez; görselleri hazır olmayan bölge listede durur ama rotaya girmez ([routeZones]).
  final bool available;

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
  // ---- Phase 2.6: ikinci gün rotası (docs/19). Rumeli'den sonra Boğaz boyunca güneye dönüş; eski bölgelerin
  // eşikleri ve sırası değişmez. Sıra kalıcı kimliktir: yeni bölgeler hep sona eklenir.
  Zone(
    name: 'Emirgan',
    greeting: "Emirgan'dan selamlar!",
    startScore: 120,
    kit: ObstacleKitId.emirgan,
    landmark: Landmark.emirgan,
    far: FarSkyline.hills,
    shore: Shore.emirgan,
    palette: PhasePalette(
      skyTop: Color(0xFF6FB0D8),
      skyMid: Color(0xFFA8D4E6),
      skyHorizon: Color(0xFFE8F0D8),
      sun: Color(0xFFFFF8E0),
      sunY: 420,
      water: Color(0xFF3E8FA0),
      waterDeep: Color(0xFF2E7488),
      far: Color(0xFF8FB49A),
      shore: Color(0xFF5E7E5A),
      landmark: Color(0xFF3E5A44),
      light: Color(0xFFFFF4D6),
      obstacleBase: Color(0xFF3B3A2F),
      obstacleDetail: Color(0xFF7A5A3A),
      windowDark: Color(0xFF4A4A48),
      obstacleTint: Color(0xFFFFFFFF),
      cloud: Color(0xFFFFFFFF),
    ),
  ),
  Zone(
    name: 'Ortaköy',
    greeting: "Ortaköy'den selamlar!",
    startScore: 150,
    kit: ObstacleKitId.ortakoy,
    landmark: Landmark.ortakoy,
    far: FarSkyline.hills,
    shore: Shore.ortakoy,
    palette: PhasePalette(
      skyTop: Color(0xFF1F78D0),
      skyMid: Color(0xFF5FA8E2),
      skyHorizon: Color(0xFFB8DDF2),
      sun: Color(0xFFFFFBE8),
      sunY: 260,
      water: Color(0xFF1E86B0),
      waterDeep: Color(0xFF136C96),
      far: Color(0xFF8CA8C4),
      shore: Color(0xFF5E7C98),
      landmark: Color(0xFF34485E),
      light: Color(0xFFFFF8E0),
      obstacleBase: Color(0xFF3A3236),
      obstacleDetail: Color(0xFF9A4A34),
      windowDark: Color(0xFF4A4650),
      obstacleTint: Color(0xFFFFFFFF),
      cloud: Color(0xFFFFFFFF),
    ),
  ),
  Zone(
    name: 'Dolmabahçe',
    greeting: "Dolmabahçe'den selamlar!",
    startScore: 180,
    kit: ObstacleKitId.dolmabahce,
    landmark: Landmark.dolmabahce,
    far: FarSkyline.uskudar,
    shore: Shore.dolmabahce,
    palette: PhasePalette(
      skyTop: Color(0xFF3E7EC0),
      skyMid: Color(0xFF8AB4D8),
      skyHorizon: Color(0xFFF2DDB0),
      sun: Color(0xFFFFE9B0),
      sunY: 640,
      water: Color(0xFF2F7E9A),
      waterDeep: Color(0xFF246884),
      far: Color(0xFFB4A8A8),
      shore: Color(0xFF8A7A70),
      landmark: Color(0xFF5A4A44),
      light: Color(0xFFFFE2A0),
      obstacleBase: Color(0xFF3E3430),
      obstacleDetail: Color(0xFFA87A4A),
      windowDark: Color(0xFF4E4448),
      obstacleTint: Color(0xFFFFF4E4),
      cloud: Color(0xFFFFF4E0),
    ),
  ),
  Zone(
    name: 'Üsküdar',
    greeting: "Üsküdar'dan selamlar!",
    startScore: 210,
    kit: ObstacleKitId.uskudar,
    landmark: Landmark.uskudar,
    far: FarSkyline.peninsula,
    shore: Shore.uskudar,
    palette: PhasePalette(
      skyTop: Color(0xFF5A6AA8),
      skyMid: Color(0xFFC8A0B0),
      skyHorizon: Color(0xFFF8D8B0),
      sun: Color(0xFFFFE0A8),
      sunY: 980,
      water: Color(0xFF6A7AA0),
      waterDeep: Color(0xFF56658A),
      far: Color(0xFFA88AA0),
      shore: Color(0xFF7A6A84),
      landmark: Color(0xFF4A3A54),
      light: Color(0xFFFFD2A0),
      obstacleBase: Color(0xFF33283A),
      obstacleDetail: Color(0xFFB07A6A),
      windowDark: Color(0xFF443A4E),
      obstacleTint: Color(0xFFF6E2D8),
      cloud: Color(0xFFF2C8C0),
    ),
  ),
];

/// Rotadaki bölgelerin [zones] sıraları (yalnızca [Zone.available] olanlar, skor eşiğine göre artan).
final List<int> routeZones = [
  for (var i = 0; i < zones.length; i++)
    if (zones[i].available) i,
];

/// Rotadaki bölgeler (sırasıyla).
List<Zone> get routeZoneList => [for (final i in routeZones) zones[i]];

/// Klasik rotanın ilk beş bölgesi (Phase 2.0–2.5). Günün Uçuşu v1/v2 ve keşif albümü ödülü bu sınırı kullanır.
const firstRouteLastZone = 4;

/// Skorun bulunduğu bölge (rotadaki son eşiği geçilmiş bölge). [maxZone] verilirse rota o bölgede biter
/// (Günün Uçuşu v1/v2: Rumeli Hisarı).
int zoneIndexForScore(int score, {int? maxZone}) {
  var index = 0;
  for (final i in routeZones) {
    if (maxZone != null && i > maxZone) break;
    if (score >= zones[i].startScore) index = i;
  }
  return index;
}

/// Rotada [zone]'dan sonraki bölge (son bölgede null).
int? nextRouteZone(int zone) {
  final at = routeZones.indexOf(zone);
  return at < 0 || at + 1 >= routeZones.length ? null : routeZones[at + 1];
}

/// Skora bağlı gün döngüsü: bölge değişince palet [transitionTime] sürede yumuşakça geçer.
class DayCycle {
  DayCycle({this.transitionTime = 3.0});

  final double transitionTime;
  int _zone = 0;

  /// Etkinlik bölge dizisi (Phase 2.7): (bölge, bu skordan itibaren). null: klasik rota.
  List<(int, int)>? _route;

  List<(int, int)>? get route => _route;

  /// Bölge dizisini değiştirir; görünüm bir sonraki [reset] ile dizinin ilk bölgesine geçer.
  set route(List<(int, int)>? r) => _route = r == null || r.isEmpty ? null : r;

  /// Uçuşun başladığı bölge.
  int get startZone => _route?.first.$1 ?? 0;

  /// Rotadaki duraklar ve eşikleri (HUD rota çubuğu).
  List<(int, int)> get stages =>
      _route ?? [for (final z in routeZones) (z, zones[z].startScore)];

  int _zoneFor(int score, int? maxZone) {
    final r = _route;
    if (r == null) return zoneIndexForScore(score, maxZone: maxZone);
    var z = r.first.$1;
    for (final (zone, from) in r) {
      if (score >= from) z = zone;
    }
    return z;
  }
  PhasePalette _from = zones[0].palette;
  double _t = 1;
  PhasePalette _current = zones[0].palette;

  int get zoneIndex => _zone;
  Zone get zone => zones[_zone];
  PhasePalette get palette => _current;

  /// Geçiş sürüyor mu (sadece bu sırada palet her karede yeniden hesaplanır).
  bool get isTransitioning => _t < 1;

  /// Skor yeni bir bölgeye geçtiyse true döner. [maxZone]: rotanın biteceği bölge (Günün Uçuşu).
  bool updateScore(int score, {int? maxZone}) {
    final next = _zoneFor(score, maxZone);
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
    _zone = startZone;
    _from = zones[_zone].palette;
    _current = zones[_zone].palette;
    _t = 1;
  }
}
