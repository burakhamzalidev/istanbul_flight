/// Phase 2.6.3: bölgelere hafif atmosfer çeşitliliği (docs/19 §6a).
///
/// **Yalnızca görsel ve ses**: oynanışı etkilemez (fizik, engel, çarpışma aynı). Efektler engellerin arkasında
/// çizilir; sis ya da yağmur hiçbir engeli örtmez. Seçim görsel rastgelelikle yapılır (oynanış RNG'si
/// okunmaz); Günün Uçuşu'nda hava hep açıktır (her oyuncu aynı görüntüyü görür).
enum Weather { clear, rain, fog, windy }

abstract final class WeatherRules {
  /// Bölge girişinde açık dışı bir havanın gelme olasılığı.
  static const chance = 0.4;

  /// Bölgenin olası havaları (sıra = bölge kimliği). İklim ve saatle uyumlu: sabah sisi (Haliç), gece sisi
  /// (Rumeli), bahar rüzgârı (Emirgan, Ortaköy), yağmur (Galata, Köprü, Üsküdar).
  static const options = <List<Weather>>[
    [Weather.fog], // Haliç · şafak
    [Weather.rain], // Galata · gündüz
    [], // Kız Kulesi · gün batımı (açık)
    [Weather.rain], // Boğaz Köprüsü · akşam
    [Weather.fog], // Rumeli Hisarı · gece
    [Weather.windy], // Emirgan · bahar sabahı
    [Weather.windy], // Ortaköy · açık öğle
    [], // Dolmabahçe · öğleden sonra (açık)
    [Weather.rain], // Üsküdar · akşamüstü
  ];

  /// [roll] ve [pick] 0..1 (görsel rastgelelik).
  static Weather pick(int zone, double roll, double pick) {
    final o = zone >= 0 && zone < options.length
        ? options[zone]
        : const <Weather>[];
    if (o.isEmpty || roll >= chance) return Weather.clear;
    return o[(pick * o.length).floor().clamp(0, o.length - 1)];
  }
}
