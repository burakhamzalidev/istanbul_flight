import 'dart:typed_data';
import 'dart:ui';

/// Çizim çağrısı birleştirme ayarı (Phase 2.9, docs/22 §4).
///
/// Açıkken aynı görselden gelen parçalar tek `drawRawAtlas`, aynı renkteki ayrık dikdörtgenler tek
/// `drawPath` ile çizilir. Kapalıyken eski yol (parça başına bir çağrı) kullanılır; testler iki yolun
/// piksel piksel aynı sonucu verdiğini bu anahtarla karşılaştırır.
abstract final class RenderTuning {
  static bool batchDraws = true;

  /// Aynı görselden parçaları drawRawAtlas ile birleştirme. Kapalı: Windows test çizicisinde birebir aynıydı
  /// ama Codemagic Mac (Metal) çizicisinde kesirli koordinatlarda 292–892 piksel fark verdi (engelli sahneler).
  /// iPhone da Metal kullandığı için görüntü değişebilir → yalnızca yol birleştirmesi açık (docs/22 §4).
  static bool batchAtlas = false;
}

/// Aynı görselden çok parça: tek `drawRawAtlas` çağrısı. Tamponlar yeniden kullanılır (kare başına
/// nesne üretmez). Yalnızca iki eksende aynı ölçekli parçalar birleştirilir; [add] false dönerse
/// çağıran [flush] edip o parçayı `drawImageRect` ile çizer (sıra korunur).
class AtlasBatch {
  Float32List _xf = Float32List(4 * 32);
  Float32List _rc = Float32List(4 * 32);
  int _n = 0;

  int get length => _n;

  /// [src] görsel pikseli, [dst] tuval dikdörtgeni (dönüşsüz, ölçek + öteleme).
  bool add(Rect src, Rect dst) {
    // boş parça: çizilecek bir şey yok
    if (src.width <= 0 || src.height <= 0) return true;
    final sx = dst.width / src.width, sy = dst.height / src.height;
    // iki eksende aynı ölçek değilse birleştirilmez (çağıran drawImageRect'e düşer)
    if ((sx - sy).abs() > 1e-9 * sx.abs().clamp(1, double.infinity)) {
      return false;
    }
    if (4 * (_n + 1) > _xf.length) {
      _xf = Float32List(_xf.length * 2)..setAll(0, _xf);
      _rc = Float32List(_rc.length * 2)..setAll(0, _rc);
    }
    final i = 4 * _n++;
    _xf[i] = sx;
    _xf[i + 1] = 0;
    _xf[i + 2] = dst.left;
    _xf[i + 3] = dst.top;
    _rc[i] = src.left;
    _rc[i + 1] = src.top;
    _rc[i + 2] = src.right;
    _rc[i + 3] = src.bottom;
    return true;
  }

  void flush(Canvas canvas, Image image, Paint paint) {
    if (_n == 0) return;
    canvas.drawRawAtlas(
      image,
      Float32List.sublistView(_xf, 0, 4 * _n),
      Float32List.sublistView(_rc, 0, 4 * _n),
      null,
      null,
      null,
      paint,
    );
    _n = 0;
  }
}
