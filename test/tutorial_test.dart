import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/challenge/daily_challenge.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/events/event_calendar.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/game/tutorial.dart';
import 'package:istanbul_flight/progression/game_events.dart';
import 'package:istanbul_flight/services/game_center/game_center_controller.dart';
import 'package:istanbul_flight/services/progress.dart';
import 'package:istanbul_flight/services/ux_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';
import 'game_center_fakes.dart';

// Phase 2.8 (docs/21 §4): ilk uçuş eğitimi.

final _now = DateTime.utc(2026, 11, 11, 12);

class _Events implements GameEventListener {
  final all = <GameEvent>[];
  @override
  void onGameEvent(GameEvent e) => all.add(e);
}

Future<(IstanbulFlightGame, TestServices, _Events, FakeGameCenterApi)> _game({
  UxState ux = const UxState(),
  PlayerProgress progress = const PlayerProgress(),
  InMemoryScoreRepository? scores,
}) async {
  final api = FakeGameCenterApi();
  final t = TestServices(
    progress: progress,
    clock: () => _now,
    gameCenter: (p) => GameCenterController(
      api: api,
      store: InMemoryGameCenterStore(const GcRecord(legacyExported: true)),
      progress: p,
      scores: InMemoryScoreRepository(),
      clock: () => _now,
    ),
    ux: UxController(InMemoryUxRepository(ux), ux),
  );
  final ev = _Events();
  t.services.listeners.add(ev);
  await t.services.gameCenter.start();
  final g = await initializeGame(
    () => IstanbulFlightGame(
      scores: scores ?? InMemoryScoreRepository(),
      random: Random(7),
      pickupRandom: Random(8),
      loadArt: false,
      services: t.services,
    ),
  );
  g.onGameResize(Vector2(1080, 1920));
  await g.ready();
  return (g, t, ev, api);
}

/// Eğitimi uçan basit pilot: geçidin ortasına doğru kanat çırpar (gerçek dokunuşla aynı yol).
void _fly(IstanbulFlightGame g, double seconds, {bool Function()? until}) {
  for (var i = 0, n = (seconds * 60).round(); i < n; i++) {
    if (until != null && until()) return;
    if (g.phase.value == GamePhase.ready) {
      g.handleTap();
      continue;
    }
    final next = g.obstacles.where((o) => o.right > g.birdX - 40).firstOrNull;
    final target = next?.pickupY ?? next?.gapCenter ?? g.config.worldHeight * 0.45;
    if (g.physics.y > target + 30 && g.physics.velocity > -150) g.handleTap();
    g.update(1 / 60);
  }
}

void main() {
  group('Eğitim akışı (durum makinesi)', () {
    test('aşamalar sırayla: uç → engel → simit → bitti', () {
      final f = TutorialFlow();
      expect(f.stage, TutorialStage.fly);
      expect(f.wantsObstacle, isFalse);
      f.onFlap();
      for (var i = 0; i < 120 * 2; i++) {
        f.onStep(1 / 120);
      }
      expect(f.stage, TutorialStage.fly);
      for (var i = 0; i < 120; i++) {
        f.onStep(1 / 120);
      }
      expect(f.stage, TutorialStage.obstacle);
      expect(f.wantsObstacle, isTrue);
      expect(f.obstacleHasSimit, isFalse);
      f.onObstacleSpawned();
      expect(f.wantsObstacle, isFalse);
      f.onObstaclePassed();
      expect(f.stage, TutorialStage.simit);
      expect(f.obstacleHasSimit, isTrue);
      f.onObstacleSpawned();
      f.onSimitCollected();
      f.onObstaclePassed();
      expect(f.isDone, isTrue);
    });

    test('simit kaçırılırsa bir tane daha; çarpınca aynı aşama, ilerleme sıfırlanmaz', () {
      final f = TutorialFlow();
      for (var i = 0; i < 400; i++) {
        f.onStep(1 / 120);
      }
      f.onObstacleSpawned();
      f.onObstaclePassed();
      f.onObstacleSpawned();
      f.onObstaclePassed(); // simit alınmadı
      expect(f.stage, TutorialStage.simit);
      expect(f.hint, TutorialHint.missedSimit);
      expect(f.wantsObstacle, isTrue);
      f.onObstacleSpawned();
      f.onCrash();
      expect(f.stage, TutorialStage.simit);
      expect(f.hint, TutorialHint.crashed);
      expect(f.wantsObstacle, isTrue); // yeniden başlayınca engel yeniden gelir
      final g = TutorialFlow();
      for (var i = 0; i < 200; i++) {
        g.onStep(1 / 120);
      }
      g.onCrash(); // Aşama 1'de: havada kalma süresi baştan
      expect(g.stage, TutorialStage.fly);
      expect(g.flyProgress, 0);
    });
  });

  group('Deneyim kaydı (ux_v1)', () {
    test('yeni oyuncu eğitim görür; ilerlemesi olan eski oyuncu görmez', () {
      expect(
        UxState.initialFor(const PlayerProgress(), best: 0).tutorial,
        TutorialStatus.pending,
      );
      expect(
        UxState.initialFor(const PlayerProgress(), best: 12).tutorial,
        TutorialStatus.legacy,
      );
      final old = UxState.initialFor(
        const PlayerProgress(flights: 3, unlockedCosmetics: {'classic', 'denizci'}),
        best: 0,
      );
      expect(old.tutorial, TutorialStatus.legacy);
      // güncellemeden sonra menü bir yığın "yeni" işaretiyle açılmaz
      expect(old.seenCosmetics, {'classic', 'denizci'});
    });

    test('tamamlanan eğitim geri alınmaz; atlama yalnızca bekleyen eğitimde', () {
      final c = UxController.memory(const UxState());
      c.finishTutorial(TutorialStatus.skipped);
      expect(c.value.tutorial, TutorialStatus.skipped);
      c.finishTutorial(TutorialStatus.completed); // sonradan tamamlama olur
      expect(c.value.tutorial, TutorialStatus.completed);
      c.finishTutorial(TutorialStatus.skipped); // tamamlanmış geri alınmaz
      expect(c.value.tutorial, TutorialStatus.completed);
      final legacy = UxController.memory(
        const UxState(tutorial: TutorialStatus.legacy),
      );
      legacy.finishTutorial(TutorialStatus.skipped);
      expect(legacy.value.tutorial, TutorialStatus.legacy);
    });

    test('ayrı anahtar, kendi sürümü; bozuk ya da tanınmayan kayıt eğitimi zorlamaz', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsUxRepository(prefs);
      expect(await repo.load(), isNull);
      final c = await UxController.load(repo, const PlayerProgress(), best: 0);
      expect(c.value.tutorial, TutorialStatus.pending);
      expect(prefs.getString(SharedPrefsUxRepository.key), contains('"v":1'));
      c.finishTutorial(TutorialStatus.completed);
      await c.flush();
      expect((await repo.load())!.tutorial, TutorialStatus.completed);
      // ilerleme kaydına dokunulmaz
      expect(prefs.getString(SharedPrefsProgressRepository.key), isNull);
      await prefs.setString(SharedPrefsUxRepository.key, '{bozuk');
      expect((await repo.load())!.tutorial, TutorialStatus.legacy);
      expect(UxState.fromJson({'tutorial': 'gelecek_durum'}).tutorial, TutorialStatus.legacy);
    });
  });

  group('Eğitim oyunda', () {
    test('ilk açılışta yeni oyuncu doğrudan eğitimde (menü yerine); eski oyuncu menüde', () async {
      final (g, _, _, _) = await _game();
      expect(g.runMode.value, RunMode.tutorial);
      expect(g.menuOpen.value, isFalse);
      expect(g.tutorialStage.value, TutorialStage.fly);
      final (old, _, _, _) = await _game(
        ux: const UxState(tutorial: TutorialStatus.legacy),
      );
      expect(old.runMode.value, RunMode.classic);
      expect(old.menuOpen.value, isTrue);
      expect(old.tutorialStage.value, isNull);
    });

    test('eğitimi tamamlama: üç aşama, sonra normal uçuşun "dokun" ekranı; hiçbir ödül ya da kayıt yok', () async {
      final (g, t, ev, api) = await _game();
      final before = t.services.progress.value;
      _fly(g, 60, until: () => g.tutorialJustCompleted.value);
      expect(g.tutorialJustCompleted.value, isTrue);
      expect(g.runMode.value, RunMode.classic);
      expect(g.phase.value, GamePhase.ready);
      expect(t.services.ux.value.tutorial, TutorialStatus.completed);
      // eğitim gerçek uçuş değil: olay yok, hesap yok
      expect(ev.all.whereType<RunStarted>(), isEmpty);
      expect(ev.all.whereType<RunFinished>(), isEmpty);
      expect(ev.all.whereType<RunAbandoned>(), isEmpty);
      expect(ev.all.whereType<SimitCollected>(), isEmpty);
      expect(ev.all.whereType<ObstaclePassed>(), isEmpty);
      final after = t.services.progress.value;
      expect(after.toJson(), before.toJson());
      expect(after.flights, 0);
      expect(after.xp, 0);
      expect(after.simitBalance, 0);
      expect(g.best.value, 0);
      expect(api.submissions, isEmpty);
      // bir sonraki dokunuş gerçek (klasik) uçuşu başlatır ve normal hesaplanır
      g.handleTap();
      expect(g.runMode.value, RunMode.classic);
      expect(ev.all.whereType<RunStarted>().single.mode, RunMode.classic);
    });

    test('eğitimde çarpmak oyun sonu getirmez: aynı aşama "dokun" ekranından yeniden', () async {
      final (g, t, ev, _) = await _game();
      g.handleTap(); // uçuş başlar, kanat çırpmadan düşer → suya değer
      for (var i = 0; i < 60 * 4 && g.phase.value == GamePhase.playing; i++) {
        g.update(1 / 60);
      }
      expect(g.phase.value, GamePhase.ready);
      expect(g.runMode.value, RunMode.tutorial);
      expect(g.tutorialStage.value, TutorialStage.fly);
      expect(g.tutorialHint.value, TutorialHint.crashed);
      expect(ev.all.whereType<RunFinished>(), isEmpty);
      expect(t.services.ux.value.tutorial, TutorialStatus.pending);
    });

    test('atlama: bir daha zorlanmaz, menü açılır', () async {
      final (g, t, _, _) = await _game();
      g.skipTutorial();
      expect(t.services.ux.value.tutorial, TutorialStatus.skipped);
      expect(g.menuOpen.value, isTrue);
      expect(g.runMode.value, RunMode.classic);
      expect(g.tutorialStage.value, isNull);
    });

    test('eğitim sırasında çıkış (duraklat → ana menü): yarıda bırakıldı, olay yok', () async {
      final (g, t, ev, _) = await _game();
      g.handleTap();
      g.update(1 / 60);
      g.pauseGame();
      g.openMenu();
      expect(t.services.ux.value.tutorial, TutorialStatus.skipped);
      expect(g.menuOpen.value, isTrue);
      expect(ev.all.whereType<RunAbandoned>(), isEmpty);
      expect(ev.all.whereType<RunStarted>(), isEmpty);
    });

    test('tekrar oynatma: tamamlanmış durum değişmez, yine ödülsüz', () async {
      final (g, t, ev, _) = await _game(
        ux: const UxState(tutorial: TutorialStatus.completed),
      );
      expect(g.menuOpen.value, isTrue);
      g.startTutorial();
      expect(g.runMode.value, RunMode.tutorial);
      _fly(g, 60, until: () => g.tutorialJustCompleted.value);
      expect(t.services.ux.value.tutorial, TutorialStatus.completed);
      expect(ev.all.whereType<RunFinished>(), isEmpty);
      expect(t.services.progress.value.flights, 0);
    });

    test('eğitim Günün Uçuşu hakkı ve haftalık kupa kaydı tüketmez; deterministik parkur etkilenmez', () async {
      final (g, t, _, _) = await _game();
      final dailyBefore = t.services.daily.today();
      _fly(g, 60, until: () => g.tutorialJustCompleted.value);
      final p = t.services.progress.value;
      expect(p.dailyChallenge.records, isEmpty);
      expect(p.events.records, isEmpty);
      final dailyAfter = t.services.daily.today();
      expect(dailyAfter.seed, dailyBefore.seed);
      expect(
        EventGenerators.build(EventCalendar.activeCup(_now)!).seed,
        EventGenerators.build(EventCalendar.activeCup(_now)!).seed,
      );
      // eğitimden sonra dereceli günlük uçuş hâlâ 3 hakla
      g.startDaily(ranked: true);
      g.handleTap();
      expect(g.runMode.value, RunMode.dailyRanked);
    });

    test('eğitimde hava hep açık, dinamik engel yok, skor ve rekor rozeti yok', () async {
      final (g, _, _, _) = await _game();
      _fly(g, 20, until: () => g.tutorialStage.value == TutorialStage.simit);
      expect(g.weatherLayer.weather.name, 'clear');
      expect(g.hazardViews, isEmpty);
      expect(g.score.value, 0);
      expect(g.recordPassed.value, isFalse);
    });
  });

  group('Mod regresyonu', () {
    test('klasik, günlük ve etkinlik uçuşları eğitimden sonra eskisi gibi hesaplanır', () async {
      final (g, t, ev, _) = await _game(
        ux: const UxState(tutorial: TutorialStatus.legacy),
      );
      Future<void> crashRun() async {
        g.handleTap();
        for (var i = 0; i < 60 * 6 && g.phase.value == GamePhase.playing; i++) {
          g.update(1 / 60);
        }
        for (var i = 0; i < 60 * 3; i++) {
          g.update(1 / 60);
        }
      }

      g.startFromMenu();
      await crashRun();
      g.startDaily(ranked: true);
      await crashRun();
      g.startEvent(t.services.events.definition(EventCalendar.activeCup(_now)!));
      await crashRun();
      final modes = [for (final e in ev.all.whereType<RunFinished>()) e.result.mode];
      expect(modes, [RunMode.classic, RunMode.dailyRanked, RunMode.event]);
      final p = t.services.progress.value;
      expect(p.flights, 3);
      expect(p.dailyChallenge.records.values.single.used, 1);
      expect(p.events.records.length, 1);
    });
  });
}
