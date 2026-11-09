import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/main.dart';
import 'package:istanbul_flight/services/game_center/game_center.dart';
import 'package:istanbul_flight/services/game_center/game_center_controller.dart';

import 'fakes.dart';
import 'game_center_fakes.dart';

Future<(IstanbulFlightGame, FakeGameCenterApi)> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  FakeGameCenterApi? api,
  int best = 37,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final fake = api ?? FakeGameCenterApi();
  final t = TestServices(
    gameCenter: (p) => GameCenterController(
      api: fake,
      store: InMemoryGameCenterStore(const GcRecord(legacyExported: true)),
      progress: p,
      scores: InMemoryScoreRepository(best),
    ),
  );
  final game = IstanbulFlightGame(
    scores: InMemoryScoreRepository(best),
    random: Random(3),
    pickupRandom: Random(1),
    loadArt: false,
    services: t.services,
  );
  await tester.pumpWidget(MartiApp(game: game));
  await tester.runAsync(() => t.services.gameCenter.start());
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  return (game, fake);
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

const _page = GcBoardPage(
  total: 1203,
  entries: [
    GcEntry(rank: 1, alias: 'Martı Kaptan', score: 214),
    GcEntry(rank: 2, alias: 'Boğaz Rüzgârı', score: 180),
    GcEntry(rank: 3, alias: 'Simit42', score: 150, isLocal: true),
  ],
  local: GcEntry(rank: 3, alias: 'Simit42', score: 150, isLocal: true),
);

void main() {
  testWidgets(
    'menüde Sıralama girişi; bağlıyken rekor, durum ve dünya listesi',
    (tester) async {
      final fake = FakeGameCenterApi()..page = _page;
      final (game, _) = await _pumpApp(tester, api: fake);
      expect(find.byKey(const Key('leaderboardButton')), findsOneWidget);
      await _tap(tester, 'leaderboardButton');
      expect(game.modal.value, Overlays.leaderboard);
      await tester.runAsync(() async {});
      await tester.pump(const Duration(milliseconds: 50));
      expect(_text(tester, 'ownBest'), '37');
      expect(_text(tester, 'gcStatusTitle'), 'Game Center: Simit42');
      expect(find.byKey(const Key('boardRow_1')), findsOneWidget);
      expect(find.byKey(const Key('boardRowLocal')), findsOneWidget);
      expect(find.text('Simit42 (sen)'), findsOneWidget);
      expect(find.text('1203 oyuncu'), findsOneWidget);
      expect(fake.loadCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'haftalık ve arkadaşlar seçimi yeniden yükler; arkadaş izni yoksa açıklama',
    (tester) async {
      final fake = FakeGameCenterApi()
        ..page = GcBoardPage(
          entries: _page.entries,
          occurrenceEnd: DateTime(2026, 10, 26, 3),
        );
      await _pumpApp(tester, api: fake);
      await _tap(tester, 'leaderboardButton');
      await _tap(tester, 'boardWeekly');
      await tester.runAsync(() async {});
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('weeklyEnds')), findsOneWidget);
      fake.failCode = 'friends_denied';
      await _tap(tester, 'scopeFriends');
      await tester.runAsync(() async {});
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        _text(
          tester,
          'boardError',
        ).contains('Arkadaş listesine izin verilmedi'),
        isTrue,
      );
      expect(fake.loadCalls, 3);
    },
  );

  testWidgets('internet yok: anlaşılır hata ve tekrar dene', (tester) async {
    final fake = FakeGameCenterApi()..page = _page;
    await _pumpApp(tester, api: fake);
    fake.offline = true;
    await _tap(tester, 'leaderboardButton');
    await tester.runAsync(() async {});
    await tester.pump(const Duration(milliseconds: 50));
    expect(_text(tester, 'boardError').contains('internet'), isTrue);
    fake.offline = false;
    await _tap(tester, 'boardRetry');
    await tester.runAsync(() async {});
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('boardRow_1')), findsOneWidget);
  });

  testWidgets(
    'giriş yapılmamış: boş durum ve bağlan düğmesi; iptalde Ayarlar yönergesi',
    (tester) async {
      final fake = FakeGameCenterApi(
        authResult: const GcAuthStatus(
          authenticated: false,
          error: 'cancelled',
        ),
      );
      await _pumpApp(tester, api: fake);
      await _tap(tester, 'leaderboardButton');
      expect(find.byKey(const Key('gcStatus_signedOut')), findsOneWidget);
      expect(
        _text(tester, 'gcStatusBody').contains('Ayarlar > Game Center'),
        isTrue,
      );
      expect(find.byKey(const Key('boardAllTime')), findsNothing);
      final before = fake.authCalls;
      fake.authResult = const GcAuthStatus(authenticated: true, alias: 'Yeni');
      await _tap(tester, 'gcConnect');
      await tester.runAsync(() async {});
      await tester.pump(const Duration(milliseconds: 50));
      expect(fake.authCalls, before + 1);
      expect(_text(tester, 'gcStatusTitle'), 'Game Center: Yeni');
      expect(find.byKey(const Key('boardAllTime')), findsOneWidget);
    },
  );

  testWidgets('Game Center olmayan cihaz: bilgilendirme, bağlan düğmesi yok', (
    tester,
  ) async {
    await _pumpApp(tester, api: FakeGameCenterApi(isSupported: false));
    await _tap(tester, 'leaderboardButton');
    expect(find.byKey(const Key('gcStatus_unsupported')), findsOneWidget);
    expect(find.byKey(const Key('gcConnect')), findsNothing);
    expect(_text(tester, 'ownBest'), '37');
  });

  testWidgets('Apple ekranları açılır; geri tuşu pencereyi kapatır', (
    tester,
  ) async {
    final fake = FakeGameCenterApi()..page = _page;
    final (game, _) = await _pumpApp(tester, api: fake);
    await _tap(tester, 'leaderboardButton');
    await tester.runAsync(() async {});
    await tester.pump(const Duration(milliseconds: 50));
    await _tap(tester, 'openGameCenter');
    await _tap(tester, 'openGcAchievements');
    await tester.runAsync(() async {});
    expect(fake.nativeOpens, 2);
    expect(game.handleBack(), isTrue);
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.modal.value, isNull);
  });

  for (final size in const [Size(320, 568), Size(375, 667), Size(430, 932)]) {
    testWidgets(
      'iPhone ${size.width.toInt()}×${size.height.toInt()}: menü ve sıralama taşmaz',
      (tester) async {
        final fake = FakeGameCenterApi()
          ..page = const GcBoardPage(
            total: 99999,
            entries: [
              GcEntry(
                rank: 1,
                alias: 'Çok Uzun Bir Game Center Adı Olan Oyuncu',
                score: 9999,
              ),
              GcEntry(rank: 100, alias: 'B', score: 1),
            ],
            local: GcEntry(rank: 54321, alias: 'Ben', score: 12, isLocal: true),
          );
        await _pumpApp(tester, size: size, api: fake, best: 9999);
        expect(tester.takeException(), isNull, reason: 'menü');
        await _tap(tester, 'leaderboardButton');
        await tester.runAsync(() async {});
        await tester.pump(const Duration(milliseconds: 50));
        await tester.ensureVisible(find.byKey(const Key('openGameCenter')));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'sıralama');
      },
    );
  }
}
