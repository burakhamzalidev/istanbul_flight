import '../services/progress.dart';

/// Başarımın ölçtüğü değer (profildeki kalıcı sayaçlardan okunur).
enum AchievementMetric {
  flights,
  totalSimits,
  totalNearMisses,
  totalScore,

  /// Ulaşılan en ileri bölge sırası (1 Galata ... 4 Rumeli Hisarı).
  maxZone,
  missionsCompleted,
}

/// Veri odaklı başarım tanımı. Yeni başarım = listeye bir satır.
class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    required this.metric,
    required this.target,
    required this.rewardXp,
    required this.rewardSimits,
  });

  /// Kalıcı kimlik: kayıtta bu tutulur, başlık değişse de kayıt bozulmaz.
  final String id;
  final String title;
  final String description;
  final AchievementMetric metric;
  final int target;
  final int rewardXp;
  final int rewardSimits;

  int valueIn(PlayerProgress p) => switch (metric) {
    AchievementMetric.flights => p.flights,
    AchievementMetric.totalSimits => p.totalSimits,
    AchievementMetric.totalNearMisses => p.totalNearMisses,
    AchievementMetric.totalScore => p.totalScore,
    AchievementMetric.maxZone => p.maxZone,
    AchievementMetric.missionsCompleted => p.missionsCompleted,
  };

  /// Gösterilecek ilerleme: hedefte durur.
  int progressIn(PlayerProgress p) => valueIn(p).clamp(0, target);
  double fractionIn(PlayerProgress p) => progressIn(p) / target;
  bool reachedIn(PlayerProgress p) => valueIn(p) >= target;
}

/// Başarımlar kolaydan zora sıralıdır: ilk uçuşta biri açılır, gerisi kademeli gelir.
const achievementDefs = <AchievementDef>[
  AchievementDef(
    id: 'first_flap',
    title: 'İlk Kanat Çırpışı',
    description: 'İlk uçuşunu tamamla.',
    metric: AchievementMetric.flights,
    target: 1,
    rewardXp: 10,
    rewardSimits: 5,
  ),
  AchievementDef(
    id: 'galata_explorer',
    title: 'Galata Kaşifi',
    description: "Galata'ya ulaş (15 puan).",
    metric: AchievementMetric.maxZone,
    target: 1,
    rewardXp: 25,
    rewardSimits: 10,
  ),
  AchievementDef(
    id: 'simit_hunter',
    title: 'Simit Avcısı',
    description: 'Toplam 100 simit topla.',
    metric: AchievementMetric.totalSimits,
    target: 100,
    rewardXp: 50,
    rewardSimits: 20,
  ),
  AchievementDef(
    id: 'loyal_gull',
    title: 'Sadık Martı',
    description: '25 uçuş tamamla.',
    metric: AchievementMetric.flights,
    target: 25,
    rewardXp: 40,
    rewardSimits: 15,
  ),
  AchievementDef(
    id: 'bosphorus_traveler',
    title: 'Boğaz Yolcusu',
    description: "Boğaz Köprüsü'ne ulaş (60 puan).",
    metric: AchievementMetric.maxZone,
    target: 3,
    rewardXp: 50,
    rewardSimits: 20,
  ),
  AchievementDef(
    id: 'near_miss_master',
    title: 'Kıl Payı Ustası',
    description: 'Toplam 50 kıl payı geçiş yap.',
    metric: AchievementMetric.totalNearMisses,
    target: 50,
    rewardXp: 60,
    rewardSimits: 25,
  ),
  AchievementDef(
    id: 'daily_wanderer',
    title: 'Günlük Gezgin',
    description: '10 günlük görev tamamla.',
    metric: AchievementMetric.missionsCompleted,
    target: 10,
    rewardXp: 50,
    rewardSimits: 20,
  ),
  AchievementDef(
    id: 'night_flight',
    title: 'Gece Uçuşu',
    description: "Rumeli Hisarı'nda geceye uç (90 puan).",
    metric: AchievementMetric.maxZone,
    target: 4,
    rewardXp: 75,
    rewardSimits: 30,
  ),
  AchievementDef(
    id: 'istanbul_conqueror',
    title: 'İstanbul Fatihi',
    description: 'Tüm uçuşlarda toplam 1453 puan topla.',
    metric: AchievementMetric.totalScore,
    target: 1453,
    rewardXp: 150,
    rewardSimits: 50,
  ),
];

AchievementDef? achievementById(String id) {
  for (final a in achievementDefs) {
    if (a.id == id) return a;
  }
  return null;
}
