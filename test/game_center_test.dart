import 'dart:convert';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/progression/game_events.dart';
import 'package:istanbul_flight/progression/run_settlement.dart';
import 'package:istanbul_flight/services/game_center/game_center.dart';
import 'package:istanbul_flight/services/game_center/game_center_controller.dart';
import 'package:istanbul_flight/services/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';
import 'game_center_fakes.dart';

final _now = DateTime(2026, 10, 23, 12);

/// Gerçekçi (fiziğe uygun süreli) tamamlanmış uçuş.
RunResult _run(String id, int score, {bool assisted = false, int? ms}) =>
    RunResult(
      runId: id,
      score: score,
      obstaclesPassed: score,
      simits: 0,
      nearMisses: 0,
      maxZone: 0,
      flightMs: ms ?? 2000 + score * 1400,
      assisted: assisted,
    );

class _Env {
  _Env({
    FakeGameCenterApi? api,
    int best = 0,
    GcRecord record = const GcRecord(),
    PlayerProgress progress = const PlayerProgress(),
  }) : api = api ?? FakeGameCenterApi(),
       store = InMemoryGameCenterStore(record),
       scores = InMemoryScoreRepository(best),
       progress = ValueNotifier(progress);

  final FakeGameCenterApi api;
  final InMemoryGameCenterStore store;
  final InMemoryScoreRepository scores;
  final ValueNotifier<PlayerProgress> progress;
  DateTime now = _now;

  late final GameCenterController gc = GameCenterController(
    api: api,
    store: store,
    progress: progress,
    scores: scores,
    clock: () => now,
  );

  /// Bekleyen asenkron işleri bitirir (unawaited flush'lar).
  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  List<int> sent(GcBoard b) => [
    for (final (board, s) in api.submissions)
      if (board == b) s,
  ];
}

void main() {
  group('Skor kuralları (istemci tarafı tutarlılık)', () {
    test('yalnızca gerçekten oynanmış uçuşlar kabul edilir', () {
      expect(GcScorePolicy.rejectReason(_run('a', 10)), isNull);
      expect(GcScorePolicy.rejectReason(_run('a', 0)), 'zero');
      expect(
        GcScorePolicy.rejectReason(_run('a', 10, assisted: true)),
        'assisted',
      );
      expect(GcScorePolicy.rejectReason(_run('', 10)), 'no_run_id');
      expect(GcScorePolicy.rejectReason(_run('a', 10000)), 'too_high');
      // 50 engel 5 saniyede geçilemez (en yüksek hızda ~63 sn)
      expect(GcScorePolicy.rejectReason(_run('a', 50, ms: 5000)), 'too_fast');
      // demo modunun başlangıç skoru: skor geçilen engelden büyük
      expect(
        GcScorePolicy.rejectReason(
          const RunResult(
            runId: 'd',
            score: 90,
            obstaclesPassed: 3,
            simits: 0,
            nearMisses: 0,
            maxZone: 4,
            flightMs: 9000,
          ),
        ),
        'score_mismatch',
      );
    });

    test('görünüm, XP ve simit skoru etkilemez: kural yalnızca uçuş verisine bakar', () {
      final r = _run('a', 20);
      final rich = const PlayerProgress(
        xp: 99999,
        totalSimits: 9999,
        unlockedCosmetics: {'classic', 'altin'},
        selectedCosmetic: 'altin',
      );
      final s = settleRun(rich, r, _now)!;
      expect(s.progress.selectedCosmetic, 'altin');
      expect(GcScorePolicy.rejectReason(r), isNull);
      expect(r.score, 20, reason: 'skor uçuş sonucundan; profil değiştirmez');
    });
  });

  group('Bağlantı', () {
    test(
      'başarılı bağlantı: durum, eski rekorun bir kez aktarılması, başarımlar',
      () async {
        final e = _Env(
          best: 42,
          progress: PlayerProgress(
            flights: 3,
            achievements: {'first_flap': _now},
          ),
        );
        await e.gc.start();
        await e.settle();
        expect(e.gc.value.connection, GcConnection.signedIn);
        expect(e.gc.value.alias, 'Simit42');
        expect(e.sent(GcBoard.allTime), [42]);
        expect(
          e.sent(GcBoard.weekly),
          isEmpty,
          reason: 'eski skor haftalığa geçmez',
        );
        expect(e.store.record.legacyExported, isTrue);
        expect(e.store.record.pendingBest, 0);
        expect(e.api.achievements['istanbul_flight_first_flap'], 100);
        // ilerleme yüzdesi: 25 uçuşun 3'ü
        expect(e.api.achievements['istanbul_flight_loyal_gull'], 12);
        expect(
          e.api.banners.single,
          isEmpty,
          reason: 'eski başarım için bildirim yok',
        );
      },
    );

    test('oyuncu giriş yapmıyor: oyun sürer, skor kuyrukta bekler', () async {
      final e = _Env(
        api: FakeGameCenterApi(
          authResult: const GcAuthStatus(
            authenticated: false,
            error: 'cancelled',
          ),
        ),
      );
      await e.gc.start();
      await e.gc.handleRun(_run('r1', 30));
      await e.settle();
      expect(e.gc.value.connection, GcConnection.signedOut);
      expect(e.gc.value.lastError, 'cancelled');
      expect(e.api.submissions, isEmpty);
      expect(e.store.record.pendingBest, 30);
      // oyuncu Ayarlar'dan giriş yapınca bekleyen skor gönderilir
      e.api.emitStatus(const GcAuthStatus(authenticated: true, alias: 'S'));
      await e.settle();
      expect(e.sent(GcBoard.allTime), [30]);
      expect(e.store.record.pendingBest, 0);
    });

    test(
      'Game Center olmayan cihaz: hiçbir çağrı yapılmaz, durum "yok"',
      () async {
        final e = _Env(api: FakeGameCenterApi(isSupported: false));
        await e.gc.start();
        await e.gc.handleRun(_run('r1', 30));
        await e.settle();
        expect(e.gc.value.connection, GcConnection.unsupported);
        expect(e.api.authCalls, 0);
        expect(e.api.submissions, isEmpty);
      },
    );

    test(
      'devre dışı denetleyici (Android, web, testler) hata vermez',
      () async {
        final gc = GameCenterController.disabled();
        await gc.start();
        await gc.handleRun(_run('r1', 30));
        await gc.flush();
        expect(gc.value.connection, GcConnection.unsupported);
      },
    );
  });

  group('Skor gönderimi', () {
    test('başarılı: tüm zamanlar ve haftalık tabloya gider', () async {
      final e = _Env();
      await e.gc.start();
      await e.gc.handleRun(_run('r1', 50));
      await e.settle();
      expect(e.sent(GcBoard.allTime), [50]);
      expect(e.sent(GcBoard.weekly), [50]);
      expect(e.gc.value.pendingCount, 0);
    });

    test(
      'aynı uçuş iki kez gelirse tek gönderim; düşük skor tüm zamanlara gitmez',
      () async {
        final e = _Env();
        await e.gc.start();
        await e.gc.handleRun(_run('r1', 50));
        await e.gc.handleRun(_run('r1', 50));
        await e.gc.handleRun(_run('r2', 20));
        await e.settle();
        expect(e.sent(GcBoard.allTime), [50]);
        expect(e.sent(GcBoard.weekly), [
          50,
          20,
        ], reason: 'haftalık her geçerli uçuş');
        expect(e.api.best[GcBoard.allTime], 50);
      },
    );

    test('yardımlı (demo) uçuş gönderilmez', () async {
      final e = _Env();
      await e.gc.start();
      await e.gc.handleRun(_run('r1', 80, assisted: true));
      await e.settle();
      expect(e.api.submissions, isEmpty);
    });

    test(
      'internet yok: skor kaybolmaz, bağlantı gelince bir kez gönderilir',
      () async {
        final e = _Env();
        await e.gc.start();
        e.api.offline = true;
        await e.gc.handleRun(_run('r1', 40));
        await e.settle();
        expect(e.api.submissions, isEmpty);
        expect(e.store.record.pendingBest, 40);
        expect(e.gc.value.lastError, 'network');
        expect(e.gc.value.pendingCount, 2);
        e.api.offline = false;
        await e.gc.flush(); // uygulama öne gelince
        expect(e.sent(GcBoard.allTime), [40]);
        expect(e.sent(GcBoard.weekly), [40]);
        expect(e.gc.value.pendingCount, 0);
        await e.gc.flush();
        expect(e.api.submissions.length, 2, reason: 'tekrar gönderim yok');
      },
    );

    test(
      'ağ hatası sürerken daha iyi skor gelirse kuyrukta yalnız en iyisi kalır',
      () async {
        final e = _Env();
        await e.gc.start();
        e.api.offline = true;
        await e.gc.handleRun(_run('r1', 40));
        await e.gc.handleRun(_run('r2', 60));
        await e.gc.handleRun(_run('r3', 10));
        await e.settle();
        expect(e.store.record.pendingBest, 60);
        e.api.offline = false;
        await e.gc.flush();
        expect(e.sent(GcBoard.allTime), [60]);
        expect(e.sent(GcBoard.weekly), [60]);
      },
    );

    test(
      'tablo Apple tarafında henüz yoksa skor kuyrukta kalır, oyun etkilenmez',
      () async {
        final e = _Env();
        await e.gc.start();
        e.api.failCode = 'not_configured';
        await e.gc.handleRun(_run('r1', 25));
        await e.settle();
        expect(e.store.record.pendingBest, 25);
        e.api.failCode = null;
        await e.gc.flush();
        expect(e.sent(GcBoard.allTime), [25]);
      },
    );
  });

  group('Haftalık tablo', () {
    test('dönem kapalıysa ya da skor önceki döneme aitse gönderilmez, kuyruktan düşer', () async {
      final e = _Env();
      await e.gc.start();
      e.api.offline = true;
      await e.gc.handleRun(_run('r1', 33)); // 23 Ekim'de yapıldı
      // sunucu tarafında yeni hafta başladı (cihaz saatinden bağımsız)
      e.api.offline = false;
      e.api.weekStart = DateTime(2026, 10, 26);
      await e.gc.flush();
      expect(e.sent(GcBoard.weekly), isEmpty, reason: 'geçen haftanın skoru');
      expect(e.sent(GcBoard.allTime), [33]);
      expect(e.gc.value.weeklyPending, isFalse);
      // dönem arası (kapalı)
      e.api.weekStart = null;
      await e.gc.handleRun(_run('r2', 34));
      await e.settle();
      expect(e.sent(GcBoard.weekly), isEmpty);
      expect(e.gc.value.weeklyPending, isFalse);
    });

    test('haftalık bekleyen skor diske yazılmaz: uygulama yeniden açılınca taşınmaz', () async {
      final e = _Env();
      await e.gc.start();
      e.api.offline = true;
      await e.gc.handleRun(_run('r1', 33));
      await e.settle();
      final json = jsonEncode(e.store.record.toJson());
      expect(json.contains('weekly'), isFalse);
      expect(e.store.record.pendingBest, 33);
    });
  });

  group('Kalıcılık ve geçiş', () {
    test('uygulama kapatılıp açılınca bekleyen skor gönderilir; eski rekor ikinci kez aktarılmaz', () async {
      SharedPreferences.setMockInitialValues({'best_score_v1': 18});
      final prefs = await SharedPreferences.getInstance();
      final api = FakeGameCenterApi()..offline = true;
      final gc1 = GameCenterController(
        api: api,
        store: SharedPrefsGameCenterStore(prefs),
        progress: ValueNotifier(const PlayerProgress()),
        scores: SharedPrefsScoreRepository(prefs),
        clock: () => _now,
      );
      await gc1.start();
      await gc1.handleRun(_run('r1', 27));
      await Future<void>.delayed(Duration.zero);
      expect(jsonDecode(prefs.getString('game_center_v1')!), {
        'v': 2, // Phase 2.5: dailyPending alanı eklendi
        'pendingBest': 27,
        'legacyExported': true,
        'dailyPending': <String, Object>{},
      });
      // yeniden açılış, internet var
      final api2 = FakeGameCenterApi();
      final gc2 = GameCenterController(
        api: api2,
        store: SharedPrefsGameCenterStore(prefs),
        progress: ValueNotifier(const PlayerProgress()),
        scores: SharedPrefsScoreRepository(prefs),
        clock: () => _now,
      );
      await gc2.start();
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(api2.submissions, [(GcBoard.allTime, 27)]);
      expect(
        (jsonDecode(prefs.getString('game_center_v1')!) as Map)['pendingBest'],
        0,
      );
    });

    test('Game Center kaydı ilerleme ve rekor kayıtlarına dokunmaz; kimlik saklanmaz', () async {
      final progressJson = jsonEncode(
        const PlayerProgress(xp: 640, totalSimits: 90).toJson(),
      );
      SharedPreferences.setMockInitialValues({
        'progress_v2': progressJson,
        'best_score_v1': 61,
      });
      final prefs = await SharedPreferences.getInstance();
      final e = GameCenterController(
        api: FakeGameCenterApi(),
        store: SharedPrefsGameCenterStore(prefs),
        progress: ValueNotifier(const PlayerProgress()),
        scores: SharedPrefsScoreRepository(prefs),
        clock: () => _now,
      );
      await e.start();
      await e.handleRun(_run('r1', 70));
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(prefs.getString('progress_v2'), progressJson);
      expect(prefs.getInt('best_score_v1'), 61);
      final gc = prefs.getString('game_center_v1')!;
      expect(gc.contains('Simit42'), isFalse, reason: 'oyuncu adı saklanmaz');
      expect(prefs.getKeys(), {
        'progress_v2',
        'best_score_v1',
        'game_center_v1',
      });
    });

    test('bozuk Game Center kaydı sıfırdan başlar', () async {
      SharedPreferences.setMockInitialValues({'game_center_v1': '{bozuk'});
      final prefs = await SharedPreferences.getInstance();
      expect((await SharedPrefsGameCenterStore(prefs).load()).pendingBest, 0);
      expect(GcRecord.fromJson({'pendingBest': -5}).pendingBest, 0);
      expect(GcRecord.fromJson({'pendingBest': 99999999}).pendingBest, 9999);
    });
  });

  group('Başarım eşzamanlama', () {
    test('aynı yüzde tekrar gönderilmez; oturumda açılan başarım bildirim gösterir', () async {
      final e = _Env(progress: const PlayerProgress(flights: 0));
      await e.gc.start();
      await e.settle();
      final firstReports = e.api.reports.length;
      await e.gc.flush();
      expect(e.api.reports.length, firstReports, reason: 'değişiklik yok');
      // uçuş sonrası yerel başarım açıldı (yerel sistem esas)
      e.progress.value = PlayerProgress(
        flights: 1,
        achievements: {'first_flap': _now},
      );
      await e.settle();
      expect(e.api.achievements['istanbul_flight_first_flap'], 100);
      expect(e.api.banners.last, {'istanbul_flight_first_flap'});
      expect(e.api.reports.last.keys, contains('istanbul_flight_first_flap'));
    });

    test(
      'çevrimdışı kazanılan başarım bağlanınca eşitlenir; ödül tekrar verilmez',
      () async {
        final e = _Env(
          api: FakeGameCenterApi(
            authResult: const GcAuthStatus(authenticated: false),
          ),
        );
        await e.gc.start();
        final p = settleRun(
          const PlayerProgress(),
          _run('r1', 3),
          _now,
        )!.progress;
        final bonusAfter = p.bonusSimits;
        e.progress.value = p;
        await e.settle();
        expect(e.api.reports, isEmpty);
        e.api.emitStatus(const GcAuthStatus(authenticated: true));
        await e.settle();
        expect(e.api.achievements['istanbul_flight_first_flap'], 100);
        expect(
          e.progress.value.bonusSimits,
          bonusAfter,
          reason: 'Game Center ödül vermez',
        );
      },
    );

    test(
      'her yerel başarımın Game Center karşılığı var ve kimlikler benzersiz',
      () {
        final ids = GameCenterIds.achievements.values.toList();
        expect(ids.toSet().length, ids.length);
        expect(GameCenterIds.achievements.length, 9);
        for (final id in [
          ...ids,
          GameCenterIds.bestScore,
          GameCenterIds.weeklyScore,
        ]) {
          expect(
            RegExp(r'^[a-z0-9_.]{1,100}$').hasMatch(id),
            isTrue,
            reason: id,
          );
        }
      },
    );
  });

  group('Yerel kanal', () {
    test('MethodChannel: hata kodları GameCenterException olur, eklenti yoksa "unavailable"', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('istanbul_flight/game_center_test');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'submitScore') {
              throw PlatformException(code: 'network');
            }
            if (call.method == 'authenticate') {
              return {'authenticated': true, 'alias': 'A'};
            }
            if (call.method == 'loadEntries') {
              return {
                'total': 2,
                'entries': [
                  {'rank': 1, 'alias': 'B', 'score': 90, 'isLocal': false},
                  {'rank': 2, 'alias': 'A', 'score': 40, 'isLocal': true},
                ],
                'local': {
                  'rank': 2,
                  'alias': 'A',
                  'score': 40,
                  'isLocal': true,
                },
                'occurrenceEndMs': 1793000000000.0,
              };
            }
            return null;
          });
      final api = MethodChannelGameCenterApi(channel: channel, supported: true);
      expect((await api.authenticate()).alias, 'A');
      await expectLater(
        api.submitScore(GcBoard.weekly, 5, achievedAt: _now),
        throwsA(
          isA<GameCenterException>().having((e) => e.code, 'code', 'network'),
        ),
      );
      expect(calls.last.arguments, {
        'leaderboardId': GameCenterIds.weeklyScore,
        'score': 5,
        'recurring': true,
        'achievedAtMs': _now.millisecondsSinceEpoch.toDouble(),
      });
      final page = await api.loadEntries(GcBoard.allTime, GcScope.friends);
      expect(page.entries.length, 2);
      expect(page.local?.isLocal, isTrue);
      expect(page.occurrenceEnd, isNotNull);
      expect(calls.last.arguments['scope'], 'friends');
      const missing = MethodChannel('istanbul_flight/yok');
      await expectLater(
        MethodChannelGameCenterApi(
          channel: missing,
          supported: true,
        ).authenticate(),
        throwsA(
          isA<GameCenterException>().having(
            (e) => e.code,
            'code',
            'unavailable',
          ),
        ),
      );
    });
  });

  group('Oyun akışı', () {
    test(
      'Game Center olmadan oynanır; uçuş sonu Game Center\'a tek kez gelir',
      () async {
        final fake = FakeGameCenterApi();
        final t = TestServices(
          gameCenter: (p) => GameCenterController(
            api: fake,
            store: InMemoryGameCenterStore(
              const GcRecord(legacyExported: true),
            ),
            progress: p,
            scores: InMemoryScoreRepository(),
            clock: () => _now,
          ),
        );
        await t.services.gameCenter.start();
        final g = await initializeGame(
          () => IstanbulFlightGame(
            scores: InMemoryScoreRepository(),
            random: Random(7),
            pickupRandom: Random(3),
            loadArt: false,
            services: t.services,
          ),
        );
        g.onGameResize(Vector2(1080, 1920));
        await g.ready();
        // otomatik pilotlu uçuş: geliştirme yardımı → skor gönderilmez
        g.autopilot = true;
        g.debugInvincible = true;
        g.handleTap();
        while (g.score.value < 3) {
          g.update(1 / 60);
        }
        g.autopilot = false;
        g.debugInvincible = false;
        g.physics.y = g.config.worldHeight;
        for (var i = 0; i < 120; i++) {
          g.update(1 / 60);
        }
        expect(g.phase.value, GamePhase.gameOver);
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(fake.submissions, isEmpty, reason: 'yardımlı uçuş');
        expect(
          t.services.progress.value.flights,
          1,
          reason: 'oyun ilerlemesi aynen',
        );
        // ikinci, yardımsız uçuş (hemen düşer: 0 puan → gönderilmez ama hata da yok)
        g.restart();
        g.handleTap();
        g.physics.y = g.config.worldHeight;
        for (var i = 0; i < 120; i++) {
          g.update(1 / 60);
        }
        expect(t.services.progress.value.flights, 2);
        expect(fake.submissions, isEmpty);
        g.onRemove();
      },
    );
  });
}
