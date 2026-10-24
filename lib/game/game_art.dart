import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flutter/foundation.dart';

import '../progression/cosmetics.dart';
import 'day_cycle.dart';

/// Pixel art ölçeği: 1 piksel = 4 dünya birimi (karakter, engel, arka plan, efekt hepsi aynı yoğunlukta).
const double kArtPx = 4;

/// Görseli piksel ızgarasına oturtur (alt piksel kaymasından doğan titremeyi önler).
double snapPx(double v) => (v / kArtPx).roundToDouble() * kArtPx;

/// En yakın komşu örnekleme: pixel art bulanıklaşmaz.
Paint pixelPaint() => Paint()
  ..filterQuality = FilterQuality.none
  ..isAntiAlias = false;

/// Bir bölgenin arka plan katmanları (`assets/images/pixel_art/backgrounds/<bölge>/`).
class ZoneArt {
  const ZoneArt({
    this.sky,
    this.sun,
    this.clouds,
    this.distant,
    this.midground,
    this.waterfront,
    this.water,
    this.waterHi,
    this.ferry,
  });

  final Image? sky,
      sun,
      clouds,
      distant,
      midground,
      waterfront,
      water,
      waterHi,
      ferry;

  /// Bulut atlası içindeki sprite'lar (px).
  static const cloudRects = [
    Rect.fromLTWH(0, 0, 114, 48),
    Rect.fromLTWH(114, 0, 82, 48),
    Rect.fromLTWH(196, 0, 60, 48),
  ];

  /// Kıyı şeridinde ufka denk gelen satır (px).
  static const waterfrontHorizonRow = 12.0;
}

/// Oyunun raster görselleri: pixel art seti. Hepsi bir kez yüklenir ve Flame [Images] önbelleğinde tutulur.
/// Her biri isteğe bağlı: yüklenemezse bileşenler yedek çizime düşer, oyun bozulmaz.
///
/// Kaynak: art/_source/pixel/build_all.js → assets/images/pixel_art
class GameArt {
  GameArt({
    this.simitSheet,
    Map<String, ZoneArt>? zones,
    Map<Landmark, Image>? landmarks,
    Map<ObstacleKitId, Image>? kits,
    this.fx,
    this.icons,
    Map<String, Image>? skins,
  }) : skins = skins ?? const {},
       zones = zones ?? const {},
       landmarks = landmarks ?? const {},
       kits = kits ?? const {};

  GameArt.none() : this();

  /// 12 kare, 6 sütun × 2 satır. Kare 48×42 px (= 192×168 dünya birimi), pivot (22,22).
  final Image? simitSheet;

  /// Kozmetik görünümler (kimlik → sheet). Klasik sheet ile aynı kare düzeni ve pivot.
  /// Yüklenemeyen görünüm burada yoktur → oyun klasik sheet'e döner ([sheetFor]).
  final Map<String, Image> skins;

  /// Görünümün sheet'i; yoksa klasik.
  Image? sheetFor(String cosmeticId) => skins[cosmeticId] ?? simitSheet;

  /// Bölge anahtarı (= [ObstacleKitId.name]) → katmanlar.
  final Map<String, ZoneArt> zones;
  final Map<Landmark, Image> landmarks;

  /// Engel kitleri (1/4 çözünürlüklü atlas, bkz. ObstacleKitLayout.atlasScale).
  final Map<ObstacleKitId, Image> kits;

  /// Efekt atlası: toplanabilir simit, parıltı, tüy, damla, halkalar.
  final Image? fx;

  /// Arayüz ikonları (16×16 hücre, beyaz maske).
  final Image? icons;

  static const simitFrameSize = Size(48, 42);
  static const simitPivot = Offset(22, 22);
  static const simitColumns = 6;
  static const simitFrameCount = 12;

  static Rect simitFrameRect(int frame) => Rect.fromLTWH(
    (frame % simitColumns) * simitFrameSize.width,
    (frame ~/ simitColumns) * simitFrameSize.height,
    simitFrameSize.width,
    simitFrameSize.height,
  );

  // ---- efekt atlası yerleşimi (px) ----
  static Rect pickupFrame(int i) => Rect.fromLTWH(i * 20.0, 0, 20, 20);
  static const sparkleBig = Rect.fromLTWH(80, 0, 7, 7);
  static const sparkleSmall = Rect.fromLTWH(88, 0, 7, 7);
  static const featherRect = Rect.fromLTWH(96, 0, 6, 10);
  static const dropRect = Rect.fromLTWH(104, 0, 3, 3);
  static Rect ringFrame(int i, {bool gold = false}) =>
      Rect.fromLTWH((gold ? 128 : 0) + i * 32.0, 24, 32, 32);

  /// İkon sırası (art/_source/pixel/effects.js ile aynı).
  static const iconNames = [
    'pause',
    'play',
    'replay',
    'home',
    'share',
    'soundOn',
    'soundOff',
    'settings',
    'help', //
    'music',
    'sfx',
    'vibrate',
    'touch',
    'star',
    'flight',
    'pillars',
    'bolt',
    'sunset',
    'back',
    // Phase 2.3: keşif albümü
    'map',
    'lock',
    'check',
    'badge',
    // Phase 2.4: Game Center sıralaması
    'trophy',
    // Phase 2.5: Günün Uçuşu
    'calendar',
  ];
  static Rect iconRect(String name) =>
      Rect.fromLTWH(iconNames.indexOf(name) * 16.0, 0, 16, 16);

  static const _root = 'pixel_art';
  static const zoneLayers = [
    'sky',
    'sun',
    'clouds',
    'distant',
    'midground',
    'waterfront',
    'water',
    'water_hi',
    'ferry',
  ];
  static String zonePath(String zone, String layer) =>
      '$_root/backgrounds/$zone/$layer.png';
  static String landmarkPath(Landmark l) => switch (l) {
    Landmark.suleymaniye => '$_root/landmarks/suleymaniye.png',
    Landmark.galata => '$_root/landmarks/galata.png',
    Landmark.kizKulesi => '$_root/landmarks/kiz_kulesi.png',
    Landmark.bridge => '$_root/landmarks/bridge.png',
    Landmark.rumeliHisari => '$_root/landmarks/rumeli_hisari.png',
  };
  static String kitPath(ObstacleKitId k) =>
      '$_root/obstacles/kit_${k.name}.png';
  static const simitPath = '$_root/characters/simit_sheet.png';
  static const fxPath = '$_root/effects/fx.png';
  static const iconsPath = '$_root/ui/icons.png';

  /// İstanbul keşif haritası (160×160). Oyun açılışında yüklenmez: yalnızca harita ekranı açılınca.
  static const mapPath = 'assets/images/$_root/ui/istanbul_map.png';

  /// Kozmetik sheet yolları (katalogdan).
  static Map<String, String> get skinPaths => {
    for (final c in cosmeticCatalog)
      if (c.sheetAsset != null) c.id: c.sheetAsset!,
  };

  /// Bütün asset yolları (test: dosyaların varlığı kontrol edilir).
  static List<String> get allPaths => [
    simitPath,
    ...skinPaths.values,
    fxPath,
    iconsPath,
    for (final k in ObstacleKitId.values)
      for (final l in zoneLayers) zonePath(k.name, l),
    ...Landmark.values.map(landmarkPath),
    ...ObstacleKitId.values.map(kitPath),
  ];

  static Future<GameArt> load(Images images) async {
    Future<Image?> get(String path) async {
      try {
        return await images.load(
          path,
        ); // Flame önbelleği: ikinci çağrıda diskten okumaz
      } catch (e) {
        debugPrint('Asset yüklenemedi: $path ($e)');
        return null;
      }
    }

    Future<ZoneArt> zone(String key) async {
      final l = await Future.wait(
        zoneLayers.map((layer) => get(zonePath(key, layer))),
      );
      return ZoneArt(
        sky: l[0],
        sun: l[1],
        clouds: l[2],
        distant: l[3],
        midground: l[4],
        waterfront: l[5],
        water: l[6],
        waterHi: l[7],
        ferry: l[8],
      );
    }

    final zoneKeys = ObstacleKitId.values.map((k) => k.name).toList();
    final results = await Future.wait<Object?>([
      get(simitPath),
      Future.wait(zoneKeys.map(zone)),
      Future.wait(Landmark.values.map((l) => get(landmarkPath(l)))),
      Future.wait(ObstacleKitId.values.map((k) => get(kitPath(k)))),
      get(fxPath),
      get(iconsPath),
      Future.wait(skinPaths.values.map(get)),
    ]);
    final skinIds = skinPaths.keys.toList();
    final skinImages = results[6]! as List<Image?>;
    final zoneList = results[1]! as List<ZoneArt>;
    final lm = results[2]! as List<Image?>;
    final kits = results[3]! as List<Image?>;
    return GameArt(
      simitSheet: results[0] as Image?,
      zones: {
        for (var i = 0; i < zoneKeys.length; i++) zoneKeys[i]: zoneList[i],
      },
      landmarks: {
        for (var i = 0; i < Landmark.values.length; i++)
          if (lm[i] != null) Landmark.values[i]: lm[i]!,
      },
      kits: {
        for (var i = 0; i < ObstacleKitId.values.length; i++)
          if (kits[i] != null) ObstacleKitId.values[i]: kits[i]!,
      },
      fx: results[4] as Image?,
      icons: results[5] as Image?,
      skins: {
        for (var i = 0; i < skinIds.length; i++)
          if (skinImages[i] != null) skinIds[i]: skinImages[i]!,
      },
    );
  }
}
