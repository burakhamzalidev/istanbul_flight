# Martı: Istanbul Flight

İstanbul temalı, Flappy Bird benzeri mobil arcade oyun. Flutter + Flame. **Durum: oynanabilir MVP prototipi.**

## Çalıştırma

```bash
flutter pub get
flutter run -d chrome          # web (bu makinede çalışan hedef)
flutter run                    # bağlı Android/iOS cihaz (Android SDK / Xcode gerekir)
flutter test                   # tüm testler
flutter analyze
```

Geliştirme bayrakları (normal derlemede kapalı):

```bash
flutter run -d chrome --dart-define=MARTI_AUTOPILOT=true   # Simit kendi uçar
flutter run -d chrome --dart-define=MARTI_DEMO=true        # otomatik pilot + çarpışma kapalı: 5 bölgeyi gezer
                                                           # web demoda ?zone=0..4 turu o bölgeden başlatır; &card=1 Simit'i düşürüp kartpostalı gösterir
flutter run -d chrome --dart-define=MARTI_STATS=true       # FPS ve nesne sayısı
```

## Yapı

```
lib/
  main.dart                      Uygulama girişi, dikey kilit, GameWidget + overlay eşlemesi
  data/score_repository.dart     En iyi skor (SharedPreferences) + bellek içi sürüm
  services/                      Ses (audioplayers), titreşim, paylaşım (share_plus), kalıcı ayarlar, ilerleme
  game/
    config.dart                  Tüm ayarlanabilir değerler (fizik, hız, geçit, zamanlamalar)
    game_phase.dart              READY / PLAYING / PAUSED / GAME_OVER
    istanbul_flight_game.dart    Durum makinesi + sabit adımlı simülasyon, üretim, çarpışma, puan
    day_cycle.dart               5 bölge, faz paletleri, yumuşak palet geçişi
    game_art.dart                Pixel art asset yükleme, 1 px = 4 dünya birimi (eksikse yedek çizim)
    game_services.dart           Oyunun kullandığı servis paketi (testlerde sahteleri verilir)
    logic/                       Flame'den bağımsız saf mantık: fizik, çarpışma, geçit üretici
    visual/                      Saf görsel mantık: crossfade, Simit animatörü, engel sprite yerleşimi (+ üretilmiş kit yerleşimi)
    components/                  Katmanlar: gök, bulut, uzak silüet, kıyı, su, simge, sis, efektler, engel, Simit
  ui/                            Ana menü, HUD, duraklatma, ayarlar, nasıl oynanır, kartpostal (overlay) + ortak düğmeler
  ui/pixel.dart                  Pixel arayüz parçaları: basamaklı çerçeve, ikon atlası, anahtar, kaydırıcı
assets/images/pixel_art/         Pixel art set: backgrounds/<bölge>, landmarks, characters, obstacles, effects, ui
assets/fonts/MartiPixel.ttf      Özgün bitmap font (Türkçe karakterli)
assets/audio/                    Özgün, prosedürel sentez sesler (art/_source/build_audio.js ile üretilir)
art/                             Konsept görseller, karakter sayfası, palet, prompt'lar, kaynak betikler
docs/                            01 konsept · 02 görsel · 03 Simit · 04 MVP · 05 görsel entegrasyon · 06 UI/UX, ses, oyun hissi · 08 pixel art · 09 Galata · 10 Kız Kulesi · 11 Haliç · 12 Köprü · 13 Rumeli Hisarı · 14 engeller (gerçek referans) · 10 Android/iOS yayın hazırlığı
```

Ayrıntılar: [docs/04_mvp_teknik.md](docs/04_mvp_teknik.md) · görsel sistem: [docs/05_visual_integration.md](docs/05_visual_integration.md) · arayüz ve ses: [docs/06_ui_ux_audio_gamefeel.md](docs/06_ui_ux_audio_gamefeel.md)

Pixel art seti ve fontu yeniden üretmek için: `node art/_source/pixel/build_all.js assets/images/pixel_art` (önizleme: `node art/_source/pixel/preview.js assets/images/pixel_art art/pixel_preview`). Ayrıntılar: [docs/08_premium_pixel_art.md](docs/08_premium_pixel_art.md)

Sesleri yeniden üretmek için: `node art/_source/build_audio.js assets/audio`

## Yayın

Yayın hazırlığı: [docs/10_android_ios_release_readiness.md](docs/10_android_ios_release_readiness.md) · kontrol listesi: [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) · CI: [codemagic.yaml](codemagic.yaml) · mağaza materyalleri: [docs/store/](docs/store/store_listing.md)

iOS TestFlight beta: [docs/11_ios_testflight_beta.md](docs/11_ios_testflight_beta.md) · kontrol listesi: [IOS_TESTFLIGHT_CHECKLIST.md](IOS_TESTFLIGHT_CHECKLIST.md) · beta metinleri: [docs/testflight/](docs/testflight/beta_materials.md)

Uygulama ikonları ve açılış görselleri: `node art/_source/pixel/app_icons.js`

Phase 2.1 (oyuncu ilerlemesi, görevler, başarımlar): [docs/12_phase2_player_progression.md](docs/12_phase2_player_progression.md) · beta 1.1.0: [docs/testflight/beta_1_1_0.md](docs/testflight/beta_1_1_0.md)

Phase 2.2 (Simit Mağazası, görünümler): [docs/13_phase2_cosmetics_shop.md](docs/13_phase2_cosmetics_shop.md) · beta 1.2.0: [docs/testflight/beta_1_2_0.md](docs/testflight/beta_1_2_0.md)

Phase 3 (App Store yayını): [docs/14_app_store_launch.md](docs/14_app_store_launch.md) · kontrol listesi: [APP_STORE_RELEASE_CHECKLIST.md](APP_STORE_RELEASE_CHECKLIST.md) · gizlilik: https://burakhamzalidev.github.io/istanbul_flight/privacy.html · destek: https://burakhamzalidev.github.io/istanbul_flight/support.html

Phase 2.3 (İstanbul Keşif Albümü, `feature/phase2-3-istanbul-discovery`): [docs/15_phase2_3_istanbul_discovery.md](docs/15_phase2_3_istanbul_discovery.md) · beta 1.3.0 (hazır, yüklenmedi): [docs/testflight/beta_1_3_0.md](docs/testflight/beta_1_3_0.md)

Phase 2.4 (Game Center, `feature/phase2-4-game-center`): [docs/16_phase2_4_game_center.md](docs/16_phase2_4_game_center.md)
