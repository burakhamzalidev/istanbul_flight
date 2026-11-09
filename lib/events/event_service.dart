import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/config.dart';
import '../services/game_center/game_center.dart';
import '../services/progress.dart';
import 'event_calendar.dart';
import 'event_definition.dart';
import 'event_state.dart';

/// Etkinlik servisi: takvimdeki açık etkinlikler, tanımları ve saat güvenilirliği (Phase 2.7, docs/20 §10).
///
/// Sunucu yok. Hafta cihazın UTC saatinden hesaplanır; iki koruma vardır (Günün Uçuşu ile aynı yaklaşım):
///  * dereceli oynanan en ileri hafta kayıtta tutulur, cihaz tarihi onun gerisine alınırsa dereceli oyun
///    kapanır;
///  * Game Center'a bağlıyken kupa tablosunun Apple dönemi ([trustedWeek]) cihazın haftasından farklıysa
///    dereceli oyun kapanır (saati ileri alıp gelecek haftanın kupası oynanmaz).
/// Game Center'sız ve çevrimdışıyken saati ileri almak tespit edilemez; bu sınır belgelenmiştir.
class EventService {
  EventService({DateTime Function()? clock, this.config = const GameConfig()})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final GameConfig config;

  static const trustedFor = Duration(minutes: 10);

  int? _trustedWeek;
  final Stopwatch _trustedAge = Stopwatch();

  DateTime now() => _clock();

  /// Apple'ın bildirdiği güncel kupa haftası (takvim haftası); bilinmiyorsa ya da bilgi eskiyse null.
  int? get trustedWeek =>
      _trustedAge.isRunning && _trustedAge.elapsed < trustedFor
      ? _trustedWeek
      : null;

  EventSlot? activeCup() => EventCalendar.activeCup(now());
  EventSlot? activeSpecial() => EventCalendar.activeSpecial(now());
  SeasonDefinition? season() => EventCalendar.seasonAt(now());

  /// Etkinliğin doğrulanmış tanımı (ilk çağrıda parkur doğrulanır, sonra bellekte).
  EventDefinition definition(EventSlot slot) =>
      EventGenerators.build(slot, config: config);

  /// Açık etkinliklerin parkurlarını arka planda hazırlar (ilk ekran beklemesin).
  Future<void> prepareActive() async {
    for (final s in [?activeCup(), ?activeSpecial()]) {
      await EventGenerators.prepare(s);
    }
  }

  EventClockStatus clockStatus(PlayerProgress p) =>
      checkEventClock(p.events, now(), trustedWeek: trustedWeek);

  bool canRank(PlayerProgress p, EventSlot slot) =>
      canRankEvent(p, slot, now(), trustedWeek: trustedWeek);

  Duration timeLeft(EventSlot s) {
    final d = s.endAtUtc.difference(now().toUtc());
    return d.isNegative ? Duration.zero : d;
  }

  Duration timeToStart(EventSlot s) {
    final d = s.startAtUtc.difference(now().toUtc());
    return d.isNegative ? Duration.zero : d;
  }

  /// Kupa tablosunun açık dönemi (Apple sunucu saati). Yalnızca pazartesi 00:00 UTC'de başlayan 7 günlük
  /// bir dönem güvenilir hafta sayılır; tablo farklı kurulduysa bilgi yok sayılır (dereceli oyun
  /// yanlışlıkla kapanmaz; gönderim ise dönem etkinliğe uymadığı için yapılmaz).
  void setOccurrence(GcOccurrence? o) {
    final start = o?.start.toUtc();
    if (o == null ||
        start == null ||
        start != EventCalendar.weekStart(start) ||
        o.end.difference(o.start) != const Duration(days: 7)) {
      if (o != null) {
        debugPrint('Kupa tablosu dönemi beklenmeyen biçimde: ${o.start} – ${o.end}');
      }
      _trustedWeek = null;
      _trustedAge
        ..stop()
        ..reset();
      return;
    }
    _trustedWeek = EventCalendar.weekIndex(start);
    _trustedAge
      ..reset()
      ..start();
  }
}
