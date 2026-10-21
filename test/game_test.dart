import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/components/landmark_layer.dart';
import 'package:istanbul_flight/game/components/obstacle_pair.dart';
import 'package:istanbul_flight/game/day_cycle.dart';
import 'package:istanbul_flight/game/visual/simit_animator.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';

IstanbulFlightGame Function() _create([
  InMemoryScoreRepository? repo,
  int best = 0,
]) =>
    () => IstanbulFlightGame(
      scores: repo ?? InMemoryScoreRepository(best),
      random: Random(7),
      loadArt: false,
    );

void _run(IstanbulFlightGame g, double seconds, {double dt = 1 / 60}) {
  // Tam sayı kare sayısı: kayan nokta toplamı fazladan kare çalıştırmasın
  for (var i = 0, n = (seconds / dt).round(); i < n; i++) {
    g.update(dt);
  }
}

/// Engellerden geçerken otomatik kanat çırpar (çarpışma kapalıyken bile gerçekçi bir uçuş).
void _autopilot(IstanbulFlightGame g, double seconds, {double dt = 1 / 60}) {
  for (var i = 0, n = max(1, (seconds / dt).round()); i < n; i++) {
    final next = g.obstacles.where((o) => o.right > g.birdX - 40).firstOrNull;
    final target = next?.gapCenter ?? g.config.worldHeight * 0.45;
    if (g.physics.y > target + 40 && g.physics.velocity > -200) g.handleTap();
    g.update(dt);
  }
}

Future<void> _phoneSize(IstanbulFlightGame g) async {
  g.onGameResize(Vector2(1080, 1920));
  await g.ready();
}

void main() {
  testWithGame<IstanbulFlightGame>(
    'READY ile başlar, ilk dokunuş başlatır ve kanat çırptırır',
    _create(),
    (g) async {
      await _phoneSize(g);
      expect(g.phase.value, GamePhase.ready);
      _run(g, 2);
      expect(g.obstacles, isEmpty, reason: 'READY iken engel üretilmez');
      expect(g.score.value, 0);

      g.handleTap();
      expect(g.phase.value, GamePhase.playing);
      expect(g.physics.velocity, g.config.flapVelocity);
    },
  );

  testWithGame<IstanbulFlightGame>(
    'engeller düzenli üretilir, akar ve ekran dışında silinir',
    _create(),
    (g) async {
      await _phoneSize(g);
      g.debugInvincible = true;
      g.handleTap();
      _autopilot(g, 3);
      expect(g.obstacles, isNotEmpty);
      final firstX = g.obstacles.first.position.x;
      _autopilot(g, 0.5);
      expect(
        g.obstacles.first.position.x,
        lessThan(firstX),
        reason: 'engeller sola akmalı',
      );
      for (var i = 1; i < g.obstacles.length; i++) {
        expect(
          g.obstacles[i].position.x - g.obstacles[i - 1].position.x,
          closeTo(g.config.obstacleSpacing, 0.01),
        );
      }
    },
  );

  testWithGame<IstanbulFlightGame>(
    'uzun oturum: nesne sayısı sınırlı kalır (10 dakika)',
    _create(),
    (g) async {
      await _phoneSize(g);
      g.debugInvincible = true;
      g.handleTap();
      var maxObstacles = 0;
      for (var i = 0; i < 600; i++) {
        _autopilot(g, 1);
        maxObstacles = max(maxObstacles, g.obstacles.length);
      }
      final bound =
          (g.visibleWidth + g.config.obstacleWidth * 2 + 200) ~/
              g.config.obstacleSpacing +
          2;
      expect(maxObstacles, lessThanOrEqualTo(bound));
      expect(
        g.world.children.whereType<ObstaclePair>().length,
        g.obstacles.length,
      );
      expect(
        g.score.value,
        greaterThan(300),
        reason: '10 dk boyunca engeller geçilmiş olmalı',
      );
    },
  );

  testWithGame<IstanbulFlightGame>(
    'her engel tam olarak bir puan verir',
    _create(),
    (g) async {
      await _phoneSize(g);
      g.debugInvincible = true;
      g.handleTap();
      _autopilot(g, 20);
      final passed = g.obstacles.where((o) => o.right < g.birdX).length;
      final notPassed = g.obstacles.where((o) => o.right >= g.birdX);
      expect(notPassed.every((o) => !o.scored), isTrue);
      expect(
        g.obstacles.where((o) => o.right < g.birdX).every((o) => o.scored),
        isTrue,
      );
      // Silinmiş engeller + ekrandaki geçilmiş engeller = skor
      final removed = g.obstacles.isEmpty ? 0 : g.obstacles.first.seed;
      expect(g.score.value, removed + passed);
    },
  );

  testWithGame<IstanbulFlightGame>(
    'suya düşünce GAME_OVER: skor, üretim ve engeller durur',
    _create(),
    (g) async {
      await _phoneSize(g);
      g.handleTap();
      _run(g, 2.5); // dokunmadan düşer
      expect(g.phase.value, GamePhase.gameOver);
      final score = g.score.value;
      final count = g.obstacles.length;
      final xs = g.obstacles.map((o) => o.position.x).toList();
      _run(g, 5);
      expect(g.score.value, score);
      expect(g.obstacles.length, count);
      expect(g.obstacles.map((o) => o.position.x).toList(), xs);
      expect(g.physics.y, lessThanOrEqualTo(g.config.worldHeight));
    },
  );

  testWithGame<IstanbulFlightGame>(
    'engele çarpınca GAME_OVER, sonraki adımlarda puan artmaz',
    _create(),
    (g) async {
      await _phoneSize(g);
      g.debugInvincible = true;
      g.handleTap();
      while (!g.obstacles.any(
        (o) => o.position.x < g.birdX + 30 && o.right > g.birdX,
      )) {
        _autopilot(g, 1 / 60);
      }
      final o = g.obstacles.firstWhere(
        (o) => o.position.x < g.birdX + 30 && o.right > g.birdX,
      );
      final before = g.score.value;
      g.debugInvincible = false;
      g.physics.y = o.gapTop - 120; // üst engelin içi
      g.physics.velocity = 0;
      g.update(1 / 60);
      expect(g.phase.value, GamePhase.gameOver);
      _run(g, 3);
      expect(g.score.value, before);
    },
  );

  test('rekor: yeni rekor kaydedilir, düşük skor kaydı değiştirmez', () async {
    final repo = InMemoryScoreRepository(3);
    final g = await initializeGame(_create(repo));
    await _phoneSize(g);
    expect(g.best.value, 3);

    // Tur 1: 5 puan → yeni rekor
    g.debugInvincible = true;
    g.handleTap();
    while (g.score.value < 5) {
      _autopilot(g, 1 / 60);
    }
    g.debugInvincible = false;
    g.physics.y = g.config.worldHeight;
    g.update(1 / 60);
    expect(g.phase.value, GamePhase.gameOver);
    expect(g.best.value, 5);
    expect(g.isNewRecord.value, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(await repo.loadBest(), 5);
    expect(repo.saveCount, 1);

    // Tur 2: 0 puan → rekor korunur, kayıt yapılmaz
    _run(g, 2);
    g.restart();
    expect(g.best.value, 5);
    g.handleTap();
    _run(g, 3);
    expect(g.phase.value, GamePhase.gameOver);
    expect(g.isNewRecord.value, isFalse);
    expect(repo.saveCount, 1);
    g.onRemove();
  });

  testWithGame<IstanbulFlightGame>(
    'yeniden başlatma kilidi ve tam temizlik',
    _create(),
    (g) async {
      await _phoneSize(g);
      g.handleTap();
      _run(g, 2.5);
      expect(g.phase.value, GamePhase.gameOver);
      g.handleTap(); // kilit süresi dolmadan
      expect(g.phase.value, GamePhase.gameOver);
      _run(g, g.config.gameOverCardDelay + g.config.restartLockTime + 0.1);
      expect(g.canRestart.value, isTrue);

      g.handleTap();
      g.update(0); // kaldırma işlemleri işlensin
      expect(g.phase.value, GamePhase.ready);
      expect(g.obstacles, isEmpty);
      expect(g.world.children.whereType<ObstaclePair>(), isEmpty);
      expect(g.score.value, 0);
      expect(g.zoneIndex.value, 0);
      expect(g.physics.velocity, 0);

      g.handleTap();
      expect(g.phase.value, GamePhase.playing);
    },
  );

  testWithGame<IstanbulFlightGame>(
    'duraklatma ve arka plana alınma',
    _create(),
    (g) async {
      await _phoneSize(g);
      g.handleTap();
      _run(g, 0.2);
      g.pauseGame();
      expect(g.phase.value, GamePhase.paused);
      expect(g.paused, isTrue);

      g.resumeGame();
      expect(g.phase.value, GamePhase.playing);
      expect(g.paused, isFalse);

      g.lifecycleStateChange(AppLifecycleState.paused);
      expect(g.phase.value, GamePhase.paused);
      g.lifecycleStateChange(AppLifecycleState.resumed);
      expect(
        g.phase.value,
        GamePhase.paused,
        reason: 'geri dönüşte oyuncu Devam\'a basmalı',
      );
      expect(g.paused, isTrue);
      g.handleTap();
      expect(g.phase.value, GamePhase.playing);
    },
  );

  testWithGame<IstanbulFlightGame>(
    'iOS yaşam döngüsü: kontrol merkezi, arama, kilit → duraklar; dönüşte kendiliğinden başlamaz',
    _create(),
    (g) async {
      await _phoneSize(g);
      // iOS'ta bildirim / kontrol merkezi açılınca ve gelen aramada önce "inactive" gelir
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        g.handleTap();
        _run(g, 0.1);
        expect(g.phase.value, GamePhase.playing);
        g.lifecycleStateChange(s);
        expect(g.phase.value, GamePhase.paused, reason: '$s');
        expect(g.paused, isTrue);
        g.lifecycleStateChange(AppLifecycleState.resumed);
        expect(
          g.phase.value,
          GamePhase.paused,
          reason: "dönüşte oyuncu Devam'a basmalı ($s)",
        );
        g.resumeGame();
      }
      // menüdeyken arka plana alınma: oyun durumu değişmez
      g.openMenu();
      g.lifecycleStateChange(AppLifecycleState.paused);
      expect(g.phase.value, GamePhase.ready);
      g.lifecycleStateChange(AppLifecycleState.resumed);
      expect(g.phase.value, GamePhase.ready);
    },
  );

  const g1StepMove = 1500 / 120; // azami hızla bir fizik adımında alınan yol

  test('kare hızından bağımsız: 30 fps ve 144 fps aynı yörünge', () async {
    Future<double> sim(double dt) async {
      final g = await initializeGame(_create());
      await _phoneSize(g);
      g.handleTap();
      _run(g, 0.5, dt: dt);
      final y = g.physics.y;
      g.onRemove();
      return y;
    }

    final y30 = await sim(1 / 30);
    final y144 = await sim(1 / 144);
    final y60 = await sim(1 / 60);
    expect(y30, y60, reason: '4 ve 2 fizik adımı/kare: aynı simülasyon');
    // 144 fps kare sınırları 120 Hz adımlarla hizalanmaz: fark en fazla bir adımlık yol
    expect((y30 - y144).abs(), lessThan(g1StepMove));
  });

  testWithGame<IstanbulFlightGame>(
    'bölge geçişi: yeni simge beklemeden görünür, eskisi solarak çıkar',
    _create(),
    (g) async {
      await _phoneSize(g);
      g.debugInvincible = true;
      g.handleTap();
      var maxActive = 0;
      while (g.zoneIndex.value == 0) {
        _autopilot(g, 1 / 60);
        maxActive = max(maxActive, g.landmarks.activeInstances.length);
      }
      // Geçişin hemen ardından (1 kare): yeni simge aktif, görünür alanın içinde, solmuyor
      _autopilot(g, 1 / 60);
      final target = zones[1].landmark;
      final fresh = g.landmarks.activeInstances
          .where((i) => i.landmark == target && !i.fadingOut)
          .toList();
      expect(fresh, hasLength(1));
      final w = LandmarkLayer.layout(target).w;
      expect(fresh.first.x, lessThan(g.visibleWidth));
      expect(fresh.first.x + w, greaterThan(0));
      expect(
        g.landmarks.activeInstances.where((i) => i.fadingOut),
        isNotEmpty,
        reason: 'eski simge anında kaybolmamalı',
      );

      // Solma süresi sonunda eski simge çıkmış, yenisi tam opak
      for (var i = 0; i < ((LandmarkLayer.fadeTime + 0.3) * 60).round(); i++) {
        _autopilot(g, 1 / 60);
        maxActive = max(maxActive, g.landmarks.activeInstances.length);
      }
      expect(g.landmarks.activeInstances.where((i) => i.fadingOut), isEmpty);
      expect(fresh.first.alpha, 1);
      expect(maxActive, lessThanOrEqualTo(2));
    },
  );

  testWithGame<IstanbulFlightGame>(
    'bölge geçişi oynanışı etkilemez: engel aralığı ve skor sürekliliği',
    _create(),
    (g) async {
      await _phoneSize(g);
      g.debugInvincible = true;
      g.handleTap();
      while (g.score.value < 17) {
        _autopilot(g, 1 / 60);
      }
      for (var i = 1; i < g.obstacles.length; i++) {
        expect(
          g.obstacles[i].position.x - g.obstacles[i - 1].position.x,
          closeTo(g.config.obstacleSpacing, 0.01),
        );
      }
      // Geçiş öncesi üretilen engeller kendi kitini korur, sonrası yeni bölgenin kitini alır
      expect(g.obstacles.last.kit, ObstacleKitId.galata);
    },
  );

  testWithGame<IstanbulFlightGame>(
    'oyun sonu tepkisi: suya düşünce simit başına geçer, yeniden başlatmada sıfırlanır',
    _create(),
    (g) async {
      await _phoneSize(g);
      g.handleTap();
      _run(g, 3);
      expect(g.phase.value, GamePhase.gameOver);
      expect(g.bird.animator.isLanded, isTrue);
      expect(g.bird.frame, SimitAnimator.landed);
      expect(g.fx.activeCount, lessThanOrEqualTo(24));
      _run(g, 2);
      g.restart();
      g.update(1 / 60);
      expect(g.bird.animator.isLanded, isFalse);
      expect(g.fx.activeCount, 0);
      expect(g.landmarks.activeInstances.single.landmark, zones[0].landmark);
    },
  );
}
