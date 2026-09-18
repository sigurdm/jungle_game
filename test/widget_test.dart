import 'package:flutter_test/flutter_test.dart';
import 'package:jungle_game/main.dart';

void main() {
  group('JungleWorld 2D Block Survival Mechanics', () {
    test('generates jungle biomes, rivers, native villages, and predators', () {
      final world = JungleWorld.generate(seed: 42);
      expect(world.width, 160);
      expect(world.height, 56);
      expect(world.villagers.length, 2);
      expect(world.animals, isNotEmpty);

      // Verify river water blocks exist in the world.
      bool foundWater = false;
      for (int y = 0; y < world.height && !foundWater; y++) {
        for (int x = 0; x < world.width && !foundWater; x++) {
          if (world.getBlock(x, y) == BlockType.water) {
            foundWater = true;
          }
        }
      }
      expect(foundWater, isTrue);
    });

    test('sowing seeds grows crops and yields fruit upon harvest', () {
      final world = JungleWorld.generate(seed: 7);
      final tx = world.playerTileX + 1;
      // Ensure flat surface grass with air above.
      final ty = world.playerTileY;
      world.blocks[ty][tx] = BlockType.air;
      world.blocks[ty + 1][tx] = BlockType.grass;

      expect(world.sowSeedAt(tx, ty), isTrue);
      expect(world.getBlock(tx, ty + 1), BlockType.tilledSoil);

      final crop = world.crops['$tx,$ty'];
      expect(crop, isNotNull);

      // Mature the crop and harvest it.
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
      'hunger drains life points when starving and eating fruit restores it',
      () {
        final world = JungleWorld.generate(seed: 99);
        world.hunger = 0.0;
        world.health = 80.0;
        world.update(0.05);
        expect(world.health, lessThan(80.0));

        world.addItem(ItemType.banana, 1);
        expect(world.eatFood(ItemType.banana), isTrue);
        expect(world.hunger, greaterThan(20.0));
      },
    );

    test('crafted shelter with roof, background walls, and campfire protects from cold', () {
      final world = JungleWorld.generate(seed: 12);
      final px = world.playerTileX;
      final py = world.playerTileY;

      // Construct a 3x3 enclosed room around (px, py) with wood roof, background
      // walls, side doors, and a campfire.
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
    });

    test('fishing rod casts into river water and catches fish on bite', () {
      final world = JungleWorld.generate(seed: 21);
      world.addItem(ItemType.fishingRod, 1);
      final wx = world.playerTileX + 2;
      final wy = world.playerTileY;
      world.blocks[wy][wx] = BlockType.water;

      // Cast line.
      expect(world.toggleFishingCast(wx, wy), isTrue);
      expect(world.activeFishing, isNotNull);

      // Simulate fish bite and reel in.
      world.activeFishing!.hasBite = true;
      world.activeFishing!.biteWindowRemaining = 2.0;
      expect(world.toggleFishingCast(wx, wy), isTrue);
      expect(world.inventory[ItemType.rawFish] ?? 0, greaterThanOrEqualTo(1));
      expect(world.milestoneCaughtFish, isTrue);
    });

    test('native village trade exchanges fruits for rare seeds and gear', () {
      final world = JungleWorld.generate(seed: 55);
      final trade = world.villagers.first.trades.first;
      world.addItem(trade.costItem, trade.costCount);
      expect(world.executeTrade(trade), isTrue);
      expect(
        world.inventory[trade.rewardItem] ?? 0,
        greaterThanOrEqualTo(trade.rewardCount),
      );
      expect(world.milestoneTradedWithNatives, isTrue);
    });
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
