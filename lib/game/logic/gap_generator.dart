import 'dart:math';

import '../config.dart';

/// Geçit kuralları: klasik mod ve Günün Uçuşu (üretici v2) aynı kuralları kullanır.
///
/// Adillik kuralları:
/// * Geçit her zaman HUD ile su arasındaki güvenli bandın içinde kalır.
/// * Ardışık iki geçidin merkezi yukarı en fazla [GameConfig.maxGapRise], aşağı en fazla
///   [GameConfig.maxGapDrop] kayar (tırmanmak düşmekten zordur).
/// * [GameConfig.bigShift]'ten büyük bir sıçramanın ardından gelen geçidin kayma sınırları
///   [GameConfig.afterBigShiftScale] ile küçülür (art arda büyük zikzak yok).
abstract final class GapRules {
  /// Geçit merkezinin seçilebileceği aralık. [lastCenter]/[lastShift]: önceki geçidin merkezi ve
  /// ondan önceki geçide göre kayması (ilk geçitte null).
  static ({double low, double high}) centerRange(
    GameConfig c,
    double height, {
    double? lastCenter,
    double? lastShift,
  }) {
    var low = c.gapMarginTop + height / 2;
    var high = c.worldHeight - c.gapMarginBottom - height / 2;
    if (lastCenter != null) {
      final calm = lastShift != null && lastShift.abs() > c.bigShift
          ? c.afterBigShiftScale
          : 1.0;
      low = max(low, lastCenter - c.maxGapRise * calm);
      high = min(high, lastCenter + c.maxGapDrop * calm);
    }
    return (low: low, high: high);
  }
}

/// Engel çiftleri arasındaki geçitleri üretir ([GapRules]). Klasik mod ve Günün Uçuşu (v2) aynı
/// üreticiyi kullanır: klasikte [Random], günlükte tohumlu deterministik kaynak ([GapGenerator.seeded]).
class GapGenerator {
  GapGenerator(this.config, {Random? random})
    : _next = (random ?? Random()).nextDouble;

  /// [nextDouble] [0,1) aralığında, tohuma bağlı deterministik sayı üretir (ör. DailyRng).
  GapGenerator.seeded(this.config, double Function() nextDouble)
    : _next = nextDouble;

  final GameConfig config;
  final double Function() _next;
  double? _lastCenter;
  double? _lastShift;

  /// Verilen skor için yeni bir geçit merkezi ve yüksekliği üretir.
  ({double center, double height}) next(int score) {
    final height = config.gapForScore(score);
    final range = GapRules.centerRange(
      config,
      height,
      lastCenter: _lastCenter,
      lastShift: _lastShift,
    );
    final center = range.low + _next() * (range.high - range.low);
    final last = _lastCenter;
    _lastShift = last == null ? null : center - last;
    _lastCenter = center;
    return (center: center, height: height);
  }

  /// Son üretilen geçitten bir önceki geçidin merkezi (yoksa null).
  double? get previousCenter {
    final last = _lastCenter, shift = _lastShift;
    return last == null || shift == null ? null : last - shift;
  }

  void reset() {
    _lastCenter = null;
    _lastShift = null;
  }
}
