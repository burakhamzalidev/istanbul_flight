import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'progress.dart';

// Phase 2.8: oyuncu deneyimi kaydı (docs/21 §4, §8).
//
// İlerleme kaydından (`progress_v2`) AYRI tutulur: eğitim durumu ve "görüldü" işaretleri ödül ya da
// ekonomi içermez; bozulsa bile oyuncunun ilerlemesine dokunmaz. Kendi sürüm alanı (`v`) vardır.

enum TutorialStatus {
  /// Yeni oyuncu: ilk açılışta eğitim kendiliğinden başlar.
  pending,
  completed,

  /// Atlandı ya da yarıda bırakıldı: bir daha zorlanmaz, "Nasıl oynanır"dan yeniden açılabilir.
  skipped,

  /// Bu sürümden önce oynamış oyuncu: eğitim zorlanmaz (isteğe bağlı).
  legacy;

  /// Eğitim artık kendiliğinden açılmaz (tamamlanmış ya da bilinçli geçilmiş).
  bool get isSettled => this != pending;
}

@immutable
class UxState {
  const UxState({
    this.tutorial = TutorialStatus.pending,
    this.tutorialAt,
    this.seenEvents = const {},
    this.seenCosmetics = const {'classic'},
    this.seenPostcards = const {},
  });

  static const version = 1;

  final TutorialStatus tutorial;
  final DateTime? tutorialAt;

  /// Etkinlik Merkezi'nde görülmüş etkinlikler (yeni etkinlik işareti için).
  final Set<String> seenEvents;

  /// Görünüm ekranında görülmüş sahip olunan görünümler (yeni ödül görünümü işareti).
  final Set<String> seenCosmetics;

  /// Albümde görülmüş kartpostallar (bölge sırası).
  final Set<int> seenPostcards;

  /// Kayıt yokken: hiç ilerlemesi olmayan oyuncu yeni sayılır; diğerleri eski oyuncudur (eğitim
  /// zorlanmaz). Sahip olunan görünümler ve açılmış kartpostallar "görülmüş" başlar: güncellemeden sonra
  /// menü bir yığın "yeni" işaretiyle açılmaz.
  factory UxState.initialFor(PlayerProgress p, {required int best}) {
    final fresh =
        best <= 0 &&
        p.flights == 0 &&
        p.xp == 0 &&
        p.totalSimits == 0 &&
        p.dailyChallenge.records.isEmpty &&
        p.events.records.isEmpty;
    return UxState(
      tutorial: fresh ? TutorialStatus.pending : TutorialStatus.legacy,
      seenCosmetics: {...p.unlockedCosmetics, 'classic'},
      seenPostcards: p.discovery.firstSeen.keys.toSet(),
    );
  }

  UxState copyWith({
    TutorialStatus? tutorial,
    DateTime? tutorialAt,
    Set<String>? seenEvents,
    Set<String>? seenCosmetics,
    Set<int>? seenPostcards,
  }) => UxState(
    tutorial: tutorial ?? this.tutorial,
    tutorialAt: tutorialAt ?? this.tutorialAt,
    seenEvents: seenEvents ?? this.seenEvents,
    seenCosmetics: seenCosmetics ?? this.seenCosmetics,
    seenPostcards: seenPostcards ?? this.seenPostcards,
  );

  Map<String, Object> toJson() => {
    'v': version,
    'tutorial': tutorial.name,
    'tutorialAt': ?tutorialAt?.toUtc().toIso8601String(),
    'seenEvents': seenEvents.toList()..sort(),
    'seenCosmetics': seenCosmetics.toList()..sort(),
    'seenPostcards': seenPostcards.toList()..sort(),
  };

  /// Tanınmayan eğitim durumu "eski oyuncu" sayılır (yanlışlıkla zorunlu eğitim yok).
  factory UxState.fromJson(Object? j) {
    if (j is! Map) return const UxState(tutorial: TutorialStatus.legacy);
    final at = j['tutorialAt'];
    List<T> list<T>(Object? v) => v is List ? v.whereType<T>().toList() : <T>[];
    return UxState(
      tutorial:
          TutorialStatus.values.asNameMap()[j['tutorial']] ??
          TutorialStatus.legacy,
      tutorialAt: at is String ? DateTime.tryParse(at) : null,
      seenEvents: list<String>(j['seenEvents']).toSet(),
      seenCosmetics: {...list<String>(j['seenCosmetics']), 'classic'},
      seenPostcards: list<int>(j['seenPostcards']).toSet(),
    );
  }
}

abstract class UxRepository {
  /// Kayıt yoksa null.
  Future<UxState?> load();
  Future<void> save(UxState s);
}

class SharedPrefsUxRepository implements UxRepository {
  SharedPrefsUxRepository(this._prefs);

  static const key = 'ux_v1';
  final SharedPreferences _prefs;

  @override
  Future<UxState?> load() async {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return UxState.fromJson(jsonDecode(raw));
    } catch (e) {
      // okunamayan kayıt: eğitim zorlanmaz, işaretler sıfırdan
      debugPrint('Deneyim kaydı okunamadı: $e');
      return const UxState(tutorial: TutorialStatus.legacy);
    }
  }

  @override
  Future<void> save(UxState s) => _prefs.setString(key, jsonEncode(s.toJson()));
}

class InMemoryUxRepository implements UxRepository {
  InMemoryUxRepository([this.state]);

  UxState? state;
  int saves = 0;

  @override
  Future<UxState?> load() async => state;

  @override
  Future<void> save(UxState s) async {
    state = s;
    saves++;
  }
}

/// Eğitim durumu ve "yeni" işaretlerinin canlı kaynağı; değişince kaydedilir.
class UxController extends ValueNotifier<UxState> {
  UxController(this._repo, super.value, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// Testler ve servislerin kurulamadığı durum: eğitim tamamlanmış sayılır (menü doğrudan açılır).
  factory UxController.memory([
    UxState state = const UxState(tutorial: TutorialStatus.completed),
  ]) => UxController(InMemoryUxRepository(state), state);

  final UxRepository _repo;
  final DateTime Function() _clock;
  Future<void> _saving = Future.value();

  /// Açılışta: kayıt varsa o, yoksa oyuncunun ilerlemesine göre başlangıç durumu (ve hemen yazılır).
  static Future<UxController> load(
    UxRepository repo,
    PlayerProgress progress, {
    required int best,
  }) async {
    var s = await repo.load();
    if (s == null) {
      s = UxState.initialFor(progress, best: best);
      try {
        await repo.save(s);
      } catch (e) {
        debugPrint('Deneyim kaydı yazılamadı: $e');
      }
    }
    return UxController(repo, s);
  }

  /// Eğitimin sonucu. Tamamlanmış bir eğitim hiçbir zaman geri alınmaz (atlama ya da eski kayıt onu
  /// silmez); tekrar oynamak durumu değiştirmez.
  void finishTutorial(TutorialStatus to) {
    assert(to == TutorialStatus.completed || to == TutorialStatus.skipped);
    final cur = value.tutorial;
    if (cur == TutorialStatus.completed) return;
    if (cur == to) return;
    if (to == TutorialStatus.skipped && cur != TutorialStatus.pending) return;
    value = value.copyWith(tutorial: to, tutorialAt: _clock().toUtc());
    _persist();
  }

  void markEventsSeen(Iterable<String> ids) {
    final next = {...value.seenEvents, ...ids};
    if (next.length == value.seenEvents.length) return;
    // eski haftaların kimlikleri birikmesin (son 12)
    final keep = (next.toList()..sort()).reversed.take(12).toSet();
    value = value.copyWith(seenEvents: keep);
    _persist();
  }

  void markCosmeticsSeen(Iterable<String> ids) {
    final next = {...value.seenCosmetics, ...ids};
    if (next.length == value.seenCosmetics.length) return;
    value = value.copyWith(seenCosmetics: next);
    _persist();
  }

  void markPostcardsSeen(Iterable<int> zones) {
    final next = {...value.seenPostcards, ...zones};
    if (next.length == value.seenPostcards.length) return;
    value = value.copyWith(seenPostcards: next);
    _persist();
  }

  void _persist() {
    final snapshot = value;
    _saving = _saving.then((_) async {
      try {
        await _repo.save(snapshot);
      } catch (e) {
        debugPrint('Deneyim kaydı yazılamadı: $e');
      }
    });
  }

  Future<void> flush() => _saving;
}
