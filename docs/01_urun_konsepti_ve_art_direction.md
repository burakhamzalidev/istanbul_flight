# Istanbul Flight — Ürün Konsepti ve Art Direction

> Sürüm 0.1 · 21 Ekim 2026 · Konsept aşaması (kod yok)

---

## 0. Yönetici Özeti

| Karar | Seçim |
|---|---|
| **Çekirdek fikir** | Her tur, **İstanbul'da tek bir gün**. Şafakta Haliç'ten kalkılır; gidilen mesafe arttıkça gün ilerler, Boğaz boyunca kuzeye uçulur ve gece Karadeniz ağzına varılır. |
| **Kahraman** | **Simit** — simit çalmakla ünlü, tombul, kendini beğenmiş bir İstanbul martısı. |
| **Görsel yön** | **"Modern Kartpostal"**: 1950–60'ların turizm afişlerinden beslenen, sınırlı paletli, düz şekilli, hafif baskı dokulu vektör stil. Arayüzde ölçülü İznik çinisi detayları. |
| **Ayırt edici mekanikler** | Gün döngüsü, rota ilerlemesi (durak/kartpostal koleksiyonu), simit toplama, "Kıl Payı" bonusu, günün rüzgârı (lodos/poyraz). |
| **Motor** | **Flutter + Flame**. Elinde iki Flutter projesi ve Codemagic/fastlane hattı var; menüler Flutter'da, oyun Flame'de. |
| **İsim önerisi** | Mağaza adı **"Martı: Istanbul Flight"**. "Istanbul Flight" arama (ASO) için alt başlık olarak kalsın, "Martı" marka olsun. |

---

## 1. Özgün Konsept

### 1.1 Tek cümlelik konsept
> *"Bir martının gözünden İstanbul'da bir gün: Dokun, kanat çırp, simidini kap ve gün batmadan Boğaz'ı geç."*

### 1.2 Neden "bir gün" yapısı?
Flappy Bird türünün sorunu, 10. saniyede gördüğün ekranın 100. saniyedekiyle aynı olması. Mesafeye bağlı bir **zaman ve rota ilerlemesi** üç şey kazandırıyor:

1. **Görsel ödül:** Oyuncu iyi oynadıkça yeni bir İstanbul görür. Gün batımını görmek bile başlı başına bir hedef.
2. **Somut hedef:** "47 puan" soyut kalır, "Kız Kulesi'ne vardım" akılda kalır. Skor puan olarak tutulur ama oyuncuya yer adıyla da anlatılır.
3. **Tekrar oynama isteği:** "Bir dahakine köprüyü geçeceğim" düşüncesi, "bir puan daha"dan çok daha güçlü bir motivasyon.

### 1.3 Rota (gün = rota)

| Bölge | Puan aralığı | Saat | Ön plandaki simge | Engel ailesi |
|---|---|---|---|---|
| 1. Haliç & Tarihi Yarımada | 0–15 | Şafak | Yarımada cami silüetleri (sadece arka planda) | Ahşap ev çatıları & bacalar / çamaşır ipleri |
| 2. Galata & Karaköy | 15–35 | Sabah–öğle | **Galata Kulesi** | İskele direkleri, vinçler / tramvay kabloları, tenteler |
| 3. Üsküdar & Kız Kulesi | 35–60 | İkindi → gün batımı | **Kız Kulesi**, vapurlar | **Vapur bacaları (hareketli)** / martı sürüleri |
| 4. Ortaköy & Boğaz Köprüsü | 60–90 | Gün batımı → mavi saat | Köprü, yalılar | Köprü askı kabloları / yalı çatıları |
| 5. Rumeli Hisarı → Karadeniz | 90+ | Gece | FSM ve Yavuz Sultan Selim köprüleri, hisar | Gece ışıklı kablolar / balıkçı tekneleri, şamandıralar |

90 puandan sonra gece döngüsü sonsuza kadar sürer. Zorluk artmaya devam eder, ara sıra yıldız kayar ya da bir hava fişeği atılır.

### 1.4 Engel tasarımı: "boru yok"
Flappy Bird'deki boruların yerini **İstanbul'un dikey dokusu** alıyor. Kurallar şöyle:

- **Alttan yükselenler:** çatılar, bacalar, direkler, vapur bacaları.
- **Üstten sarkanlar:** çamaşır ipleri, tramvay ve köprü kabloları, tenteler.
- **Hitbox her zaman dikdörtgen.** Görsel detay bu dikdörtgenin içinde kalır. Adil oyun, güzel görselden önce gelir.
- **⚠ Kültürel kural:** Cami, minare ve kubbeler **asla engel olmaz, çarpışma alanına girmez.** Sadece arka plan katmanında, saygın bir silüet olarak durur. Bu hem etik hem de ürün riski (yorum ve inceleme riski) açısından kesin bir karar.

### 1.5 Çekirdek döngü
```
Dokun → kanat çırp → geçitten geç (+1) → simit kap (+para) → kıl payı geç (+bonus, ekran parlar)
→ bölge değişir (gün ilerler, "durak" damgası) → çarp → kartpostal ekranı → 1 saniyede yeniden dene
```

---

## 2. Üç Görsel Stil Önerisi

### Stil A — "Modern Kartpostal" ★ ÖNERİLEN
**Referanslar:** 1950–60'ların Türk turizm afişleri, serigrafi baskılar, mid-century illüstrasyon, Monument Valley'nin sade şekil dili.

- **Atmosfer:** Nostaljik, sıcak, şiirsel ama modern. "Annemin albümündeki kartpostal, ama bugün çizilmiş."
- **Teknik:** Düz renk alanları, gradyan yerine 3–5 kademeli renk bantları, çok hafif grain/baskı dokusu, kontur yok (ya da tek renkli koyu kontur sadece oynanış katmanında).
- **Temel palet (öğle):**
  `#1F3A5F` Boğaz laciverti · `#2E8B99` turkuaz su · `#F2E6D0` kartpostal kremi · `#D9643A` kiremit/terakota · `#E8B04B` hardal güneş · `#3B2F2F` silüet kahvesi
- **Hedef kitle:** 16–45 yaş arası, geniş kitle. Türkiye'deki oyuncu + İstanbul'u bilen ya da merak eden global oyuncu. Mağaza görsellerinde premium duruyor.
- **Avantajlar:** Tamamen özgün ve İstanbul'a ait duruyor. Sınırlı palet sayesinde **gün döngüsü ucuz** (sadece palet değişiyor, yeni asset gerekmiyor). Düz şekiller küçük dosya boyutu ve yüksek FPS demek. Paylaşım kartı olarak çok iyi çalışıyor.
- **Risk:** Fazla "sakin" kalabilir. Çözüm: oynanış katmanında doygun karakter rengi, net kontrast ve canlı efektler (tüy, su sıçraması).

### Stil B — "Çini & Minyatür"
**Referanslar:** Osmanlı minyatürü (Matrakçı Nasuh'un İstanbul tasviri), İznik çinisi, ebru.

- **Atmosfer:** Masalsı, zengin, altın varaklı. Tarihi ve "müze" havası.
- **Palet:** `#1D4E89` kobalt · `#3FA7A3` turkuaz · `#C0392B` mercan kırmızısı · `#D4AF37` altın · `#F5EEDC` fildişi · `#2C5F2D` yeşil
- **Hedef kitle:** Kültür meraklısı, biraz daha yetişkin kitle. Eğitim ve kültür kurumlarının ilgisini çekebilir.
- **Avantajlar:** Dünyada eşi yok, festivallerde ve basında dikkat çeker.
- **Dezavantajlar:** Minyatürün düz, çok bakış açılı perspektifi **parallax derinliğiyle çelişiyor.** Yoğun desenler hızlı oyunda okunabilirliği düşürüyor. Asset maliyeti yüksek, gün döngüsü palet değişimiyle iyi çalışmıyor.
- **Karar:** Ana stil olarak değil, **arayüz detayı** olarak kullanılsın (çerçeveler, madalyalar, kartpostal damgaları).

### Stil C — "Neon Boğaz" (gece/synthwave)
**Referanslar:** Gece İstanbul fotoğrafları, köprü ışık şovları, synthwave.

- **Atmosfer:** Enerjik, hızlı, "şehir hiç uyumaz".
- **Palet:** `#0B0F2B` gece · `#5B2A86` mor · `#FF3E7F` neon pembe · `#00E5FF` camgöbeği · `#FFC857` sodyum lamba sarısı
- **Hedef kitle:** 13–25 yaş, hiper-casual ve TikTok/Shorts kitlesi.
- **Avantajlar:** Kısa videolarda çok çekici, bloom ve ışık efektleri "juicy" his veriyor.
- **Dezavantajlar:** **Jenerik riski çok yüksek.** Neon şehir estetiği her yerde var ve İstanbul'un kendine özgülüğünü siliyor. Bloom/glow mobilde pil ve performans maliyeti getiriyor.
- **Karar:** Ayrı bir stil olarak değil, **Stil A'nın gece paleti** içinde ölçülü kullanılsın (köprü ışıkları, sodyum lambalar).

### Nihai görsel yön
**Stil A (Modern Kartpostal) ana dil olacak. Stil B arayüz süslemelerinde, Stil C'nin ışık fikri de gece fazında kullanılacak.** Böylece üç fikir çatışmadan tek bir kimlikte birleşiyor.

---

## 3. Karakter Konseptleri

### 3.1 Simit — İstanbul Martısı ★ ÖNERİLEN KAHRAMAN
- **Kişilik:** Tombul, kendinden emin, hafif küstah, aslında sevimli bir sokak çocuğu. Vapurda yolcuların elinden simit kapan, herkesin tanıdığı martı.
- **Silüet:** Yuvarlak gövde (Flappy türünde okunabilirlik için gövde neredeyse daire), büyük turuncu-sarı gagası ve gözünün üstünde tek kaşı var. Boynuna takılı bir simit taşıyor: bu **imza aksesuarı.**
- **Renk:** Gövde krem-beyaz (`#F7F3EA`), kanatlar gri-mavi (`#8FA3B8`), gaga/ayak `#F2A93B`, simit `#C8803A` ve üstünde susamlar. Soğuk deniz ve gökyüzü üzerinde sıcak gaga ve simit en yüksek dikkati çekiyor.
- **Animasyon:** Kanat çırpma (6 kare), süzülme, düşüş (gaga aşağı dönük), çarpma (tüyler savrulur, simit yuvarlanır), menüde bekleme (kafa sallama, göz kırpma).
- **Neden?** Martı İstanbul'un gerçek sesi ve sembolü. Uçmak onun doğası, mekanik olarak açıklama gerektirmiyor. "Martı + simit" Türkiye'de herkesin anında tanıdığı, globalde ise sevimli bir hikâye.

### 3.2 Hezarfen — Küçük Mucit
- **Kişilik:** 17. yüzyılda Galata Kulesi'nden Üsküdar'a uçtuğu anlatılan Hezarfen Ahmed Çelebi'ye bir saygı duruşu. Kahramanı, tahta ve kumaş kanatlar takmış, gözlüklü, meraklı bir çocuk.
- **Silüet:** Geniş yatay kanatlar ve küçük bir gövde. Kanatlar şekli belirlediği için mobilde okunabilirlik iyi.
- **Neden ana karakter değil?** Gövde/kanat oranı hitbox'ı belirsizleştiriyor. Bir insan karakterin sürekli "çarpıp düşmesi" de bir hayvan karaktere göre daha sert bir duygu veriyor.
- **Önerilen kullanım:** **Efsanevi kilit açılır karakter** ve özel görev olarak: *"Galata'dan Üsküdar'a"* (Galata Kulesi'nden kalkıp Kız Kulesi'ne ulaşma). Hikâyesi güçlü, basında ve sosyal medyada konuşulacak bir içerik.

### 3.3 Tombi — Balonlu Sokak Kedisi
- **Kişilik:** İstanbul'un dünyaca ünlü sokak kedilerinden, turuncu tekir, uykucu, şanslı. Pazardan kaçırdığı bir demet balona tutunarak uçuyor.
- **Silüet:** Üstte balon demeti, altta sarkan kedi. Benzersiz bir dikey silüet.
- **Mekanik farkı:** Daha "yüzen" bir fizik (düşük yerçekimi, yavaş tepki). Farklı bir his veren ikinci oynanış karakteri.
- **Neden ana karakter değil?** Dikey silüet, dar geçitlerde hitbox'ı adaletsiz hissettiriyor. Ama global pazarlamada (İstanbul kedileri) çok değerli bir **ikinci karakter.**

### 3.4 Elenen fikirler (bilinçli olarak)
- **Uçan halı:** Oryantalist klişe ve jenerik "Doğu" imgesi. İstanbul'u değil bir Hollywood fantezisini anlatıyor.
- **Fesli ve bıyıklı figürler:** Karikatürleşmiş, eskimiş bir Türk imgesi.
- **Uçak:** İstanbul ile duygusal bağı yok.

---

## 4. Benzer Oyunlardan Ayrışma

| Benzerleri | Istanbul Flight |
|---|---|
| Sonsuz ve aynı arka plan | Mesafeye bağlı **gün döngüsü + gerçek rota** |
| Sadece puan | **Puan + yer adı** ("Kız Kulesi'ne vardın") |
| Soyut engeller (boru) | Şehrin kendi dokusundan engeller (çatı, baca, kablo, vapur) |
| Para toplama | **Simit** toplama: hikâyeyle bağlı, karakterin motivasyonu |
| Ölünce sıradan "Game Over" | **Kartpostal**: düştüğün yerden "selamlar" kartı, paylaşılabilir |
| Tek tip ses | Vapur düdüğü, martı çığlığı, simitçi nidası, dalga sesi, gece sessizliği |
| Her gün aynı | **Günün rüzgârı:** lodos (geri iter) / poyraz (öne savurur) / sakin |

**Ana farklılaştırıcı:** Oyuncu oyunu "skor için" değil, **"İstanbul'u görmek için"** de oynuyor. Bu duygusal bağ türde nadir.

---

## 5. Tekrar Oynanabilirlik Özellikleri (değerlendirme)

| Özellik | Etki | Maliyet | Karar |
|---|---|---|---|
| Anında yeniden başlama (<1 sn) | ★★★★★ | Düşük | **MVP** |
| Gün döngüsü / bölge ilerlemesi | ★★★★★ | Orta | **MVP** |
| Kartpostal & durak damgası koleksiyonu | ★★★★ | Düşük | **MVP** |
| Kıl Payı bonusu (risk/ödül) | ★★★★ | Düşük | **MVP** |
| Simit para birimi + karakter/şapka açma | ★★★★ | Orta | MVP'de simit sayılır; mağaza v1.1 |
| Paylaşılabilir kartpostal (skor kartı) | ★★★★ | Düşük | **MVP** |
| Günün rüzgârı (günlük değişken) | ★★★ | Düşük | v1.1 |
| Günlük görev / günlük tohumlu tur | ★★★★ | Orta | v1.1 |
| Hayalet martı (en iyi turunu gösteren gölge) | ★★★ | Orta | v1.2 |
| Liderlik tablosu (Game Center / Play Games) | ★★★ | Orta | v1.1 |
| Özel görevler (Hezarfen: Galata → Üsküdar) | ★★★★ | Orta | v1.2 |
| Mevsimsel İstanbul (Lale Festivali, kar, yılbaşı) | ★★★ | Yüksek | v2 |
| Anadolu yakası rotası (Kadıköy, Moda, Haydarpaşa) | ★★★★ | Yüksek | v2 |

**İlke:** Tekrar oynatmanın en güçlü aracı **ilerleme hissi ve merak**, zorlayıcı bildirimler değil.

---

## 6. Ekran Tasarım Yaklaşımı

### 6.1 Ana Menü — "Canlı sahne"
- Ayrı bir menü sayfası yok. **Oyun sahnesi canlı olarak arkada akıyor:** şafak, Haliç, uzakta süzülen martılar, yavaş geçen bir vapur.
- Simit bir çatı bacasının üstünde oturuyor ve kafasını sallıyor.
- Logo bir **kartpostal pulu/damgası** gibi tasarlanıyor (hafif tırtıklı kenar, eskitilmiş mürekkep).
- Ekranın ortasında "**Uçmak için dokun**" yazısı nefes alır gibi yanıp sönüyor. Ayrı bir "Oyna" butonu yok, ekrana dokunmak oyunu başlatıyor. Sürtünme sıfır.
- Altta 3 ikon var: **Albüm** (kartpostallar), **Martılar** (karakterler), **Ayarlar**. Sol üstte en iyi skor "Rekor: Kız Kulesi · 52" olarak yazıyor.

### 6.2 Oyun Ekranı — "Arayüz neredeyse yok"
- **Skor:** Üst ortada, büyük ve beyaz rakamlar, koyu gölgeli. Her arka planda okunuyor.
- **Rota çubuğu:** En üstte ince bir çizgi. Üstünde 5 durak ikonu (Galata, Kız Kulesi, köprü...) ve ilerleyen küçük bir martı ikonu var. Bu, **hedefin her zaman görünmesi** demek.
- **Simit sayacı:** Sağ üstte küçük.
- **Duraklat:** Sol üstte, notch ve safe-area'ya uygun.
- **Bölge geçişi:** Ekranın ortasında 1,5 saniyelik zarif bir yazı ("**Galata**"). Mürekkep damgası gibi basılıp kayboluyor ve oyunu durdurmuyor.
- **Okunabilirlik kuralı:** Oyuncunun parmağının olduğu alt 1/3'te hiç arayüz öğesi yok.

### 6.3 Oyun Sonu — "Kartpostal"
- Çarpınca kısa bir kare donması (hit-stop) ve tüy efekti var. Ardından ekran kayarak **bir kartpostala dönüşüyor:** düştüğün yerin illüstrasyonu, üstünde "*Galata'dan Selamlar!*" yazısı, köşede pul ve damga.
- Kartın arkasında, "el yazısı" alanında skor, rekor ve toplanan simit yazıyor. Yeni durak açıldıysa damga "küt" diye basılıyor.
- **Butonlar:**
  1. **Tekrar uç**: büyük, başparmak bölgesinde, tek dokunuş.
  2. **Paylaş**: kartpostalı 1080×1350 görsel olarak dışa aktarır. Organik büyüme kanalı.
  3. Albüm / Ana menü: küçük.
- **Hız kuralı:** Çarpmadan "Tekrar uç" butonuna kadar en fazla **0,8 saniye.** Kartpostal animasyonu dokunuşla atlanabilir.

---

## 7. MVP ve Sonraki Sürümler

### v1.0 — MVP (yayına çıkacak minimum ürün)
- Tek karakter: **Simit**
- **5 bölge**, 4 zaman fazı (şafak, öğle, gün batımı, gece) ve palet geçişleri
- 5 bölgede 2'şer engel varyantı (aynı hitbox, farklı görsel). 35 puandan sonra hareketli vapur engeli
- Simit toplama (sadece sayaç)
- Kıl Payı bonusu
- Rota çubuğu, bölge damgaları, **kartpostal oyun sonu ekranı**
- Albüm: 5 durak kartpostalı
- Paylaşılabilir skor kartı
- Ses: müzik (1 ana tema + gece varyasyonu), SFX, titreşim (haptics)
- Yerel kayıt (rekor, simit, albüm), offline çalışma
- TR + EN dil desteği
- Gizlilik dostu, minimum izin. İlk sürümde **reklam yok ya da sadece ödüllü reklam** (sonradan karar verilecek)

### v1.1
- Simit mağazası: şapkalar (vapur kaptanı, balıkçı, Galatasaray-Fenerbahçe-Beşiktaş renkleri **değil**; lisans ve kutuplaşma riski var), kanat renkleri
- Günün rüzgârı, günlük görevler
- Liderlik tablosu, başarımlar
- Ödüllü reklamla "bir kez devam"

### v1.2
- **Hezarfen** karakteri ve "Galata'dan Üsküdar'a" görevi
- **Tombi** (balonlu kedi) ve farklı fizik
- Hayalet martı

### v2
- Anadolu yakası rotası, mevsimsel temalar (kar, Lale Festivali, yılbaşı), hava durumu (yağmur, sis, düdük çalan sisli Boğaz)

---

## 8. Oyun Motoru Değerlendirmesi

### 8.1 Mevcut durum
`C:\MobilAiProjects` altında **istanbul_flight için henüz bir proje yok.** Ama `zar_uygulamasi` ve `fitness_timer` **Flutter** projeleri. `zar_uygulamasi`'nda **Codemagic + fastlane** hattı hazır, yani Flutter build ve mağaza yayını deneyimi zaten var.

### 8.2 Karşılaştırma

| Kriter | **Flutter + Flame** | Godot 4 | Unity | Defold |
|---|---|---|---|---|
| Mevcut bilgi birikimine uyum | ★★★★★ | ★★ | ★★ | ★ |
| 2D oyun yetenekleri | ★★★★ | ★★★★★ | ★★★★★ | ★★★★ |
| Menü/UI geliştirme | ★★★★★ (Flutter widget'ları) | ★★★ | ★★★ | ★★ |
| Uygulama boyutu | ~15–25 MB | ~25–40 MB | ~40–60 MB | ~5–10 MB |
| Shader / renk efektleri | ★★★ (FragmentProgram) | ★★★★★ | ★★★★★ | ★★★★ |
| Lisans / maliyet | Ücretsiz, MIT | Ücretsiz, MIT | Ücretsiz katman + kısıtlar | Ücretsiz |
| CI/CD (Codemagic/fastlane) | Hazır | Yeniden kurulmalı | Yeniden kurulmalı | Yeniden kurulmalı |
| Bu oyun için gereklilik | Fazlasıyla yeterli | Fazlasıyla yeterli | Gereğinden fazla | Yeterli, ekosistem küçük |

### 8.3 Öneri: **Flutter + Flame**
**Gerekçe:**
1. Bu oyunun teknik ihtiyacı mütevazı: parallax, sprite animasyonu, dikdörtgen çarpışma, palet geçişi. Flame bunların hepsini rahatça karşılıyor.
2. Menü, albüm, mağaza ve paylaşım kartı gibi oyunun **en çok UI içeren kısımları** Flutter'ın en güçlü olduğu alan. Flame'in `overlays` sistemiyle Flutter widget'ları oyunun üstüne konabiliyor.
3. Paylaşım kartı (`share_card.png`) ve ses varlıkları gibi deneyimler mevcut projelerinden doğrudan aktarılabilir.
4. Codemagic/fastlane hattı kopyalanarak ilk günden mağaza build'i alınabilir.

**Teknik riskler ve çözümler:**
- *Gün döngüsü renk geçişi:* Her katmanı **gri tonlamalı/maskeli** asset olarak tutup çalışma anında `ColorFilter` ile renklendirmek (ucuz yöntem) ya da tek bir `FragmentShader` ile palet/LUT eşlemesi yapmak. İkisi de mobilde 60 FPS'e uygun.
- *Performans:* Tüm sprite'lar **texture atlas** içinde olmalı, katman başına tek atlas. Parallax katmanları yatay döşenebilir (tileable) olmalı.
- *Gelecekte daha ağır efekt istenirse* (ışık, partikül yoğunluğu) Godot 4 B planı olarak kalır. Ama bu oyunun ölçeğinde gerekmeyeceğini öngörüyorum.

---

## 9. ART DIRECTION DOKÜMANI

### 9.1 Sanat ilkeleri (her karar bunlarla test edilir)
1. **Önce oynanış okunur:** Karakter ve engel her zaman arka plandan daha yüksek kontrastta olmalı.
2. **İstanbul bir karakterdir:** Her ekranda en az bir "burası İstanbul" işareti olmalı (silüet, vapur, martı, su). Ama aynı anda **en fazla bir kahraman simge** (hero landmark) görünür.
3. **Az ama net:** Her katmanda en fazla 3–4 renk. Detay, şekil ve ışıkla verilmeli, çizgi kalabalığıyla değil.
4. **Sıcak kahraman, serin dünya:** Simit'in sıcak gagası ve simidi her zaman soğuk Boğaz tonları üzerinde öne çıkar.
5. **Saygı:** Kutsal yapılar sadece arka planda, saygın ve detaylı silüet olarak görünür. Asla engel, asla komik öğe değildir.

### 9.2 Şekil dili
- **Karakter ve canlılar:** Yuvarlak, yumuşak, sevimli. Daire ve oval tabanlı.
- **Engeller:** Dikdörtgen tabanlı, hafif yuvarlatılmış köşeli (radius ≈ genişliğin %8'i), "sağlam ve tahmin edilebilir" bir his.
- **Mimari:** Arka planda kubbe ve minare ritmi (yay + dikey), orta planda Galata'nın konik ve silindir formu, ön planda yalıların yatay saçak çizgileri.
- **Su:** Yatay bantlar ve kısa, kesik beyaz yansıma çizgileri (kartpostal tekniği).

### 9.3 Kamera ve perspektif
- **Ortografik yan görünüş**, dikey (portre) ekran.
- **Ufuk çizgisi** ekran yüksekliğinin **%62'sinde** sabit. Altı deniz, üstü gökyüzü. Bu sayede Boğaz her zaman görünür.
- **Atmosferik perspektif:** Uzaklaştıkça değer (açıklık) gökyüzüne yaklaşır, doygunluk düşer, detay azalır.

### 9.4 Katman yapısı (arkadan öne)

| # | Katman | İçerik | Parallax hızı | Kontrast | Not |
|---|---|---|---|---|---|
| L0 | Gökyüzü | Bantlı gradyan, güneş/ay, yıldız | 0 | Çok düşük | Palet geçişi ile renklenir |
| L1 | Bulutlar | Düz, 2 tonlu kartpostal bulutları | 0,05 | Düşük | |
| L2 | Uzak silüet | Tarihi yarımada cami silüetleri, karşı kıyı tepeleri | 0,1 | Düşük | Tek renk + tek ışık tonu |
| L3 | **Kahraman simge** | Galata, Kız Kulesi, köprüler | 0,2 | Orta | Bölge başına 1 tane, ekrana "girer" |
| L4 | Orta plan | Kıyı binaları, yalılar, vapurlar, iskele | 0,4 | Orta | Vapurlar kendi hızıyla da hareket eder |
| L5 | Su | Boğaz yüzeyi, yansımalar | 0,5 | Orta | Basit dalga animasyonu |
| **L6** | **OYNANIŞ** | Simit, engeller, simitler | 1,0 | **En yüksek** | Koyu taban + açık kenar ışığı (rim light) |
| L7 | Ön plan | Bulanık martılar, vapur dumanı, çamaşır | 1,3 | Düşük, bulanık | Seyrek; oynanışı asla kapatmaz |

### 9.5 Işık ve gün döngüsü — Renk Senaryosu

Her faz tek bir **ana ışık yönü ve rengi** ile tanımlanır. Engellerin bir kenarında o fazın ışık renginde ince bir **kenar ışığı (rim light)** bulunur. Bu, engelleri her fazda arka plandan ayırır.

| Faz | Gökyüzü (üst → ufuk) | Su | Silüet | Işık / Rim | Engel tabanı | Duygu |
|---|---|---|---|---|---|---|
| **Şafak** | `#3E4A7A` → `#F4A9A0` → `#FCD9B8` | `#5C6E9A` | `#4A3F63` | `#FFD3A1` | `#2E2A40` | Sessiz, umut |
| **Öğle** | `#4FA3C7` → `#BFE3EC` | `#2E8B99` | `#6E8FA3` | `#FFF6DA` | `#3B2F2F` | Canlı, kalabalık |
| **Gün batımı** | `#5B3A6E` → `#E3684A` → `#F7C35F` | `#7A4A63` | `#3A2340` | `#FFB25B` | `#2A1A2E` | Altın saat, doruk |
| **Gece** | `#0E1433` → `#26305E` | `#141C40` | `#0A0E24` | `#FFC857` (sodyum) | `#05070F` + ışıklı pencereler | Büyülü, sakin |

- Geçişler **3–4 saniyede** palet enterpolasyonu ile yapılır, oyun akışı bozulmaz.
- Gece fazında köprü ışıkları ve pencereler **sabit, önceden çizilmiş** parlak renkler kullanır. Gerçek bloom yok, sadece çizilmiş hale var (performans).

### 9.6 Karakter kuralları (Simit)
- Ekran genişliğinin **%11–12'si** kadar (1080 px genişlikte ≈ 128 px).
- **Hitbox:** Görsel dairenin %80'i. Tüy ve kanat uçları hitbox dışında kalır, oyuncu lehine.
- Her fazda okunması için gövdede **koyu bir kontur** (`#2B2B3A`, 4 px @1080) bulunur. Karakter, sahnede konturu olan **tek** öğedir. Bu onu anında ayırır.
- Gece fazında karakterin üzerine hafif sıcak bir dolgu ışığı eklenir (renk kaybolmasın).

### 9.7 Engel kuralları
- Geçit (gap) yüksekliği başlangıçta karakterin **3,2 katı**, en dar hali **2,4 katı**.
- Engel genişliği sabit (≈ ekranın %18'i).
- Her engel 3 parçadan oluşur: **gövde (dikey döşenebilir)** + **uç başlığı** (çatı, baca ağzı, kablo bağlantısı) + **bölgeye özel süs.** Böylece az asset ile çok çeşitlilik sağlanır.
- Uç başlıkları, geçidin sınırını net gösteren **açık renkli bir kenarla** biter.

### 9.8 Doku ve son işlem
- Tüm sahnede **%4–6 opaklıkta baskı grain'i** bulunur (tek, döşenebilir bir doku olarak). Kartpostal hissinin anahtarı bu.
- Kenarlarda çok hafif bir vinyet var. Gradyanlar bantlı (posterize), yumuşak geçiş yok.

### 9.9 Arayüz (UI) dili
- **Malzeme metaforu:** Kartpostal, pul, mürekkep damgası, vapur bileti.
- **Süsleme:** Butonların köşelerinde ve madalyalarda İznik çinisi motifleri (lale, karanfil, rumi) ölçülü ve tek renkli olarak kullanılır.
- **Tipografi:** Türkçe glifleri (ğ, ş, ı, İ, ç, ö, ü) tam destekleyen fontlar seçilmeli.
  - Başlık ve skor: yuvarlak, kalın, sıcak bir display font (aday: *Baloo 2 ExtraBold*, *Fredoka Bold*)
  - Kartpostal metinleri: el yazısı karakterli bir font (aday: *Caveat*)
  - Gövde metni: *Nunito*
  - Lisanslar OFL (ücretsiz) olmalı. Final seçim stil kareleriyle test edilip yapılacak.
- **UI renkleri:** Kartpostal kremi `#F2E6D0` zemin, Boğaz laciverti `#1F3A5F` metin, kiremit `#D9643A` ana aksiyon butonu, hardal `#E8B04B` ödül ve vurgu.
- **Dokunma alanları:** En az 48 dp. Ana aksiyon butonu en az 72 dp yüksekliğinde.

### 9.10 Efekt (VFX) ve "juice"
- **Kanat çırpma:** 2–3 küçük tüy partikülü, hafif "squash & stretch".
- **Kıl payı:** Karakter çevresinde 0,15 sn'lik beyaz bir halka ve "kıl payı!" yazısı (el yazısı fontuyla).
- **Simit toplama:** Simit sayaca uçar, susam partikülleri saçılır.
- **Çarpma:** 80 ms'lik hit-stop, tüy patlaması, kamera sarsıntısı (çok hafif, 6 px).
- **Suya düşme:** Kartpostal tarzında stilize bir sıçrama.
- **Ses eşleşmeleri:** Kanat sesi (tok, yumuşak), puan (kısa vapur düdüğü notası, bölgeye göre perdesi değişir), bölge geçişi (uzun vapur düdüğü), çarpma (martı çığlığı + gülünç bir "vık").

### 9.11 Teknik asset standartları
- **Referans çözünürlük:** 1080×1920 (portre), 9:16. 19,5:9 ve 20:9 telefonlarda gökyüzü ve deniz uzar, oynanış alanı merkezde kalır. Tablet için yanlara ekstra parallax genişliği bırakılmalı.
- **Kaynak formatı:** Vektör (Figma, Affinity Designer ya da Illustrator). Çıktı **PNG @1x/@2x/@3x** ya da tek @3x üretilip çalışma anında ölçeklenmeli.
- **Texture atlas:** Katman başına en fazla 2048×2048.
- **Gün döngüsü tekniği:** Her arka plan katmanı **3–4 değer kademeli gri ya da maskeli** olarak teslim edilir. Renkler koddaki palet tablosundan gelir. *(Bu, gün döngüsü için 4 kat asset çizmeyi önler ve en büyük maliyet tasarrufudur.)*
- **Dosya adlandırma:** `zone{n}_layer{L}_{isim}_v{sürüm}.png` (ör. `zone2_L3_galata_v01.png`)
- **Animasyon:** 12 fps sprite sheet, kareler yatayda dizilir. Kanat çırpmada 6 kare.

### 9.12 Yapılmayacaklar (Do / Don't)
- ❌ Cami ve minareyi engel ya da çarpışma objesi yapmak
- ❌ Uçan halı, fes, oryantalist kostümler
- ❌ Takım renkleri ve logoları, siyasi isimler. Köprüler oyunda "Boğaz Köprüsü", "Fatih Köprüsü", "Kuzey Köprüsü" gibi tarafsız adlarla anılmalı
- ❌ Fotogerçekçi doku ya da fotoğraf kolajı
- ❌ Aynı ekranda iki kahraman simge
- ❌ Oynanış katmanında düşük kontrastlı renk
- ✅ Her ekranda su, her bölgede bir simge, her fazda net bir ışık rengi

---

## 10. Sonraki Aşamada Hazırlanacak Görseller

Öncelik sırasına göre. **İlk 3 madde onaylanmadan üretime geçilmez.**

### Aşama A — Görsel yön onayı (en kritik)
1. **Stil kareleri (style frames), 3 adet, 1080×1920:** Sahte bir oyun ekran görüntüsü olarak hazırlanacak (arayüzle birlikte):
   - (a) Şafak, Haliç, bacalı engeller
   - (b) Gün batımı, Kız Kulesi, hareketli vapur bacası
   - (c) Gece, Boğaz Köprüsü ışıkları, askı kablosu engelleri
2. **Renk senaryosu (color script):** 4 fazın palet şeritleri ve tek bir sahnenin 4 fazdaki küçük versiyonları (thumbnail).
3. **Simit karakter sayfası:** Ön, yan ve 3/4 görünüş, 6 yüz ifadesi, boyut karşılaştırması (engel ve geçitle), ışık fazlarındaki görünüşü.

### Aşama B — MVP üretim asset'leri
4. **Simit animasyon sprite sheet'leri:** Bekleme, kanat çırpma (6 kare), süzülme, düşüş, çarpma, suya düşme.
5. **Parallax arka plan kiti, 5 bölge × L0–L5:** Döşenebilir (tileable) ve maskeli/gri tonlamalı.
6. **Kahraman simge illüstrasyonları:** Tarihi yarımada silüeti, Galata Kulesi, Kız Kulesi, Boğaz Köprüsü, Rumeli Hisarı ve kuzey köprüleri.
7. **Engel kiti:** 5 bölge × 2 varyant (gövde + uç başlığı + süs), hareketli vapur bacası.
8. **Toplanabilirler ve efekt sprite'ları:** Simit, susam, tüy, su sıçraması, kıl payı halkası, damga mürekkebi.
9. **Arayüz kiti:** Logo (kartpostal pulu), butonlar, ikonlar (albüm, martılar, ayarlar, duraklat, paylaş), skor rakamları, rota çubuğu ve durak ikonları, çini köşe süsleri.
10. **Kartpostal şablonları:** 5 durak için ön yüz illüstrasyonları ve ortak arka yüz/pul/damga tasarımı. Paylaşım kartı (1080×1350) varyantı.

### Aşama C — Mağaza ve tanıtım
11. **Uygulama ikonu:** Simit'in yüzü ve simidi, gün batımı zemin. 3 alternatif + küçük boyut testi.
12. **Splash / açılış ekranı.**
13. **Mağaza ekran görüntüleri:** 5–6 adet, metin bindirmeli, her biri farklı bölge ve faz. Google Play feature graphic (1024×500).

### Aşama D — Sonraki sürümler için konsept
14. Hezarfen ve Tombi karakter sayfaları
15. Şapka ve kostüm konsept sayfası (simit mağazası)

---

### Önerilen sonraki adım
**Madde 1–3'ü** (3 stil karesi + renk senaryosu + Simit karakter sayfası) hazırlayalım ve onaylayalım. Bu üçü onaylanınca görsel kimlik kilitlenir. Geri kalan tüm asset'ler bu referanslardan türetilir ve tutarlılık korunur.
