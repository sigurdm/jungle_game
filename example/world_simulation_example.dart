import 'package:jungle_game/src/models.dart';
import 'package:jungle_game/src/world_state.dart';

void main() {
  final world = JungleWorld.generate(seed: 42);
  // Sow medicinal herb seeds and berry seeds on surface grass blocks near the player.
  final sowedHerb = world.sowSeedAt(
    world.playerTileX + 1,
    world.playerTileY,
    ItemType.healingHerbSeeds,
  );
  final sowedBerry = world.sowSeedAt(
    world.playerTileX + 2,
    world.playerTileY,
    ItemType.berrySeeds,
  );
  // Advance the simulation by 1 second.
  world.update(1.0);
  if (sowedHerb && sowedBerry) {
    final status = world.evaluateShelterStatus(
      world.playerTileX,
      world.playerTileY,
    );
    assert(status.ambientTemperatureCelsius > 0);
  }
}
