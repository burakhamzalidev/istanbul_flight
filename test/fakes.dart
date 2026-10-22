import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:istanbul_flight/game/game_services.dart';
import 'package:istanbul_flight/services/audio_service.dart';
import 'package:istanbul_flight/services/game_center/game_center_controller.dart';
import 'package:istanbul_flight/services/haptics_service.dart';
import 'package:istanbul_flight/services/progress.dart';
import 'package:istanbul_flight/services/settings.dart';
import 'package:istanbul_flight/services/share_service.dart';

/// Ses çağrılarını kaydeder (oyun hangi anda ne çaldı).
class RecordingAudio implements AudioService {
  final sfx = <Sfx>[];
  final music = <MusicTrack?>[];
  final ambience = <Ambience?>[];
  final cues = <AmbientCue>[];
  int pauses = 0, resumes = 0, ducks = 0, unlocks = 0;
  double musicVolume = -1, sfxVolume = -1;

  @override
  Future<void> init() async {}
  @override
  void playSfx(Sfx s) => sfx.add(s);
  @override
  void playMusic(MusicTrack t) => music.add(t);
  @override
  void stopMusic() => music.add(null);
  @override
  void setAmbience(Ambience? a) => ambience.add(a);
  @override
  void playCue(AmbientCue c) => cues.add(c);
  @override
  void duck() => ducks++;
  @override
  void pauseAll() => pauses++;
  @override
  void resumeAll() => resumes++;
  @override
  void setVolumes({required double music, required double sfx}) {
    musicVolume = music;
    sfxVolume = sfx;
  }

  @override
  void unlock() => unlocks++;
  @override
  void dispose() {}
}

class RecordingHaptics extends HapticsService {
  final calls = <String>[];
  @override
  void light() => enabled ? calls.add('light') : null;
  @override
  void medium() => enabled ? calls.add('medium') : null;
  @override
  void heavy() => enabled ? calls.add('heavy') : null;
}

class FakeShare implements ShareService {
  FakeShare([this.outcome = ShareOutcome.shared]);

  ShareOutcome outcome;
  Uint8List? lastPng;
  String? lastText;
  Rect? lastOrigin;

  @override
  Future<ShareOutcome> sharePostcard(
    Uint8List png,
    String text, {
    Rect? origin,
  }) async {
    lastPng = png;
    lastText = text;
    lastOrigin = origin;
    return outcome;
  }
}

/// Test servis paketi: kaydedici ses/titreşim/paylaşım, bellek içi ayar ve ilerleme.
class TestServices {
  TestServices({
    GameSettings settings = const GameSettings(),
    PlayerProgress progress = const PlayerProgress(),
    GameCenterController Function(ProgressController progress)? gameCenter,
  }) : settingsRepo = InMemorySettingsRepository(settings),
       progressRepo = InMemoryProgressRepository(progress) {
    final progressController = ProgressController(progressRepo, progress);
    services = GameServices(
      audio: audio,
      haptics: haptics,
      settings: SettingsController(settingsRepo, settings),
      progress: progressController,
      share: share,
      gameCenter: gameCenter?.call(progressController),
    );
  }

  final audio = RecordingAudio();
  final haptics = RecordingHaptics();
  final share = FakeShare();
  final InMemorySettingsRepository settingsRepo;
  final InMemoryProgressRepository progressRepo;
  late final GameServices services;
}
