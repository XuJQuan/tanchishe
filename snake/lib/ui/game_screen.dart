import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game_engine.dart';
import '../game/game_state.dart';
import '../game/score_storage.dart';
import 'board_painter.dart';
import 'game_pad.dart';

/// Main (and only) screen: HUD, board, touch d-pad and state overlays.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.storage});

  final ScoreStorage storage;

  @override
  State<GameScreen> createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> {
  /// Exposed for tests to inspect or drive the engine.
  GameEngine get engine => _engine;

  late final GameEngine _engine;
  final FocusNode _focusNode = FocusNode();
  int _highScore = 0;
  // D-pad is shown out of the box on phones; on web/desktop it appears
  // once a touch pointer is detected.
  bool _showPad = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  Offset? _dragStart;
  bool _dragConsumed = false;
  static const double _swipeThreshold = 24;

  @override
  void initState() {
    super.initState();
    _engine = GameEngine();
    _engine.addListener(_onEngineChanged);
    widget.storage.loadHighScore().then((value) {
      if (mounted) setState(() => _highScore = value);
    });
  }

  void _onEngineChanged() {
    final score = _engine.state.score;
    if (score > _highScore) {
      _highScore = score;
      widget.storage.saveHighScore(score);
    }
  }

  void _steer(Direction direction) => _engine.setDirection(direction);

  @override
  void dispose() {
    _engine.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.keyW:
        _steer(Direction.up);
      case LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.keyS:
        _steer(Direction.down);
      case LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.keyA:
        _steer(Direction.left);
      case LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.keyD:
        _steer(Direction.right);
      case LogicalKeyboardKey.space:
        _engine.togglePause();
      case LogicalKeyboardKey.keyR:
        _engine.restart();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Listener(
          onPointerDown: (event) {
            if (event.kind == PointerDeviceKind.touch && !_showPad) {
              setState(() => _showPad = true);
            }
          },
          child: Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _onKeyEvent,
            child: GestureDetector(
              onTap: () => _focusNode.requestFocus(),
              behavior: HitTestBehavior.translucent,
              child: ListenableBuilder(
                listenable: _engine,
                builder: (context, _) {
                  final state = _engine.state;
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildHud(state, theme),
                        const SizedBox(height: 12),
                        Expanded(child: _buildBoard(state)),
                        if (_showPad)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: GamePad(onDirection: _steer),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHud(GameState state, ThemeData theme) {
    final high = math.max(_highScore, state.score);
    return Row(
      children: [
        _scoreChip('得分', state.score),
        const SizedBox(width: 8),
        _scoreChip('最高', high),
        const Spacer(),
        IconButton(
          tooltip: state.status == GameStatus.paused ? '继续' : '暂停',
          icon: Icon(state.status == GameStatus.paused
              ? Icons.play_circle_outlined
              : Icons.pause_circle_outlined),
          onPressed:
              state.status == GameStatus.over ? null : _engine.togglePause,
        ),
        IconButton(
          tooltip: '重新开始',
          icon: const Icon(Icons.refresh),
          onPressed: _engine.restart,
        ),
      ],
    );
  }

  Widget _scoreChip(String label, int value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$label $value',
          style: TextStyle(
            color: Colors.white70,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );

  Widget _buildBoard(GameState state) {
    return LayoutBuilder(builder: (context, constraints) {
      final side = math.min(constraints.maxWidth, constraints.maxHeight);
      return Center(
        child: Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: BoardPainter(state)),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) {
                    _dragStart = details.localPosition;
                    _dragConsumed = false;
                  },
                  onPanUpdate: (details) {
                    final start = _dragStart;
                    if (start == null || _dragConsumed) return;
                    final dx = details.localPosition.dx - start.dx;
                    final dy = details.localPosition.dy - start.dy;
                    if (dx.abs() < _swipeThreshold &&
                        dy.abs() < _swipeThreshold) {
                      return;
                    }
                    final direction = dx.abs() > dy.abs()
                        ? (dx > 0 ? Direction.right : Direction.left)
                        : (dy > 0 ? Direction.down : Direction.up);
                    _steer(direction);
                    _dragConsumed = true;
                  },
                  onPanEnd: (_) => _dragStart = null,
                ),
                if (state.status != GameStatus.running)
                  _buildOverlay(state),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildOverlay(GameState state) {
    final isOver = state.status == GameStatus.over;
    final title = switch (state.status) {
      GameStatus.ready => '贪吃蛇',
      GameStatus.paused => '已暂停',
      _ => state.won ? '恭喜通关！' : '游戏结束',
    };
    final buttonLabel = switch (state.status) {
      GameStatus.ready => '开始游戏',
      GameStatus.paused => '继续',
      _ => '再来一局',
    };
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (isOver) ...[
            const SizedBox(height: 8),
            Text('本局得分 ${state.score}'),
            Text(
              '历史最高 ${math.max(_highScore, state.score)}',
              style: TextStyle(color: Colors.white54),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              switch (state.status) {
                case GameStatus.over:
                  _engine.restart();
                case GameStatus.paused:
                  _engine.resume();
                case GameStatus.ready:
                  _engine.start();
                case GameStatus.running:
                  break;
              }
              _focusNode.requestFocus();
            },
            icon: const Icon(Icons.play_arrow),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}
