# App Review cevabı: 1.4.0 (Guideline 2.1, Information Needed)

> 1.2.0 (3) incelemesi "Information Needed" ile döndü. 23 Ekim 2026 22:25'te (İstanbul) hesaptaki tüm TestFlight derlemeleri Apple tarafında aynı anda "Expired" oldu.
> Kullanıcı kararıyla (24 Ekim 2026) aynı sürüm kaydı 1.4.0'a çevrilip yeni derleme 1.4.0 (6) ile gönderilecek.
> Video kullanıcı tarafından gerçek iPhone'da çekilir ve ASC'de cevaba eklenir.
> Bu metin "Reply to App Review" alanına ve sürümün "Notes" (App Review Information) alanına yazılır.

## Cevap (EN)

```
Hello App Review Team,

Thank you for reviewing İstanbul Flight. We have updated this submission to version 1.4.0, which includes everything in 1.2.0 plus an Istanbul discovery album and Game Center support. The requested information is below. The screen recording (made on a physical iPhone running the latest iOS, starting from app launch) is attached.

1. Screen recording
Attached. The app has no account registration or login, no user-generated content, and no paid content or in-app purchases.

2. Purpose and target audience
İstanbul Flight is a casual, one-tap pixel-art arcade game for all ages (rated 4+). The player guides a seagull named Simit through five Istanbul districts (Golden Horn, Galata, Maiden's Tower, Bosphorus Bridge, Rumeli Fortress), passing obstacles and collecting simits (a traditional Turkish bread). It offers short, relaxing play sessions in a recognizable Istanbul setting. Daily missions, achievements, a postcard album of the districts and cosmetic looks are unlocked with simits earned in the game.

3. How to use the main features
No login, account or sample files are needed. The interface is in Turkish.
- Launch the app and tap "Uçmaya başla" (Start flying), then tap anywhere to flap and fly.
- After a crash, the results postcard shows your score. "Paylaş" (Share) opens the iOS share sheet.
- On the main menu, the level bar opens the Profile, "Görev" opens Daily Missions and the star opens Achievements.
- "İstanbul'u Keşfet" (Discover Istanbul) opens the map and postcard album. Reaching a district in a flight unlocks its postcard and discovery goals.
- The trophy button ("Sıralama") opens the leaderboards: all-time and weekly, global or friends. If the device is signed in to Game Center, scores and achievements are sent to Game Center automatically. The game is fully playable without Game Center.
- The simit counter ("Mağaza") opens the Simit Shop. Looks are bought only with in-game simits; there is no real money.
- The gear icon opens Settings (music, sound effects, vibration, reduce motion).

4. External services
Apple Game Center only (GameKit): optional sign-in, leaderboards ("istanbul_flight_best_score", weekly "istanbul_flight_weekly_score") and 9 achievements. The friends leaderboard asks for Game Center friends access only when the player opens it. There are no own servers, analytics, advertising, crash reporting or third-party SDKs. Game progress is stored on the device.

5. Regional differences
None. The app works the same in all regions where it is available. The interface language is Turkish in all regions.

6. Regulated industry or third-party material
Not applicable. The app is not in a regulated industry and contains no protected third-party content. All artwork, music, sound effects and the pixel font were created by the developer. The depicted places are public landmarks of Istanbul, shown as original pixel-art illustrations.

Best regards,
Burak Hamzalı
```

## Ekran kaydı (kullanıcı çeker)

TestFlight'tan 1.4.0 (6) kurulduktan sonra, uygulama kapalıyken Denetim Merkezi → Ekran Kaydı ile başlatın (1–2 dk):

1. Uygulamayı açın: açılış, Game Center karşılama bildirimi, ana menü.
2. Uçmaya başlayın, simit toplayın, çarpın, kartpostala bakın, Paylaş'a dokunun.
3. Görevler, Başarımlar ve Profil'i açın.
4. İstanbul'u Keşfet: haritaya ve bir kartpostala bakın.
5. Sıralama: Tüm zamanlar, Haftalık, Arkadaşlar; "Game Center'da aç".
6. Mağaza'da bir görünüm alıp "Kullan"a basın. Son olarak Ayarlar'ı açın.
