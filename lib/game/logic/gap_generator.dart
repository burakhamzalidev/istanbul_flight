import 'dart:math';

import '../config.dart';

/// Engel çiftleri arasındaki geçitleri üretir.
///
/// Adillik kuralları:
/// * Geçit her zaman HUD ile su arasındaki güvenli bandın içinde kalır.
/// * Ardışık iki geçidin merkezleri en fazla [GameConfig.maxGapShift] kadar farklıdır.
class GapGenerator {
  GapGenerator(this.config, {Random? random}) : _random = random ?? Random();

  final GameConfig config;
  final Random _random;
  double? _lastCenter;

  /// Verilen skor için yeni bir geçit merkezi ve yüksekliği üretir.
  ({double center, double height}) next(int score) {
    final height = config.gapForScore(score);
    final minCenter = config.gapMarginTop + height / 2;
    final maxCenter = config.worldHeight - config.gapMarginBottom - height / 2;

    var low = minCenter;
    var high = maxCenter;
    final last = _lastCenter;
    if (last != null) {
      low = max(low, last - config.maxGapShift);
      high = min(high, last + config.maxGapShift);
    }
    final center = low + _random.nextDouble() * (high - low);
    _lastCenter = center;
    return (center: center, height: height);
  }

  void reset() => _lastCenter = null;
}
