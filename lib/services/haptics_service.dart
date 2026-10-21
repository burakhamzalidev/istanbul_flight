import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dokunsal geri bildirim. Ölçülü: kanat çırpmada titreşim yok, sadece önemli anlarda.
abstract class HapticsService {
  bool enabled = true;

  /// Simit toplama.
  void light();

  /// Kıl payı.
  void medium();

  /// Çarpışma.
  void heavy();
}

class NoHaptics extends HapticsService {
  @override
  void light() {}
  @override
  void medium() {}
  @override
  void heavy() {}
}

/// Platform titreşimi. Web'de ve desteklenmeyen cihazlarda sessizce hiçbir şey yapmaz,
/// platform hatası oyunu asla durdurmaz.
class PlatformHaptics extends HapticsService {
  PlatformHaptics({bool? supported}) : supported = supported ?? !kIsWeb;

  final bool supported;
  int failures = 0;

  Future<void> _run(Future<void> Function() f) async {
    if (!enabled || !supported) return;
    try {
      await f();
    } catch (e) {
      failures++;
      debugPrint('Titreşim desteklenmiyor: $e');
    }
  }

  @override
  void light() => _run(HapticFeedback.lightImpact);
  @override
  void medium() => _run(HapticFeedback.mediumImpact);
  @override
  void heavy() => _run(HapticFeedback.heavyImpact);
}
