import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../day_cycle.dart';
import '../game_art.dart';
import '../istanbul_flight_game.dart';
import 'background.dart';

/// Ekrandaki bir simge örneği (havuzda tekrar kullanılır).
class LandmarkInstance {
  Landmark landmark = Landmark.suleymaniye;
  double x = 0;
  double alpha = 0;
  double rise = 0;
  bool active = false;
  bool fadingOut = false;
}

/// L3: bölgenin kahraman simgesi (pixel art, bölge ışığında boyalı; tint uygulanmaz).
///
/// Geçiş sistemi (docs/05 §Bölge geçişi):
/// * Bölge değişince yeni simge BEKLEMEDEN, görünür alanın sağ yarısında belirir ([fadeTime] sürede
///   opaklaşır ve [riseDistance] kadar aşağıdan yükselir).
/// * Eski simge kaybolmaz: akmaya devam ederken aynı sürede solar → görsel sıçrama yok.
/// * Simge ekrandan çıkınca aynı bölgenin simgesi sağdan doğal olarak yeniden girer.
/// * Aynı anda en fazla 2 örnek çizilir (havuz: 3).
///
/// Karadaki simgeler (Süleymaniye, Galata) bu katmanda, orta plan binaların ARKASINDA çizilir.
/// Kıyıdaki ve sudaki simgeler (Kız Kulesi, köprü, Rumeli Hisarı) [LandmarkFrontLayer] ile
/// kıyı şeridinin önünde, yansımalarıyla birlikte çizilir (docs/08 §Parallax).
/// Sadece görseldir: fizik, puan ve engel üretimine dokunmaz.
class LandmarkLayer extends Component
    with HasGameReference<IstanbulFlightGame>, LayerContext {
  LandmarkLayer() : super(priority: 3);

  static const parallax = 0.16;

  /// Yeni simgenin odak noktasının yerleştiği yer (görünür genişlik oranı).
  static const focusAt = 0.64;
  static const fadeTime = 2.2;
  static const riseDistance = 60.0;

  final List<LandmarkInstance> _pool = List.generate(
    3,
    (_) => LandmarkInstance(),
  );
  Landmark? _zoneLandmark;
  final AlphaPaint _paint = AlphaPaint(), _reflection = AlphaPaint();
  final Paint _fallback = Paint();

  @visibleForTesting
  Iterable<LandmarkInstance> get activeInstances =>
      _pool.where((i) => i.active);

  /// Simge boyutu (pixel art boyutunun 4 katı), ufka göre taban kaydırması (+ = ufkun altında,
  /// − = tepede) ve odak noktası (görselin genişlik oranı: köprüde sağ kule, hisarda Saruca Paşa Kulesi).
  static ({double w, double h, double baseOffset, double focus}) layout(
    Landmark l,
  ) => switch (l) {
    // Süleymaniye + Üçüncü Tepe sırtı (docs/11): alt kenar ufkun 44 px üstünde; odak kubbe ile minareler arası
    Landmark.suleymaniye => (
      w: 832.0,
      h: 496.0,
      baseOffset: -176.0,
      focus: 0.4,
    ),
    // Galata: kule + tepedeki bina kümesi (docs/09); küme alt kenarı ufkun 40 px üstünde, sırtın arkasında
    Landmark.galata => (w: 704.0, h: 800.0, baseOffset: -160.0, focus: 0.5),
    // Kız Kulesi ve adacığı (docs/10): kule gövdesinin ortası görselin tam ortasında
    Landmark.kizKulesi => (w: 688.0, h: 528.0, baseOffset: 88.0, focus: 0.5),
    // Boğaz Köprüsü + Ortaköy Camii (docs/12): odak kule ile kara çıkıntısındaki cami, açıklık sağa uzanır
    Landmark.bridge => (w: 1920.0, h: 800.0, baseOffset: 72.0, focus: 0.15),
    // Rumeli Hisarı (docs/13): Boğaz'dan cepheden; odak kıyıdaki Halil Paşa Kulesi
    Landmark.rumeliHisari => (
      w: 1520.0,
      h: 528.0,
      baseOffset: 32.0,
      focus: 0.36,
    ),
  };

  /// Kıyının önünde (suda / sahilde) duran simgeler.
  static bool isFront(Landmark l) =>
      l == Landmark.kizKulesi ||
      l == Landmark.bridge ||
      l == Landmark.rumeliHisari;

  /// Odak noktası görünür alanın [at] oranına gelecek x.
  double focusX(Landmark l, double at) {
    final lay = layout(l);
    return width * at - lay.w * lay.focus;
  }

  void reset() {
    for (final i in _pool) {
      i.active = false;
    }
    _zoneLandmark = zones[0].landmark;
    _spawn(
      zones[0].landmark,
      x: focusX(zones[0].landmark, 0.6),
      alpha: 1,
      rise: 0,
    );
  }

  @override
  void onMount() {
    super.onMount();
    reset();
  }

  LandmarkInstance? _spawn(
    Landmark l, {
    required double x,
    required double alpha,
    required double rise,
  }) {
    final slot =
        _pool.where((i) => !i.active).firstOrNull ??
        _pool.reduce((a, b) => a.alpha < b.alpha ? a : b);
    return slot
      ..landmark = l
      ..x = x
      ..alpha = alpha
      ..rise = rise
      ..active = true
      ..fadingOut = false;
  }

  @override
  void update(double dt) {
    final target = game.dayCycle.zone.landmark;
    if (target != _zoneLandmark) {
      _zoneLandmark = target;
      for (final i in _pool) {
        if (i.active) i.fadingOut = true;
      }
      // Yeni simge: odak noktası görünür alanın %64'ünde, yükselerek belirir
      _spawn(target, x: focusX(target, focusAt), alpha: 0, rise: riseDistance);
    }

    final dx = game.frameScroll * parallax;
    final step = dt / fadeTime;
    for (final i in _pool) {
      if (!i.active) continue;
      i.x -= dx;
      if (i.fadingOut) {
        i.alpha = math.max(0, i.alpha - step);
        if (i.alpha == 0) i.active = false;
      } else {
        i.alpha = math.min(1, i.alpha + step);
        i.rise = math.max(0, i.rise - riseDistance * step);
      }
      if (i.x + layout(i.landmark).w < -40) {
        if (i.fadingOut) {
          i.active = false;
        } else {
          i.x = width + 120; // aynı bölgenin simgesi sağdan yeniden girer
        }
      }
    }
  }

  @override
  void render(Canvas canvas) => renderPass(canvas, front: false);

  /// [front] grubundaki simgeleri çizer: önce soluklaşanlar, sonra baskın olan.
  void renderPass(Canvas canvas, {required bool front}) {
    for (final pass in [true, false]) {
      for (final i in _pool) {
        if (i.active &&
            i.fadingOut == pass &&
            i.alpha > 0.01 &&
            isFront(i.landmark) == front) {
          _draw(canvas, i);
        }
      }
    }
  }

  void _draw(Canvas canvas, LandmarkInstance inst) {
    final img = game.art.landmarks[inst.landmark];
    final lay = layout(inst.landmark);
    final eased = inst.alpha * inst.alpha * (3 - 2 * inst.alpha);
    final base = horizon + lay.baseOffset + snapPx(inst.rise);
    final dst = Rect.fromLTWH(snapPx(inst.x), base - lay.h, lay.w, lay.h);
    if (img == null) {
      _fallback.color = pal.landmark.withValues(alpha: eased);
      canvas.drawRect(
        Rect.fromLTWH(dst.center.dx - 30, dst.top, 60, dst.height),
        _fallback,
      );
      return;
    }
    final src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );
    if (isFront(inst.landmark)) {
      // Su yansıması: ters çevrilmiş, soluk, piksel satırları dalgayla hafifçe kayar
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(dst.left - 16, base, dst.right + 16, worldH),
      );
      canvas.translate(0, base * 2);
      canvas.scale(1, -1);
      final p = _reflection.at(
        eased * (inst.landmark == Landmark.rumeliHisari ? 0.14 : 0.28),
      );
      const band = 8.0; // px satırı bandı
      for (var y = 0.0; y < img.height; y += band) {
        final h = math.min(band, img.height - y);
        final wob = snapPx(math.sin(game.time * 1.8 + y * 0.4) * 6);
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, img.height - y - h, src.width, h),
          Rect.fromLTWH(
            dst.left + wob,
            base - (y + h) * kArtPx,
            lay.w,
            h * kArtPx,
          ),
          p,
        );
      }
      canvas.restore();
    }
    canvas.drawImageRect(img, src, dst, _paint.at(eased));
  }
}

/// L8: kıyı şeridinin ve vapurun önündeki simgeler ([LandmarkLayer.isFront]).
class LandmarkFrontLayer extends Component {
  LandmarkFrontLayer(this.source) : super(priority: 8);
  final LandmarkLayer source;

  @override
  void render(Canvas canvas) => source.renderPass(canvas, front: true);
}
