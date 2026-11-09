import 'package:flutter/material.dart';

/// Arayüz renkleri (docs/01 §9.9). Font: özgün bitmap "MartiPixel" (docs/08), ThemeData'da genel.
/// Pixel font 10 punto = 1 nokta/piksel: boyutlar 5'in katı (2× ekranda tam piksel).
abstract final class UiColors {
  static const cream = Color(0xFFF2E6D0);
  static const paper = Color(0xFFFBF7EE);
  static const navy = Color(0xFF1F3A5F);
  static const navySoft = Color(0xFF4C6280);
  static const tile = Color(0xFFD9643A);
  static const mustard = Color(0xFFE8B04B);
  static const ink = Color(0xFF2B2B3A);

  /// Ana aksiyon (kiremidin koyusu): beyaz yazıyla ~5,2:1 kontrast (WCAG AA).
  static const action = Color(0xFFB84A26);
  static const actionPressed = Color(0xFF9C3C1E);

  /// Oyun sahnesi üstündeki yarı saydam paneller (okunabilirlik).
  static const scrim = Color(0xB31F3A5F);
}

/// Oyun sahnesi üstündeki beyaz yazılar için gölge (her arka planda okunur).
const kSceneTextShadow = [
  Shadow(color: Color(0xCC1F3A5F), offset: Offset(0, 2)),
];

/// Phase 2.8 tasarım sistemi: ortak aralıklar (2 pt piksel ızgarası) ve dokunma hedefi.
abstract final class UiSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;

  /// En küçük dokunma hedefi (iOS İnsan Arayüzü Yönergeleri: 44 × 44 pt).
  static const tap = 44.0;
}

/// Animasyon süreleri: kısa ve tutarlı; azaltılmış harekette animasyon yok, son durum hemen gösterilir.
abstract final class UiDur {
  /// Dokunma tepkisi, sayaç büyümesi.
  static const fast = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 220);

  /// Damga, kart girişi, bakiye sayma.
  static const emphasis = Duration(milliseconds: 420);

  /// İlerleme çubuğunun dolması.
  static const fill = Duration(milliseconds: 700);
}

/// Metin seviyeleri: piksel font boyutları 5'in katı (10 dipnot, 15 gövde, 20 başlık, 25+ vurgu).
abstract final class UiText {
  static const caption = TextStyle(fontSize: 10, color: UiColors.navySoft);
  static const body = TextStyle(fontSize: 15, color: UiColors.navy);
  static const heading = TextStyle(fontSize: 20, color: UiColors.navy);
  static const score = TextStyle(
    fontSize: 70,
    color: UiColors.paper,
    height: 1,
    shadows: [Shadow(color: Color(0x991F3A5F), offset: Offset(0, 4))],
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const stamp = TextStyle(
    fontSize: 20,
    letterSpacing: 2,
    color: UiColors.navy,
  );
}

/// Türkçe büyük harf: i → İ, ı → I (Dart'ın toUpperCase'i dil kuralı uygulamaz).
String trUpper(String s) =>
    s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
