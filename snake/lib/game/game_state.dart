import 'dart:math' as math;

/// A cell coordinate on the board.
class Point {
  const Point(this.x, this.y);

  final int x;
  final int y;

  Point operator +(Point other) => Point(x + other.x, y + other.y);

  @override
  bool operator ==(Object other) => other is Point && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Point($x, $y)';
}

/// Snake movement directions.
enum Direction { up, down, left, right }

extension DirectionVector on Direction {
  /// Unit vector for this direction.
  Point get vector => switch (this) {
        Direction.up => const Point(0, -1),
        Direction.down => const Point(0, 1),
        Direction.left => const Point(-1, 0),
        Direction.right => const Point(1, 0),
      };

  bool isOppositeOf(Direction other) =>
      vector.x + other.vector.x == 0 && vector.y + other.vector.y == 0;
}

/// Game phase.
enum GameStatus { ready, running, paused, over }

/// Pure snake rules with no UI or platform dependencies.
///
/// The snake body is ordered head-first. [step] advances the simulation by
/// one cell and is driven by the timer in [GameEngine].
class GameState {
  GameState({
    int gridSize = defaultGridSize,
    math.Random? random,
    List<Point>? snake,
    Point? food,
  })  : _size = gridSize,
        _random = random ?? math.Random() {
    if (snake != null) {
      this.snake.addAll(snake);
    } else {
      _initSnake();
    }
    _food = food ?? _randomFreeCell();
    if (_food == null) {
      _won = true;
      _status = GameStatus.over;
    }
  }

  static const int defaultGridSize = 20;
  static const int startTickMs = 150;
  static const int minTickMs = 60;
  static const int speedUpPerFood = 4;
  static const int scorePerFood = 10;

  final int _size;
  final math.Random _random;
  final List<Point> snake = <Point>[];

  Point? _food;
  int _score = 0;
  int _tickMs = startTickMs;
  GameStatus _status = GameStatus.ready;
  Direction _direction = Direction.right;
  Direction? _pendingDirection;
  bool _won = false;

  int get gridSize => _size;
  int get score => _score;
  int get tickMs => _tickMs;
  GameStatus get status => _status;
  Direction get direction => _direction;
  Point? get food => _food;
  bool get won => _won;
  Point get head => snake.first;

  void _initSnake() {
    final mid = _size ~/ 2;
    snake
      ..clear()
      ..add(Point(mid, mid))
      ..add(Point(mid - 1, mid))
      ..add(Point(mid - 2, mid));
  }

  /// Random cell not occupied by the snake, or null when the board is full.
  Point? _randomFreeCell() {
    final occupied = snake.toSet();
    final free = <Point>[
      for (int y = 0; y < _size; y++)
        for (int x = 0; x < _size; x++)
          if (!occupied.contains(Point(x, y))) Point(x, y),
    ];
    return free.isEmpty ? null : free[_random.nextInt(free.length)];
  }

  /// Starts a [GameStatus.ready] run.
  void start() {
    if (_status == GameStatus.ready) _status = GameStatus.running;
  }

  void pause() {
    if (_status == GameStatus.running) _status = GameStatus.paused;
  }

  void resume() {
    if (_status == GameStatus.paused) _status = GameStatus.running;
  }

  /// Resets the board and immediately starts a new run.
  void restart() {
    _score = 0;
    _tickMs = startTickMs;
    _won = false;
    _direction = Direction.right;
    _pendingDirection = null;
    _initSnake();
    _food = _randomFreeCell();
    _status = _food == null ? GameStatus.over : GameStatus.running;
  }

  /// Queues [direction] for the next [step].
  ///
  /// From [GameStatus.ready] any direction starts the run (even the one
  /// opposite to the initial heading, because the snake has not moved yet).
  /// While running, a 180 degree reversal is ignored.
  ///
  /// Returns true when this call started the run.
  bool setDirection(Direction direction) {
    if (_status == GameStatus.over) return false;
    if (_status == GameStatus.ready) {
      _direction = direction;
      _pendingDirection = null;
      _status = GameStatus.running;
      return true;
    }
    if (direction.isOppositeOf(_direction)) return false;
    _pendingDirection = direction;
    return false;
  }

  /// Advances the simulation by one cell.
  void step() {
    if (_status != GameStatus.running) return;

    final dir = _pendingDirection ?? _direction;
    _direction = dir;
    _pendingDirection = null;

    final newHead = head + dir.vector;
    if (newHead.x < 0 ||
        newHead.x >= _size ||
        newHead.y < 0 ||
        newHead.y >= _size) {
      _status = GameStatus.over;
      return;
    }

    final willEat = _food != null && newHead == _food;
    // The tail vacates its cell on this step unless the snake grows.
    final body = willEat ? snake : snake.sublist(0, snake.length - 1);
    if (body.contains(newHead)) {
      _status = GameStatus.over;
      return;
    }

    snake.insert(0, newHead);
    if (willEat) {
      _score += scorePerFood;
      _tickMs = math.max(minTickMs, _tickMs - speedUpPerFood);
      final next = _randomFreeCell();
      _food = next;
      if (next == null) {
        _won = true;
        _status = GameStatus.over;
      }
    } else {
      snake.removeLast();
    }
  }

  /// Test helper: overrides the food cell without playing a step.
  void placeFood(Point point) => _food = point;
}
