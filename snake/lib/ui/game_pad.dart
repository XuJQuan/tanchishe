import 'package:flutter/material.dart';

import '../game/game_state.dart';

/// On-screen d-pad, shown on touch devices.
class GamePad extends StatelessWidget {
  const GamePad({super.key, required this.onDirection});

  final ValueChanged<Direction> onDirection;

  static const double _button = 48;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, Direction direction) => SizedBox(
          width: _button,
          height: _button,
          child: Material(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onDirection(direction),
              child: Icon(icon, size: 22, color: Colors.white70),
            ),
          ),
        );

    final spacer = SizedBox(width: _button, height: _button);

    return SizedBox(
      width: _button * 3 + 8,
      height: _button * 3 + 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            spacer,
            button(Icons.arrow_upward, Direction.up),
            spacer,
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            button(Icons.arrow_back, Direction.left),
            button(Icons.arrow_downward, Direction.down),
            button(Icons.arrow_forward, Direction.right),
          ]),
          Row(mainAxisSize: MainAxisSize.min,
              children: [spacer, spacer, spacer]),
        ],
      ),
    );
  }
}
