import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/challenge/daily_challenge.dart';
import 'package:istanbul_flight/challenge/daily_state.dart';
import 'package:istanbul_flight/events/event_calendar.dart';
import 'package:istanbul_flight/events/event_definition.dart';
import 'package:istanbul_flight/events/event_state.dart';
import 'package:istanbul_flight/events/weekly_missions.dart';
import 'package:istanbul_flight/game/game_services.dart';
import 'package:istanbul_flight/progression/cosmetics.dart';
import 'package:istanbul_flight/progression/game_events.dart';
import 'package:istanbul_flight/progression/missions.dart';
import 'package:istanbul_flight/progression/run_settlement.dart';
import 'package:istanbul_flight/services/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Phase 2.7 (docs/20 §7–§9, §13): etkinlik hesabı, sezon, haftalık görevler, saat ve kayıt.

final _wed = DateTime.utc(2026, 11, 11, 12); // 1. hafta (kupa: Boğaz Maratonu)
final _cup = EventCalendar.activeCup(_wed)!;
final _festivalCup = EventCalendar.cupFor(1)!; // Simit Festivali
final _sat = DateTime.utc(2026, 11, 14, 12);
final _special = EventCalendar.activeSpecial(_sat)!;

RunResult _run(
  String id, {
  required int score,
  int simits = 0,
  EventSlot? slot,
  RunMode? mode,
  Map<int, ZoneRunStats> zoneStats = const {},
}) => RunResult(
  runId: id,
  score: score,
  obstaclesPassed: score,
  simits: simits,
  nearMisses: 0,
  maxZone: 0,
  flightMs: score * 2000 + 1000,
  zoneStats: zoneStats,
  mode: mode ?? (slot == null ? RunMode.classic : RunMode.event),
  eventId: slot?.eventId,
);

/// ProgressController ile tam hesap (settleRun + günlük + etkinlik + haftalık), sabit saatle.
(PlayerProgress, ProgressController) _settle(
  List<RunResult> runs, {
  PlayerProgress start = const PlayerProgress(),
  DateTime? now,
}) {
  final c = ProgressController(
    InMemoryProgressRepository(start),
    start,
    clock: () => now ?? _wed,
  );
  for (final r in runs) {
    c.settle(r);
  }
  return (c.value, c);
}

void main() {
  group('Etkinlik hesabı', () {
    test('en iyi TEK uçuş sayılır (toplam değil); deneme sınırı yok', () {
      final runs = [
        for (var i = 0; i < 6; i++) _run('r$i', score: [12, 30, 8, 25, 5, 3][i], slot: _cup),
      ];
      final (p, _) = _settle(runs);
      final rec = p.events[_cup.eventId]!;
      expect(rec.flights, 6);
      expect(rec.bestScore, 30);
      expect(rec.bestRunId, 'r1');
    });

    test('ödüller bir kez: katılım ve skor eşikleri; aynı uçuş ikinci kez sayılmaz', () {
      final c = ProgressController(
        InMemoryProgressRepository(),
        const PlayerProgress(),
        clock: () => _wed,
      );
      var weeklyPoints = 0;
      c.settle(_run('a', score: 30, slot: _cup)); // katılım + 25
      weeklyPoints += c.lastWeekly.value!.seasonPoints;
      final after1 = c.value;
      final o = c.lastEvent.value!;
      expect(o.rewards, [
        EventRewardPolicy.participationKey,
        EventRewardPolicy.milestoneKey(25),
      ]);
      expect(o.seasonPoints, 20 + 15);
      expect(o.simits, 10);
      expect(c.settle(_run('a', score: 30, slot: _cup)), isNull); // aynı runId
      expect(c.value, same(after1));
      c.settle(_run('b', score: 26, slot: _cup)); // eşik zaten alındı
      weeklyPoints += c.lastWeekly.value!.seasonPoints;
      expect(c.lastEvent.value!.rewards, isEmpty);
      expect(c.lastEvent.value!.seasonPoints, 0);
      c.settle(_run('c', score: 55, slot: _cup)); // 50 eşiği
      weeklyPoints += c.lastWeekly.value!.seasonPoints;
      expect(c.lastEvent.value!.rewards, [EventRewardPolicy.milestoneKey(50)]);
      final s = EventCalendar.seasonAt(_wed)!.seasonId;
      // etkinlik ödülleri + aynı uçuşların tamamladığı haftalık görevler
      expect(c.value.events.season(s).points, 20 + 15 + 25 + weeklyPoints);
      expect(c.value.events.season(s).completedEvents, {_cup.eventId});
    });

    test('saf hesap da idempotent (kendi uçuş defteriyle)', () {
      final r = _run('x', score: 40, slot: _cup);
      final (p1, o1) = settleEventRun(const PlayerProgress(), r, _wed);
      expect(o1, isNotNull);
      final (p2, o2) = settleEventRun(p1, r, _wed);
      expect(o2, isNull);
      expect(p2, same(p1));
    });

    test('antrenman (dereceli olmayan) uçuş kayıt ve ödül değiştirmez', () {
      final (p, c) = _settle([
        _run('p', score: 60, slot: _cup, mode: RunMode.eventPractice),
      ]);
      expect(p.events[_cup.eventId], isNull);
      expect(c.lastEvent.value!.ranked, isFalse);
      expect(c.lastEvent.value!.seasonPoints, 0);
    });

    test('etkinlik bittikten sonra biten uçuş sayılmaz (30 dk tolerans)', () {
      final late = _cup.endAtUtc.add(const Duration(hours: 1));
      final (p, o) = settleEventRun(
        const PlayerProgress(),
        _run('l', score: 50, slot: _cup),
        late,
      );
      expect(o!.ranked, isFalse);
      expect(p.events[_cup.eventId], isNull);
    });

    test('özel etkinlik kendi kaydı ve ödülleriyle; kupa kaydını etkilemez', () {
      final (p, c) = _settle([_run('s', score: 45, slot: _special)], now: _sat);
      expect(p.events[_special.eventId]!.bestScore, 45);
      expect(p.events[_cup.eventId], isNull);
      expect(c.lastEvent.value!.kind, EventKind.special);
      expect(c.lastEvent.value!.rewards.length, 3); // katılım + 20 + 40
    });

    test('Simit Festivali: skor = engel + 2 × simit; cüzdana geçen simit etkinlik başına sınırlı', () {
      final now = DateTime.utc(2026, 11, 18, 12);
      final cap = _festivalCup.rewards.simitCap!;
      final runs = [
        for (var i = 0; i < 4; i++)
          _run('f$i', score: 40, simits: 35, slot: _festivalCup),
      ];
      final (p, c) = _settle(runs, now: now);
      expect(p.events[_festivalCup.eventId]!.bestScore, 40 + 2 * 35);
      // uçuşlarda toplanan 140 simitten yalnızca sınır kadarı cüzdana geçti
      expect(p.totalSimits, cap);
      expect(p.events[_festivalCup.eventId]!.creditedSimits, cap);
      expect(c.lastEvent.value!.simitsCapped, isTrue);
    });

    test('dereceli olmayan modlar etkinlik kaydı açmaz; klasik rekor ve günlük kayıt etkilenmez', () {
      final (p, _) = _settle([_run('k', score: 20)]);
      expect(p.events.records, isEmpty);
      expect(p.dailyChallenge.records, isEmpty);
    });
  });

  group('Keşif ve görevler', () {
    test('etkinlik bölge atlamayı ödüle çevirmez: Gece Uçuşu, Rumeli Hisarı keşfini skorsuz vermez', () {
      final night = EventCalendar.cupFor(3)!;
      final now = night.startAtUtc.add(const Duration(days: 1));
      final r = RunResult(
        runId: 'n',
        score: 2,
        obstaclesPassed: 2,
        simits: 0,
        nearMisses: 0,
        maxZone: 4, // uçuş Rumeli Hisarı'nda geçti
        flightMs: 6000,
        zoneStats: const {4: ZoneRunStats(obstacles: 2)},
        mode: RunMode.event,
        eventId: night.eventId,
      );
      final (p, c) = _settle([r], now: now);
      // klasik rotadaki karşılığı: 2 puan = Haliç
      expect(p.discoveredZones, {0});
      expect(p.discovery.firstSeen.keys, isNot(contains(4)));
      expect(c.lastRun.value!.newZones, isEmpty);
      final reach = p.daily!.missions.where((m) => m.kind == MissionKind.reachZone);
      expect(reach.every((m) => m.progress == 0), isTrue);
      // etkinlik kaydı yine tutulur
      expect(p.events[night.eventId]!.bestScore, 2);
    });

    test('etkinlikte klasik eşiğe ulaşan bölge normal kuralla keşfedilir', () {
      final (p, _) = _settle([_run('m', score: 36, slot: _cup)]);
      expect(p.discoveredZones, {0, 1, 2});
    });
  });

  group('Sezon', () {
    test('sezon puanı XP\'den ayrı; seviye ödülleri bir kez, kalıcı ve mevcut sahiplik sistemine', () {
      final season = EventCalendar.seasonAt(_wed)!;
      var p = const PlayerProgress(xp: 500);
      final (p1, levels) = addSeasonPoints(p, season.seasonId, 600, _wed);
      expect(p1.xp, 500); // XP değişmedi
      expect(levels.map((l) => l.level), [1, 2, 3, 4, 5, 6]);
      expect(p1.bonusSimits, 20 + 40 + 60);
      expect(p1.events.badges.keys, {SeasonRules.badgeId(season.seasonId)});
      expect(p1.events.frames, {'kupa'});
      expect(p1.unlockedCosmetics, contains('kupa'));
      expect(ownsCosmetic(p1, 'kupa'), isTrue);
      // tekrar puan: ödül ikinci kez verilmez
      final (p2, again) = addSeasonPoints(p1, season.seasonId, 100, _wed);
      expect(again, isEmpty);
      expect(p2.bonusSimits, p1.bonusSimits);
      p = p2;
    });

    test('sonraki sezonda aynı kalıcı ödül tekrar verilmez, yerine simit; kozmetik geri alınmaz', () {
      final s1 = EventCalendar.seasonForWeek(0)!, s2 = EventCalendar.seasonForWeek(4)!;
      final (a, _) = addSeasonPoints(const PlayerProgress(), s1.seasonId, 600, _wed);
      final later = s2.startAtUtc.add(const Duration(days: 1));
      final (b, levels) = addSeasonPoints(a, s2.seasonId, 600, later);
      expect(levels.length, 6);
      final frame = SeasonRules.levelsV1[3], skin = SeasonRules.levelsV1[5];
      expect(
        b.bonusSimits - a.bonusSimits,
        20 + 40 + 60 + frame.duplicateSimits + skin.duplicateSimits,
      );
      expect(b.unlockedCosmetics, contains('kupa'));
      expect(b.events.badges.length, 2); // her sezonun kendi rozeti
      expect(b.events.season(s1.seasonId).points, 600); // eski sezon kaydı duruyor
    });

    test('kozmetik ödülü kayıttan sonra da kalıcı ve seçilebilir', () {
      final s = EventCalendar.seasonAt(_wed)!;
      final (p, _) = addSeasonPoints(const PlayerProgress(), s.seasonId, 600, _wed);
      final back = PlayerProgress.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>,
      );
      expect(back.unlockedCosmetics, contains('kupa'));
      expect(equipCosmetic(back, 'kupa')!.selectedCosmetic, 'kupa');
      expect(purchaseCosmetic(const PlayerProgress(), 'kupa').$2, PurchaseResult.notForSale);
    });

    test('kartpostal çerçevesi yalnızca sahip olunduğunda seçilir', () {
      expect(selectPostcardFrame(const PlayerProgress(), 'kupa'), isNull);
      final s = EventCalendar.seasonAt(_wed)!;
      final (p, _) = addSeasonPoints(const PlayerProgress(), s.seasonId, 300, _wed);
      final sel = selectPostcardFrame(p, 'kupa')!;
      expect(sel.events.effectiveFrame, 'kupa');
      expect(selectPostcardFrame(sel, null)!.events.effectiveFrame, isNull);
    });
  });

  group('Haftalık görevler', () {
    test('hafta anahtarından deterministik; günlük görevlerden ayrı kayıt ve defter', () {
      final a = WeeklyMissions.generate('2026-W46', level: 5);
      final b = WeeklyMissions.generate('2026-W46', level: 5);
      expect(a.toJson(), b.toJson());
      expect(a.missions.length, WeeklyMissionCatalog.perWeek);
      final (p, _) = _settle([_run('r', score: 10)]);
      expect(p.daily, isNotNull);
      expect(p.events.weekly, isNotNull);
      expect(p.events.weekly!.weekKey, EventCalendar.weekKey(_wed));
      expect(p.daily!.dayKey, dayKeyFor(_wed));
    });

    test('görev ödülü bir kez; yeni haftada eski haftanın ödülü verilmez', () {
      // bu haftanın görevlerini hepsini tamamlayacak uçuşlar
      var p = ensureWeekly(const PlayerProgress(), _wed);
      final ids = p.events.weekly!.missions.map((m) => m.kind).toSet();
      final c = ProgressController(InMemoryProgressRepository(p), p, clock: () => _wed);
      for (var i = 0; i < 10; i++) {
        c.settle(
          _run(
            'w$i',
            score: 30 + i * 10,
            simits: 10,
            slot: _cup,
            zoneStats: {
              for (var z = 0; z < 5; z++) z: const ZoneRunStats(obstacles: 3),
            },
          ),
        );
      }
      p = c.value;
      final done = p.events.weekly!.missions.where((m) => m.completed).length;
      expect(done, ids.length);
      final ledgerWeek = p.events.ledger.where((k) => k.startsWith('week:')).length;
      expect(ledgerWeek, ids.length);
      // yeni hafta: yeni görevler, defterde eski anahtarlar korunur, ödül tekrar yok
      final next = _wed.add(const Duration(days: 7));
      final c2 = ProgressController(InMemoryProgressRepository(p), p, clock: () => next);
      c2.settle(_run('n1', score: 5));
      expect(c2.value.events.weekly!.weekKey, EventCalendar.weekKey(next));
      expect(c2.value.events.weekly!.missions.every((m) => !m.completed || m.target <= 5), isTrue);
    });

    test('günlük antrenman ve etkinlik antrenmanı haftalık görevi ilerletmez', () {
      final (p, _) = _settle([
        _run('d', score: 99, mode: RunMode.dailyPractice),
        _run('e', score: 99, slot: _cup, mode: RunMode.eventPractice),
      ]);
      final w = p.events.weekly;
      expect(w == null || w.missions.every((m) => m.progress == 0), isTrue);
    });
  });

  group('Cihaz saati', () {
    test('saati geri almak: dereceli etkinlik kapanır, ödül ve görev ilerlemesi yok', () {
      final (p, _) = _settle([_run('a', score: 30, slot: _cup)]);
      expect(p.events.highWaterWeek, 0);
      // bir hafta ileri: yeni kupa, sonra saat geri alınıyor
      final next = _wed.add(const Duration(days: 7));
      final nextCup = EventCalendar.activeCup(next)!;
      final (p2, _) = _settle([_run('b', score: 30, slot: nextCup)], start: p, now: next);
      expect(p2.events.highWaterWeek, 1);
      expect(checkEventClock(p2.events, _wed), EventClockStatus.rolledBack);
      expect(canRankEvent(p2, _cup, _wed), isFalse);
      final (p3, o3) = settleEventRun(p2, _run('c', score: 99, slot: _cup), _wed);
      expect(o3!.ranked, isFalse);
      expect(p3.events[_cup.eventId]!.bestScore, 30);
      final (p4, w4) = settleWeekly(p3, _run('c', score: 99), _wed);
      expect(w4.completed, isEmpty);
      expect(p4, same(p3));
    });

    test('saati ileri almak aynı ödülü iki kez vermez (anahtarlar etkinlik ve sezona bağlı)', () {
      final future = EventCalendar.cupFor(2)!;
      final at = future.startAtUtc.add(const Duration(hours: 1));
      final (p1, _) = _settle([_run('f1', score: 30, slot: future)], now: at);
      // gerçek zamana gelince aynı etkinlik: ödüller zaten alınmış
      final (p2, c) = _settle([_run('f2', score: 30, slot: future)], start: p1, now: at);
      expect(c.lastEvent.value!.rewards, isEmpty);
      expect(p2.events[future.eventId]!.flights, 2);
    });

    test('Game Center haftası cihazınkinden farklıysa dereceli oyun kapanır', () {
      expect(
        checkEventClock(EventProgressState.empty, _wed, trustedWeek: 0),
        EventClockStatus.ok,
      );
      expect(
        checkEventClock(EventProgressState.empty, _wed, trustedWeek: 1),
        EventClockStatus.mismatch,
      );
      expect(
        canRankEvent(const PlayerProgress(), _cup, _wed, trustedWeek: 1),
        isFalse,
      );
    });

    test('kapanmış ya da başlamamış etkinlik dereceli oynanamaz', () {
      expect(canRankEvent(const PlayerProgress(), _cup, _wed), isTrue);
      expect(canRankEvent(const PlayerProgress(), _special, _wed), isFalse);
      expect(
        canRankEvent(const PlayerProgress(), _cup, _cup.endAtUtc),
        isFalse,
      );
    });
  });

  group('Kayıt ve geçiş', () {
    test('v4 kaydı (etkinlik alanı yok) aynen okunur; etkinlikler boş başlar', () {
      final v4 = const PlayerProgress(
        totalSimits: 120,
        xp: 900,
        unlockedCosmetics: {'classic', 'denizci'},
        selectedCosmetic: 'denizci',
        achievements: {},
      ).toJson()..remove('events');
      v4['v'] = 4;
      final p = PlayerProgress.fromJson(v4);
      expect(p.totalSimits, 120);
      expect(p.xp, 900);
      expect(p.selectedCosmetic, 'denizci');
      expect(p.events.records, isEmpty);
      expect(p.toJson()['v'], 5);
    });

    test('eski sürüm etkinlik alanını düşürürse yedekten geri gelir (ödül tekrar verilmez)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsProgressRepository(prefs, clock: () => _wed);
      final (earned, _) = _settle([
        _run('a', score: 60, slot: _cup),
      ]);
      await repo.save(earned);
      // 1.6.0 gibi alanı tanımayan bir sürüm ana kaydı yazdı
      final j = jsonDecode(prefs.getString(SharedPrefsProgressRepository.key)!)
          as Map<String, Object?>;
      j.remove('events');
      await prefs.setString(SharedPrefsProgressRepository.key, jsonEncode(j));
      final back = await repo.load();
      expect(back.events[_cup.eventId]!.bestScore, 60);
      expect(back.events[_cup.eventId]!.claimed, earned.events[_cup.eventId]!.claimed);
      final (again, o) = settleEventRun(back, _run('b', score: 60, slot: _cup), _wed);
      expect(o!.rewards, isEmpty);
      expect(again.bonusSimits, back.bonusSimits);
    });

    test('bozuk etkinlik alanları diğerlerini etkilemez; tanınmayan kayıtlar atılır', () {
      final s = EventProgressState.fromJson({
        'records': {
          'x': {'eventId': 'cup_1999_w01', 'bestScore': 5},
          'ok': {'eventId': _cup.eventId, 'bestScore': -3, 'flights': 'a'},
        },
        'seasons': {'s': {'seasonId': 'season_1', 'points': 50}},
        'weekly': 'bozuk',
        'badges': {'season_1_badge': 'tarih değil'},
        'highWaterWeek': -2,
      });
      expect(s.records.keys, {_cup.eventId});
      expect(s.records[_cup.eventId]!.bestScore, 0);
      expect(s.season('season_1').points, 50);
      expect(s.weekly, isNull);
      expect(s.badges, isEmpty);
      expect(s.highWaterWeek, isNull);
      expect(EventProgressState.fromJson('bozuk').records, isEmpty);
    });

    test('etkinlik kaydı JSON gidiş-dönüş kayıpsız; kayıt sayısı sınırlı', () {
      var s = EventProgressState.empty;
      for (var w = 0; w < 30; w++) {
        s = s.withRecord(EventRecord(eventId: EventCalendar.cupFor(w)!.eventId, bestScore: w));
      }
      expect(s.records.length, EventRules.keepRecords);
      expect(s.records.containsKey(EventCalendar.cupFor(29)!.eventId), isTrue);
      expect(s.records.containsKey(EventCalendar.cupFor(0)!.eventId), isFalse);
      final back = EventProgressState.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(back.toJson(), s.toJson());
    });

    test('mevcut sistemler korunur: rekor kaydı ayrı anahtarda, günlük kayıt ve keşif aynen', () {
      final (p, _) = _settle([_run('a', score: 60, slot: _cup)]);
      final p2 = settleRun(p, _run('k', score: 3), _wed)!.progress;
      expect(p2.flights, 2);
      expect(p2.events[_cup.eventId]!.bestScore, 60);
      expect(p2.dailyChallenge, same(p.dailyChallenge));
      expect(p2.discovery.toJson(), isNotNull);
      expect(DailyGcStatus.values, isNotEmpty);
    });
  });
}
