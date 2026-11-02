import 'dart:async';

import 'package:flutter/foundation.dart';

import 'game_state.dart';

/// Drives a [GameState] on a [Timer] and notifies listeners on every tick.
class GameEngine extends ChangeNotifier {
  GameEngine({GameState? state}) : _state = state ?? GameState();

  final GameState _state;
  Timer? _timer;
  bool _disposed = false;

  GameState get state => _state;

  bool get isRunning => _state.status == GameStatus.running;

  /// Starts a fresh run from the ready screen.
  void start() {
    if (_state.status != GameStatus.ready) return;
    _state.start();
    _schedule();
    notifyListeners();
  }

  void pause() {
    if (_state.status != GameStatus.running) return;
    _state.pause();
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void resume() {
    if (_state.status != GameStatus.paused) return;
    _state.resume();
    _schedule();
    notifyListeners();
  }

  void togglePause() {
    switch (_state.status) {
      case GameStatus.running:
        pause();
      case GameStatus.paused:
        resume();
      case GameStatus.ready:
        start();
      case GameStatus.over:
        break;
    }
  }

  /// Resets the board and starts immediately.
  void restart() {
    _state.restart();
    if (_state.status == GameStatus.running) _schedule();
    notifyListeners();
  }

  /// Feeds a user direction into the state; starts a ready run.
  void setDirection(Direction direction) {
    final started = _state.setDirection(direction);
    if (started) _schedule();
    notifyListeners();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: _state.tickMs), _tick);
  }

  void _tick() {
    if (_disposed) return;
    _state.step();
    notifyListeners();
    // Keep the tick chain alive while the run is going. Each reschedule
    // re-reads tickMs, so speed-ups after eating apply to the next step.
    if (_state.status == GameStatus.running) _schedule();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
