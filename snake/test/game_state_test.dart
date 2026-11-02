import 'package:flutter_test/flutter_test.dart';
import 'package:snake/game/game_state.dart';

void main() {
  group('Direction', () {
    test('isOppositeOf pairs up/down and left/right', () {
      expect(Direction.up.isOppositeOf(Direction.down), isTrue);
      expect(Direction.down.isOppositeOf(Direction.up), isTrue);
      expect(Direction.left.isOppositeOf(Direction.right), isTrue);
      expect(Direction.up.isOppositeOf(Direction.left), isFalse);
      expect(Direction.right.isOppositeOf(Direction.right), isFalse);
    });

    test('vectors point the right way', () {
      expect(Direction.up.vector, const Point(0, -1));
      expect(Direction.down.vector, const Point(0, 1));
      expect(Direction.left.vector, const Point(-1, 0));
      expect(Direction.right.vector, const Point(1, 0));
    });
  });

  group('initial state', () {
    test('snake starts at the center heading right', () {
      final s = GameState(gridSize: 20);
      expect(s.status, GameStatus.ready);
      expect(s.direction, Direction.right);
      expect(s.snake.length, 3);
      expect(s.head, const Point(10, 10));
      expect(s.score, 0);
      expect(s.tickMs, GameState.startTickMs);
    });

    test('food spawns on the board and not on the snake', () {
      final s = GameState(gridSize: 20);
      final f = s.food!;
      expect(f.x, inInclusiveRange(0, 19));
      expect(f.y, inInclusiveRange(0, 19));
      expect(s.snake.contains(f), isFalse);
    });
  });

  group('direction input', () {
    test('ready: any direction starts the run (even opposite heading)', () {
      final s = GameState(gridSize: 20);
      expect(s.setDirection(Direction.left), isTrue);
      expect(s.status, GameStatus.running);
      expect(s.direction, Direction.left);
    });

    test('running: 180 degree reversal is ignored', () {
      final s = GameState(gridSize: 20)..start();
      expect(s.setDirection(Direction.left), isFalse);
      expect(s.direction, Direction.right);
    });

    test('running: a turn is applied on the next step', () {
      final s = GameState(gridSize: 20)..start();
      s.setDirection(Direction.down);
      final head = s.head;
      s.step();
      expect(s.direction, Direction.down);
      expect(s.head, Point(head.x, head.y + 1));
    });
  });

  group('movement and collision', () {
    test('moves one cell per step', () {
      final s = GameState(
        gridSize: 20,
        snake: const [Point(5, 10), Point(4, 10), Point(3, 10)],
        food: const Point(15, 15),
      )..start();
      s.step();
      expect(s.head, const Point(6, 10));
      expect(s.snake.length, 3);
    });

    test('wall collision ends the game', () {
      final s = GameState(
        gridSize: 5,
        snake: const [Point(4, 2), Point(3, 2), Point(2, 2)],
        food: const Point(0, 0),
      )..start();
      s.step();
      expect(s.status, GameStatus.over);
      expect(s.won, isFalse);
    });

    test('self collision ends the game', () {
      // Head at (2,1) turns down into the body cell (2,2).
      final s = GameState(
        gridSize: 5,
        snake: const [
          Point(2, 1),
          Point(2, 2),
          Point(1, 2),
          Point(1, 1)
        ],
        food: const Point(4, 4),
      )..start();
      s.setDirection(Direction.down);
      s.step();
      expect(s.status, GameStatus.over);
    });

    test('moving into the cell the tail vacates is safe', () {
      // S-shaped snake heading right: the tail cell (3,2) is vacated on
      // this same step, so the head may move into it without a collision.
      final s = GameState(
        gridSize: 5,
        snake: const [Point(2, 2), Point(2, 1), Point(3, 1), Point(3, 2)],
        food: const Point(0, 0),
      )..start();
      s.step(); // head moves right into (3,2), the cell the tail vacates
      expect(s.status, GameStatus.running);
      expect(s.head, const Point(3, 2));
      expect(s.snake.length, 4);
    });

    test('step is a no-op while paused or over', () {
      final s = GameState(
        gridSize: 20,
        snake: const [Point(5, 10), Point(4, 10), Point(3, 10)],
        food: const Point(15, 15),
      )..start();
      s.pause();
      s.step();
      expect(s.head, const Point(5, 10));
      expect(s.status, GameStatus.paused);
    });
  });

  group('food, score and speed', () {
    test('eating grows the snake, scores and speeds up', () {
      final s = GameState(
        gridSize: 10,
        snake: const [Point(2, 2), Point(1, 2), Point(0, 2)],
        food: const Point(3, 2),
      )..start();
      final tickBefore = s.tickMs;
      s.step();
      expect(s.score, GameState.scorePerFood);
      expect(s.snake.length, 4);
      expect(s.tickMs, tickBefore - GameState.speedUpPerFood);
    });

    test('respawned food never lands on the snake', () {
      final s = GameState(
        gridSize: 10,
        snake: const [Point(2, 2), Point(1, 2), Point(0, 2)],
        food: const Point(3, 2),
      )..start();
      s.step();
      expect(s.food, isNotNull);
      expect(s.snake.contains(s.food!), isFalse);
    });

    test('speed never drops below the minimum', () {
      final s = GameState(gridSize: 100)..start();
      s.placeFood(s.head + Direction.right.vector);
      for (var i = 0; i < 40 && s.status == GameStatus.running; i++) {
        s.step();
        if (s.status == GameStatus.running) {
          s.placeFood(s.head + Direction.right.vector);
        }
      }
      expect(s.tickMs, GameState.minTickMs);
    });

    test('filling the board is a win', () {
      final s = GameState(
        gridSize: 2,
        snake: const [Point(0, 0), Point(1, 0), Point(1, 1)],
        food: const Point(0, 1),
      )..start();
      s.setDirection(Direction.down);
      s.step();
      expect(s.won, isTrue);
      expect(s.status, GameStatus.over);
      expect(s.food, isNull);
    });
  });

  group('lifecycle', () {
    test('pause and resume', () {
      final s = GameState(
        gridSize: 20,
        snake: const [Point(5, 10), Point(4, 10), Point(3, 10)],
        food: const Point(15, 15),
      )..start();
      s.pause();
      expect(s.status, GameStatus.paused);
      s.resume();
      expect(s.status, GameStatus.running);
    });

    test('restart resets score, speed and snake', () {
      final s = GameState(
        gridSize: 10,
        snake: const [Point(2, 2), Point(1, 2), Point(0, 2)],
        food: const Point(3, 2),
      )..start();
      s.step(); // eat one food
      s.restart();
      expect(s.status, GameStatus.running);
      expect(s.score, 0);
      expect(s.tickMs, GameState.startTickMs);
      expect(s.snake.length, 3);
      expect(s.direction, Direction.right);
    });

    test('setDirection is ignored after the game is over', () {
      final s = GameState(
        gridSize: 5,
        snake: const [Point(4, 2), Point(3, 2), Point(2, 2)],
        food: const Point(0, 0),
      )..start();
      s.step(); // into the wall
      expect(s.setDirection(Direction.down), isFalse);
      expect(s.status, GameStatus.over);
    });
  });
}
