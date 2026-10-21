import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/game_art.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/game_services.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/progression/cosmetics.dart';
import 'package:istanbul_flight/progression/progression_config.dart';
import 'package:istanbul_flight/services/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// Seviye [level], harcanabilir simit [simits].
PlayerProgress _p({int simits = 0, int level = 1, Set<String>? owned}) =>
    PlayerProgress(
      totalSimits: simits,
      xp: ProgressionConfig.xpToReach(level),
      unlockedCosmetics: owned ?? const {'classic'},
    );

class _FailingRepo implements ProgressRepository {
  @override
  Future<PlayerProgress> load() async => const PlayerProgress();
  @override
  Future<void> save(PlayerProgress p) async => throw Exception('disk dolu');
}

Future<ui.Image> _img() async {
  final r = ui.PictureRecorder();
  ui.Canvas(r).drawRect(const ui.Rect.fromLTWH(0, 0, 1, 1), ui.Paint());
  return r.endRecording().toImage(1, 1);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Katalog', () {
    test('kimlikler benzersiz, klasik ücretsiz ve ilk sırada', () {
      final ids = cosmeticCatalog.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.first, classicCosmeticId);
      expect(cosmeticById(classicCosmeticId)!.isFree, isTrue);
      expect(
        cosmeticCatalog.every(
          (c) => c.name.isNotEmpty && c.description.isNotEmpty,
        ),
        isTrue,
      );
    });

    test('fiyatlar istenen tabloyla aynı ve yapılandırmadan okunuyor', () {
      expect(
        {for (final c in cosmeticCatalog) c.name: c.price},
        {
          'Klasik Simit': 0,
          'Denizci Simit': 50,
          'Pilot Simit': 100,
          'Gece Martısı': 150,
          'Altın Kanat': 250,
          'İstanbul Kaşifi': 350,
        },
      );
      for (final c in cosmeticCatalog) {
        expect(c.price, ShopConfig.prices[c.id], reason: c.id);
      }
    });

    test('her ücretli görünümün sprite sheet\'i var: klasikle aynı boyut (288×84, 12 kare)', () {
      final classic = File('assets/images/${GameArt.simitPath}')
          .readAsBytesSync();
      int w(List<int> b) =>
          (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19];
      int h(List<int> b) =>
          (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23];
      for (final c in cosmeticCatalog.where((c) => !c.isFree)) {
        final f = File('assets/images/${c.sheetAsset}');
        expect(f.existsSync(), isTrue, reason: c.sheetAsset);
        final b = f.readAsBytesSync();
        expect((w(b), h(b)), (w(classic), h(classic)), reason: c.id);
      }
      expect(GameArt.allPaths, containsAll(GameArt.skinPaths.values));
    });
  });

  group('Satın alma (saf)', () {
    test('yeterli bakiye: tam fiyat düşülür, sahiplik eklenir (bakiye = fiyat sınırı)', () {
      final (p, r) = purchaseCosmetic(_p(simits: 50), 'denizci');
      expect(r, PurchaseResult.purchased);
      expect(p.simitBalance, 0);
      expect(p.spentSimits, 50);
      expect(p.unlockedCosmetics, containsAll(['classic', 'denizci']));
      expect(p.totalSimits, 50, reason: 'toplanan simit istatistiği değişmez');
    });

    test('yetersiz bakiye: hiçbir şey değişmez', () {
      final before = _p(simits: 49);
      final (p, r) = purchaseCosmetic(before, 'denizci');
      expect(r, PurchaseResult.insufficientFunds);
      expect(identical(p, before), isTrue);
    });

    test(
      'ödül simitleri de harcanabilir; bakiye hiçbir yolla negatife düşmez',
      () {
        final p0 = const PlayerProgress(totalSimits: 20, bonusSimits: 40);
        final (p1, r1) = purchaseCosmetic(p0, 'denizci');
        expect(r1, PurchaseResult.purchased);
        expect(p1.simitBalance, 10);
        final (p2, r2) = purchaseCosmetic(p1, 'pilot');
        expect(r2, isNot(PurchaseResult.purchased));
        expect(p2.simitBalance, 10);
        final corrupt = PlayerProgress.fromJson({
          'totalSimits': 5,
          'spentSimits': 900,
        });
        expect(corrupt.simitBalance, 0);
        expect(
          purchaseCosmetic(corrupt, 'denizci').$2,
          PurchaseResult.insufficientFunds,
        );
      },
    );

    test(
      'aynı ürün iki kez satın alınamaz (ikinci denemede simit düşülmez)',
      () {
        final (p1, _) = purchaseCosmetic(_p(simits: 500), 'denizci');
        final (p2, r2) = purchaseCosmetic(p1, 'denizci');
        expect(r2, PurchaseResult.alreadyOwned);
        expect(p2.simitBalance, 450);
        expect(purchaseCosmetic(p1, 'classic').$2, PurchaseResult.alreadyOwned);
      },
    );

    test('seviye kilidi ve bilinmeyen ürün', () {
      expect(
        purchaseCosmetic(_p(simits: 999, level: 4), 'altin').$2,
        PurchaseResult.levelLocked,
      );
      expect(
        purchaseCosmetic(_p(simits: 999, level: 5), 'altin').$2,
        PurchaseResult.purchased,
      );
      expect(
        purchaseCosmetic(_p(simits: 999), 'uçan_halı').$2,
        PurchaseResult.unknownItem,
      );
    });

    test('durumlar: kullanılıyor, sende, kilitli, alınabilir, pahalı', () {
      final p = _p(
        simits: 120,
        level: 3,
        owned: {'classic', 'denizci'},
      ).copyWith(selectedCosmetic: 'denizci');
      CosmeticStatus s(String id) => cosmeticStatus(p, cosmeticById(id)!);
      expect(s('denizci'), CosmeticStatus.equipped);
      expect(s('classic'), CosmeticStatus.owned);
      expect(s('pilot'), CosmeticStatus.affordable);
      expect(s('gece'), CosmeticStatus.tooExpensive);
      expect(s('altin'), CosmeticStatus.levelLocked);
    });
  });

  group('Seçim ve geriye uyum', () {
    test('sahip olunmayan / bilinmeyen görünüm seçilemez; klasik her zaman seçilebilir', () {
      final p = _p(owned: {'classic', 'denizci'});
      expect(equipCosmetic(p, 'pilot'), isNull);
      expect(equipCosmetic(p, 'yok'), isNull);
      expect(equipCosmetic(p, 'denizci')!.selectedCosmetic, 'denizci');
      final bare = const PlayerProgress(unlockedCosmetics: {});
      expect(equipCosmetic(bare, classicCosmeticId), isNotNull);
    });

    test('bilinmeyen kayıtlı görünüm (gelecek sürüm) korunur ama oyunda klasik kullanılır', () {
      final p = PlayerProgress.fromJson({
        'v': 2,
        'totalSimits': 300,
        'unlockedCosmetics': ['classic', 'kaptan_sapkasi', 'denizci'],
        'selectedCosmetic': 'kaptan_sapkasi',
      });
      expect(
        p.unlockedCosmetics,
        contains('kaptan_sapkasi'),
        reason: 'veri silinmez',
      );
      expect(effectiveCosmetic(p).id, classicCosmeticId);
      expect(purchaseCosmetic(p, 'pilot').$2, PurchaseResult.purchased);
    });

    test(
      'bozuk kozmetik alanları: liste değil / sahip olunmayan seçim → klasik',
      () {
        final p = PlayerProgress.fromJson({
          'unlockedCosmetics': 'pilot',
          'selectedCosmetic': 'pilot',
          'spentSimits': -40,
        });
        expect(p.unlockedCosmetics, {'classic'});
        expect(p.selectedCosmetic, 'classic');
        expect(p.spentSimits, 0);
      },
    );

    test(
      '1.0.0 ve 1.1.0 kayıtları olduğu gibi okunur (yeni şema gerekmez)',
      () async {
        SharedPreferences.setMockInitialValues({
          'progress_v1': '{"v":1,"totalSimits":80,"unlockedCosmetics":["classic"],"selectedCosmetic":"classic"}',
          'best_score_v1': 20,
        });
        final prefs = await SharedPreferences.getInstance();
        final p = await SharedPrefsProgressRepository(prefs).load();
        expect(p.simitBalance, 80);
        expect(effectiveCosmetic(p).id, classicCosmeticId);
        expect(purchaseCosmetic(p, 'denizci').$2, PurchaseResult.purchased);
      },
    );
  });

  group('ProgressController: işlem güvenliği ve kalıcılık', () {
    test(
      'satın alma ve seçim kalıcı: uygulama yeniden açılınca korunur',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = SharedPrefsProgressRepository(prefs);
        final c = ProgressController(repo, _p(simits: 120));
        expect(await c.purchase('denizci'), PurchaseResult.purchased);
        expect(c.equip('denizci'), isTrue);
        await c.flush();
        final again = await SharedPrefsProgressRepository(
          await SharedPreferences.getInstance(),
        ).load();
        expect(again.unlockedCosmetics, contains('denizci'));
        expect(again.selectedCosmetic, 'denizci');
        expect(again.simitBalance, 70);
        // klasik görünüme dönüş de kalıcı
        expect(c.equip(classicCosmeticId), isTrue);
        await c.flush();
        expect((await repo.load()).selectedCosmetic, classicCosmeticId);
      },
    );

    test('çift dokunma: eşzamanlı iki istek tek kez ücretlendirilir', () async {
      final repo = InMemoryProgressRepository();
      final c = ProgressController(repo, _p(simits: 200));
      final results = await Future.wait([
        c.purchase('pilot'),
        c.purchase('pilot'),
      ]);
      expect(
        results,
        containsAll([PurchaseResult.purchased, PurchaseResult.busy]),
      );
      expect(c.value.simitBalance, 100);
      expect(await c.purchase('pilot'), PurchaseResult.alreadyOwned);
      expect(c.value.simitBalance, 100);
    });

    test(
      'kayıt yazılamazsa satın alma geri alınır: simit düşülmez, ürün verilmez',
      () async {
        final c = ProgressController(_FailingRepo(), _p(simits: 100));
        expect(await c.purchase('denizci'), PurchaseResult.saveFailed);
        expect(c.value.simitBalance, 100);
        expect(c.value.unlockedCosmetics, isNot(contains('denizci')));
      },
    );
  });

  group('Oyun entegrasyonu', () {
    test(
      'eksik sprite: görünüm yüklenemediyse klasik sheet kullanılır',
      () async {
        final classic = await _img(), pilot = await _img();
        final art = GameArt(simitSheet: classic, skins: {'pilot': pilot});
        expect(art.sheetFor('pilot'), pilot);
        expect(art.sheetFor('denizci'), classic, reason: 'denizci yüklenemedi');
        expect(art.sheetFor('yok'), classic);
      },
    );

    Future<(IstanbulFlightGame, TestServices)> game(PlayerProgress p) async {
      final t = TestServices(progress: p);
      final g = await initializeGame(
        () => IstanbulFlightGame(
          scores: InMemoryScoreRepository(),
          random: Random(7),
          pickupRandom: Random(3),
          loadArt: false,
          services: t.services,
        ),
      );
      g.onGameResize(Vector2(1080, 1920));
      await g.ready();
      return (g, t);
    }

    test('seçili görünüm uygulanır; uçuş sırasında değişmez, sonraki turda uygulanır', () async {
      final owned = _p(
        simits: 0,
        owned: {'classic', 'pilot', 'gece'},
      ).copyWith(selectedCosmetic: 'pilot');
      final (g, t) = await game(owned);
      expect(g.cosmetic.value, 'pilot');
      g.handleTap(); // uçuş başlar
      t.services.progress.equip('gece');
      expect(g.cosmetic.value, 'pilot', reason: 'uçuş içinde görünüm değişmez');
      g.physics.y = g.config.worldHeight;
      g.update(1 / 60);
      expect(g.phase.value, GamePhase.gameOver);
      g.restart();
      expect(g.cosmetic.value, 'gece');
      g.onRemove();
    });

    test('görünüm oyun fiziğini, çarpışmayı ve skoru değiştirmez', () async {
      Future<(int, int, double, double)> simulate(PlayerProgress p) async {
        final (g, _) = await game(p);
        g.autopilot = true;
        g.handleTap();
        for (
          var i = 0;
          i < 60 * 25 && g.phase.value == GamePhase.playing;
          i++
        ) {
          g.update(1 / 60);
        }
        final r = (
          g.score.value,
          g.runSimits.value,
          g.physics.y,
          g.config.birdHitRadius,
        );
        g.onRemove();
        return r;
      }

      final classic = await simulate(_p());
      final skins = <(int, int, double, double)>[];
      for (final id in ['denizci', 'pilot', 'gece', 'altin', 'kasif']) {
        skins.add(
          await simulate(
            _p(owned: {'classic', id}).copyWith(selectedCosmetic: id),
          ),
        );
      }
      for (final s in skins) {
        expect(s, classic);
      }
      expect(classic.$1, greaterThan(5), reason: 'simülasyon gerçekten uçtu');
    });
  });

  test('kayıt JSON gidiş-dönüşünde satın alımlar ve seçim korunur', () {
    final (p, _) = purchaseCosmetic(_p(simits: 400, level: 3), 'gece');
    final q = equipCosmetic(p, 'gece')!;
    final back = PlayerProgress.fromJson(
      jsonDecode(jsonEncode(q.toJson())) as Map<String, Object?>,
    );
    expect(back.unlockedCosmetics, q.unlockedCosmetics);
    expect(back.selectedCosmetic, 'gece');
    expect(back.simitBalance, 250);
  });
}
