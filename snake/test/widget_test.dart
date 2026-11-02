import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snake/game/game_state.dart';
import 'package:snake/game/score_storage.dart';
import 'package:snake/ui/game_screen.dart';

Widget buildApp(ScoreStorage storage) => MaterialApp(home: GameScreen(storage: storage));

void main() {
  testWidgets('shows the start overlay and begins a run', (tester) async {
    await tester.pumpWidget(buildApp(MemoryScoreStorage()));

    expect(find.text('贪吃蛇'), findsOneWidget);
    expect(find.text('开始游戏'), findsOneWidget);
    expect(find.text('得分 0'), findsOneWidget);

    await tester.tap(find.text('开始游戏'));
    await tester.pump();

    expect(find.text('开始游戏'), findsNothing);
    expect(
        tester.state<GameScreenState>(find.byType(GameScreen))
            .engine
            .state
            .status,
        GameStatus.running);
  });

  testWidgets('keyboard steers the snake', (tester) async {
    await tester.pumpWidget(buildApp(MemoryScoreStorage()));
    await tester.tap(find.text('开始游戏'));
    await tester.pump();

    final engine =
        tester.state<GameScreenState>(find.byType(GameScreen)).engine;
    final before = engine.state.head;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 300));
    expect(engine.state.head, isNot(before));
    expect(engine.state.direction, Direction.down);
  });

  testWidgets('crashing ends the run and restart resets it', (tester) async {
    await tester.pumpWidget(buildApp(MemoryScoreStorage()));
    await tester.tap(find.text('开始游戏'));
    await tester.pump();

    // Drive the snake straight into the right wall.
    final engine =
        tester.state<GameScreenState>(find.byType(GameScreen)).engine;
    // Capped loop: a regression that keeps the run "running" must fail
    // the test instead of hanging the runner.
    var pumps = 0;
    while (engine.state.status == GameStatus.running && pumps < 200) {
      await tester.pump(const Duration(milliseconds: 100));
      pumps++;
    }
    expect(find.text('游戏结束'), findsOneWidget);
    expect(find.text('再来一局'), findsOneWidget);

    await tester.tap(find.text('再来一局'));
    await tester.pump();
    expect(find.text('游戏结束'), findsNothing);
    expect(engine.state.score, 0);
    expect(engine.state.status, GameStatus.running);
  });

  testWidgets('high score is recorded and persisted', (tester) async {
    final storage = MemoryScoreStorage();
    await tester.pumpWidget(buildApp(storage));

    await tester.tap(find.text('开始游戏'));
    await tester.pump();

    final engine =
        tester.state<GameScreenState>(find.byType(GameScreen)).engine;
    // Put the food one cell ahead of the head so the first tick eats it,
    // then let the run end at the wall.
    engine.state.placeFood(
        engine.state.head + Direction.right.vector);
    var pumps = 0;
    while (engine.state.status == GameStatus.running && pumps < 200) {
      await tester.pump(const Duration(milliseconds: 100));
      pumps++;
    }
    expect(engine.state.status, GameStatus.over);
    expect(engine.state.score, greaterThan(0));
    expect(storage.value, engine.state.score);
  });
}
