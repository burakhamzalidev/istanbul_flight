# Phase 3.0 kalite denetimi matrisi

> **Kod:** `feature/phase3-0-premium-release`, `main` `56898e5` üzerine. **Aday derleme:** TestFlight 1.8.0 (11).
> **Sütunlar:** "Otomatik" = `flutter test` (489/489, 11 Kasım 2026). "Web" = Flutter web derlemesinde benim baktıklarım (başsız Edge; iPhone 402×874 ve iPad 1024×1366, ayrıca iPad yatay). "iPhone" = gerçek cihaz.
> **Gerçek cihaz testi (11 Kasım 2026):** Apple hesap sorunu (talep 103007198858) çözüldü; 1.8.0 (11) TestFlight'tan iPhone'a kuruldu. "iPhone" sütunundaki **PASS** sonuçları kullanıcının kendi iPhone'unda yaptığı ve bildirdiği testlerdir (aşağıdaki plan, 2–10. maddeler). Yapılmayanlar **NOT RUN** olarak kaldı. Simülatör yok (Windows).

## Önem dereceleri

P0 veri kaybı, açılış hatası, kritik çökme · P1 temel oyunu ya da satın alınmış görünümü etkileyen hata · P2 kullanılabilirlik ve görsel kalite · P3 küçük kozmetik iyileştirme.

## Bulgular

| # | Önem | Alan | Bulgu | Durum |
|---|---|---|---|---|
| 1 | — | Bütün oyun | P0 ya da P1 bulgu **yok**: 489 otomatik test, 110 uçuşluk bellek taraması (Phase 2.9), 7 dakikalık otomatik pilot uçuşu (9 bölge), modal ekranlar | Gerçek cihazda doğrulanmadı |
| 2 | P2 | App Store metinleri | 1.2.0 metinleri eski: 5 bölge anlatıyor; Günün Uçuşu, kupa, sezon ve Game Center yok | **Düzeltildi:** `docs/store/phase3_0/metadata.json` (yüklenmedi) |
| 3 | P2 | App Store görüntüleri | Eski görüntüler 1.2.0 öncesi, 5 bölgeli dönemden; 13 inç iPad görüntüsü zorunlu ama güncel değil | **Düzeltildi:** 24 yeni görüntü, TR/EN × iPhone/iPad (yüklenmedi) |
| 4 | P3 | iPad yatay | iPad'de oyun yataya dönebiliyor (Info.plist dört yön; yön kilidi çoklu görevde iPad'de uygulanmaz). Görüş alanı dikey orana sabit kalıyor, yanlarda koyu şerit var. Oynanış ve sıralama adaleti etkilenmiyor | Değiştirilmedi: `UIRequiresFullScreen` iPadOS 26'da kullanımdan kalkıyor |
| 5 | P3 | Etkinlikler (iPhone) | Kupa sekmesinde "Uçuşa başla" düğmesi kaydırma alanının kenarında kısmen kesik görünüyor (kaydırınca tam görünür) | Açık; düzeltme düğmeyi alana sabitlemek olur |
| 6 | P3 | iPad arayüzü | Menüler ve modallar iPad'de telefon boyutunda, ortada; büyük ekranı tam kullanmıyor (önceki fazlardan bilinen) | Açık |
| 7 | P3 | Gizlilik bildirimi | Uygulamanın kendi `PrivacyInfo.xcprivacy` dosyası yok. Gerekçe isteyen API'leri kullanan eklentiler (`shared_preferences`, `share_plus`) ve Flutter motoru kendi bildirimini taşıyor. `audioplayers` ve `path_provider` kaynağında böyle bir API bulunmadı. 14 yüklemede Apple "ITMS-91053" uyarısı göndermedi | Değişiklik gerekmiyor; isteğe bağlı |

## Özellik matrisi

| Alan | Otomatik | Web | iPhone |
|---|---|---|---|
| İlk açılış, yeni oyuncu → eğitim | ✓ (`tutorial_test`, `player_experience_ui_test`) | ✓ eğitim ekranı açılıyor | NOT RUN |
| Eski oyuncu → menü, kayıt korunuyor | ✓ (ux_v1 legacy, kayıt geri okuma) | — | PASS (güncelleme kurulumu) |
| Eğitim: 3 aşama, atla, tekrar oyna, ödülsüz | ✓ | ✓ (Phase 2.8) | NOT RUN |
| Ana menü, 10 ekrana tek dokunuş | ✓ | ✓ | NOT RUN |
| Uçuş, fizik, çarpışma | ✓ (fizik, hitbox, 30/60/120 Hz aynı sonuç) | ✓ | PASS |
| 9 bölge ve geçişler | ✓ (`expanded_istanbul_test`) | ✓ 7 dk otomatik pilot, Haliç → Üsküdar | PASS (uzun uçuş, geçişlerde takılma yok) |
| Engel açıklıkları | ✓ (`obstacle_balance_test`) | ✓ | NOT RUN |
| Dinamik engeller ve hava | ✓ (`hazards_*`) | ✓ (rüzgâr, gece, sis görüldü) | NOT RUN |
| Günün Uçuşu: hak, tohum, ödül, kurtarma | ✓ (`daily_*`) | ✓ ekran | PASS (hak düşüşü, yeniden açılış) |
| Game Center (sahte GameKit) | ✓ (`game_center_test`, çevrimdışı kuyruk) | — (web'de yok) | PASS (giriş, skor sıralamada) |
| Haftalık kupa, etkinlik, sezon | ✓ (`event_*`) | ✓ ekran | PASS (kupa uçuşu, sezon puanı) |
| Profil, XP, seviye, görevler, başarımlar | ✓ (`progression_*`) | ✓ | NOT RUN |
| Simit Mağazası: satın alma, kalıcılık, çift dokunma | ✓ (`cosmetics_test`, `shop_ui_test`) | ✓ ekran | PASS (satın alma, kapat-aç sonrası duruyor) |
| Keşif albümü | ✓ (`discovery_*`) | ✓ | NOT RUN |
| Kartpostal paylaşımı (iOS paylaşım menüsü) | Kısmen (sahte paylaşım servisi) | — | PASS |
| Ayarlar, ses, titreşim, hareketi azalt | ✓ | ✓ | NOT RUN |
| Çevrimdışı | ✓ (Game Center çevrimdışı) | — | PASS (uçak modu, sonra skor gönderildi) |
| Arka plan / ön plan, boşta uyku (Phase 2.9) | ✓ (`idle_sleep_test`) | ✓ (Phase 2.9) | PASS |
| Erişilebilirlik (VoiceOver etiketleri, 44 pt, büyük metin) | ✓ | — | NOT RUN |
| iPad dikey ve yatay | — | ✓ (yatayda koyu şerit, P3) | NOT RUN |
| Kayıt sürümleri ve geri dönüş yedekleri | ✓ (`services_test`, `disk_writes_test`) | — | PASS (eski kaydın üzerine güncelleme) |

## Yayın kalite kapıları

| Kapı | Durum |
|---|---|
| P0 hata yok | ✓ (otomatik testlerde ve web'de bulunmadı) |
| Çözülmemiş P1 yok | ✓ |
| `flutter analyze` temiz | ✓ |
| Bütün otomatik testler | ✓ 489/489 |
| Eski kayıtların korunması | ✓ otomatik · iPhone PASS |
| Yeni kurulum | iPhone NOT RUN |
| Günün Uçuşu doğrulaması | ✓ otomatik · iPhone PASS |
| Game Center gerçek test | PASS (iPhone, kullanıcı) |
| Görünüm satın alma ve kalıcılık | ✓ otomatik · iPhone PASS |
| iOS paylaşımı | PASS (iPhone, kullanıcı) |
| Menü ve eğitim akışları | ✓ otomatik ve web |
| En az bir gerçek iPhone'da uçtan uca test | PASS (plan 2–10; 1, 11, 12 NOT RUN) |
| iPad uyumluluğu | Web'de bakıldı (P3 bulgular) · gerçek iPad NOT RUN |

**Sonuç:** 1.8.0 (11) gerçek iPhone'da ana akışlarda sorunsuz (11 Kasım 2026, kullanıcı testi). Yeni kurulumdaki eğitim, erişilebilirlik ve gerçek iPad testleri NOT RUN. App Review için ekran kaydı bekleniyor.

## Gerçek iPhone test planı (TestFlight 1.8.0 (11) ile)

1. Temiz kurulum → eğitim → ilk uçuş → oyun sonu → "Tekrar uç".
2. 1.6.0 / 1.7.0 kaydının üzerine güncelleme: rekor, simit, XP, seviye, görünümler, başarımlar, albüm, günlük ve haftalık ilerleme yerinde mi?
3. Dokuz bölgeye kadar uzun bir uçuş (en az Rumeli Hisarı); bölge geçişlerinde takılma var mı?
4. Günün Uçuşu: 1 dereceli uçuş; hak 2/3'e iniyor mu, uygulama kapatılıp açılınca doğru mu?
5. Game Center: giriş, skorun dünya ve arkadaş sıralamasında görünmesi, başarım bildirimi.
6. İstanbul Kupası uçuşu ve sezon puanı.
7. Mağaza: 50 simitle Denizci al, uygulamayı kapat-aç, görünüm duruyor mu?
8. Kartpostal paylaşımı: Mesajlar'a gönder, Fotoğraflar'a kaydet (izin metni).
9. Uçak modunda oyna, sonra bağlan: bekleyen skor gönderiliyor mu?
10. Menüde 30 sn bekle (sahne durur), dokun (devam eder). Uçarken arka plana al ve dön ("Devam").
11. Hareketi Azalt, Büyük Metin ve VoiceOver ile menü ve oyun sonu.
12. iPad'de dikey ve yatay; Split View.
13. **App Review 2.1 için ekran kaydı:** uygulama açılışından başlayan, ana özellikleri gezen 1–2 dakikalık kayıt.
