import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/services/haptics_service.dart';
import 'package:istanbul_flight/services/progress.dart';
import 'package:istanbul_flight/services/settings.dart';
import 'package:istanbul_flight/services/share_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kalıcı ayarlar', () {
    test('kaydedilir ve yeniden açılışta aynen okunur', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const s = GameSettings(
        musicVolume: 0.3,
        sfxVolume: 0.6,
        muted: true,
        haptics: false,
        reduceMotion: true,
      );
      await SharedPrefsSettingsRepository(prefs).save(s);
      final again = await SharedPrefsSettingsRepository(
        await SharedPreferences.getInstance(),
      ).load();
      expect(again, s);
    });

    test('bozuk kayıt varsayılana düşer, eski en iyi skor kaybolmaz', () async {
      SharedPreferences.setMockInitialValues({
        'best_score_v1': 42, // önceki sürümlerden kalan rekor
        SharedPrefsSettingsRepository.key: '{bozuk json',
        SharedPrefsProgressRepository.key: '[1,2,3]',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(
        await SharedPrefsSettingsRepository(prefs).load(),
        const GameSettings(),
      );
      expect(
        (await SharedPrefsProgressRepository(prefs).load()).totalSimits,
        0,
      );
      expect(await SharedPrefsScoreRepository(prefs).loadBest(), 42);
    });

    test('aralık dışı değerler sınırlanır', () {
      final s = GameSettings.fromJson({
        'musicVolume': 7,
        'sfxVolume': -1,
        'muted': 'evet',
      });
      expect(s.musicVolume, 1);
      expect(s.sfxVolume, 0);
      expect(s.muted, isFalse);
    });

    test('SettingsController değişikliği hemen uygular ve kaydeder', () async {
      final repo = InMemorySettingsRepository();
      final c = SettingsController(repo, const GameSettings());
      c.update((s) => s.copyWith(sfxVolume: 0.2));
      await Future<void>.delayed(Duration.zero);
      expect(c.value.sfxVolume, 0.2);
      expect((await repo.load()).sfxVolume, 0.2);
      c.update((s) => s); // değişiklik yoksa kayıt yok
      expect(repo.saveCount, 1);
    });
  });

  group('İlerleme (simit) ve kozmetik veri yapısı', () {
    test(
      'turlar toplanır, en iyi tur tutulur, kozmetik alanı genişletilebilir',
      () {
        var p = const PlayerProgress();
        p = p.addRun(simits: 4).addRun(simits: 2);
        expect(p.totalSimits, 6);
        expect(p.bestRunSimits, 4);
        expect(p.unlockedCosmetics, contains('classic'));
        final back = PlayerProgress.fromJson(p.toJson());
        expect(back.totalSimits, 6);
        expect(back.selectedCosmetic, 'classic');
        final bad = PlayerProgress.fromJson({
          'totalSimits': -5,
          'selectedCosmetic': 'yok',
          'unlockedCosmetics': [1, 'kaptan'],
        });
        expect(bad.totalSimits, 0);
        expect(
          bad.selectedCosmetic,
          'classic',
          reason: 'açılmamış görünüm seçilemez',
        );
        expect(bad.unlockedCosmetics, containsAll(['classic', 'kaptan']));
      },
    );
  });

  group('Titreşim', () {
    final calls = <String>[];
    setUp(() => calls.clear());

    void handler(Future<Object?>? Function(MethodCall) h) =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, h);

    test('destekleyen platformda doğru şiddetle çağrılır', () async {
      handler((call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add(call.arguments as String);
        }
        return null;
      });
      final h = PlatformHaptics(supported: true)
        ..light()
        ..medium()
        ..heavy();
      await Future<void>.delayed(Duration.zero);
      expect(calls, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
      ]);
      h.enabled = false;
      h.heavy();
      await Future<void>.delayed(Duration.zero);
      expect(calls, hasLength(3), reason: 'kapalıyken çağrı yok');
    });

    test('desteklenmeyen platform (web) hiç çağırmaz', () async {
      handler((call) async {
        calls.add(call.method);
        return null;
      });
      PlatformHaptics(supported: false)
        ..light()
        ..heavy();
      await Future<void>.delayed(Duration.zero);
      expect(calls, isEmpty);
    });

    test('platform hatası oyunu durdurmaz', () async {
      handler((call) async => throw PlatformException(code: 'unsupported'));
      final h = PlatformHaptics(supported: true);
      h.heavy();
      await Future<void>.delayed(Duration.zero);
      expect(h.failures, 1);
    });
  });

  group('Paylaşım', () {
    final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);

    test('başarılı paylaşım: PNG dosyası ve Türkçe metin gönderilir', () async {
      ShareParams? sent;
      final s = PlatformShareService(
        share: (p) async {
          sent = p;
          return const ShareResult('ok', ShareResultStatus.success);
        },
      );
      expect(
        await s.sharePostcard(
          png,
          shareText(zoneName: 'Kız Kulesi', score: 42, simits: 5),
        ),
        ShareOutcome.shared,
      );
      expect(sent!.files!.single.mimeType, 'image/png');
      expect(sent!.downloadFallbackEnabled, isTrue);
      expect(sent!.text, contains('Kız Kulesi'));
      expect(sent!.sharePositionOrigin, isNull);
    });

    test("iPad: paylaşım başlangıç noktası share_plus'a iletilir", () async {
      ShareParams? sent;
      const origin = Rect.fromLTWH(20, 600, 160, 56);
      await PlatformShareService(
        share: (p) async {
          sent = p;
          return const ShareResult('ok', ShareResultStatus.success);
        },
      ).sharePostcard(png, 't', origin: origin);
      expect(sent!.sharePositionOrigin, origin);
    });

    test('web\'de paylaşım yoksa indirme yedeği → downloaded; mobilde unavailable → shared', () async {
      Future<ShareResult> unavailable(ShareParams p) async =>
          ShareResult.unavailable;
      expect(
        await PlatformShareService(
          share: unavailable,
          isWeb: true,
        ).sharePostcard(png, 't'),
        ShareOutcome.downloaded,
      );
      expect(
        await PlatformShareService(
          share: unavailable,
          isWeb: false,
        ).sharePostcard(png, 't'),
        ShareOutcome.shared,
      );
    });

    test('kapatma ve hata düzgün ele alınır', () async {
      expect(
        await PlatformShareService(
          share: (_) async =>
              const ShareResult('', ShareResultStatus.dismissed),
        ).sharePostcard(png, 't'),
        ShareOutcome.dismissed,
      );
      expect(
        await PlatformShareService(share: (_) async => throw Exception('yok'))
            .sharePostcard(png, 't'),
        ShareOutcome.failed,
      );
    });
  });
}
