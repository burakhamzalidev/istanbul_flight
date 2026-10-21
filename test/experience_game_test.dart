import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/components/obstacle_pair.dart';
import 'package:istanbul_flight/game/config.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/game/logic/collision.dart';
import 'package:istanbul_flight/game/logic/gap_generator.dart';
import 'package:istanbul_flight/game/logic/pickup_rules.dart';
import 'package:istanbul_flight/services/audio_service.dart';

import 'fakes.dart';

Future<(IstanbulFlightGame, TestServices)> _game({
  int best = 0,
  ScoreRepository? scores,
}) async {
  final t = TestServices();
  final g = await initializeGame(
    () => IstanbulFlightGame(
      scores: scores ?? InMemoryScoreRepository(best),
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

void _run(IstanbulFlightGame g, double seconds, {double dt = 1 / 60}) {
  for (var i = 0, n = (seconds / dt).round(); i < n; i++) {
    g.update(dt);
  }
}

/// Sadece ilk engeli bırakır ve onu kuşun hemen önüne koyar (kontrollü senaryo).
ObstaclePair _isolateFirstObstacle(
  IstanbulFlightGame g, {
  double aheadBy = 10,
}) {
  while (g.obstacles.isEmpty) {
    g.update(1 / 60);
  }
  final o = g.obstacles.first;
  for (final x in g.obstacles.skip(1).toList()) {
    x.removeFromParent();
    g.obstacles.remove(x);
  }
  o.position.x = g.birdX + g.config.birdHitRadius + aheadBy;
  return o;
}

/// Kuşu sabit yükseklikte tutarak engelin yanından geçirir.
void _passAtHeight(IstanbulFlightGame g, ObstaclePair o, double y) {
  for (
    var i = 0;
    i < 400 && g.birdX - g.config.birdHitRadius <= o.right + 5;
    i++
  ) {
    g.physics
      ..y = y
      ..velocity = 0;
    g.update(1 / 120);
  }
}

void main() {
  group('Ana menü ve durumlar', () {
    test('ana menüyle açılır; UÇMAYA BAŞLA → hazır; dokunuş → oyun; müzik geçişleri', () async {
      final (g, t) = await _game();
      expect(g.phase.value, GamePhase.ready);
      expect(g.menuOpen.value, isTrue);
      expect(t.audio.music.last, MusicTrack.menu);
      expect(t.audio.ambience.last, Ambience.harbor);

      g.startFromMenu();
      expect(g.menuOpen.value, isFalse);
      expect(g.phase.value, GamePhase.ready);
      g.handleTap();
      expect(g.phase.value, GamePhase.playing);
      expect(t.audio.music.last, MusicTrack.game);
      expect(t.audio.sfx, contains(Sfx.flap));
      g.onRemove();
    });

    test('oyun sonundan ana menüye dönüş turu temizler', () async {
      final (g, t) = await _game();
      g.startFromMenu();
      g.handleTap();
      _run(g, 3);
      expect(g.phase.value, GamePhase.gameOver);
      expect(t.audio.music, contains(null), reason: 'çarpışmada müzik durur');
      expect(
        t.audio.music.last,
        MusicTrack.gameOver,
        reason: 'kartpostalla oyun sonu müziği',
      );
      g.openMenu();
      g.update(0);
      expect(g.phase.value, GamePhase.ready);
      expect(g.menuOpen.value, isTrue);
      expect(g.obstacles, isEmpty);
      expect(g.score.value, 0);
      expect(g.runSimits.value, 0);
      g.onRemove();
    });
  });

  group('Duraklatma', () {
    test(
      'duraklatmada simülasyon durur, dönüşte sıçrama ve hızlanma olmaz',
      () async {
        final (g, t) = await _game();
        g.handleTap();
        _run(g, 0.3);
        final y = g.physics.y,
            v = g.physics.velocity,
            x = g.obstacles.map((o) => o.position.x).toList();
        g.pauseGame();
        expect(t.audio.pauses, 1);
        g.update(5); // uzun bir arka plan süresi
        expect(g.physics.y, y);
        expect(g.obstacles.map((o) => o.position.x).toList(), x);
        g.resumeGame();
        expect(t.audio.resumes, 1);
        g.update(1 / 60);
        // Tek kare: en fazla 1/60 sn'lik hareket (birikmiş süre sıfırlandı)
        expect(
          (g.physics.y - y).abs(),
          lessThan((v.abs() + g.config.gravity / 60) / 60 + 1),
        );
        g.onRemove();
      },
    );

    test(
      'duraklatmadan yeniden başlatma: motor çalışır, tur sıfırlanır',
      () async {
        final (g, _) = await _game();
        g.handleTap();
        _run(g, 0.5);
        g.pauseGame();
        expect(g.paused, isTrue);
        g.restart();
        g.update(0);
        expect(g.paused, isFalse);
        expect(g.phase.value, GamePhase.ready);
        expect(
          g.menuOpen.value,
          isFalse,
          reason: 'yeniden başlat doğrudan "uçmak için dokun"a gider',
        );
        expect(g.obstacles, isEmpty);
        g.onRemove();
      },
    );
  });

  group('Toplanabilir simit', () {
    test('temasla toplanır: sayaç, ses, hafif titreşim; aynı simit iki kez toplanmaz', () async {
      final (g, t) = await _game();
      g.handleTap();
      g.debugInvincible = true; // simidi geçit dışında da test edebilmek için
      final o = _isolateFirstObstacle(g);
      o.position.x = g.birdX - o.size.x / 2; // simit tam kuşun üstünde
      o.pickupY = g.physics.y;
      o.pickupTaken = false;
      g.physics.velocity = 0;
      g.update(1 / 120);
      expect(g.runSimits.value, 1);
      expect(o.pickupTaken, isTrue);
      expect(t.audio.sfx.where((s) => s == Sfx.collect), hasLength(1));
      expect(t.haptics.calls, contains('light'));

      for (var i = 0; i < 30; i++) {
        g.physics
          ..y = o.pickupY!
          ..velocity = 0;
        g.update(1 / 120);
      }
      expect(g.runSimits.value, 1, reason: 'toplanan simit tekrar sayılmaz');
      expect(t.audio.sfx.where((s) => s == Sfx.collect), hasLength(1));
      g.onRemove();
    });

    test('simitler ulaşılamayan konumda üretilmez (5000 geçit)', () {
      const c = GameConfig();
      final gaps = GapGenerator(c, random: Random(1));
      final rnd = Random(2);
      var placed = 0;
      for (var i = 0; i < 5000; i++) {
        final gap = gaps.next(i % 150);
        final y = PickupRules.place(
          config: c,
          gapCenter: gap.center,
          gapHeight: gap.height,
          random: rnd,
        );
        if (y == null) continue;
        placed++;
        final top = gap.center - gap.height / 2,
            bottom = gap.center + gap.height / 2;
        // Kuş simidin merkezinde dururken engele değmez → çarpışmadan toplanabilir
        final birdAtPickup = Offset(500, y);
        expect(
          circleIntersectsRect(
            birdAtPickup,
            c.birdHitRadius,
            Rect.fromLTRB(400, -9999, 600, top),
          ),
          isFalse,
        );
        expect(
          circleIntersectsRect(
            birdAtPickup,
            c.birdHitRadius,
            Rect.fromLTRB(400, bottom, 600, 9999),
          ),
          isFalse,
        );
        expect(
          y - top,
          greaterThanOrEqualTo(c.birdHitRadius + c.pickupSafetyMargin),
        );
        expect(
          bottom - y,
          greaterThanOrEqualTo(c.birdHitRadius + c.pickupSafetyMargin),
        );
      }
      expect(placed / 5000, closeTo(c.pickupChance, 0.03));
    });

    test('oyunda üretilen simitler geçidin güvenli bandında, ilk engelde simit yok', () async {
      final (g, _) = await _game();
      g.debugInvincible = true;
      g.autopilot = true;
      g.handleTap();
      final seen = <int>{};
      var withPickup = 0;
      for (var i = 0; i < 60 * 60; i++) {
        g.update(1 / 60);
        for (final o in g.obstacles) {
          if (!seen.add(o.seed)) continue;
          if (o.seed == 0) expect(o.pickupY, isNull);
          final y = o.pickupY;
          if (y == null) continue;
          withPickup++;
          final band = PickupRules.reachableBand(
            config: g.config,
            gapCenter: o.gapCenter,
            gapHeight: o.gapHeight,
          )!;
          expect(y, inInclusiveRange(band.top, band.bottom));
        }
      }
      expect(withPickup, greaterThan(10));
      expect(
        g.runSimits.value,
        greaterThan(0),
        reason: 'otomatik pilot geçitten geçerken simit toplar',
      );
      g.onRemove();
    });
  });

  group('Kıl payı', () {
    test('çok yakın geçiş bir kez tetiklenir (ses + orta titreşim)', () async {
      final (g, t) = await _game();
      g.handleTap();
      final o = _isolateFirstObstacle(g);
      final r = g.config.birdHitRadius;
      _passAtHeight(g, o, o.gapBottom - r - 8); // alt engele 8 birim
      expect(g.phase.value, GamePhase.playing);
      expect(g.nearMisses.value, 1);
      expect(t.audio.sfx.where((s) => s == Sfx.nearMiss), hasLength(1));
      expect(t.haptics.calls, contains('medium'));
      _run(g, 0.3, dt: 1 / 120);
      expect(
        g.nearMisses.value,
        1,
        reason: 'aynı engel için tekrar tetiklenmez',
      );
      g.onRemove();
    });

    test('rahat geçişte tetiklenmez', () async {
      final (g, _) = await _game();
      g.handleTap();
      final o = _isolateFirstObstacle(g);
      _passAtHeight(g, o, o.gapCenter);
      expect(g.phase.value, GamePhase.playing);
      expect(g.score.value, 1);
      expect(g.nearMisses.value, 0);
      g.onRemove();
    });

    test('çarpışma kıl payı sayılmaz', () async {
      final (g, _) = await _game();
      g.handleTap();
      g.debugInvincible = true; // çarpışsa bile geçip değerlendirilsin
      final o = _isolateFirstObstacle(g);
      _passAtHeight(g, o, o.gapBottom); // gövdesi alt engele giriyor
      expect(o.nearMissChecked, isTrue);
      expect(o.minClearance, lessThan(0));
      expect(g.nearMisses.value, 0);
      g.onRemove();
    });
  });

  group('Kayıt ve geri bildirim', () {
    test('rekor + toplanan simitler kaydedilir; çarpışmada ses, ağır titreşim, müzik durur', () async {
      final repo = InMemoryScoreRepository(2);
      final (g, t) = await _game(scores: repo);
      g.debugInvincible = true;
      g.autopilot = true;
      g.handleTap();
      while (g.score.value < 4) {
        g.update(1 / 60);
      }
      expect(g.recordPassed.value, isTrue);
      g.runSimits.value = 3;
      g.debugInvincible = false;
      g.autopilot = false;
      g.physics.y = g.config.worldHeight;
      g.update(1 / 60);
      expect(g.phase.value, GamePhase.gameOver);
      await Future<void>.delayed(Duration.zero);
      expect(await repo.loadBest(), 4);
      expect((await t.progressRepo.load()).totalSimits, 3);
      expect(t.services.progress.value.totalSimits, 3);
      expect(t.audio.sfx, contains(Sfx.crash));
      expect(t.haptics.calls, contains('heavy'));
      _run(g, 1.5);
      expect(t.audio.sfx, contains(Sfx.splash));
      expect(t.audio.sfx, contains(Sfx.record));
      g.onRemove();
    });

    test('animasyonları azalt: sarsıntı yok; ayar değişince ses düzeyi ve titreşim uygulanır', () async {
      final (g, t) = await _game();
      t.services.settings.update(
        (s) => s.copyWith(reduceMotion: true, sfxVolume: 0.4, haptics: false),
      );
      expect(t.audio.sfxVolume, 0.4);
      expect(t.haptics.enabled, isFalse);
      g.handleTap();
      g.physics.y = g.config.worldHeight;
      g.update(1 / 60);
      _run(g, 0.1);
      expect(g.camera.viewfinder.position, Vector2.zero());
      expect(t.haptics.calls, isEmpty, reason: 'titreşim kapalıyken çağrı yok');
      t.services.settings.update((s) => s.copyWith(muted: true));
      expect(t.audio.musicVolume, 0);
      expect(t.audio.sfxVolume, 0);
      g.onRemove();
    });

    test('bölge değişince bölge sesi ve ortam (liman → rüzgâr)', () async {
      final (g, t) = await _game();
      g.debugInvincible = true;
      g.autopilot = true;
      g.handleTap();
      while (g.zoneIndex.value < 3) {
        g.update(1 / 60);
      }
      expect(t.audio.sfx.where((s) => s == Sfx.zone), hasLength(3));
      expect(t.audio.ambience.last, Ambience.windy);
      expect(
        t.audio.cues,
        isNotEmpty,
        reason: 'uzak martı / vapur düdüğü ara sıra çalar',
      );
      g.onRemove();
    });
  });

  test('Android geri tuşu: bir seviye geri, sadece ana menüde çıkış', () async {
    final (g, _) = await _game();
    // ana menü: olay tüketilmez → uygulama kapanabilir
    expect(g.menuOpen.value, isTrue);
    expect(g.handleBack(), isFalse);
    // açık pencere kapanır
    g.openModal(Overlays.settings);
    expect(g.handleBack(), isTrue);
    expect(g.modal.value, isNull);
    // "uçmak için dokun" ekranından menüye
    g.startFromMenu();
    expect(g.handleBack(), isTrue);
    expect(g.menuOpen.value, isTrue);
    // oyunda: duraklatır
    g.startFromMenu();
    g.handleTap();
    expect(g.phase.value, GamePhase.playing);
    expect(g.handleBack(), isTrue);
    expect(g.phase.value, GamePhase.paused);
    // duraklatmadan: tur temizlenir, menüye dönülür, motor yeniden çalışır
    expect(g.handleBack(), isTrue);
    expect(g.phase.value, GamePhase.ready);
    expect(g.menuOpen.value, isTrue);
    expect(g.paused, isFalse);
    // oyun sonu: kart açılmadan yok sayılır, sonra menüye
    g.startFromMenu();
    g.handleTap();
    _run(g, 2.5);
    expect(g.phase.value, GamePhase.gameOver);
    expect(g.canRestart.value, isFalse);
    expect(g.handleBack(), isTrue);
    expect(g.phase.value, GamePhase.gameOver);
    _run(g, g.config.gameOverCardDelay + g.config.restartLockTime + 0.1);
    expect(g.handleBack(), isTrue);
    expect(g.phase.value, GamePhase.ready);
    expect(g.menuOpen.value, isTrue);
    g.onRemove();
  });

  test(
    'kare hızından bağımsız: 30 ve 60 fps aynı skor, simit ve kıl payı',
    () async {
      Future<(int, int, int)> sim(double dt) async {
        final (g, _) = await _game();
        g.autopilot = true;
        g.handleTap();
        for (
          var i = 0, n = (25 / dt).round();
          i < n && g.phase.value == GamePhase.playing;
          i++
        ) {
          g.update(dt);
        }
        final r = (g.score.value, g.runSimits.value, g.nearMisses.value);
        g.onRemove();
        return r;
      }

      final a = await sim(1 / 30), b = await sim(1 / 60);
      expect(a, b);
      expect(a.$1, greaterThan(5));
    },
  );
}
