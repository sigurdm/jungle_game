import 'dart:math' as math;

import 'models.dart';

/// Complete mutable simulation state for the 2D side-scrolling jungle world.
///
/// Manages terrain blocks, background shelter walls, player physics, hunger and
/// cold survival stats, crop growth, fishing casts, native villager trading,
/// and dangerous animal AI.
///
/// {@example example/world_simulation_example.dart}
final class JungleWorld {
  /// Creates a generated jungle world using [seed].
  ///
  /// It is an error if [width] or [height] is less than `20`.
  JungleWorld._({
    required this.width,
    required this.height,
    required this.blocks,
    required this.walls,
    required this.villagers,
    required this.animals,
    required this.playerX,
    required this.playerY,
    required int seed,
  }) : _rng = math.Random(seed) {
    if (width < 20 || height < 20) {
      throw ArgumentError('World dimensions must be at least 20x20 tiles.');
    }
    // Starter explorer kit so the player can immediately mine, defend, or fish.
    inventory[ItemType.woodPickaxe] = 1;
    inventory[ItemType.woodSpear] = 1;
    inventory[ItemType.berrySeeds] = 3;
    inventory[ItemType.jungleBerry] = 3;
    inventory[ItemType.torchItem] = 2;
  }

  /// Standard pixel size of a single world grid tile.
  static const double tileSize = 32.0;

  /// Standard crafting recipes available in the crafting menu.
  static const List<CraftingRecipe> recipes = [
    CraftingRecipe(
      output: ItemType.woodPlankItem,
      outputCount: 4,
      ingredients: {ItemType.woodLogItem: 1},
      description: 'Solid wooden planks for shelter roofs, floors, and walls.',
    ),
    CraftingRecipe(
      output: ItemType.thatchRoofItem,
      outputCount: 4,
      ingredients: {ItemType.thatchBundle: 1, ItemType.vineFiber: 1},
      description: 'Insulated thatch roof tiles that keep out rain and cold.',
    ),
    CraftingRecipe(
      output: ItemType.woodWallItem,
      outputCount: 6,
      ingredients: {ItemType.woodLogItem: 1},
      description: 'Background wall panels required to enclose warm rooms.',
    ),
    CraftingRecipe(
      output: ItemType.thatchWallItem,
      outputCount: 6,
      ingredients: {ItemType.thatchBundle: 1},
      description: 'Woven background wall panels for insulated jungle huts.',
    ),
    CraftingRecipe(
      output: ItemType.doorItem,
      outputCount: 1,
      ingredients: {ItemType.woodPlankItem: 3},
      description:
          'Toggleable door that blocks jaguars/snakes and holds warmth.',
    ),
    CraftingRecipe(
      output: ItemType.campfireItem,
      outputCount: 1,
      ingredients: {ItemType.woodLogItem: 2, ItemType.stoneBlock: 2},
      description: 'Heats enclosed shelters at night and roasts caught fish.',
    ),
    CraftingRecipe(
      output: ItemType.torchItem,
      outputCount: 3,
      ingredients: {ItemType.woodLogItem: 1, ItemType.vineFiber: 1},
      description: 'Provides light and mild warmth underground or in huts.',
    ),
    CraftingRecipe(
      output: ItemType.fishingRod,
      outputCount: 1,
      ingredients: {ItemType.woodLogItem: 2, ItemType.vineFiber: 2},
      description: 'Cast into jungle rivers to catch nutritious fish.',
    ),
    CraftingRecipe(
      output: ItemType.cookedFish,
      outputCount: 1,
      ingredients: {ItemType.rawFish: 1},
      description:
          'Roast raw fish over a nearby campfire for +48 Hunger & Warmth.',
      requiresCampfire: true,
    ),
    CraftingRecipe(
      output: ItemType.woodSpear,
      outputCount: 1,
      ingredients: {ItemType.woodLogItem: 2, ItemType.vineFiber: 1},
      description: 'Long-reach spear for fending off jaguars and vipers.',
    ),
    CraftingRecipe(
      output: ItemType.stonePickaxe,
      outputCount: 1,
      ingredients: {
        ItemType.woodLogItem: 2,
        ItemType.stoneBlock: 3,
        ItemType.vineFiber: 1,
      },
      description: 'Fast mining tool for stone, coal, and iron ore veins.',
    ),
    CraftingRecipe(
      output: ItemType.ironMachete,
      outputCount: 1,
      ingredients: {
        ItemType.ironOreItem: 3,
        ItemType.coalItem: 1,
        ItemType.woodLogItem: 1,
      },
      description: 'Heavy jungle blade that deals 38 damage to predators.',
      requiresCampfire: true,
    ),
    CraftingRecipe(
      output: ItemType.warmPoncho,
      outputCount: 1,
      ingredients: {ItemType.vineFiber: 4, ItemType.thatchBundle: 3},
      description:
          'Woven thermal poncho that cuts night cold heat loss by 50%.',
    ),
  ];

  /// Generates a complete side-scrolling jungle world with rivers, native
  /// villages, canopy trees, caves, and wildlife.
  ///
  /// Runs in $O(W \times H)$ time where $W$ is [width] and $H$ is [height].
  factory JungleWorld.generate({
    int seed = 1337,
    int width = 160,
    int height = 56,
  }) {
    final rng = math.Random(seed);
    final blocks = List<List<BlockType>>.generate(
      height,
      (_) => List<BlockType>.filled(width, BlockType.air),
    );
    final walls = List<List<WallType>>.generate(
      height,
      (_) => List<WallType>.filled(width, WallType.none),
    );

    // Compute surface heights across the horizontal world.
    final surfaceY = List<int>.filled(width, 22);
    double h = 22.0;
    for (int x = 0; x < width; x++) {
      // Keep flat plateaus for the two native villages (around x=34..48 and x=116..130)
      // and carved basins for the two rivers (around x=58..68 and x=96..106).
      if (x >= 32 && x <= 48) {
        h = 21.0;
      } else if (x >= 114 && x <= 130) {
        h = 20.0;
      } else if (x >= 58 && x <= 68) {
        final centerDist = (x - 63).abs();
        h = 26.0 - centerDist * 0.6;
      } else if (x >= 96 && x <= 106) {
        final centerDist = (x - 101).abs();
        h = 26.0 - centerDist * 0.6;
      } else {
        h += (rng.nextDouble() - 0.49) * 1.1;
        h = h.clamp(17.0, 24.0);
      }
      surfaceY[x] = h.round();
    }

    const waterLevel = 23;

    // Fill terrain layers.
    for (int x = 0; x < width; x++) {
      final topY = surfaceY[x];
      for (int y = topY; y < height; y++) {
        if (y == topY) {
          blocks[y][x] = y > waterLevel ? BlockType.dirt : BlockType.grass;
        } else if (y <= topY + 3) {
          blocks[y][x] = BlockType.dirt;
          walls[y][x] = WallType.dirtWall;
        } else {
          final depth = y - topY;
          final roll = rng.nextDouble();
          if (depth > 10 && roll < 0.055) {
            blocks[y][x] = BlockType.ironOre;
          } else if (depth > 5 && roll < 0.11) {
            blocks[y][x] = BlockType.coalOre;
          } else {
            blocks[y][x] = BlockType.stone;
          }
          walls[y][x] = WallType.dirtWall;
        }
      }

      // Carve small underground cave pockets below y = topY + 6.
      for (int y = topY + 6; y < height - 4; y++) {
        final caveWave =
            math.sin(x * 0.19 + y * 0.31) + math.cos(x * 0.08 - y * 0.23);
        if (caveWave > 1.55) {
          blocks[y][x] = BlockType.air;
        }
      }

      // Fill river basins with water up to waterLevel.
      if (topY > waterLevel) {
        for (int y = waterLevel; y < topY; y++) {
          blocks[y][x] = BlockType.water;
        }
      }
    }

    // Build two Native Villages with thatched stilt huts and villagers.
    final villagers = <NativeVillager>[];
    void buildVillageHut(
      int startX,
      int groundY,
      String villagerName,
      String role,
      String greeting,
      List<VillageTrade> trades,
    ) {
      const hutWidth = 9;
      const hutHeight = 5;
      final floorY = groundY;
      final roofY = floorY - hutHeight;

      for (int dx = 0; dx < hutWidth; dx++) {
        final wx = startX + dx;
        // Sturdy timber floor and stilt supports.
        blocks[floorY][wx] = BlockType.villageHutBlock;
        for (int sy = floorY + 1; sy <= floorY + 3 && sy < height; sy++) {
          if (dx == 0 || dx == hutWidth - 1) {
            blocks[sy][wx] = BlockType.woodPlank;
          }
        }
        // Thatch roof pyramid.
        blocks[roofY][wx] = BlockType.thatchRoof;
        if (dx >= 1 && dx <= hutWidth - 2) {
          blocks[roofY - 1][wx] = BlockType.thatchRoof;
        }
        // Clear interior & add insulated village background walls.
        for (int iy = roofY + 1; iy < floorY; iy++) {
          blocks[iy][wx] = BlockType.air;
          walls[iy][wx] = WallType.villageWall;
        }
      }

      // Side pillars & doors on left and right entrances.
      for (int iy = roofY + 1; iy < floorY; iy++) {
        if (iy >= floorY - 2) {
          blocks[iy][startX] = BlockType.doorOpen;
          blocks[iy][startX + hutWidth - 1] = BlockType.doorOpen;
        } else {
          blocks[iy][startX] = BlockType.villageHutBlock;
          blocks[iy][startX + hutWidth - 1] = BlockType.villageHutBlock;
        }
      }

      // Warm campfire & torches inside the village hut.
      blocks[floorY - 1][startX + 2] = BlockType.campfire;
      blocks[floorY - 3][startX + 4] = BlockType.torch;

      villagers.add(
        NativeVillager(
          name: villagerName,
          role: role,
          x: (startX + 5) * tileSize + tileSize * 0.5,
          y: (floorY - 1) * tileSize,
          greeting: greeting,
          trades: trades,
        ),
      );
    }

    buildVillageHut(
      35,
      surfaceY[38],
      'Kaelo',
      'Sun-Canopy Botanist',
      'Welcome, explorer! Bring us jungle fruits or roasted fish to trade for rare seeds and warm gear.',
      const [
        VillageTrade(
          costItem: ItemType.jungleBerry,
          costCount: 3,
          rewardItem: ItemType.bananaSeeds,
          rewardCount: 3,
          note: 'Sow Banana Seeds on dirt/grass for rich banana harvests.',
        ),
        VillageTrade(
          costItem: ItemType.banana,
          costCount: 3,
          rewardItem: ItemType.mangoSeeds,
          rewardCount: 2,
          note: 'Prized Golden Mango Seeds that yield high-energy mangoes.',
        ),
        VillageTrade(
          costItem: ItemType.jungleBerry,
          costCount: 4,
          rewardItem: ItemType.papaya,
          rewardCount: 2,
          note: 'Fresh Jungle Papayas (+36 Hunger, +14 Health).',
        ),
        VillageTrade(
          costItem: ItemType.banana,
          costCount: 4,
          rewardItem: ItemType.warmPoncho,
          rewardCount: 1,
          note: 'Hand-woven Jungle Poncho that halves night cold heat loss.',
        ),
      ],
    );

    buildVillageHut(
      117,
      surfaceY[120],
      'Yara',
      'River & Forge Artisan',
      'The jungle grows freezing after dusk! Trade your fruits or fish for tools and healing herbs.',
      const [
        VillageTrade(
          costItem: ItemType.cookedFish,
          costCount: 2,
          rewardItem: ItemType.ironMachete,
          rewardCount: 1,
          note: 'Razor-sharp Iron Machete (38 melee damage, fast chopping).',
        ),
        VillageTrade(
          costItem: ItemType.mango,
          costCount: 2,
          rewardItem: ItemType.healingHerb,
          rewardCount: 3,
          note: 'Medicinal Jungle Poultice (+40 Life Points).',
        ),
        VillageTrade(
          costItem: ItemType.jungleBerry,
          costCount: 2,
          rewardItem: ItemType.torchItem,
          rewardCount: 6,
          note: 'Bundle of resin torches for caves and night warmth.',
        ),
        VillageTrade(
          costItem: ItemType.rawFish,
          costCount: 2,
          rewardItem: ItemType.campfireItem,
          rewardCount: 1,
          note: 'Ready-to-place Campfire for heating your shelter.',
        ),
      ],
    );

    // Populate Mahogany Jungle Trees, Hanging Vines, and Wild Berry Bushes.
    for (int x = 6; x < width - 6; x++) {
      // Skip village footprints and river basins.
      if ((x >= 33 && x <= 47) ||
          (x >= 115 && x <= 129) ||
          (x >= 57 && x <= 69) ||
          (x >= 95 && x <= 107)) {
        continue;
      }
      final gy = surfaceY[x];
      if (blocks[gy][x] != BlockType.grass) continue;

      if (x % 7 == 0 && rng.nextDouble() < 0.78) {
        // Grow a tall jungle tree with canopy leaves and climbable vines.
        final trunkHeight = 5 + rng.nextInt(4);
        for (int ty = gy - 1; ty >= gy - trunkHeight && ty >= 2; ty--) {
          blocks[ty][x] = BlockType.woodLog;
        }
        final topTreeY = (gy - trunkHeight).clamp(3, height - 1);
        for (int ly = topTreeY - 2; ly <= topTreeY + 1; ly++) {
          for (int lx = x - 3; lx <= x + 3; lx++) {
            if (lx >= 1 &&
                lx < width - 1 &&
                ly >= 1 &&
                (lx - x).abs() + (ly - topTreeY).abs() <= 4) {
              if (blocks[ly][lx] == BlockType.air) {
                blocks[ly][lx] = BlockType.leaves;
              }
            }
          }
        }
        // Hang climbable vines from the outer edges of the canopy.
        for (final vx in [x - 2, x + 2]) {
          if (vx >= 1 && vx < width - 1) {
            final vineLen = 2 + rng.nextInt(4);
            for (
              int vy = topTreeY + 1;
              vy <= topTreeY + vineLen && vy < gy;
              vy++
            ) {
              if (blocks[vy][vx] == BlockType.air) {
                blocks[vy][vx] = BlockType.vine;
              }
            }
          }
        }
      } else if (rng.nextDouble() < 0.24 &&
          blocks[gy - 1][x] == BlockType.air) {
        blocks[gy - 1][x] = BlockType.berryBush;
      }
    }

    // Spawn initial wildlife (Jaguars, Snakes, and River Piranhas).
    final animals = <JungleAnimal>[
      JungleAnimal(
        type: AnimalType.piranha,
        x: 63 * tileSize,
        y: (waterLevel + 1) * tileSize,
      ),
      JungleAnimal(
        type: AnimalType.piranha,
        x: 101 * tileSize,
        y: (waterLevel + 1) * tileSize,
      ),
      JungleAnimal(
        type: AnimalType.snake,
        x: 20 * tileSize,
        y: (surfaceY[20] - 1) * tileSize,
      ),
      JungleAnimal(
        type: AnimalType.jaguar,
        x: 82 * tileSize,
        y: (surfaceY[82] - 1) * tileSize,
      ),
      JungleAnimal(
        type: AnimalType.snake,
        x: 140 * tileSize,
        y: (surfaceY[140] - 1) * tileSize,
      ),
    ];

    final spawnTileX = 28;
    final spawnTileY = surfaceY[spawnTileX] - 1;

    return JungleWorld._(
      width: width,
      height: height,
      blocks: blocks,
      walls: walls,
      villagers: villagers,
      animals: animals,
      playerX: spawnTileX * tileSize + tileSize * 0.5,
      playerY: spawnTileY * tileSize,
      seed: seed,
    );
  }

  /// Width of the world in tiles.
  final int width;

  /// Height of the world in tiles.
  final int height;

  /// 2D grid (`[y][x]`) of foreground blocks.
  final List<List<BlockType>> blocks;

  /// 2D grid (`[y][x]`) of background shelter walls.
  final List<List<WallType>> walls;

  /// Native village NPCs available for fruit trading.
  final List<NativeVillager> villagers;

  /// Active dangerous animals in the world.
  final List<JungleAnimal> animals;

  /// Active planted crops indexed by `'x,y'` coordinate key.
  final Map<String, CropPlot> crops = {};

  /// Inventory quantities owned by the explorer.
  final Map<ItemType, int> inventory = {};

  /// Ordered hotbar slots for quick selection.
  final List<ItemType> hotbar = [
    ItemType.woodPickaxe,
    ItemType.woodSpear,
    ItemType.berrySeeds,
    ItemType.jungleBerry,
    ItemType.woodPlankItem,
    ItemType.thatchRoofItem,
    ItemType.woodWallItem,
    ItemType.doorItem,
    ItemType.campfireItem,
    ItemType.fishingRod,
  ];

  /// Currently selected index in [hotbar] (`0..9`).
  int selectedHotbarIndex = 0;

  /// Explorer horizontal center position in world pixels.
  double playerX;

  /// Explorer vertical foot position in world pixels.
  double playerY;

  /// Explorer horizontal velocity in pixels per second.
  double playerVx = 0.0;

  /// Explorer vertical velocity in pixels per second.
  double playerVy = 0.0;

  /// Whether the explorer is currently facing right.
  bool playerFacingRight = true;

  /// Explorer life points (`0.0..100.0`).
  double health = 100.0;

  /// Explorer fullness / hunger gauge (`0.0..100.0`).
  double hunger = 88.0;

  /// Explorer body warmth gauge (`0.0..100.0`).
  double warmth = 92.0;

  /// Normalized time of day in `0.0..1.0` (`0.20..0.75` = day, else night).
  double timeOfDay = 0.30;

  /// Current survival day counter starting at Day 1.
  int dayCount = 1;

  /// Whether a cooling tropical rainstorm is currently active.
  bool isRaining = false;

  /// Active fishing bobber state, or `null` when not fishing.
  FishingState? activeFishing;

  /// Recent status banner message shown in the HUD.
  String statusMessage =
      'Explore the jungle! Gather seeds, build a shelter with walls & campfire before nightfall.';

  /// Remaining seconds to highlight [statusMessage].
  double statusBannerTimer = 6.0;

  /// Currently targeted block coordinate for mining (`null` if not mining).
  (int, int)? miningTarget;

  /// Accumulated mining progress (`0.0..1.0`) on [miningTarget].
  double miningProgress = 0.0;

  /// Visual swing animation timer when attacking or mining.
  double swingAnimationTimer = 0.0;

  /// Brief red flash timer when the explorer takes damage.
  double playerHurtFlashTimer = 0.0;

  // Completed explorer milestone flags.
  /// Whether the explorer has gathered wild seeds.
  bool milestoneGatheredSeeds = false;

  /// Whether the explorer has sowed seeds on tilled soil.
  bool milestoneSowedCrop = false;

  /// Whether the explorer has harvested ripe fruit from a crop.
  bool milestoneHarvestedFruit = false;

  /// Whether the explorer has stood inside a completed warm shelter.
  bool milestoneBuiltShelter = false;

  /// Whether the explorer has caught a river fish.
  bool milestoneCaughtFish = false;

  /// Whether the explorer has traded fruits with a native villager.
  bool milestoneTradedWithNatives = false;

  /// Whether the explorer has defeated a dangerous jungle predator.
  bool milestoneDefeatedPredator = false;

  final math.Random _rng;
  double _animalSpawnTimer = 14.0;
  double _weatherTimer = 35.0;

  /// Currently selected item in the explorer's hotbar.
  ItemType get equippedItem => hotbar[selectedHotbarIndex];

  /// Explorer's current horizontal tile coordinate.
  int get playerTileX => (playerX ~/ tileSize).clamp(0, width - 1);

  /// Explorer's current vertical tile coordinate (at torso height).
  int get playerTileY => ((playerY - 14.0) ~/ tileSize).clamp(0, height - 1);

  /// Whether it is currently night in the jungle.
  bool get isNight => timeOfDay < 0.22 || timeOfDay > 0.76;

  /// Whether the explorer carries a [ItemType.warmPoncho] in their inventory.
  bool get hasWarmPoncho => (inventory[ItemType.warmPoncho] ?? 0) > 0;

  /// Returns the [BlockType] at grid coordinates ([tx], [ty]), or
  /// [BlockType.stone] if out of bounds.
  BlockType getBlock(int tx, int ty) {
    if (tx < 0 || tx >= width || ty < 0 || ty >= height) {
      return BlockType.stone;
    }
    return blocks[ty][tx];
  }

  /// Returns the [WallType] at grid coordinates ([tx], [ty]), or
  /// [WallType.none] if out of bounds.
  WallType getWall(int tx, int ty) {
    if (tx < 0 || tx >= width || ty < 0 || ty >= height) {
      return WallType.none;
    }
    return walls[ty][tx];
  }

  /// Evaluates whether the tile ([tx], [ty]) is inside an insulated shelter
  /// and near heat sources.
  ///
  /// Runs in $O(R^2)$ time where $R \le 8$ is the local room scan radius.
  ///
  /// {@example example/world_simulation_example.dart}
  ShelterEvaluation evaluateShelterStatus(int tx, int ty) {
    // 1. Check for solid overhead roof within 8 tiles above.
    bool hasRoof = false;
    for (int dy = 1; dy <= 8; dy++) {
      if (getBlock(tx, ty - dy).countsAsRoof) {
        hasRoof = true;
        break;
      }
    }

    // 2. Check background wall insulation at and around the explorer.
    final centerWall = getWall(tx, ty);
    final aboveWall = getWall(tx, ty - 1);
    final hasBgWalls =
        centerWall.providesInsulation && aboveWall.providesInsulation;

    // 3. Check horizontal side walls / closed doors within 6 tiles left & right.
    bool leftWall = false;
    bool rightWall = false;
    for (int dx = 1; dx <= 6; dx++) {
      final lb = getBlock(tx - dx, ty - 1);
      if (lb.isSolid || lb == BlockType.doorClosed) leftWall = true;
      final rb = getBlock(tx + dx, ty - 1);
      if (rb.isSolid || rb == BlockType.doorClosed) rightWall = true;
    }
    final hasSideEnclosure = leftWall && rightWall;

    // 4. Scan 5-tile radius for placed campfires and torches.
    bool nearCampfire = false;
    bool nearTorch = false;
    for (int dy = -4; dy <= 4; dy++) {
      for (int dx = -5; dx <= 5; dx++) {
        final b = getBlock(tx + dx, ty + dy);
        if (b == BlockType.campfire) nearCampfire = true;
        if (b == BlockType.torch) nearTorch = true;
      }
    }

    // Compute ambient temperature in Celsius.
    final dayWave = math.sin((timeOfDay - 0.2) * math.pi / 0.56);
    double temp = 16.0 + 13.0 * dayWave; // ~29°C midday, ~4°C midnight
    if (isRaining) temp -= 4.5;
    if (hasRoof && (hasBgWalls || hasSideEnclosure)) {
      temp += 9.0; // Shelter enclosure traps body heat
    }
    if (nearCampfire) temp += 12.0;
    if (nearTorch) temp += 3.5;

    return ShelterEvaluation(
      hasRoof: hasRoof,
      hasBackgroundWalls: hasBgWalls,
      hasSideEnclosure: hasSideEnclosure,
      nearCampfire: nearCampfire,
      nearTorch: nearTorch,
      ambientTemperatureCelsius: temp,
    );
  }

  /// Returns the nearest [NativeVillager] within interaction range (110 pixels),
  /// or `null` if no villager is nearby.
  NativeVillager? get nearbyVillager {
    for (final v in villagers) {
      final dist = math.sqrt(
        math.pow(v.x - playerX, 2) + math.pow(v.y - playerY, 2),
      );
      if (dist <= 115.0) return v;
    }
    return null;
  }

  /// Adds [count] of [item] to the explorer's inventory and places it in the
  /// hotbar if an empty slot is available.
  void addItem(ItemType item, int count) {
    if (count <= 0) return;
    inventory[item] = (inventory[item] ?? 0) + count;
    if (item.category == ItemCategory.seed) {
      milestoneGatheredSeeds = true;
    }
    if (!hotbar.contains(item) && hotbar.length < 10) {
      hotbar.add(item);
    }
  }

  /// Consumes one unit of [item] (or the first edible food in the inventory)
  /// to restore hunger, health, and warmth.
  bool eatFood([ItemType? specificFood]) {
    ItemType? target = specificFood;
    if (target == null || !target.isEdible || (inventory[target] ?? 0) <= 0) {
      if (equippedItem.isEdible && (inventory[equippedItem] ?? 0) > 0) {
        target = equippedItem;
      } else {
        for (final entry in inventory.entries) {
          if (entry.key.isEdible && entry.value > 0) {
            target = entry.key;
            break;
          }
        }
      }
    }
    if (target == null || (inventory[target] ?? 0) <= 0) {
      setBanner('No edible fruit or cooked fish in your pack!');
      return false;
    }

    inventory[target] = inventory[target]! - 1;
    hunger = (hunger + target.hungerRestore).clamp(0.0, 100.0);
    health = (health + target.healthRestore).clamp(0.0, 100.0);
    warmth = (warmth + target.warmthRestore).clamp(0.0, 100.0);
    setBanner(
      'Ate ${target.icon} ${target.label} (+${target.hungerRestore.round()} Hunger, +${target.healthRestore.round()} HP)',
    );
    return true;
  }

  /// Sows the currently equipped seed (or any seed in inventory) at or near
  /// tile coordinates ([tx], [ty]).
  ///
  /// Automatically tills [BlockType.grass] or [BlockType.dirt] into
  /// [BlockType.tilledSoil].
  ///
  /// {@example example/world_simulation_example.dart}
  bool sowSeedAt(int tx, int ty) {
    ItemType? seed =
        equippedItem.category == ItemCategory.seed &&
            (inventory[equippedItem] ?? 0) > 0
        ? equippedItem
        : null;
    seed ??= [
      ItemType.mangoSeeds,
      ItemType.bananaSeeds,
      ItemType.berrySeeds,
    ].where((s) => (inventory[s] ?? 0) > 0).firstOrNull;

    if (seed == null) {
      setBanner('You need seeds (🌱) to sow! Gather wild bushes or trade.');
      return false;
    }

    // Identify soil tile and the air tile directly above it.
    int soilY = ty;
    if (getBlock(tx, ty) == BlockType.air) {
      soilY = ty + 1;
    }
    final ground = getBlock(tx, soilY);
    final above = getBlock(tx, soilY - 1);
    if ((ground != BlockType.grass &&
            ground != BlockType.dirt &&
            ground != BlockType.tilledSoil) ||
        above != BlockType.air) {
      setBanner(
        'Sow seeds on surface grass or dirt blocks with open space above.',
      );
      return false;
    }

    final key = '$tx,${soilY - 1}';
    if (crops.containsKey(key)) {
      setBanner('A crop is already growing on that plot!');
      return false;
    }

    blocks[soilY][tx] = BlockType.tilledSoil;
    crops[key] = CropPlot(tileX: tx, tileY: soilY - 1, seedType: seed);
    inventory[seed] = inventory[seed]! - 1;
    milestoneSowedCrop = true;
    setBanner('Sowed ${seed.icon} ${seed.label} on tilled soil!');
    return true;
  }

  /// Harvests a mature crop at ([tx], [ty]) or mines/interacts with the tile.
  bool interactOrPlaceAt(int tx, int ty) {
    if ((tx - playerTileX).abs() > 5 || (ty - playerTileY).abs() > 5) {
      setBanner('Target tile is out of reach! Move closer.');
      return false;
    }

    // 1. Check if a ripe crop is at (tx, ty) or (tx, ty - 1).
    for (final cy in [ty, ty - 1]) {
      final key = '$tx,$cy';
      final crop = crops[key];
      if (crop != null && crop.isMature) {
        crops.remove(key);
        final fruit = crop.harvestedFruit;
        addItem(fruit, 2 + _rng.nextInt(2));
        addItem(crop.seedType, 1 + _rng.nextInt(2));
        milestoneHarvestedFruit = true;
        setBanner('Harvested ripe ${fruit.icon} ${fruit.label} + seeds!');
        return true;
      }
    }

    // 2. Toggle shelter doors if tapping a door block.
    final block = getBlock(tx, ty);
    if (block == BlockType.doorClosed) {
      blocks[ty][tx] = BlockType.doorOpen;
      setBanner('Opened shelter door.');
      return true;
    } else if (block == BlockType.doorOpen) {
      blocks[ty][tx] = BlockType.doorClosed;
      setBanner('Closed shelter door (blocks predators & traps warmth).');
      return true;
    }

    // 3. If holding Fishing Rod and clicking near water, cast or reel in!
    if (equippedItem == ItemType.fishingRod || block == BlockType.water) {
      if ((inventory[ItemType.fishingRod] ?? 0) > 0 &&
          (block == BlockType.water || _isWaterNearby(tx, ty))) {
        return toggleFishingCast(tx, ty);
      }
    }

    // 4. If holding a seed, sow it.
    if (equippedItem.category == ItemCategory.seed &&
        (inventory[equippedItem] ?? 0) > 0) {
      return sowSeedAt(tx, ty);
    }

    // 5. If holding a building block or background wall, place it.
    final item = equippedItem;
    if (item.category == ItemCategory.building && (inventory[item] ?? 0) > 0) {
      if (item.placedWall != null) {
        if (getWall(tx, ty) != item.placedWall) {
          walls[ty][tx] = item.placedWall!;
          inventory[item] = inventory[item]! - 1;
          setBanner('Placed ${item.label} for shelter insulation.');
          return true;
        }
      } else if (item.placedBlock != null && block == BlockType.air) {
        // Prevent placing a solid block directly inside the explorer's body.
        final overlapsPlayer =
            tx == playerTileX && (ty == playerTileY || ty == playerTileY - 1);
        if (!overlapsPlayer || !item.placedBlock!.isSolid) {
          blocks[ty][tx] = item.placedBlock!;
          if (item == ItemType.doorItem &&
              ty - 1 >= 0 &&
              blocks[ty - 1][tx] == BlockType.air) {
            // Doors are 1-tile or 2-tile tall; add background wood wall for seal.
            walls[ty][tx] = WallType.woodWall;
          }
          inventory[item] = inventory[item]! - 1;
          setBanner('Placed ${item.icon} ${item.label}.');
          return true;
        }
      }
    }

    return false;
  }

  bool _isWaterNearby(int tx, int ty) {
    for (int dy = -2; dy <= 2; dy++) {
      for (int dx = -2; dx <= 2; dx++) {
        if (getBlock(tx + dx, ty + dy) == BlockType.water) return true;
      }
    }
    return false;
  }

  /// Casts the fishing line into a water block near ([tx], [ty]) or reels in
  /// an active bite.
  bool toggleFishingCast([int? targetTx, int? targetTy]) {
    if ((inventory[ItemType.fishingRod] ?? 0) <= 0) {
      setBanner(
        'Craft a 🎣 Fishing Rod first (2 Mahogany Logs + 2 Vine Fibers)!',
      );
      return false;
    }

    if (activeFishing != null) {
      final fishState = activeFishing!;
      activeFishing = null;
      if (fishState.hasBite) {
        addItem(ItemType.rawFish, 1);
        if (_rng.nextDouble() < 0.35) {
          addItem(ItemType.bananaSeeds, 1);
        }
        milestoneCaughtFish = true;
        setBanner('🐟 Caught a fresh River Fish! Roast it at a Campfire.');
        return true;
      } else {
        setBanner('Reeled in fishing line early.');
        return false;
      }
    }

    // Locate water block to drop bobber.
    int? waterX;
    int? waterY;
    final searchCenterX =
        targetTx ?? (playerTileX + (playerFacingRight ? 3 : -3));
    final searchCenterY = targetTy ?? playerTileY;
    for (int r = 0; r <= 5 && waterX == null; r++) {
      for (int dy = -r; dy <= r && waterX == null; dy++) {
        for (int dx = -r; dx <= r && waterX == null; dx++) {
          final cx = searchCenterX + dx;
          final cy = searchCenterY + dy;
          if (getBlock(cx, cy) == BlockType.water) {
            waterX = cx;
            waterY = cy;
          }
        }
      }
    }

    if (waterX == null || waterY == null) {
      setBanner(
        'Walk next to a jungle river or lagoon to cast your fishing rod!',
      );
      return false;
    }

    activeFishing = FishingState(
      bobberX: waterX * tileSize + tileSize * 0.5,
      bobberY: waterY * tileSize + tileSize * 0.4,
      waitTimer: 2.2 + _rng.nextDouble() * 2.0,
    );
    setBanner('🎣 Cast line into the river... wait for the splash!');
    return true;
  }

  /// Performs a melee swing with the equipped tool/weapon against nearby
  /// dangerous animals.
  bool attackNearbyAnimals() {
    swingAnimationTimer = 0.25;
    final damage = equippedItem.attackDamage;
    bool hitAny = false;

    for (int i = animals.length - 1; i >= 0; i--) {
      final a = animals[i];
      final dx = a.x - playerX;
      final dy = a.y - (playerY - 12.0);
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist <= 68.0) {
        a.health -= damage;
        a.hurtFlashTimer = 0.25;
        a.vx = (dx >= 0 ? 1 : -1) * 160.0;
        a.vy = -120.0;
        hitAny = true;
        if (a.health <= 0) {
          animals.removeAt(i);
          milestoneDefeatedPredator = true;
          if (a.type == AnimalType.piranha) {
            addItem(ItemType.rawFish, 1);
          } else {
            addItem(ItemType.vineFiber, 2);
            addItem(ItemType.healingHerb, 1);
          }
          setBanner('Defeated ${a.type.label}! Gathered survival drops.');
        } else {
          setBanner(
            'Hit ${a.type.label} for ${damage.round()} dmg (${a.health.ceil()} HP left)!',
          );
        }
      }
    }
    return hitAny;
  }

  /// Mines the block at ([tx], [ty]) for duration [dt] seconds.
  void mineTileStep(int tx, int ty, double dt) {
    if ((tx - playerTileX).abs() > 5 || (ty - playerTileY).abs() > 5) {
      miningTarget = null;
      miningProgress = 0.0;
      return;
    }

    // First check if a mature crop can be harvested immediately.
    final cropKey = '$tx,$ty';
    if (crops[cropKey]?.isMature == true) {
      interactOrPlaceAt(tx, ty);
      return;
    }

    final block = getBlock(tx, ty);
    if (block == BlockType.air ||
        block == BlockType.water ||
        block == BlockType.villageHutBlock) {
      miningTarget = null;
      miningProgress = 0.0;
      return;
    }

    swingAnimationTimer = 0.18;
    if (miningTarget != (tx, ty)) {
      miningTarget = (tx, ty);
      miningProgress = 0.0;
    }

    final speed = equippedItem.miningSpeedMultiplier;
    miningProgress += (dt * speed) / math.max(0.15, block.hardness);
    if (miningProgress >= 1.0) {
      _harvestBlockDrop(tx, ty, block);
      blocks[ty][tx] = BlockType.air;
      crops.remove('$tx,${ty - 1}');
      miningTarget = null;
      miningProgress = 0.0;
    }
  }

  void _harvestBlockDrop(int tx, int ty, BlockType block) {
    switch (block) {
      case BlockType.grass:
        addItem(ItemType.dirtBlock, 1);
        if (_rng.nextDouble() < 0.65) {
          addItem(ItemType.berrySeeds, 1);
          setBanner('Gathered Jungle Dirt + 🌱 Berry Seeds!');
        }
      case BlockType.dirt:
      case BlockType.tilledSoil:
        addItem(ItemType.dirtBlock, 1);
      case BlockType.stone:
        addItem(ItemType.stoneBlock, 1);
      case BlockType.coalOre:
        addItem(ItemType.coalItem, 1);
        addItem(ItemType.stoneBlock, 1);
        setBanner('Mined ⚫ Coal Lump!');
      case BlockType.ironOre:
        addItem(ItemType.ironOreItem, 1);
        setBanner('Mined 🔩 Iron Ore!');
      case BlockType.woodLog:
        addItem(ItemType.woodLogItem, 2);
        setBanner('Chopped 🌲 Mahogany Logs!');
      case BlockType.leaves:
        addItem(ItemType.thatchBundle, 2);
        if (_rng.nextDouble() < 0.45) {
          addItem(ItemType.banana, 1);
          addItem(ItemType.bananaSeeds, 1);
          setBanner('Gathered 🍃 Thatch + 🍌 Banana & Seeds!');
        }
      case BlockType.vine:
        addItem(ItemType.vineFiber, 2);
        if (_rng.nextDouble() < 0.4) {
          addItem(ItemType.berrySeeds, 1);
        }
        setBanner('Harvested 🪢 Vine Fibers!');
      case BlockType.berryBush:
        addItem(ItemType.jungleBerry, 2);
        addItem(ItemType.berrySeeds, 2);
        setBanner('Gathered 🫐 Jungle Berries & 🌱 Berry Seeds!');
      case BlockType.woodPlank:
        addItem(ItemType.woodPlankItem, 1);
      case BlockType.thatchRoof:
        addItem(ItemType.thatchRoofItem, 1);
      case BlockType.doorClosed:
      case BlockType.doorOpen:
        addItem(ItemType.doorItem, 1);
      case BlockType.campfire:
        addItem(ItemType.campfireItem, 1);
      case BlockType.torch:
        addItem(ItemType.torchItem, 1);
      case BlockType.air:
      case BlockType.water:
      case BlockType.villageHutBlock:
        break;
    }
  }

  /// Attempts to craft [recipe] if the explorer holds the required ingredients
  /// (and stands near a campfire if [CraftingRecipe.requiresCampfire] is true).
  bool craft(CraftingRecipe recipe) {
    if (recipe.requiresCampfire) {
      final shelter = evaluateShelterStatus(playerTileX, playerTileY);
      if (!shelter.nearCampfire) {
        setBanner(
          'You must stand near a placed 🔥 Campfire to craft ${recipe.output.label}!',
        );
        return false;
      }
    }
    for (final req in recipe.ingredients.entries) {
      if ((inventory[req.key] ?? 0) < req.value) {
        setBanner(
          'Need ${req.value}x ${req.key.label} to craft ${recipe.output.label}.',
        );
        return false;
      }
    }
    for (final req in recipe.ingredients.entries) {
      inventory[req.key] = inventory[req.key]! - req.value;
    }
    addItem(recipe.output, recipe.outputCount);
    setBanner(
      'Crafted ${recipe.outputCount}x ${recipe.output.icon} ${recipe.output.label}!',
    );
    return true;
  }

  /// Executes a barter trade with a [NativeVillager].
  bool executeTrade(VillageTrade trade) {
    final have = inventory[trade.costItem] ?? 0;
    if (have < trade.costCount) {
      setBanner(
        'Need ${trade.costCount}x ${trade.costItem.icon} ${trade.costItem.label} for this trade!',
      );
      return false;
    }
    inventory[trade.costItem] = have - trade.costCount;
    addItem(trade.rewardItem, trade.rewardCount);
    milestoneTradedWithNatives = true;
    setBanner(
      'Traded ${trade.costCount}x ${trade.costItem.label} for ${trade.rewardCount}x ${trade.rewardItem.icon} ${trade.rewardItem.label}!',
    );
    return true;
  }

  /// Sets the HUD banner message for 4.5 seconds.
  void setBanner(String message) {
    statusMessage = message;
    statusBannerTimer = 4.5;
  }

  /// Advances the world simulation by [dt] seconds.
  ///
  /// Updates time of day, weather, hunger and cold survival gauges, planted
  /// crop growth, active fishing bobber, player movement physics, and animal AI.
  ///
  /// {@example example/world_simulation_example.dart}
  void update(
    double dt, {
    bool moveLeft = false,
    bool moveRight = false,
    bool jumpOrSwimUp = false,
    bool climbDown = false,
  }) {
    final clampedDt = dt.clamp(0.0, 0.05);

    if (statusBannerTimer > 0) statusBannerTimer -= clampedDt;
    if (swingAnimationTimer > 0) swingAnimationTimer -= clampedDt;
    if (playerHurtFlashTimer > 0) playerHurtFlashTimer -= clampedDt;

    // 1. Advance Day/Night cycle (1 full day = 150 seconds).
    final prevTime = timeOfDay;
    timeOfDay = (timeOfDay + clampedDt / 150.0) % 1.0;
    if (timeOfDay < prevTime) {
      dayCount++;
      setBanner('☀️ Dawn of Day $dayCount in the Jungle!');
    }

    // Weather transitions.
    _weatherTimer -= clampedDt;
    if (_weatherTimer <= 0) {
      isRaining = _rng.nextDouble() < 0.30;
      _weatherTimer = 25.0 + _rng.nextDouble() * 30.0;
    }

    // 2. Evaluate shelter & update Hunger / Warmth / Life Points.
    final shelter = evaluateShelterStatus(playerTileX, playerTileY);
    if (shelter.isCompleteShelter && shelter.nearCampfire) {
      milestoneBuiltShelter = true;
    }

    // Hunger decays slowly (~1.1 points/sec).
    hunger = (hunger - clampedDt * 0.95).clamp(0.0, 100.0);

    // Warmth responds to ambient temperature & shelter protection.
    final coldThreshold = 17.5;
    if (shelter.ambientTemperatureCelsius < coldThreshold &&
        !shelter.isCompleteShelter &&
        !shelter.nearCampfire) {
      final chillFactor =
          (coldThreshold - shelter.ambientTemperatureCelsius) *
          0.26 *
          (hasWarmPoncho ? 0.5 : 1.0);
      warmth = (warmth - clampedDt * chillFactor).clamp(0.0, 100.0);
    } else {
      final recoveryRate = shelter.nearCampfire ? 7.5 : 3.5;
      warmth = (warmth + clampedDt * recoveryRate).clamp(0.0, 100.0);
    }

    // Life points drain if starving or freezing; slowly regenerate when well-fed & warm.
    if (hunger <= 0.0) {
      health = (health - clampedDt * 3.2).clamp(0.0, 100.0);
    }
    if (warmth <= 0.0) {
      health = (health - clampedDt * 3.8).clamp(0.0, 100.0);
    }
    if (hunger > 65.0 && warmth > 55.0 && health < 100.0) {
      health = (health + clampedDt * 1.2).clamp(0.0, 100.0);
    }

    // Respawn explorer at village clearing if life points hit zero.
    if (health <= 0.0) {
      health = 100.0;
      hunger = 75.0;
      warmth = 90.0;
      playerX = 37 * tileSize;
      playerY = 20 * tileSize;
      playerVx = 0;
      playerVy = 0;
      setBanner('Rescued by native villagers! Keep food & shelter ready.');
    }

    // 3. Grow planted crops.
    final growthMultiplier = (isNight ? 0.45 : 1.15) * (isRaining ? 1.35 : 1.0);
    for (final crop in crops.values) {
      if (!crop.isMature) {
        final nearWater = _isWaterNearby(crop.tileX, crop.tileY + 1);
        final rate = (nearWater ? 0.048 : 0.032) * growthMultiplier;
        crop.growthProgress = (crop.growthProgress + clampedDt * rate).clamp(
          0.0,
          1.0,
        );
      }
    }

    // 4. Update active fishing cast.
    if (activeFishing != null) {
      final fish = activeFishing!;
      if (!fish.hasBite) {
        fish.waitTimer -= clampedDt;
        if (fish.waitTimer <= 0) {
          fish.hasBite = true;
          fish.biteWindowRemaining = 2.6;
          setBanner('🐟 SPLASH! A fish is biting! Tap Fish / Reel In now!');
        }
      } else {
        fish.biteWindowRemaining -= clampedDt;
        if (fish.biteWindowRemaining <= 0) {
          activeFishing = null;
          setBanner('The fish got away! Cast again.');
        }
      }
    }

    // 5. Update Explorer movement & physics.
    _updatePlayerPhysics(
      clampedDt,
      moveLeft: moveLeft,
      moveRight: moveRight,
      jumpOrSwimUp: jumpOrSwimUp,
      climbDown: climbDown,
    );

    // 6. Update & spawn dangerous animals.
    _updateAnimals(clampedDt);
  }

  void _updatePlayerPhysics(
    double dt, {
    required bool moveLeft,
    required bool moveRight,
    required bool jumpOrSwimUp,
    required bool climbDown,
  }) {
    const moveSpeed = 148.0;
    const gravity = 560.0;
    const jumpImpulse = -255.0;

    if (moveLeft && !moveRight) {
      playerVx = -moveSpeed;
      playerFacingRight = false;
      activeFishing = null;
    } else if (moveRight && !moveLeft) {
      playerVx = moveSpeed;
      playerFacingRight = true;
      activeFishing = null;
    } else {
      playerVx *= 0.72;
      if (playerVx.abs() < 4.0) playerVx = 0.0;
    }

    final footBlock = getBlock(playerTileX, (playerY - 4) ~/ tileSize);
    final torsoBlock = getBlock(playerTileX, playerTileY);
    final inWater =
        footBlock == BlockType.water || torsoBlock == BlockType.water;
    final onVine = footBlock == BlockType.vine || torsoBlock == BlockType.vine;

    if (onVine) {
      if (jumpOrSwimUp) {
        playerVy = -120.0;
      } else if (climbDown) {
        playerVy = 120.0;
      } else {
        playerVy = 0.0;
      }
    } else if (inWater) {
      playerVy += gravity * 0.25 * dt;
      if (jumpOrSwimUp) {
        playerVy = -135.0;
      }
      playerVy = playerVy.clamp(-140.0, 110.0);
    } else {
      playerVy = (playerVy + gravity * dt).clamp(-340.0, 420.0);
    }

    // Horizontal step & collision check.
    final nextX = (playerX + playerVx * dt).clamp(
      tileSize,
      (width - 1) * tileSize,
    );
    if (!_collidesAt(nextX, playerY)) {
      playerX = nextX;
    } else {
      // Auto-step up 1 single block height if air is above it (smooth mobile/platforming feel).
      if (!_collidesAt(nextX, playerY - tileSize) &&
          _collidesAt(playerX, playerY + 2.0)) {
        playerX = nextX;
        playerY -= tileSize;
      } else {
        playerVx = 0.0;
      }
    }

    // Vertical step & ground collision check.
    final nextY = (playerY + playerVy * dt).clamp(
      tileSize * 2,
      (height - 2) * tileSize,
    );
    if (!_collidesAt(playerX, nextY)) {
      playerY = nextY;
    } else {
      final landedOnGround = playerVy > 0;
      playerVy = 0.0;
      if (landedOnGround && jumpOrSwimUp && !onVine && !inWater) {
        playerVy = jumpImpulse;
      }
    }
  }

  bool _collidesAt(double px, double py) {
    const halfW = 9.0;
    const heightPx = 26.0;
    final leftTile = ((px - halfW) ~/ tileSize);
    final rightTile = ((px + halfW) ~/ tileSize);
    final topTile = ((py - heightPx) ~/ tileSize);
    final bottomTile = ((py - 1.0) ~/ tileSize);

    for (int ty = topTile; ty <= bottomTile; ty++) {
      for (int tx = leftTile; tx <= rightTile; tx++) {
        if (getBlock(tx, ty).isSolid) return true;
      }
    }
    return false;
  }

  void _updateAnimals(double dt) {
    _animalSpawnTimer -= dt;
    final maxAnimals = isNight ? 9 : 6;
    if (_animalSpawnTimer <= 0 && animals.length < maxAnimals) {
      _animalSpawnTimer = isNight ? 10.0 : 16.0;
      final offsetTiles = (_rng.nextBool() ? 1 : -1) * (14 + _rng.nextInt(12));
      final spawnTx = (playerTileX + offsetTiles).clamp(6, width - 6);
      // Do not spawn predators directly inside the two native village safe zones.
      final inVillage =
          (spawnTx >= 33 && spawnTx <= 47) ||
          (spawnTx >= 115 && spawnTx <= 129);
      if (!inVillage) {
        int surfaceTy = 10;
        while (surfaceTy < height - 2 &&
            !getBlock(spawnTx, surfaceTy).isSolid &&
            getBlock(spawnTx, surfaceTy) != BlockType.water) {
          surfaceTy++;
        }
        if (getBlock(spawnTx, surfaceTy) == BlockType.water) {
          animals.add(
            JungleAnimal(
              type: AnimalType.piranha,
              x: spawnTx * tileSize,
              y: (surfaceTy + 1) * tileSize,
            ),
          );
        } else {
          final type = (_rng.nextDouble() < (isNight ? 0.6 : 0.4))
              ? AnimalType.jaguar
              : AnimalType.snake;
          animals.add(
            JungleAnimal(
              type: type,
              x: spawnTx * tileSize,
              y: surfaceTy * tileSize,
            ),
          );
        }
      }
    }

    for (final a in animals) {
      if (a.attackCooldown > 0) a.attackCooldown -= dt;
      if (a.hurtFlashTimer > 0) a.hurtFlashTimer -= dt;
      a.patrolTimer -= dt;

      final dxToPlayer = playerX - a.x;
      final dyToPlayer = playerY - a.y;
      final distToPlayer = math.sqrt(
        dxToPlayer * dxToPlayer + dyToPlayer * dyToPlayer,
      );

      final aggroRange = isNight ? 240.0 : 165.0;
      if (distToPlayer < aggroRange) {
        a.facingRight = dxToPlayer >= 0;
        a.vx = (dxToPlayer >= 0 ? 1.0 : -1.0) * a.type.speed;
      } else {
        if (a.patrolTimer <= 0) {
          a.facingRight = _rng.nextBool();
          a.patrolTimer = 2.0 + _rng.nextDouble() * 2.5;
        }
        a.vx = (a.facingRight ? 0.55 : -0.55) * a.type.speed;
      }

      if (a.type.aquatic) {
        final nextX = a.x + a.vx * dt;
        final tx = (nextX ~/ tileSize).clamp(0, width - 1);
        final ty = ((a.y - 8) ~/ tileSize).clamp(0, height - 1);
        if (getBlock(tx, ty) == BlockType.water) {
          a.x = nextX;
        } else {
          a.facingRight = !a.facingRight;
        }
      } else {
        a.vy = (a.vy + 520.0 * dt).clamp(-260.0, 360.0);
        final nextX = a.x + a.vx * dt;
        final frontTx = ((nextX + (a.facingRight ? 10 : -10)) ~/ tileSize)
            .clamp(0, width - 1);
        final bodyTy = ((a.y - 10) ~/ tileSize).clamp(0, height - 1);

        final frontBlock = getBlock(frontTx, bodyTy);
        // Shelter doors & solid walls block predators; Jaguars can jump 1-tile ledges if not a door/wall.
        if (!frontBlock.isSolid) {
          a.x = nextX;
        } else if (frontBlock != BlockType.doorClosed &&
            frontBlock != BlockType.woodPlank &&
            frontBlock != BlockType.villageHutBlock &&
            !getBlock(frontTx, bodyTy - 1).isSolid) {
          a.x = nextX;
          a.y -= tileSize;
        } else {
          a.facingRight = !a.facingRight;
        }

        final nextY = a.y + a.vy * dt;
        final footTy = (nextY ~/ tileSize).clamp(0, height - 1);
        if (!getBlock((a.x ~/ tileSize).clamp(0, width - 1), footTy).isSolid) {
          a.y = nextY;
        } else {
          a.vy = 0.0;
        }
      }

      // Check contact bite on explorer (blocked if a solid wall/door separates them).
      if (distToPlayer < 24.0 && a.attackCooldown <= 0) {
        final midTx = (((a.x + playerX) * 0.5) ~/ tileSize).clamp(0, width - 1);
        final midTy = (((a.y + playerY - 16.0) * 0.5) ~/ tileSize).clamp(
          0,
          height - 1,
        );
        if (!getBlock(midTx, midTy).isSolid) {
          a.attackCooldown = 1.35;
          health = (health - a.type.contactDamage).clamp(0.0, 100.0);
          playerHurtFlashTimer = 0.35;
          playerVx = (playerX >= a.x ? 1 : -1) * 175.0;
          playerVy = -130.0;
          setBanner(
            '⚠️ Attacked by ${a.type.label} (-${a.type.contactDamage.round()} HP)! Fight back or retreat to shelter!',
          );
        }
      }
    }
  }
}
