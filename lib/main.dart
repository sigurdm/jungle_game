import 'package:flutter/material.dart';

import 'src/game_hud.dart';

export 'src/game_hud.dart';
export 'src/jungle_flame_game.dart';
export 'src/models.dart';
export 'src/world_state.dart';

/// Entry point for the 2D Side-Scrolling Jungle Survival Flutter Game.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JungleSurvivalApp());
}

/// Root Flutter application widget for the Jungle Survival game.
final class JungleSurvivalApp extends StatelessWidget {
  /// Creates the [JungleSurvivalApp].
  const JungleSurvivalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jungle Survival 2D',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const JungleSurvivalScreen(),
    );
  }
}
