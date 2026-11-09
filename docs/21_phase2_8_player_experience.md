# 21 · Phase 2.8: Oyuncu deneyimi, ilk uçuş eğitimi ve arayüz cilası

> **Dosya adı:** İstekte `docs/20_phase2_8_player_experience.md` geçiyordu; 20 numara Phase 2.7'de kullanıldığı için 21.
> **Dal:** `feature/phase2-8-player-experience`, `main` (`42e774a`, Phase 2.7 dahil) üzerine. Sürüm değiştirilmedi (1.6.0+9). **Öneri: 1.7.0** (Phase 2.7 + 2.8; App Store'daki son kayıt 1.2.0, TestFlight'taki son derleme 1.6.0 (9)).
> TestFlight, App Review ve yayın **yapılmadı**. Gerçek iPhone testi **yapılmadı** (§10).

## 1. Denetim ve önceki UX

- **Dallar:** Bütün fazlar `main`'de birleşik (PR #1). Phase 2.7 doğrulanmış taban.
- **Önceki menü:** Logo; üstte rekor ve "· Mağaza" kutucukları; seviye/görev/başarım şeridi; Günlük + Etkinlikler satırı; Keşfet + Sıralama satırı; "UÇMAYA BAŞLA"; Ses / Ayarlar / Nasıl oynanır.
  - **Sorunlar:**
    - Aynı görünümde çok sayıda giriş: Profil "SV 1" çubuğunun içinde gizli, Mağaza bir bakiye kutucuğunda.
    - Rekor kutusu düğme gibi görünüyor ama dokunulmuyor.
    - Yeni oyuncu için ilk dakikada yönlendirme yok; yalnızca "Nasıl oynanır" metni var.
- **Önceki oyun sonu:** "Tekrar uç" kartpostal ve özetin altında. Küçük ekranda kaydırma gerektiriyordu. Özet bütün satırları aynı anda gösteriyordu.
- **Var olan geri bildirimler** (yeniden üretilmedi):
  - Skor ve simit sayacında büyüme, simit parçacıkları.
  - "KIL PAYI!", "REKOR GEÇİLDİ!", bölge damgası.
  - Rekor konfetisi ve damgası, satın alma damgası, seviye satırı.

## 2. Ekran akışı (yeni)

```
İlk açılış (yeni oyuncu) → Eğitim 1/3 → 2/3 → 3/3 → "Eğitim tamam" → dokun → klasik uçuş
İlk açılış (eski oyuncu) → Ana menü
Ana menü → Uçuşa başla → dokun → uçuş → oyun sonu → Tekrar uç (tek dokunuş)
Ana menü → Günün Uçuşu | Etkinlikler | Profil | Mağaza | Keşif | Sıralama | Görevler | Başarımlar | Ayarlar | Nasıl oynanır   (hepsi tek dokunuş)
Mağaza → görünüm seç (2. adım) · Nasıl oynanır → Eğitimi oyna
```

## 3. Etkileşimli eğitim

- **Durum makinesi** (`lib/game/tutorial.dart`, saf): `fly → obstacle → simit → done`; ipuçları `crashed`, `missedSimit`.
  1. **Uçmayı öğren:** Oyuncunun dokunması beklenir; parmak animasyonu ve "Uçmak için ekrana dokun" gösterilir. Uçuşta "Güzel!" ve havada kalma çubuğu (2,5 sn).
  2. **Engelleri geç:** Tek, geniş geçit (560; klasik 370).
  3. **Simit topla:** Geçidin ortasında simit; gerçek toplama efekti ve sesi. Kaçırılırsa bir tane daha gelir.
  - **Çarpınca** oyun sonu yok: aynı aşama "dokun" ekranından yeniden başlar ("Neredeyse!").
- **Ayrı uçuş türü** `RunMode.tutorial`: uçuş olayı yayınlanmaz (başladı / bitti / yarıda bırakıldı / simit / engel). Bu yüzden:
  - XP, simit, görev, başarım ve rekor yok; ilerleme kaydı değişmez.
  - Game Center'a gönderim yok.
  - Günlük hak ve kupa kaydı tüketilmez; tohumlar etkilenmez.
  - Hepsi testle doğrulandı.
- **Kayıt** (`ux_v1`, ilerlemeden ayrı, sürümlü): `pending | completed | skipped | legacy`.
  - **Yeni oyuncu:** Hiç ilerlemesi yoksa ilk açılış doğrudan eğitime gider.
  - **Eski oyuncu:** `legacy`; eğitim zorlanmaz.
  - **Atlama ya da yarıda çıkış:** `skipped`; bir daha zorlanmaz.
  - **Silinmez:** Tamamlanan eğitim hiçbir koşulda geri alınmaz.
  - **Bozuk kayıt:** Eğitim zorlanmaz.
  - **Tekrar oynama:** "Nasıl oynanır → Eğitimi oyna"; durum değişmez.

## 4. Menü ve navigasyon

| Seviye | İçerik |
|---|---|
| Kimlik | Logo; rekor (kutusuz yazı); bugünün özeti: seviye çubuğu, Görev n/3, Başarım n/9 |
| İkincil | Günün Uçuşu · Etkinlikler (eşit genişlik) |
| **Birincil** | **UÇUŞA BAŞLA**, en büyük düğme |
| Oyuncu alanı | Profil (SV) · Mağaza (bakiye) · Keşif (%) · Sıralama: eşit karolar |
| Yardımcı | Ses · Ayarlar · Nasıl oynanır (küçültülmüş) |

- **"Yeni" işaretleri:** Görülmemiş görünüm (Mağaza), yeni kartpostal (Keşif) ve yeni açık etkinlik (Etkinlikler) için karonun köşesinde küçük kare. Pop-up yok; ekran açılınca söner.
  - Eski oyuncu güncellemede işaret yığınıyla karşılaşmaz.
  - Ceza ya da zorunlu günlük giriş yok.
- **Ölü kod silindi:** Eski Keşfet, Sıralama ve Mağaza düğmeleri, bilgi rozeti.

## 5. HUD

- **Eğitimde:** Skor, rota ve vurgular yerine aşama, tek satır yönerge ve çubuk.
- **Mod etiketi:** Günlük, etkinlik ve antrenmanda en üstte küçük bir mod etiketi; Simit Festivali'nde canlı puan. Oyun alanına inmiyor.
- **Simit:** Sayacın altında "+1" (festivalde "+1 · +2 puan"), ses kapalıyken de görünür.
- **Kıl payı:** "KIL PAYI!" altında "+5 XP" (ayardan okunuyor).

## 6. Oyun sonu

- **Sabit eylem çubuğu:** "Tekrar uç" (birincil), altında daha alçak "Paylaş · Ana menü".
  - Kartpostal ve özet üstte kaydırılabilir alanda.
  - "Tekrar uç" 320×568, 375×667 ve 430×932'de kaydırmadan görünüyor (test).
- **Özet:** XP, seviye ve simit üstte.
  - XP çubuğu uçuş öncesinden dolar; seviye atlanınca "SEVİYE n!" damgası çıkar.
  - Görev, başarım ve keşif satırlarının ilk ikisi görünür, gerisi "Ayrıntılar"da.
  - Başarım satırı başarımlar ekranını açar.
- **Kartpostal görseli değişmedi.**

## 7. Game feel

- **Mağaza:** Bakiye eski değerden yenisine sayar, yanında kısa süre "−50" görünür.
- **Yeni geri bildirimler:** Seviye damgası, "+1", "+5 XP", eğitimde "Güzel!" ve dokunma animasyonu.
- **Kısıtlamalar:** Yeni sarsıntı ya da flaş yok. Hepsi azaltılmış harekette sabit.
- **Tasarım değerleri** (`theme.dart`):
  - `UiSpace`: 4/8/12/16/24 ve 44 pt dokunma hedefi.
  - `UiDur`: 160/220/420/700 ms.
  - `UiText`: dipnot 10 / gövde 15 / başlık 20.

## 8. Erişilebilirlik

- **VoiceOver:** Bütün menü karoları, eğitim aşaması, "Eğitimi atla" ve tıklanabilir özet satırları etiketli. `labeledTapTargetGuideline` testi geçiyor.
- **Dokunma hedefi:** ≥ 44 pt (`iOSTapTargetGuideline` testi).
- **Hareketi Azalt:** iOS ayarı oyunun azaltılmış hareketine eşleniyor; fizik ve çarpışma aynı (test).
- **Büyük metin:** 1,3×'e kadar uygulanıyor (piksel font ve düzen daha büyükte taşar); 375×667'de menü ve oyun sonu taşmıyor (test).
- **Renk körlüğü:** "Yeni" işareti biçimle (kare) ve sesli etiketle ayrılıyor; tamamlanma onay ikonu ve metinle.
- **Bulunan ve düzeltilen hata:** Görev ekranı ilk açılışta görevleri oluşturma (build) sırasında üretiyordu; ilk kareden sonraya alındı.

## 9. Performans ve testler

- **Performans:** Yeni bileşenler hafif. Kare başına yeniden çizilen tek şey, eğitimin 1. aşamasındaki havada kalma çubuğu. Oyun döngüsüne ek iş yok; eğitim mevcut bileşenleri kullanıyor. Gerçek iPhone ölçümü yok; FPS iddiası yok.
- **Testler:**

| Komut | Sonuç |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **454 / 454** (26 yeni) |

- **`tutorial_test.dart` (14):**
  - Durum makinesi; ux kaydı (yeni / eski, geri alınamaz tamamlama, bozuk kayıt).
  - İlk açılış; eğitimi baştan sona tamamlama, ödül / olay / kayıt / Game Center yok.
  - Çarpma, atlama, yarıda çıkış, tekrar oynama.
  - Günlük hak ve kupa güvenliği, hava ve engel; klasik / günlük / etkinlik regresyonu.
- **`player_experience_ui_test.dart` (12):**
  - İlk açılış ekranı, eğitim HUD'u, "Eğitimi oyna".
  - Menüden 10 özelliğe tek dokunuş.
  - 3 ekran boyutunda "Tekrar uç" görünürlüğü ve tek dokunuş.
  - "Yeni" işaretleri; VoiceOver ve dokunma hedefi yönergeleri; büyük metin; Hareketi Azalt.
- **Güncellenen mevcut testler:** "UÇUŞA BAŞLA" metni, Mağaza karosu, "Ayrıntılar" açılımı.

**Kabul ölçütleri:**

| Ölçüt | Durum |
|---|---|
| Tek eylemle uçuş | Menüden tek dokunuş, sonra ilk dokunuş uçuşu başlatır |
| Oyun sonundan tek eylemle yeniden uçuş | Doğrulandı (otomatik) |
| Özellikler en fazla iki adımda | Hepsi bir adım (otomatik) |
| İlk 30 saniyede uçmayı öğrenme | Eğitim ~10–20 sn'de bitiyor (test pilotu). **Gerçek kullanıcıyla ölçülmedi** |

## 10. Gerçek cihaz test planı (hepsi NOT RUN)

1. Temiz kurulum: eğitim açılıyor, üç aşama anlaşılır, çarpınca aynı aşamadan dönüyor, "Atla" çalışıyor.
2. 1.6.0'dan güncelleme: eğitim zorlanmıyor; rekor, simit, görünüm ve albüm duruyor; işaret yağmuru yok.
3. VoiceOver ile menü ve eğitim; Hareketi Azalt; Büyük Metin.
4. iPhone SE'de menü, oyun sonu ve "Tekrar uç".
5. Ses kapalıyken simit ve kıl payı görsel geri bildirimi.
6. Akıcılık 1.6.0 ile aynı.

## 11. Bilinen eksikler

- **Ekran görüntüleri:** Eski ve yeni ekran görüntüleri bu turda üretilmedi (kullanım sınırı). Tarayıcı paneli uçuş sırasında duraklıyor; görüntüler bir sonraki turda alınmalı.
- **Kullanıcı testi:** Gerçek kullanıcı testi yok; 30 saniye hedefi doğrulanmadı.
- **Metin boyutu:** Bütün ekranlardaki 10 punto dipnotlar gözden geçirilmedi (yalnızca yeni ve değişen ekranlar).
- **Kontrast:** Otomatik kontrast denetimi oyun sahnesinin önünde çalıştırılmadı.
