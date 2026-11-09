import 'package:flutter/foundation.dart';

import '../game/config.dart';
import '../services/game_center/game_center.dart';
import '../services/progress.dart';
import 'daily_challenge.dart';
import 'daily_state.dart';

/// Günün Uçuşu servisi: bugünün challenge tanımı ve saat güvenilirliği (Phase 2.5, docs/17 §6).
///
/// Sunucu yoktur. Gün, cihazın UTC saatinden hesaplanır; iki ek koruma vardır:
///  * dereceli oynanan en ileri gün kayıtta tutulur, cihaz tarihi onun gerisine alınırsa dereceli oyun
///    kapanır (saati geri alıp hak ya da ödül yenilenmez);
///  * Game Center'a bağlıyken Apple'ın günlük tablo döneminin günü ([trustedDay]) cihazın gününden
///    farklıysa dereceli oyun kapanır (saati ileri alıp yarının parkuru dereceli oynanmaz).
/// Game Center'sız ve çevrimdışıyken saati ileri almak tespit edilemez; bu sınır belgelenmiştir.
class DailyChallengeService {
  DailyChallengeService({
    DateTime Function()? clock,
    this.config = const GameConfig(),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final GameConfig config;

  /// Apple dönem bilgisinin geçerli sayıldığı süre. Duvar saatinden bağımsız kronometreyle ölçülür:
  /// gece yarısını geçen eski bilgi dereceli oyunu yanlışlıkla kapatmasın.
  static const trustedFor = Duration(minutes: 10);

  String? _trustedDay;
  final Stopwatch _trustedAge = Stopwatch();

  /// Apple'ın bildirdiği güncel günlük dönem (UTC gün anahtarı); bilinmiyorsa ya da bilgi eskiyse null.
  String? get trustedDay =>
      _trustedAge.isRunning && _trustedAge.elapsed < trustedFor
      ? _trustedDay
      : null;

  DateTime now() => _clock();

  /// Bugünün (UTC) challenge'ı. Günün ilk çağrısında parkur doğrulanır (~0,1 sn), sonra bellekte.
  DailyChallengeDefinition today() =>
      DailyGenerators.forDay(now(), config: config);

  DailyClockStatus clockStatus(PlayerProgress p) =>
      checkDailyClock(p.dailyChallenge, now(), trustedDay: trustedDay);

  /// Bir sonraki challenge'a (00:00 UTC) kalan süre.
  Duration timeToReset() {
    final n = now().toUtc();
    return utcDayStart(n).add(const Duration(days: 1)).difference(n);
  }

  /// Game Center günlük tablosunun açık dönemi (Apple sunucu saati). Yalnızca 00:00 UTC'de başlayan
  /// 24 saatlik bir dönem güvenilir gün sayılır; tablo farklı kurulduysa bilgi yok sayılır (dereceli oyun
  /// yanlışlıkla kapanmaz; gönderim ise dönem challenge gününe uymadığı için yapılmaz).
  void setOccurrence(GcOccurrence? o) {
    final start = o?.start.toUtc();
    if (o == null ||
        start == null ||
        start != utcDayStart(start) ||
        o.end.difference(o.start) != const Duration(days: 1)) {
      if (o != null) {
        debugPrint(
          'Günlük tablo dönemi beklenmeyen biçimde: ${o.start} – ${o.end}',
        );
      }
      _trustedDay = null;
      _trustedAge
        ..stop()
        ..reset();
      return;
    }
    _trustedDay = utcDayKey(start);
    _trustedAge
      ..reset()
      ..start();
  }
}
