# TestFlight beta: İstanbul Flight 1.1.0 (Phase 2.1)

> **Durum: TestFlight'a YÜKLENDİ (22 Ekim 2026, onayınla).** 1.1.0 (2): Codemagic `ios-testflight` hatasız; App Store Connect işledi ("Ready to Submit"); yalnızca dahili "Ekip" grubuna dağıtıldı; What to Test (TR) girildi. Harici test / App Store yok.
> Bundle ID ve Codemagic iş akışları değişmedi. Teknik ayrıntı: [../12_phase2_player_progression.md](../12_phase2_player_progression.md)

## 1. Sürüm notları

**TR:**

```
İstanbul Flight 1.1.0 (beta 2): oyuncu ilerlemesi

• Profil: seviye, XP çubuğu, simit bakiyesi ve uçuş istatistikleri
• XP: geçtiğin her engel, topladığın simit, kıl payı geçiş ve keşfettiğin yeni bölge XP kazandırır
• Günlük görevler: her gün 3 görev, uçtukça kendiliğinden ilerler, ödülü hemen verilir
• 9 başarım: İlk Kanat Çırpışı'ndan İstanbul Fatihi'ne
• Oyun sonu özeti: kazandığın XP, seviye, simit, tamamlanan görev ve başarımlar (kartpostal aynı)
• 1.0.0'daki simitlerin, rekorun ve ayarların korunur
```

**EN:**

```
İstanbul Flight 1.1.0 (beta 2): player progression

• Profile: level, XP bar, simit balance and flight stats
• XP from every obstacle passed, simit collected, near miss and newly discovered district
• Daily missions: 3 per day, progress automatically, rewarded instantly
• 9 achievements, from "First Flap" to "Conqueror of Istanbul"
• End-of-run summary: XP, level, simits, completed missions and achievements (postcard unchanged)
• Your 1.0.0 simits, high score and settings are kept
```

## 2. What to Test (TR, TestFlight alanı)

```
1.0.0'ı oynadıysanız önce GÜNCELLEYİN (silip yeniden kurmayın), sonra:

1. Veri: Ana menüde simit sayınız ve rekorunuz 1.0.0'daki gibi mi? Profilde ulaştığınız bölgeler işaretli mi?
2. Ana menü: "SV" (seviye), "Görev x/3" ve yıldız düğmeleri çalışıyor mu, ekrana sığıyor mu?
3. Bir uçuş yapın: kartpostalın altında "+XP" özeti çıkıyor mu? Kartpostal eskisi gibi mi?
4. Paylaş: Paylaşılan kartpostal görselinde XP paneli OLMAMALI.
5. Görevler: 3 görev var mı? Uçtukça ilerliyor mu? Tamamlanınca ödül bir kez mi geliyor?
6. Başarımlar: İlk uçuştan sonra "İlk Kanat Çırpışı" açıldı mı? Tarih doğru mu?
7. Uygulamayı tamamen kapatıp açın: seviye, XP, görev ilerlemesi ve başarımlar duruyor mu?
8. Gece yarısından sonra açın: yeni görevler geldi mi?
9. Uçuş sırasında hiçbir açılır pencere çıkmamalı; oyun hissi 1.0.0 ile aynı olmalı.
10. Küçük ekranlı iPhone'da (SE) profil, görev ve başarım ekranları taşıyor mu?
```

## 3. Test senaryoları (gerçek iPhone)

Durum: PASS · FAIL · BLOCKED · NOT RUN. **Hepsi NOT RUN** (henüz yüklenmedi).

| # | Senaryo | Beklenen | Durum |
|---|---|---|---|
| 1 | 1.0.0 → 1.1.0 güncelleme | Simit, rekor, ayarlar aynı; ulaşılan bölgeler profilde; bölge XP'si verilmiş | NOT RUN |
| 2 | Temiz kurulum | SV 1, 0 simit, 3 kolay görev, 0/9 başarım | NOT RUN |
| 3 | İlk uçuş | Özet panelinde +XP; "İlk Kanat Çırpışı" açılır; profilde 1 uçuş | NOT RUN |
| 4 | XP ve seviye | 60 XP'de 2. seviye; özet panelinde "Seviye 1 → 2!" | NOT RUN |
| 5 | Galata'ya ulaşma (15 puan) | "Yeni bölge: Galata", "Galata Kaşifi"; ikinci kez XP yok | NOT RUN |
| 6 | Görev tamamlama | Çubuk dolar, "TAMAM"; ödül bir kez; sonraki uçuşlarda tekrar yok | NOT RUN |
| 7 | Uygulamayı zorla kapatma | Bütün ilerleme korunur | NOT RUN |
| 8 | Oyun sonu animasyonu sırasında uygulamayı kapatma | Uçuş bir kez sayılır (açılınca uçuş sayısı +1, iki değil) | NOT RUN |
| 9 | Gece yarısı geçişi | Görev ekranı açıkken ya da yeniden açılışta yeni görevler | NOT RUN |
| 10 | Saat dilimi değişimi (Ayarlar → Tarih ve Saat) | Görevler o güne göre; tamamlanan görev tekrar ödül vermez | NOT RUN |
| 11 | Cihaz tarihini geri alma | Aynı günün ödülü tekrar alınmaz | NOT RUN |
| 12 | Paylaşılan kartpostal | Görselde XP paneli yok; kompozisyon 1.0.0 ile aynı | NOT RUN |
| 13 | Profil / Görevler / Başarımlar ekranları | Dynamic Island ve ana ekran çubuğu kapatmıyor; kayar içerik | NOT RUN |
| 14 | iPhone SE (küçük ekran) | Menü şeridi tek satır, ekranlar taşmıyor | NOT RUN |
| 15 | Duraklat → Ana menü | Yarıda kalan uçuş sayılmaz (1.0.0 ile aynı) | NOT RUN |
| 16 | Akıcılık | Uçuşta takılma yok; oyun sonu panelinde gecikme yok | NOT RUN |

## 4. Veri geçişi test planı

Amaç: 1.0.0 (1) TestFlight kullanıcısının verisinin 1.1.0'a kayıpsız geçmesi.

1. **Hazırlık:** 1.0.0 (1) kurulu bir iPhone'da birkaç uçuş yap. Rekoru ve menüdeki simit sayısını not et (ör. rekor 40, 37 simit). Ayarlardan sesi kapat.
2. **Güncelleme:** TestFlight'tan 1.1.0'a **güncelle** (silme).
3. **Kontrol:**
   - Menüde rekor 40 ve 37 simit görünmeli.
   - Ses kapalı kalmalı.
   - Profilde Haliç, Galata ve Kız Kulesi açık olmalı.
   - Seviye 1, XP 50/60 olmalı (2 bölge × 25).
   - Uçuş sayısı 0 olmalı (1.0.0'da tutulmuyordu; beklenen).
4. **İlk uçuş:** "İlk Kanat Çırpışı" ve rekora göre "Galata Kaşifi" açılmalı.
5. **Kalıcılık:** Uygulamayı kapatıp aç; değerler aynı kalmalı.
6. **Eski sürüme dönüş (isteğe bağlı):** TestFlight'tan 1.0.0 (1)'i yeniden kur. Simit ve rekor görünmeye devam eder (v1 kaydı silinmedi). Not: 1.0.0'da kazanılan yeni simitler 1.1.0'a geri dönüşte taşınmaz, çünkü v2 öncelikli.

Otomatik karşılığı `test/progression_test.dart` → "1.0.0 kaydı … v2'ye geçer", "bozuk v2 …" testleri.

## 5. Bilinen sorunlar (beta 2)

1. 1.0.0 için uçuş sayısı ve toplam skor geriye dönük bilinmiyor; 0'dan başlıyor.
2. Cihaz tarihini ileri almak yeni günün görevlerini açar (çevrimdışı oyun; ödüller küçük).
3. Yarıda bırakılan uçuşlar sayılmıyor (1.0.0 davranışı).
4. Simit harcanacak yer henüz yok (mağaza Phase 2.2).
5. Arayüz yalnızca Türkçe; iPad'de arayüz küçük (1.0.0'dan).
6. Gerçek cihazda henüz denenmedi; kare hızı ölçülmedi.
