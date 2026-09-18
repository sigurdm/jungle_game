import 'package:jungle_game/src/world_state.dart';

void main() {
  final world = JungleWorld.generate(seed: 42);
  // Sow berry seeds on a surface grass block near the player.
  final sowed = world.sowSeedAt(world.playerTileX + 1, world.playerTileY);
  // Advance the simulation by 1 second.
  world.update(1.0);
  if (sowed) {
    final status = world.evaluateShelterStatus(
      world.playerTileX,
      world.playerTileY,
    );
    assert(status.ambientTemperatureCelsius > 0);
  }
}
