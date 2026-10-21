import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../game/day_cycle.dart';
import 'game_events.dart';

/// Günlük görev türleri. Hepsi normal oynanışla, uçuş sonunda kendiliğinden ilerler.
enum MissionKind {
  collectSimits,
  nearMisses,
  flights,
  singleRunScore,
  reachZone,
  totalScore,
}

/// Görev şablonu: zorluk kademesine göre hedef (kolay, orta, zor).
class MissionTemplate {
  const MissionTemplate(this.kind, this.targets);

  final MissionKind kind;
  final List<int> targets;
}

abstract final class MissionCatalog {
  static const perDay = 3;

  static const templates = <MissionTemplate>[
    MissionTemplate(MissionKind.collectSimits, [5, 12, 25]),
    MissionTemplate(MissionKind.nearMisses, [2, 5, 10]),
    MissionTemplate(MissionKind.flights, [3, 5, 8]),
    MissionTemplate(MissionKind.singleRunScore, [10, 25, 45]),
    // hedef = bölge sırası (1 Galata, 2 Kız Kulesi, 3 Boğaz Köprüsü)
    MissionTemplate(MissionKind.reachZone, [1, 2, 3]),
    MissionTemplate(MissionKind.totalScore, [30, 100, 200]),
  ];

  /// Kademe başına ödül: (XP, simit).
  static const rewards = <(int, int)>[(30, 5), (50, 10), (75, 15)];

  /// Oyuncu seviyesine göre kademe: yeni oyuncular ilk dakikalarda bitirebileceği hedefler alır.
  static int tierFor(int level) => level < 3
      ? 0
      : level < 8
      ? 1
      : 2;

  /// Yeni oyuncuya (kolay kademe) bölge görevi verilmez: önce kontrolü öğrensin.
  static bool allowedAt(MissionKind kind, int tier) =>
      !(tier == 0 && kind == MissionKind.reachZone);

  static String title(MissionKind kind, int target) => switch (kind) {
    MissionKind.collectSimits => '$target simit topla',
    MissionKind.nearMisses => '$target kıl payı geçiş yap',
    MissionKind.flights => '$target uçuş tamamla',
    MissionKind.singleRunScore => 'Tek uçuşta $target puana ulaş',
    MissionKind.reachZone =>
      '${zones[target.clamp(0, zones.length - 1)].name} bölgesine ulaş',
    MissionKind.totalScore => 'Toplam $target puan kazan',
  };
}

/// Aktif bir günlük görev ve ilerlemesi.
@immutable
class DailyMission {
  const DailyMission({
    required this.kind,
    required this.target,
    required this.rewardXp,
    required this.rewardSimits,
    this.progress = 0,
  });

  final MissionKind kind;
  final int target;
  final int rewardXp;
  final int rewardSimits;
  final int progress;

  /// Gün içinde aynı tür bir kez seçildiği için tür adı kimliktir.
  String get id => kind.name;
  bool get completed => progress >= target;
  double get fraction => target <= 0 ? 1 : (progress / target).clamp(0, 1);
  String get title => MissionCatalog.title(kind, target);

  /// Uçuş sonucunu uygular. İlerleme hedefte durur.
  DailyMission advance(RunResult r) {
    final next = switch (kind) {
      MissionKind.collectSimits => progress + r.simits,
      MissionKind.nearMisses => progress + r.nearMisses,
      MissionKind.flights => progress + 1,
      MissionKind.singleRunScore => math.max(progress, r.score),
      MissionKind.reachZone => math.max(progress, r.maxZone),
      MissionKind.totalScore => progress + r.score,
    };
    return DailyMission(
      kind: kind,
      target: target,
      rewardXp: rewardXp,
      rewardSimits: rewardSimits,
      progress: next.clamp(0, target),
    );
  }

  Map<String, Object> toJson() => {
    'kind': kind.name,
    'target': target,
    'progress': progress,
    'rewardXp': rewardXp,
    'rewardSimits': rewardSimits,
  };

  /// Tanınmayan ya da bozuk kayıt null döner (o görev atlanır, diğerleri korunur).
  static DailyMission? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = MissionKind.values.where((k) => k.name == raw['kind']);
    final target = raw['target'];
    if (kind.isEmpty || target is! int || target <= 0) return null;
    int count(Object? v) => v is int && v >= 0 ? v : 0;
    return DailyMission(
      kind: kind.first,
      target: target,
      progress: count(raw['progress']).clamp(0, target),
      rewardXp: count(raw['rewardXp']),
      rewardSimits: count(raw['rewardSimits']),
    );
  }
}

/// Bir takvim gününün görevleri.
@immutable
class DailyMissions {
  const DailyMissions({required this.dayKey, required this.missions});

  /// Yerel takvim günü: "yyyy-aa-gg".
  final String dayKey;
  final List<DailyMission> missions;

  /// Günün görevleri: gün anahtarından türetilen sabit tohumla seçilir. Aynı gün aynı
  /// kademede her zaman aynı görevler çıkar (uygulamayı yeniden açmak görevleri değiştirmez).
  factory DailyMissions.generate(String dayKey, {required int level}) {
    final tier = MissionCatalog.tierFor(level);
    final pool = MissionCatalog.templates
        .where((t) => MissionCatalog.allowedAt(t.kind, tier))
        .toList();
    final rnd = math.Random(stableSeed(dayKey));
    final picked = <MissionTemplate>[];
    while (picked.length < MissionCatalog.perDay && pool.isNotEmpty) {
      picked.add(pool.removeAt(rnd.nextInt(pool.length)));
    }
    final (xp, simits) = MissionCatalog.rewards[tier];
    return DailyMissions(
      dayKey: dayKey,
      missions: [
        for (final t in picked)
          DailyMission(
            kind: t.kind,
            target: t.targets[tier],
            rewardXp: xp,
            rewardSimits: simits,
          ),
      ],
    );
  }

  int get completedCount => missions.where((m) => m.completed).length;

  DailyMissions withMissions(List<DailyMission> m) =>
      DailyMissions(dayKey: dayKey, missions: m);

  Map<String, Object> toJson() => {
    'day': dayKey,
    'missions': [for (final m in missions) m.toJson()],
  };

  static DailyMissions? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final day = raw['day'];
    final list = raw['missions'];
    if (day is! String || !isDayKey(day) || list is! List) return null;
    final missions = list.map(DailyMission.fromJson).nonNulls.toList();
    if (missions.isEmpty) return null;
    return DailyMissions(dayKey: day, missions: missions);
  }

  /// Platformdan bağımsız, sürümler arasında değişmeyen tohum (String.hashCode'a güvenilmez).
  static int stableSeed(String s) {
    var h = 17;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x3fffffff;
    }
    return h;
  }
}

/// Yerel takvim günü anahtarı. Saat dilimi ya da cihaz tarihi değişirse anahtar da değişir;
/// tekrar ödül, ödül defteri ("gün:görev") ile engellenir.
String dayKeyFor(DateTime t) {
  final l = t.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${l.year.toString().padLeft(4, '0')}-${two(l.month)}-${two(l.day)}';
}

bool isDayKey(String s) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s);

/// Bir sonraki yerel gece yarısına kalan süre (görevlerin yenilenmesi).
Duration untilNextDay(DateTime now) {
  final l = now.toLocal();
  final next = DateTime(l.year, l.month, l.day + 1);
  final d = next.difference(l);
  return d.isNegative ? Duration.zero : d;
}
