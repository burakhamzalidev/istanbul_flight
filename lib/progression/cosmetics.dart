import '../services/progress.dart';

/// Kozmetik kategorisi (mağazada ve görünüm ekranında etiket).
enum CosmeticCategory {
  classic('Klasik'),
  outfit('Kıyafet'),
  plumage('Tüy');

  const CosmeticCategory(this.label);
  final String label;
}

/// Mağaza fiyatları ve kilitleri (simit; gerçek para yok). Denge gerekçesi: docs/13 §6.
abstract final class ShopConfig {
  static const prices = <String, int>{
    'classic': 0,
    'denizci': 50,
    'pilot': 100,
    'gece': 150,
    'altin': 250,
    'kasif': 350,
  };

  /// Satın alınabilmesi için gereken oyuncu seviyesi (yalnızca hafif bir sıralama; zorunlu tekrar yok).
  static const minLevels = <String, int>{'gece': 3, 'altin': 5, 'kasif': 8};
}

/// Merkezi kozmetik tanımı. Yeni görünüm = art/_source/pixel/characters.js'e bir SKINS girdisi +
/// buraya bir satır. Görünümler yalnızca görseldir: fizik, çarpışma ve skor hiçbir alanı okumaz.
class CosmeticDef {
  const CosmeticDef({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.sheetAsset,
    this.previewFrame = 6,
  });

  /// Kalıcı kimlik (kayıtta bu tutulur).
  final String id;
  final String name;
  final String description;
  final CosmeticCategory category;

  /// Simit sprite sheet'i (12 kare, 48×42, pivot 22,22). null = klasik sheet.
  final String? sheetAsset;

  /// Kartlarda gösterilen sabit kare (6 = süzülme).
  final int previewFrame;

  int get price => ShopConfig.prices[id] ?? 0;
  int get minLevel => ShopConfig.minLevels[id] ?? 1;
  bool get isFree => price == 0;
}

const classicCosmeticId = 'classic';

const cosmeticCatalog = <CosmeticDef>[
  CosmeticDef(
    id: classicCosmeticId,
    name: 'Klasik Simit',
    description: 'Haliç martısı, göğsünde simidiyle.',
    category: CosmeticCategory.classic,
  ),
  CosmeticDef(
    id: 'denizci',
    name: 'Denizci Simit',
    description: 'Beyaz denizci şapkası, uçuşan kurdeleler, lacivert fular.',
    category: CosmeticCategory.outfit,
    sheetAsset: 'pixel_art/characters/skins/denizci.png',
  ),
  CosmeticDef(
    id: 'pilot',
    name: 'Pilot Simit',
    description: 'Deri pilot başlığı, gözlük ve rüzgârda kırmızı atkı.',
    category: CosmeticCategory.outfit,
    sheetAsset: 'pixel_art/characters/skins/pilot.png',
  ),
  CosmeticDef(
    id: 'gece',
    name: 'Gece Martısı',
    description: 'Ay ışığında lavanta tüyler, kanatlarında yıldızlar.',
    category: CosmeticCategory.plumage,
    sheetAsset: 'pixel_art/characters/skins/gece.png',
  ),
  CosmeticDef(
    id: 'altin',
    name: 'Altın Kanat',
    description: 'Altın tüylü kanatlar, bronz uçlar, pırıltılar.',
    category: CosmeticCategory.plumage,
    sheetAsset: 'pixel_art/characters/skins/altin.png',
  ),
  CosmeticDef(
    id: 'kasif',
    name: 'İstanbul Kaşifi',
    description: 'Püsküllü kırmızı fes ve nazar boncuğu.',
    category: CosmeticCategory.outfit,
    sheetAsset: 'pixel_art/characters/skins/kasif.png',
  ),
];

CosmeticDef? cosmeticById(String id) {
  for (final c in cosmeticCatalog) {
    if (c.id == id) return c;
  }
  return null;
}

/// Oyunda gerçekten kullanılacak görünüm: seçili görünüm katalogda yoksa ya da sahip olunmuyorsa klasik.
CosmeticDef effectiveCosmetic(PlayerProgress p) {
  final c = cosmeticById(p.selectedCosmetic);
  return c != null && ownsCosmetic(p, c.id)
      ? c
      : cosmeticById(classicCosmeticId)!;
}

bool ownsCosmetic(PlayerProgress p, String id) =>
    id == classicCosmeticId || p.unlockedCosmetics.contains(id);

/// Kartın durumu (mağaza ve görünüm ekranı).
enum CosmeticStatus { equipped, owned, levelLocked, affordable, tooExpensive }

CosmeticStatus cosmeticStatus(PlayerProgress p, CosmeticDef c) {
  if (effectiveCosmetic(p).id == c.id) return CosmeticStatus.equipped;
  if (ownsCosmetic(p, c.id)) return CosmeticStatus.owned;
  if (p.level < c.minLevel) return CosmeticStatus.levelLocked;
  return p.simitBalance >= c.price
      ? CosmeticStatus.affordable
      : CosmeticStatus.tooExpensive;
}

enum PurchaseResult {
  purchased,
  alreadyOwned,
  insufficientFunds,
  levelLocked,
  unknownItem,

  /// Aynı ürün için önceki satın alma henüz bitmedi (çift dokunma).
  busy,

  /// Kayıt yazılamadı: hiçbir şey değişmedi, simit düşülmedi.
  saveFailed,
}

/// Satın alma (saf): bakiye ve sahiplik kontrolü + harcama + sahiplik tek adımda.
/// Başarısız her durumda profil aynen döner (simit düşülmez).
(PlayerProgress, PurchaseResult) purchaseCosmetic(PlayerProgress p, String id) {
  final c = cosmeticById(id);
  if (c == null) return (p, PurchaseResult.unknownItem);
  if (ownsCosmetic(p, id)) return (p, PurchaseResult.alreadyOwned);
  if (p.level < c.minLevel) return (p, PurchaseResult.levelLocked);
  final spent = p.trySpend(c.price);
  if (spent == null) return (p, PurchaseResult.insufficientFunds);
  return (
    spent.copyWith(unlockedCosmetics: {...p.unlockedCosmetics, id}),
    PurchaseResult.purchased,
  );
}

/// Görünüm seçimi (saf). Sahip olunmayan ya da bilinmeyen görünüm seçilemez (null).
PlayerProgress? equipCosmetic(PlayerProgress p, String id) {
  if (cosmeticById(id) == null || !ownsCosmetic(p, id)) return null;
  if (p.selectedCosmetic == id) return p;
  return p.copyWith(selectedCosmetic: id);
}
