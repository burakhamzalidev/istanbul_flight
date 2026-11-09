// ÜRETİLDİ — elle düzenlemeyin. Kaynak: art/_source/pixel/obstacles.js
// ignore_for_file: constant_identifier_names
import 'dart:ui';

/// Engel kiti yerleşimi (dünya birimi). Atlas pixel art olarak [atlasScale] çözünürlüktedir:
/// kaynak dikdörtgen = yerleşim × atlasScale. Işık maskesi yok: [lightsOffsetY] atlasın alt kenarıdır.
abstract final class ObstacleKitLayout {
  static const atlasScale = 0.5;
  static const bodyWidth = 196.0;
  static const capWidth = 224.0;
  static const overhang = 14.0;
  static const tileHeight = 192.0;
  static const capHeight = 128.0;
  static const baseHeight = 320.0;
  static const lightsOffsetY = 520.0;
  static const bottomBodyA = Rect.fromLTWH(0, 0, 196, 192);
  static const bottomBodyB = Rect.fromLTWH(200, 0, 196, 192);
  static const topBodyA = Rect.fromLTWH(400, 0, 196, 192);
  static const topBodyB = Rect.fromLTWH(600, 0, 196, 192);
  static const bottomCap = Rect.fromLTWH(0, 200, 224, 128);
  static const topCap = Rect.fromLTWH(232, 200, 224, 128);
  static const bottomBase = Rect.fromLTWH(464, 200, 224, 320);

  /// Alt başlıkta hitbox üst kenarının görsel içindeki y konumu (üstünde kalan baca vb. çarpışmasız süs).
  static const bottomCapBoundary = <String, double>{
    'halic': 28.0,
    'galata': 32.0,
    'kizkulesi': 12.0,
    'kopru': 8.0,
    'rumeli': 12.0,
    'ortakoy': 32.0,
    'emirgan': 28.0,
    'dolmabahce': 20.0,
    'uskudar': 28.0,
  };
}
