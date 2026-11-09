import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/challenge/daily_challenge.dart';
import 'package:istanbul_flight/challenge/daily_state.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/events/event_calendar.dart';
import 'package:istanbul_flight/events/event_definition.dart';
import 'package:istanbul_flight/events/event_state.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/game/logic/hazards.dart';
import 'package:istanbul_flight/game/weather.dart';
import 'package:istanbul_flight/progression/game_events.dart';
import 'package:istanbul_flight/services/game_center/game_center.dart';
import 'package:istanbul_flight/services/game_center/game_center_controller.dart';
import 'package:istanbul_flight/services/progress.dart';

import 'fakes.dart';
import 'game_center_fakes.dart';

// Phase 2.7 (docs/20 §5, §6): etkinlik uçuşu oyun motorunda, Game Center haftalık kupa tablosu.

final _week2 = DateTime.utc(2026, 11, 25, 12); // 3. hafta: kupa Rüzgâr Ustası
final _windCup = EventCalendar.activeCup(_week2)!;
final _week4 = DateTime.utc(2026, 12, 9, 12); // 5. hafta: kupa Boğaz Maratonu (2. sezon)

class _Recorder implements GameEventListener {
  final finished = <RunResult>[];
  final started = <RunStarted>[];
  @override
  void onGameEvent(GameEvent e) {
    if (e is RunFinished) finished.add(e.result);
    if (e is RunStarted) started.add(e);
  }
}

Future<(IstanbulFlightGame, TestServices, _Recorder)> _game({
  DateTime? now,
  PlayerProgress progress = const PlayerProgress(),
  Vector2? size,
  int classicSeed = 7,
}) async {
  final t = TestServices(progress: progress, clock: () => now ?? _week2);
  final rec = _Recorder();
  t.services.listeners.add(rec);
  final g = await initializeGame(
    () => IstanbulFlightGame(
      scores: InMemoryScoreRepository(),
      random: Random(classicSeed),
      pickupRandom: Random(classicSeed + 1),
      hazardRandom: Random(classicSeed + 2),
      loadArt: false,
      services: t.services,
    ),
  );
  g.onGameResize(size ?? Vector2(1080, 1920));
  await g.ready();
  return (g, t, rec);
}

/// Çarpışmasız, otomatik pilotla etkinlik uçuşu; görülen engeller ve tehlikeler (sırasıyla).
Future<(List<String>, List<String>)> _eventRun({
  required double dt,
  Vector2? size,
  int classicSeed = 7,
}) async {
  final (g, t, _) = await _game(size: size, classicSeed: classicSeed);
  final def = t.services.events.definition(_windCup);
  g.debugInvincible = true;
  g.autopilot = true;
  g.startEvent(def);
  g.handleTap();
  final obstacles = <int, String>{};
  final hazards = <int, String>{};
  for (var i = 0, n = (60 / dt).round(); i < n; i++) {
    g.update(dt);
    for (final o in g.obstacles) {
      obstacles[o.courseIndex] =
          '${o.gapCenter.toStringAsFixed(4)}/${o.gapHeight}/${o.pickupY?.toStringAsFixed(4)}';
    }
    for (final h in g.hazardViews) {
      hazards[h.anchor.courseIndex] = '${h.hazard.kind.name}:${h.hazard.accel}';
    }
  }
  final keys = obstacles.keys.toList()..sort();
  return (
    [for (final k in keys.take(30)) obstacles[k]!],
    [
      for (final k in (hazards.keys.toList()..sort()).where((k) => k < 30))
        '$k=${hazards[k]}',
    ],
  );
}

/// Uçuşu işler ve zaman uyumsuz gönderimlerin bitmesini bekler.
Future<void> _h(GameCenterController gc, RunResult r) async {
  await gc.handleRun(r);
  await pumpEventQueue();
}

void main() {
  group('Oyun motoru', () {
    test('Gece Uçuşu sahneyi Rumeli Hisarı\'nda başlatır; menüye dönünce klasik rota geri gelir', () async {
      final night = DateTime.utc(2026, 11, 30, 12); // 4. hafta: kupa Gece Uçuşu
      final (g, t, _) = await _game(now: night);
      final slot = EventCalendar.activeCup(night)!;
      expect(slot.type, EventType.nightFlight);
      g.startEvent(t.services.events.definition(slot));
      expect(g.phase.value, GamePhase.ready);
      expect(g.dayCycle.zoneIndex, 4);
      expect(g.zoneIndex.value, 4);
      expect(g.runMode.value, RunMode.event);
      g.openMenu();
      expect(g.dayCycle.zoneIndex, 0);
      expect(g.dayCycle.route, isNull);
      expect(g.eventDefinition.value, isNull);
      expect(g.runMode.value, RunMode.classic);
    });

    test('etkinlik parkuru: aynı engeller, simitler ve dinamik engeller kare hızından ve ekrandan bağımsız', () async {
      final a = await _eventRun(dt: 1 / 60);
      final b = await _eventRun(dt: 1 / 30, size: Vector2(1440, 1920));
      final c = await _eventRun(dt: 1 / 120, classicSeed: 99);
      expect(a.$1.length, 30);
      expect(b.$1, a.$1);
      expect(c.$1, a.$1);
      expect(a.$2, isNotEmpty); // Rüzgâr Ustası: hava akımları çıktı
      expect(b.$2, a.$2);
      expect(c.$2, a.$2);
      // parkurla birebir aynı (motor tanımdaki parkuru oynar)
      final course = EventCourse(EventGenerators.build(_windCup));
      expect(a.$1.first, isNotEmpty);
      expect(
        a.$1[5],
        '${course.course.at(5).gapCenter.toStringAsFixed(4)}/${course.course.at(5).gapHeight}/${course.course.at(5).pickupY?.toStringAsFixed(4)}',
      );
    });

    test('etkinlikte hava hep açık ve sürü yok (Rüzgâr Ustası yalnızca hava akımı)', () async {
      final (g, t, _) = await _game();
      g.debugInvincible = true;
      g.autopilot = true;
      g.startEvent(t.services.events.definition(_windCup));
      g.handleTap();
      for (var i = 0; i < 60 * 40; i++) {
        g.update(1 / 60);
        expect(g.weatherLayer.weather, Weather.clear);
        expect(g.hazardViews.where((h) => h.hazard.kind == HazardKind.flock), isEmpty);
      }
    });

    test('uçuş sonu: RunResult etkinlik kimliği ve modu taşır; etkinlik kaydı ve sezon güncellenir', () async {
      final (g, t, rec) = await _game();
      g.startEvent(t.services.events.definition(_windCup));
      g.handleTap();
      // kanat çırpmadan düşer → suya çarpar
      for (var i = 0; i < 60 * 6 && g.phase.value == GamePhase.playing; i++) {
        g.update(1 / 60);
      }
      expect(g.phase.value, GamePhase.gameOver);
      expect(rec.started.single.eventId, _windCup.eventId);
      final r = rec.finished.single;
      expect(r.mode, RunMode.event);
      expect(r.eventId, _windCup.eventId);
      final p = t.services.progress.value;
      expect(p.events[_windCup.eventId]!.flights, 1);
      expect(t.services.progress.lastEvent.value!.ranked, isTrue);
      final season = EventCalendar.seasonAt(_week2)!;
      expect(p.events.season(season.seasonId).points, greaterThan(0));
      // klasik rekor etkinlik uçuşundan etkilenmez
      expect(g.best.value, 0);
    });

    test('cihaz saati geri alınmışsa uçuş antrenmana döner (ödül ve sıralama yok)', () async {
      final ahead = const PlayerProgress().copyWith(
        events: const EventProgressState(highWaterWeek: 9),
      );
      final (g, t, rec) = await _game(progress: ahead);
      g.startEvent(t.services.events.definition(_windCup));
      g.handleTap();
      expect(g.runMode.value, RunMode.eventPractice);
      expect(g.eventPracticeNotice.value, isTrue);
      for (var i = 0; i < 60 * 6 && g.phase.value == GamePhase.playing; i++) {
        g.update(1 / 60);
      }
      expect(rec.finished.single.mode, RunMode.eventPractice);
      expect(t.services.progress.value.events[_windCup.eventId], isNull);
    });

    test('klasik regresyon: etkinlikten sonra klasik parkur ilk açılıştakiyle aynı', () async {
      Future<List<String>> classic({required bool afterEvent}) async {
        final (g, t, _) = await _game();
        if (afterEvent) {
          g.startEvent(t.services.events.definition(_windCup));
          g.openMenu();
        }
        g.debugInvincible = true;
        g.autopilot = true;
        g.startFromMenu();
        g.handleTap();
        final seen = <String>{};
        for (var i = 0; i < 60 * 20; i++) {
          g.update(1 / 60);
          for (final o in g.obstacles) {
            seen.add('${o.seed}:${o.gapCenter.toStringAsFixed(3)}:${o.courseIndex}');
          }
        }
        expect(g.runMode.value, RunMode.classic);
        return seen.toList()..sort();
      }

      expect(await classic(afterEvent: true), await classic(afterEvent: false));
    });

    test('Günün Uçuşu regresyonu: etkinlikten günlüğe geçince günlük parkur ve Haliç', () async {
      final (g, t, _) = await _game();
      g.startEvent(t.services.events.definition(_windCup));
      expect(g.dayCycle.zoneIndex, 5); // Emirgan
      g.startDaily(ranked: false);
      expect(g.dayCycle.zoneIndex, 0);
      expect(g.eventDefinition.value, isNull);
      expect(g.runMode.value, RunMode.dailyPractice);
      expect(g.dailyDefinition.value!.challengeId, t.services.daily.today().challengeId);
    });
  });

  group('Game Center haftalık kupa', () {
    RunResult cupRun(
      String id,
      int score, {
      int simits = 0,
      EventSlot? slot,
      RunMode mode = RunMode.event,
    }) => RunResult(
      runId: id,
      score: score,
      obstaclesPassed: score,
      simits: simits,
      nearMisses: 0,
      maxZone: 0,
      flightMs: score * 2000,
      mode: mode,
      eventId: (slot ?? _windCup).eventId,
    );

    (GameCenterController, FakeGameCenterApi, InMemoryGameCenterStore, List<(String, DailyGcStatus)>) make({
      DateTime? now,
      DateTime? weekStart,
    }) {
      final api = FakeGameCenterApi()..weekStart = weekStart ?? _windCup.startAtUtc;
      final store = InMemoryGameCenterStore(const GcRecord(legacyExported: true));
      final gc = GameCenterController(
        api: api,
        store: store,
        progress: ValueNotifier(const PlayerProgress()),
        scores: InMemoryScoreRepository(),
        clock: () => now ?? _week2,
      );
      final statuses = <(String, DailyGcStatus)>[];
      gc.onEventStatus = (id, s) => statuses.add((id, s));
      return (gc, api, store, statuses);
    }

    test('kupa skoru yalnızca kupa tablosuna, kendi haftasının dönemine gider', () async {
      final (gc, api, _, statuses) = make();
      await gc.start();
      await pumpEventQueue();
      await _h(gc, cupRun('r1', 33));
      expect(api.submissions, [(GcBoard.weeklyCup, 33)]);
      expect(api.submittedOccurrences.single, _windCup.startAtUtc);
      expect(statuses.last, (_windCup.eventId, DailyGcStatus.submitted));
      expect(GcBoard.weeklyCup.id, 'istanbul_flight_weekly_cup');
      expect(GcBoard.weeklyCup.recurring, isTrue);
    });

    test('Simit Festivali kupası etkinlik skoruyla (engel + 2 × simit) gönderilir', () async {
      final festival = EventCalendar.cupFor(1)!;
      final now = festival.startAtUtc.add(const Duration(days: 2));
      final (gc, api, _, _) = make(now: now, weekStart: festival.startAtUtc);
      await gc.start();
      await pumpEventQueue();
      await _h(gc, cupRun('f', 30, simits: 20, slot: festival));
      expect(api.submissions, [(GcBoard.weeklyCup, 70)]);
    });

    test('yanlış döneme gönderilmez: Apple\'ın açık dönemi başka haftaysa düşer', () async {
      final (gc, api, store, statuses) = make(
        weekStart: _windCup.startAtUtc.add(const Duration(days: 7)),
      );
      await gc.start();
      await pumpEventQueue();
      await _h(gc, cupRun('r1', 40));
      expect(api.submissions, isEmpty);
      expect(statuses.last.$2, DailyGcStatus.expired);
      expect(store.record.eventPending, isEmpty);
    });

    test('özel etkinlik, antrenman, klasik tablo karışmaz; uygunsuz festival skoru reddedilir', () async {
      final (gc, api, _, statuses) = make(now: DateTime.utc(2026, 11, 28, 12));
      await gc.start();
      await pumpEventQueue();
      final sp = EventCalendar.activeSpecial(DateTime.utc(2026, 11, 28, 12))!;
      await _h(gc, cupRun('s', 30, slot: sp));
      await _h(gc, cupRun('p', 30, mode: RunMode.eventPractice));
      expect(api.submissions, isEmpty);
      final festival = EventCalendar.cupFor(1)!;
      final (gc2, api2, _, st2) = make(
        now: festival.startAtUtc.add(const Duration(days: 1)),
        weekStart: festival.startAtUtc,
      );
      await gc2.start();
      await pumpEventQueue();
      // geçilen engelden fazla simit: imkânsız uçuş
      await _h(gc2, cupRun('x', 10, simits: 11, slot: festival));
      expect(api2.submissions, isEmpty);
      expect(st2.last.$2, DailyGcStatus.notEligible);
      expect(statuses, isEmpty);
    });

    test('bağlantı yokken skor kalıcı kuyrukta bekler; gelince kendi dönemine gönderilir', () async {
      final (gc, api, store, _) = make();
      api.offline = true;
      await gc.start();
      await pumpEventQueue();
      await _h(gc, cupRun('r1', 21));
      await _h(gc, cupRun('r2', 18)); // daha düşük: kuyruktaki değişmez
      expect(store.record.eventPending[_windCup.eventId]!.score, 21);
      expect(gc.value.eventPending, 1);
      final back = GcRecord.fromJson(store.record.toJson());
      expect(back.eventPending[_windCup.eventId]!.score, 21);
      api.offline = false;
      await gc.flush();
      await pumpEventQueue();
      expect(api.submissions, [(GcBoard.weeklyCup, 21)]);
      expect(store.record.eventPending, isEmpty);
    });

    test('hafta bittikten bir gün sonra bekleyen kupa skoru düşer (yeni haftaya taşınmaz)', () async {
      var now = _week2;
      final api = FakeGameCenterApi()..weekStart = _windCup.startAtUtc;
      final store = InMemoryGameCenterStore(const GcRecord(legacyExported: true));
      final gc = GameCenterController(
        api: api,
        store: store,
        progress: ValueNotifier(const PlayerProgress()),
        scores: InMemoryScoreRepository(),
        clock: () => now,
      );
      api.offline = true;
      await gc.start();
      await pumpEventQueue();
      await _h(gc, cupRun('r1', 30));
      now = _windCup.endAtUtc.add(const Duration(days: 2));
      api.offline = false;
      api.weekStart = _windCup.endAtUtc;
      await gc.flush();
      await pumpEventQueue();
      expect(api.submissions, isEmpty);
      expect(store.record.eventPending, isEmpty);
    });

    test('Apple\'ın kupa dönemi haftalık saat denetimine gider (GameServices bağlantısı)', () async {
      final api = FakeGameCenterApi()..weekStart = _windCup.startAtUtc;
      final t = TestServices(
        clock: () => _week2,
        gameCenter: (p) => GameCenterController(
          api: api,
          store: InMemoryGameCenterStore(const GcRecord(legacyExported: true)),
          progress: p,
          scores: InMemoryScoreRepository(),
          clock: () => _week2,
        ),
      );
      await t.services.gameCenter.start();
      await t.services.gameCenter.refreshCupOccurrence();
      expect(t.services.events.trustedWeek, _windCup.weekIndex);
      expect(t.services.events.clockStatus(t.services.progress.value), EventClockStatus.ok);
      // Apple başka bir haftayı bildiriyor: dereceli oyun kapanır
      api.weekStart = EventCalendar.cupFor(_windCup.weekIndex + 1)!.startAtUtc;
      await t.services.gameCenter.refreshCupOccurrence();
      expect(t.services.events.clockStatus(t.services.progress.value), EventClockStatus.mismatch);
      expect(t.services.events.canRank(t.services.progress.value, _windCup), isFalse);
      // yanlış kurulmuş tablo (pazartesi değil): bilgi yok sayılır
      api.weekStart = _windCup.startAtUtc.add(const Duration(hours: 21));
      await t.services.gameCenter.refreshCupOccurrence();
      expect(t.services.events.trustedWeek, isNull);
    });

    test('2. sezon: sezon puanı yeni sezona yazılır, ilk sezonunki korunur', () async {
      final cup5 = EventCalendar.activeCup(_week4)!;
      final first = EventCalendar.seasonForWeek(0)!.seasonId;
      final (g, t, _) = await _game(
        now: _week4,
        progress: const PlayerProgress().copyWith(
          events: EventProgressState(
            seasons: {first: SeasonProgress(seasonId: first, points: 120)},
          ),
        ),
      );
      g.startEvent(t.services.events.definition(cup5));
      g.handleTap();
      for (var i = 0; i < 60 * 6 && g.phase.value == GamePhase.playing; i++) {
        g.update(1 / 60);
      }
      final p = t.services.progress.value;
      expect(p.events.season(first).points, 120);
      expect(p.events.season('season_2').points, greaterThan(0));
    });
  });
}
