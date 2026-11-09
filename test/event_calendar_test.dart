import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/challenge/daily_challenge.dart';
import 'package:istanbul_flight/events/event_calendar.dart';
import 'package:istanbul_flight/events/event_definition.dart';
import 'package:istanbul_flight/game/config.dart';
import 'package:istanbul_flight/game/day_cycle.dart';
import 'package:istanbul_flight/services/game_center/game_center.dart';

// Phase 2.7 (docs/20): etkinlik takvimi, veri modeli ve deterministik parkur.

void main() {
  group('Takvim', () {
    test('haftalık kupa pazartesi 00:00 UTC başlar, sonraki pazartesi 00:00 UTC biter', () {
      final wed = DateTime.utc(2026, 11, 11, 15);
      final cup = EventCalendar.activeCup(wed)!;
      expect(cup.startAtUtc, DateTime.utc(2026, 11, 9));
      expect(cup.endAtUtc, DateTime.utc(2026, 11, 16));
      expect(cup.kind, EventKind.weeklyCup);
      expect(cup.eventId, 'cup_2026_w46');
      expect(cup.leaderboardId, GameCenterIds.weeklyCup);
    });

    test('UTC hafta geçişi: pazar 23:59:59 ile pazartesi 00:00 farklı kupalar', () {
      final before = DateTime.utc(2026, 11, 15, 23, 59, 59);
      final after = DateTime.utc(2026, 11, 16);
      expect(EventCalendar.activeCup(before)!.eventId, 'cup_2026_w46');
      expect(EventCalendar.activeCup(after)!.eventId, 'cup_2026_w47');
      // yerel saat dilimi sonucu değiştirmez (İstanbul pazartesi 02:59 = UTC pazar 23:59)
      final local = DateTime.utc(2026, 11, 15, 23, 59).toLocal();
      expect(EventCalendar.activeCup(local)!.eventId, 'cup_2026_w46');
    });

    test('takvimden önce etkinlik yok; başlangıç ve bitiş sınırları', () {
      expect(EventCalendar.activeCup(DateTime.utc(2026, 11, 8, 23)), isNull);
      expect(EventCalendar.seasonAt(DateTime.utc(2026, 11, 1)), isNull);
      final cup = EventCalendar.cupFor(0)!;
      expect(cup.isActiveAt(cup.startAtUtc), isTrue);
      expect(cup.isActiveAt(cup.endAtUtc), isFalse);
      expect(cup.isUpcomingAt(DateTime.utc(2026, 11, 8)), isTrue);
      expect(cup.isOverAt(DateTime.utc(2026, 11, 16)), isTrue);
    });

    test('hafta sonu etkinliği cuma 00:00 – pazartesi 00:00 UTC ve kupadan farklı tür', () {
      for (var w = 0; w < 12; w++) {
        final cup = EventCalendar.cupFor(w)!, sp = EventCalendar.specialFor(w)!;
        expect(sp.startAtUtc.weekday, DateTime.friday);
        expect(sp.endAtUtc, cup.endAtUtc);
        expect(sp.type, isNot(cup.type));
        expect(sp.leaderboardId, isNull); // özel etkinliğin tablosu yok
      }
      expect(EventCalendar.activeSpecial(DateTime.utc(2026, 11, 12)), isNull);
      expect(
        EventCalendar.activeSpecial(DateTime.utc(2026, 11, 14))!.eventId,
        'special_2026_w46',
      );
    });

    test('dört hafta içinde dört etkinlik türünün hepsi kupa olur', () {
      expect(
        {for (var w = 0; w < 4; w++) EventCalendar.cupFor(w)!.type},
        EventType.values.toSet(),
      );
    });

    test('kimlikten slot: gidiş-dönüş, yıl sınırı ve geçersiz kimlikler', () {
      for (var w = 0; w < 80; w++) {
        for (final s in [EventCalendar.cupFor(w)!, EventCalendar.specialFor(w)!]) {
          expect(EventCalendar.slotById(s.eventId), s);
          expect(EventCalendar.slotById(s.eventId)!.startAtUtc, s.startAtUtc);
        }
      }
      // 2026'da 53 ISO haftası var; 2027-W01 4 Ocak'ta başlar
      expect(EventCalendar.cupFor(7)!.eventId, 'cup_2026_w53');
      expect(EventCalendar.cupFor(8)!.eventId, 'cup_2027_w01');
      expect(EventCalendar.cupFor(8)!.startAtUtc, DateTime.utc(2027, 1, 4));
      for (final bad in [
        'cup_2026_w54',
        'cup_2025_w53', // 2025'te 52 hafta
        'cup_2026_w45', // takvimden önce
        'daily_2026_11_09',
        'cup_2026_46',
        '',
      ]) {
        expect(EventCalendar.slotById(bad), isNull, reason: bad);
      }
    });

    test('sezon 4 hafta; kimlikten sezon; seviye eşikleri artan', () {
      final s1 = EventCalendar.seasonForWeek(0)!;
      expect(s1.seasonId, 'season_1');
      expect(s1.endAtUtc.difference(s1.startAtUtc), const Duration(days: 28));
      expect(EventCalendar.seasonForWeek(3)!.seasonId, 'season_1');
      expect(EventCalendar.seasonForWeek(4)!.seasonId, 'season_2');
      expect(EventCalendar.seasonById('season_2')!.startAtUtc, EventCalendar.weekStartOf(4));
      expect(EventCalendar.seasonById('season_0'), isNull);
      final pts = [for (final l in s1.levels) l.points];
      expect(pts, [...pts]..sort());
      expect(s1.levelFor(0), 0);
      expect(s1.levelFor(pts.last), s1.levels.length);
    });
  });

  group('Veri modeli', () {
    test('etkinlik türleri kendi kurallarını taşır (motorda dallanma yok)', () {
      expect(EventPresets.zonesFor(EventType.nightFlight).zoneList, [4]);
      expect(
        EventPresets.zonesFor(EventType.marathon).zoneList,
        routeZones,
      );
      for (final t in EventType.values) {
        expect(EventPresets.zonesFor(t).isValid, isTrue, reason: t.name);
      }
      expect(EventPresets.modifiersFor(EventType.windMaster).hazards!.flockChance, 0);
      expect(EventPresets.modifiersFor(EventType.nightFlight).hazards, isNull);
      expect(EventPresets.scoringFor(EventType.simitFestival).simitWeight, 2);
      expect(ScoringPolicy.festival.score(obstacles: 30, simits: 20), 70);
      expect(ScoringPolicy.obstacles.score(obstacles: 30, simits: 20), 30);
    });

    test('JSON gidiş-dönüş (uzaktan yapılandırmaya hazır); bozuk tanım reddedilir', () {
      final def = EventGenerators.build(EventCalendar.cupFor(2)!);
      final back = EventDefinition.fromJson(def.toJson())!;
      expect(back.eventId, def.eventId);
      expect(back.seed, def.seed);
      expect(back.zoneSelection.zoneList, def.zoneSelection.zoneList);
      expect(back.modifiers.toJson(), def.modifiers.toJson());
      expect(back.scoring.id, def.scoring.id);
      expect(back.leaderboardId, def.leaderboardId);
      // aynı tanım → aynı parkur
      final a = EventCourse(def), b = EventCourse(back);
      for (var i = 0; i < 60; i++) {
        expect(b.course.at(i).gapCenter, a.course.at(i).gapCenter);
        expect(b.hazardAt(i)?.accel, a.hazardAt(i)?.accel);
      }
      final j = def.toJson();
      expect(EventDefinition.fromJson({...j, 'scoring': 'x'}), isNull);
      expect(EventDefinition.fromJson({...j, 'zoneSelection': [[99, 0]]}), isNull);
      expect(EventDefinition.fromJson({...j, 'endAtUtc': j['startAtUtc']}), isNull);
      expect(EventDefinition.fromJson('bozuk'), isNull);
    });
  });

  group('Deterministik parkur', () {
    test('aynı etkinlik → aynı tohum, aynı engeller, aynı simitler, aynı dinamik engeller', () {
      for (final slot in [EventCalendar.cupFor(0)!, EventCalendar.specialFor(0)!]) {
        final a = EventGenerators.build(slot);
        // ayrı bir GameConfig örneği: önbellek atlanır, tanım baştan hesaplanır
        // ignore: prefer_const_constructors
        final b = EventGenerators.build(slot, config: GameConfig());
        expect(b.seed, a.seed);
        final ca = EventCourse(a), cb = EventCourse(b);
        for (var i = 0; i < 150; i++) {
          final x = ca.course.at(i), y = cb.course.at(i);
          expect(y.gapCenter, x.gapCenter);
          expect(y.gapHeight, x.gapHeight);
          expect(y.pickupY, x.pickupY);
          expect(cb.hazardAt(i)?.kind, ca.hazardAt(i)?.kind);
          expect(cb.hazardAt(i)?.accel, ca.hazardAt(i)?.accel);
          expect(cb.hazardAt(i)?.baseY, ca.hazardAt(i)?.baseY);
        }
      }
    });

    test('farklı haftalar farklı parkur', () {
      final a = EventCourse(EventGenerators.build(EventCalendar.cupFor(0)!));
      final b = EventCourse(EventGenerators.build(EventCalendar.cupFor(4)!));
      expect(a.definition.type, b.definition.type);
      expect(
        [for (var i = 0; i < 10; i++) a.course.at(i).gapCenter],
        isNot([for (var i = 0; i < 10; i++) b.course.at(i).gapCenter]),
      );
    });

    test('üretici sürümü: takvim v1; bilinmeyen sürüm oynanmaz', () {
      expect(EventGenerators.versionFor(DateTime.utc(2026, 11, 9)), 1);
      final def = EventGenerators.build(EventCalendar.cupFor(0)!);
      final future = EventDefinition.fromJson({
        ...def.toJson(),
        'generatorVersion': 99,
      })!;
      expect(
        () => EventGenerators.course(future),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('etkinlik parkuru günlük parkurun dondurulmuş üreticisini kullanır; Günün Uçuşu değişmedi', () {
      final def = EventGenerators.build(EventCalendar.cupFor(0)!);
      expect(def.course.generatorVersion, 2);
      // Günün Uçuşu'nun sürüm takvimi Phase 2.7'de değişmedi
      expect(DailyGenerators.schedule, [('2026-01-01', 1), ('2026-11-10', 2)]);
    });

    test('Simit Festivali neredeyse her geçitte simit; Gece Uçuşu ve Festival dinamik engelsiz', () {
      final festival = EventCourse(
        EventGenerators.build(EventCalendar.cupFor(1)!),
      );
      expect(festival.definition.type, EventType.simitFestival);
      final withSimit = [
        for (var i = 1; i < 101; i++) festival.course.at(i).pickupY,
      ].nonNulls.length;
      expect(withSimit, greaterThan(85));
      for (var i = 0; i < 100; i++) {
        expect(festival.hazardAt(i), isNull);
      }
      final night = EventCourse(EventGenerators.build(EventCalendar.cupFor(3)!));
      expect(night.definition.type, EventType.nightFlight);
      expect([for (var i = 0; i < 100; i++) night.hazardAt(i)].nonNulls, isEmpty);
    });

    test('Rüzgâr Ustası: yalnızca hava akımı, erken ve sık; ardışık koridorda iki akım yok', () {
      final wind = EventCourse(EventGenerators.build(EventCalendar.cupFor(2)!));
      expect(wind.definition.type, EventType.windMaster);
      final hz = [for (var i = 0; i < 150; i++) wind.hazardAt(i)];
      expect(hz.nonNulls.every((h) => h.accel.abs() == 400), isTrue);
      expect(hz.nonNulls.length, greaterThan(25));
      for (var i = 1; i < hz.length; i++) {
        expect(hz[i] != null && hz[i - 1] != null, isFalse, reason: 'koridor $i');
      }
      expect(hz.take(3).nonNulls, isEmpty);
    });
  });

  group('Adalet (erişilebilirlik simülasyonu)', () {
    // Her etkinlik dinamik engelleriyle birlikte doğrulanır; iki karar aralığının engel başına büyüğü
    // gerçek bandın geçerli alt sınırıdır (docs/19 §6a).
    test('8 haftanın 16 etkinliği 150 engel boyunca geçilebilir, en dar bant ≥ 90', () {
      for (var w = 0; w < 8; w++) {
        for (final slot in [EventCalendar.cupFor(w)!, EventCalendar.specialFor(w)!]) {
          final def = EventGenerators.build(slot);
          expect(def.validatedDepth, CourseValidator.requiredDepth, reason: slot.eventId);
          final c = EventCourse(def);
          final a = <double>[], b = <double>[];
          final r1 = CourseValidator.explore(c.course, maxScore: 150, bands: a, hazardAt: c.hazardAt);
          final r2 = CourseValidator.explore(
            c.course,
            maxScore: 150,
            bands: b,
            hazardAt: c.hazardAt,
            decisionSteps: 4,
          );
          expect(r1.depth, 150, reason: slot.eventId);
          expect(r2.depth, 150, reason: slot.eventId);
          var worst = double.infinity;
          for (var i = 0; i < min(a.length, b.length); i++) {
            worst = min(worst, max(a[i], b[i]));
          }
          expect(worst, greaterThanOrEqualTo(90), reason: slot.eventId);
        }
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

