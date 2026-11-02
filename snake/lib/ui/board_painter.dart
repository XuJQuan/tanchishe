import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../game/game_state.dart';

/// Draws the board, food and snake for the current [GameState].
class BoardPainter extends CustomPainter {
  BoardPainter(this.state);

  final GameState state;

  static const Color background = Color(0xFF0B1220);
  static const Color gridLine = Color(0x14FFFFFF);
  static const Color snakeBody = Color(0xFF22C55E);
  static const Color snakeHead = Color(0xFF86EFAC);
  static const Color foodColor = Color(0xFFF87171);

  @override
  void paint(Canvas canvas, Size size) {
    final n = state.gridSize;
    final cell = size.width / n;

    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final gridPaint = Paint()
      ..color = gridLine
      ..strokeWidth = 1;
    for (int i = 1; i < n; i++) {
      final line = i * cell;
      canvas.drawLine(Offset(line, 0), Offset(line, size.height), gridPaint);
      canvas.drawLine(Offset(0, line), Offset(size.width, line), gridPaint);
    }

    final f = state.food;
    if (f != null) {
      final inset = cell * 0.22;
      final rect = Rect.fromLTWH(
          f.x * cell + inset, f.y * cell + inset, cell - inset * 2,
          cell - inset * 2);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              rect, Radius.circular(rect.width * 0.3)),
          Paint()..color = foodColor);
    }

    // Tail first so the head paints on top.
    for (var i = state.snake.length - 1; i >= 0; i--) {
      final p = state.snake[i];
      final isHead = i == 0;
      final inset = isHead ? cell * 0.08 : cell * 0.14;
      final rect = Rect.fromLTWH(
          p.x * cell + inset, p.y * cell + inset, cell - inset * 2,
          cell - inset * 2);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              rect, Radius.circular(math.min(cell * 0.3, 8))),
          Paint()..color = isHead ? snakeHead : snakeBody);
    }
  }

  @override
  bool shouldRepaint(BoardPainter oldDelegate) {
    final a = state;
    final b = oldDelegate.state;
    return a.status != b.status ||
        a.score != b.score ||
        a.head != b.head ||
        a.food != b.food ||
        a.snake.length != b.snake.length;
  }
}
