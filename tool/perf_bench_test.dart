// Performans ölçümü (docs/19 §8). Çalıştırma: flutter test tool/perf_bench_test.dart
// Masaüstünde, JIT ile; çizim komutlarının kaydı ölçülür, GPU raster ölçülmez. Göreli karşılaştırma içindir.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/day_cycle.dart';
import 'package:istanbul_flight/game/game_art.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/game/visual/atlas_batch.dart';
import 'package:istanbul_flight/game/weather.dart';

import '../test/fakes.dart';

(int, int) dims(Uint8List b) {
  final d = ByteData.sublistView(b);
  return (d.getUint32(16), d.getUint32(20));
}

Future<Map<String, double>> bench(String label, int score, Weather? w, Vector2 size, {int frames = 1800}) async {
  final t = TestServices(clock: () => DateTime.utc(2026, 10, 24, 10));
  final g = await initializeGame(() => IstanbulFlightGame(scores: InMemoryScoreRepository(0), random: Random(7), pickupRandom: Random(8), hazardRandom: Random(9), services: t.services));
  g.onGameResize(size);
  await g.ready();
  g.debugInvincible = true;
  g.autopilot = true;
  g.debugStartScore = score;
  g.debugWeather = w;
  g.handleTap();
  for (var i = 0; i < 300; i++) { g.update(1 / 60); if (i % 10 == 0) await g.ready(); }
  final up = <double>[], rd = <double>[];
  var maxComp = 0, hz = 0;
  final sw = Stopwatch();
  for (var i = 0; i < frames; i++) {
    sw..reset()..start();
    g.update(1 / 60);
    sw.stop();
    up.add(sw.elapsedMicroseconds / 1000);
    final rec = ui.PictureRecorder();
    sw..reset()..start();
    g.render(ui.Canvas(rec));
    final pic = rec.endRecording();
    sw.stop();
    pic.dispose();
    rd.add(sw.elapsedMicroseconds / 1000);
    if (i % 10 == 0) await g.ready();
    maxComp = max(maxComp, g.world.children.length);
    if (g.hazardViews.isNotEmpty) hz++;
  }
  double p(List<double> v, double q) => (List.of(v)..sort())[(v.length * q).floor().clamp(0, v.length - 1)];
  double avg(List<double> v) => v.reduce((a, b) => a + b) / v.length;
  final r = {'upAvg': avg(up), 'upP95': p(up, .95), 'rdAvg': avg(rd), 'rdP95': p(rd, .95), 'rdP99': p(rd, .99)};
  print('$label zone=${g.dayCycle.zoneIndex} weather=${g.weatherLayer.weather.name} worldChildren<=$maxComp hazardFrames=$hz/$frames '
      'update avg ${r['upAvg']!.toStringAsFixed(3)} p95 ${r['upP95']!.toStringAsFixed(3)} | render(record) avg ${r['rdAvg']!.toStringAsFixed(3)} p95 ${r['rdP95']!.toStringAsFixed(3)} p99 ${r['rdP99']!.toStringAsFixed(3)} ms');
  return r;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('assets', () {
    var files = 0, bytes = 0, decoded = 0;
    final byGroup = <String, List<int>>{};
    final first = {for (final z in routeZoneList.take(firstRouteLastZone + 1)) z.kit.name};
    for (final path in GameArt.allPaths) {
      final f = File('assets/images/$path');
      final b = f.readAsBytesSync();
      final (w, h) = dims(b);
      files++; bytes += b.length; decoded += w * h * 4;
      final zone = routeZoneList.map((z) => z.kit.name).where((n) => path.contains('/$n/') || path.contains('_$n.') || path.contains('/$n.')).firstOrNull;
      final grp = zone == null ? 'ortak' : (first.contains(zone) ? '1.gun:$zone' : '2.gun:$zone');
      final e = byGroup.putIfAbsent(grp, () => [0, 0, 0]);
      e[0]++; e[1] += b.length; e[2] += w * h * 4;
    }
    print('TOPLAM $files dosya, ${(bytes / 1024).toStringAsFixed(0)} KB PNG, ${(decoded / 1048576).toStringAsFixed(1)} MB RGBA');
    for (final e in byGroup.entries) {
      print('  ${e.key}: ${e.value[0]} dosya, ${(e.value[1] / 1024).toStringAsFixed(0)} KB, ${(e.value[2] / 1048576).toStringAsFixed(2)} MB');
    }
    var ab = 0;
    for (final f in Directory('assets/audio').listSync().whereType<File>()) { ab += f.lengthSync(); }
    print('SES ${(ab / 1048576).toStringAsFixed(2)} MB');
  });
  test('bench', () async {
    final phone = Vector2(1170, 2532);
    // Phase 2.9: çizim birleştirme kapalı (ÖNCE) / açık (SONRA), dönüşümlü; ilk tur ısınma
    for (var rep = 0; rep < 3; rep++) {
      for (final batch in [false, true]) {
        RenderTuning.batchDraws = batch;
        final tag = '${rep == 0 ? "ısınma " : "tur $rep "}${batch ? "SONRA" : "ÖNCE "}';
        await bench('$tag A Haliç açık        ', 1, null, phone);
        await bench('$tag B Ortaköy açık+tehl.', 150, null, phone);
        await bench('$tag C Ortaköy rüzgârlı  ', 150, Weather.windy, phone);
        await bench('$tag D Üsküdar yağmur    ', 215, Weather.rain, phone);
        await bench('$tag E Rumeli sis        ', 95, Weather.fog, phone);
      }
    }
    RenderTuning.batchDraws = true;
  }, timeout: const Timeout(Duration(minutes: 10)));
}
