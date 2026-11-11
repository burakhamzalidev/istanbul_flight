# Phase 3.0 yayın planı

> Hiçbir adım otomatik değil. Yükleme, inceleme gönderimi ve yayın **yalnızca kullanıcının açık onayıyla** yapılır. Arka planda izleme ya da bildirim yok; aşağıdaki kontroller elle yapılır.

## 0. Yayın engelleri (sırayla)

| # | Engel | Kim | Not |
|---|---|---|---|
| 1 | **Apple hesap sorunu:** TestFlight kurulumu "uygulama kullanılamıyor"; beta incelemesi gönderimi 422 | Kullanıcı ve Apple | Talep 103007198858. Lisans sözleşmesi 10 Kasım'da kabul edildi, sorun sürüyor |
| 2 | Gerçek iPhone'da uçtan uca test | Kullanıcı | `docs/phase3_0_qa_matrix.md` sonundaki 13 madde |
| 3 | App Review 2.1 için ekran kaydı (fiziksel iPhone, açılıştan başlayan) | Kullanıcı | 1.2.0 incelemesi bu yüzden durdu |
| 4 | App Store Connect: sürüm kaydı 1.4.0 → 1.8.0, derleme 1.8.0 (11), metinler, 24 görüntü | Kullanıcı onayı → ben ya da kullanıcı | Materyaller hazır: `docs/store/phase3_0/` |
| 5 | App Privacy | — | "Data Not Collected" yayında ve hâlâ doğru (veri akışı değişmedi; yalnızca Apple Game Center) |

## 1. Yayın sırası

1. **Hesap:** Engel 1 çözülür; TestFlight'tan 1.8.0 (11) telefona kurulur.
2. **Test:** Gerçek cihaz testi yapılır.
   - **Hata çıkarsa:** Düzeltilir, 1.8.1 (12) olarak derlenir (onayla) ve test tekrarlanır.
3. **Ekran kaydı:** App Review için alınır.
4. **App Store Connect hazırlığı** (onayla):
   - Sürüm 1.8.0 olur, derleme 11 seçilir.
   - TR/EN metinler ve 24 görüntü yüklenir.
   - App Review notu ve kayıt eklenir.
   - "Manually release this version" seçilir.
5. **App Review'a gönderim:** Yalnızca açık onayla.
6. **Onaydan sonra:** "Pending Developer Release" durumunda yayın tarihi kararlaştırılır. **Halka açık yayın yalnızca açık onayla.**

## 2. Aşamalı dağıtım

- **Ne yapar:** Apple'ın resmî sayfası, otomatik güncellemeleri 7 gün içinde (%1, 2, 5, 10, 20, 50, 100) kademeli dağıtır. Toplam 30 güne kadar duraklatılabilir.
- **Kime uygulanır:** Yalnızca **sürüm güncellemeleri**, yani mevcut kullanıcıların otomatik güncellemesi. Sayfa ilk sürüm için uygun olup olmadığını açıkça yazmıyor; ilk sürümde güncellenecek kullanıcı da olmadığı için anlamlı değil. App Store'dan elle indirenler her zaman yeni sürümü alır.
- **Öneri:** İlk sürüm (1.8.0) **manuel** yayınlanır. 1.8.1 ve sonraki güncellemelerde aşamalı dağıtım açılır.

## 3. Geri alma ve düzeltme

- **Geri alma yok:** App Store'da önceki sürüme geri dönülemez.
- **Ciddi bir sorunda:**
  1. "Remove from Sale" ile satıştan kaldırılır (kurulu kopyalar çalışmaya devam eder).
  2. Düzeltme 1.8.1 olarak derlenir; Codemagic `ios-testflight` ile, onayla.
  3. TestFlight'ta doğrulanır.
  4. App Review'a "expedited review" (hızlandırılmış inceleme) isteğiyle gönderilir (onayla).
- **Güncelleme sırasında sorun:** Aşamalı dağıtım duraklatılır.
- **Kayıt güvenliği:** Kayıt anahtarları ve geri dönüş yedekleri sayesinde eski bir sürüme dönen oyuncunun ilerlemesi kaybolmaz (Phase 2.3–2.7 yedekleri).

## 4. Yayından sonra kontrol

| Zaman | Kontrol | Kaynak |
|---|---|---|
| İlk 24 saat | Çökme var mı; ilk yorumlar; Game Center sıralamalarına skor geliyor mu; destek e-postası | App Store Connect → TestFlight / App Analytics → Crashes; Xcode Organizer; Game Center sıralamaları |
| 7 gün | İndirme, ürün sayfası dönüşüm oranı, ülkeler; çökme oranı; 1. gün geri dönüş; yorumlara yanıt | App Analytics (Acquisition, Usage, Retention) |
| 30 gün | 7. ve 28. gün geri dönüş; oturum sayısı; aktif cihaz; görüntü ve metin denemesi gerekiyor mu; 1.8.1 ihtiyacı | App Analytics; Product Page Optimization (A/B) |

**Analitik kapsamı:** App Store Connect Analytics şunları verir:
- indirme ve ürün sayfası görüntüleme
- dönüşüm oranı
- oturum ve aktif cihaz
- geri dönüş (Retention)
- çökmeler
- ülke ve sürüm kırılımı

Bu veriler yalnızca Apple ile veri paylaşmayı kabul eden kullanıcılardan gelir. **Yeni bir SDK gerekmiyor.** Oyun içi olay analitiği için teknik tasarım: `docs/23_phase3_0_premium_release.md` §8. Uygulanmadı, onay gerektirir.
