import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/events/event_calendar.dart';
import 'package:istanbul_flight/events/event_state.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/main.dart';
import 'package:istanbul_flight/services/game_center/game_center_controller.dart';
import 'package:istanbul_flight/services/progress.dart';

import 'fakes.dart';
import 'game_center_fakes.dart';

// Phase 2.7 (docs/20 §11): Etkinlik Merkezi, uçuş şeridi, oyun sonu paneli, küçük ekranlar.

final _wed = DateTime.utc(2026, 11, 11, 12);
final _cup = EventCalendar.activeCup(_wed)!;

Future<(IstanbulFlightGame, TestServices)> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  PlayerProgress progress = const PlayerProgress(),
  FakeGameCenterApi? api,
  DateTime? now,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final t = TestServices(
    progress: progress,
    clock: () => now ?? _wed,
    gameCenter: api == null
        ? null
        : (p) => GameCenterController(
            api: api,
            store: InMemoryGameCenterStore(const GcRecord(legacyExported: true)),
            progress: p,
            scores: InMemoryScoreRepository(),
            clock: () => now ?? _wed,
          ),
  );
  final game = IstanbulFlightGame(
    scores: InMemoryScoreRepository(),
    random: Random(3),
    pickupRandom: Random(1),
    loadArt: false,
    services: t.services,
  );
  await tester.pumpWidget(MartiApp(game: game));
  if (api != null) await tester.runAsync(() => t.services.gameCenter.start());
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  return (game, t);
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pump();
  await tester.tap(find.byKey(Key(key)));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

String _text(WidgetTester tester, String key) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(Text),
        matchRoot: true,
      ),
    )
    .data!;

void main() {
  for (final size in const [
    Size(320, 568), // iPhone SE 1
    Size(375, 667), // iPhone SE 2/3
    Size(390, 844),
    Size(430, 932),
  ]) {
    testWidgets('menüde tek "Etkinlikler" girişi ve üç sekme taşmadan (${size.width.toInt()}×${size.height.toInt()})', (tester) async {
      final (game, _) = await _pumpApp(tester, size: size);
      expect(find.byKey(const Key('dailyButton')), findsOneWidget);
      expect(find.byKey(const Key('eventsButton')), findsOneWidget);
      await _tap(tester, 'eventsButton');
      expect(game.modal.value, Overlays.events);
      expect(find.byKey(Key('activeEvent_${_cup.eventId}')), findsOneWidget);
      expect(_text(tester, 'eventTitle_${_cup.eventId}'), 'Boğaz Maratonu');
      expect(_text(tester, 'eventTime_${_cup.eventId}'), 'Bitiş: 4 gün 12 sa sonra');
      expect(_text(tester, 'eventBest_${_cup.eventId}'), '0');
      expect(find.byKey(Key('eventStart_${_cup.eventId}')), findsOneWidget);
      await _tap(tester, 'eventsTab_events');
      expect(find.byKey(const Key('specialNone')), findsOneWidget);
      expect(find.byKey(Key('upcoming_${EventCalendar.specialFor(0)!.eventId}')), findsOneWidget);
      await _tap(tester, 'eventsTab_season');
      expect(_text(tester, 'seasonLevel'), 'Sezon 1 · Seviye 0/6');
      for (var l = 1; l <= 6; l++) {
        expect(find.byKey(Key('seasonReward_$l')), findsOneWidget);
      }
      expect(find.byKey(const Key('weekly_cupFlights')).evaluate().length +
          find.byKey(const Key('weekly_singleRunScore')).evaluate().length,
          greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('takvim başlamadan: kupa yok notu, sahte sıralama yok', (tester) async {
    await _pumpApp(tester, now: DateTime.utc(2026, 11, 2, 12));
    await _tap(tester, 'eventsButton');
    expect(find.byKey(const Key('cupNone')), findsOneWidget);
    expect(find.byKey(const Key('eventsMenuLevel')), findsNothing);
  });

  testWidgets('Game Center bağlı değilse sıralama yerine yalnızca durum metni', (tester) async {
    await _pumpApp(tester);
    await _tap(tester, 'eventsButton');
    expect(find.byKey(const Key('cupBoardOffline')), findsOneWidget);
    expect(find.byKey(const Key('cupScopeGlobal')), findsNothing);
  });

  testWidgets('Game Center bağlıyken dünya / arkadaşlar seçimi kupa tablosunu yükler', (tester) async {
    final api = FakeGameCenterApi()..weekStart = _cup.startAtUtc;
    await _pumpApp(tester, api: api);
    await _tap(tester, 'eventsButton');
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('cupScopeGlobal')), findsOneWidget);
    expect(api.loadCalls, greaterThan(0));
    await _tap(tester, 'cupScopeFriends');
    expect(find.byKey(const Key('cupBoardOffline')), findsNothing);
  });

  testWidgets('Uçuşa başla → şerit, uçuş, oyun sonu etkinlik paneli ve "Tekrar uç"', (tester) async {
    final (game, t) = await _pumpApp(tester);
    await _tap(tester, 'eventsButton');
    await tester.runAsync(() async {}); // tanım eşzamanlı hesaplanır
    await _tap(tester, 'eventStart_${_cup.eventId}');
    expect(game.modal.value, isNull);
    expect(game.runMode.value.isEvent, isTrue);
    expect(find.byKey(const Key('eventReadyBanner')), findsOneWidget);
    expect(_text(tester, 'eventReadyText'), 'Boğaz Maratonu');
    game.handleTap();
    for (var i = 0; i < 400 && game.phase.value == GamePhase.playing; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.phase.value, GamePhase.gameOver);
    // kartpostal gecikmesi oyun saatiyle (kare kare) geçer
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byKey(const Key('eventResult')), findsOneWidget);
    expect(find.byKey(const Key('eventRetry')), findsOneWidget);
    expect(find.byKey(const Key('restartButton')), findsNothing);
    expect(find.byKey(Key('eventResultReward_participation')), findsOneWidget);
    expect(t.services.progress.value.events[_cup.eventId]!.flights, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kupa çerçevesi: sahip olunca sezon ekranında açılır, kartpostalda görünür', (tester) async {
    final season = EventCalendar.seasonAt(_wed)!;
    final (owned, _) = addSeasonPoints(const PlayerProgress(), season.seasonId, 300, _wed);
    final (game, t) = await _pumpApp(tester, progress: owned);
    await _tap(tester, 'eventsButton');
    await _tap(tester, 'eventsTab_season');
    expect(_text(tester, 'seasonLevel'), 'Sezon 1 · Seviye 4/6');
    await _tap(tester, 'kupaFrameSwitch');
    expect(t.services.progress.value.events.effectiveFrame, 'kupa');
    await _tap(tester, 'closeModal');
    game.startFromMenu();
    game.handleTap();
    for (var i = 0; i < 400 && game.phase.value == GamePhase.playing; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // kartpostal gecikmesi oyun saatiyle (kare kare) geçer
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byKey(const Key('postcardKupaFrame')), findsOneWidget);
  });
}
