import 'package:shared_preferences/shared_preferences.dart';

/// En iyi skorun kalıcı kaydı.
abstract class ScoreRepository {
  Future<int> loadBest();
  Future<void> saveBest(int score);
}

class SharedPrefsScoreRepository implements ScoreRepository {
  SharedPrefsScoreRepository(this._prefs);

  static const _key = 'best_score_v1';
  final SharedPreferences _prefs;

  static Future<SharedPrefsScoreRepository> create() async =>
      SharedPrefsScoreRepository(await SharedPreferences.getInstance());

  @override
  Future<int> loadBest() async => _prefs.getInt(_key) ?? 0;

  @override
  Future<void> saveBest(int score) => _prefs.setInt(_key, score);
}

/// Testler ve kayıt erişilemediği durumlar için.
class InMemoryScoreRepository implements ScoreRepository {
  InMemoryScoreRepository([this._best = 0]);

  int _best;
  int saveCount = 0;

  @override
  Future<int> loadBest() async => _best;

  @override
  Future<void> saveBest(int score) async {
    _best = score;
    saveCount++;
  }
}
