import 'dart:math';
import 'dart:ui';

import '../config.dart';

/// Toplanabilir simitlerin yerleşim kuralları.
///
/// Simit, engel çiftinin geçidinin ortasında (x = engelin ortası) durur. Dikey konumu,
/// Simit'in engele değmeden simidin merkezine ulaşabileceği bantta seçilir:
///   [geçit üstü + kuş yarıçapı + güvenlik payı, geçit altı − kuş yarıçapı − güvenlik payı]
/// Oyuncu geçitten zaten geçmek zorunda olduğu için simit her zaman ulaşılabilirdir.
abstract final class PickupRules {
  /// Simit üretilecekse dikey konumu, üretilmeyecekse null.
  static double? place({
    required GameConfig config,
    required double gapCenter,
    required double gapHeight,
    required Random random,
  }) {
    if (random.nextDouble() >= config.pickupChance) return null;
    final band = reachableBand(
      config: config,
      gapCenter: gapCenter,
      gapHeight: gapHeight,
    );
    if (band == null) return null;
    // Bandın orta %70'i: kenara yapışık, riskli konumlar seçilmez
    final mid = (band.top + band.bottom) / 2;
    final span = (band.bottom - band.top) * 0.7;
    return mid + (random.nextDouble() - 0.5) * span;
  }

  /// Simit merkezinin bulunabileceği güvenli dikey bant (geçit çok darsa null).
  static ({double top, double bottom})? reachableBand({
    required GameConfig config,
    required double gapCenter,
    required double gapHeight,
  }) {
    final margin = config.birdHitRadius + config.pickupSafetyMargin;
    final top = gapCenter - gapHeight / 2 + margin;
    final bottom = gapCenter + gapHeight / 2 - margin;
    return bottom > top ? (top: top, bottom: bottom) : null;
  }

  /// Simit toplandı mı: kuş dairesi ile simit dairesi temas ediyor mu.
  static bool touches({
    required Offset bird,
    required double birdRadius,
    required Offset pickup,
    required double pickupRadius,
  }) {
    final r = birdRadius + pickupRadius;
    return (bird - pickup).distanceSquared <= r * r;
  }
}
