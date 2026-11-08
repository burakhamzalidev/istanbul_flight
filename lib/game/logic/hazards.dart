import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../config.dart';

/// Phase 2.6.3: kontrollü dinamik engeller (docs/19 §5a).
///
/// İki engel çifti arasındaki boşluğa ("koridor") yerleşen, önceden görünen ve ritmi tahmin edilebilen
/// tehlikeler. Yalnızca klasik modda ve ikinci gün bölgelerinde ([GameConfig.hazardsFromScore]); Günün Uçuşu
/// v1/v2 parkurlarına uygulanmaz.
///
/// * **Martı sürüsü:** sağdan kuşa doğru uçar (kaydırmadan [GameConfig.flockApproach] oranında hızlı) ve kuşun
///   hizasına koridorun ortasında gelir; dikeyde yavaş ve düzenli salınır. Koridorun yalnızca bir kenarını
///   kaplar; iki geçidi birleştiren yolun ortası her zaman açıktır.
/// * **Hava akımı (rüzgâr):** koridorda kuşa dikey ivme verir; kenarlarda sıfır, ortada en büyük (sin²).
///   Akımın yönünde kavislenen rüzgâr şeritleriyle önceden belli olur; ani itme yoktur.
enum HazardKind { flock, gust }

@immutable
class Hazard {
  const Hazard.flock({
    required this.corridor,
    required this.baseY,
    required this.phase,
  }) : kind = HazardKind.flock,
       accel = 0;

  const Hazard.gust({required this.corridor, required this.accel})
    : kind = HazardKind.gust,
      baseY = 0,
      phase = 0;

  final HazardKind kind;

  /// Koridor: [corridor]-1. ve [corridor]. engel çiftleri arasındaki boşluk.
  final int corridor;

  /// Sürünün salınım merkezi (dünya y).
  final double baseY;

  /// Salınım fazı (0..1).
  final double phase;

  /// Rüzgârın dikey ivmesi (birim/s²; + aşağı, − yukarı).
  final double accel;

  /// Sürünün [time] anındaki merkez y'si (oyun saati; kare hızından bağımsız).
  double flockY(GameConfig c, double time) =>
      baseY +
      c.flockBob * math.sin(2 * math.pi * (time / c.flockBobPeriod + phase));

  /// Sürünün çarpışma dikdörtgeni (görselden küçük: kanat uçları dışarıda, oyuncu lehine).
  Rect flockRect(GameConfig c, double centerX, double time) => Rect.fromCenter(
    center: Offset(centerX, flockY(c, time)),
    width: c.flockWidth * 0.8,
    height: c.flockHeight * 0.7,
  );
}

/// Koridor geometrisi ve yerleşim kuralları (saf; oyun, planlayıcı ve doğrulayıcı aynı kuralları kullanır).
abstract final class HazardRules {
  /// Bu kadar dikey kayma varsa sürünün tarafı kaymanın yönüne göre seçilir ([HazardPlanner]).
  static const flockSideShift = 60.0;

  /// Koridorun yatay ortası: önceki engelin sağ kenarı ile sonrakinin sol kenarının ortası.
  static double corridorCenterX(
    GameConfig c,
    double nextLeft,
    double spacing,
  ) => nextLeft - (spacing - c.obstacleWidth) / 2;

  /// Sürünün yatay merkezi: kuşa doğru uçar, koridor ortası kuşun hizasındayken tam kuşun hizasındadır.
  static double flockCenterX(GameConfig c, double corridorCenter, double birdX) =>
      birdX + (corridorCenter - birdX) * (1 + c.flockApproach);

  /// Hava akımının kuşun konumundaki gücü (0..1): koridor kenarlarında 0, ortasında 1 (sin²).
  static double gustFactor(
    GameConfig c,
    double birdX,
    double nextLeft,
    double spacing,
  ) {
    final w = spacing - c.obstacleWidth;
    final u = (birdX - (nextLeft - w)) / w;
    if (u <= 0 || u >= 1) return 0;
    final s = math.sin(math.pi * u);
    return s * s;
  }

  /// Kuş merkezi bu koridorda mı (önceki engelin sağı ile sonrakinin solu arası).
  static bool inCorridor(
    GameConfig c,
    double birdX,
    double nextLeft,
    double spacing,
  ) => birdX > nextLeft - (spacing - c.obstacleWidth) && birdX < nextLeft;

  /// İki geçidi birleştiren yolun dikey zarfı: önceki ve sonraki geçidin birleşimi.
  static ({double top, double bottom}) envelope(
    ({double center, double height}) a,
    ({double center, double height}) b,
  ) => (
    top: math.min(a.center - a.height / 2, b.center - b.height / 2),
    bottom: math.max(a.center + a.height / 2, b.center + b.height / 2),
  );

  /// Sürünün salınım merkezi: zarfın bir kenarından içeri en fazla [GameConfig.flockOverlap] kadar girer
  /// (salınımın en uç anında bile). [top] true ise üst kenar.
  static double flockBaseY(
    GameConfig c,
    ({double top, double bottom}) env, {
    required bool top,
  }) {
    final half =
        c.flockHeight * 0.35 + c.flockBob; // çarpışma yarı yüksekliği + salınım
    return top
        ? env.top + c.flockOverlap - half
        : env.bottom - c.flockOverlap + half;
  }
}

/// Tehlike planlayıcısı: her yeni engel çifti için önündeki koridora tehlike koyar mı karar verir.
///
/// Deterministik: aynı sayı kaynağı aynı kararları verir. Her çağrıda kaynaktan her zaman üç sayı çekilir
/// (tehlike olsa da olmasa da akış hizalı kalır).
class HazardPlanner {
  HazardPlanner(this.config, this._next);

  final GameConfig config;
  final double Function() _next;
  int _cooldown = 0;

  Hazard? next({
    required int corridor,
    required int score,
    required ({double center, double height}) previous,
    required ({double center, double height}) gap,
  }) {
    final roll = _next(), side = _next(), phase = _next();
    if (score < config.hazardsFromScore) return null;
    if (_cooldown > 0) {
      _cooldown--;
      return null;
    }
    if (roll < config.flockChance) {
      _cooldown = config.hazardCooldown;
      final env = HazardRules.envelope(previous, gap);
      // Geçit belirgin biçimde kayıyorsa sürü, kuşun terk ettiği tarafta durur (tırmanışta altta, inişte
      // üstte): kuşun gittiği yolu daraltmaz. Hizalı geçitlerde taraf rastgele.
      final shift = gap.center - previous.center;
      final top = shift.abs() > HazardRules.flockSideShift
          ? shift > 0
          : side < 0.5;
      return Hazard.flock(
        corridor: corridor,
        baseY: HazardRules.flockBaseY(config, env, top: top),
        phase: phase,
      );
    }
    if (roll < config.flockChance + config.gustChance) {
      _cooldown = config.hazardCooldown;
      // rüzgâr kuşu sonraki geçide doğru iter ya da hafifçe karşı koyar (ikisi de yumuşak)
      return Hazard.gust(
        corridor: corridor,
        accel: (side < 0.5 ? -1 : 1) * config.gustAccel,
      );
    }
    return null;
  }

  void reset() => _cooldown = 0;
}
