import 'package:flutter_test/flutter_test.dart';
import 'package:snake/game/game_engine.dart';
import 'package:snake/game/game_state.dart';

GameState freshState() => GameState(
      gridSize: 20,
      snake: const [Point(5, 10), Point(4, 10), Point(3, 10)],
      food: const Point(15, 15),
    );

void main() {
  test('start begins ticking and the snake moves', () async {
    final engine = GameEngine(state: freshState());
    engine.start();
    expect(engine.state.status, GameStatus.running);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(engine.state.head.x, greaterThan(5));
    engine.dispose();
  });

  test('ticking continues step after step, not just the first', () async {
    final engine = GameEngine(state: freshState());
    engine.start();
    // Poll until the snake has taken 7 steps (150ms tick each); give up
    // after 5s so a one-shot-timer regression fails instead of hanging.
    final deadline =
        DateTime.now().add(const Duration(seconds: 5));
    while (engine.state.head.x < 12 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(engine.state.head.x, greaterThanOrEqualTo(12));
    engine.dispose();
  });

  test('pause halts ticking, resume continues', () async {
    final engine = GameEngine(state: freshState());
    engine.start();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    engine.pause();
    final head = engine.state.head;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(engine.state.head, head);
    engine.resume();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(engine.state.head, isNot(head));
    engine.dispose();
  });

  test('restart resets the run and keeps ticking', () async {
    final engine = GameEngine(state: freshState());
    engine.start();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    engine.restart();
    expect(engine.state.score, 0);
    expect(engine.state.snake.length, 3);
    expect(engine.state.status, GameStatus.running);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(engine.state.head.x, greaterThan(9));
    engine.dispose();
  });

  test('setDirection from ready starts the run', () {
    final engine = GameEngine(state: freshState());
    engine.setDirection(Direction.down);
    expect(engine.state.status, GameStatus.running);
    engine.dispose();
  });

  test('disposal stops the timer', () async {
    final engine = GameEngine(state: freshState());
    engine.start();
    engine.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(engine.state.head.x, 5);
  });
}
