# 06 · UI/UX, Ses Tasarımı ve Oyun Hissi

> Martı: Istanbul Flight · Aşama 5 · 21 Ekim 2026
> Önceki: [05_visual_integration.md](05_visual_integration.md)

## Özet

Bu aşamada oyuna şunlar eklendi: ana menü, duraklatma menüsü (geri sayımlı devam), ayarlar, nasıl oynanır, yeniden tasarlanan HUD, profesyonel kartpostal ve gerçek paylaşım, toplanabilir simit, kıl payı bonusu, ses sistemi (efekt, ortam ve müzik), titreşim, kalıcı ayarlar ve game feel efektleri.

- Fizik, engel geometrisi ve durum makinesi korundu.
- Önceki 62 testin 54'ü hiç değiştirilmeden geçiyor. Yeni ana menü akışını yansıtmak için 8 arayüz testinde küçük değişiklik yapıldı (bkz. §Testler).

---

## Yeni ekranlar ve akış

```
Açılış → ANA MENÜ ──"UÇMAYA BAŞLA"──▶ UÇMAK İÇİN DOKUN ──dokun──▶ OYUN (HUD)
  │  ├─ Ses aç/kapat (hızlı)                                      │   └─ ⏸ → DURAKLATMA
  │  ├─ Ayarlar (modal)                                           │        ├─ Devam et → 3-2-1 → OYUN
  │  └─ Nasıl oynanır (modal)                                     │        ├─ Yeniden başlat → UÇMAK İÇİN DOKUN
  │                                                               │        ├─ Ana menü → ANA MENÜ
  │                                                               │        └─ Müzik / Efekt düzeyleri
  └────────────────────────────── ANA MENÜ ◀── KARTPOSTAL ◀── çarpışma
                                    TEKRAR UÇ → UÇMAK İÇİN DOKUN · PAYLAŞ → paylaşım / indirme
```

**Mimari not:** `GamePhase.ready`, iki arayüz moduyla kullanılıyor. Ana menü (`menuOpen = true`) ve "uçmak için dokun" ekranı, oyun mantığı açısından aynı durum: Simit süzülüyor, engel yok. Böylece durum makinesine yeni bir durum eklenmedi. Menü tam ekran dokunuşu tutuyor, sadece kendi düğmeleri çalışıyor.

| Ekran | Dosya | Öne çıkanlar |
|---|---|---|
| Ana menü | `ui/overlays/menu_overlays.dart` → `MainMenuOverlay` | Canlı sahne (süzülen Simit, akan şehir, bulut, su), hafifçe süzülen logo pulu, rekor ("Rekor: Kız Kulesi · 37"), toplam simit, 72 dp "UÇMAYA BAŞLA", Ses / Ayarlar / Nasıl oynanır |
| Uçmak için dokun | `ReadyOverlay` | Dokunma ikonu, nabız gibi atan yazı, tek satırlık ipucu; dokunuşları oyuna geçirir |
| HUD | `ui/overlays/hud_overlay.dart` | Sol üstte 52 dp duraklat, ortada skor (artışta büyür), sağ üstte simit sayacı (artışta büyür), rota çubuğu, bölge damgası, "KIL PAYI!", "REKOR GEÇİLDİ!" rozeti |
| Duraklatma | `PauseOverlay` | Devam et (3-2-1), Yeniden başlat, Ana menü, Müzik ve Efektler kaydırıcıları |
| Ayarlar | `SettingsOverlay` | Müzik, Efektler, Tüm sesi kapat, Titreşim, Animasyonları azalt |
| Nasıl oynanır | `HowToOverlay` | Dokun / Geç / Topla / Kıl payı / Gün ilerler. Can simidi ile altın simit farkı açıkça yazıyor |
| Kartpostal | `ui/overlays/postcard_overlay.dart` | Bölge illüstrasyonu, pul, selam, sersem Simit, ulaşılan bölge (n/5), Skor / Rekor / Simit, kıl payı sayısı, YENİ REKOR damgası ve susam konfetisi, TEKRAR UÇ / PAYLAŞ / ANA MENÜ |

## UI bileşenleri

- **`Pressable`:** Basınca 0,94 ölçeğe küçülür, buton sesi ve hafif titreşim verir. Animasyonları azalt açıkken ölçeklenmez. Semantik etiket taşır.
- **`MartiButton`** (birincil, ikincil, şeffaf):
  - En az 56 dp, birincil 68–72 dp.
  - Etiket Türkçe büyük harfle yazılır (`trUpper`: UÇMAYA BAŞLA, TEKRAR UÇ, PAYLAŞ).
  - Dar ekranda etiket kesilmez, sığacak kadar küçülür. Tarayıcı kontrolünde 375 px'te "ANA ME…" kesilmesi bulundu ve düzeltildi.
- **`RoundIconButton`:** 60 dp daire ve etiket.
- **`SimitIcon`**, **`Bump`** (değer artışı), **`EventPopup`** (KIL PAYI!), **`OneShotFade`**, **`LogoStamp`**, **`InfoChip`**.
- **`ZonePostcardPainter`:** Kartpostal ön yüzü. Oyundaki faz paleti, simge maskesi (`LandmarkLayer.layout` ile aynı odak noktası) ve su yansımasıyla çizilir.
- **Renk ve kontrast:** Ana aksiyon rengi `#B84A26` (kiremidin koyusu), beyaz yazıyla yaklaşık 5,2:1 (WCAG AA). Sahne üstündeki yazılarda koyu gölge (`kSceneTextShadow`), rozetlerde yarı saydam lacivert zemin (`UiColors.scrim`) var.

## Ses mimarisi

**Kaynak ve lisans:** Lisanslı bir ses kütüphanesine ya da ses üretim aracına erişim yok, internetten lisansı belirsiz ses **indirilmedi**. Bütün sesler `art/_source/build_audio.js` ile **prosedürel olarak sentezlendi**: osilatörler, filtrelenmiş gürültü, Karplus-Strong telli çalgı sentezi ve basit yankı. Hepsi bu projeye ait özgün dosyalar, telif sorunu yok.

| Kategori | Dosya | İçerik |
|---|---|---|
| Efekt | `sfx_flap` | Yumuşak kanat "fıs"ı (süpürülen filtreli gürültü) |
| | `sfx_collect` | İki notalı parlak çan |
| | `sfx_near_miss` | Yükselen rüzgâr ve yüksek tel teli |
| | `sfx_crash` | Perdesi düşen tok darbe |
| | `sfx_splash` | Su sıçraması ve kabarcıklar |
| | `sfx_button` | Yumuşak tık |
| | `sfx_zone` | İki tel notası (bölgeye giriş) |
| | `sfx_record` | Hicaz arpeji (yeni rekor) |
| Ortam | `amb_waves`, `amb_wind` | 8 sn dikişsiz döngüler |
| | `amb_gull` | Martı çığlığı |
| | `amb_ferry_horn` | Uzak vapur düdüğü |
| Müzik | `music_menu` | 84 bpm, Hicaz makamı, kanun benzeri tel, darbuka ritmi (düm-tek), döngü |
| | `music_game` | 112 bpm, seyrek ve alçak melodi (efektleri bastırmaz), döngü |
| | `music_gameover` | İnen kısa ezgi |

Toplam yaklaşık 2,9 MB (22,05 kHz mono 16-bit WAV). Hiçbir dosyada kırpılma yok. Döngü dikişleri sayısal olarak doğrulandı: döngü sonu ile başı arasındaki fark, dosyanın içindeki tipik örnek adımından küçük.

**Dürüst sınır:** Sesler **kulakla değerlendirilmedi** (bu ortamda dinleyemiyorum). Sentetik oldukları için gerçek kayıt kalitesinde değiller; özellikle martı sesi belirgin biçimde sentetik olabilir. Final için lisanslı kayıt ya da bir ses tasarımcısı önerilir. Dosya adları ve düzeyler aynı kalırsa kod değişmeden yerleri değiştirilebilir.

**Servis** (`services/audio_service.dart`):
- `AudioService` arayüzünün iki uygulaması var: `AudioplayersAudioService` (gerçek) ve `SilentAudioService`.
- **Efektler:** düşük gecikmeli `AudioPool` ile çalınıyor (kanat 4 ses, diğerleri 1–2).
- **Kanallar:** müzik, ortam döngüsü ve ara sıra çalan uzak sesler için ayrı oynatıcılar var.
- **Karışım dengesi:** Her sesin ayrı kazancı var (`Sfx.gain`); oyun müziği menü müziğinden daha kısık. Çarpışmada müzik durur, kartpostalla oyun sonu ezgisi gelir. `duck()` ile müzik geçici olarak kısılabiliyor.
- **Bölge ortamı:** İlk üç bölgede liman dalgası, Boğaz'da rüzgâr. Uzak martı ve vapur düdüğü 7–16 sn aralıklarla, oyun saatine bağlı çalıyor. Duraklatmada durur, gece bölgesinde martı yok.
- **Durum geçişleri:** Duraklatma ve uygulamanın arka plana alınması sesleri duraklatır, geri dönüş devam ettirir.
- **Web:** Tarayıcı, ilk kullanıcı etkileşimine kadar sesi engelliyor. Uygulama kökündeki `Listener` ilk dokunuşta `unlock()` çağırıyor.
- **Hata dayanıklılığı:** Her ses çağrısı hata yakalar; ses çalınamazsa oyun etkilenmez.
- **Tarayıcıda doğrulanan:** Bütün ses dosyaları 200 ile yüklendi, konsolda hata yok. Sesin gerçekten duyulduğu doğrulanamadı.

## Titreşim

`services/haptics_service.dart` → `PlatformHaptics`

| Olay | Şiddet |
|---|---|
| Simit toplama, buton | Hafif |
| Kıl payı | Orta |
| Çarpışma | Ağır |
| Kanat çırpma | Yok (sürekli titreşim rahatsız eder) |

- Web'de `supported = false`: hiç çağrı yapılmıyor.
- Platform hatası yakalanıyor (`failures` sayacı), oyun durmuyor.
- Ayarlardan kapatılabiliyor.

## Toplanabilir simit

- **Konum:**
  - Engel çiftinin geçidinin ortasında (yatayda engelin ortası).
  - Dikeyde güvenli bandın orta %70'i: `[geçit üstü + kuş yarıçapı + 16, geçit altı − kuş yarıçapı − 16]`.
  - Kuş simidin tam merkezindeyken bile engele değmiyor, yani simit **her zaman çarpışmadan toplanabilir.**
- **Sıklık:** Engellerin %45'inde. İlk engelde yok, oyuncu önce kontrolü öğreniyor. Ayrı bir rastgele sayı üreteci kullanılıyor, geçit dizisi önceki aşamalarla aynı.
- **Toplama:** Kuş dairesi ile simit dairesi temas edince (yarıçap 30, görselle aynı). Her simit bir kez sayılıyor (`pickupTaken`). Simülasyonda sıra: çarpışma → toplama → puan; aynı adımda çarpan oyuncu simit almaz.
- **Geri bildirim:** Altın halka patlaması, 6 susam parıltısı (azaltılmış harekette 3), çan sesi, hafif titreşim, HUD sayacı büyür.
- **Görsel ayrım:**
  - Toplanabilir simit: altın-kahve, susamlı, sıcak parıltı halesi, nefes alır gibi salınım, dönme hissi, açık gökyüzünde.
  - Can simidi: kırmızı-beyaz, koyu ahşap kazığa sabit, hareketsiz, sadece iskele engelinde.
  - Tarayıcıda gün batımı bölgesinde yan yana kontrol edildi.
- **Veri:**
  - Tur simidi ana skordan ayrı tutuluyor (`runSimits`).
  - Oyun sonunda `PlayerProgress.totalSimits`'e ekleniyor (`progress_v1`).
  - Gelecek kozmetik sistemi için `unlockedCosmetics` ve `selectedCosmetic` alanları var. Mağaza veya ekonomi **kurulmadı**.

## Kıl payı algılama

- Kuş bir engelin yatay aralığındayken her fizik adımında, kuş dairesinin kenarı ile üst ve alt engel dikdörtgenleri arasındaki en küçük boşluk ölçülüyor (`circleClearance`).
- Kuş engelin tamamen ötesine geçtiği anda (`kuş x − r > engel sağı`) **bir kez** değerlendiriliyor (`nearMissChecked`).
- **Koşul:** `0 ≤ en küçük boşluk ≤ 18 birim`. Çarpışma sayılmıyor (negatif boşluk).
- **Geri bildirim:** "KIL PAYI!" vurgusu (0,8 sn), beyaz halka, rüzgâr ve tel sesi, orta titreşim. Kartpostalda "Kıl payı geçiş: n" olarak görünüyor. Ana skor değişmiyor.
- Sabit fizik adımı sayesinde kare hızından bağımsız. Testte 30 ve 60 fps aynı sonucu veriyor.

## Paylaşım

- Kartpostal bir `RepaintBoundary` içinde; **1080 px genişliğinde gerçek bir PNG** üretiliyor (`captureBoundaryPng`).
- `share_plus` ile görsel ve Türkçe metin paylaşılıyor ("…Kız Kulesi bölgesine kadar uçtum! Skor: 42 · Simit: 5").

| Durum | Sonuç | Kullanıcıya mesaj |
|---|---|---|
| Mobil, paylaşım menüsü | `shared` | "Kartpostal paylaşıldı." |
| Web, Web Share API yok | Yerleşik indirme yedeği → `downloaded` | "Bu tarayıcı paylaşımı desteklemiyor; kartpostal indirildi." |
| Kullanıcı kapattı | `dismissed` | Mesaj yok |
| Hata veya görsel üretilemedi | `failed` | "Kartpostal paylaşılamadı. Lütfen tekrar deneyin." |

Tarayıcıda Paylaş düğmesine **basılmadı**: web'de bu, dosya indirmeyi tetikleyebilir. Akış widget testinde gerçek PNG üretimiyle doğrulandı (PNG imzası, boyut 10 KB'tan büyük, metin, üç sonucun mesajları).

## Kalıcı ayarlar ve veri güvenliği

| Anahtar | İçerik | Not |
|---|---|---|
| `best_score_v1` | En iyi skor | **Değişmedi**, eski rekorlar korunuyor (testli) |
| `settings_v1` | Müzik ve efekt düzeyi (0..1), sessiz, titreşim, animasyonları azalt | JSON |
| `progress_v1` | Toplam simit, en iyi tur simidi, kozmetik yer tutucuları | JSON |

- Bozuk JSON ya da aralık dışı değerler varsayılana düşüyor veya sınırlanıyor.
- Kayıt hataları oyunu durdurmuyor, ayar değişikliği hemen uygulanıyor.
- Hepsi tek bir `SharedPreferences` örneğiyle açılıyor; erişilemezse bellek içi kayda düşülüyor.

## Oyun hissi

| Alan | Uygulama |
|---|---|
| Kanat çırpma | 6 karelik vuruş, ara sıra kopan tüy, yumuşak ses |
| Çarpışma | 80 ms donma, kamera sarsıntısı (0,28 sn, sönen; hitbox'lar etkilenmez), 0,15 sn beyaz flaş, tok ses, ağır titreşim |
| Skor artışı | Skor rakamı 1,18 ölçekten 220 ms'de oturur |
| Simit | Halka patlaması, susamlar, sayaç büyümesi |
| Yeni rekor | Oyun içinde bir kez "REKOR GEÇİLDİ!"; kartpostalda YENİ REKOR damgası, susam konfetisi, Hicaz arpeji |
| Bölgeye giriş | Mürekkep damgası (Türkçe büyük harf), iki notalı tel, ortam değişimi |
| Butonlar | Basınca küçülme, tık sesi, hafif titreşim |
| Menü geçişleri | Kartpostal aşağıdan kayarak gelir; geri sayım büyük rakamlarla |
| Devam | 3-2-1 (3 × 0,45 sn); sayım bitene kadar simülasyon durur, dönüşte birikmiş süre sıfırlanır → sıçrama ve ani çarpışma olmaz |

Animasyonların hepsi kısa (≤ 0,8 sn, kartpostal girişi 0,42 sn) ve hiçbiri girdiyi engellemiyor.

## Erişilebilirlik ve kullanılabilirlik

- **Türkçe karakterler:** Bütün etiketlerde doğru (`trUpper` ile İ/I kuralı uygulanıyor, testli).
- **Dokunma hedefleri:** En az 52 dp (duraklat), menü ve aksiyon düğmeleri 56–72 dp.
- **Güvenli alan:** Bütün overlay'lerde `SafeArea` var. HUD sadece üst bölgede; alt üçte birde öğe yok.
- **Küçük ekran:** Menü, ayarlar, nasıl oynanır, duraklatma ve kartpostal 320×568 ve 360×640'ta widget testiyle taşmasız. Modal kartlarda başlık ve "Tamam" sabit, içerik kayıyor.
- **Ses kapalıyken:** Her ses olayının görsel karşılığı var (sayaç, KIL PAYI!, damga, flaş, rozet).
- **Animasyonları azalt:** Sarsıntı, flaş, konfeti, buton ve skor büyümesi kapanıyor; parıltılar azalıyor; logo sabit kalıyor.
- **Ekran okuyucu:** Düğmelerde semantik etiketler var. Flutter web, erişilebilirlik ağacını ancak ekran okuyucu istediğinde açıyor; ekran okuyucuyla gerçek cihazda **test edilmedi**.

## Önceki aşamadan kalan beyaz alan sorunu: araştırma sonucu

Varsayım yapılmadan ölçüldü (Chrome, panelde 768×1024 emülasyonu):

1. Flutter görünümü ve canvas tam 768×1024 CSS piksel, arka tampon 848×1131 (= CSS × dpr 1,104). Doğru.
2. Sayfanın **sağ alt köşesine Flutter dışı bir HTML öğesi** (kırmızı kare), sol üstüne de bir yeşil kare kondu. Ekran görüntüsünde kırmızı kare de Flutter içeriğinin sağ alt köşesinde, yani yakalanan alanın ortasında çıktı.
3. Bu, sadece oyunun değil **sayfanın tamamının** yakalama yüzeyinin sol üst kısmına küçültüldüğünü gösteriyor.
4. Panele sığan 390×844'te iki işaretçi de doğru köşelerde.

**Sonuç:** Beyaz alan, panelden büyük emülasyonlarda önizleme panelinin ekran görüntüsü artefaktı; Flutter ya da oyunda bir hata değil. Headless Edge ile bağımsız ekran görüntüsü denendi, WebGL sayfasında zaman aşımına uğradı. Bu yüzden **gerçek bir tablette doğrulama** hâlâ önerilir.

## Testler

| Komut | Sonuç |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **95/95 geçti** |
| `flutter build web --release` | Başarılı |

İstenen 15 senaryonun karşılıkları:

| # | Senaryo | Test |
|---|---|---|
| 1 | Ana menüden oyuna giriş | `experience_ui_test`: menü kimliği, arka plan dokunuşu başlatmaz, UÇMAYA BAŞLA → dokun → oyun; `experience_game_test`: müzik geçişleri |
| 2 | Duraklatma ve devam | `experience_game_test`: duraklamada durur, dönüşte sıçrama yok; `experience_ui_test`: 3-2-1 sırasında oyun durur |
| 3 | Duraklatmadan yeniden başlatma | Oyun ve arayüz testleri |
| 4 | Oyun sonu ve kartpostal | `experience_ui_test`: bölge, skor, rekor, simit, düğmeler, ana menüye dönüş |
| 5 | Rekor kaydı | `experience_game_test` + mevcut `game_test` |
| 6 | Simit toplama | Sayaç, ses, titreşim |
| 7 | Aynı simit iki kez toplanmaz | Aynı test |
| 8 | Ulaşılamayan simit yok | 5000 geçit + 60 sn gerçek oyun |
| 9 | Kıl payı | Yakın geçiş bir kez tetiklenir; rahat geçiş ve çarpışma tetiklemez |
| 10 | Ses ayarları korunur | `services_test` + `experience_ui_test` (kaydırıcı, anahtarlar, sessiz) |
| 11 | Titreşim desteklenmeyen platformda | `services_test`: web'de çağrı yok, platform hatası yakalanır |
| 12 | Paylaşım | `services_test`: sonuçlar; `experience_ui_test`: gerçek PNG ve mesajlar |
| 13 | Farklı ekran boyutları | `widget_flow_test` (6 boyut) + `experience_ui_test` (320×568, 360×640) |
| 14 | Bölge geçişleri | Mevcut testler + bölge sesi ve ortam değişimi |
| 15 | FPS bağımsızlığı | Mevcut testler + 30/60 fps'te aynı skor, simit ve kıl payı |

**Mevcut testlerde yapılan değişiklikler:** `widget_flow_test.dart` içindeki 8 test, oyun artık ana menüyle açıldığı için önce "UÇMAYA BAŞLA"ya basıyor. Duraklatma testi ayrıca 3-2-1 geri sayımını bekliyor. Bu testlerin kontrol ettiği şeyler (akış, taşma, oyun alanı ölçüleri) değişmedi. Diğer 54 eski test hiç değiştirilmedi.

**Testlerin yakaladığı gerçek hatalar:**
1. 320 px'te kartpostal düğmelerinde 32 px taşma.
2. Duraklatma düğmelerinde aynı risk.
3. Ayarlar kartında Material olmayan zeminde `SwitchListTile` hatası.
4. Küçük ekranda "Tamam" düğmesinin ekran dışında kalması.

Tarayıcıda ayrıca 375 px'te düğme etiketinin kesildiği görüldü. Hepsi düzeltildi.

**Tarayıcıda gerçek akış** (Chrome, 375×812 ve 360×640): menü → dokun → oyun → duraklat → 3-2-1 → çarpışma → kartpostal; ayarlar ve nasıl oynanır. Demo derlemesinde 36 puanda 15 simit toplandı, "REKOR GEÇİLDİ!" rozeti göründü, beş bölge boyunca **60 FPS** ve 12–13 bileşen ölçüldü (masaüstü GPU).

## Bilinen sorunlar

1. Sesler sentetik ve kulakla değerlendirilmedi; gerçek kayıt kalitesinde değil.
2. Ses formatı WAV (yaklaşık 2,9 MB). Bu ortamda OGG/AAC kodlayıcı olmadığı için sıkıştırılmadı.
3. Web'de ilk dokunuştan önce menü müziği çalmıyor (tarayıcı politikası). İlk dokunuşta başlıyor.
4. Fontlar hâlâ sistem fontu (Baloo 2 / Caveat / Nunito eklenmedi).
5. Paylaşım ve indirme gerçek tarayıcıda ve gerçek cihazda tetiklenmedi, yalnızca testle doğrulandı.
6. Kozmetik veri yapısı var, ama görünüm açma arayüzü yok (bilinçli olarak).

## Mobil cihazda doğrulanması gerekenler

- [ ] Ses gecikmesi (`AudioPool`, özellikle Android'de düşük gecikme modu), müzik döngü dikişi, kulaklık ve hoparlör seviyesi, sessiz mod anahtarı (iOS)
- [ ] Arka plana alınınca ses ve oyunun duraklaması, gelen arama ya da bildirim kesintisi
- [ ] Titreşim şiddetlerinin cihazlarda hissedilir ama rahatsız etmeyen düzeyde olması
- [ ] Paylaşım menüsü (Android ve iOS): PNG ekinin WhatsApp ve Instagram'da görünmesi
- [ ] Çentikli ve Dynamic Island'lı ekranlarda HUD güvenli alanı
- [ ] Orta segment Android'de FPS ve bellek (WAV ses havuzlarının bellek etkisi)
- [ ] TalkBack ve VoiceOver ile menü gezintisi
- [ ] Gerçek tablette yerleşim (önizleme artefaktından bağımsız)
