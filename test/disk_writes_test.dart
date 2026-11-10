import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/progression/discovery.dart';
import 'package:istanbul_flight/services/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Phase 2.9 (docs/22 §8): değişmeyen yedek anahtarlar yeniden yazılmaz; kayıt ve yedekler eksiksiz kalır.

void main() {
  late SharedPreferences prefs;
  late SharedPrefsProgressRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = SharedPrefsProgressRepository(prefs);
  });

  test('ilk kayıt: ana kayıt + 3 yedek yazılır', () async {
    await repo.save(const PlayerProgress(flights: 1));
    expect(repo.writes, 4);
    for (final k in [
      SharedPrefsProgressRepository.key,
      SharedPrefsProgressRepository.discoveryBackupKey,
      SharedPrefsProgressRepository.dailyBackupKey,
      SharedPrefsProgressRepository.eventsBackupKey,
    ]) {
      expect(prefs.getString(k), isNotNull, reason: k);
    }
  });

  test('sıradan uçuş sonu: yalnızca ana kayıt yazılır (yedekler değişmedi)', () async {
    await repo.save(const PlayerProgress(flights: 1));
    final w = repo.writes;
    await repo.save(const PlayerProgress(flights: 2, totalScore: 40));
    expect(repo.writes - w, 1);
    expect(
      jsonDecode(prefs.getString(SharedPrefsProgressRepository.key)!)['flights'],
      2,
    );
  });

  test('albüm değişince keşif yedeği de yazılır; değişmeyen kayıt hiç yazılmaz', () async {
    await repo.save(const PlayerProgress(flights: 1));
    final w = repo.writes;
    final p = PlayerProgress(
      flights: 2,
      discoveredZones: const {0},
      discovery: DiscoveryState(firstSeen: {0: DateTime.utc(2026, 11, 11)}),
    );
    await repo.save(p);
    expect(repo.writes - w, 2);
    await repo.save(p);
    expect(repo.writes - w, 2, reason: 'aynı kayıt ikinci kez yazılmaz');
  });

  test('kaydedilen veri olduğu gibi geri okunur', () async {
    final p = PlayerProgress(
      flights: 7,
      totalScore: 300,
      totalSimits: 25,
      discoveredZones: const {0, 1},
      discovery: DiscoveryState(firstSeen: {0: DateTime.utc(2026, 11, 11), 1: DateTime.utc(2026, 11, 11)}),
    );
    await repo.save(p);
    await repo.save(p.copyWith(flights: 8));
    final loaded = await SharedPrefsProgressRepository(prefs).load();
    expect(loaded.flights, 8);
    expect(loaded.totalScore, 300);
    expect(loaded.discoveredZones, {0, 1});
  });

  test('önceki süreçte yazılmış aynı yedek yeniden yazılmaz (diskteki değerle karşılaştırılır)', () async {
    await repo.save(const PlayerProgress(flights: 1));
    final fresh = SharedPrefsProgressRepository(prefs);
    await fresh.save(const PlayerProgress(flights: 2));
    expect(fresh.writes, 1);
  });
}
