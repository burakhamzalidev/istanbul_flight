> **App Store için güncel metinler:** [app_store_metadata.json](app_store_metadata.json) ve docs/14_app_store_launch.md (ad "İstanbul Flight", Phase 2.1–2.2 özellikleri dahil). Bu dosya Görev 8 taslağıdır (eski ad ve özellik listesi); Google Play bölümleri kapsam dışı.

# Mağaza materyalleri: Google Play ve App Store

**Durum:** Metinler ve görseller hazır, **hiçbir mağazaya yüklenmedi.** Yükleme ve gönderim açık kullanıcı onayı gerektirir.

Kurallar (resmî kaynaklardan, Ekim 2026):

- **Google Play:**
  - Uygulama adı en fazla 30, kısa açıklama en fazla 80, uzun açıklama en fazla 4000 karakter.
  - İkon 512×512, en fazla 1024 KB; tanıtım görseli 1024×500, alfa kanalı olmadan.
  - Ekran görüntüsü kenarı 320–3840 px olmalı; uzun kenar kısa kenarın en fazla 2 katı olabilir.
- **App Store:**
  - Ad ve alt başlık en fazla 30, anahtar kelimeler en fazla 100, açıklama en fazla 4000 karakter.
  - Ekran görüntüleri alfa kanalı olmadan: iPhone 6,1" (1179×2556) zorunlu; uygulama iPad'de de çalıştığından iPad 13" (2064×2752) zorunlu.

> **Dil:** Oyunun arayüzü **yalnızca Türkçe.** İngilizce metinler bunu açıkça belirtir; olmayan bir İngilizce arayüz vaat edilmez.

## 1. Metinler

### Uygulama adı (her iki mağaza)

`Martı: Istanbul Flight` (22 karakter)

### Google Play: kısa açıklama

- **TR:** `Simit adlı martıyla İstanbul'un beş semtinde uç; engellerden geç, simit topla.` (78)
- **EN:** `Fly a seagull named Simit across five Istanbul districts. Turkish-language game.` (80)

### App Store: alt başlık

- **TR:** `İstanbul üzerinde pixel uçuş` (28)
- **EN:** `Pixel-art flight over Istanbul` (30)

### Uzun açıklama (Google Play "Tam açıklama" / App Store "Açıklama")

**TR**

```
Martı: Istanbul Flight, Simit adlı bir martının İstanbul'un gökyüzünde uçtuğu, tek dokunuşla oynanan bir arcade oyunu.

Ekrana dokun, Simit kanat çırpıp yükselsin; bırakınca alçalır. Binaların, vapur bacalarının ve köprü ayaklarının arasındaki boşluklardan geç; her geçiş bir puan.

BEŞ BÖLGE, BİR GÜN
Şafakta Haliç'ten yola çık, Süleymaniye'yi geç. Gün ortasında Galata Kulesi'nin yanından uç, gün batımında Kız Kulesi'ni selamla. Akşam Boğaz Köprüsü'nün altından geç, gece Rumeli Hisarı'na ulaş. Bölgeler gerçek fotoğraflara dayanan pixel art ile çizildi.

TOPLA, RİSKE GİR
• Geçitlerdeki altın simitleri topla.
• Bir engelin çok yakınından geçersen "KIL PAYI!"
• Rekorunu kır; en iyi skorun cihazında saklanır.

KARTPOSTAL
Her tur, ulaştığın bölgenin kartpostalıyla biter. İstersen kartpostalı resim olarak arkadaşlarınla paylaş.

AYARLAR
Müzik ve efekt ses düzeyi, titreşim, animasyonları azaltma seçeneği.

Reklam yok. Uygulama içi satın alma yok. İnternet bağlantısı gerekmez. Kişisel veri toplanmaz.
Oyunun dili Türkçedir.
```

**EN**

```
Martı: Istanbul Flight is a one-touch arcade game about Simit, a seagull flying over Istanbul.

Tap to flap and climb; let go to glide down. Fly through the gaps between apartment blocks, ferry funnels and bridge towers — every gap is a point.

FIVE DISTRICTS, ONE DAY
Start at dawn over the Golden Horn and the Süleymaniye Mosque, pass Galata Tower at noon, greet the Maiden's Tower at sunset, fly under the Bosphorus Bridge in the evening and reach Rumeli Fortress at night. Every district is drawn in pixel art based on real photographs.

COLLECT AND TAKE RISKS
• Collect golden simit rings in the gaps.
• Pass an obstacle by a hair for a "NEAR MISS".
• Beat your record — your best score is saved on your device.

POSTCARD
Every run ends with a postcard of the district you reached. Share it as an image if you like.

SETTINGS
Music and sound effect volume, vibration, reduced motion.

No ads. No in-app purchases. No internet connection required. No personal data collected.
Note: the game's interface is in Turkish.
```

### App Store anahtar kelimeleri (100 karakter, virgülle, boşluksuz)

- **TR:** `istanbul,martı,simit,arcade,pixel,galata,kız kulesi,boğaz,köprü,uçuş,kuş,retro,tek dokunuş` (90)
- **EN:** `istanbul,seagull,arcade,pixel,retro,bird,flying,bosphorus,galata,one tap,casual,turkey` (86)

**Anahtar kelime stratejisi:**

- Yer adları (İstanbul, Galata, Boğaz) oyunu benzerlerinden ayırır ve gerçek içerikle eşleşir.
- Tür kelimeleri (arcade, pixel, retro, one tap) kategori aramaları için.
- Başka oyunların ya da markaların adları **kullanılmadı.** Bu, mağaza kurallarına aykırı olurdu.

### Kategori

- **Google Play:** Oyun → Arcade
- **App Store:** birincil Games, alt kategoriler Arcade ve Casual

### Destek ve gizlilik URL'leri (kullanıcı sağlamalı)

- **Gizlilik politikası URL'si:** Her iki mağazada zorunlu. Taslak: [privacy_policy.md](privacy_policy.md). Herkese açık bir adreste yayımlanmalı (ör. GitHub Pages).
- **Destek URL'si (App Store zorunlu):** Bir iletişim sayfası ya da e-posta içeren basit bir sayfa. Henüz yok.

## 2. Görseller

| Dosya | Boyut | Mağaza |
|---|---|---|
| [play_icon_512.png](play_icon_512.png) | 512×512 | Google Play ikonu |
| [app_store_icon_1024.png](app_store_icon_1024.png) | 1024×1024, opak | App Store (Xcode'daki AppIcon ile aynı) |
| [graphics/play/feature_graphic.png](graphics/play/feature_graphic.png) | 1024×500, RGB | Google Play tanıtım görseli |
| `screenshots/play_phone/01–06` | 1080×1920 (9:16), RGB | Google Play telefon |
| `screenshots/play_tablet/01–06` | 1600×2844 (9:16), RGB | Google Play tablet (isteğe bağlı) |
| `screenshots/ios_iphone_6_1/01–06` | 1179×2556, RGB | App Store, iPhone 6,1" (**zorunlu**) |
| `screenshots/ios_iphone_6_9/01–06` | 1320×2868, RGB | App Store, iPhone 6,9" |
| `screenshots/ios_ipad_13/01–06` | 2064×2752, RGB | App Store, iPad 13" (iPad desteklendiği için **zorunlu**) |

Ekran görüntüsü sırası:

1. Ana menü (Haliç)
2. Galata
3. Kız Kulesi
4. Boğaz Köprüsü
5. Rumeli Hisarı
6. Kartpostal

**Ekran görüntülerinin kaynağı:** Görüntüler aynı Flutter uygulamasının **web derlemesinden**, headless tarayıcıda hedef çözünürlük ve piksel yoğunluğu taklit edilerek alındı. Demo modunda: otomatik pilot, bölge seçimi. Arayüz ve çizim mobildekiyle aynı koddan geliyor. Ancak bunlar **gerçek cihaz ekran görüntüsü değil.** Durum çubuğu ve çentik görünmüyor. Bölge sahnelerinde skor, o bölgenin başlangıç skoru.

**İkon:** Oyunun kendi pixel art'ından üretildi (Simit, Galata Kulesi silueti, gün batımı). Küçük boyutta okunuyor. Programatik bir çizim olduğu için yayından önce bir tasarımcı incelemesi önerilir. **Geçici değil, yayına aday.**

## 3. İçerik derecelendirmesi (hazırlık)

| Soru grubu | Yanıt | Gerekçe |
|---|---|---|
| Şiddet | Yok, ya da hafif fantastik | Martı engele çarpınca sersemler (yıldızlar); kan, yaralanma, silah yok |
| Korku, cinsellik, küfür, uyuşturucu, alkol, tütün | Yok | |
| Kumar / benzetilmiş kumar | Yok | |
| Kullanıcı etkileşimi / sohbet | Yok | Çevrimiçi özellik yok |
| Konum paylaşımı | Yok | |
| Dijital satın alma | Yok | |
| Reklam | Yok | |

**Beklenen sonuç:** Google Play'de IARC üzerinden PEGI 3 / ESRB Everyone, App Store'da 4+. Kesin derece anket sonucunda belirlenir. App Store'da 2026 yaş derecelendirme sistemi güncellendi; yeni sorular App Store Connect'te yanıtlanmalı.

## 4. Google Play veri güvenliği beyanı (hazırlık)

| Soru | Yanıt | Kanıt (kod) |
|---|---|---|
| Uygulama kullanıcı verisi topluyor mu? | **Hayır** | Ağ kodu yok. En iyi skor, ayarlar ve ilerleme yalnızca cihazda (`shared_preferences`) |
| Veri üçüncü taraflarla paylaşılıyor mu? | **Hayır** | Kartpostal paylaşımı kullanıcının başlattığı, sistem paylaşım menüsüyle yapılan bir aktarım. Kullanıcı başlatınca beyan dışı kalır |
| Aktarımda şifreleme | Uygulanmaz (veri aktarılmıyor) | |
| Veri silme talebi | Uygulanmaz | Uygulamayı kaldırmak yerel kayıtları siler |
| Reklam kimliği | Kullanılmıyor | Reklam SDK'sı yok; AD_ID izni yok |

## 5. App Store gizlilik etiketi (hazırlık)

- **Data Not Collected.** Analitik, çökme raporu, reklam ya da takip yok.
- **Takip yok.** `NSUserTrackingUsageDescription` gerekmez.
- **Gizlilik manifestleri:**
  - Flutter motoru ile shared_preferences_foundation ve share_plus eklentileri kendi `PrivacyInfo.xcprivacy` dosyalarını taşıyor. UserDefaults kullanımı orada beyan edilmiş.
  - audioplayers_darwin'de manifest yok. İlk yüklemede App Store Connect uyarısı gelirse uygulama düzeyinde manifest eklenmeli (bkz. docs/10 §Bilinen sorunlar).
- **Şifreleme:** `ITSAppUsesNonExemptEncryption = false` (Info.plist). Uygulama şifreleme kullanmıyor.

## 6. Test dağıtım planı

| Aşama | Google Play | App Store |
|---|---|---|
| 1. Dahili | Dahili test kanalı: en fazla 100 test kullanıcısı, inceleme beklemeden | TestFlight dahili test (App Store Connect kullanıcıları, inceleme yok) |
| 2. Kapalı | Kapalı test kanalı. **Yeni kişisel geliştirici hesaplarında üretime geçmeden önce kapalı test şartı** olabilir; Play Console'da hesabınız için gösterilen şartı izleyin | TestFlight harici test (ilk derleme Beta App Review'dan geçer) |
| 3. Üretim | Aşamalı yayın (ör. %10 → %50 → %100) | Manuel yayın, inceleme sonrası |

Her aşamada: docs/10 §8'deki cihaz test planı, çökme yok, kare hızı ve bellek ölçümü.
