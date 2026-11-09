/// Günün Uçuşu'nun deterministik rastgele sayı üreticisi (Phase 2.5, docs/17 §3).
///
/// `dart:math` Random(seed) algoritması Dart sürümleri arasında değişebilir; günlük parkurun her cihazda
/// ve her uygulama sürümünde aynı olması için kendi 32 bit üreticimiz kullanılır (Mulberry32).
/// Tüm işlemler 32 bit tam sayıyla yapılır; çarpma 16 bitlik yarımlarla hesaplanır, böylece sonuç
/// platformun tam sayı genişliğinden bağımsızdır. Bu sınıfın çıktısı değişirse günlük parkurlar değişir:
/// test/daily_challenge_test.dart'taki altın değerler bunu yakalar.
class DailyRng {
  DailyRng(int seed) : _state = seed & _mask;

  static const _mask = 0xffffffff;
  int _state;

  /// 0 .. 2^32-1
  int nextUint32() {
    _state = (_state + 0x6D2B79F5) & _mask;
    var t = _state;
    t = imul32(t ^ (t >> 15), t | 1);
    t = (t ^ ((t + imul32(t ^ (t >> 7), t | 61)) & _mask)) & _mask;
    return (t ^ (t >> 14)) & _mask;
  }

  /// [0, 1)
  double nextDouble() => nextUint32() / 4294967296.0;

  /// 32 bit çarpımın alt 32 biti (JavaScript Math.imul'ün işaretsiz karşılığı).
  static int imul32(int a, int b) {
    final al = a & 0xffff, ah = (a >> 16) & 0xffff;
    final bl = b & 0xffff, bh = (b >> 16) & 0xffff;
    return (al * bl + (((ah * bl + al * bh) & 0xffff) << 16)) & _mask;
  }

  /// FNV-1a (32 bit) metin özeti: tohumlar okunabilir anahtarlardan türetilir.
  static int hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c & 0xff;
      h = imul32(h, 0x01000193);
      h ^= (c >> 8) & 0xff;
      h = imul32(h, 0x01000193);
    }
    return h;
  }
}
