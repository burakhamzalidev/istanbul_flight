import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/main.dart';
import 'package:istanbul_flight/progression/progression_config.dart';
import 'package:istanbul_flight/services/progress.dart';
import 'package:istanbul_flight/ui/overlays/postcard_overlay.dart';

import 'fakes.dart';

Future<(IstanbulFlightGame, TestServices)> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  PlayerProgress progress = const PlayerProgress(),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final t = TestServices(progress: progress);
  final game = IstanbulFlightGame(
    scores: InMemoryScoreRepository(),
    random: Random(3),
    pickupRandom: Random(1),
    loadArt: false,
    services: t.services,
  );
  await tester.pumpWidget(MartiApp(game: game));
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

PlayerProgress _rich({int simits = 120, int level = 3}) =>
    PlayerProgress(totalSimits: simits, xp: ProgressionConfig.xpToReach(level));

void main() {
  testWidgets('menü: bakiye rozeti mağazayı açar; 6 görünüm, durumlar', (
    tester,
  ) async {
    final (game, _) = await _pumpApp(tester, progress: _rich());
    expect(
      tester.widget<Text>(find.byKey(const Key('totalSimits'))).data,
      '120',
    );
    expect(find.text('· Mağaza'), findsOneWidget);
    await _tap(tester, 'shopButton');
    expect(game.modal.value, Overlays.shop);
    expect(
      tester.widget<Text>(find.byKey(const Key('shopBalance'))).data,
      '120',
    );
    for (final id in [
      'classic',
      'denizci',
      'pilot',
      'gece',
      'altin',
      'kasif',
    ]) {
      expect(find.byKey(Key('shopItem_$id')), findsOneWidget, reason: id);
    }
    expect(find.byKey(const Key('equipped_classic')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('shopStatus_gece'))).data,
      '150 simit · 30 eksik',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('shopStatus_altin'))).data,
      '5. seviyede açılır',
    );
    expect(find.byKey(const Key('locked_kasif')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'satın alma: onay → satın alındı damgası → kullan; bakiye düşer, tekrar alınamaz',
    (tester) async {
      final (game, t) = await _pumpApp(tester, progress: _rich());
      await _tap(tester, 'shopButton');
      await _tap(tester, 'buy_denizci');
      expect(
        find.byKey(const Key('purchaseConfirm')),
        findsOneWidget,
        reason: 'önce onay',
      );
      expect(find.text('Fiyat 50 simit · Kalan 70 simit'), findsOneWidget);
      expect(
        t.services.progress.value.simitBalance,
        120,
        reason: 'onaysız düşülmez',
      );
      await _tap(tester, 'confirmPurchase');
      await tester.pump(const Duration(milliseconds: 600));
      expect(t.services.progress.value.simitBalance, 70);
      expect(find.byKey(const Key('boughtStamp')), findsOneWidget);
      expect(find.textContaining('Denizci Simit artık senin'), findsOneWidget);
      expect(
        find.byKey(const Key('buy_denizci')),
        findsNothing,
        reason: 'tekrar satın alınamaz',
      );
      expect(find.byKey(const Key('equip_denizci')), findsOneWidget);
      await _tap(tester, 'equipAfterBuy');
      expect(t.services.progress.value.selectedCosmetic, 'denizci');
      expect(game.cosmetic.value, 'denizci', reason: 'menüde hemen uygulanır');
      expect(find.byKey(const Key('equipped_denizci')), findsOneWidget);
      expect(t.progressRepo.saveCount, greaterThanOrEqualTo(2));
    },
  );

  testWidgets('çift dokunma: onay düğmesine hızlı iki dokunuş tek ücret', (
    tester,
  ) async {
    final (_, t) = await _pumpApp(tester, progress: _rich(simits: 300));
    await _tap(tester, 'shopButton');
    await _tap(tester, 'buy_pilot');
    await tester.ensureVisible(find.byKey(const Key('confirmPurchase')));
    await tester.tap(find.byKey(const Key('confirmPurchase')));
    await tester.tap(
      find.byKey(const Key('confirmPurchase')),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 600));
    expect(t.services.progress.value.simitBalance, 200);
    expect(t.services.progress.value.unlockedCosmetics, contains('pilot'));
  });

  testWidgets('aşağıdaki üründe satın al: onay paneli görünür alana kayar', (
    tester,
  ) async {
    await _pumpApp(tester, progress: _rich(simits: 999, level: 8));
    await _tap(tester, 'shopButton');
    await _tap(tester, 'buy_kasif');
    await tester.pump(const Duration(milliseconds: 300));
    final r = tester.getRect(find.byKey(const Key('confirmPurchase')));
    expect(r.top, greaterThanOrEqualTo(0));
    expect(r.bottom, lessThanOrEqualTo(844), reason: 'onay ekranda görünmeli');
    expect(find.text('İstanbul Kaşifi alınsın mı?'), findsOneWidget);
  });

  testWidgets('yetersiz simit: satın al düğmesi kapalı, eksik miktar görünür', (
    tester,
  ) async {
    final (_, t) = await _pumpApp(tester, progress: _rich(simits: 20));
    await _tap(tester, 'shopButton');
    final btn = find.byKey(const Key('buy_denizci'));
    await tester.ensureVisible(btn);
    await tester.tap(btn, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byKey(const Key('purchaseConfirm')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('shopStatus_denizci'))).data,
      '50 simit · 30 eksik',
    );
    expect(t.services.progress.value.simitBalance, 20);
  });

  testWidgets(
    'profil → Martı görünümü: sahip olunanlar, seçim, klasik görünüme dönüş, mağaza',
    (tester) async {
      final (game, t) = await _pumpApp(
        tester,
        progress: _rich().copyWith(
          unlockedCosmetics: {'classic', 'pilot'},
          selectedCosmetic: 'pilot',
        ),
      );
      expect(game.cosmetic.value, 'pilot');
      await _tap(tester, 'profileButton');
      await _tap(tester, 'openWardrobe');
      expect(game.modal.value, Overlays.wardrobe);
      expect(
        tester.widget<Text>(find.byKey(const Key('wardrobeCurrent'))).data,
        'Pilot Simit',
      );
      expect(find.byKey(const Key('wear_classic')), findsOneWidget);
      expect(
        find.byKey(const Key('wear_denizci')),
        findsNothing,
        reason: 'yalnız sahip olunanlar',
      );
      await _tap(tester, 'resetClassic');
      expect(t.services.progress.value.selectedCosmetic, 'classic');
      expect(game.cosmetic.value, 'classic');
      await _tap(tester, 'wear_pilot');
      expect(game.cosmetic.value, 'pilot');
      await _tap(tester, 'openShop');
      expect(game.modal.value, Overlays.shop);
    },
  );

  testWidgets('kartpostal: görünüm değişse de kompozisyon ve boyut aynı', (
    tester,
  ) async {
    Future<Size> postcardSize(PlayerProgress p) async {
      final (game, _) = await _pumpApp(tester, progress: p);
      await tester.tap(find.byKey(const Key('startButton')));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tapAt(const Offset(195, 600));
      for (var i = 0; i < 260; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(game.phase.value, GamePhase.gameOver);
      expect(find.byKey(const Key('postcardSimit')), findsOneWidget);
      return tester.getSize(find.byType(Postcard));
    }

    final classic = await postcardSize(const PlayerProgress());
    final kasif = await postcardSize(
      const PlayerProgress(
        unlockedCosmetics: {'classic', 'kasif'},
        selectedCosmetic: 'kasif',
      ),
    );
    expect(kasif, classic);
    await tester.pump(const Duration(milliseconds: 100));
  });

  for (final size in const [Size(320, 568), Size(375, 667), Size(430, 932)]) {
    testWidgets(
      'iPhone ${size.width.toInt()}×${size.height.toInt()}: mağaza ve görünüm ekranı taşmaz',
      (tester) async {
        await _pumpApp(
          tester,
          size: size,
          progress: _rich(simits: 99999, level: 8).copyWith(
            unlockedCosmetics: {
              'classic',
              'denizci',
              'pilot',
              'gece',
              'altin',
              'kasif',
            },
            selectedCosmetic: 'kasif',
          ),
        );
        await _tap(tester, 'shopButton');
        expect(tester.takeException(), isNull);
        await _tap(tester, 'closeModal');
        await _tap(tester, 'profileButton');
        await _tap(tester, 'openWardrobe');
        expect(tester.takeException(), isNull);
        await _tap(tester, 'closeModal');
      },
    );
  }
}
