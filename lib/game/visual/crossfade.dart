/// İki görsel durum arasında yumuşak geçiş (ör. bölge değişince uzak silüet).
/// Saf mantık: zaman [update] ile ilerler, kare hızından bağımsızdır.
class Crossfade<T> {
  Crossfade(this._current, {this.duration = 2.5});

  final double duration;
  T _current;
  T? _previous;
  double _t = 1;

  T get current => _current;

  /// Solmakta olan önceki değer (geçiş bitince null).
  T? get previous => _previous;

  bool get isActive => _previous != null;

  /// Yeni değerin opaklığı (0..1, yumuşatılmış).
  double get alpha => _t * _t * (3 - 2 * _t);

  /// Önceki değerin opaklığı.
  double get previousAlpha => _previous == null ? 0 : 1 - alpha;

  /// Yeni hedef. Aynı değerse bir şey yapmaz. Geçiş sırasında çağrılırsa, o anda baskın
  /// olan değer "önceki" olur. Böylece aynı anda en fazla iki katman çizilir.
  void set(T next) {
    if (next == _current) return;
    if (_previous != null && alpha < 0.5) {
      // Yeni değer henüz baskın değilse eskisini koru, sadece hedefi değiştir
      _current = next;
      if (next == _previous) {
        _previous = null;
        _t = 1;
      }
      return;
    }
    _previous = _current;
    _current = next;
    _t = 0;
  }

  void update(double dt) {
    if (_previous == null) return;
    _t += dt / duration;
    if (_t >= 1) {
      _t = 1;
      _previous = null;
    }
  }

  /// Geçişsiz anında değiştir (yeniden başlatma).
  void snap(T value) {
    _current = value;
    _previous = null;
    _t = 1;
  }
}
