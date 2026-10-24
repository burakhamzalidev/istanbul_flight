import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/challenge/daily_challenge.dart';
import 'package:istanbul_flight/challenge/daily_rng.dart';
import 'package:istanbul_flight/game/config.dart';
import 'package:istanbul_flight/game/logic/pickup_rules.dart';

// Phase 2.5: deterministik günlük parkur (docs/17 §3–§4).

DailyChallengeDefinition _def(int seed, {DateTime? day}) =>
    DailyChallengeDefinition(
      challengeId: 'daily_2026_10_24',
      dateUtc: day ?? DateTime.utc(2026, 10, 24),
      seed: seed,
      generatorVersion: 1,
      candidate: 0,
      validatedDepth: 0,
    );

List<double> _gaps(DailyCourse c, int n) => [
  for (var i = 0; i < n; i++) c.at(i).gapCenter,
];

void main() {
  group('PRNG ve tohum', () {
    test(
      'Mulberry32 standart çıktıyla birebir aynı (JavaScript referansı)',
      () {
        // node: mulberry32(12345) → Math.imul tabanlı referans uygulama
        final r = DailyRng(12345);
        expect(
          [for (var i = 0; i < 5; i++) r.nextUint32()],
          [4207900869, 1317490944, 2079646450, 3513001552, 2187978186],
        );
        expect(DailyRng.hash('istanbul_flight'), 3272871632);
        expect(
          DailyRng.hash('İstanbul'),
          3557459129,
        ); // Türkçe karakter: 16 bit kod birimi
      },
    );

    test(
      '32 bit çarpım taşmada doğru (platform tamsayı genişliğinden bağımsız)',
      () {
        expect(DailyRng.imul32(0xffffffff, 0xffffffff), 1);
        expect(DailyRng.imul32(0x80000000, 2), 0);
        expect(
          DailyRng.imul32(123456789, 987654321),
          (123456789 * 987654321) & 0xffffffff,
        );
      },
    );

    test('nextDouble [0,1) aralığında', () {
      final r = DailyRng(7);
      for (var i = 0; i < 10000; i++) {
        final v = r.nextDouble();
        expect(v, greaterThanOrEqualTo(0));
        expect(v, lessThan(1));
      }
    });
  });

  group('Determinizm', () {
    test('aynı tohum aynı parkuru üretir (engel, açıklık, simit)', () {
      final a = DailyCourse(_def(42)), b = DailyCourse(_def(42));
      for (var i = 0; i < 150; i++) {
        expect(a.at(i).gapCenter, b.at(i).gapCenter);
        expect(a.at(i).gapHeight, b.at(i).gapHeight);
        expect(a.at(i).pickupY, b.at(i).pickupY);
      }
    });

    test('erişim sırası sonucu değiştirmez (önce 80. engel, sonra baştan)', () {
      final a = DailyCourse(_def(9)), b = DailyCourse(_def(9));
      final late = a.at(80);
      expect(b.at(80).gapCenter, late.gapCenter);
      expect(_gaps(a, 80), _gaps(b, 80));
    });

    test('farklı tohum farklı parkur üretebilir', () {
      expect(
        _gaps(DailyCourse(_def(1)), 10),
        isNot(_gaps(DailyCourse(_def(2)), 10)),
      );
    });

    test('farklı günler farklı challenge; aynı gün her çağrıda aynı tanım', () {
      final a = DailyGenerators.forDay(DateTime.utc(2026, 10, 24, 3));
      final b = DailyGenerators.forDay(DateTime.utc(2026, 10, 24, 23, 59));
      final c = DailyGenerators.forDay(DateTime.utc(2026, 10, 25));
      expect(a.challengeId, 'daily_2026_10_24');
      expect(b.seed, a.seed);
      expect(c.challengeId, 'daily_2026_10_25');
      expect(c.seed, isNot(a.seed));
    });

    test('gün UTC\'dir: İstanbul\'da 25 Ekim 01:00 = UTC 24 Ekim 22:00 → 24 Ekim challenge\'ı', () {
      final istanbul = DateTime.parse('2026-10-25T01:00:00+03:00');
      expect(utcDayKey(istanbul), '2026-10-24');
      expect(DailyGenerators.forDay(istanbul).challengeId, 'daily_2026_10_24');
    });

    test('altın değerler: üretici v1 çıktısı sessizce değişmez', () {
      // Bu değerler değişirse süren ve geçmiş günlerin parkurları değişmiş demektir: üretici kodunu
      // değiştirmek yerine yeni bir sürüm açılmalı (DailyGenerators.schedule).
      final d = DailyGenerators.forDay(DateTime.utc(2026, 10, 24));
      expect(d.seed, 3439186215);
      expect(d.candidate, 0);
      expect(d.generatorVersion, 1);
      final c = DailyCourse(d);
      expect(
        [for (var i = 0; i < 5; i++) c.at(i).gapCenter.toStringAsFixed(6)],
        ['455.277306', '511.166936', '756.473247', '958.463935', '1374.932839'],
      );
      expect(
        [for (var i = 0; i < 8; i++) c.at(i).pickupY?.toStringAsFixed(6)],
        [
          null,
          null,
          '837.096436',
          null,
          '1441.388582',
          null,
          '1071.086316',
          '1140.072681',
        ],
      );
      final next = DailyGenerators.forDay(DateTime.utc(2026, 10, 25));
      expect(next.seed, 1637703470);
      expect(
        DailyCourse(next).at(0).gapCenter.toStringAsFixed(6),
        '1348.426832',
      );
    });

    test(
      'ilk engelde simit yok; geçit eğrisi klasikle aynı (n. engel = skor n)',
      () {
        final c = DailyCourse(_def(5));
        const cfg = GameConfig();
        expect(c.at(0).pickupY, isNull);
        for (var i = 0; i < 120; i++) {
          expect(c.at(i).gapHeight, cfg.gapForScore(i));
        }
      },
    );
  });

  group('Oynanabilirlik doğrulaması', () {
    test(
      'kurallar: geçit güvenli bantta, kayma sınırlı, simit ulaşılabilir',
      () {
        const cfg = GameConfig();
        for (final seed in [1, 2, 3, 99, 4242]) {
          final c = DailyCourse(_def(seed));
          for (var i = 0; i < 150; i++) {
            final s = c.at(i);
            expect(
              s.gapCenter - s.gapHeight / 2,
              greaterThanOrEqualTo(cfg.gapMarginTop - 1e-6),
            );
            expect(
              s.gapCenter + s.gapHeight / 2,
              lessThanOrEqualTo(cfg.worldHeight - cfg.gapMarginBottom + 1e-6),
            );
            if (i > 0) {
              expect(
                (s.gapCenter - c.at(i - 1).gapCenter).abs(),
                lessThanOrEqualTo(cfg.maxGapShift + 1e-6),
              );
            }
            final py = s.pickupY;
            if (py != null) {
              final band = PickupRules.reachableBand(
                config: cfg,
                gapCenter: s.gapCenter,
                gapHeight: s.gapHeight,
              )!;
              expect(py, inInclusiveRange(band.top, band.bottom));
            }
          }
        }
      },
    );

    test('seçilen günlük parkurlar 100 engel boyunca fiziksel olarak geçilebilir ve dar boğazsız', () {
      for (var d = 0; d < 14; d++) {
        final def = DailyGenerators.forDay(
          DateTime.utc(2026, 10, 24).add(Duration(days: d)),
        );
        expect(
          def.validatedDepth,
          CourseValidator.requiredDepth,
          reason: def.challengeId,
        );
        final check = CourseValidator.check(DailyCourse(def));
        expect(check.passes, isTrue, reason: def.challengeId);
        expect(
          check.tightest,
          greaterThanOrEqualTo(CourseValidator.minSafeBand),
        );
      }
    });

    test('imkânsız parkur reddedilir: geçidi kuştan dar bir parkur 0 engelde kalır', () {
      const narrow = GameConfig(startGap: 60, minGap: 60);
      final check = CourseValidator.check(DailyCourse(_def(3), config: narrow));
      expect(check.passes, isFalse);
      expect(check.depth, 0);
    });

    test('aşırı dar boğaz reddedilir (geçilebilse bile piksel hassasiyeti isteyen parkur)', () {
      // geçit kuş çapından yalnızca biraz büyük: geçilebilir ama güvenli aralık çok dar
      const tight = GameConfig(startGap: 84, minGap: 84);
      final check = CourseValidator.check(DailyCourse(_def(3), config: tight));
      expect(check.passes, isFalse);
    });

    test('aday seçimi deterministik: ilk aday reddedilen gün her seferinde aynı yedeğe düşer', () {
      // 12 Aralık 2026: ilk aday dar boğaz yüzünden elenir, 1. aday seçilir
      final a = DailyGenerators.forDay(DateTime.utc(2026, 12, 12));
      expect(a.candidate, 1);
      final first = DailyChallengeDefinition(
        challengeId: a.challengeId,
        dateUtc: a.dateUtc,
        seed: DailyRng.hash('istanbul_flight/daily/v1/2026-12-12/0'),
        generatorVersion: 1,
        candidate: 0,
        validatedDepth: 0,
      );
      expect(CourseValidator.check(DailyCourse(first)).passes, isFalse);
      expect(CourseValidator.check(DailyCourse(a)).passes, isTrue);
    });

    test('arka planda hazırlanan tanım doğrudan hesaplananla aynı', () async {
      final day = DateTime.utc(2026, 11, 3);
      final bg = await DailyGenerators.prepare(day);
      final fg = DailyGenerators.forDay(day);
      expect(bg.seed, fg.seed);
      expect(bg.candidate, fg.candidate);
    });
  });

  group('Üretici sürümü', () {
    test('takvim: bilinen her gün v1; sürüm tanımla birlikte saklanır', () {
      expect(DailyGenerators.versionFor('2026-10-24'), 1);
      expect(DailyGenerators.versionFor('2030-01-01'), 1);
      expect(
        DailyGenerators.forDay(DateTime.utc(2026, 10, 24)).generatorVersion,
        1,
      );
    });

    test('bilinmeyen üretici sürümü sessizce başka parkur üretmez (hata)', () {
      final def = DailyChallengeDefinition(
        challengeId: 'daily_2026_10_24',
        dateUtc: DateTime.utc(2026, 10, 24),
        seed: 1,
        generatorVersion: 99,
        candidate: 0,
        validatedDepth: 0,
      );
      expect(() => DailyGenerators.course(def), throwsUnsupportedError);
    });

    test(
      'challenge kimliği ve gün anahtarı çift yönlü; geçersizler reddedilir',
      () {
        expect(
          DailyChallengeDefinition.idFor('2026-10-24'),
          'daily_2026_10_24',
        );
        expect(
          DailyChallengeDefinition.dayKeyOf('daily_2026_10_24'),
          '2026-10-24',
        );
        expect(DailyChallengeDefinition.dayKeyOf('daily_2026_02_30'), isNull);
        expect(DailyChallengeDefinition.dayKeyOf('weekly_2026_10_24'), isNull);
        expect(parseUtcDayKey('2026-13-01'), isNull);
      },
    );
  });
}
