# Gizlilik politikası güncelleme taslağı (Game Center, sürüm 1.4.0)

> **Durum: TASLAK, YAYIMLANMADI.** Yayındaki sayfa (https://burakhamzalidev.github.io/istanbul_flight/privacy.html, `gh-pages` dalı) değiştirilmedi.
> 1.4.0 (Game Center) App Store'a gönderilmeden önce, kullanıcının onayıyla yayımlanmalı. 1.2.0 ve 1.3.0 için mevcut metin doğru.

## Değişecek bölüm: "İnternet" → "İnternet ve Game Center"

**TR (mevcut):** Uygulama internete bağlanmaz. Hesap, oturum açma, sunucu, analitik, reklam, çökme raporlama ya da takip hizmeti yoktur.

**TR (yeni):**

> **İnternet ve Game Center.** Oyun internet olmadan oynanır. Cihazınızda Apple Game Center'a giriş yaptıysanız, uygulama Apple'ın Game Center hizmetini kullanır: uçuş skorlarınız Apple'ın liderlik tablolarına, başarımlarınız Game Center'a gönderilir ve sıralamada sizin ve diğer oyuncuların Game Center adları gösterilir. Bu veriler Apple tarafından işlenir ([Apple Games ve Gizlilik](https://www.apple.com/legal/privacy/data/en/apple-games/)). Uygulama Game Center kimliğinizi, adınızı, avatarınızı ya da arkadaş listenizi saklamaz ve bize ya da üçüncü taraflara göndermez. "Arkadaşlar" sıralamasını açarsanız iOS arkadaş listesi için izin ister; liste yalnızca sıralamayı göstermek için kullanılır. Game Center'a giriş yapmak zorunlu değildir. Uygulamanın kendi sunucusu, hesabı, analitiği, reklamı, çökme raporlaması ya da takibi yoktur.

**EN (new):**

> **Internet and Game Center.** The game works without an internet connection. If you are signed in to Apple Game Center on your device, the App uses Apple's Game Center service: your flight scores are sent to Apple's leaderboards and your achievements to Game Center, and the leaderboard shows your Game Center name and those of other players. This data is processed by Apple ([Apple Games & Privacy](https://www.apple.com/legal/privacy/data/en/apple-games/)). The App does not store your Game Center identifier, name, avatar or friends list and does not send them to us or to any third party. If you open the "Friends" leaderboard, iOS asks for permission to access your friends list; it is used only to show that leaderboard. Signing in to Game Center is optional. The App has no servers, accounts, analytics, advertising, crash reporting or tracking of its own.

## Destek sayfası SSS ekleri

- **TR:** *Game Center'a nasıl bağlanırım?* iPhone Ayarlar > Game Center'dan Apple hesabınızla giriş yapın; oyunda "Sıralama" ekranı bağlantı durumunu gösterir. Bağlanmasanız da oyun aynen oynanır ve rekorunuz cihazda saklanır.
- **EN:** *How do I connect to Game Center?* Sign in under iPhone Settings > Game Center. The in-game "Leaderboard" screen shows your connection status. The game works the same without it, and your record stays on your device.

## App Privacy (App Store Connect) değerlendirmesi

Apple'ın tanımı: "collect" = verinin cihaz dışına, sizin ya da üçüncü taraf ortaklarınızın erişebileceği şekilde aktarılması. Ayrıca: "You are not responsible for disclosing data collected by Apple." (developer.apple.com/app-store/app-privacy-details).

- Skorlar ve başarımlar yalnızca Apple'ın Game Center hizmetine gider. Uygulamanın kendi sunucusu yok; Game Center verisi saklanmıyor.
- **Değerlendirme:** "Data Not Collected" beyanı değişmeden kalabilir.
- **Uyarı:** Bu bir hukuki görüş değildir. Apple'ın App Privacy sayfasında Game Center adı geçmiyor. Kesin karar App Store Connect beyanını yapan geliştiricinindir.
