// Uzun seans bellek ölçümü (docs/22 §5). Çalıştırma:
//   flutter test --enable-vmservice tool/leak_bench_test.dart
// Tam uygulama (MartiApp, görselsiz) içinde 110 uçuş: klasik, Günün Uçuşu antrenmanı ve etkinlik. Her 5 uçuşta
// bütün ekranlar açılıp kapanır. 10., 60. ve 110. uçuşta çöp toplama sonrası canlı nesne sayıları sınıf bazında
// alınır; iki aralıkta da büyüyen sınıflar "birikme adayı" olarak yazılır. Test ortamı (debug, masaüstü).
// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'dart:convert';
import 'dart:developer';
import 'dart:isolate' as di;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istanbul_flight/data/score_repository.dart';
import 'package:istanbul_flight/game/game_phase.dart';
import 'package:istanbul_flight/game/istanbul_flight_game.dart';
import 'package:istanbul_flight/main.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import '../test/fakes.dart';

const _frame = Duration(milliseconds: 16);
const _modals = [
  Overlays.profile, Overlays.shop, Overlays.discovery, Overlays.leaderboard, Overlays.daily,
  Overlays.events, Overlays.missions, Overlays.achievements, Overlays.settings, Overlays.howTo,
];

void main() {
  testWidgets('110 uçuş: birikme taraması', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    var now = DateTime.utc(2026, 11, 11, 12);
    final t = TestServices(clock: () => now);
    final game = IstanbulFlightGame(
      scores: InMemoryScoreRepository(),
      random: Random(3),
      pickupRandom: Random(1),
      loadArt: false,
      services: t.services,
    );
    await tester.pumpWidget(MartiApp(game: game));
    await tester.pump(const Duration(milliseconds: 100));

    late VmService vm;
    late String iso;
    await tester.runAsync(() async {
      final info = await Service.getInfo();
      vm = await vmServiceConnectUri(info.serverWebSocketUri.toString());
      iso = Service.getIsolateId(di.Isolate.current)!;
    });

    Future<(Map<String, int>, int)> snap() async {
      late Map<String, int> counts;
      late int heap;
      await tester.runAsync(() async {
        final p = await vm.getAllocationProfile(iso, gc: true);
        counts = {
          for (final m in p.members!)
            if ((m.instancesCurrent ?? 0) > 0)
              '${m.classRef?.name} (${m.classRef?.library?.uri?.split('/').take(3).join('/')})': m.instancesCurrent!,
        };
        heap = (await vm.getMemoryUsage(iso)).heapUsage!;
      });
      return (counts, heap);
    }

    var flights = 0;
    Future<void> fly() async {
      final kind = flights % 10;
      if (kind == 3) {
        game.startDaily(ranked: false);
      } else if (kind == 7) {
        final slot = t.services.events.activeCup();
        if (slot != null) game.startEvent(t.services.events.definition(slot));
      } else {
        game.startFromMenu();
      }
      await tester.pump(_frame);
      game.handleTap();
      for (var i = 0; i < 600 && game.phase.value == GamePhase.playing; i++) {
        await tester.pump(_frame);
      }
      for (var i = 0; i < 400 && !game.canRestart.value; i++) {
        await tester.pump(_frame);
      }
      await tester.pump(_frame);
      game.restart();
      await tester.pump(_frame);
      flights++;
      if (flights % 5 == 0) {
        for (final m in _modals) {
          game.openModal(m);
          await tester.pump(_frame);
          await tester.pump(const Duration(milliseconds: 300));
          game.closeModal();
          await tester.pump(_frame);
        }
      }
      now = now.add(const Duration(minutes: 1));
    }

    String status() =>
        'dünya ${game.world.children.length} · engel ${game.obstacles.length} · tehlike ${game.hazardViews.length} '
        '· efekt ${game.fx.activeCount} · dinleyici ${t.services.listeners.length} '
        '· kayıt ${jsonEncode(t.services.progress.value.toJson()).length} B';

    while (flights < 10) {
      await fly();
    }
    final (c10, h10) = await snap();
    print('10 uçuş: heap ${(h10 / 1048576).toStringAsFixed(1)} MB · ${status()}');
    while (flights < 60) {
      await fly();
    }
    final (c60, h60) = await snap();
    print('60 uçuş: heap ${(h60 / 1048576).toStringAsFixed(1)} MB · ${status()}');
    while (flights < 110) {
      await fly();
    }
    final (c110, h110) = await snap();
    print('110 uçuş: heap ${(h110 / 1048576).toStringAsFixed(1)} MB · ${status()}');

    final grow = <String>[];
    for (final k in c110.keys) {
      final a = c10[k] ?? 0, b = c60[k] ?? 0, c = c110[k]!;
      if (b - a >= 10 && c - b >= 10) grow.add('$k: $a → $b → $c');
    }
    grow.sort();
    print('İki aralıkta da ≥10 büyüyen sınıflar (${grow.length}):');
    for (final g in grow) {
      print('  $g');
    }
    await tester.runAsync(() => vm.dispose());
  }, timeout: const Timeout(Duration(minutes: 20)));
}
