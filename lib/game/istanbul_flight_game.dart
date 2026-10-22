import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../data/score_repository.dart';
import '../progression/cosmetics.dart';
import '../progression/game_events.dart';
import '../services/audio_service.dart';
import 'components/background.dart';
import 'components/fx_layer.dart';
import 'components/landmark_layer.dart';
import 'components/obstacle_pair.dart';
import 'components/pickup_layer.dart';
import 'components/simit_bird.dart';
import 'config.dart';
import 'day_cycle.dart';
import 'game_art.dart';
import 'game_phase.dart';
import 'game_services.dart';
import 'logic/bird_physics.dart';
import 'logic/collision.dart';
import 'logic/gap_generator.dart';
import 'logic/pickup_rules.dart';
import 'visual/obstacle_renderer.dart';

/// Overlay adları (Flutter arayüzü: lib/ui/overlays).
abstract final class Overlays {
  static const menu = 'menu';
  static const ready = 'ready';
  static const hud = 'hud';
  static const pause = 'pause';
  static const gameOver = 'gameOver';
  static const settings = 'settings';
  static const howTo = 'howTo';
  static const stats = 'stats';
  static const profile = 'profile';
  static const missions = 'missions';
  static const achievements = 'achievements';
  static const shop = 'shop';
  static const wardrobe = 'wardrobe';
  static const discovery = 'discovery';
}

/// Martı: Istanbul Flight oyunu.
///
/// Sorumluluk: durum makinesi + sabit adımlı simülasyon (fizik, engel akışı, çarpışma, puan,
/// simit toplama, kıl payı). Çizim bileşenlerde; ses, titreşim, ayar ve ilerleme [GameServices]'te;
/// menüler Flutter overlay'lerinde. Arayüz, buradaki [ValueNotifier]'ları dinler.
///
/// READY durumu iki arayüz moduna sahiptir: ana menü ([menuOpen] = true) ve "uçmak için dokun".
/// Oyun mantığı açısından ikisi aynıdır (Simit süzülür, engel yok); menü dokunuşları kendi düğmeleriyle karşılar.
class IstanbulFlightGame extends FlameGame with TapCallbacks {
  IstanbulFlightGame({
    required this.scores,
    this.config = const GameConfig(),
    math.Random? random,
    math.Random? pickupRandom,
    this.loadArt = true,
    GameServices? services,
  }) : _random = random ?? math.Random(),
       _pickupRandom = pickupRandom ?? math.Random(),
       services = services ?? GameServices.silent();

  final ScoreRepository scores;
  final GameConfig config;
  final bool loadArt;
  final GameServices services;
  final math.Random _random;
  final math.Random _pickupRandom;
  final math.Random _ambientRandom = math.Random(11);

  // ---- Arayüzün dinlediği durum ----
  final phase = ValueNotifier(GamePhase.ready);
  final score = ValueNotifier(0);
  final best = ValueNotifier(0);
  final zoneIndex = ValueNotifier(0);
  final isNewRecord = ValueNotifier(false);
  final canRestart = ValueNotifier(false);

  /// READY'de ana menü mü yoksa "uçmak için dokun" ekranı mı görünüyor.
  final menuOpen = ValueNotifier(true);

  /// Açık modal (ayarlar / nasıl oynanır) ya da null.
  final modal = ValueNotifier<String?>(null);

  /// Bu turda toplanan simit (ana skordan ayrı).
  final runSimits = ValueNotifier(0);

  /// Bu turdaki kıl payı geçiş sayısı (arayüz artışı dinleyip "KIL PAYI!" gösterir).
  final nearMisses = ValueNotifier(0);

  /// Bu turda önceki rekor geçildi mi (HUD'da bir kez rozet).
  final recordPassed = ValueNotifier(false);

  /// Simit'in uygulanan görünümü (kozmetik kimliği). Yalnızca çizimi etkiler; uçuş sırasında değişmez:
  /// seçim menüde hemen, uçuş içinde yapılırsa bir sonraki turda uygulanır.
  final cosmetic = ValueNotifier(classicCosmeticId);

  /// Simit sprite sheet'i: seçili görünüm, yüklenemediyse klasik.
  Image? get birdSheet => art.sheetFor(cosmetic.value);

  // ---- Dünya ----
  GameArt art = GameArt.none();
  final dayCycle = DayCycle();
  late final BirdPhysics physics = BirdPhysics(config, y: readyY);
  late final GapGenerator _gaps = GapGenerator(config, random: _random);
  late final SimitBird bird;
  late final LandmarkLayer _landmarks;

  @visibleForTesting
  LandmarkLayer get landmarks => _landmarks;
  late final List<ZoneLayer> _zoneLayers;
  late final FerryLayer _ferry;
  late final FxLayer fx;

  /// Engel sprite çizicisi (paylaşılan paint'ler, karede bir kez palet güncellenir).
  final ObstacleRenderer obstacleRenderer = ObstacleRenderer();
  final List<ObstaclePair> obstacles = [];

  /// Görünen dünya genişliği (yükseklik her zaman [GameConfig.worldHeight]).
  double visibleWidth = 1080;

  /// Toplam kaydırma mesafesi (parallax katmanları kullanır).
  double scrollDistance = 0;

  /// Bu karede kaydırılan mesafe.
  double frameScroll = 0;

  double _accumulator = 0;
  double _time = 0;
  bool _landed = false;
  bool _cardShown = false;
  double _hitStopT = 0;
  double _shakeT = 0;
  double _cueTimer = 8;
  double _statsClock = 0;
  int _statsFrames = 0;

  /// Oyun saati (sn): mikro animasyonlar buna bağlı, kare hızından bağımsız.
  double get time => _time;

  bool get reduceMotion => services.settings.value.reduceMotion;

  /// Geliştirme: FPS ve nesne sayısı (`--dart-define=MARTI_STATS=true`).
  bool showStats = false;
  final stats = ValueNotifier('');
  double _gameOverTime = 0;
  double _nextSpawnX = 0;
  int _spawnCount = 0;

  // ---- Uçuş kaydı (ilerleme sistemi: lib/progression) ----
  int _runCounter = 0;
  String _runId = '';
  double _runTime = 0;
  int _runObstacles = 0;

  /// Uçuşun bölge bazlı sayaçları (keşif hedefleri, Phase 2.3). Fizik ve skor bunları okumaz.
  final Map<int, ZoneRunStats> _zoneStats = {};

  void _countInZone({int obstacles = 0, int simits = 0, int nearMisses = 0}) {
    final z = zoneIndex.value;
    _zoneStats[z] = (_zoneStats[z] ?? const ZoneRunStats()).add(
      obstacles: obstacles,
      simits: simits,
      nearMisses: nearMisses,
    );
  }

  /// Test ve demo modu: çarpışmaları kapatır (uzun oturum testi, MARTI_DEMO).
  bool debugInvincible = false;

  /// Demo modu: tur bu skordan başlar (bölge ekran görüntüleri için; MARTI_DEMO + `?zone=n`).
  int debugStartScore = 0;

  /// Demo modu: yüklenince menüyü atlayıp turu başlatır (mağaza ekran görüntüleri; MARTI_DEMO + `&play=1`).
  bool debugAutoStart = false;

  /// Geliştirme: Simit kendi kendine uçar (`--dart-define=MARTI_AUTOPILOT=true`).
  bool autopilot = false;

  PhasePalette get palette => dayCycle.palette;
  double get readyY => config.worldHeight * 0.42;
  double get birdX => (visibleWidth * config.birdXFraction).clamp(
    config.birdMinX,
    config.birdMaxX,
  );
  double get currentSpeed => config.speedForScore(score.value);

  @override
  Color backgroundColor() => const Color(0xFF0E1433);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();
    if (loadArt) art = await GameArt.load(images);
    try {
      best.value = await scores.loadBest();
    } catch (e) {
      debugPrint('En iyi skor okunamadı: $e');
    }
    bird = SimitBird(art: art, displayWidth: config.birdDisplayWidth);
    _landmarks = LandmarkLayer();
    _ferry = FerryLayer();
    fx = FxLayer();
    _zoneLayers = [
      SkyLayer(),
      CloudLayer(),
      FarLayer(),
      ShoreLayer(),
      WaterLayer(),
      WaterfrontLayer(),
    ];
    await world.addAll([
      ..._zoneLayers,
      _landmarks,
      _ferry,
      LandmarkFrontLayer(_landmarks),
      FogLayer(),
      PickupLayer(),
      fx,
      bird,
    ]);
    services.settings.addListener(_applySettings);
    _applySettings();
    services.progress.addListener(_onProgressChanged);
    _applyCosmetic();
    services.audio.setAmbience(ambienceForZone(0));
    _syncBird(idle: true);
    _applyOverlays();
    _syncMusic();
    if (debugAutoStart) {
      startFromMenu();
      handleTap();
    }
  }

  @override
  void onRemove() {
    services.settings.removeListener(_applySettings);
    services.progress.removeListener(_onProgressChanged);
    super.onRemove();
  }

  void _applySettings() {
    final s = services.settings.value;
    services.audio.setVolumes(music: s.effectiveMusic, sfx: s.effectiveSfx);
    services.haptics.enabled = s.haptics;
  }

  void _onProgressChanged() {
    if (phase.value == GamePhase.ready) _applyCosmetic();
  }

  /// Seçili görünümü uygular (bilinmeyen / sahip olunmayan görünüm → klasik).
  void _applyCosmetic() {
    cosmetic.value = effectiveCosmetic(services.progress.value).id;
  }

  /// Bölgenin ortam döngüsü: limanlı bölgelerde dalga, açık Boğaz'da rüzgâr.
  static Ambience ambienceForZone(int zone) =>
      zone <= 2 ? Ambience.harbor : Ambience.windy;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size.y <= 0) return;
    final zoom = size.y / config.worldHeight;
    camera.viewfinder.zoom = zoom;
    visibleWidth = size.x / zoom;
  }

  // ================= Girdi =================

  @override
  void onTapDown(TapDownEvent event) => handleTap();

  /// Dokunma: READY'de oyunu başlatır ve aynı anda kanat çırptırır (ilk dokunuş boşa gitmez).
  /// Ana menü açıkken dokunuşlar menünün kendi düğmelerine gider (overlay dokunuşu tutar).
  void handleTap() {
    switch (phase.value) {
      case GamePhase.ready:
        _start();
      case GamePhase.playing:
        _flap();
      case GamePhase.paused:
        resumeGame();
      case GamePhase.gameOver:
        if (canRestart.value) restart();
    }
  }

  void _start() {
    _accumulator = 0;
    _nextSpawnX = visibleWidth + config.firstObstacleOffset;
    menuOpen.value = false;
    modal.value = null;
    _setPhase(GamePhase.playing);
    if (debugStartScore > 0 && score.value == 0) {
      score.value = debugStartScore - 1;
      _addPoint();
    }
    _runId = '${DateTime.now().microsecondsSinceEpoch}-${_runCounter++}';
    _runTime = 0;
    _runObstacles = 0;
    _zoneStats.clear();
    services.emit(RunStarted(_runId));
    _flap();
  }

  void _flap() {
    physics.flap();
    bird.onFlap();
    fx.feather(birdX, physics.y);
    services.audio.playSfx(Sfx.flap);
  }

  // ================= Menü =================

  /// "UÇMAYA BAŞLA": menüyü kapatır, "uçmak için dokun" ekranına geçer.
  void startFromMenu() {
    if (phase.value != GamePhase.ready) return;
    menuOpen.value = false;
    modal.value = null;
    _applyOverlays();
  }

  /// Ana menüye dön (duraklatma ya da oyun sonundan). Tur temizlenir.
  void openMenu() {
    if (phase.value != GamePhase.ready) restart();
    menuOpen.value = true;
    _applyOverlays();
    _syncMusic();
  }

  void openModal(String name) {
    modal.value = name;
    _applyOverlays();
  }

  void closeModal() {
    modal.value = null;
    _applyOverlays();
  }

  /// Sistem geri tuşu (Android). Bir seviye geri gider; `true` = olay tüketildi, uygulama kapanmaz.
  /// Pencere açıksa kapatır, oyunda duraklatır, duraklatma / oyun sonu / "dokun" ekranından ana menüye
  /// döner. Sadece ana menüdeyken `false` döner (uygulamadan çıkılır).
  bool handleBack() {
    if (modal.value != null) {
      closeModal();
      return true;
    }
    switch (phase.value) {
      case GamePhase.playing:
        pauseGame();
        return true;
      case GamePhase.paused:
        openMenu();
        return true;
      case GamePhase.gameOver:
        // çarpışma animasyonu bitmeden geri tuşu yok sayılır
        if (canRestart.value) openMenu();
        return true;
      case GamePhase.ready:
        if (menuOpen.value) return false;
        openMenu();
        return true;
    }
  }

  // ================= Döngü =================

  @override
  void update(double dt) {
    final frameDt = math.min(dt, config.maxFrameDt);
    _time += frameDt;
    final before = scrollDistance;

    switch (phase.value) {
      case GamePhase.ready:
        // Canlı menü: Simit süzülür, şehir yavaşça akar
        physics.y = readyY + math.sin(_time * 2.6) * 16;
        physics.velocity = 0;
        scrollDistance += frameDt * config.startSpeed * 0.35;
      case GamePhase.playing:
        _accumulator += frameDt;
        while (_accumulator >= config.physicsStep &&
            phase.value == GamePhase.playing) {
          _accumulator -= config.physicsStep;
          _stepPlaying(config.physicsStep);
        }
      case GamePhase.gameOver:
        _updateGameOver(frameDt);
      case GamePhase.paused:
        break;
    }

    frameScroll = scrollDistance - before;
    dayCycle.update(frameDt);
    obstacleRenderer.setPalette(palette);
    _syncBird(idle: phase.value == GamePhase.ready);
    _updateShake(frameDt);
    if (phase.value != GamePhase.paused) _updateAmbientCues(frameDt);
    super.update(dt);
    if (showStats) _updateStats(dt);
  }

  void _updateStats(double dt) {
    _statsFrames++;
    _statsClock += dt;
    if (_statsClock < 0.5) return;
    final fps = _statsFrames / _statsClock;
    stats.value =
        'FPS ${fps.toStringAsFixed(0)} · bileşen ${world.children.length} · engel ${obstacles.length} · efekt ${fx.activeCount}';
    _statsClock = 0;
    _statsFrames = 0;
  }

  /// Uzak martı ve vapur düdüğü: bölgeye göre ara sıra (oyun saatine bağlı, duraklamada durur).
  void _updateAmbientCues(double dt) {
    _cueTimer -= dt;
    if (_cueTimer > 0) return;
    final z = dayCycle.zoneIndex;
    final roll = _ambientRandom.nextDouble();
    if (z >= 1 && z <= 3 && roll < 0.3) {
      services.audio.playCue(AmbientCue.ferryHorn);
    } else if (z <= 3) {
      services.audio.playCue(AmbientCue.gull); // gece (Rumeli) martılar uyur
    }
    _cueTimer = 7 + _ambientRandom.nextDouble() * 9;
  }

  /// Bir sabit fizik adımı (sadece PLAYING).
  void _stepPlaying(double dt) {
    if (autopilot) _autopilotStep();
    _runTime += dt;
    final speed = currentSpeed;
    final dx = speed * dt;
    scrollDistance += dx;
    physics.step(dt);

    for (final o in obstacles) {
      o.position.x -= dx;
    }
    _nextSpawnX -= dx;
    _spawnIfNeeded();
    _recycleOffscreen();

    // Önce çarpışma, sonra toplama ve puan: aynı adımda çarpan oyuncu puan/simit almaz.
    if (!debugInvincible && (_collides() || physics.hitsWater)) {
      _crash();
      return;
    }
    final bx = birdX;
    final r = config.birdHitRadius;
    final center = Offset(bx, physics.y);
    for (final o in obstacles) {
      // Simit toplama (her simit bir kez)
      final py = o.pickupY;
      if (py != null &&
          !o.pickupTaken &&
          PickupRules.touches(
            bird: center,
            birdRadius: r,
            pickup: Offset(o.pickupX, py),
            pickupRadius: config.pickupRadius,
          )) {
        o.pickupTaken = true;
        _collect(o.pickupX, py);
      }
      // Kıl payı: engelin yanındayken en küçük boşluğu izle
      if (!o.nearMissChecked && o.position.x - r <= bx && bx <= o.right + r) {
        final c = math.min(
          circleClearance(center, r, o.topRect),
          circleClearance(center, r, o.bottomRect),
        );
        if (c < o.minClearance) o.minClearance = c;
      }
      if (!o.scored && o.right < bx) {
        o.scored = true;
        _runObstacles++;
        _countInZone(
          obstacles: 1,
        ); // geçildiği bölgeye sayılır (bölge değişmeden önce)
        _addPoint();
        services.emit(ObstaclePassed(score.value));
      }
      // Kuş engelin tamamen ötesine geçince bir kez değerlendir
      if (!o.nearMissChecked && bx - r > o.right) {
        o.nearMissChecked = true;
        if (o.minClearance >= 0 && o.minClearance <= config.nearMissClearance) {
          _nearMiss();
        }
      }
    }
  }

  void _collect(double x, double y) {
    runSimits.value++;
    _countInZone(simits: 1);
    fx.collect(x, y);
    services.audio.playSfx(Sfx.collect);
    services.haptics.light();
    services.emit(SimitCollected(runSimits.value));
  }

  void _nearMiss() {
    nearMisses.value++;
    _countInZone(nearMisses: 1);
    fx.nearMiss(birdX, physics.y);
    services.audio.playSfx(Sfx.nearMiss);
    services.haptics.medium();
    services.emit(NearMissAchieved(nearMisses.value));
  }

  void _autopilotStep() {
    final bx = birdX;
    ObstaclePair? next;
    for (final o in obstacles) {
      if (o.right > bx - config.birdHitRadius) {
        next = o;
        break;
      }
    }
    final target = (next?.gapCenter ?? config.worldHeight * 0.45) + 30;
    if (physics.y > target && physics.velocity > -150) _flap();
  }

  void _spawnIfNeeded() {
    // Engel görünür alanın hemen sağında, ekrana girmeden önce üretilir
    while (_nextSpawnX <= visibleWidth + config.obstacleWidth + 40) {
      final gap = _gaps.next(score.value);
      final o = ObstaclePair(
        x: _nextSpawnX,
        gapCenter: gap.center,
        gapHeight: gap.height,
        width: config.obstacleWidth,
        worldHeight: config.worldHeight,
        kit: dayCycle.zone.kit,
        seed: _spawnCount++,
      );
      // İlk engelde simit yok: oyuncu önce kontrolü öğrensin
      if (o.seed > 0) {
        o.pickupY = PickupRules.place(
          config: config,
          gapCenter: gap.center,
          gapHeight: gap.height,
          random: _pickupRandom,
        );
      }
      obstacles.add(o);
      world.add(o);
      _nextSpawnX += config.obstacleSpacing;
    }
  }

  void _recycleOffscreen() {
    while (obstacles.isNotEmpty && obstacles.first.right < -60) {
      obstacles.removeAt(0).removeFromParent();
    }
  }

  bool _collides() {
    final center = Offset(birdX, physics.y);
    final r = config.birdHitRadius;
    for (final o in obstacles) {
      if (o.position.x > center.dx + r || o.right < center.dx - r) continue;
      if (circleIntersectsRect(center, r, o.topRect) ||
          circleIntersectsRect(center, r, o.bottomRect)) {
        return true;
      }
    }
    return false;
  }

  void _addPoint() {
    score.value++;
    if (!recordPassed.value &&
        best.value > 0 &&
        score.value == best.value + 1) {
      recordPassed.value = true;
    }
    if (dayCycle.updateScore(score.value)) {
      zoneIndex.value = dayCycle.zoneIndex;
      services.audio.playSfx(Sfx.zone);
      services.audio.setAmbience(ambienceForZone(dayCycle.zoneIndex));
      services.emit(ZoneReached(dayCycle.zoneIndex));
    }
  }

  void _crash() {
    _gameOverTime = 0;
    _landed = false;
    _cardShown = false;
    _hitStopT = config.hitStop;
    canRestart.value = false;
    bird.onHit();
    physics.velocity = math.min(
      physics.velocity,
      -420,
    ); // küçük sekme, sonra düşüş
    final s = score.value;
    if (s > best.value) {
      best.value = s;
      isNewRecord.value = true;
      unawaited(_saveBest(s));
    }
    // Uçuşun tek hesap noktası: ilerleme sistemi aynı runId'yi ikinci kez saymaz.
    services.emit(
      RunFinished(
        RunResult(
          runId: _runId,
          score: s,
          obstaclesPassed: _runObstacles,
          simits: runSimits.value,
          nearMisses: nearMisses.value,
          maxZone: zoneIndex.value,
          flightMs: (_runTime * 1000).round(),
          zoneStats: Map.unmodifiable(_zoneStats),
        ),
      ),
    );
    services.audio.stopMusic();
    services.audio.playSfx(Sfx.crash);
    services.haptics.heavy();
    if (!reduceMotion) {
      _shakeT = config.shakeTime;
      fx.flash();
    }
    _setPhase(GamePhase.gameOver);
  }

  Future<void> _saveBest(int s) async {
    try {
      await scores.saveBest(s);
    } catch (e) {
      debugPrint('En iyi skor kaydedilemedi: $e');
    }
  }

  /// GAME_OVER: engeller ve skor donmuş, kısa donmanın ardından Simit suya düşer, kartpostal açılır.
  void _updateGameOver(double dt) {
    _gameOverTime += dt;
    if (_hitStopT > 0) {
      _hitStopT -= dt;
      return;
    }
    final floor = config.worldHeight - config.birdHitRadius;
    if (physics.y < floor) {
      physics.step(dt);
      if (physics.y >= floor) physics.y = floor;
    }
    // Suya ilk değişte: sıçrama + oyun sonu tepkisi (simit başına geçer)
    if (!_landed && physics.y >= floor) {
      _landed = true;
      physics.velocity = 0;
      bird.onLanded();
      fx.splash(birdX, floor + 20);
      services.audio.playSfx(Sfx.splash);
    }
    if (_gameOverTime >= config.gameOverCardDelay && !_cardShown) {
      _cardShown = true;
      _showOverlay(Overlays.gameOver);
      services.audio.playMusic(MusicTrack.gameOver);
      if (isNewRecord.value) services.audio.playSfx(Sfx.record);
    }
    if (_gameOverTime >= config.gameOverCardDelay + config.restartLockTime) {
      canRestart.value = true;
    }
  }

  /// Çarpışma sarsıntısı: sadece kamera kayar, oyun dünyası ve hitbox'lar etkilenmez.
  void _updateShake(double dt) {
    if (_shakeT <= 0) return;
    _shakeT -= dt;
    if (_shakeT <= 0) {
      camera.viewfinder.position = Vector2.zero();
      return;
    }
    final k = _shakeT / config.shakeTime;
    final a = config.shakeAmplitude * k * k;
    camera.viewfinder.position = Vector2(
      math.sin(_time * 90) * a,
      math.cos(_time * 77) * a,
    );
  }

  void _syncBird({required bool idle}) {
    bird.sync(
      x: birdX,
      y: physics.y,
      velocity: physics.velocity,
      maxFall: config.maxFallSpeed,
      idle: idle,
    );
  }

  // ================= Durum geçişleri =================

  void pauseGame() {
    if (phase.value != GamePhase.playing) return;
    _setPhase(GamePhase.paused);
    services.audio.pauseAll();
    pauseEngine();
  }

  /// Devam: simülasyon birikmiş süreyi sıfırlar, Flame döngüsü ilk karede dt = 0 verir
  /// → beklenmeyen hızlanma ya da ani sıçrama olmaz.
  void resumeGame() {
    if (phase.value != GamePhase.paused) return;
    _accumulator = 0;
    _setPhase(GamePhase.playing);
    services.audio.resumeAll();
    resumeEngine();
  }

  /// Yeni tur: eski engeller, skor, palet ve karakter temizlenir. READY'e ("uçmak için dokun") dönülür.
  void restart() {
    for (final o in obstacles) {
      o.removeFromParent();
    }
    obstacles.clear();
    _gaps.reset();
    dayCycle.reset();
    score.value = 0;
    zoneIndex.value = 0;
    isNewRecord.value = false;
    canRestart.value = false;
    runSimits.value = 0;
    nearMisses.value = 0;
    recordPassed.value = false;
    physics.reset(readyY);
    bird.reset();
    _landmarks.reset();
    for (final l in _zoneLayers) {
      l.reset();
    }
    _ferry.reset();
    fx.clear();
    _landed = false;
    _cardShown = false;
    _hitStopT = 0;
    _shakeT = 0;
    camera.viewfinder.position = Vector2.zero();
    _accumulator = 0;
    if (paused) {
      resumeEngine();
      services.audio.resumeAll();
    }
    menuOpen.value = false;
    services.audio.setAmbience(ambienceForZone(0));
    _setPhase(GamePhase.ready);
    _applyCosmetic();
  }

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    super.lifecycleStateChange(state);
    if (state == AppLifecycleState.resumed) {
      // Duraklatılmış oyunda ses, oyuncu "Devam"a basınca açılır
      if (phase.value != GamePhase.paused) services.audio.resumeAll();
      return;
    }
    // Oyun sırasında arka plana alınırsa PAUSED'a geç. Geri dönüşte oyuncu "Devam"a basar.
    if (phase.value == GamePhase.playing) {
      pauseGame();
    } else {
      services.audio.pauseAll();
    }
  }

  void _setPhase(GamePhase p) {
    phase.value = p;
    _applyOverlays();
    _syncMusic();
  }

  /// Müzik: menü ve hazırlıkta menü teması, oyunda oyun müziği. Oyun sonu müziği kartpostalla başlar.
  void _syncMusic() {
    switch (phase.value) {
      case GamePhase.ready:
        services.audio.playMusic(MusicTrack.menu);
      case GamePhase.playing:
        services.audio.playMusic(MusicTrack.game);
      case GamePhase.paused:
      case GamePhase.gameOver:
        break;
    }
  }

  void _applyOverlays() {
    final wanted = switch (phase.value) {
      GamePhase.ready => {menuOpen.value ? Overlays.menu : Overlays.ready},
      GamePhase.playing => {Overlays.hud},
      GamePhase.paused => {Overlays.hud, Overlays.pause},
      GamePhase.gameOver => {if (_cardShown) Overlays.gameOver},
    };
    final m = modal.value;
    if (m != null) wanted.add(m);
    if (showStats) wanted.add(Overlays.stats);
    for (final name in overlays.activeOverlays.toList()) {
      if (!wanted.contains(name)) overlays.remove(name);
    }
    wanted.forEach(_showOverlay);
  }

  void _showOverlay(String name) {
    // Testlerde GameWidget yoktur; sadece kayıtlı overlay'ler açılır.
    if (overlays.registeredOverlays.contains(name) &&
        !overlays.isActive(name)) {
      overlays.add(name);
    }
  }
}
