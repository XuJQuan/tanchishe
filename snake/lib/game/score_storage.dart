import 'package:shared_preferences/shared_preferences.dart';

/// Abstraction over high-score persistence so the UI and tests can swap
/// backends.
abstract class ScoreStorage {
  Future<int> loadHighScore();

  Future<void> saveHighScore(int score);
}

/// Persists the high score with `shared_preferences` (works on every
/// Flutter platform including web).
class SharedPreferencesScoreStorage implements ScoreStorage {
  const SharedPreferencesScoreStorage({this.key = 'snake.high_score'});

  final String key;

  @override
  Future<int> loadHighScore() async =>
      (await SharedPreferences.getInstance()).getInt(key) ?? 0;

  @override
  Future<void> saveHighScore(int score) async =>
      (await SharedPreferences.getInstance()).setInt(key, score);
}

/// In-memory implementation for tests and quick previews.
class MemoryScoreStorage implements ScoreStorage {
  int _value = 0;

  int get value => _value;

  @override
  Future<int> loadHighScore() async => _value;

  @override
  Future<void> saveHighScore(int score) async => _value = score;
}
