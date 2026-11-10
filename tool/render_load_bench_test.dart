// Çizim yükü ölçümü (docs/22 §4). Çalıştırma: flutter test tool/render_load_bench_test.dart
// Gerçek görsellerle, 1170×2532 ekranda her karede yapılan çizim çağrılarını sayar ve boyanan alanın
// ekran alanına oranını (overdraw) hesaplar. GPU süresi değil, GPU'ya giden işin miktarıdır: aynı sahne
// önce/sonra karşılaştırması içindir. drawPicture içindeki komutlar görünmez (kayıtlı resim tek çağrı sayılır).
// ignore_for_file: avoid_print

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/game/visual/atlas_batch.dart';
import 'package:istanbul_flight/game/weather.dart';

import '../test/fakes.dart';

/// Yalnızca sayan tuval: 2B dönüşümü (ölçek + öteleme) izler, hedef dikdörtgenleri ekrana kırpıp alanlarını toplar.
class CountingCanvas implements ui.Canvas {
  CountingCanvas(this.screen);

  final ui.Rect screen;
  final calls = <String, int>{};
  double area = 0;
  int saveLayers = 0;
  // a, b, c, d, tx, ty (x' = a*x + c*y + tx, y' = b*x + d*y + ty)
  var _m = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];
  final _stack = <List<double>>[];

  void _count(String k) => calls[k] = (calls[k] ?? 0) + 1;

  void _paint(String k, ui.Rect r) {
    _count(k);
    final pts = [
      _apply(r.left, r.top),
      _apply(r.right, r.top),
      _apply(r.left, r.bottom),
      _apply(r.right, r.bottom),
    ];
    final xs = pts.map((p) => p.dx), ys = pts.map((p) => p.dy);
    final box = ui.Rect.fromLTRB(xs.reduce(min), ys.reduce(min), xs.reduce(max), ys.reduce(max));
    final c = box.intersect(screen);
    if (c.width > 0 && c.height > 0) area += c.width * c.height;
  }

  ui.Offset _apply(double x, double y) => ui.Offset(
    _m[0] * x + _m[2] * y + _m[4],
    _m[1] * x + _m[3] * y + _m[5],
  );

  void _mul(double a, double b, double c, double d, double tx, double ty) {
    final m = _m;
    _m = [
      m[0] * a + m[2] * b,
      m[1] * a + m[3] * b,
      m[0] * c + m[2] * d,
      m[1] * c + m[3] * d,
      m[0] * tx + m[2] * ty + m[4],
      m[1] * tx + m[3] * ty + m[5],
    ];
  }

  @override
  void save() => _stack.add(List.of(_m));
  @override
  void saveLayer(ui.Rect? bounds, ui.Paint paint) {
    saveLayers++;
    save();
  }

  @override
  void restore() {
    if (_stack.isNotEmpty) _m = _stack.removeLast();
  }

  @override
  void restoreToCount(int count) {
    while (_stack.length + 1 > count && _stack.isNotEmpty) {
      restore();
    }
  }

  @override
  int getSaveCount() => _stack.length + 1;
  @override
  void translate(double dx, double dy) => _mul(1, 0, 0, 1, dx, dy);
  @override
  void scale(double sx, [double? sy]) => _mul(sx, 0, 0, sy ?? sx, 0, 0);
  @override
  void rotate(double radians) {
    _count('rotate');
    final c = cos(radians), s = sin(radians);
    _mul(c, s, -s, c, 0, 0);
  }

  @override
  void transform(Float64List m) => _mul(m[0], m[1], m[4], m[5], m[12], m[13]);
  @override
  void drawRect(ui.Rect rect, ui.Paint paint) => _paint('drawRect', rect);
  @override
  void drawRRect(ui.RRect rrect, ui.Paint paint) => _paint('drawRRect', rrect.outerRect);
  @override
  void drawOval(ui.Rect rect, ui.Paint paint) => _paint('drawOval', rect);
  @override
  void drawCircle(ui.Offset c, double radius, ui.Paint paint) =>
      _paint('drawCircle', ui.Rect.fromCircle(center: c, radius: radius));
  @override
  // Yolun gerçek boyanan alanı bilinemez (kutusu çok büyük olabilir): sayılır, alana katılmaz.
  void drawPath(ui.Path path, ui.Paint paint) => _count('drawPath');
  @override
  void drawImage(ui.Image image, ui.Offset offset, ui.Paint paint) => _paint(
    'drawImage',
    offset & ui.Size(image.width.toDouble(), image.height.toDouble()),
  );
  @override
  void drawImageRect(ui.Image image, ui.Rect src, ui.Rect dst, ui.Paint paint) =>
      _paint('drawImageRect', dst);
  @override
  void drawPaint(ui.Paint paint) {
    _count('drawPaint');
    area += screen.width * screen.height;
  }

  @override
  void drawColor(ui.Color color, ui.BlendMode blendMode) {
    _count('drawColor');
    area += screen.width * screen.height;
  }

  @override
  void drawAtlas(
    ui.Image atlas,
    List<ui.RSTransform> transforms,
    List<ui.Rect> rects,
    List<ui.Color>? colors,
    ui.BlendMode? blendMode,
    ui.Rect? cullRect,
    ui.Paint paint,
  ) {
    _count('drawAtlas');
    for (var i = 0; i < rects.length; i++) {
      area += rects[i].width * rects[i].height * transforms[i].scos.abs() * transforms[i].scos.abs() * _m[0] * _m[3];
    }
  }

  @override
  void drawRawAtlas(
    ui.Image atlas,
    Float32List rstTransforms,
    Float32List rects,
    Int32List? colors,
    ui.BlendMode? blendMode,
    ui.Rect? cullRect,
    ui.Paint paint,
  ) {
    _count('drawRawAtlas');
    final calls0 = calls['drawRawAtlas'];
    for (var i = 0; i < rects.length; i += 4) {
      final s = rstTransforms[i]; // dönüşsüz ölçek (ssin = 0)
      _paint('_atlasSprite', ui.Rect.fromLTWH(
        rstTransforms[i + 2],
        rstTransforms[i + 3],
        (rects[i + 2] - rects[i]) * s,
        (rects[i + 3] - rects[i + 1]) * s,
      ));
    }
    calls.remove('_atlasSprite');
    calls['drawRawAtlas'] = calls0!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    _count(invocation.memberName.toString().replaceAll('Symbol("', '').replaceAll('")', ''));
    return null;
  }
}

Future<void> _scene(String label, {bool batch = true, int score = 0, Weather? weather, bool menu = false, bool gameOver = false}) async {
  RenderTuning.batchDraws = batch;
  final t = TestServices(clock: () => DateTime.utc(2026, 10, 24, 10));
  final g = await initializeGame(
    () => IstanbulFlightGame(
      scores: InMemoryScoreRepository(0),
      random: Random(7),
      pickupRandom: Random(8),
      hazardRandom: Random(9),
      services: t.services,
    ),
  );
  final size = Vector2(1170, 2532);
  g.onGameResize(size);
  await g.ready();
  if (!menu) {
    g.debugInvincible = !gameOver;
    g.autopilot = !gameOver;
    g.debugStartScore = score;
    g.debugWeather = weather;
    g.handleTap();
  }
  for (var i = 0; i < 300; i++) {
    g.update(1 / 60);
    if (i % 10 == 0) await g.ready();
  }
  const frames = 120;
  var area = 0.0, saveLayers = 0;
  final calls = <String, int>{};
  for (var i = 0; i < frames; i++) {
    g.update(1 / 60);
    final c = CountingCanvas(ui.Offset.zero & ui.Size(size.x, size.y));
    g.render(c);
    area += c.area;
    saveLayers += c.saveLayers;
    c.calls.forEach((k, v) => calls[k] = (calls[k] ?? 0) + v);
    if (i % 10 == 0) await g.ready();
  }
  final draws = calls.entries.where((e) => e.key.startsWith('draw')).fold<int>(0, (s, e) => s + e.value);
  final top = (calls.entries.where((e) => e.key.startsWith('draw')).toList()..sort((a, b) => b.value.compareTo(a.value)))
      .take(5)
      .map((e) => '${e.key} ${(e.value / frames).toStringAsFixed(1)}')
      .join(', ');
  // bileşen bazında çağrı sayısı (dünya bileşenleri ayrı ayrı; kamera dönüşümü olmadan)
  final per = <String, int>{};
  for (final ch in g.world.children) {
    final c = CountingCanvas(ui.Offset.zero & ui.Size(size.x, size.y));
    ch.renderTree(c);
    final n = c.calls.entries.where((e) => e.key.startsWith('draw')).fold<int>(0, (s, e) => s + e.value);
    final k = ch.runtimeType.toString();
    per[k] = (per[k] ?? 0) + n;
  }
  final perTop = (per.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).where((e) => e.value > 0).map((e) => '${e.key} ${e.value}').join(', ');
  print('${batch ? 'SONRA' : 'ÖNCE '} $label faz=${g.phase.value.name} bölge=${g.dayCycle.zoneIndex} hava=${g.weatherLayer.weather.name} '
      '| çizim/kare ${(draws / frames).toStringAsFixed(1)} | overdraw ${(area / frames / (size.x * size.y)).toStringAsFixed(2)}× '
      '| saveLayer/kare ${(saveLayers / frames).toStringAsFixed(1)} | bileşen ${g.world.children.length}\n    $top\n    bileşenler: $perTop');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('çizim yükü', () async {
    await _scene(batch: false, 'Menü               ', menu: true);
    await _scene('Menü               ', menu: true);
    await _scene(batch: false, 'A Haliç açık       ', score: 1);
    await _scene('A Haliç açık       ', score: 1);
    await _scene(batch: false, 'B Ortaköy açık+tehl', score: 150);
    await _scene('B Ortaköy açık+tehl', score: 150);
    await _scene(batch: false, 'C Ortaköy rüzgârlı ', score: 150, weather: Weather.windy);
    await _scene('C Ortaköy rüzgârlı ', score: 150, weather: Weather.windy);
    await _scene(batch: false, 'D Üsküdar yağmur   ', score: 215, weather: Weather.rain);
    await _scene('D Üsküdar yağmur   ', score: 215, weather: Weather.rain);
    await _scene(batch: false, 'E Rumeli sis       ', score: 95, weather: Weather.fog);
    await _scene('E Rumeli sis       ', score: 95, weather: Weather.fog);
    await _scene(batch: false, 'F Oyun sonu        ', gameOver: true);
    await _scene('F Oyun sonu        ', gameOver: true);
    RenderTuning.batchDraws = true;
  }, timeout: const Timeout(Duration(minutes: 10)));
}
