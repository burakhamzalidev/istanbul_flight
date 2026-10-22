import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/main.dart';
import 'package:istanbul_flight/progression/discovery.dart';
import 'package:istanbul_flight/services/progress.dart';
import 'package:istanbul_flight/ui/overlays/discovery_overlays.dart';

import 'fakes.dart';

Future<(IstanbulFlightGame, TestServices)> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  PlayerProgress progress = const PlayerProgress(),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final t = TestServices(progress: progress);
  t.services.progress.refreshDay();
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

/// Haliç ve Galata keşfedilmiş (Galata bu sürümde, Haliç eski sürümde); Haliç'in rozeti var.
PlayerProgress _explorer() {
  final seen = DateTime(2026, 10, 23, 12);
  return PlayerProgress(
    discoveredZones: const {0, 1},
    discovery: DiscoveryState(
      firstSeen: {1: seen},
      legacyZones: const {0},
      zoneRecords: const {0: 14, 1: 6},
      progress: const {'galata_near': 2},
      completed: {
        'halic_reach': seen,
        'halic_simits': seen,
        'halic_obstacles': seen,
        'galata_reach': seen,
      },
      badges: {0: seen},
    ),
  );
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  testWidgets(
    'menü: tek giriş noktası, keşif penceresini açar; harita ve beş işaret',
    (tester) async {
      final (game, _) = await _pumpApp(tester, progress: _explorer());
      expect(find.byKey(const Key('discoveryButton')), findsOneWidget);
      expect(_text(tester, 'discoveryMenuCount'), '%31');
      await _tap(tester, 'discoveryButton');
      expect(game.modal.value, Overlays.discovery);
      expect(find.byKey(const Key('istanbulMap')), findsOneWidget);
      for (var z = 0; z < 5; z++) {
        expect(find.byKey(Key('mapMarker_$z')), findsOneWidget, reason: '$z');
      }
      expect(find.byKey(const Key('mapLegend')), findsOneWidget);
      expect(_text(tester, 'albumBadges'), '1/5');
      // Albüm yüzdesi: Haliç 3/3, Galata ulaş + kıl payı 2/3 → (1 + (1 + 2/3 + 0)/3) / 5
      expect(_text(tester, 'albumPercent'), 'Albüm %31');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'işarete dokununca bölge detayı: tarih, rekor, hedefler, bilgiler; geri dönüş',
    (tester) async {
      await _pumpApp(tester, progress: _explorer());
      await _tap(tester, 'discoveryButton');
      await _tap(tester, 'mapMarker_1');
      expect(find.byKey(const Key('zoneDetail_1')), findsOneWidget);
      expect(_text(tester, 'zoneDetailName'), '2. durak · Galata');
      expect(find.text('İlk keşif: 23 Ekim 2026'), findsOneWidget);
      expect(find.text('Bölge rekoru: tek uçuşta 6 engel'), findsOneWidget);
      expect(find.byKey(const Key('goalRow_galata_reach')), findsOneWidget);
      expect(_text(tester, 'goalValue_galata_reach'), 'Tamam');
      expect(_text(tester, 'goalValue_galata_near'), '2/3');
      expect(_text(tester, 'goalValue_galata_score'), '0/25');
      expect(find.byKey(const Key('zoneFacts')), findsOneWidget);
      expect(find.textContaining('1348'), findsOneWidget);
      await _tap(tester, 'discoveryBack');
      expect(find.byKey(const Key('istanbulMap')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'eski sürümde keşfedilen bölge: tarih uydurulmaz; rozet gösterilir',
    (tester) async {
      await _pumpApp(tester, progress: _explorer());
      await _tap(tester, 'discoveryButton');
      await _tap(tester, 'zoneRow_0');
      expect(
        find.text('Önceki bir sürümde keşfedildi (tarih kaydı yok).'),
        findsOneWidget,
      );
      expect(find.text('Rozet kazanıldı · %100'), findsOneWidget);
    },
  );

  testWidgets('kilitli bölge: ad ve bilgiler gizli, nasıl açılacağı yazılı', (
    tester,
  ) async {
    await _pumpApp(tester, progress: _explorer());
    await _tap(tester, 'discoveryButton');
    await _tap(tester, 'mapMarker_3');
    expect(_text(tester, 'zoneDetailName'), '4. durak · ???');
    expect(
      find.text('Henüz keşfedilmedi: tek uçuşta 60 puana ulaş.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('zoneFactsLocked')), findsOneWidget);
    expect(find.byKey(const Key('zoneFacts')), findsNothing);
    expect(find.textContaining('1973'), findsNothing);
  });

  testWidgets('kartpostal sekmesi: beş kart, kilitli/açık, albüm ödülü', (
    tester,
  ) async {
    await _pumpApp(tester, progress: _explorer());
    await _tap(tester, 'discoveryButton');
    await _tap(tester, 'discoveryTabAlbum');
    for (var z = 0; z < 5; z++) {
      expect(find.byKey(Key('postcardTile_$z')), findsOneWidget, reason: '$z');
    }
    expect(find.text('3. kartpostal'), findsOneWidget);
    expect(find.text('35 puanda açılır'), findsOneWidget);
    expect(find.byType(ZonePostcardImage), findsNWidgets(5));
    await tester.ensureVisible(find.byKey(const Key('albumReward')));
    expect(
      _text(tester, 'albumRewardText'),
      startsWith('Beş bölgenin rozetini topla'),
    );
    await _tap(tester, 'postcardTile_0');
    expect(find.byKey(const Key('zoneDetail_0')), findsOneWidget);
    await _tap(tester, 'discoveryBack');
    expect(find.byKey(const Key('postcardTile_0')), findsOneWidget);
  });

  testWidgets('geri tuşu keşif penceresini kapatır', (tester) async {
    final (game, _) = await _pumpApp(tester);
    await _tap(tester, 'discoveryButton');
    expect(game.handleBack(), isTrue);
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.modal.value, isNull);
  });

  testWidgets(
    'oyun sonu: ilk uçuşta yeni kartpostal ve keşif hedefi özetlenir',
    (tester) async {
      final (game, t) = await _pumpApp(tester);
      await tester.tap(find.byKey(const Key('startButton')));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tapAt(const Offset(195, 600));
      for (var i = 0; i < 260; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(game.phase.value, GamePhase.gameOver);
      expect(find.text('Albüme yeni kartpostal: Haliç'), findsOneWidget);
      expect(find.text("Keşif: Haliç'e ulaş (+5)"), findsOneWidget);
      expect(t.services.progress.value.discovery.firstSeen.keys, [0]);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in const [Size(320, 568), Size(375, 667), Size(430, 932)]) {
    testWidgets(
      'iPhone ${size.width.toInt()}×${size.height.toInt()}: menü, harita, albüm ve detay taşmaz',
      (tester) async {
        final full = DiscoveryState(
          firstSeen: {for (var z = 0; z < 5; z++) z: DateTime(2026, 10, 23)},
          zoneRecords: const {0: 15, 1: 20, 2: 25, 3: 30, 4: 999},
          completed: {
            for (final g in discoveryZones.expand((z) => z.goals))
              g.id: DateTime(2026, 10, 23),
          },
          badges: {for (var z = 0; z < 5; z++) z: DateTime(2026, 10, 23)},
          albumCompletedAt: DateTime(2026, 10, 23),
        );
        await _pumpApp(
          tester,
          size: size,
          progress: PlayerProgress(
            xp: 99999,
            totalSimits: 99999,
            discoveredZones: const {0, 1, 2, 3, 4},
            unlockedCosmetics: const {'classic', 'iznik'},
            discovery: full,
          ),
        );
        expect(tester.takeException(), isNull, reason: 'menü');
        await _tap(tester, 'discoveryButton');
        expect(tester.takeException(), isNull, reason: 'harita');
        for (var z = 0; z < 5; z++) {
          await _tap(tester, 'zoneRow_$z');
          await tester.ensureVisible(find.byKey(const Key('zoneFacts')));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'detay $z');
          await _tap(tester, 'discoveryBack');
        }
        await _tap(tester, 'discoveryTabAlbum');
        await tester.ensureVisible(find.byKey(const Key('albumReward')));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'albüm');
        expect(
          _text(tester, 'albumRewardText'),
          'Açıldı! Martı Görünümü’nden seçebilirsin.',
        );
      },
    );
  }
}
