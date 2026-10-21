# 05 · Görsel Entegrasyon ve Animasyon Sistemi

> Martı: Istanbul Flight · Aşama 4 · 21 Ekim 2026
> Önceki: [04_mvp_teknik.md](04_mvp_teknik.md)

## Üretim yöntemi

**AI görsel üretim aracı kullanılmadı, bu oturumda erişim yok.** Bütün oyun asset'leri elle yazılmış vektör çizimler (SVG). Çizimler `art/_source/build_game_assets.js` içinde, konsept sayfalarıyla aynı çizim fonksiyonlarıyla (`build.js`) üretiliyor ve Edge headless ile şeffaf PNG'ye çevriliyor.

| Durum | Asset'ler |
|---|---|
| **Oyunda kullanılan, tutarlı ama final değil** | Simit sprite sheet'i, 5 engel kiti, 5 simge, 3 uzak silüet, 5 kıyı şeridi |
| **Geçici (kodla çizilen)** | Gökyüzü bantları, güneş/hilal/yıldızlar, bulutlar, su, sis, tüy ve sıçrama efektleri, eski engel çizicisi (`obstacle_painter.dart`, sadece asset yüklenemezse) |
| **Henüz yok** | Final illüstratör çizimleri, ses, fontlar, uygulama ikonu |

"Final değil" şu anlama geliyor: düz şekilli ve stile uygun, ama bir illüstratörün elinden çıkmış detay seviyesinde değil. Kaynaklar katmanlı SVG olarak `art/game_src/` altında duruyor, yerlerine final çizimler aynı yerleşimle konabilir.

---

## Görsel mimari

```
IstanbulFlightGame (durum makinesi + sabit adımlı simülasyon, DEĞİŞMEDİ)
 ├─ DayCycle            bölge → palet + atmosfer (sis, yıldız, ay, ışık) yumuşak geçiş
 ├─ GameArt             22 PNG, paralel yükleme, Flame Images önbelleği, eksikse yedek çizim
 ├─ world
 │   ├─ SkyLayer        L0  gök bantları, güneş ⇄ hilal, iki grup titreşen yıldız
 │   ├─ CloudLayer      L1  kartpostal bulutları (rüzgâr + parallax)
 │   ├─ FarLayer        L2  uzak silüet (Crossfade)
 │   ├─ ShoreLayer      L4  kıyı + titreşen pencere ışıkları (Crossfade)
 │   ├─ WaterLayer      L5  su bantları, dalga çizgileri, güneş/ay yansıması
 │   ├─ LandmarkLayer   L3  kahraman simge + ışıkları + su yansıması (havuzlu geçiş)
 │   ├─ FogLayer            ufuk sisi (Haliç şafağında belirgin)
 │   ├─ ObstaclePair    L6  hitbox (değişmedi) + ObstacleRenderer (sprite kiti)
 │   ├─ FxLayer             tüy / su sıçraması (sabit havuz)
 │   └─ SimitBird           SimitAnimator kare seçimi + eğim + suda salınım
 └─ Flutter overlay'leri    HUD, menü, kartpostal (sersem Simit), MARTI_STATS
```

**Ayrım kuralı:** Görsel bileşenler sadece okur (`palette`, `scrollDistance`, `frameScroll`, `time`, `dayCycle.zone`). Fizik, puan, engel geometrisi ve üretimi `IstanbulFlightGame` içinde ve bu aşamada **değiştirilmedi**. Tek fark: engel artık bir "stil" yerine bölgenin kit kimliğini (`ObstacleKitId`) taşıyor.

## Asset klasör yapısı

```
art/_source/
  build.js                    çizim fonksiyonları (Simit, Galata, Kız Kulesi, Süleymaniye...)
  build_game_assets.js        oyun asset'leri + lib/game/visual/obstacle_kit_layout.g.dart
  render_game_assets.sh       tüm SVG → şeffaf PNG (40 sn zaman aşımı, güncel olanı atlar)
  render_transparent.sh       tek dosya render (Edge headless)
  png_alpha.js                alfa/ASCII önizleme (kontrol aracı)
art/game_src/                 katmanlı SVG kaynakları + PNG çıktıları
assets/images/                oyunun yüklediği PNG'ler (toplam 664 KB)
  simit/simit_sheet.png                  2160×630   12 kare
  background/far_{peninsula,uskudar,hills}.png          2160×420   maske
  background/shore_{halic,galata,uskudar,ortakoy,rumeli}.png 2160×600  3 satır maske
  landmarks/{suleymaniye,galata,kiz_kulesi,bridge,rumeli_hisari}.png  2 satır maske
  obstacles/kit_{halic,galata,kizkulesi,kopru,rumeli}.png   1500×640  renkli + ışık
```

Yeniden üretmek için:
```bash
node art/_source/build_game_assets.js art/game_src lib/game/visual/obstacle_kit_layout.g.dart
sh art/_source/render_game_assets.sh art/game_src
```
Ardından PNG'leri `assets/images/` altına kopyalamak gerekiyor.

## Beş bölge

| Bölge | Saat | L2 uzak | L4 kıyı | L3 simge | L6 engel kiti |
|---|---|---|---|---|---|
| Haliç | Şafak + sis | Tarihi yarımada | Fener/Balat ahşap evleri, serviler | **Süleymaniye** (sadece arka plan) | Ahşap ev, kiremit çatı, baca, taş temel / cumbalı cephe, çamaşır |
| Galata | Öğle | Tarihi yarımada | Karaköy blokları, bacalar, su depoları | **Galata Kulesi** | Taş apartman, çatı ve iki baca, dükkân / ferforje balkon, kırmızı-beyaz tente |
| Kız Kulesi | Gün batımı | Üsküdar tepeleri (Çamlıca) | Üsküdar evleri, iskele binası | **Kız Kulesi** | Vapur bacası (çapa amblemi), vapur gövdesi + duman / iskele kazığı, can simidi, fener |
| Boğaz Köprüsü | Akşam, ay doğuyor | Ağaçlı tepeler | Ortaköy yalıları | **Boğaz Köprüsü** (kule odaklı) | Granit direk + üç fener / çelik kafes askı kablosu, ışık boncukları |
| Rumeli Hisarı | Gece, hilal, yıldızlar | Ağaçlı tepeler | Korular, seyrek yalılar, sahil fenerleri | **Rumeli Hisarı** (yeni asset: 3 büyük kule, mazgallı surlar) | Balıkçı direği, ağ, iki fener + kayık / çardak, asma, fenerler |

- **5. bölge köprü görselini artık tekrar kullanmıyor.** Bunu bir test denetliyor.
- **Tarihi ve dini yapılar hiçbir zaman engel değil.** Süleymaniye, Ortaköy ve yarımada camileri, Rumeli Hisarı surları sadece L2 ve L3'te yer alıyor.

## Parallax katmanları

| Katman | Hız katsayısı | Not |
|---|---|---|
| L0 gök | 0 | 7 düz bant, palet geçişi |
| L1 bulut | 0,03 + kendi rüzgârı | 4 bulut, nesne üretmez |
| L2 uzak silüet | 0,06 | döşenebilir maske |
| L4 kıyı | 0,14 | döşenebilir maske + 2 ışık seti |
| L3 simge | 0,16 | odak noktalı yerleşim |
| L5 su | 0,5 | dalga çizgileri kendi fazında parıldar |
| L6 engel | 1,0 | oynanış |

**Çizim sırasındaki tek sapma:** L3 simgeler L4 kıyı ve L5 sudan **sonra** çiziliyor. Sebebi: Kız Kulesi ve köprü suyun içinde duruyor, kıyı şeridi önlerinde olursa simgeyi keser. Hız katsayıları derinlik sırasına uygun olduğu için hareket tutarlı.

**Dikiş önleme:**
- Her şerit öğesi x−W, x ve x+W konumlarında üretiliyor (`tile()`), böylece kenarlar birleşiyor.
- Çizimde döşemeler 1 birim üst üste biniyor.
- Test: şeridin dikişteki kenar farkı, şeridin içindeki en sert komşu sütun geçişinden büyük olamaz.

**Ekran oranı:** Dünya yüksekliği her cihazda 1920 birim, şeritler genişliğe göre tekrarlanıyor. 320×568'den yatay 1024×768'e kadar 6 boyut test ediliyor.

## Bölge geçiş sistemi

MVP'deki sorun: Yeni simge, eskisi ekrandan çıkana kadar bekliyordu.

Çözüm:
1. **Palet** (`DayCycle`): renkler ve atmosfer değerleri (sis, yıldız, ay, ışık) 3 sn'de yumuşakça (smoothstep) geçiyor.
2. **L2 ve L4** (`Crossfade<T>`): eski ve yeni şerit 2,5 sn boyunca çapraz geçişle çiziliyor. Aynı anda en fazla iki şerit var. Geçiş sırasında yeni bir hedef gelirse önceki baskın şerit korunuyor.
3. **L3** (`LandmarkLayer`, 3 örneklik havuz):
   - Bölge değişince yeni simge **aynı karede** oluşuyor. Odak noktası görünür alanın %64'üne yerleşiyor, 2,2 sn'de opaklaşıyor ve 60 birim aşağıdan yükseliyor.
   - Eski simge **kaybolmuyor**, akmaya devam ederken aynı sürede soluyor.
   - Simge ekrandan çıkınca aynı bölgenin simgesi sağdan doğal olarak yeniden giriyor.
   - Odak noktası: köprüde sağ kule (%84), Rumeli Hisarı'nda tepedeki kule (%62). Geniş simgelerin önemli kısmı ekranda kalıyor.
4. **Engeller:** Her engel üretildiği bölgenin kitini korur. Geçişte ekrandaki engeller değişmez, yeni bölgenin engelleri sağdan gelir.
5. **Oynanış etkilenmiyor:** Testle doğrulandı. Geçiş boyunca engel aralığı sabit, skor sürekli, aynı anda en fazla 2 simge var.

## Simit animasyonları

`SimitAnimator` saf bir sınıf; sadece geçen süreye bakıyor, kare hızından bağımsız (testte 30 ve 120 fps aynı kareleri veriyor).

| Kare | Durum | Kullanım |
|---|---|---|
| 0–5 | Kanat döngüsü (yukarı → itiş → toparlanma) | Dokunuşta 0,27 sn'lik tek vuruş; menüde 0,09 sn/kare sürekli |
| 6 | Süzülme | Hız −250…700 arası |
| 7 | Yükselme (odaklı bakış) | Hız < −250 |
| 8 | Düşüş (şaşkın, kanatlar yukarı) | Hız > 700 |
| 9 | Çarpışma (X göz, tüyler, simit fırlar) | Çarpma anı |
| 10 | Göz kırpma | Menüde ~3,2 sn'de bir; sadece kanat kare 2 konumundayken başlar, sıçrama olmaz |
| 11 | **Oyun sonu tepkisi** (simit başına geçmiş, spiral göz) | Suya ilk değişte, dalgayla salınır; kartpostalda da gösteriliyor |

Ek detaylar:
- Gövde eğimi hıza göre değişiyor.
- Gece ve şafakta faz ışığında ince bir kenar ışığı var.
- Kanat çırpınca bazen bir tüy kopuyor (%45 olasılık).
- Suya düşüşte 10 damlalık sıçrama oluyor.

## Engel sprite yapısı

Kit atlası (1500×640) iki satırdan oluşuyor:
- **Satır 0:** renkli parçalar.
- **Satır 1:** aynı konumlarda ışık maskesi.

Parçalar:
- Alt ve üst gövde karoları (2'şer varyant, 196×192, dikey döşenebilir)
- Alt başlık ve üst başlık (224×128)
- Alt taban (224×320)

Yerleşim `obstacle_kit_layout.g.dart` dosyasına otomatik yazılıyor, art ve kod tek kaynaktan besleniyor.

**Geometri kuralları** (`ObstaclePiecePlan`, 75 kombinasyonda test edildi):
- Gövde karoları tam hitbox genişliğinde (196).
- Başlık ve tabanlar her yandan en fazla 14 birim taşıyor (oyuncu lehine).
- Alt başlığın `boundary` çizgisi geçidin alt kenarına, üst başlığın alt kenarı geçidin üst kenarına hizalı.
- Geçide sadece alt başlığın çarpışmasız süsü (baca, en fazla 30 birim) giriyor.
- [0, geçit üstü] ve [geçit altı, dünya altı] aralıkları kesintisiz kaplı. Hitbox içinde görünmez boşluk yok.

İnceleme sırasında Galata balkonunun, Haliç çamaşır bandının, köprü fenerlerinin ve Rumeli fenerlerinin arkasında **şeffaf boşluklar** buldum ve hepsine arka yüzey ekledim.

**Renklendirme:**
- Renkli kit, fazın tonuyla çarpılıyor (`BlendMode.modulate`): öğlede orijinal renk, gece karanlık.
- Işık maskesi fazın ışık rengine boyanıp üstüne çiziliyor, pencereler gece parlıyor.
- Geçit sınırı ve sağ kenarda faz ışığında çizgi var.

**Varyasyon ve hareket:**
- Gövde varyantı engelin numarasından seçiliyor.
- Kız Kulesi kazığındaki can simidi sadece başlığa komşu karoda görünüyor. Her karoda tekrar edince "zincir" gibi duruyordu.
- Vapur bacasından zamana bağlı, durumsuz duman çıkıyor.

## Performans kararları

- **Önbellek:** 22 görsel bir kez ve paralel yükleniyor (`Images.load` önbelleği). Kare başına texture üretilmiyor.
- **Paint ve filtre:** Paint nesneleri bileşen başına bir kez oluşturuluyor. `ColorFilter` sadece renk değişince yenileniyor (`TintPaint`, `ObstacleRenderer.setPalette` karede bir kez).
- **Havuzlar:** Simge örnekleri (3) ve efekt parçacıkları (24) sabit havuzlarda. Oyun boyunca yeni nesne üretilmiyor.
- **Ucuz çizimler:** Yıldızlar iki `drawRawPoints` çağrısıyla, hazır `Float32List`'lerle çiziliyor. Hilal `Path`'i statik.
- **Kullanılmayanlar:** Bloom, shader ya da blur yok. Efektler düşük opaklıklı ve oynanış alanını kapatmıyor.
- **Asset boyutu:** Toplam 664 KB. En büyük texture 2160 px genişliğinde (Simit 2160×630, mobil sınır olan 4096'nın altında).
- **Ölçüm** (web, Chrome, masaüstü GPU, `MARTI_STATS`):
  - Beş bölgenin tamamında ve geçişlerde **60 FPS**.
  - Dünyada 9–12 bileşen, ekranda 2–3 engel, en fazla 2 efekt parçacığı.
  - 10 dakikalık simülasyon testinde nesne sayısı sınırlı kaldı.
  - **Mobil cihazda ölçülmedi.**

## Test sonuçları

| Komut | Sonuç |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **62/62 geçti** (önceki 25 testin tamamı dahil) |
| `flutter build web --release` | Başarılı |

Yeni testler:
- `test/visual_test.dart`: Crossfade (3), SimitAnimator (4), engel parça yerleşimi ve hitbox uyumu (5 kit × 3 geçit × 4 varyant), bölge özgünlüğü (2), asset varlığı ve boyutları (2), şerit dikişleri (1).
- `test/game_test.dart`: bölge geçişinde yeni simgenin hemen görünmesi ve eskisinin solması; geçişin oynanışı etkilememesi; oyun sonu tepkisi ve yeniden başlatmada sıfırlanma.
- `test/widget_flow_test.dart`: 6 ekran boyutunda taşma ve oyun alanı kontrolü.
- `test/logic_test.dart`: Türkçe büyük harf (`trUpper`).

**Tarayıcıda doğrulandı** (375×812, 360×640, 390×860; demo ve normal derleme):
- Beş bölgenin kendine özgü simgesi göründü.
- Galata, Kız Kulesi ve Rumeli Hisarı geçişlerinde yeni simge hemen belirdi, eskisi soldu.
- Oyun sonu kartpostalı sersem Simit'i gösteriyor, rekor korunuyor.

**Bu aşamada bulunup düzeltilen hatalar:**
- Bölge damgası "RUMELI HISARI" yazıyordu: Dart'ın `toUpperCase`'i Türkçe değil, `trUpper` eklendi.
- Gece simgesi kontrastı yetersizdi.
- Geniş köprü simgesinin iki kulesi de ekran dışında kalıyordu.
- Can simidi tekrarı.
- Başlıklardaki şeffaf boşluklar.

**Not:** 768×1024 ve 412×915 boyutlarında tarayıcı panelindeki ekran görüntüsünde alt ve sağda beyaz alan görüldü. DOM ölçümü Flutter görünümünün sayfanın tamamını kapladığını gösterdi. Panele sığan boyutlarda sorun yok, widget testleri de bu boyutlarda doğru yerleşimi doğruluyor. Bunu önizleme panelinin ölçekleme artefaktı olarak değerlendiriyorum, ama **gerçek tablette doğrulanmadı.**

## Bilinen eksikler

1. **Mobil cihaz testi yapılmadı** (Android SDK yok, iOS için Mac yok). FPS, dokunma gecikmesi ve bellek sadece web'de ölçüldü.
2. Asset'ler elle çizilmiş vektörler, final illüstrasyon kalitesinde değil. Mimari detay sadeleştirilmiş.
3. Simit'in kanat döngüsü 6 kare ama ara kareler arasında yumuşatma (tween) yok.
4. Bölge simgeleri tek renk maske. Galata ve Kız Kulesi'nde iç detay (taş dokusu vb.) yok, sadece silüet ve ışıklar var.
5. Uzak silüetlerde ışık yok (sadece kıyı ve simgelerde var).
6. Sis tek renk bantlardan oluşuyor, gerçek hacim hissi vermiyor.
7. Efekt sesleri, müzik ve titreşim yok.
8. Asset render hattı Windows + Edge'e bağlı. Edge headless ara sıra süreç kapatmadan asılı kalıyor; betikte 40 sn zaman aşımı ve yeniden deneme var.

## Sonraki aşamaya bırakılan işler

- Final illüstrasyonlar: aynı atlas yerleşimiyle (`obstacle_kit_layout.g.dart`) parça parça değiştirilebilir.
- Simit için 8–10 karelik akıcı kanat döngüsü ve ayrı simit halkası sprite'ı (ikincil hareketi kodla vermek için).
- Toplanabilir simit, kıl payı bonusu (efekt havuzu buna hazır).
- Ses tasarımı: vapur düdüğü, martı, dalga; bölgeye göre ortam sesi.
- Fontlar (Baloo 2, Caveat, Nunito) ve arayüz kiti.
- Gerçek cihazda performans profili (Android orta segment hedef).
