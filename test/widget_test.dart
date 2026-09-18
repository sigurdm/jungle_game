import 'package:flutter_test/flutter_test.dart';
import 'package:jungle_game/main.dart';

void main() {
  group('JungleWorld 2D Block Survival, Physics & Bees', () {
    test(
      'generates jungle biomes, rivers, native villages, beehives, and wildlife',
      () {
        final world = JungleWorld.generate(seed: 42);
        expect(world.width, 160);
        expect(world.height, 56);
        expect(world.villagers.length, 2);
        expect(world.animals, isNotEmpty);

        // Verify river water blocks and wild beehives exist in the world.
        bool foundWater = false;
        bool foundBeehive = false;
        for (int y = 0; y < world.height; y++) {
          for (int x = 0; x < world.width; x++) {
            final b = world.getBlock(x, y);
            if (b == BlockType.water) foundWater = true;
            if (b == BlockType.beehive) foundBeehive = true;
          }
        }
        expect(foundWater, isTrue);
        expect(foundBeehive, isTrue);
        expect(world.animals.any((a) => a.type == AnimalType.beeSwarm), isTrue);
      },
    );

    test('water falls with gravity and extinguishes wildfire below', () {
      final world = JungleWorld.generate(seed: 10);
      const tx = 30;
      const ty = 12;
      world.blocks[ty][tx] = BlockType.water;
      world.blocks[ty + 1][tx] = BlockType.air;
      world.blocks[ty + 2][tx] = BlockType.wildfire;

      // Step cellular physics: water falls 1 tile into air.
      world.stepBlockPhysics();
      expect(world.getBlock(tx, ty), BlockType.air);
      expect(world.getBlock(tx, ty + 1), BlockType.water);

      // Step again: falling water hits and extinguishes the wildfire below!
      world.stepBlockPhysics();
      expect(world.getBlock(tx, ty + 2), BlockType.water);
    });

    test('wildfire spreads to adjacent flammable foliage blocks', () {
      final world = JungleWorld.generate(seed: 15);
      const tx = 40;
      const ty = 14;
      world.isRaining = false;
      world.blocks[ty][tx] = BlockType.wildfire;
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx != 0 || dy != 0) {
            world.blocks[ty + dy][tx + dx] = BlockType.leaves;
          }
        }
      }

      // Run a few physics ticks so at least one adjacent leaf block ignites.
      bool spreadOccurred = false;
      for (int i = 0; i < 6 && !spreadOccurred; i++) {
        world.stepBlockPhysics();
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            if ((dx != 0 || dy != 0) &&
                world.getBlock(tx + dx, ty + dy) == BlockType.wildfire) {
              spreadOccurred = true;
            }
          }
        }
      }
      expect(spreadOccurred, isTrue);
    });

    test(
      'harvesting beehive grants honeycomb and smoke prevents provoking bees',
      () {
        final world = JungleWorld.generate(seed: 33);
        final hx = world.playerTileX + 1;
        final hy = world.playerTileY;
        world.blocks[hy][hx] = BlockType.beehive;

        // Place a calming torch next to the hive.
        world.blocks[hy][hx + 1] = BlockType.torch;
        expect(world.hasBeeCalmingSmokeNear(hx, hy), isTrue);
        expect(world.interactOrPlaceAt(hx, hy), isTrue);
        expect(
          world.inventory[ItemType.honeycomb] ?? 0,
          greaterThanOrEqualTo(2),
        );
        expect(world.milestoneHarvestedHoney, isTrue);
        expect(
          world.animals
              .where((a) => a.type == AnimalType.beeSwarm && a.isAngry)
              .isEmpty,
          isTrue,
        );

        // Remove torch and unequip torch item -> harvesting provokes bees.
        world.blocks[hy][hx + 1] = BlockType.air;
        world.selectedHotbarIndex = 0; // Wood Pickaxe
        expect(world.interactOrPlaceAt(hx, hy), isTrue);
        expect(
          world.animals.any((a) => a.type == AnimalType.beeSwarm && a.isAngry),
          isTrue,
        );
      },
    );

    test('sowing seeds grows crops and yields fruit upon harvest', () {
      final world = JungleWorld.generate(seed: 7);
      final tx = world.playerTileX + 1;
      final ty = world.playerTileY;
      world.blocks[ty][tx] = BlockType.air;
      world.blocks[ty + 1][tx] = BlockType.grass;

      expect(world.sowSeedAt(tx, ty), isTrue);
      expect(world.getBlock(tx, ty + 1), BlockType.tilledSoil);

      final crop = world.crops['$tx,$ty'];
      expect(crop, isNotNull);

      crop!.growthProgress = 1.0;
      final beforeBerries = world.inventory[ItemType.jungleBerry] ?? 0;
      expect(world.interactOrPlaceAt(tx, ty), isTrue);
      expect(
        (world.inventory[ItemType.jungleBerry] ?? 0) > beforeBerries,
        isTrue,
      );
      expect(world.milestoneHarvestedFruit, isTrue);
    });

    test(
      'crafted shelter with roof, background walls, and campfire protects from cold',
      () {
        final world = JungleWorld.generate(seed: 12);
        final px = world.playerTileX;
        final py = world.playerTileY;

        for (int dx = -1; dx <= 1; dx++) {
          world.blocks[py - 2][px + dx] = BlockType.thatchRoof;
          world.walls[py][px + dx] = WallType.woodWall;
          world.walls[py - 1][px + dx] = WallType.woodWall;
        }
        world.blocks[py - 1][px - 2] = BlockType.doorClosed;
        world.blocks[py - 1][px + 2] = BlockType.doorClosed;
        world.blocks[py][px + 1] = BlockType.campfire;

        final status = world.evaluateShelterStatus(px, py);
        expect(status.hasRoof, isTrue);
        expect(status.hasBackgroundWalls, isTrue);
        expect(status.nearCampfire, isTrue);
        expect(status.isCompleteShelter, isTrue);
      },
    );
  });

  testWidgets(
    'JungleSurvivalApp renders Flame canvas, survival HUD, and mobile pad',
    (tester) async {
      await tester.pumpWidget(const JungleSurvivalApp());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Life'), findsOneWidget);
      expect(find.textContaining('Food'), findsOneWidget);
      expect(find.textContaining('Warmth'), findsOneWidget);
      expect(find.text('JUMP'), findsOneWidget);
    },
  );
}
