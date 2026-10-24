import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/challenge/daily_challenge.dart';
import 'package:istanbul_flight/challenge/daily_service.dart';
import 'package:istanbul_flight/challenge/daily_state.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/game_services.dart';
import 'package:istanbul_flight/progression/game_events.dart';
import 'package:istanbul_flight/services/game_center/game_center.dart';
import 'package:istanbul_flight/services/game_center/game_center_controller.dart';
import 'package:istanbul_flight/services/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_center_fakes.dart';

// Phase 2.5: günlük deneme hakları, saat, ödüller, kayıt ve Game Center kuralları (docs/17 §5–§9, §12).

final _day = DateTime.utc(2026, 10, 24, 12);
final _def = DailyGenerators.forDay(_day);

/// Arka plandaki Game Center gönderimlerinin bitmesini bekler.
Future<void> _idle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

RunResult _run(
  String id,
  int score, {
  RunMode mode = RunMode.dailyRanked,
  String? challengeId,
  bool assisted = false,
}) => RunResult(
  runId: id,
  score: score,
  obstaclesPassed: score,
  simits: 0,
  nearMisses: 0,
  maxZone: 0,
  flightMs: 2000 + score * 1400,
  assisted: assisted,
  mode: mode,
  challengeId: mode == RunMode.classic ? null : challengeId ?? _def.challengeId,
);

/// Bellekte ilerleme denetleyicisi + saat.
class _Env {
  _Env({PlayerProgress progress = const PlayerProgress()})
    : repo = InMemoryProgressRepository(progress) {
    controller = ProgressController(repo, progress, clock: () => now);
  }

  DateTime now = _day;
  final InMemoryProgressRepository repo;
  late final ProgressController controller;

  DailyChallengeRecord? get record =>
      controller.value.dailyChallenge[_def.challengeId];

  DailyBeginResult begin(
    String id, {
    DailyChallengeDefinition? def,
    String? trusted,
  }) => controller.beginDailyAttempt(def ?? _def, id, trustedDay: trusted);

  /// Başlat + bitir (dereceli).
  DailyRunOutcome? play(String id, int score) {
    expect(begin(id), DailyBeginResult.started);
    controller.settle(_run(id, score));
    return controller.lastDaily.value;
  }
}

void main() {
  group('Dereceli deneme hakları', () {
    test('ilk, ikinci, üçüncü deneme; dördüncüsü reddedilir', () {
      final e = _Env();
      expect(e.play('a', 4)!.attemptNumber, 1);
      expect(e.record!.remaining, 2);
      expect(e.play('b', 9)!.attemptNumber, 2);
      final third = e.play('c', 7)!;
      expect(third.attemptNumber, 3);
      expect(third.remaining, 0);
      expect(e.record!.completedAt, isNotNull);
      expect(e.begin('d'), DailyBeginResult.noAttempts);
      expect(e.record!.used, 3);
    });

    test(
      'hak uçuş başlarken harcanır ve hemen kaydedilir (uçuş bitmeden)',
      () async {
        final e = _Env();
        e.begin('a');
        await e.controller.flush();
        final saved = await e.repo.load();
        expect(saved.dailyChallenge[_def.challengeId]!.remaining, 2);
        expect(
          saved.dailyChallenge[_def.challengeId]!.attempts.single.status,
          DailyAttemptStatus.started,
        );
      },
    );

    test('uygulama uçuşta kapanırsa açılışta "kesildi" olur; hak geri gelmez, skor sayılmaz', () {
      final e = _Env();
      e.begin('a');
      e.controller.recoverDaily();
      final a = e.record!.attempts.single;
      expect(a.status, DailyAttemptStatus.interrupted);
      expect(e.record!.remaining, 2);
      // geç gelen sonuç (ör. aynı kimlik) yok sayılır
      e.controller.settle(_run('a', 50));
      expect(e.record!.bestScore, 0);
    });

    test('yarıda bırakılan uçuş hak harcar; skor ve ödül yok', () {
      final e = _Env();
      e.begin('a');
      e.controller.onGameEvent(const RunAbandoned('a'));
      expect(e.record!.attempts.single.status, DailyAttemptStatus.abandoned);
      expect(e.record!.remaining, 2);
      expect(e.record!.claimed, isEmpty);
    });

    test('aynı uçuş iki kez başlatılamaz ya da iki kez bitirilemez', () {
      final e = _Env();
      expect(e.begin('a'), DailyBeginResult.started);
      expect(e.begin('a'), DailyBeginResult.duplicate);
      e.controller.settle(_run('a', 20));
      final xp = e.controller.value.xp;
      final simits = e.controller.value.simitBalance;
      expect(e.controller.settle(_run('a', 20)), isNull);
      expect(e.controller.value.xp, xp);
      expect(e.controller.value.simitBalance, simits);
      expect(e.record!.used, 1);
    });

    test('başlatılmamış bir dereceli uçuş sonucu kabul edilmez', () {
      final e = _Env();
      e.controller.settle(_run('hayalet', 80));
      expect(e.record, isNull);
      expect(e.controller.lastDaily.value, isNull);
    });

    test('antrenman hak harcamaz, kayıt ve ödül değiştirmez', () {
      final e = _Env();
      e.play('a', 3);
      final before = e.controller.value;
      e.controller.settle(_run('p1', 70, mode: RunMode.dailyPractice));
      final o = e.controller.lastDaily.value!;
      expect(o.ranked, isFalse);
      expect(o.rewards, isEmpty);
      expect(e.record!.used, 1);
      expect(e.record!.bestScore, 3);
      // günlük ödül yok (normal uçuş ilerlemesi, ör. görevler, ayrıca işleyebilir)
      expect(
        e.record!.claimed,
        before.dailyChallenge[_def.challengeId]!.claimed,
      );
    });

    test(
      'gün değişince yeni challenge üç hakla başlar; dünün kaydı korunur',
      () {
        final e = _Env();
        e.play('a', 5);
        e.play('b', 6);
        e.play('c', 7);
        e.now = _day.add(const Duration(days: 1));
        final tomorrow = DailyGenerators.forDay(e.now);
        expect(
          e.controller.beginDailyAttempt(tomorrow, 'd'),
          DailyBeginResult.started,
        );
        expect(
          e.controller.value.dailyChallenge[tomorrow.challengeId]!.remaining,
          2,
        );
        expect(e.record!.bestScore, 7);
      },
    );

    test('dünün challenge\'ı bugün dereceli başlatılamaz', () {
      final e = _Env();
      e.now = _day.add(const Duration(days: 1));
      expect(e.begin('a'), DailyBeginResult.notToday);
    });
  });

  group('Cihaz saati', () {
    test('saati geri almak hak ya da ödül açmaz: dereceli kapanır', () {
      final e = _Env();
      e.now = _day.add(const Duration(days: 1));
      final tomorrow = DailyGenerators.forDay(e.now);
      e.controller.beginDailyAttempt(tomorrow, 'x');
      // saat bir gün geri
      e.now = _day;
      expect(e.begin('a'), DailyBeginResult.clockProblem);
      expect(
        checkDailyClock(e.controller.value.dailyChallenge, e.now),
        DailyClockStatus.rolledBack,
      );
    });

    test('saati ileri almak tamamlanmış günün haklarını yenilemez', () {
      final e = _Env();
      e.play('a', 1);
      e.play('b', 1);
      e.play('c', 1);
      e.now = _day.add(const Duration(days: 3)); // ileri
      e.now = _day; // geri: aynı gün
      expect(e.begin('d'), DailyBeginResult.noAttempts);
    });

    test(
      'Apple\'ın günü (Game Center) cihazınkinden farklıysa dereceli kapanır',
      () {
        final e = _Env();
        expect(
          e.begin('a', trusted: '2026-10-23'),
          DailyBeginResult.clockProblem,
        );
        expect(e.begin('a', trusted: '2026-10-24'), DailyBeginResult.started);
      },
    );

    test(
      'çevrimdışı (Apple günü bilinmiyor): cihaz günüyle dereceli oynanır',
      () {
        final e = _Env();
        expect(e.begin('a'), DailyBeginResult.started);
      },
    );

    test('servis: Apple dönemi yalnızca 00:00 UTC + 24 saat biçimindeyse güvenilir', () {
      final s = DailyChallengeService(clock: () => _day);
      s.setOccurrence(
        GcOccurrence(
          start: DateTime.utc(2026, 10, 24),
          end: DateTime.utc(2026, 10, 25),
        ),
      );
      expect(s.trustedDay, '2026-10-24');
      // İstanbul gece yarısına kurulmuş (yanlış) tablo: yok sayılır, dereceli oyun kapanmaz
      s.setOccurrence(
        GcOccurrence(
          start: DateTime.utc(2026, 10, 23, 21),
          end: DateTime.utc(2026, 10, 24, 21),
        ),
      );
      expect(s.trustedDay, isNull);
      s.setOccurrence(
        GcOccurrence(
          start: DateTime.utc(2026, 10, 24),
          end: DateTime.utc(2026, 10, 31),
        ),
      );
      expect(s.trustedDay, isNull);
      s.setOccurrence(null);
      expect(s.trustedDay, isNull);
    });

    test('servis: sıfırlanmaya kalan süre UTC gece yarısına göre', () {
      final s = DailyChallengeService(
        clock: () => DateTime.utc(2026, 10, 24, 21, 30),
      );
      expect(s.timeToReset(), const Duration(hours: 2, minutes: 30));
    });
  });

  group('Günlük skor ve ödüller', () {
    test('günlük rekor ve önceki denemeye göre fark', () {
      final e = _Env();
      final a = e.play('a', 12)!;
      expect(a.newBest, isTrue);
      expect(a.diffFromPrevious, isNull);
      final b = e.play('b', 8)!;
      expect(b.newBest, isFalse);
      expect(b.bestScore, 12);
      expect(b.diffFromPrevious, -4);
      final c = e.play('c', 20)!;
      expect(c.newBest, isTrue);
      expect(c.diffFromPrevious, 12);
      expect(e.record!.bestScore, 20);
      expect(e.record!.bestRunId, 'c');
    });

    test(
      'ödüller tek seferlik: ilk uçuş XP\'si ve eşik simitleri tekrar verilmez',
      () {
        final e = _Env();
        final p0 = e.controller.value;
        final a = e.play('a', 16)!; // ilk uçuş + 15 eşiği
        expect(a.rewards, [
          DailyRewardPolicy.firstFlightKey,
          DailyRewardPolicy.scoreKey(15),
        ]);
        expect(a.xp, 5);
        expect(a.simits, 10);
        final b = e.play('b', 40)!; // 15 tekrar yok, 35 yeni
        expect(b.rewards, [DailyRewardPolicy.scoreKey(35)]);
        expect(b.simits, 15);
        final c = e.play('c', 70)!; // yalnızca 60
        expect(c.rewards, [DailyRewardPolicy.scoreKey(60)]);
        final p = e.controller.value;
        expect(
          p.bonusSimits - p0.bonusSimits,
          greaterThanOrEqualTo(10 + 15 + 20),
        );
        expect(e.record!.claimed.length, 4);
      },
    );

    test('günlük ödül, günlük görev ödülleriyle çakışmaz (ayrı defter)', () {
      final e = _Env();
      e.play('a', 16);
      expect(
        e.controller.value.rewardedMissions.where(
          (k) => k.contains('first_flight'),
        ),
        isEmpty,
      );
      expect(e.record!.claimed, contains(DailyRewardPolicy.firstFlightKey));
    });

    test('bakiye negatife düşmez; ödüller harcamadan bağımsız', () {
      final e = _Env(
        progress: const PlayerProgress(totalSimits: 5, spentSimits: 5),
      );
      e.play('a', 20);
      expect(e.controller.value.simitBalance, greaterThanOrEqualTo(10));
      expect(e.controller.value.trySpend(-1), isNull);
    });

    test('klasik uçuş günlük kayda dokunmaz; günlük uçuş normal uçuş ilerlemesini de işler', () {
      final e = _Env();
      e.controller.settle(_run('k', 30, mode: RunMode.classic));
      expect(e.controller.value.dailyChallenge.records, isEmpty);
      expect(e.controller.lastDaily.value, isNull);
      final flights = e.controller.value.flights;
      e.play('a', 5);
      expect(e.controller.value.flights, flights + 1);
    });
  });

  group('Kayıt ve geçiş', () {
    test('günlük kayıt JSON\'da kayıpsız gidip gelir', () {
      final e = _Env();
      e.play('a', 16);
      e.begin('b');
      final json = jsonDecode(
        jsonEncode(e.controller.value.toJson()),
      ) as Map<String, Object?>;
      final back = PlayerProgress.fromJson(json);
      final r = back.dailyChallenge[_def.challengeId]!;
      expect(r.bestScore, 16);
      expect(r.attempts.map((a) => a.status), [
        DailyAttemptStatus.finished,
        DailyAttemptStatus.started,
      ]);
      expect(r.claimed, e.record!.claimed);
      expect(r.seed, _def.seed);
      expect(back.dailyChallenge.highWaterDay, '2026-10-24');
      expect(json['v'], 4);
    });

    test(
      '1.4.0 (v3) kaydı: her şey korunur, günlük kayıt boş başlar',
      () async {
        final v3 =
            const PlayerProgress(xp: 345, totalSimits: 80, flights: 12).toJson()
              ..remove('dailyChallenge')
              ..['v'] = 3;
        SharedPreferences.setMockInitialValues({
          'progress_v2': jsonEncode(v3),
          'best_score_v1': 44,
        });
        final prefs = await SharedPreferences.getInstance();
        final p = await SharedPrefsProgressRepository(
          prefs,
          clock: () => _day,
        ).load();
        expect(p.xp, 345);
        expect(p.totalSimits, 80);
        expect(p.flights, 12);
        expect(p.dailyChallenge.records, isEmpty);
        expect(prefs.getInt('best_score_v1'), 44);
      },
    );

    test('eski sürüm günlük alanı düşürürse yedekten geri gelir; hak ve ödül yenilenmez', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsProgressRepository(prefs, clock: () => _day);
      final e = _Env();
      e.play('a', 40);
      await repo.save(e.controller.value);
      // eski sürüm (1.4.0) ana kaydı alanı tanımadan yazar
      final raw =
          jsonDecode(prefs.getString('progress_v2')!) as Map<String, Object?>;
      raw.remove('dailyChallenge');
      await prefs.setString('progress_v2', jsonEncode(raw));
      final back = await repo.load();
      final r = back.dailyChallenge[_def.challengeId]!;
      expect(r.used, 1);
      expect(r.claimed, contains(DailyRewardPolicy.scoreKey(35)));
    });

    test('bozuk günlük alanı diğer alanları etkilemez; bozuk deneme harcanmış sayılır', () {
      final p = PlayerProgress.fromJson({
        'v': 4,
        'xp': 120,
        'dailyChallenge': {
          'records': {
            'daily_2026_10_24': {
              'challengeId': 'daily_2026_10_24',
              'attempts': [
                {'runId': 'a', 'status': '???', 'score': 'çok'},
                'bozuk',
              ],
              'bestScore': -5,
              'claimed': [1, 'first_flight'],
            },
            'çöp': {'challengeId': 'daily_2026_02_30'},
          },
          'highWaterDay': 'dün',
        },
      });
      expect(p.xp, 120);
      final r = p.dailyChallenge['daily_2026_10_24']!;
      expect(r.attempts.single.status, DailyAttemptStatus.interrupted);
      expect(r.bestScore, 0);
      expect(r.claimed, {'first_flight'});
      expect(p.dailyChallenge.records.length, 1);
      expect(p.dailyChallenge.highWaterDay, isNull);
      expect(
        PlayerProgress.fromJson({'dailyChallenge': 'bozuk'})
            .dailyChallenge
            .records,
        isEmpty,
      );
    });

    test('saklama: en fazla 30 günün kaydı tutulur, en eskiler düşer', () {
      var s = DailyChallengeState.empty;
      for (var d = 0; d < 40; d++) {
        final def = DailyGenerators.forDay(_day.add(Duration(days: d)));
        s = s.withRecord(
          DailyChallengeRecord.forDefinition(def),
          day: def.dayKey,
        );
      }
      expect(s.records.length, DailyRules.keepRecords);
      expect(
        s.records.keys.reduce((a, b) => a.compareTo(b) < 0 ? a : b),
        'daily_2026_11_03',
      );
      expect(s.highWaterDay, '2026-12-02');
    });
  });

  group('Game Center günlük tablo', () {
    late FakeGameCenterApi api;
    late InMemoryGameCenterStore store;
    late _Env env;
    late GameCenterController gc;
    late GameServices services;

    setUp(() async {
      api = FakeGameCenterApi()..dayStart = DateTime.utc(2026, 10, 24);
      store = InMemoryGameCenterStore(const GcRecord(legacyExported: true));
      env = _Env();
      gc = GameCenterController(
        api: api,
        store: store,
        progress: env.controller,
        scores: InMemoryScoreRepository(),
        clock: () => env.now,
      );
      services = GameServices.silent();
      // GameServices bağlantısı: durum günlük kayda yazılır
      gc.onDailyStatus = env.controller.markDailyGc;
      await gc.start();
    });

    Future<void> finish(
      String id,
      int score, {
      RunMode mode = RunMode.dailyRanked,
    }) async {
      if (mode == RunMode.dailyRanked) env.begin(id);
      final r = _run(id, score, mode: mode);
      env.controller.settle(r);
      await gc.handleRun(r);
      await _idle();
    }

    test(
      'günlük skor yalnızca günlük tabloya gider; klasik tablolara gitmez',
      () async {
        await finish('a', 21);
        expect(api.submissions.map((s) => s.$1).toSet(), {GcBoard.daily});
        expect(api.best[GcBoard.daily], 21);
        expect(api.submittedOccurrences.last, DateTime.utc(2026, 10, 24));
        expect(env.record!.gcStatus, DailyGcStatus.submitted);
        expect(services.daily, isNotNull);
      },
    );

    test(
      'antrenman hiçbir tabloya gitmez; klasik uçuş günlük tabloya gitmez',
      () async {
        await finish('p', 33, mode: RunMode.dailyPractice);
        await gc.handleRun(_run('k', 12, mode: RunMode.classic));
        await _idle();
        expect(api.submissions.where((s) => s.$1 == GcBoard.daily), isEmpty);
        expect(api.submissions.map((s) => s.$1), contains(GcBoard.allTime));
      },
    );

    test('çevrimdışı: kuyrukta kalır, kalıcıdır; bağlantı gelince aynı günün dönemine gider', () async {
      api.offline = true;
      await finish('a', 15);
      expect(env.record!.gcStatus, DailyGcStatus.pending);
      expect(store.record.dailyPending[_def.challengeId]!.score, 15);
      expect(gc.value.pendingCount, greaterThanOrEqualTo(1));
      // daha iyi skor: tek kayıt, en iyisi
      await finish('b', 18);
      expect(store.record.dailyPending.length, 1);
      expect(store.record.dailyPending[_def.challengeId]!.score, 18);
      api.offline = false;
      await gc.flush();
      await _idle();
      expect(api.best[GcBoard.daily], 18);
      expect(store.record.dailyPending, isEmpty);
      expect(env.record!.gcStatus, DailyGcStatus.submitted);
    });

    test(
      'günlük dönem değiştiyse eski skor yeni günün tablosuna gönderilmez',
      () async {
        api.offline = true;
        await finish('a', 15);
        // ertesi gün bağlantı geldi: Apple'ın açık dönemi artık 25 Ekim
        env.now = _day.add(const Duration(days: 1));
        api
          ..offline = false
          ..dayStart = DateTime.utc(2026, 10, 25);
        await gc.flush();
        expect(api.submissions.where((s) => s.$1 == GcBoard.daily), isEmpty);
        expect(store.record.dailyPending, isEmpty);
        expect(env.record!.gcStatus, DailyGcStatus.expired);
      },
    );

    test(
      'cihaz saati ileri: yarının parkuru bugünün tablosuna gönderilmez',
      () async {
        // cihaz 25 Ekim diyor, Apple hâlâ 24 Ekim
        env.now = _day.add(const Duration(days: 1));
        final tomorrow = DailyGenerators.forDay(env.now);
        env.controller.beginDailyAttempt(tomorrow, 'x');
        final r = _run('x', 30, challengeId: tomorrow.challengeId);
        env.controller.settle(r);
        await gc.handleRun(r);
        await _idle();
        expect(api.submissions.where((s) => s.$1 == GcBoard.daily), isEmpty);
        expect(
          env.controller.value.dailyChallenge[tomorrow.challengeId]!.gcStatus,
          DailyGcStatus.expired,
        );
      },
    );

    test(
      'uygunsuz uçuş (geliştirme yardımı) gönderilmez ve işaretlenir',
      () async {
        env.begin('a');
        final r = _run('a', 40, assisted: true);
        env.controller.settle(r);
        await gc.handleRun(r);
        await _idle();
        expect(api.submissions, isEmpty);
        expect(env.record!.gcStatus, DailyGcStatus.notEligible);
      },
    );

    test(
      'gönderim tekrarı: aynı uçuş iki kez işlense de bir kez gönderilir',
      () async {
        await finish('a', 22);
        await gc.handleRun(_run('a', 22));
        expect(api.submissions.where((s) => s.$1 == GcBoard.daily).length, 1);
      },
    );

    test(
      'Apple günlük dönemi okunur ve servise iletilir (saat denetimi)',
      () async {
        GcOccurrence? got;
        gc.onDailyOccurrence = (o) => got = o;
        await gc.refreshDailyOccurrence();
        expect(got!.start, DateTime.utc(2026, 10, 24));
        api.offline = true;
        await gc.refreshDailyOccurrence();
        expect(got, isNull);
      },
    );

    test('GameServices bağlantısı: Game Center durumu günlük kayda, Apple günü servise gider', () async {
      final progress = ProgressController(
        InMemoryProgressRepository(),
        const PlayerProgress(),
        clock: () => _day,
      );
      final controller = GameCenterController(
        api: api,
        store: InMemoryGameCenterStore(const GcRecord(legacyExported: true)),
        progress: progress,
        scores: InMemoryScoreRepository(),
        clock: () => _day,
      );
      final s = GameServices.silent();
      final wired = GameServices(
        audio: s.audio,
        haptics: s.haptics,
        settings: s.settings,
        progress: progress,
        share: s.share,
        gameCenter: controller,
        daily: DailyChallengeService(clock: () => _day),
      );
      await controller.start();
      await controller.refreshDailyOccurrence();
      expect(wired.daily.trustedDay, '2026-10-24');
      progress.beginDailyAttempt(_def, 'w');
      wired.emit(RunFinished(_run('w', 9)));
      await Future<void>.delayed(Duration.zero);
      await controller.flush();
      expect(
        progress.value.dailyChallenge[_def.challengeId]!.gcStatus,
        DailyGcStatus.submitted,
      );
    });
  });

  test('GcRecord: bekleyen günlük skorlar kalıcı; bozuk girdiler atlanır', () {
    final r = GcRecord(
      dailyPending: {
        'daily_2026_10_24': GcDailyPending(score: 12, achievedAt: _day),
      },
    );
    final back = GcRecord.fromJson(jsonDecode(jsonEncode(r.toJson())));
    expect(back.dailyPending['daily_2026_10_24']!.score, 12);
    final bad = GcRecord.fromJson({
      'v': 2,
      'dailyPending': {
        'daily_2026_10_24': {'score': -3, 'achievedAt': 'x'},
        'haftalık': {'score': 5, 'achievedAt': _day.toIso8601String()},
      },
    });
    expect(bad.dailyPending, isEmpty);
    // 1.4.0 kaydı (v1): dailyPending yok
    expect(GcRecord.fromJson({'v': 1, 'pendingBest': 4}).dailyPending, isEmpty);
  });

  test('ValueNotifier ilerleme ile de Game Center denetleyicisi kurulur (eski API)', () {
    expect(
      GameCenterController(
        api: FakeGameCenterApi(),
        store: InMemoryGameCenterStore(),
        progress: ValueNotifier(const PlayerProgress()),
        scores: InMemoryScoreRepository(),
      ).value.dailyPending,
      0,
    );
  });
}
