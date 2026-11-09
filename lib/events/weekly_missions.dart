import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../challenge/daily_rng.dart';
import '../progression/game_events.dart';

// Phase 2.7: haftalık görevler (docs/20 §9). Günlük görevlerden ayrıdır: kendi kaydı, kendi haftası (UTC,
// kupayla aynı), kendi ödül defteri anahtarı (`week:<hafta>:<görev>`). İlerleme aynı uçuş sonu olayından
// (RunResult) beslenir.

enum WeeklyMissionKind {
  /// Haftalık kupada N uçuş (dereceli kupa uçuşları).
  cupFlights,

  /// Herhangi bir modda tek uçuşta N skor (geçilen engel).
  singleRunScore,

  /// Etkinliklerde (kupa + özel) toplam N simit.
  eventSimits,

  /// Tek uçuşta N farklı bölgeden geç.
  zonesInRun,

  /// Haftalık kupada en iyi skorunu N kez geliştir (ilk uçuş sayılmaz).
  improveCupBest,
}

@immutable
class WeeklyMissionTemplate {
  const WeeklyMissionTemplate(this.kind, this.targets);

  final WeeklyMissionKind kind;

  /// Kademeye göre hedef (yeni, orta, deneyimli oyuncu).
  final List<int> targets;
}

abstract final class WeeklyMissionCatalog {
  static const perWeek = 4;

  static const templates = <WeeklyMissionTemplate>[
    WeeklyMissionTemplate(WeeklyMissionKind.cupFlights, [3, 5, 8]),
    WeeklyMissionTemplate(WeeklyMissionKind.singleRunScore, [40, 70, 100]),
    WeeklyMissionTemplate(WeeklyMissionKind.eventSimits, [15, 30, 45]),
    WeeklyMissionTemplate(WeeklyMissionKind.zonesInRun, [2, 3, 4]),
    WeeklyMissionTemplate(WeeklyMissionKind.improveCupBest, [1, 2, 3]),
  ];

  /// Görev başına: sezon puanı ve simit (XP yok: sezon ilerlemesi XP'den ayrı).
  static const seasonPoints = 20;
  static const simits = 10;

  static int tierFor(int level) => level < 3
      ? 0
      : level < 8
      ? 1
      : 2;

  static String title(WeeklyMissionKind k, int target) => switch (k) {
    WeeklyMissionKind.cupFlights => 'Haftalık kupada $target uçuş yap',
    WeeklyMissionKind.singleRunScore => 'Tek uçuşta $target puana ulaş',
    WeeklyMissionKind.eventSimits => 'Etkinliklerde $target simit topla',
    WeeklyMissionKind.zonesInRun =>
      'Tek uçuşta $target farklı İstanbul bölgesinden geç',
    WeeklyMissionKind.improveCupBest => target == 1
        ? 'Haftalık en iyi skorunu geliştir'
        : 'Haftalık en iyi skorunu $target kez geliştir',
  };
}

@immutable
class WeeklyMission {
  const WeeklyMission({
    required this.kind,
    required this.target,
    this.progress = 0,
  });

  final WeeklyMissionKind kind;
  final int target;
  final int progress;

  String get id => kind.name;
  bool get completed => progress >= target;
  double get fraction => target <= 0 ? 1 : (progress / target).clamp(0, 1);
  String get title => WeeklyMissionCatalog.title(kind, target);

  /// Uçuşu uygular. [cup]: dereceli kupa uçuşu; [event]: dereceli etkinlik uçuşu (kupa ya da özel);
  /// [improvedCupBest]: bu uçuş haftalık kupa rekorunu (önceki > 0) geliştirdi.
  WeeklyMission advance(
    RunResult r, {
    required bool cup,
    required bool event,
    required bool improvedCupBest,
  }) {
    final zonesSeen = r.zoneStats.isEmpty
        ? 1
        : r.zoneStats.values.where((s) => s.obstacles > 0).length;
    final next = switch (kind) {
      WeeklyMissionKind.cupFlights => progress + (cup ? 1 : 0),
      WeeklyMissionKind.singleRunScore => math.max(progress, r.obstaclesPassed),
      WeeklyMissionKind.eventSimits => progress + (event ? r.simits : 0),
      WeeklyMissionKind.zonesInRun => math.max(progress, zonesSeen),
      WeeklyMissionKind.improveCupBest => progress + (improvedCupBest ? 1 : 0),
    };
    return WeeklyMission(
      kind: kind,
      target: target,
      progress: next.clamp(0, target),
    );
  }

  Map<String, Object> toJson() => {
    'kind': kind.name,
    'target': target,
    'progress': progress,
  };

  static WeeklyMission? fromJson(Object? j) {
    if (j is! Map) return null;
    final kind = WeeklyMissionKind.values.asNameMap()[j['kind']];
    final target = j['target'], progress = j['progress'];
    if (kind == null || target is! int || target <= 0) return null;
    return WeeklyMission(
      kind: kind,
      target: target,
      progress: progress is int ? progress.clamp(0, target) : 0,
    );
  }
}

/// Bir UTC haftasının görevleri.
@immutable
class WeeklyMissions {
  const WeeklyMissions({required this.weekKey, required this.missions});

  /// ISO hafta anahtarı (`2026-W46`).
  final String weekKey;
  final List<WeeklyMission> missions;

  /// Haftanın görevleri: hafta anahtarından türetilen sabit tohumla (her cihazda ve her açılışta aynı).
  factory WeeklyMissions.generate(String weekKey, {required int level}) {
    final tier = WeeklyMissionCatalog.tierFor(level);
    final pool = [...WeeklyMissionCatalog.templates];
    final rng = DailyRng(DailyRng.hash('weekly_missions/$weekKey'));
    final picked = <WeeklyMissionTemplate>[];
    while (picked.length < WeeklyMissionCatalog.perWeek && pool.isNotEmpty) {
      picked.add(pool.removeAt((rng.nextDouble() * pool.length).floor()));
    }
    return WeeklyMissions(
      weekKey: weekKey,
      missions: [
        for (final t in picked) WeeklyMission(kind: t.kind, target: t.targets[tier]),
      ],
    );
  }

  int get completedCount => missions.where((m) => m.completed).length;

  WeeklyMissions withMissions(List<WeeklyMission> m) =>
      WeeklyMissions(weekKey: weekKey, missions: m);

  Map<String, Object> toJson() => {
    'week': weekKey,
    'missions': [for (final m in missions) m.toJson()],
  };

  static WeeklyMissions? fromJson(Object? j) {
    if (j is! Map) return null;
    final week = j['week'], list = j['missions'];
    if (week is! String ||
        !RegExp(r'^\d{4}-W\d{2}$').hasMatch(week) ||
        list is! List) {
      return null;
    }
    final missions = list.map(WeeklyMission.fromJson).nonNulls.toList();
    if (missions.isEmpty) return null;
    return WeeklyMissions(weekKey: week, missions: missions);
  }
}
