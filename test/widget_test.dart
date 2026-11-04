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
        expect(
          world.animals.any((a) => a.type == AnimalType.capuchinMonkey),
          isTrue,
        );
        expect(world.animals.any((a) => a.type == AnimalType.toucan), isTrue);
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
      // Perennial berry bush regrows from rootstock after harvest.
      expect(world.crops['$tx,$ty']?.growthProgress, closeTo(0.42, 0.05));
    });

    test(
      'supports sowing all 8 seed varieties and growing Mahogany Sapling into a canopy tree',
      () {
        final world = JungleWorld.generate(seed: 19);
        for (final seed in ItemType.allSeedVarieties) {
          world.addItem(seed, 2);
        }

        final baseTx = world.playerTileX - 3;
        final ty = world.playerTileY;
        for (int i = 0; i < ItemType.allSeedVarieties.length; i++) {
          final seed = ItemType.allSeedVarieties[i];
          final tx = baseTx + i;
          world.blocks[ty][tx] = BlockType.air;
          world.blocks[ty + 1][tx] = BlockType.grass;
          expect(world.sowSeedAt(tx, ty, seed), isTrue);
        }
        expect(
          world.sowedSeedVarieties.length,
          ItemType.allSeedVarieties.length,
        );

        // Advance the Mahogany Sapling to maturity and verify it bursts into a tree.
        final saplingTx = baseTx + ItemType.allSeedVarieties.length - 1;
        final saplingCrop = world.crops['$saplingTx,$ty']!;
        saplingCrop.growthProgress = 0.999;
        world.update(0.05);
        expect(world.crops.containsKey('$saplingTx,$ty'), isFalse);
        expect(world.getBlock(saplingTx, ty), BlockType.woodLog);
      },
    );

    test(
      'medicinal herbs repel snakes, briar thorns prick jaguars, and pitcher plants trap snakes & fertilize neighbors',
      () {
        final world = JungleWorld.generate(seed: 23);
        world.animals.clear();
        final px = world.playerTileX;
        final py = world.playerTileY;

        // 1. Medicinal Herb repels nearby Emerald Viper.
        world.blocks[py][px + 2] = BlockType.air;
        world.blocks[py + 1][px + 2] = BlockType.grass;
        world.sowSeedAt(px + 2, py, ItemType.healingHerbSeeds);
        world.crops['${px + 2},$py']!.growthProgress = 0.8;

        final snake = JungleAnimal(
          type: AnimalType.snake,
          x: (px + 3) * JungleWorld.tileSize,
          y: (py + 1) * JungleWorld.tileSize,
          facingRight: false,
        );
        world.animals.add(snake);
        world.update(0.05);
        expect(snake.facingRight, isTrue);
        expect(snake.activityBadge, contains('Repelled'));

        // 2. Briar Thorn-Vine pricks and damages a prowling Jaguar.
        world.animals.clear();
        world.blocks[py][px - 2] = BlockType.air;
        world.blocks[py + 1][px - 2] = BlockType.grass;
        world.sowSeedAt(px - 2, py, ItemType.thornVineSeeds);
        world.crops['${px - 2},$py']!.growthProgress = 1.0;

        final jaguar = JungleAnimal(
          type: AnimalType.jaguar,
          x: (px - 2) * JungleWorld.tileSize + 12.0,
          y: (py + 1) * JungleWorld.tileSize,
        );
        world.animals.add(jaguar);
        world.update(0.05);
        expect(jaguar.health, lessThan(AnimalType.jaguar.maxHealth));
        expect(jaguar.activityBadge, contains('Pricked'));

        // 3. Pitcher Plant traps snake and fertilizes adjacent Berry crop.
        world.animals.clear();
        world.crops.clear();
        world.blocks[py][px + 1] = BlockType.air;
        world.blocks[py + 1][px + 1] = BlockType.grass;
        world.blocks[py][px + 2] = BlockType.air;
        world.blocks[py + 1][px + 2] = BlockType.grass;
        world.sowSeedAt(px + 1, py, ItemType.pitcherPlantSeeds);
        world.sowSeedAt(px + 2, py, ItemType.berrySeeds);
        final pitcher = world.crops['${px + 1},$py']!;
        final neighborBerry = world.crops['${px + 2},$py']!;
        pitcher.growthProgress = 0.8;
        neighborBerry.isFertilized = false;

        final trappedSnake = JungleAnimal(
          type: AnimalType.snake,
          x: (px + 1) * JungleWorld.tileSize + 14.0,
          y: (py + 1) * JungleWorld.tileSize,
        );
        world.animals.add(trappedSnake);
        world.update(0.05);
        expect(trappedSnake.health, lessThan(AnimalType.snake.maxHealth));
        expect(neighborBerry.isFertilized, isTrue);
        expect(world.milestonePlantAnimalInteraction, isTrue);
      },
    );

    test(
      'bees pollinate flowering crops and befriended capuchin monkey harvests ripe fruit',
      () {
        final world = JungleWorld.generate(seed: 31);
        world.animals.clear();
        final px = world.playerTileX;
        final py = world.playerTileY;

        world.blocks[py][px + 1] = BlockType.air;
        world.blocks[py + 1][px + 1] = BlockType.grass;
        world.sowSeedAt(px + 1, py, ItemType.bananaSeeds);
        final bananaCrop = world.crops['${px + 1},$py']!;
        bananaCrop.growthProgress = 0.75; // Flowering stage

        final bee = JungleAnimal(
          type: AnimalType.beeSwarm,
          x: (px + 1) * JungleWorld.tileSize + 16.0,
          y: py * JungleWorld.tileSize + 12.0,
          homeX: (px + 1) * JungleWorld.tileSize + 16.0,
          homeY: py * JungleWorld.tileSize + 12.0,
          interactionTimer: 0.0,
        );
        world.animals.add(bee);
        world.update(0.05);
        world.update(0.05);
        expect(bananaCrop.isPollinated, isTrue);

        // Befriend a Capuchin Monkey with a banana and verify it harvests the ripe crop.
        bananaCrop.growthProgress = 1.0;
        final monkey = JungleAnimal(
          type: AnimalType.capuchinMonkey,
          x: (px + 1) * JungleWorld.tileSize + 16.0,
          y: (py + 1) * JungleWorld.tileSize,
          interactionTimer: 0.0,
        );
        world.animals.add(monkey);
        expect(world.feedNearbyWildlife(monkey), isTrue);
        expect(monkey.isTamed, isTrue);
        expect(world.milestoneBefriendedMonkey, isTrue);

        final bananasBefore = world.inventory[ItemType.banana] ?? 0;
        monkey.interactionTimer = 0.0;
        world.update(0.05);
        world.update(0.05);
        expect((world.inventory[ItemType.banana] ?? 0) > bananasBefore, isTrue);
        expect(bananaCrop.growthProgress, closeTo(0.45, 0.05));

        // Verify Rainbow Toucan eats ripe fruit and disperses a new sowed seed nearby!
        bananaCrop.growthProgress = 1.0;
        final toucan = JungleAnimal(
          type: AnimalType.toucan,
          x: (px + 1) * JungleWorld.tileSize + 16.0,
          y: py * JungleWorld.tileSize,
          interactionTimer: 0.0,
        );
        world.animals
          ..clear()
          ..add(toucan);
        world.blocks[py][px + 3] = BlockType.air;
        world.blocks[py + 1][px + 3] = BlockType.grass;
        final cropsBeforeToucan = world.crops.length;

        world.update(0.05);
        world.update(0.05);
        expect(toucan.carriedSeed, isNotNull);
        expect(toucan.activityBadge, contains('Ate'));
        expect(bananaCrop.growthProgress, closeTo(0.52, 0.05));

        final (dropTx, dropTy) = toucan.targetPlantTile!;
        toucan.x = dropTx * JungleWorld.tileSize + 16.0;
        toucan.y = dropTy * JungleWorld.tileSize;
        world.update(0.05);
        expect(toucan.carriedSeed, isNull);
        expect(world.crops.length, greaterThan(cropsBeforeToucan));
      },
    );

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

    test(
      'streams infinite chunks on the fly when exploring West (-X) and East (+X)',
      () {
        final worldA = JungleWorld.generate(seed: 101);
        final worldB = JungleWorld.generate(seed: 909);

        final initialChunks = worldA.generatedChunkCount;
        expect(initialChunks, 10);

        // Walk far West into negative tile coordinates (X = -140) and trigger update.
        worldA.playerX = -140 * JungleWorld.tileSize;
        worldA.update(0.05);
        expect(worldA.playerTileX, -140);
        expect(worldA.generatedChunkCount, greaterThan(initialChunks));
        final westSurface = worldA.surfaceElevationAt(-140);
        expect(worldA.getBlock(-140, westSurface), isNot(BlockType.air));

        // Walk far East beyond the initial 160-tile window (X = 380) and trigger update.
        final chunksAfterWest = worldA.generatedChunkCount;
        worldA.playerX = 380 * JungleWorld.tileSize;
        worldA.update(0.05);
        expect(worldA.generatedChunkCount, greaterThan(chunksAfterWest));

        // Ensure chunks across a wide range (-160..480) generate additional villages
        // and wild botanical clearing crops on the fly.
        for (int tx = -160; tx <= 480; tx += 16) {
          worldA.getBlock(tx, 20);
        }
        expect(worldA.villagers.length, greaterThan(2));
        expect(worldA.crops, isNotEmpty);

        // Verify different world seeds generate distinct biome/elevation profiles.
        bool foundDifference = false;
        for (int tx = -128; tx <= 320; tx += 16) {
          if (worldA.biomeAt(tx) != worldB.biomeAt(tx) ||
              worldA.surfaceElevationAt(tx) != worldB.surfaceElevationAt(tx)) {
            foundDifference = true;
            break;
          }
        }
        expect(foundDifference, isTrue);
      },
    );

    test(
      'different soil types and microclimates make specific plants thrive or struggle',
      () {
        final world = JungleWorld.generate(seed: 55);
        world.animals.clear();
        world.crops.clear();
        for (final seed in ItemType.allSeedVarieties) {
          world.inventory[seed] = 10;
        }

        final px = world.playerTileX;
        final py = world.playerTileY;

        // 1. Shaded, humid Peat Bog at px - 2 vs Sunny, dry Volcanic Ash at px + 2.
        // Clear sky above px + 2 for direct sun, and put canopy leaves + nearby water at px - 2.
        for (int y = 0; y < py; y++) {
          world.blocks[y][px - 2] = BlockType.air;
          world.blocks[y][px + 2] = BlockType.air;
          world.blocks[y][px + 4] = BlockType.air;
        }
        world.blocks[py - 3][px - 2] = BlockType.leaves; // Shaded canopy
        world.blocks[py + 1][px - 3] = BlockType.water; // Humid riverbank
        world.blocks[py][px - 2] = BlockType.air;
        world.blocks[py + 1][px - 2] = BlockType.peatBog;

        world.blocks[py][px + 2] = BlockType.air;
        world.blocks[py + 1][px + 2] = BlockType.volcanicAsh;

        final bogClimate = world.evaluateMicroclimate(px - 2, py);
        final ashClimate = world.evaluateMicroclimate(px + 2, py);

        expect(bogClimate.soilType, SoilType.peatBog);
        expect(bogClimate.isShadedCanopyOrCave, isTrue);
        expect(bogClimate.isHumidRiverbank, isTrue);

        expect(ashClimate.soilType, SoilType.volcanicAsh);
        expect(ashClimate.isShadedCanopyOrCave, isFalse);

        // Pitcher Plant thrives in shaded, humid Peat Bog (> 1.8x) and struggles in dry Volcanic Ash (< 0.6x).
        expect(
          bogClimate.growthMultiplierFor(ItemType.pitcherPlantSeeds),
          greaterThan(1.8),
        );
        expect(
          ashClimate.growthMultiplierFor(ItemType.pitcherPlantSeeds),
          lessThan(0.6),
        );

        // Briar Thorn-Vine and Golden Mango thrive on sunny Volcanic Ash (> 1.45x) and struggle in shaded Peat Bog (< 0.8x).
        expect(
          ashClimate.growthMultiplierFor(ItemType.thornVineSeeds),
          greaterThan(1.45),
        );
        expect(
          bogClimate.growthMultiplierFor(ItemType.thornVineSeeds),
          lessThan(0.75),
        );

        // Sow Pitcher Plants on both tiles and advance 5 seconds to verify real growth speed difference.
        expect(world.sowSeedAt(px - 2, py, ItemType.pitcherPlantSeeds), isTrue);
        expect(world.sowSeedAt(px + 2, py, ItemType.pitcherPlantSeeds), isTrue);
        // Specialized soil blocks remain intact when sowed on.
        expect(world.getBlock(px - 2, py + 1), BlockType.peatBog);
        expect(world.getBlock(px + 2, py + 1), BlockType.volcanicAsh);

        world.update(5.0);
        final bogPitcher = world.crops['${px - 2},$py']!;
        final ashPitcher = world.crops['${px + 2},$py']!;
        expect(
          bogPitcher.growthProgress,
          greaterThan(ashPitcher.growthProgress * 3.0),
        );

        // 2. River Silt makes Banana Seeds thrive and grants +1 bonus fruit yield on harvest!
        world.blocks[py][px + 4] = BlockType.air;
        world.blocks[py + 1][px + 4] = BlockType.riverSilt;
        world.blocks[py + 1][px + 5] = BlockType.water;
        expect(world.sowSeedAt(px + 4, py, ItemType.bananaSeeds), isTrue);
        final siltBanana = world.crops['${px + 4},$py']!;
        siltBanana.growthProgress = 1.0;

        final bananasBefore = world.inventory[ItemType.banana] ?? 0;
        world.playerX = (px + 4) * JungleWorld.tileSize;
        world.playerY = py * JungleWorld.tileSize;
        expect(world.interactOrPlaceAt(px + 4, py), isTrue);
        // Base yield (2..3) + 1 bonus from thriving River Silt habitat = 3..4 bananas.
        expect(
          (world.inventory[ItemType.banana] ?? 0) - bananasBefore,
          greaterThanOrEqualTo(3),
        );
      },
    );

    test(
      'procedurally synthesizes bee buzzing and attacking animal roars and emits spatial sound events',
      () {
        // 1. Verify DSP waveform & RIFF/WAVE generation for all procedural sound cues.
        for (final cue in SoundCue.values) {
          final samples = JungleSoundSynthesizer.synthesizeSamples(cue);
          expect(samples.length, greaterThan(1000));
          expect(JungleSoundSynthesizer.computeRms(samples), greaterThan(0.05));

          final wavBytes = JungleSoundSynthesizer.encodeWavBytes(samples);
          expect(wavBytes.length, 44 + samples.length * 2);
          // Check "RIFF" and "WAVE" magic bytes.
          expect(String.fromCharCodes(wavBytes.sublist(0, 4)), 'RIFF');
          expect(String.fromCharCodes(wavBytes.sublist(8, 12)), 'WAVE');
        }

        // Jaguar roar is a deep low-frequency growl, whereas angry bee buzz and
        // viper hiss have much higher zero-crossing rates.
        final roarHz = JungleSoundSynthesizer.estimateZeroCrossingHz(
          JungleSoundSynthesizer.synthesizeSamples(SoundCue.jaguarRoar),
        );
        final angryBeeHz = JungleSoundSynthesizer.estimateZeroCrossingHz(
          JungleSoundSynthesizer.synthesizeSamples(SoundCue.beeBuzzAngry),
        );
        final snakeHissHz = JungleSoundSynthesizer.estimateZeroCrossingHz(
          JungleSoundSynthesizer.synthesizeSamples(SoundCue.snakeHiss),
        );
        expect(roarHz, lessThan(angryBeeHz));
        expect(angryBeeHz, lessThan(snakeHissHz));

        // 2. Verify 2-channel stereo synthesis (equal-power panning + Haas delay).
        final leftRoar = JungleSoundSynthesizer.synthesizeStereo(
          SoundCue.jaguarRoar,
          volume: 0.9,
          pan: -0.8,
        );
        final rightRoar = JungleSoundSynthesizer.synthesizeStereo(
          SoundCue.jaguarRoar,
          volume: 0.9,
          pan: 0.8,
        );
        expect(
          JungleSoundSynthesizer.computeRms(leftRoar.left),
          greaterThan(JungleSoundSynthesizer.computeRms(leftRoar.right) * 2.0),
        );
        expect(
          JungleSoundSynthesizer.computeRms(rightRoar.right),
          greaterThan(JungleSoundSynthesizer.computeRms(rightRoar.left) * 2.0),
        );
        final stereoWav = JungleSoundSynthesizer.encodeStereoWavBytes(
          left: leftRoar.left,
          right: leftRoar.right,
        );
        // 4 bytes per stereo frame (16-bit L + 16-bit R) + 44-byte RIFF header.
        expect(stereoWav.length, 44 + leftRoar.left.length * 4);
        // Channels field at byte offset 22 should be 2 (stereo).
        expect(stereoWav[22], 2);

        // 3. Verify spatial bee buzzing proximity & stereo pan relative to explorer.
        final world = JungleWorld.generate(seed: 77);
        world.animals.clear();
        world.pendingSoundEvents.clear();

        final beeRight = JungleAnimal(
          type: AnimalType.beeSwarm,
          x: world.playerX + 90.0,
          y: world.playerY - 16.0,
          homeX: world.playerX + 90.0,
          homeY: world.playerY - 16.0,
          isAngry: true,
        )..angryTimer = 5.0;
        world.animals.add(beeRight);
        world.update(0.05);
        expect(world.beeBuzzIntensity, greaterThan(0.60));
        expect(world.beeBuzzAngry, isTrue);
        expect(world.beeBuzzPan, greaterThan(0.35)); // To the right of explorer

        // 4. Verify attacking Shadow Jaguar on the left emits a left-panned jaguarRoar SoundEvent.
        world.animals.clear();
        world.pendingSoundEvents.clear();
        final jaguarLeft = JungleAnimal(
          type: AnimalType.jaguar,
          x: world.playerX - 18.0,
          y: world.playerY,
          interactionTimer: 0.0,
        );
        world.animals.add(jaguarLeft);
        world.update(0.05);
        final roarEvents =
            world.pendingSoundEvents
                .where((e) => e.cue == SoundCue.jaguarRoar)
                .toList();
        expect(roarEvents, isNotEmpty);
        expect(roarEvents.first.pan, lessThan(0.0)); // Panned left of explorer
        expect(world.lastSoundEvent?.cue, SoundCue.jaguarRoar);

        // 5. Verify toucan emits a stereo toucanScream when spotting a predator or fed fruit!
        world.pendingSoundEvents.clear();
        final toucanRight = JungleAnimal(
          type: AnimalType.toucan,
          x: world.playerX + 42.0,
          y: world.playerY - 18.0,
        )..patrolTimer = 0.0;
        world.animals.add(toucanRight);
        world.update(0.05);
        final screamEvents =
            world.pendingSoundEvents
                .where((e) => e.cue == SoundCue.toucanScream)
                .toList();
        expect(screamEvents, isNotEmpty);
        expect(screamEvents.first.pan, greaterThan(0.0));

        // 6. Verify hut roofs & background walls block falling rain, and vining
        // crops extend climbable vine tendrils up to overhead trellises.
        final tx = world.playerTileX + 6;
        final ty = world.playerTileY;
        for (int y = 0; y <= ty; y++) {
          world.blocks[y][tx] = BlockType.air;
          world.walls[y][tx] = WallType.none;
        }
        world.blocks[ty + 1][tx] = BlockType.grass;
        expect(world.isTileShelteredFromRain(tx, ty), isFalse);

        // Place a thatch roof 2 tiles overhead: interior tile is now sheltered from rain!
        world.blocks[ty - 2][tx] = BlockType.thatchRoof;
        expect(world.isTileShelteredFromRain(tx, ty), isTrue);

        // Sow a vining Berry Bush beneath the roof trellis and grow past 60%:
        // it sprouts a climbable BlockType.vine tendril connecting to the trellis!
        world.addItem(ItemType.berrySeeds, 2);
        expect(world.sowSeedAt(tx, ty, ItemType.berrySeeds), isTrue);
        final berryCrop = world.crops['$tx,$ty']!;
        berryCrop.growthProgress = 0.65;
        world.update(0.1);
        expect(berryCrop.vineSegments, greaterThanOrEqualTo(2));
        expect(world.getBlock(tx, ty - 1), BlockType.vine);

        // 7. Verify Red-Bellied Piranhas continuously swim across river lagoons
        // even when the explorer stands on the adjacent dry riverbank.
        final riverWorld = JungleWorld.generate(seed: 77);
        final piranha = riverWorld.animals.firstWhere(
          (a) => a.type == AnimalType.piranha,
        );
        final riverLeftBankTx = (piranha.x / JungleWorld.tileSize).floor() - 4;
        riverWorld.playerX = riverLeftBankTx * JungleWorld.tileSize;
        riverWorld.playerY =
            riverWorld.surfaceElevationAt(riverLeftBankTx) *
            JungleWorld.tileSize;
        final startX = piranha.x;
        double totalDistanceSwum = 0.0;
        double prevX = startX;
        for (int step = 0; step < 30; step++) {
          riverWorld.update(0.1);
          totalDistanceSwum += (piranha.x - prevX).abs();
          prevX = piranha.x;
        }
        expect(totalDistanceSwum, greaterThan(120.0));
      },
    );
  });

  testWidgets(
    'JungleSurvivalApp renders Flame canvas, survival HUD, Seed Pouch button, and mobile pad',
    (tester) async {
      await tester.pumpWidget(const JungleSurvivalApp());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Life'), findsOneWidget);
      expect(find.textContaining('Food'), findsOneWidget);
      expect(find.textContaining('Warmth'), findsOneWidget);
      expect(find.textContaining('Seeds'), findsOneWidget);
      expect(find.text('JUMP'), findsOneWidget);
    },
  );
}
