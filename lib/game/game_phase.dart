/// Oyunun durumları.
enum GamePhase {
  /// Oyun başlamayı bekliyor. Simit süzülüyor, engel yok. İlk dokunuş oyunu başlatır ve kanat çırptırır.
  ready,

  /// Simit uçuyor, engeller akıyor, puan sayılıyor.
  playing,

  /// Oyuncu duraklattı ya da uygulama arka plana alındı. Simülasyon durur.
  paused,

  /// Çarpışma oldu. Skor sabit, üretim ve puanlama durdu. Simit düşüş animasyonunu tamamlar.
  gameOver,
}
