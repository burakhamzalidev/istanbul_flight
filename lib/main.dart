import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/score_repository.dart';
import 'game/game_services.dart';
import 'game/day_cycle.dart';
import 'game/istanbul_flight_game.dart';
import 'services/audio_service.dart';
import 'services/haptics_service.dart';
import 'services/progress.dart';
import 'services/settings.dart';
import 'services/share_service.dart';
import 'ui/overlays/hud_overlay.dart';
import 'ui/overlays/menu_overlays.dart';
import 'ui/overlays/postcard_overlay.dart';
import 'ui/overlays/progression_overlays.dart';
import 'ui/pixel.dart';
import 'ui/simit_frame_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Kenardan kenara: saydam sistem çubukları, açık ikonlar (gök ve deniz koyu tonlarda)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0x00000000),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  // Ses oturumu: sessiz moda uy, kullanıcının müziğini kesme (oyunlar için önerilen davranış)
  await configureAudioSession();

  // Kalıcı kayıtlar: en iyi skor (best_score_v1, önceki sürümlerle aynı anahtar),
  // ayarlar (settings_v1), ilerleme (progress_v2; ilk açılışta progress_v1'den geçilir, v1 silinmez).
  // Erişilemezse bellek içi sürüme düşülür.
  ScoreRepository scores;
  SettingsRepository settingsRepo;
  ProgressRepository progressRepo;
  try {
    final prefs = await SharedPreferences.getInstance();
    scores = SharedPrefsScoreRepository(prefs);
    settingsRepo = SharedPrefsSettingsRepository(prefs);
    progressRepo = SharedPrefsProgressRepository(prefs);
  } catch (e) {
    debugPrint('Kalıcı kayıt açılamadı, bellek içi kayıt kullanılıyor: $e');
    scores = InMemoryScoreRepository();
    settingsRepo = InMemorySettingsRepository();
    progressRepo = InMemoryProgressRepository();
  }
  await PixelIcons.load();
  final settings = await settingsRepo.load();
  final progress = await progressRepo.load();

  final audio = AudioplayersAudioService();
  unawaited(
    audio.init(),
  ); // ses havuzları arka planda hazırlanır; açılışı bekletmez

  final services = GameServices(
    audio: audio,
    haptics: PlatformHaptics(),
    settings: SettingsController(settingsRepo, settings),
    progress: ProgressController(progressRepo, progress),
    share: PlatformShareService(),
  );
  services.progress.refreshDay(); // günlük görevler (gün değiştiyse yenilenir)

  // Geliştirme bayrakları (normal derlemede kapalı):
  //   MARTI_AUTOPILOT=true  → Simit kendi uçar
  //   MARTI_DEMO=true       → otomatik pilot + çarpışma kapalı (tüm bölgeleri görmek için)
  //   MARTI_STATS=true      → FPS ve nesne sayısı
  // Web demoda: ?zone=n turu o bölgeden başlatır; &card=1 otomatik pilotu ve korumayı kapatır
  // (Simit düşer → o bölgenin kartpostalı görülür); &play=1 menüyü atlayıp turu başlatır.
  const demo = bool.fromEnvironment('MARTI_DEMO');
  final card = demo && Uri.base.queryParameters['card'] == '1';
  final game = IstanbulFlightGame(scores: scores, services: services)
    ..autopilot =
        (demo && !card) || const bool.fromEnvironment('MARTI_AUTOPILOT')
    ..debugInvincible = demo && !card
    ..debugStartScore = demo
        ? zones[(int.tryParse(Uri.base.queryParameters['zone'] ?? '') ?? 0)
                  .clamp(0, zones.length - 1)]
              .startScore
        : 0
    ..debugAutoStart = demo && Uri.base.queryParameters['play'] == '1'
    ..showStats = const bool.fromEnvironment('MARTI_STATS');
  runApp(MartiApp(game: game));
}

class MartiApp extends StatelessWidget {
  const MartiApp({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Martı: Istanbul Flight',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1F3A5F),
        // Özgün bitmap font (docs/08): Türkçe karakterli; tek ağırlık, sahte kalınlık yok
        fontFamily: 'MartiPixel',
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF0E1433),
        // Web: tarayıcı, ilk kullanıcı etkileşimine kadar sesi engeller → ilk dokunuşta sesi aç
        // Android geri tuşu: bir seviye geri (duraklat / menü); sadece ana menüdeyken uygulamadan çıkar
        body: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (!game.handleBack()) SystemNavigator.pop();
          },
          child: Listener(
            onPointerDown: (_) => game.services.audio.unlock(),
            child: GameScreen(game: game),
          ),
        ),
      ),
    );
  }
}

/// Oyun alanı. Geniş ekranlarda (web/tablet yatay) oyun dikey bir sütunda ortalanır.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key, required this.game});

  final IstanbulFlightGame game;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, c) {
          final maxW = c.maxHeight * 0.75; // 3:4'ten geniş olmasın
          return SizedBox(
            width: c.maxWidth > maxW ? maxW : c.maxWidth,
            height: c.maxHeight,
            child: ClipRect(
              child: GameWidget<IstanbulFlightGame>(
                game: game,
                overlayBuilderMap: {
                  Overlays.menu: (_, g) => MainMenuOverlay(game: g),
                  Overlays.ready: (_, g) => ReadyOverlay(game: g),
                  Overlays.hud: (_, g) => HudOverlay(game: g),
                  Overlays.pause: (_, g) => PauseOverlay(game: g),
                  Overlays.gameOver: (_, g) => GameOverOverlay(game: g),
                  Overlays.settings: (_, g) => SettingsOverlay(game: g),
                  Overlays.howTo: (_, g) => HowToOverlay(game: g),
                  Overlays.stats: (_, g) => StatsOverlay(game: g),
                  Overlays.profile: (_, g) => ProfileOverlay(game: g),
                  Overlays.missions: (_, g) => MissionsOverlay(game: g),
                  Overlays.achievements: (_, g) => AchievementsOverlay(game: g),
                },
                initialActiveOverlays: const [Overlays.menu],
              ),
            ),
          );
        },
      ),
    );
  }
}
