import 'package:flutter/foundation.dart';

// Phase 2.8: ilk uçuş eğitimi (docs/21 §4).
//
// Saf durum makinesi: oyun motoru olayları bildirir (dokunuş, uçuş adımı, engel geçişi, simit, çarpışma),
// makine aşamayı ve bir sonraki engelin gerekip gerekmediğini söyler. Eğitim gerçek bir uçuş değildir:
// skor, simit, XP, görev, başarım, rekor ve Game Center'a hiçbir şey yazılmaz (motor olay yayınlamaz).

/// Eğitimin aşamaları (ekranda 1/3, 2/3, 3/3).
enum TutorialStage {
  /// Aşama 1: dokunarak uç ve bir süre havada kal.
  fly,

  /// Aşama 2: geniş, kolay bir geçitten geç.
  obstacle,

  /// Aşama 3: geçitteki simidi topla.
  simit,

  /// Tamamlandı: normal uçuşa geçiş.
  done;

  /// 1..3 (bitti: 3).
  int get number => switch (this) {
    fly => 1,
    obstacle => 2,
    simit || done => 3,
  };

  String get title => switch (this) {
    fly => 'Uçmayı öğren',
    obstacle => 'Engelleri geç',
    simit || done => 'Simit topla',
  };
}

/// Aşama içindeki ipucu (yeniden deneme, kaçırılan simit).
enum TutorialHint { none, crashed, missedSimit }

/// Eğitim akışı. Her olay idempotent ve sıraya bağlı; geçersiz aşamada gelen olay yok sayılır.
class TutorialFlow {
  /// Aşama 1: bu kadar saniye havada kalınca (çarpmadan) engel aşamasına geçilir.
  static const flySeconds = 2.5;

  /// Eğitim engelleri: klasik başlangıç geçidinden (370) belirgin geniş.
  static const obstacleGap = 560.0;
  static const simitGap = 520.0;

  TutorialStage _stage = TutorialStage.fly;
  TutorialHint _hint = TutorialHint.none;
  double _air = 0;
  int _flaps = 0;
  bool _obstacleOut = false;
  bool _simitTaken = false;
  int _retries = 0;

  TutorialStage get stage => _stage;
  TutorialHint get hint => _hint;
  int get flaps => _flaps;
  int get retries => _retries;
  bool get isDone => _stage == TutorialStage.done;

  /// Aşama 1'in ilerlemesi (0..1).
  double get flyProgress => (_air / flySeconds).clamp(0.0, 1.0);

  /// Şu anda ekranda engel yoksa ve aşama engel istiyorsa true: motor bir engel üretir.
  bool get wantsObstacle =>
      !_obstacleOut &&
      (_stage == TutorialStage.obstacle || _stage == TutorialStage.simit);

  /// İstenen engelin simidi var mı (Aşama 3).
  bool get obstacleHasSimit => _stage == TutorialStage.simit;

  void reset() {
    _stage = TutorialStage.fly;
    _hint = TutorialHint.none;
    _air = 0;
    _flaps = 0;
    _obstacleOut = false;
    _simitTaken = false;
    _retries = 0;
  }

  void onFlap() => _flaps++;

  /// Uçuşun sabit adımı (yalnızca oynarken).
  void onStep(double dt) {
    if (_stage != TutorialStage.fly) return;
    _air += dt;
    if (_air >= flySeconds) {
      _stage = TutorialStage.obstacle;
      _hint = TutorialHint.none;
    }
  }

  void onObstacleSpawned() => _obstacleOut = true;

  void onSimitCollected() {
    if (_stage == TutorialStage.simit) _simitTaken = true;
  }

  /// Kuş engelin ötesine geçti.
  void onObstaclePassed() {
    if (!_obstacleOut) return;
    _obstacleOut = false;
    switch (_stage) {
      case TutorialStage.obstacle:
        _stage = TutorialStage.simit;
        _hint = TutorialHint.none;
      case TutorialStage.simit:
        if (_simitTaken) {
          _stage = TutorialStage.done;
          _hint = TutorialHint.none;
        } else {
          _hint = TutorialHint.missedSimit; // bir simitli geçit daha gelir
        }
      case TutorialStage.fly || TutorialStage.done:
        break;
    }
  }

  /// Engele ya da suya çarptı: aynı aşama baştan (ilerleme kaybolmaz, ceza yok).
  void onCrash() {
    if (_stage == TutorialStage.done) return;
    _obstacleOut = false;
    if (_stage == TutorialStage.fly) _air = 0;
    _hint = TutorialHint.crashed;
    _retries++;
  }

  @visibleForTesting
  bool get obstacleOut => _obstacleOut;
}
