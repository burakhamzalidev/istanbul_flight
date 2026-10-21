import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Ses oturumu (bütün oyuncular için, oyuncular oluşturulmadan önce çağrılır).
///
/// * iOS: `ambient` kategorisi → sessiz anahtarına uyar, kullanıcının çaldığı müzikle karışır.
///   (Varsayılan `playback` sessiz modu yok sayardı.)
/// * Android: kullanım türü `game`, ses odağı alınmaz (`AudioFocus.none`) → arka plandaki müzik
///   durmaz; ses düzeyi medya kanalından.
/// Web'de ve desteklenmeyen platformlarda hiçbir şey yapmaz; hata oyunu etkilemez.
Future<void> configureAudioSession() async {
  if (kIsWeb) return;
  try {
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.game,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
      ),
    );
  } catch (e) {
    debugPrint('Ses oturumu ayarlanamadı: $e');
  }
}

/// Oyun efektleri (assets/audio/sfx_*.wav).
enum Sfx {
  flap('sfx_flap.wav', 0.35, 4),
  collect('sfx_collect.wav', 0.8, 2),
  nearMiss('sfx_near_miss.wav', 0.8, 2),
  crash('sfx_crash.wav', 0.9, 1),
  splash('sfx_splash.wav', 0.6, 1),
  button('sfx_button.wav', 0.5, 2),
  zone('sfx_zone.wav', 0.6, 1),
  record('sfx_record.wav', 0.9, 1);

  const Sfx(this.file, this.gain, this.voices);
  final String file;

  /// Karışım dengesi: efektler birbirini bastırmasın diye dosya başına kazanç.
  final double gain;

  /// Aynı anda en fazla kaç kopya çalabilir (ses havuzu).
  final int voices;
}

enum MusicTrack {
  menu('music_menu.wav', 0.5, loop: true),
  game('music_game.wav', 0.38, loop: true),
  gameOver('music_gameover.wav', 0.55, loop: false);

  const MusicTrack(this.file, this.gain, {required this.loop});
  final String file;
  final double gain;
  final bool loop;
}

/// Bölge ortam döngüsü.
enum Ambience {
  harbor('amb_waves.wav', 0.32),
  windy('amb_wind.wav', 0.28);

  const Ambience(this.file, this.gain);
  final String file;
  final double gain;
}

/// Ara sıra çalan uzak ortam sesleri.
enum AmbientCue {
  gull('amb_gull.wav', 0.4),
  ferryHorn('amb_ferry_horn.wav', 0.38);

  const AmbientCue(this.file, this.gain);
  final String file;
  final double gain;
}

/// Ses servisi. Oyun mantığı sadece bu arayüzü bilir; testlerde sessiz/kaydedici sürüm kullanılır.
abstract class AudioService {
  Future<void> init();
  void playSfx(Sfx sfx);
  void playMusic(MusicTrack track);
  void stopMusic();
  void setAmbience(Ambience? ambience);
  void playCue(AmbientCue cue);

  /// Müziği kısa süre kısar (çarpışma, rekor): efekt öne çıkar.
  void duck();
  void pauseAll();
  void resumeAll();

  /// 0..1 düzeyler (sessiz modda 0).
  void setVolumes({required double music, required double sfx});

  /// Web: tarayıcı ilk kullanıcı etkileşiminden önce sesi engeller. İlk dokunuşta çağrılır.
  void unlock();
  void dispose();
}

class SilentAudioService implements AudioService {
  const SilentAudioService();
  @override
  Future<void> init() async {}
  @override
  void playSfx(Sfx sfx) {}
  @override
  void playMusic(MusicTrack track) {}
  @override
  void stopMusic() {}
  @override
  void setAmbience(Ambience? ambience) {}
  @override
  void playCue(AmbientCue cue) {}
  @override
  void duck() {}
  @override
  void pauseAll() {}
  @override
  void resumeAll() {}
  @override
  void setVolumes({required double music, required double sfx}) {}
  @override
  void unlock() {}
  @override
  void dispose() {}
}

/// audioplayers tabanlı uygulama. Her hata yakalanır: ses çalınamazsa oyun etkilenmez.
class AudioplayersAudioService implements AudioService {
  static const _dir = 'audio/'; // AudioCache öneki 'assets/' → assets/audio/...

  final Map<Sfx, AudioPool> _pools = {};
  final AudioPlayer _music = AudioPlayer(playerId: 'marti_music');
  final AudioPlayer _ambience = AudioPlayer(playerId: 'marti_ambience');
  final AudioPlayer _cue = AudioPlayer(playerId: 'marti_cue');

  double _musicVol = 0.7, _sfxVol = 0.9, _duckFactor = 1;
  MusicTrack? _track;
  Ambience? _amb;
  bool _ready = false, _paused = false, _musicStarted = false;
  Timer? _duckTimer;

  Future<void> _safe(String what, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      debugPrint('Ses: $what başarısız ($e)');
    }
  }

  @override
  Future<void> init() async {
    await _safe('başlatma', () async {
      await _music.setPlayerMode(PlayerMode.mediaPlayer);
      await _ambience.setReleaseMode(ReleaseMode.loop);
      for (final s in Sfx.values) {
        _pools[s] = await AudioPool.createFromAsset(
          path: '$_dir${s.file}',
          maxPlayers: s.voices,
        );
      }
      _ready = true;
    });
  }

  @override
  void playSfx(Sfx sfx) {
    final pool = _pools[sfx];
    final v = _sfxVol * sfx.gain;
    if (!_ready || pool == null || v <= 0 || _paused) return;
    _safe('efekt ${sfx.name}', () => pool.start(volume: v));
  }

  double get _musicLevel => _musicVol * (_track?.gain ?? 0.5) * _duckFactor;

  @override
  void playMusic(MusicTrack track) {
    if (_track == track && _musicStarted) return;
    _track = track;
    _musicStarted = false;
    _safe('müzik ${track.name}', () async {
      await _music.stop();
      await _music.setReleaseMode(
        track.loop ? ReleaseMode.loop : ReleaseMode.stop,
      );
      if (_musicVol <= 0) return;
      await _music.play(AssetSource('$_dir${track.file}'), volume: _musicLevel);
      _musicStarted = true;
    });
  }

  @override
  void stopMusic() {
    _track = null;
    _musicStarted = false;
    _safe('müzik durdurma', _music.stop);
  }

  @override
  void setAmbience(Ambience? ambience) {
    if (ambience == _amb) return;
    _amb = ambience;
    _safe('ortam', () async {
      await _ambience.stop();
      if (ambience == null || _sfxVol <= 0) return;
      await _ambience.play(
        AssetSource('$_dir${ambience.file}'),
        volume: _sfxVol * ambience.gain,
      );
    });
  }

  @override
  void playCue(AmbientCue cue) {
    if (_sfxVol <= 0 || _paused) return;
    _safe(
      'ortam sesi ${cue.name}',
      () => _cue.play(
        AssetSource('$_dir${cue.file}'),
        volume: _sfxVol * cue.gain,
      ),
    );
  }

  @override
  void duck() {
    _duckFactor = 0.3;
    _safe('kısma', () => _music.setVolume(_musicLevel));
    _duckTimer?.cancel();
    _duckTimer = Timer(const Duration(milliseconds: 1400), () {
      _duckFactor = 1;
      _safe('kısma bitişi', () => _music.setVolume(_musicLevel));
    });
  }

  @override
  void pauseAll() {
    _paused = true;
    _safe('duraklatma', () async {
      await _music.pause();
      await _ambience.pause();
    });
  }

  @override
  void resumeAll() {
    _paused = false;
    _safe('devam', () async {
      if (_track != null && _musicVol > 0) await _music.resume();
      if (_amb != null && _sfxVol > 0) await _ambience.resume();
    });
  }

  @override
  void setVolumes({required double music, required double sfx}) {
    final wasSilent = _musicVol <= 0;
    _musicVol = music;
    _sfxVol = sfx;
    _safe('ses düzeyi', () async {
      await _music.setVolume(_musicLevel);
      await _ambience.setVolume(_sfxVol * (_amb?.gain ?? 0.3));
    });
    // Ses 0'dan açıldıysa müzik/ortam yeniden başlasın
    final t = _track;
    if (wasSilent && music > 0 && t != null) {
      _track = null;
      playMusic(t);
    }
    if (sfx > 0 && _amb != null) {
      final a = _amb;
      _amb = null;
      setAmbience(a);
    } else if (sfx <= 0) {
      _safe('ortam durdurma', _ambience.stop);
    }
  }

  @override
  void unlock() {
    final t = _track;
    if (t != null && !_musicStarted) {
      _track = null;
      playMusic(t);
    }
    final a = _amb;
    if (a != null) {
      _amb = null;
      setAmbience(a);
    }
  }

  @override
  void dispose() {
    _duckTimer?.cancel();
    for (final p in _pools.values) {
      p.dispose();
    }
    _music.dispose();
    _ambience.dispose();
    _cue.dispose();
  }
}
