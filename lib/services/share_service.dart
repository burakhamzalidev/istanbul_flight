import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

enum ShareOutcome {
  /// Paylaşım menüsü açıldı ve bir uygulama seçildi (ya da platform sonucu bildirmiyor).
  shared,

  /// Kullanıcı paylaşım menüsünü kapattı.
  dismissed,

  /// Paylaşım desteklenmiyor; görsel indirildi (web yedeği).
  downloaded,

  /// Paylaşılamadı (hata). Arayüz kullanıcıya bildirir.
  failed,
}

abstract class ShareService {
  /// [origin]: paylaşım düğmesinin ekrandaki dikdörtgeni. iPad'de iOS paylaşım menüsü (popover) bir
  /// başlangıç noktası ister; verilmezse menü açılamaz. iPhone'da yok sayılır.
  Future<ShareOutcome> sharePostcard(
    Uint8List png,
    String text, {
    Rect? origin,
  });
}

/// share_plus ile paylaşım. Web'de Web Share API yoksa görsel indirilir.
class PlatformShareService implements ShareService {
  PlatformShareService({
    Future<ShareResult> Function(ShareParams)? share,
    bool? isWeb,
  }) : _share = share ?? SharePlus.instance.share,
       _isWeb = isWeb ?? kIsWeb;

  final Future<ShareResult> Function(ShareParams) _share;
  final bool _isWeb;

  static const fileName = 'marti_istanbul_flight_kartpostal.png';

  @override
  Future<ShareOutcome> sharePostcard(
    Uint8List png,
    String text, {
    Rect? origin,
  }) async {
    try {
      final result = await _share(
        ShareParams(
          text: text,
          subject: 'Martı: Istanbul Flight',
          files: [XFile.fromData(png, mimeType: 'image/png', name: fileName)],
          fileNameOverrides: const [fileName],
          downloadFallbackEnabled: true,
          sharePositionOrigin: origin,
        ),
      );
      return switch (result.status) {
        ShareResultStatus.success => ShareOutcome.shared,
        ShareResultStatus.dismissed => ShareOutcome.dismissed,
        // Web: indirme yedeği çalıştı. Mobil: platform sonuç bildirmiyor ama menü açıldı.
        ShareResultStatus.unavailable =>
          _isWeb ? ShareOutcome.downloaded : ShareOutcome.shared,
      };
    } catch (e) {
      debugPrint('Paylaşım başarısız: $e');
      return ShareOutcome.failed;
    }
  }
}

/// Bir RepaintBoundary'nin içeriğini PNG'ye çevirir (kartpostal görseli).
/// [targetWidth] piksel genişliğe ölçeklenir (paylaşım için ~1080 px).
Future<Uint8List?> captureBoundaryPng(
  RenderRepaintBoundary boundary, {
  double targetWidth = 1080,
}) async {
  try {
    final ratio = targetWidth / boundary.size.width;
    final image = await boundary.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  } catch (e) {
    debugPrint('Kartpostal görseli üretilemedi: $e');
    return null;
  }
}

/// Paylaşım metni (Türkçe, bölge adıyla).
String shareText({
  required String zoneName,
  required int score,
  required int simits,
}) =>
    'Martı: Istanbul Flight\'ta $zoneName bölgesine kadar uçtum! Skor: $score · Simit: $simits';
