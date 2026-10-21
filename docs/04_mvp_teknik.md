# 04 · MVP Teknik Notlar

> Martı: Istanbul Flight · Aşama 3 · 21 Ekim 2026

## Ortam

| | |
|---|---|
| Flutter / Dart | 3.47.7 stable / 3.13.5 |
| Flame | 1.38.2 (+ flame_test 2.3.1) |
| Kalıcı kayıt | shared_preferences 2.5.6 |
| Bu makinede derlenebilen | Web ✅ · Android ❌ (Android SDK yok) · iOS ❌ (Windows) · Windows masaüstü ❌ (Visual Studio yok) |

Android ve iOS derlemesi için Android Studio kurulumu ya da Codemagic (zar_uygulamasi'ndaki hat örnek alınabilir) gerekiyor. Flutter + Flame kararında uyumluluk sorunu çıkmadı.

## Mimari kararlar

- **Durum makinesi:** `GamePhase` (ready, playing, paused, gameOver). Tüm geçişler `IstanbulFlightGame._setPhase` üzerinden yapılıyor ve overlay'ler oradan senkronlanıyor.
- **İlk dokunuş:** READY'de dokunmak hem oyunu başlatıyor hem kanat çırptırıyor, ilk dokunuş boşa gitmiyor. Kontrol modeli Flappy türünün standardı: her dokunuş yukarı doğru anlık bir hız veriyor, parmak kalktıktan sonra yer çekimi işliyor (basılı tutmak itmiyor).
- **Kare hızından bağımsızlık:** Simülasyon 120 Hz sabit adımla işleniyor (birikimli zaman). Kare süresi en fazla 1/20 sn olacak şekilde kırpılıyor, böylece takılmalar ve arka plandan dönüş sıçrama yaratmıyor. Test edildi: 30 ve 60 fps aynı yörüngeyi veriyor, 144 fps'te fark bir adımdan az.
- **Hitbox'lar çizimden ayrı:** Simit'in hitbox'ı r=34 birimlik bir daire (görsel gövdenin yaklaşık %80'i; kanat, gaga ve kuyruk dışarıda). Engellerin hitbox'ı iki dikdörtgen. Gerçek daire-dikdörtgen testi kullanılıyor.
- **Puan:** Engelin sağ kenarı Simit'in merkezini geçince bir kez veriliyor (`scored` bayrağı). Aynı adımda önce çarpışma kontrol ediliyor, çarpan oyuncu puan alamıyor.
- **Oyun sonu:** Üretim, akış ve puanlama anında duruyor. Simit suya düşüyor. Kartpostal 0,7 sn sonra açılıyor, "Tekrar uç" bir 0,6 sn daha kilitli kalıyor (yanlışlıkla dokunmayı önlemek için).
- **Yeniden başlatma:** Engeller dünyadan kaldırılıyor. Skor, bölge, palet, geçit üretici, karakter ve simge katmanı sıfırlanıyor, oyun READY'e dönüyor.
- **Duraklatma:** HUD'daki buton ya da uygulamanın arka plana alınması oyunu PAUSED'a geçiriyor. Geri dönüşte oyun kendiliğinden devam etmiyor, oyuncu "Devam"a basıyor.
- **Bellek:** Ekrandan çıkan engeller hemen siliniyor. 10 dakikalık simülasyonda ekrandaki engel sayısı sınırlı kaldı (test).
- **Kayıt:** En iyi skor sadece rekor kırıldığında, oyun sonunda ve döngüyü beklemeden (`unawaited`) yazılıyor. Kayıt hatası oyunu durdurmuyor.
- **Ekran uyumu:** Dünya yüksekliği her cihazda sabit 1920 birim, genişlik ekran oranına göre değişiyor. Uzun telefonlarda dikey oynanış aynı kalıyor. Web ve tabletlerde oyun en fazla 3:4 oranında bir sütunda ortalanıyor.
- **Gün döngüsü:** Skor 0 / 15 / 35 / 60 / 90 eşiklerinde bölge değişiyor (Haliç, Galata, Kız Kulesi, Boğaz Köprüsü, Rumeli Hisarı). Palet 3 sn'de yumuşakça geçiyor ve bölge adı damga olarak çıkıyor.

## Görseller

| Asset | Kaynak | Durum |
|---|---|---|
| `simit/simit_sheet.png` (5 kare: 4 kanat + çarpışma) | Karakter sayfasıyla aynı vektör kaynak (`build_game_assets.js`) | ✅ Oyunda, gerçek karakter |
| `background/skyline_far_mask.png` | Tarihi yarımada silüeti, yatay döşenebilir beyaz maske | ✅ Faz rengine boyanıyor |
| `landmarks/galata_mask.png`, `kiz_kulesi_mask.png`, `bridge_mask.png` | Beyaz maskeler | ✅ Faz rengine boyanıyor |
| Gökyüzü, güneş/ay, su, yansımalar | Kodla çiziliyor (`background.dart`) | Geçici ama stile uygun |
| Engeller (ev/cumba, vapur bacası/iskele, kablo/direk) | Kodla çiziliyor (`obstacle_painter.dart`) | **Geçici**, tek dosyadan değiştirilebilir |
| Arayüz fontları | Sistem fontu | **Geçici** |

Konsept sayfaları küçültülüp arka plan olarak kullanılmadı. Asset'ler yeniden üretmek için:
```bash
node art/_source/build_game_assets.js art/game_src
sh art/_source/render_transparent.sh <svg> <genişlik> <yükseklik>   # Edge headless, şeffaf PNG
```

Can simitleri sadece iskele engelinin dekoru. MVP'de toplanabilir simit yok, bu yüzden karışma riski henüz oluşmuyor.

## Testler (`flutter test`, 25 test)

- `test/logic_test.dart`: fizik, daire-dikdörtgen çarpışması, geçit adilliği (2000 geçit), hız ve geçit eğrileri, bölge eşikleri, palet geçişi, rota çubuğu, SharedPreferences kalıcılığı.
- `test/game_test.dart` (gerçek Flame oyunu): READY ve ilk dokunuş, engel üretimi, akışı ve aralığı, 10 dakikalık oturumda nesne sınırı, her engelin tek puan vermesi, suya ve engele çarpınca GAME_OVER ve sonrasında skor/akış donması, rekor kaydı (yeni ve düşük skor), yeniden başlatma kilidi ve tam temizlik, duraklatma ve arka plan, kare hızı bağımsızlığı.
- `test/widget_flow_test.dart` (Flutter arayüzü): hazır → oyun → kartpostal → tekrar akışı; duraklat → devam.

## Bilinen eksikler ve sorunlar

1. **Mobil cihazda çalıştırılmadı.** Sadece web (Chrome, 375×812 telefon görünümü) ve testlerde doğrulandı. Android ve iOS'ta dokunma gecikmesi, performans ve safe-area davranışı kontrol edilmeli.
2. **Ses ve titreşim yok.**
3. **Toplanabilir simit, kıl payı bonusu, albüm ve paylaşım kartı yok** (MVP dokümanındaki sonraki adımlar).
4. **Kahraman simge bölge değişiminde gecikmeli geliyor:** Eski simge ekrandan çıkmadan yenisi girmiyor (tek simge kuralı). Örneğin gün batımına girildiğinde birkaç saniye daha Galata görünüyor.
5. **Rumeli Hisarı simgesi yok.** 5. bölgede köprü maskesi kullanılıyor.
6. Faza göre Simit'in kenar ışığı (rim light) oyunda yok, gece sahnesinde Simit biraz düz görünüyor.
7. Ay, hilal yerine tam disk olarak çiziliyor.
8. Zorluk değerleri (yer çekimi 2600, kanat −880, geçit 340→265, hız 340→440) ilk tahmin, oyun testiyle ayarlanmalı.
9. Uygulama ikonu, splash ekranı ve mağaza meta verileri hâlâ Flutter varsayılanları.
