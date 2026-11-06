import 'dart:collection';
import 'dart:math' as math;

import 'models.dart';
import 'sound_synthesizer.dart';

/// Infinite horizontal row view backed by 16-tile chunks generated on demand.
///
/// Supports negative (`tx < 0`, West) and positive (`tx >= 0`, East) horizontal
/// tile indices while preserving standard `List<T>` (`blocks[y][x]`) access.
final class _InfiniteTileRow<T> extends ListBase<T> {
  _InfiniteTileRow({
    required this.world,
    required this.defaultValue,
    required int nominalLength,
  }) : _nominalLength = nominalLength;

  final JungleWorld world;
  final T defaultValue;
  final Map<int, List<T>> _chunks = {};
  int _nominalLength;

  static int chunkIndexOf(int tx) => (tx / JungleWorld.chunkWidth).floor();

  static int localIndexOf(int tx) =>
      tx - chunkIndexOf(tx) * JungleWorld.chunkWidth;

  @override
  int get length => _nominalLength;

  @override
  set length(int newLength) {
    _nominalLength = newLength;
  }

  T _getRaw(int tx) {
    final chunk = _chunks[chunkIndexOf(tx)];
    return chunk != null ? chunk[localIndexOf(tx)] : defaultValue;
  }

  void _setRaw(int tx, T value) {
    final chunkIdx = chunkIndexOf(tx);
    final chunk =
        _chunks[chunkIdx] ??= List<T>.filled(
          JungleWorld.chunkWidth,
          defaultValue,
        );
    chunk[localIndexOf(tx)] = value;
  }

  @override
  T operator [](int index) {
    world.ensureChunkGenerated(chunkIndexOf(index));
    return _getRaw(index);
  }

  @override
  void operator []=(int index, T value) {
    final chunkIdx = chunkIndexOf(index);
    world.ensureChunkGenerated(chunkIdx);
    world._activePhysicsChunks.add(chunkIdx);
    _setRaw(index, value);
  }
}

/// Complete mutable simulation state for the 2D side-scrolling jungle world.
///
/// Manages infinitely streamed horizontal terrain chunks, background shelter
/// walls, cellular automata physics (gravity-driven water flow and fire
/// propagation), player physics, hunger and cold survival stats, multi-variety
/// crop growth, active plant defenses, beehives and bee/toucan pollination,
/// capuchin monkey foraging and taming, fishing casts, native villager trading,
/// and wildlife AI.
///
/// {@example example/world_simulation_example.dart}
final class JungleWorld {
  /// Creates a generated jungle world using [worldSeed].
  ///
  /// It is an error if [width] or [height] is less than `20`.
  JungleWorld._({
    required this.width,
    required this.height,
    required this.worldSeed,
    required this.playerX,
    required this.playerY,
  }) : _rng = math.Random(worldSeed) {
    if (width < 20) {
      throw ArgumentError.value(
        width,
        'width',
        'Must be at least 20 tiles wide.',
      );
    }
    if (height < 20) {
      throw ArgumentError.value(
        height,
        'height',
        'Must be at least 20 tiles high.',
      );
    }
    blocks = List<List<BlockType>>.generate(
      height,
      (_) => _InfiniteTileRow<BlockType>(
        world: this,
        defaultValue: BlockType.air,
        nominalLength: width,
      ),
    );
    walls = List<List<WallType>>.generate(
      height,
      (_) => _InfiniteTileRow<WallType>(
        world: this,
        defaultValue: WallType.none,
        nominalLength: width,
      ),
    );

    // Lean starter survival kit: begin with only a crude Wood Pickaxe, a
    // starter seed pouch, and light rations. Weapons, torches, water buckets,
    // stone/iron pickaxes, glow-bulbs, and mahogany saplings must be foraged,
    // grown, or crafted to unlock the 3 danger zones and awaken the Shrine!
    inventory[ItemType.woodPickaxe] = 1;
    inventory[ItemType.berrySeeds] = 3;
    inventory[ItemType.bananaSeeds] = 1;
    inventory[ItemType.healingHerbSeeds] = 1;
    inventory[ItemType.thornVineSeeds] = 1;
    inventory[ItemType.pitcherPlantSeeds] = 1;
    inventory[ItemType.jungleBerry] = 2;
    inventory[ItemType.banana] = 1;
  }

  /// Standard pixel size of a single world grid tile.
  static const double tileSize = 32.0;

  /// Horizontal width in tiles of each streamed terrain chunk.
  static const int chunkWidth = 16;

  /// Standard surface river and lagoon water level (tile Y).
  static const int waterLevel = 23;

  /// Converts a world pixel coordinate to a tile coordinate (supporting negative
  /// coordinates cleanly via `.floor()`).
  static int pixelToTile(double pixelCoord) => (pixelCoord / tileSize).floor();

  /// Standard crafting recipes available in the crafting menu.
  static final List<CraftingRecipe> recipes = [
    CraftingRecipe(
      output: ItemType.healingHerbSeeds,
      outputCount: 2,
      ingredients: {ItemType.healingHerb: 1, ItemType.vineFiber: 1},
      description:
          'Extract aromatic herb seeds whose scent repels venomous vipers.',
    ),
    CraftingRecipe(
      output: ItemType.thornVineSeeds,
      outputCount: 2,
      ingredients: {ItemType.vineFiber: 2, ItemType.berrySeeds: 1},
      description:
          'Splice spiky briar seeds that grow into predator-pricking hedges.',
    ),
    CraftingRecipe(
      output: ItemType.glowBulbSeeds,
      outputCount: 2,
      ingredients: {ItemType.honeycomb: 1, ItemType.berrySeeds: 1},
      description:
          'Cultivate bioluminescent spores that glow at night and calm bees.',
    ),
    CraftingRecipe(
      output: ItemType.pitcherPlantSeeds,
      outputCount: 2,
      ingredients: {ItemType.rawFish: 1, ItemType.vineFiber: 1},
      description:
          'Breed carnivorous pitcher seeds that lure snakes and fertilize soil.',
    ),
    CraftingRecipe(
      output: ItemType.mahoganySapling,
      outputCount: 1,
      ingredients: {ItemType.woodLogItem: 1, ItemType.thatchBundle: 1},
      description:
          'Root a Mahogany Sapling that grows into a full canopy tree.',
    ),
    CraftingRecipe(
      output: ItemType.peatBogBlock,
      outputCount: 3,
      ingredients: {ItemType.dirtBlock: 2, ItemType.thatchBundle: 1},
      description:
          'Compost acidic Mossy Peat Bog soil (1.8x boost for Pitcher Plants, Glow-Bulbs & Herbs).',
    ),
    CraftingRecipe(
      output: ItemType.riverSiltBlock,
      outputCount: 3,
      ingredients: {ItemType.dirtBlock: 2, ItemType.rawFish: 1},
      description:
          'Mix moisture-rich Alluvial River Silt (1.6x boost for Bananas, Glow-Bulbs & Mangoes).',
    ),
    CraftingRecipe(
      output: ItemType.volcanicAshBlock,
      outputCount: 3,
      ingredients: {ItemType.dirtBlock: 2, ItemType.coalItem: 1},
      description:
          'Enrich warm Volcanic Highland Ash soil (1.7x boost for Briar Thorns, Mangoes & Herbs).',
    ),
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
      description: 'Toggleable door that blocks predators and holds warmth.',
    ),
    CraftingRecipe(
      output: ItemType.campfireItem,
      outputCount: 1,
      ingredients: {ItemType.woodLogItem: 2, ItemType.stoneBlock: 2},
      description:
          'Heats shelters at night, calms bees with smoke, and roasts fish.',
    ),
    CraftingRecipe(
      output: ItemType.torchItem,
      outputCount: 3,
      ingredients: {ItemType.woodLogItem: 1, ItemType.vineFiber: 1},
      description:
          'Lights up caverns, calms beehives for safe honey harvest, or ignites brush.',
    ),
    CraftingRecipe(
      output: ItemType.woodenBeehiveItem,
      outputCount: 1,
      ingredients: {
        ItemType.woodPlankItem: 2,
        ItemType.thatchBundle: 1,
        ItemType.honeycomb: 1,
      },
      description:
          'Domesticated apiary hive that produces honey and boosts crop growth by +50%.',
    ),
    CraftingRecipe(
      output: ItemType.waterBucket,
      outputCount: 2,
      ingredients: {ItemType.woodLogItem: 1, ItemType.vineFiber: 1},
      description:
          'Bamboo water bucket to pour waterfalls, fill moats, or douse spreading fires.',
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
      description:
          'Upgraded stone pickaxe required to mine Iron Ore and breach Ancient Obsidian.',
    ),
    CraftingRecipe(
      output: ItemType.ironPickaxe,
      outputCount: 1,
      ingredients: {
        ItemType.ironOreItem: 2,
        ItemType.coalItem: 1,
        ItemType.woodLogItem: 1,
      },
      description:
          'Heavy forged pickaxe that shatters deep Ancient Obsidian vaults (4.8x mining speed).',
      requiresCampfire: true,
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
      output: ItemType.healingHerb,
      outputCount: 2,
      ingredients: {ItemType.jungleBerry: 2, ItemType.vineFiber: 1},
      description:
          'Field poultice (+40 HP) that also protects against Toxic Viper Marsh Miasma.',
    ),
    CraftingRecipe(
      output: ItemType.warmPoncho,
      outputCount: 1,
      ingredients: {ItemType.vineFiber: 4, ItemType.thatchBundle: 3},
      description:
          'Woven thermal poncho that cuts night cold heat loss by 50%.',
    ),
  ];

  /// Generates an infinitely streamable side-scrolling jungle world with
  /// multi-biome terrain, rivers, native villages, wild botanical clearings,
  /// canopy trees, wild beehives, caves, and wildlife.
  ///
  /// Pre-generates the initial [width] span (`0..width-1`) and seamlessly
  /// generates new 16-tile horizontal chunks on the fly in both West (`-∞`)
  /// and East (`+∞`) directions as the explorer moves or interacts.
  factory JungleWorld.generate({int? seed, int width = 160, int height = 56}) {
    final resolvedSeed = seed ?? (math.Random().nextInt(900000) + 100000);
    const spawnTileX = 28;
    final world = JungleWorld._(
      width: width,
      height: height,
      worldSeed: resolvedSeed,
      playerX: spawnTileX * tileSize + tileSize * 0.5,
      playerY: 20 * tileSize,
    );

    final initialChunks = (width / chunkWidth).ceil();
    for (int c = 0; c < initialChunks; c++) {
      world.ensureChunkGenerated(c);
    }

    final spawnSurfaceY = world.surfaceElevationAt(spawnTileX);
    world.playerY = spawnSurfaceY * tileSize;
    return world;
  }

  /// Nominal initial span of the world in tiles (chunks extend infinitely in
  /// both `-X` and `+X` directions beyond this initial window).
  final int width;

  /// Vertical height of the world in tiles.
  final int height;

  /// Deterministic world generation seed.
  final int worldSeed;

  /// 2D grid (`[y][x]`) of foreground blocks backed by infinite chunk rows.
  late final List<List<BlockType>> blocks;

  /// 2D grid (`[y][x]`) of background shelter walls backed by infinite chunk rows.
  late final List<List<WallType>> walls;

  /// Native village NPCs available for fruit trading across discovered chunks.
  final List<NativeVillager> villagers = [];

  /// Active wildlife entities (predators, pollinators, monkeys, and toucans)
  /// in the world.
  final List<JungleAnimal> animals = [];

  /// Set of horizontal chunk indices (`chunkIdx = (tx / 16).floor()`) that have
  /// already been procedurally generated.
  final Set<int> _generatedChunks = {};

  /// Set of chunk indices that have had block modifications (water/fire/build)
  /// and should be included in cellular automata physics steps.
  final Set<int> _activePhysicsChunks = {};

  /// Number of 16-tile horizontal chunks generated so far.
  int get generatedChunkCount => _generatedChunks.length;

  /// Total horizontal tile span generated so far across all visited chunks.
  int get exploredTileSpan => _generatedChunks.length * chunkWidth;

  /// Minimum and maximum horizontal tile coordinates generated so far.
  (int, int) get generatedTileBounds {
    if (_generatedChunks.isEmpty) return (0, width - 1);
    int minC = _generatedChunks.first;
    int maxC = _generatedChunks.first;
    for (final c in _generatedChunks) {
      if (c < minC) minC = c;
      if (c > maxC) maxC = c;
    }
    return (minC * chunkWidth, (maxC + 1) * chunkWidth - 1);
  }

  /// Returns a deterministic pseudo-random hash in `0..0x7fffffff` for
  /// ([chunkIdx], [salt]).
  int _hashCoords(int chunkIdx, [int salt = 0]) {
    int h = worldSeed ^ (chunkIdx * 0x27d4eb2d) ^ (salt * 0x165667b1);
    h = ((h >> 15) ^ h) * 0x85ebca6b;
    h = ((h >> 13) ^ h) * 0xc2b2ae35;
    h = (h >> 16) ^ h;
    return h & 0x7fffffff;
  }

  /// Returns the [JungleBiome] for the 16-tile chunk at [chunkIndex].
  JungleBiome biomeForChunk(int chunkIndex) {
    // Keep the initial valley (chunks 1..7) rich with all 5 biomes so starter
    // exploration immediately encounters villages, rivers, groves, and crags.
    switch (chunkIndex) {
      case 1:
        return JungleBiome.canopyForest;
      case 2:
        return JungleBiome.nativeVillage;
      case 3:
        return JungleBiome.riverLagoon;
      case 4:
        return JungleBiome.botanicalClearing;
      case 5:
        return JungleBiome.mistHighlands;
      case 6:
        return JungleBiome.riverLagoon;
      case 7:
        return JungleBiome.nativeVillage;
    }

    // Outside the starter valley (for any negative West or positive East chunk),
    // place a Native Village deterministically every 6–7 chunks and cycle
    // diverse biomes in between.
    final villagePhase = ((chunkIndex + (worldSeed % 7)) % 7 + 7) % 7;
    if (villagePhase == 0 && chunkIndex != 0 && chunkIndex != 8) {
      return JungleBiome.nativeVillage;
    }
    const wildBiomes = [
      JungleBiome.canopyForest,
      JungleBiome.riverLagoon,
      JungleBiome.botanicalClearing,
      JungleBiome.mistHighlands,
      JungleBiome.canopyForest,
      JungleBiome.botanicalClearing,
    ];
    return wildBiomes[_hashCoords(chunkIndex, 11) % wildBiomes.length];
  }

  /// Returns the [JungleBiome] at horizontal tile coordinate [tx] (valid for
  /// any negative or positive integer [tx]).
  JungleBiome biomeAt(int tx) =>
      biomeForChunk(_InfiniteTileRow.chunkIndexOf(tx));

  /// Explorer's current biome based on [playerTileX].
  JungleBiome get currentBiome => biomeAt(playerTileX);

  double _chunkBaseElevation(int chunkIndex) {
    final biome = biomeForChunk(chunkIndex);
    final jitter = ((_hashCoords(chunkIndex, 23) % 100) / 100.0 - 0.5) * 1.6;
    return switch (biome) {
      JungleBiome.nativeVillage => 20.0,
      JungleBiome.riverLagoon => 26.8,
      JungleBiome.botanicalClearing => 20.5 + jitter * 0.4,
      JungleBiome.mistHighlands => 15.2 + jitter * 0.8,
      JungleBiome.canopyForest => 20.8 + jitter,
    };
  }

  /// Computes the deterministic surface tile Y coordinate at horizontal tile [tx].
  ///
  /// Uses smooth cosine interpolation across chunk centers so chunk boundaries
  /// meet seamlessly with zero vertical seams whether exploring West (`-X`) or
  /// East (`+X`).
  int surfaceElevationAt(int tx) {
    final chunkIdx = _InfiniteTileRow.chunkIndexOf(tx);
    final localX = _InfiniteTileRow.localIndexOf(tx);
    final biome = biomeForChunk(chunkIdx);

    // Keep the starter spawn clearing (tx = 27..30) level for immediate sowing.
    if (tx >= 27 && tx <= 30) {
      return 21;
    }

    // Keep Native Village hut foundations flat so stilt huts sit evenly.
    if (biome == JungleBiome.nativeVillage && localX >= 2 && localX <= 13) {
      return 20;
    }

    // Smoothly interpolate between neighboring chunk center elevations.
    final centerPos = chunkIdx * chunkWidth + chunkWidth * 0.5;
    final neighborIdx = tx < centerPos ? chunkIdx - 1 : chunkIdx + 1;
    final neighborCenter = neighborIdx * chunkWidth + chunkWidth * 0.5;
    final tRaw = ((tx - centerPos).abs() / (neighborCenter - centerPos).abs())
        .clamp(0.0, 1.0);
    final smoothT = (1.0 - math.cos(tRaw * math.pi)) * 0.5;

    final h0 = _chunkBaseElevation(chunkIdx);
    final h1 = _chunkBaseElevation(neighborIdx);
    double h = h0 + (h1 - h0) * smoothT;

    // Carve a deep swimmable river basin in River Lagoon chunks.
    if (biome == JungleBiome.riverLagoon && localX >= 2 && localX <= 13) {
      final riverDist = (localX - 7.5).abs();
      final basinDepth = math.max(0.0, 4.2 - riverDist * 0.65);
      h = math.max(h, waterLevel + basinDepth);
    } else if (biome != JungleBiome.nativeVillage) {
      final seedPhase = (worldSeed % 997) * 0.07;
      final detailWave =
          math.sin(tx * 0.37 + seedPhase) * 0.75 +
          math.cos(tx * 0.17 - seedPhase) * 0.55;
      h += detailWave;
    }

    return h.round().clamp(12, height - 14);
  }

  /// Ensures all chunks within [radiusChunks] of [centerTileX] are generated.
  void ensureChunksAround(int centerTileX, {int radiusChunks = 3}) {
    final centerChunk = _InfiniteTileRow.chunkIndexOf(centerTileX);
    for (
      int c = centerChunk - radiusChunks;
      c <= centerChunk + radiusChunks;
      c++
    ) {
      ensureChunkGenerated(c);
    }
  }

  /// Procedurally generates the 16-tile chunk at [chunkIndex] on the fly if it
  /// has not been generated yet.
  void ensureChunkGenerated(int chunkIndex) {
    if (!_generatedChunks.add(chunkIndex)) return;

    final chunkStart = chunkIndex * chunkWidth;
    final biome = biomeForChunk(chunkIndex);
    final chunkRng = math.Random(_hashCoords(chunkIndex, 97));
    final seedPhase = (worldSeed % 1024) * 0.05;

    final surfaceY = List<int>.generate(
      chunkWidth,
      (i) => surfaceElevationAt(chunkStart + i),
    );

    // 1. Fill terrain layers, biome soil substrates, ore veins, underground caves, and river water.
    for (int i = 0; i < chunkWidth; i++) {
      final x = chunkStart + i;
      final topY = surfaceY[i];

      // Determine the natural surface soil block for this column based on biome & microclimate.
      BlockType surfaceSoil =
          topY > waterLevel ? BlockType.riverSilt : BlockType.grass;
      BlockType subSoil = BlockType.dirt;
      if (x < 26 || x > 31) {
        if (biome == JungleBiome.riverLagoon) {
          surfaceSoil = BlockType.riverSilt;
          subSoil = BlockType.riverSilt;
        } else if (biome == JungleBiome.botanicalClearing &&
            (i <= 5 || i >= 11)) {
          surfaceSoil = BlockType.peatBog;
          subSoil = BlockType.peatBog;
        } else if (biome == JungleBiome.mistHighlands && i >= 2 && i <= 13) {
          surfaceSoil = BlockType.volcanicAsh;
          subSoil = BlockType.volcanicAsh;
        }
      }

      for (int y = topY; y < height; y++) {
        if (y == topY) {
          _setBlockRaw(x, y, surfaceSoil);
        } else if (y <= topY + 2) {
          _setBlockRaw(x, y, subSoil);
          _setWallRaw(x, y, WallType.dirtWall);
        } else if (y == topY + 3) {
          _setBlockRaw(x, y, BlockType.dirt);
          _setWallRaw(x, y, WallType.dirtWall);
        } else {
          final depth = y - topY;
          final roll = chunkRng.nextDouble();
          final ironChance = biome == JungleBiome.mistHighlands ? 0.085 : 0.055;
          final coalChance = biome == JungleBiome.mistHighlands ? 0.15 : 0.11;
          if (depth > 9 && roll < ironChance) {
            _setBlockRaw(x, y, BlockType.ironOre);
          } else if (depth > 4 && roll < coalChance) {
            _setBlockRaw(x, y, BlockType.coalOre);
          } else {
            _setBlockRaw(x, y, BlockType.stone);
          }
          _setWallRaw(x, y, WallType.dirtWall);
        }
      }

      // Carve multi-layer underground cave pockets below y = topY + 6, and line
      // cavern floors with Mossy Peat Bog or Alluvial Silt for underground gardening.
      for (int y = topY + 6; y < height - 4; y++) {
        final caveWave =
            math.sin(x * 0.19 + y * 0.31 + seedPhase) +
            math.cos(x * 0.08 - y * 0.23 - seedPhase);
        if (caveWave > 1.52) {
          _setBlockRaw(x, y, y >= height - 9 ? BlockType.water : BlockType.air);
          if (y + 1 < height - 3 && _getBlockRaw(x, y + 1) == BlockType.stone) {
            _setBlockRaw(
              x,
              y + 1,
              y >= height - 11 ? BlockType.riverSilt : BlockType.peatBog,
            );
          }
        }
      }

      // Fill surface river and lagoon basins with water up to waterLevel.
      if (topY > waterLevel) {
        for (int y = waterLevel; y < topY; y++) {
          _setBlockRaw(x, y, BlockType.water);
        }
      }
    }

    // 2. Populate biome-specific structures, wild plants, trees, and wildlife.
    switch (biome) {
      case JungleBiome.nativeVillage:
        _populateVillageChunk(chunkIndex, chunkStart, surfaceY);
      case JungleBiome.riverLagoon:
        _populateRiverLagoonChunk(chunkIndex, chunkStart, surfaceY, chunkRng);
        _buildAbyssObsidianVaultInChunk(chunkStart);
      case JungleBiome.botanicalClearing:
        _populateBotanicalClearingChunk(
          chunkIndex,
          chunkStart,
          surfaceY,
          chunkRng,
        );
      case JungleBiome.mistHighlands:
      case JungleBiome.canopyForest:
        _populateForestOrHighlandChunk(
          chunkIndex,
          chunkStart,
          surfaceY,
          biome,
          chunkRng,
        );
        if (biome == JungleBiome.mistHighlands) {
          _buildAbyssObsidianVaultInChunk(chunkStart);
        }
    }
  }

  /// Carves a subterranean Ancient Obsidian Vault deep in the Pitch-Black Abyss
  /// (`y = 38..42`) housing the `🔮 Deep Abyss Totem Shard` pedestal.
  void _buildAbyssObsidianVaultInChunk(int chunkStart) {
    const vaultTop = 38;
    const vaultBottom = 42;
    final leftX = chunkStart + 5;
    final rightX = chunkStart + 11;
    for (int y = vaultTop; y <= vaultBottom; y++) {
      for (int x = leftX; x <= rightX; x++) {
        final isBorder =
            y == vaultTop || y == vaultBottom || x == leftX || x == rightX;
        if (y == vaultBottom && x > leftX && x < rightX) {
          _setBlockRaw(x, y, BlockType.peatBog);
        } else if (isBorder) {
          _setBlockRaw(x, y, BlockType.ancientObsidian);
        } else {
          _setBlockRaw(x, y, BlockType.air);
        }
      }
    }
    _setBlockRaw(chunkStart + 8, vaultBottom - 1, BlockType.totemPedestal);
  }

  /// Builds a high-altitude Floating Sky Sanctuary (`y = 7..8`) above the
  /// forest canopy housing the `☀️ Sky Canopy Totem Shard` pedestal.
  void _buildFloatingSkySanctuaryInChunk(int centerTx) {
    const islandY = 8;
    for (int dx = -2; dx <= 2; dx++) {
      final x = centerTx + dx;
      _setBlockRaw(x, islandY, BlockType.cloudStone);
      _setBlockRaw(x, islandY - 1, BlockType.air);
      if (dx.abs() == 2) {
        // Hanging sky-vines descend to y = 12 (9 tiles above the ground at y = 21,
        // requiring a grown Mahogany Tree or vine trellis below to bridge!).
        for (int vy = islandY + 1; vy <= islandY + 4; vy++) {
          _setBlockRaw(x, vy, BlockType.vine);
        }
      }
    }
    _setBlockRaw(centerTx, islandY - 1, BlockType.totemPedestal);
  }

  void _setBlockRaw(int tx, int ty, BlockType block) {
    if (ty < 0 || ty >= height) return;
    (blocks[ty] as _InfiniteTileRow<BlockType>)._setRaw(tx, block);
  }

  BlockType _getBlockRaw(int tx, int ty) {
    if (ty < 0 || ty >= height) return BlockType.stone;
    return (blocks[ty] as _InfiniteTileRow<BlockType>)._getRaw(tx);
  }

  void _setWallRaw(int tx, int ty, WallType wall) {
    if (ty < 0 || ty >= height) return;
    (walls[ty] as _InfiniteTileRow<WallType>)._setRaw(tx, wall);
  }

  void _buildCanopyTreeInChunk({
    required int trunkX,
    required int groundY,
    required int chunkStart,
    required math.Random chunkRng,
    required bool attachBeehive,
  }) {
    final trunkHeight = 5 + chunkRng.nextInt(4);
    for (int ty = groundY - 1; ty >= groundY - trunkHeight && ty >= 2; ty--) {
      _setBlockRaw(trunkX, ty, BlockType.woodLog);
    }
    final topTreeY = (groundY - trunkHeight).clamp(3, height - 1);
    final minX = chunkStart;
    final maxX = chunkStart + chunkWidth - 1;
    for (int ly = topTreeY - 2; ly <= topTreeY + 1; ly++) {
      for (int lx = trunkX - 3; lx <= trunkX + 3; lx++) {
        if (lx >= minX &&
            lx <= maxX &&
            ly >= 1 &&
            (lx - trunkX).abs() + (ly - topTreeY).abs() <= 4) {
          if (_getBlockRaw(lx, ly) == BlockType.air) {
            _setBlockRaw(lx, ly, BlockType.leaves);
          }
        }
      }
    }
    for (final vx in [trunkX - 2, trunkX + 2]) {
      if (vx >= minX && vx <= maxX) {
        final vineLen = 2 + chunkRng.nextInt(4);
        for (
          int vy = topTreeY + 1;
          vy <= topTreeY + vineLen && vy < groundY;
          vy++
        ) {
          if (_getBlockRaw(vx, vy) == BlockType.air) {
            _setBlockRaw(vx, vy, BlockType.vine);
          }
        }
      }
    }

    if (attachBeehive) {
      final hiveX = (trunkX + 1).clamp(minX, maxX);
      final hiveY = (topTreeY + 2).clamp(3, groundY - 2);
      _setBlockRaw(hiveX, hiveY, BlockType.beehive);
      animals.add(
        JungleAnimal(
          type: AnimalType.beeSwarm,
          x: hiveX * tileSize + tileSize * 0.5,
          y: hiveY * tileSize + tileSize * 0.5,
          homeX: hiveX * tileSize + tileSize * 0.5,
          homeY: hiveY * tileSize + tileSize * 0.5,
        ),
      );
    }
  }

  void _spawnWildCropInChunk(
    int tx,
    int groundY,
    ItemType seedType, {
    double growthProgress = 0.85,
  }) {
    if (groundY <= 2 || groundY >= height) return;
    final groundBlock = _getBlockRaw(tx, groundY);
    final soil = groundBlock.soilType;
    if (soil == null) {
      return;
    }
    final cropY = groundY - 1;
    if (_getBlockRaw(tx, cropY) != BlockType.air) return;
    final key = '$tx,$cropY';
    if (crops.containsKey(key)) return;

    if (groundBlock == BlockType.grass || groundBlock == BlockType.dirt) {
      _setBlockRaw(tx, groundY, BlockType.tilledSoil);
    }
    crops[key] = CropPlot(
      tileX: tx,
      tileY: cropY,
      seedType: seedType,
      soilType: soil,
      lastHabitatMultiplier: soil.soilMultiplierFor(seedType),
      growthProgress: growthProgress,
      isFertilized: true,
    );
  }

  void _populateVillageChunk(
    int chunkIndex,
    int chunkStart,
    List<int> surfaceY,
  ) {
    final startX = chunkStart + 3;
    const hutWidth = 9;
    const hutHeight = 5;
    final floorY = surfaceY[7];
    final roofY = floorY - hutHeight;

    for (int dx = 0; dx < hutWidth; dx++) {
      final wx = startX + dx;
      _setBlockRaw(wx, floorY, BlockType.villageHutBlock);
      for (int sy = floorY + 1; sy <= floorY + 3 && sy < height; sy++) {
        if (dx == 0 || dx == hutWidth - 1) {
          _setBlockRaw(wx, sy, BlockType.woodPlank);
        }
      }
      _setBlockRaw(wx, roofY, BlockType.thatchRoof);
      if (dx >= 1 && dx <= hutWidth - 2) {
        _setBlockRaw(wx, roofY - 1, BlockType.thatchRoof);
      }
      for (int iy = roofY + 1; iy < floorY; iy++) {
        _setBlockRaw(wx, iy, BlockType.air);
        _setWallRaw(wx, iy, WallType.villageWall);
      }
    }

    for (int iy = roofY + 1; iy < floorY; iy++) {
      if (iy >= floorY - 2) {
        _setBlockRaw(startX, iy, BlockType.doorOpen);
        _setBlockRaw(startX + hutWidth - 1, iy, BlockType.doorOpen);
      } else {
        _setBlockRaw(startX, iy, BlockType.villageHutBlock);
        _setBlockRaw(startX + hutWidth - 1, iy, BlockType.villageHutBlock);
      }
    }

    _setBlockRaw(startX + 2, floorY - 1, BlockType.campfire);
    _setBlockRaw(startX + 4, floorY - 3, BlockType.torch);

    // Plant tended village garden crops beside the stilt hut!
    _spawnWildCropInChunk(
      chunkStart + 1,
      surfaceY[1],
      ItemType.bananaSeeds,
      growthProgress: 1.0,
    );
    _spawnWildCropInChunk(
      chunkStart + 14,
      surfaceY[14],
      ItemType.healingHerbSeeds,
      growthProgress: 0.9,
    );

    const archetypes = [
      (
        'Kaelo',
        'Sun-Canopy Botanist',
        'Welcome, explorer! Sow diverse seeds and watch how bees, monkeys, and toucans interact with your garden!',
        [
          VillageTrade(
            costItem: ItemType.jungleBerry,
            costCount: 3,
            rewardItem: ItemType.bananaSeeds,
            rewardCount: 3,
            note:
                'Sow Banana Seeds to grow bananas & befriend Capuchin Monkeys!',
          ),
          VillageTrade(
            costItem: ItemType.honeycomb,
            costCount: 2,
            rewardItem: ItemType.mangoSeeds,
            rewardCount: 3,
            note: 'Villagers prize sweet Honeycomb! Get 3 Golden Mango Seeds.',
          ),
          VillageTrade(
            costItem: ItemType.banana,
            costCount: 2,
            rewardItem: ItemType.pitcherPlantSeeds,
            rewardCount: 2,
            note:
                'Carnivorous Pitcher Seeds that trap snakes & fertilize adjacent crops!',
          ),
          VillageTrade(
            costItem: ItemType.jungleBerry,
            costCount: 3,
            rewardItem: ItemType.glowBulbSeeds,
            rewardCount: 3,
            note:
                'Bioluminescent Glow-Bulb Spores that shine at night and calm bees.',
          ),
          VillageTrade(
            costItem: ItemType.banana,
            costCount: 4,
            rewardItem: ItemType.warmPoncho,
            rewardCount: 1,
            note: 'Hand-woven Jungle Poncho that halves night cold heat loss.',
          ),
        ],
      ),
      (
        'Yara',
        'River & Forge Artisan',
        'Plant Medicinal Herbs to repel snakes and Briar Thorns to guard against jaguars!',
        [
          VillageTrade(
            costItem: ItemType.cookedFish,
            costCount: 2,
            rewardItem: ItemType.ironMachete,
            rewardCount: 1,
            note: 'Razor-sharp Iron Machete (38 melee damage, fast chopping).',
          ),
          VillageTrade(
            costItem: ItemType.honeycomb,
            costCount: 2,
            rewardItem: ItemType.ironMachete,
            rewardCount: 1,
            note: 'Trade 2 Golden Honeycombs for a forged Iron Machete!',
          ),
          VillageTrade(
            costItem: ItemType.jungleBerry,
            costCount: 2,
            rewardItem: ItemType.healingHerbSeeds,
            rewardCount: 3,
            note: 'Medicinal Herb Seeds that ward off Emerald Vipers!',
          ),
          VillageTrade(
            costItem: ItemType.vineFiber,
            costCount: 3,
            rewardItem: ItemType.thornVineSeeds,
            rewardCount: 3,
            note: 'Spiky Briar Thorn Seeds that prick & knock back predators!',
          ),
          VillageTrade(
            costItem: ItemType.rawFish,
            costCount: 2,
            rewardItem: ItemType.campfireItem,
            rewardCount: 1,
            note: 'Ready-to-place Campfire for heating your shelter.',
          ),
        ],
      ),
      (
        'Tupã',
        'Mist Highland Herbalist',
        'Highland crags hold rich iron ore, and our Mahogany Saplings grow into towering bee trees!',
        [
          VillageTrade(
            costItem: ItemType.mango,
            costCount: 2,
            rewardItem: ItemType.mahoganySapling,
            rewardCount: 2,
            note:
                'Plant Mahogany Saplings to grow full canopy trees & beehives!',
          ),
          VillageTrade(
            costItem: ItemType.glowFruit,
            costCount: 2,
            rewardItem: ItemType.pitcherPlantSeeds,
            rewardCount: 3,
            note: 'Carnivorous Pitcher Seeds bred from highland mist flora.',
          ),
          VillageTrade(
            costItem: ItemType.jungleBerry,
            costCount: 3,
            rewardItem: ItemType.papaya,
            rewardCount: 2,
            note: 'Fresh Jungle Papayas (+36 Hunger, +14 Health).',
          ),
          VillageTrade(
            costItem: ItemType.jungleBerry,
            costCount: 2,
            rewardItem: ItemType.torchItem,
            rewardCount: 6,
            note:
                'Bundle of resin torches for caves, warmth, and calming bees.',
          ),
        ],
      ),
      (
        'Moema',
        'Lagoon Apiarist & Seedkeeper',
        'Feed fruit to Toucans and Capuchin Monkeys—they will sow rare seeds and help harvest your crops!',
        [
          VillageTrade(
            costItem: ItemType.honeycomb,
            costCount: 1,
            rewardItem: ItemType.glowBulbSeeds,
            rewardCount: 3,
            note: 'Glow-Bulb Spores that calm bees and speed up river fishing!',
          ),
          VillageTrade(
            costItem: ItemType.banana,
            costCount: 2,
            rewardItem: ItemType.mangoSeeds,
            rewardCount: 2,
            note: 'Sweet Golden Mango Seeds favored by Rainbow Toucans.',
          ),
          VillageTrade(
            costItem: ItemType.mango,
            costCount: 2,
            rewardItem: ItemType.healingHerb,
            rewardCount: 3,
            note: 'Medicinal Jungle Poultice (+40 Life Points).',
          ),
        ],
      ),
    ];

    final archetypeIndex =
        chunkIndex == 2
            ? 0
            : (chunkIndex == 7
                ? 1
                : (_hashCoords(chunkIndex, 41) % archetypes.length));
    final (name, role, greeting, trades) = archetypes[archetypeIndex];
    villagers.add(
      NativeVillager(
        name: name,
        role: role,
        x: (startX + 5) * tileSize + tileSize * 0.5,
        y: (floorY - 1) * tileSize,
        greeting: greeting,
        trades: trades,
      ),
    );
  }

  void _populateRiverLagoonChunk(
    int chunkIndex,
    int chunkStart,
    List<int> surfaceY,
    math.Random chunkRng,
  ) {
    // Spawn a pair of piranhas actively patrolling the river basin in opposite
    // directions and at different depths.
    animals.addAll([
      JungleAnimal(
        type: AnimalType.piranha,
        x: (chunkStart + 5) * tileSize + tileSize * 0.5,
        y: (waterLevel + 1) * tileSize + 8.0,
        facingRight: true,
        homeX: (chunkStart + 5) * tileSize,
        homeY: (waterLevel + 1) * tileSize + 8.0,
      )..patrolTimer = 4.5,
      JungleAnimal(
        type: AnimalType.piranha,
        x: (chunkStart + 10) * tileSize + tileSize * 0.5,
        y: (waterLevel + 2) * tileSize + 6.0,
        facingRight: false,
        homeX: (chunkStart + 10) * tileSize,
        homeY: (waterLevel + 2) * tileSize + 6.0,
      )..patrolTimer = 5.5,
    ]);

    // Plant riverside glow-bulbs or pitcher plants on the banks.
    for (final bankOffset in const [1, 14]) {
      final bx = chunkStart + bankOffset;
      final by = surfaceY[bankOffset];
      if (by <= waterLevel) {
        final bankSeed =
            bankOffset == 1
                ? ItemType.glowBulbSeeds
                : ItemType.pitcherPlantSeeds;
        _spawnWildCropInChunk(bx, by, bankSeed, growthProgress: 0.78);
      }
    }

    if (chunkRng.nextDouble() < 0.65) {
      animals.add(
        JungleAnimal(
          type: AnimalType.toucan,
          x: (chunkStart + 4) * tileSize,
          y: (waterLevel - 5) * tileSize,
          homeX: (chunkStart + 4) * tileSize,
          homeY: (waterLevel - 5) * tileSize,
        ),
      );
    }
  }

  void _populateBotanicalClearingChunk(
    int chunkIndex,
    int chunkStart,
    List<int> surfaceY,
    math.Random chunkRng,
  ) {
    // One canopy tree on the left side with a wild beehive to pollinate the clearing.
    if (_getBlockRaw(chunkStart + 4, surfaceY[4]).isSowableSoil) {
      _buildCanopyTreeInChunk(
        trunkX: chunkStart + 4,
        groundY: surfaceY[4],
        chunkStart: chunkStart,
        chunkRng: chunkRng,
        attachBeehive: true,
      );
    }

    // Build the Venom Marsh Altar in the center of the clearing (localX = 7..9):
    // a Mossy Peat Bog platform holding the `🐍 Venom Marsh Totem Shard` pedestal,
    // guarded by venomous Emerald Vipers and Toxic Marsh Miasma!
    final altarY = surfaceY[8];
    for (int dx = -1; dx <= 1; dx++) {
      final ax = chunkStart + 8 + dx;
      _setBlockRaw(ax, altarY, BlockType.peatBog);
      _setBlockRaw(ax, altarY - 1, BlockType.air);
    }
    _setBlockRaw(chunkStart + 8, altarY - 1, BlockType.totemPedestal);
    animals.addAll([
      JungleAnimal(
        type: AnimalType.snake,
        x: (chunkStart + 7) * tileSize + tileSize * 0.5,
        y: altarY * tileSize,
        facingRight: false,
      ),
      JungleAnimal(
        type: AnimalType.snake,
        x: (chunkStart + 9) * tileSize + tileSize * 0.5,
        y: altarY * tileSize,
        facingRight: true,
      ),
    ]);

    // Spawn wild botanical crops across the outer clearing edges.
    const clearingSeeds = [
      ItemType.bananaSeeds,
      ItemType.mangoSeeds,
      ItemType.healingHerbSeeds,
      ItemType.glowBulbSeeds,
      ItemType.thornVineSeeds,
      ItemType.pitcherPlantSeeds,
      ItemType.berrySeeds,
    ];
    for (final offset in const [2, 12, 14]) {
      final tx = chunkStart + offset;
      final gy = surfaceY[offset];
      final seed =
          clearingSeeds[(_hashCoords(chunkIndex, offset) + offset) %
              clearingSeeds.length];
      _spawnWildCropInChunk(
        tx,
        gy,
        seed,
        growthProgress: 0.65 + chunkRng.nextDouble() * 0.35,
      );
    }

    // Spawn a Capuchin Monkey and Rainbow Toucan in the botanical grove.
    animals.add(
      JungleAnimal(
        type: AnimalType.capuchinMonkey,
        x: (chunkStart + 5) * tileSize,
        y: (surfaceY[5] - 1) * tileSize,
        homeX: (chunkStart + 5) * tileSize,
        homeY: (surfaceY[5] - 1) * tileSize,
      ),
    );
    animals.add(
      JungleAnimal(
        type: AnimalType.toucan,
        x: (chunkStart + 11) * tileSize,
        y: (surfaceY[11] - 6) * tileSize,
        homeX: (chunkStart + 11) * tileSize,
        homeY: (surfaceY[11] - 6) * tileSize,
      ),
    );
  }

  void _populateForestOrHighlandChunk(
    int chunkIndex,
    int chunkStart,
    List<int> surfaceY,
    JungleBiome biome,
    math.Random chunkRng,
  ) {
    for (final localX in const [4, 11]) {
      final tx = chunkStart + localX;
      // Leave the immediate starter spawn clearing (tx = 26..31) open.
      if (tx >= 26 && tx <= 31) continue;
      final gy = surfaceY[localX];
      if (_getBlockRaw(tx, gy).isSowableSoil &&
          (chunkIndex == 1 || chunkRng.nextDouble() < 0.82)) {
        final attachHive =
            chunkIndex == 1 || (localX == 4 && chunkRng.nextDouble() < 0.45);
        _buildCanopyTreeInChunk(
          trunkX: tx,
          groundY: gy,
          chunkStart: chunkStart,
          chunkRng: chunkRng,
          attachBeehive: attachHive,
        );
      }
    }

    // Scatter wild berry bushes and occasional wild herb/briar sprouts.
    for (int localX = 1; localX < chunkWidth - 1; localX++) {
      final tx = chunkStart + localX;
      if (tx >= 27 && tx <= 31) continue;
      final gy = surfaceY[localX];
      if (!_getBlockRaw(tx, gy).isSowableSoil ||
          _getBlockRaw(tx, gy - 1) != BlockType.air) {
        continue;
      }
      final roll = chunkRng.nextDouble();
      if (roll < 0.18) {
        _setBlockRaw(tx, gy - 1, BlockType.berryBush);
      } else if (roll < 0.24) {
        final wildSeed =
            biome == JungleBiome.mistHighlands
                ? ItemType.thornVineSeeds
                : ItemType.healingHerbSeeds;
        _spawnWildCropInChunk(tx, gy, wildSeed, growthProgress: 0.75);
      }
    }

    // In the starter valley (chunkIndex == 1), erect the Ancient Jungle Shrine
    // right beside the spawn clearing (tx = 31) and a Floating Sky Sanctuary
    // high overhead (tx = 22, y = 7..8)!
    if (chunkIndex == 1) {
      final shrineY = surfaceY[15];
      _setBlockRaw(31, shrineY, BlockType.cloudStone);
      _setBlockRaw(31, shrineY - 1, BlockType.jungleShrine);
      _buildFloatingSkySanctuaryInChunk(chunkStart + 6);

      animals.addAll([
        JungleAnimal(
          type: AnimalType.capuchinMonkey,
          x: (chunkStart + 9) * tileSize,
          y: (surfaceY[9] - 1) * tileSize,
          homeX: (chunkStart + 9) * tileSize,
          homeY: (surfaceY[9] - 1) * tileSize,
        ),
        JungleAnimal(
          type: AnimalType.toucan,
          x: (chunkStart + 14) * tileSize,
          y: (surfaceY[14] - 6) * tileSize,
          homeX: (chunkStart + 14) * tileSize,
          homeY: (surfaceY[14] - 6) * tileSize,
        ),
      ]);
    } else {
      if (biome == JungleBiome.mistHighlands) {
        _buildFloatingSkySanctuaryInChunk(chunkStart + 8);
      }
      final animalRoll = chunkRng.nextDouble();
      final spawnX = (chunkStart + 7) * tileSize;
      final spawnY = (surfaceY[7] - 1) * tileSize;
      if (animalRoll < 0.32) {
        animals.add(JungleAnimal(type: AnimalType.snake, x: spawnX, y: spawnY));
      } else if (animalRoll < 0.58) {
        animals.add(
          JungleAnimal(type: AnimalType.jaguar, x: spawnX, y: spawnY),
        );
      } else if (animalRoll < 0.80) {
        animals.add(
          JungleAnimal(
            type: AnimalType.capuchinMonkey,
            x: spawnX,
            y: spawnY,
            homeX: spawnX,
            homeY: spawnY,
          ),
        );
      } else {
        animals.add(
          JungleAnimal(
            type: AnimalType.toucan,
            x: spawnX,
            y: spawnY - 5 * tileSize,
            homeX: spawnX,
            homeY: spawnY - 5 * tileSize,
          ),
        );
      }
    }
  }

  /// Active planted crops indexed by `'x,y'` coordinate key.
  final Map<String, CropPlot> crops = {};

  /// Distinct seed varieties sowed by the explorer so far.
  final Set<ItemType> sowedSeedVarieties = {};

  /// Ancient Totem Shards (`☀️ Sky`, `🐍 Marsh`, `🔮 Abyss`) socketed into the
  /// [BlockType.jungleShrine].
  final Set<ItemType> socketedTotemShards = {};

  /// Vertical tile threshold where the subterranean Pitch-Black Abyss begins.
  static const int abyssDepthY = 31;

  /// Whether all 3 Ancient Totem Shards have been socketed into the Shrine.
  bool get shrineAwakened =>
      socketedTotemShards.length >= ItemType.allTotemShards.length;

  /// Whether the `☀️ Sky Canopy Totem Shard` is socketed in the Shrine.
  bool get skyBlessingActive =>
      socketedTotemShards.contains(ItemType.skyTotemShard);

  /// Whether the `🐍 Venom Marsh Totem Shard` is socketed in the Shrine.
  bool get marshBlessingActive =>
      socketedTotemShards.contains(ItemType.marshTotemShard);

  /// Whether the `🔮 Deep Abyss Totem Shard` is socketed in the Shrine.
  bool get abyssBlessingActive =>
      socketedTotemShards.contains(ItemType.abyssTotemShard);

  /// Number of distinct Totem Shards either socketed or carried in inventory.
  int get discoveredTotemShardCount =>
      ItemType.allTotemShards
          .where(
            (s) => socketedTotemShards.contains(s) || (inventory[s] ?? 0) > 0,
          )
          .length;

  /// Remaining burn ticks per `'x,y'` coordinate for [BlockType.wildfire].
  final Map<String, int> _fireBurnTicks = {};

  /// Inventory quantities owned by the explorer.
  final Map<ItemType, int> inventory = {};

  /// Ordered hotbar slots for quick selection.
  final List<ItemType> hotbar = [
    ItemType.woodPickaxe,
    ItemType.woodSpear,
    ItemType.torchItem,
    ItemType.waterBucket,
    ItemType.berrySeeds,
    ItemType.healingHerbSeeds,
    ItemType.thornVineSeeds,
    ItemType.glowBulbSeeds,
    ItemType.banana,
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
      'Sow 8 seed varieties (🌱🌾✨🌿💡🌵🌺🌳), watch 🐝 Bees & 🦜 Toucans pollinate, and feed 🐒 Monkeys bananas!';

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

  /// Whether procedural Web Audio / sound synthesis is enabled.
  bool soundEnabled = true;

  /// Queued spatial sound events to be played by [JungleSoundscape].
  final List<SoundEvent> pendingSoundEvents = [];

  /// Most recently triggered discrete [SoundEvent] for HUD visualization.
  SoundEvent? lastSoundEvent;

  /// Remaining display seconds for [lastSoundEvent] in the HUD.
  double lastSoundTimer = 0.0;

  /// Current continuous spatial bee-buzz proximity intensity (`0.0..1.0`).
  double beeBuzzIntensity = 0.0;

  /// Whether the nearest audible bee swarm is currently angry/chasing.
  bool beeBuzzAngry = false;

  /// Stereo pan (`-1.0..1.0`) toward the nearest audible bee swarm or hive.
  double beeBuzzPan = 0.0;

  /// Emits a spatial stereo [SoundCue] originating at ([worldX], [worldY])
  /// relative to the explorer's head/ears (`(playerX, playerY - 16)`).
  void emitSound(
    SoundCue cue, {
    double? worldX,
    double? worldY,
    double baseVolume = 0.85,
  }) {
    double gain = baseVolume;
    double pan = 0.0;
    if (worldX != null && worldY != null) {
      final dx = worldX - playerX;
      final dy = worldY - (playerY - 16.0);
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist > 460.0) return;
      // Smooth inverse-distance falloff + full left/right stereo panning.
      final normDist = dist / 180.0;
      gain = (baseVolume / (1.0 + normDist * normDist * 0.85)).clamp(0.08, 1.0);
      pan = (dx / 180.0).clamp(-1.0, 1.0);
    }
    final event = SoundEvent(cue: cue, volume: gain, pan: pan);
    pendingSoundEvents.add(event);
    lastSoundEvent = event;
    lastSoundTimer = 2.4;
  }

  // Completed explorer milestone flags.
  /// Whether the explorer has gathered wild seeds.
  bool milestoneGatheredSeeds = false;

  /// Whether the explorer has sowed seeds on tilled soil.
  bool milestoneSowedCrop = false;

  /// Whether the explorer has harvested ripe fruit from a crop.
  bool milestoneHarvestedFruit = false;

  /// Whether the explorer has harvested golden honeycomb from a beehive.
  bool milestoneHarvestedHoney = false;

  /// Whether the explorer has stood inside a completed warm shelter.
  bool milestoneBuiltShelter = false;

  /// Whether the explorer has caught a river fish.
  bool milestoneCaughtFish = false;

  /// Whether the explorer has traded fruits with a native villager.
  bool milestoneTradedWithNatives = false;

  /// Whether the explorer has defeated a dangerous jungle predator.
  bool milestoneDefeatedPredator = false;

  /// Whether a plant and animal have actively interacted (pollination, herbal
  /// snake repulsion, briar defense, pitcher trap, or seed dispersal).
  bool milestonePlantAnimalInteraction = false;

  /// Whether the explorer has befriended a [AnimalType.capuchinMonkey] with fruit.
  bool milestoneBefriendedMonkey = false;

  final math.Random _rng;
  double _animalSpawnTimer = 14.0;
  double _weatherTimer = 35.0;
  double _physicsTickAccumulator = 0.0;

  /// Currently selected item in the explorer's hotbar.
  ItemType get equippedItem => hotbar[selectedHotbarIndex];

  /// Explorer's current horizontal tile coordinate (unbounded West/East).
  int get playerTileX => pixelToTile(playerX);

  /// Explorer's current vertical tile coordinate (at torso height).
  int get playerTileY => pixelToTile(playerY - 14.0).clamp(0, height - 1);

  /// Whether it is currently night in the jungle.
  bool get isNight => timeOfDay < 0.22 || timeOfDay > 0.76;

  /// Whether the explorer carries a [ItemType.warmPoncho] in their inventory.
  bool get hasWarmPoncho => (inventory[ItemType.warmPoncho] ?? 0) > 0;

  /// Returns the [BlockType] at grid coordinates ([tx], [ty]), or
  /// [BlockType.stone] if vertically out of bounds.
  ///
  /// Automatically generates the horizontal chunk containing [tx] on demand.
  BlockType getBlock(int tx, int ty) {
    if (ty < 0 || ty >= height) {
      return BlockType.stone;
    }
    return blocks[ty][tx];
  }

  /// Returns the [WallType] at grid coordinates ([tx], [ty]), or
  /// [WallType.none] if vertically out of bounds.
  ///
  /// Automatically generates the horizontal chunk containing [tx] on demand.
  WallType getWall(int tx, int ty) {
    if (ty < 0 || ty >= height) {
      return WallType.none;
    }
    return walls[ty][tx];
  }

  /// Cycles the active seed selection across all owned seed varieties in
  /// [ItemType.allSeedVarieties] and places the chosen seed into the hotbar.
  ItemType? cycleEquippedSeed() {
    final ownedSeeds =
        ItemType.allSeedVarieties
            .where((seed) => (inventory[seed] ?? 0) > 0)
            .toList();
    if (ownedSeeds.isEmpty) {
      setBanner('No seeds in your pack! Harvest bushes, grass, or vines.');
      return null;
    }

    final current = equippedItem;
    final currentIndex = ownedSeeds.indexOf(current);
    final nextSeed =
        currentIndex >= 0
            ? ownedSeeds[(currentIndex + 1) % ownedSeeds.length]
            : ownedSeeds.first;

    final existingSlot = hotbar.indexOf(nextSeed);
    if (existingSlot >= 0) {
      selectedHotbarIndex = existingSlot;
    } else {
      final replaceSlot =
          equippedItem.category == ItemCategory.seed ? selectedHotbarIndex : 4;
      hotbar[replaceSlot] = nextSeed;
      selectedHotbarIndex = replaceSlot;
    }

    setBanner(
      'Selected ${nextSeed.icon} ${nextSeed.label} (x${inventory[nextSeed] ?? 0}) — ${nextSeed.ecologyNote ?? ""}',
    );
    return nextSeed;
  }

  /// Equips [seedType] in the explorer's hotbar so it can be sowed immediately.
  void equipSeedVariety(ItemType seedType) {
    if (seedType.category != ItemCategory.seed) return;
    final existingSlot = hotbar.indexOf(seedType);
    if (existingSlot >= 0) {
      selectedHotbarIndex = existingSlot;
    } else {
      final replaceSlot =
          equippedItem.category == ItemCategory.seed ? selectedHotbarIndex : 4;
      hotbar[replaceSlot] = seedType;
      selectedHotbarIndex = replaceSlot;
    }
    setBanner(
      'Equipped ${seedType.icon} ${seedType.label} (x${inventory[seedType] ?? 0}). Tap any grass or dirt tile to sow!',
    );
  }

  /// Returns whether the tile at ([tx], [ty]) is sheltered from falling rain
  /// by an overhead roof/solid block (`countsAsRoof`) or an enclosing
  /// background wall (`providesInsulation`).
  bool isTileShelteredFromRain(int tx, int ty) {
    if (ty < 0 || ty >= height) return true;
    if (getBlock(tx, ty).countsAsRoof) return true;
    if (getWall(tx, ty).providesInsulation) return true;
    for (int y = ty - 1; y >= 0 && y >= ty - 14; y--) {
      if (getBlock(tx, y).countsAsRoof) return true;
    }
    return false;
  }

  /// Evaluates whether the tile ([tx], [ty]) is inside an insulated shelter
  /// and near heat sources (including bioluminescent glow-bulbs).
  ///
  /// Runs in $O(R^2)$ time where $R \le 8$ is the local room scan radius.
  ///
  /// {@example example/world_simulation_example.dart}
  ShelterEvaluation evaluateShelterStatus(int tx, int ty) {
    bool hasRoof = false;
    for (int dy = 1; dy <= 8; dy++) {
      if (getBlock(tx, ty - dy).countsAsRoof) {
        hasRoof = true;
        break;
      }
    }

    final centerWall = getWall(tx, ty);
    final aboveWall = getWall(tx, ty - 1);
    final hasBgWalls =
        centerWall.providesInsulation && aboveWall.providesInsulation;

    bool leftWall = false;
    bool rightWall = false;
    for (int dx = 1; dx <= 6; dx++) {
      final lb = getBlock(tx - dx, ty - 1);
      if (lb.isSolid || lb == BlockType.doorClosed) leftWall = true;
      final rb = getBlock(tx + dx, ty - 1);
      if (rb.isSolid || rb == BlockType.doorClosed) rightWall = true;
    }
    final hasSideEnclosure = leftWall && rightWall;

    bool nearCampfire = false;
    bool nearTorch = false;
    bool nearGlowBulb = false;
    for (int dy = -4; dy <= 4; dy++) {
      for (int dx = -5; dx <= 5; dx++) {
        final cx = tx + dx;
        final cy = ty + dy;
        final b = getBlock(cx, cy);
        if (b == BlockType.campfire || b == BlockType.wildfire) {
          nearCampfire = true;
        }
        if (b == BlockType.torch) nearTorch = true;
        if (crops['$cx,$cy'] case final crop?
            when crop.seedType == ItemType.glowBulbSeeds &&
                crop.growthProgress >= 0.33) {
          nearGlowBulb = true;
        }
      }
    }

    final dayWave = math.sin((timeOfDay - 0.2) * math.pi / 0.56);
    double temp = 16.0 + 13.0 * dayWave;
    if (isRaining) temp -= 4.5;
    if (hasRoof && (hasBgWalls || hasSideEnclosure)) {
      temp += 9.0;
    }
    if (nearCampfire) temp += 12.0;
    if (nearTorch) temp += 3.5;
    if (nearGlowBulb) temp += 2.5;

    return ShelterEvaluation(
      hasRoof: hasRoof,
      hasBackgroundWalls: hasBgWalls,
      hasSideEnclosure: hasSideEnclosure,
      nearCampfire: nearCampfire,
      nearTorch: nearTorch || nearGlowBulb,
      ambientTemperatureCelsius: temp,
    );
  }

  /// Returns the nearest [NativeVillager] within interaction range (115 pixels),
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
    if (item == ItemType.honeycomb) {
      milestoneHarvestedHoney = true;
    }
    if (!hotbar.contains(item) && hotbar.length < 10) {
      hotbar.add(item);
    }
  }

  /// Consumes one unit of [specificFood] (or the first edible food/honey in the
  /// inventory) to restore hunger, health, and warmth.
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
      setBanner('No edible fruit, honey, or cooked fish in your pack!');
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

  /// Feeds a nearby wild [AnimalType.capuchinMonkey] or [AnimalType.toucan]
  /// using fruit from the explorer's inventory, befriending monkeys into
  /// crop-harvesting helpers and inspiring toucans to drop rare seeds.
  bool feedNearbyWildlife([JungleAnimal? specificAnimal]) {
    JungleAnimal? targetAnimal = specificAnimal;
    if (targetAnimal == null) {
      double bestDistance = 95.0;
      for (final animal in animals) {
        if (animal.type == AnimalType.capuchinMonkey ||
            animal.type == AnimalType.toucan) {
          final distance = math.sqrt(
            math.pow(animal.x - playerX, 2) +
                math.pow(animal.y - (playerY - 14.0), 2),
          );
          if (distance <= bestDistance) {
            bestDistance = distance;
            targetAnimal = animal;
          }
        }
      }
    }
    if (targetAnimal == null) return false;

    const fruitOptions = [
      ItemType.banana,
      ItemType.jungleBerry,
      ItemType.mango,
      ItemType.papaya,
      ItemType.glowFruit,
    ];
    ItemType? chosenFruit =
        fruitOptions.contains(equippedItem) &&
                (inventory[equippedItem] ?? 0) > 0
            ? equippedItem
            : fruitOptions.where((f) => (inventory[f] ?? 0) > 0).firstOrNull;

    if (chosenFruit == null) {
      setBanner(
        'Hold or carry 🍌 Bananas or 🫐 Berries to feed the ${targetAnimal.type.label}!',
      );
      return false;
    }

    inventory[chosenFruit] = inventory[chosenFruit]! - 1;
    milestonePlantAnimalInteraction = true;

    if (targetAnimal.type == AnimalType.capuchinMonkey) {
      targetAnimal.isTamed = true;
      targetAnimal.homeX = playerX;
      targetAnimal.homeY = playerY;
      targetAnimal.interactionTimer = 1.0;
      targetAnimal.showBadge('💚 Helper!', duration: 4.0);
      milestoneBefriendedMonkey = true;
      emitSound(
        SoundCue.monkeyChatter,
        worldX: targetAnimal.x,
        worldY: targetAnimal.y,
      );
      setBanner(
        '🐒 Fed ${chosenFruit.icon} ${chosenFruit.label} to Capuchin Monkey! It is now your farm helper & will harvest ripe crops!',
      );
    } else if (targetAnimal.type == AnimalType.toucan) {
      const rareSeeds = [
        ItemType.mangoSeeds,
        ItemType.pitcherPlantSeeds,
        ItemType.glowBulbSeeds,
        ItemType.healingHerbSeeds,
        ItemType.mahoganySapling,
      ];
      final giftedSeed = rareSeeds[_rng.nextInt(rareSeeds.length)];
      addItem(giftedSeed, 2);
      targetAnimal.carriedSeed = giftedSeed;
      targetAnimal.interactionTimer = 0.0;
      targetAnimal.showBadge(
        '🍌 Ate & Gifted ${giftedSeed.icon}!',
        duration: 3.5,
      );
      emitSound(
        SoundCue.toucanScream,
        worldX: targetAnimal.x,
        worldY: targetAnimal.y,
      );
      setBanner(
        '🦜 Fed ${chosenFruit.icon} to Rainbow Toucan! It let out a happy scream, gifted 2x ${giftedSeed.icon} ${giftedSeed.label}, and flew off to sow!',
      );
    }
    return true;
  }

  /// Evaluates the soil substrate and local microclimate at tile ([tx], [ty]),
  /// where [ty] is the air tile occupied by a plant (or player torso) and
  /// `ty + 1` is the ground block underneath.
  MicroclimateProfile evaluateMicroclimate(int tx, int ty) {
    final belowSoil = getBlock(tx, ty + 1).soilType;
    final currentSoil = getBlock(tx, ty).soilType;
    final soil = belowSoil ?? currentSoil ?? SoilType.jungleLoam;
    final biome = biomeAt(tx);

    final isHumid = _isWaterNearby(tx, ty + 1) || isRaining;

    bool isShaded = false;
    for (int dy = 1; dy <= 9; dy++) {
      final above = getBlock(tx, ty - dy);
      if (above == BlockType.leaves ||
          above == BlockType.stone ||
          above == BlockType.dirt ||
          above == BlockType.peatBog ||
          above == BlockType.riverSilt ||
          above == BlockType.volcanicAsh) {
        isShaded = true;
        break;
      }
    }

    final isHighAltitude = ty <= 17 || biome == JungleBiome.mistHighlands;

    bool warmedByFire = false;
    for (int dy = -3; dy <= 3 && !warmedByFire; dy++) {
      for (int dx = -4; dx <= 4; dx++) {
        final b = getBlock(tx + dx, ty + dy);
        if (b == BlockType.campfire || b == BlockType.torch) {
          warmedByFire = true;
          break;
        }
      }
    }

    return MicroclimateProfile(
      soilType: soil,
      biome: biome,
      isHumidRiverbank: isHumid,
      isShadedCanopyOrCave: isShaded,
      isHighAltitude: isHighAltitude,
      isWarmedByFire: warmedByFire,
    );
  }

  /// Sows [explicitSeed] (or the currently equipped seed / first available seed
  /// in inventory) at or near tile coordinates ([tx], [ty]).
  ///
  /// Supports all 4 [SoilType] substrates (`Jungle Loam`, `Alluvial River Silt`,
  /// `Mossy Peat Bog`, and `Volcanic Highland Ash`), evaluates the local
  /// [MicroclimateProfile], and applies adjacent [ItemType.pitcherPlantSeeds]
  /// fertilization if present.
  ///
  /// {@example example/world_simulation_example.dart}
  bool sowSeedAt(int tx, int ty, [ItemType? explicitSeed]) {
    ItemType? seed =
        explicitSeed != null &&
                explicitSeed.category == ItemCategory.seed &&
                (inventory[explicitSeed] ?? 0) > 0
            ? explicitSeed
            : null;
    seed ??=
        equippedItem.category == ItemCategory.seed &&
                (inventory[equippedItem] ?? 0) > 0
            ? equippedItem
            : null;
    seed ??=
        ItemType.allSeedVarieties
            .where((s) => (inventory[s] ?? 0) > 0)
            .firstOrNull;

    if (seed == null) {
      setBanner('You need seeds (🌱) to sow! Gather wild bushes or trade.');
      return false;
    }

    int soilY = ty;
    if (getBlock(tx, ty) == BlockType.air) {
      soilY = ty + 1;
    }
    final ground = getBlock(tx, soilY);
    final above = getBlock(tx, soilY - 1);
    final soilType = ground.soilType;
    if (soilType == null || above != BlockType.air) {
      setBanner(
        'Sow seeds on Loam, River Silt, Peat Bog, or Volcanic Ash with open space above.',
      );
      return false;
    }

    final cropY = soilY - 1;
    final key = '$tx,$cropY';
    if (crops.containsKey(key)) {
      setBanner('A crop is already growing on that plot!');
      return false;
    }

    if (ground == BlockType.grass || ground == BlockType.dirt) {
      blocks[soilY][tx] = BlockType.tilledSoil;
    }
    final climate = evaluateMicroclimate(tx, cropY);
    final habitatMult = climate.growthMultiplierFor(seed);
    final fertilizedByNeighbor = _hasNearbyPitcherFertilizer(tx, cropY);
    crops[key] = CropPlot(
      tileX: tx,
      tileY: cropY,
      seedType: seed,
      soilType: soilType,
      lastHabitatMultiplier: habitatMult,
      isFertilized: fertilizedByNeighbor,
    );
    inventory[seed] = inventory[seed]! - 1;
    milestoneSowedCrop = true;
    sowedSeedVarieties.add(seed);
    emitSound(
      SoundCue.sowSeed,
      worldX: tx * tileSize,
      worldY: cropY * tileSize,
    );
    setBanner(
      'Sowed ${seed.icon} ${seed.label} in ${soilType.icon} ${soilType.label} (${climate.microclimateLabel}: ${climate.affinityBadgeFor(seed)})!',
    );
    return true;
  }

  bool _hasNearbyPitcherFertilizer(int tx, int ty) {
    for (final existing in crops.values) {
      if (existing.seedType == ItemType.pitcherPlantSeeds &&
          (existing.tileX - tx).abs() <= 2 &&
          (existing.tileY - ty).abs() <= 1) {
        return true;
      }
    }
    return false;
  }

  /// Checks whether calming smoke (from a nearby placed [BlockType.campfire] or
  /// [BlockType.torch], holding [ItemType.torchItem], or a nearby flowering
  /// [ItemType.glowBulbSeeds] plant) protects the explorer when harvesting a
  /// beehive at ([tx], [ty]).
  bool hasBeeCalmingSmokeNear(int tx, int ty) {
    if (equippedItem == ItemType.torchItem &&
        (inventory[ItemType.torchItem] ?? 0) > 0) {
      return true;
    }
    for (int dy = -4; dy <= 4; dy++) {
      for (int dx = -4; dx <= 4; dx++) {
        final cx = tx + dx;
        final cy = ty + dy;
        final b = getBlock(cx, cy);
        if (b == BlockType.campfire || b == BlockType.torch) {
          return true;
        }
        if (crops['$cx,$cy'] case final crop?
            when crop.seedType == ItemType.glowBulbSeeds &&
                crop.growthProgress >= 0.50) {
          return true;
        }
      }
    }
    return false;
  }

  /// Harvests [ItemType.honeycomb] from a [BlockType.beehive] at ([tx], [ty]).
  ///
  /// If calming smoke or a glowing lotus bulb is absent, nearby
  /// [AnimalType.beeSwarm] entities become angry and pursue the explorer.
  bool harvestHoneyFromHive(int tx, int ty) {
    if (getBlock(tx, ty) != BlockType.beehive) return false;

    // Flowering crops near the beehive increase honey yield!
    int nearbyFlowers = 0;
    for (final crop in crops.values) {
      if (crop.isFlowering &&
          (crop.tileX - tx).abs() <= 6 &&
          (crop.tileY - ty).abs() <= 6) {
        nearbyFlowers++;
      }
    }
    final honeyYield = 2 + (nearbyFlowers >= 2 ? 1 : 0);
    addItem(ItemType.honeycomb, honeyYield);

    final hasSmoke = hasBeeCalmingSmokeNear(tx, ty);
    if (hasSmoke) {
      emitSound(
        SoundCue.harvestCrop,
        worldX: tx * tileSize + tileSize * 0.5,
        worldY: ty * tileSize + tileSize * 0.5,
      );
      setBanner(
        '💨 Bees stayed calm! Safely harvested ${honeyYield}x 🍯 Golden Honeycomb!',
      );
    } else {
      _provokeBeesNear(tx, ty);
      emitSound(
        SoundCue.beeBuzzAngry,
        worldX: tx * tileSize + tileSize * 0.5,
        worldY: ty * tileSize + tileSize * 0.5,
        baseVolume: 0.95,
      );
      setBanner(
        '🐝 Harvested ${honeyYield}x 🍯 Honeycomb without smoke — Bee Swarm provoked! Use 🕯️ Torch, 🔥 Campfire, or 💡 Glow-Bulb!',
      );
    }
    return true;
  }

  void _provokeBeesNear(int tx, int ty) {
    final wx = tx * tileSize + tileSize * 0.5;
    final wy = ty * tileSize + tileSize * 0.5;
    bool foundExistingSwarm = false;
    for (final a in animals) {
      if (a.type == AnimalType.beeSwarm) {
        final d = math.sqrt(math.pow(a.x - wx, 2) + math.pow(a.y - wy, 2));
        if (d <= 220.0) {
          a.isAngry = true;
          a.angryTimer = 9.0;
          foundExistingSwarm = true;
        }
      }
    }
    if (!foundExistingSwarm) {
      animals.add(
        JungleAnimal(
          type: AnimalType.beeSwarm,
          x: wx,
          y: wy,
          homeX: wx,
          homeY: wy,
          isAngry: true,
        )..angryTimer = 9.0,
      );
    }
  }

  /// Harvests a mature crop or beehive at ([tx], [ty]), feeds friendly
  /// wildlife, pours/scoops water, ignites brush with a torch, sows seeds, or
  /// places a building block/wall.
  bool interactOrPlaceAt(int tx, int ty) {
    if ((tx - playerTileX).abs() > 5 || (ty - playerTileY).abs() > 5) {
      setBanner('Target tile is out of reach! Move closer.');
      return false;
    }

    // 1. Check if tapping the Ancient Jungle Shrine, a Totem Pedestal, or a Beehive!
    final block = getBlock(tx, ty);
    if (block == BlockType.jungleShrine) {
      return socketShardsIntoShrine();
    }
    if (block == BlockType.totemPedestal) {
      return claimTotemPedestalAt(tx, ty);
    }
    if (block == BlockType.beehive) {
      return harvestHoneyFromHive(tx, ty);
    }

    // 2. Check if a ripe crop is at (tx, ty) or (tx, ty - 1).
    for (final cy in [ty, ty - 1]) {
      final key = '$tx,$cy';
      if (crops[key] case final crop? when crop.isMature) {
        return _harvestMatureCrop(key, crop);
      }
    }

    // 3. Toggle shelter doors if tapping a door block.
    if (block == BlockType.doorClosed) {
      blocks[ty][tx] = BlockType.doorOpen;
      setBanner('Opened shelter door.');
      return true;
    } else if (block == BlockType.doorOpen) {
      blocks[ty][tx] = BlockType.doorClosed;
      setBanner('Closed shelter door (blocks predators/bees & traps warmth).');
      return true;
    }

    // 4. Water Bucket: scoop river water or pour gravity-flowing water / douse wildfire!
    if (equippedItem == ItemType.waterBucket) {
      if (block == BlockType.water) {
        blocks[ty][tx] = BlockType.air;
        addItem(ItemType.waterBucket, 1);
        setBanner('🪣 Scooped river water into your bucket!');
        return true;
      } else if ((inventory[ItemType.waterBucket] ?? 0) > 0 &&
          (block == BlockType.air || block == BlockType.wildfire)) {
        blocks[ty][tx] = BlockType.water;
        _fireBurnTicks.remove('$tx,$ty');
        inventory[ItemType.waterBucket] = inventory[ItemType.waterBucket]! - 1;
        setBanner('🪣 Poured flowing water!');
        return true;
      }
    }

    // 5. Holding Torch and tapping a flammable block ignites Spreading Wildfire!
    if (equippedItem == ItemType.torchItem &&
        (inventory[ItemType.torchItem] ?? 0) > 0 &&
        block != BlockType.air &&
        block.flammability > 0) {
      blocks[ty][tx] = BlockType.wildfire;
      _fireBurnTicks['$tx,$ty'] = 0;
      setBanner(
        '🔥 Ignited ${block.label}! Fire will spread to nearby foliage!',
      );
      return true;
    }

    // 6. If holding Fishing Rod and clicking near water, cast or reel in!
    if (equippedItem == ItemType.fishingRod || block == BlockType.water) {
      if ((inventory[ItemType.fishingRod] ?? 0) > 0 &&
          (block == BlockType.water || _isWaterNearby(tx, ty))) {
        return toggleFishingCast(tx, ty);
      }
    }

    // 7. If holding edible fruit and a friendly monkey/toucan is near the tapped tile, feed it!
    if (equippedItem.isEdible && (inventory[equippedItem] ?? 0) > 0) {
      final tapWorldX = tx * tileSize + tileSize * 0.5;
      final tapWorldY = ty * tileSize + tileSize * 0.5;
      for (final animal in animals) {
        if (animal.type == AnimalType.capuchinMonkey ||
            animal.type == AnimalType.toucan) {
          final distance = math.sqrt(
            math.pow(animal.x - tapWorldX, 2) +
                math.pow(animal.y - tapWorldY, 2),
          );
          if (distance <= 52.0) {
            return feedNearbyWildlife(animal);
          }
        }
      }
    }

    // 8. If holding a seed, sow it.
    if (equippedItem.category == ItemCategory.seed &&
        (inventory[equippedItem] ?? 0) > 0) {
      return sowSeedAt(tx, ty, equippedItem);
    }

    // 9. If holding a building block, beehive, or background wall, place it.
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
        final overlapsPlayer =
            tx == playerTileX && (ty == playerTileY || ty == playerTileY - 1);
        if (!overlapsPlayer || !item.placedBlock!.isSolid) {
          blocks[ty][tx] = item.placedBlock!;
          if (item == ItemType.doorItem &&
              ty - 1 >= 0 &&
              blocks[ty - 1][tx] == BlockType.air) {
            walls[ty][tx] = WallType.woodWall;
          }
          if (item == ItemType.woodenBeehiveItem) {
            animals.add(
              JungleAnimal(
                type: AnimalType.beeSwarm,
                x: tx * tileSize + tileSize * 0.5,
                y: ty * tileSize + tileSize * 0.5,
                homeX: tx * tileSize + tileSize * 0.5,
                homeY: ty * tileSize + tileSize * 0.5,
              ),
            );
          }
          inventory[item] = inventory[item]! - 1;
          setBanner('Placed ${item.icon} ${item.label}.');
          return true;
        }
      }
    }

    return false;
  }

  bool _harvestMatureCrop(String key, CropPlot crop) {
    if (crop.seedType == ItemType.mahoganySapling) {
      _growSaplingIntoMahoganyTree(crop.tileX, crop.tileY);
      addItem(ItemType.woodLogItem, 3);
      addItem(ItemType.mahoganySapling, 1);
      milestoneHarvestedFruit = true;
      setBanner(
        '🌳 Mahogany Sapling matured into a full canopy tree (+3 Logs & Sapling)!',
      );
      return true;
    }

    final product = crop.harvestedFruit;
    final pollinationBonus = crop.isPollinated ? 1 : 0;
    final thrivingBonus = crop.lastHabitatMultiplier >= 1.35 ? 1 : 0;
    final strugglingPenalty = crop.lastHabitatMultiplier <= 0.70 ? -1 : 0;
    final productCount = math.max(
      1,
      2 +
          _rng.nextInt(2) +
          pollinationBonus +
          thrivingBonus +
          strugglingPenalty,
    );
    final seedCount = math.max(
      1,
      1 + _rng.nextInt(2) + pollinationBonus + thrivingBonus,
    );

    addItem(product, productCount);
    addItem(crop.seedType, seedCount);
    milestoneHarvestedFruit = true;
    emitSound(
      SoundCue.harvestCrop,
      worldX: crop.tileX * tileSize,
      worldY: crop.tileY * tileSize,
    );

    // Cross-pollinated crops have a chance to yield a rare hybrid/discovered seed!
    String bonusText = '';
    if (crop.isPollinated && _rng.nextDouble() < 0.55) {
      const discoveryPool = [
        ItemType.glowBulbSeeds,
        ItemType.pitcherPlantSeeds,
        ItemType.healingHerbSeeds,
        ItemType.thornVineSeeds,
        ItemType.mangoSeeds,
      ];
      final bonusSeed = discoveryPool[_rng.nextInt(discoveryPool.length)];
      addItem(bonusSeed, 1);
      bonusText =
          ' + 1x ${bonusSeed.icon} ${bonusSeed.label} (cross-pollinated!)';
    }

    if (crop.seedType.regrowsOnHarvest) {
      crop.growthProgress = 0.42;
      crop.isPollinated = false;
      setBanner(
        'Harvested ${productCount}x ${product.icon} ${product.label}$bonusText! Perennial plant will regrow.',
      );
    } else {
      crops.remove(key);
      setBanner(
        'Harvested ${productCount}x ${product.icon} ${product.label} + seeds$bonusText!',
      );
    }
    return true;
  }

  void _growSaplingIntoMahoganyTree(int tx, int ty) {
    crops.remove('$tx,$ty');
    if (ty + 1 < height) {
      blocks[ty + 1][tx] = BlockType.grass;
    }
    // Tall 7-tile Mahogany trunk + canopy crown reaching up to ty - 8 so a
    // grown Mahogany Tree bridges the vertical gap to Floating Sky Sanctuaries!
    final trunkHeight = 7;
    for (int y = ty; y >= ty - trunkHeight + 1 && y >= 2; y--) {
      if (blocks[y][tx] == BlockType.air || blocks[y][tx] == BlockType.leaves) {
        blocks[y][tx] = BlockType.woodLog;
      }
    }
    final topTreeY = (ty - trunkHeight + 1).clamp(3, height - 1);
    for (int ly = topTreeY - 2; ly <= topTreeY + 1; ly++) {
      for (int lx = tx - 2; lx <= tx + 2; lx++) {
        if (ly >= 1 && (lx - tx).abs() + (ly - topTreeY).abs() <= 3) {
          if (blocks[ly][lx] == BlockType.air) {
            blocks[ly][lx] = BlockType.leaves;
          }
        }
      }
    }
    for (final vx in [tx - 2, tx, tx + 2]) {
      for (int vy = topTreeY - 1; vy <= topTreeY + 5 && vy <= ty; vy++) {
        if (vy >= 1 && blocks[vy][vx] == BlockType.air) {
          blocks[vy][vx] = BlockType.vine;
        }
      }
    }
    // Attract a wild beehive & bee swarm if no hive is immediately adjacent.
    if (!_isBeePollinationNearby(tx, ty)) {
      final hiveX = tx + 1;
      final hiveY = (topTreeY + 2).clamp(3, ty);
      if (blocks[hiveY][hiveX] == BlockType.air ||
          blocks[hiveY][hiveX] == BlockType.leaves) {
        blocks[hiveY][hiveX] = BlockType.beehive;
        animals.add(
          JungleAnimal(
            type: AnimalType.beeSwarm,
            x: hiveX * tileSize + tileSize * 0.5,
            y: hiveY * tileSize + tileSize * 0.5,
            homeX: hiveX * tileSize + tileSize * 0.5,
            homeY: hiveY * tileSize + tileSize * 0.5,
          ),
        );
      }
    }
    milestonePlantAnimalInteraction = true;
  }

  /// Returns which of the 3 [ItemType.allTotemShards] rests on the pedestal at
  /// tile coordinates ([tx], [ty]) based on vertical elevation zone.
  ItemType totemShardForPedestalAt(int tx, int ty) {
    if (ty <= 12) return ItemType.skyTotemShard;
    if (ty >= abyssDepthY) return ItemType.abyssTotemShard;
    return ItemType.marshTotemShard;
  }

  /// Claims the [BlockType.totemPedestal] at ([tx], [ty]), adding its
  /// Ancient Totem Shard to the explorer's inventory.
  bool claimTotemPedestalAt(int tx, int ty) {
    if (getBlock(tx, ty) != BlockType.totemPedestal) return false;
    final shard = totemShardForPedestalAt(tx, ty);
    blocks[ty][tx] = BlockType.air;
    addItem(shard, 1);
    emitSound(
      SoundCue.harvestCrop,
      worldX: tx * tileSize + tileSize * 0.5,
      worldY: ty * tileSize + tileSize * 0.5,
      baseVolume: 1.0,
    );
    setBanner(
      '🏆 Recovered ${shard.icon} ${shard.label} ($discoveredTotemShardCount/3)! Return to the 🗿 Ancient Jungle Shrine (X:31) to socket it!',
    );
    return true;
  }

  /// Sockets any carried [ItemType.allTotemShards] into the Ancient Jungle
  /// Shrine and triggers the Jungle Awakening when all 3/3 Shards are socketed.
  bool socketShardsIntoShrine() {
    final newlySocketed = <ItemType>[];
    for (final shard in ItemType.allTotemShards) {
      if ((inventory[shard] ?? 0) > 0 && !socketedTotemShards.contains(shard)) {
        inventory[shard] = inventory[shard]! - 1;
        socketedTotemShards.add(shard);
        newlySocketed.add(shard);
      }
    }

    if (newlySocketed.isEmpty) {
      if (shrineAwakened) {
        setBanner(
          '🌟 The Ancient Jungle Shrine is Awakened (3/3 Shards)! Eternal canopy blessing active!',
        );
        return true;
      }
      final missing = ItemType.allTotemShards
          .where((s) => !socketedTotemShards.contains(s))
          .map((s) => '${s.icon} ${s.label}')
          .join(', ');
      setBanner(
        '🗿 Ancient Jungle Shrine (${socketedTotemShards.length}/3 Shards). Still needed: $missing.',
      );
      return false;
    }

    emitSound(SoundCue.harvestCrop, worldX: playerX, worldY: playerY);
    if (shrineAwakened) {
      health = 100.0;
      hunger = 100.0;
      warmth = 100.0;
      for (final crop in crops.values) {
        crop.isPollinated = true;
        crop.isFertilized = true;
      }
      emitSound(SoundCue.toucanScream, worldX: playerX, worldY: playerY - 24.0);
      setBanner(
        '🌟 THE ANCIENT JUNGLE SHRINE IS AWAKENED (3/3 Totem Shards)! Eternal canopy & bioluminescent blessings unlocked!',
      );
    } else {
      final names = newlySocketed.map((s) => '${s.icon} ${s.label}').join(', ');
      setBanner(
        '🗿 Socketed $names into the Shrine (${socketedTotemShards.length}/3)! Shrine blessing granted!',
      );
    }
    return true;
  }

  /// Whether the explorer's currently equipped tool is strong enough to mine
  /// [block].
  ///
  /// Enforces tool progression gates:
  /// - [BlockType.ironOre] requires at least a [ItemType.stonePickaxe],
  ///   [ItemType.ironPickaxe], or [ItemType.ironMachete].
  /// - [BlockType.ancientObsidian] requires a [ItemType.stonePickaxe] or
  ///   [ItemType.ironPickaxe].
  bool canMineBlock(BlockType block) {
    if (block == BlockType.ironOre) {
      return equippedItem == ItemType.stonePickaxe ||
          equippedItem == ItemType.ironPickaxe ||
          equippedItem == ItemType.ironMachete;
    }
    if (block == BlockType.ancientObsidian) {
      return equippedItem == ItemType.stonePickaxe ||
          equippedItem == ItemType.ironPickaxe;
    }
    return block != BlockType.jungleShrine &&
        block != BlockType.villageHutBlock &&
        block != BlockType.air &&
        block != BlockType.water;
  }

  /// Whether tile ([tx], [ty]) in the subterranean Pitch-Black Abyss
  /// (`ty >= abyssDepthY`) is illuminated by a held or placed torch, campfire,
  /// bioluminescent [ItemType.glowBulbSeeds] plant, or the Abyss Shrine blessing.
  bool hasAbyssLightAt(int tx, int ty) {
    if (abyssBlessingActive) return true;
    if (equippedItem == ItemType.torchItem &&
        (inventory[ItemType.torchItem] ?? 0) > 0) {
      return true;
    }
    if (equippedItem == ItemType.glowFruit &&
        (inventory[ItemType.glowFruit] ?? 0) > 0) {
      return true;
    }
    for (int dy = -6; dy <= 6; dy++) {
      for (int dx = -6; dx <= 6; dx++) {
        final b = getBlock(tx + dx, ty + dy);
        if (b == BlockType.torch || b == BlockType.campfire) {
          return true;
        }
      }
    }
    for (final crop in crops.values) {
      if (crop.seedType == ItemType.glowBulbSeeds &&
          crop.growthProgress >= 0.30 &&
          (crop.tileX - tx).abs() <= 6 &&
          (crop.tileY - ty).abs() <= 6) {
        return true;
      }
    }
    return false;
  }

  /// Whether tile ([tx], [ty]) lies inside the poisonous Toxic Viper Marsh
  /// Miasma cloud surrounding a surface Venom Marsh Altar.
  bool isInToxicMarshMiasma(int tx, int ty) {
    if (ty < 14 || ty >= abyssDepthY) return false;
    for (int dy = -3; dy <= 3; dy++) {
      for (int dx = -5; dx <= 5; dx++) {
        final checkY = ty + dy;
        if (checkY >= 14 &&
            checkY < abyssDepthY &&
            getBlock(tx + dx, checkY) == BlockType.totemPedestal) {
          return true;
        }
      }
    }
    return false;
  }

  /// Whether the explorer at ([tx], [ty]) is protected from Toxic Viper Marsh
  /// Miasma by nearby [ItemType.healingHerbSeeds] / [ItemType.pitcherPlantSeeds]
  /// flora, carried [ItemType.healingHerb] poultices, or the Marsh Shrine blessing.
  bool hasMarshMiasmaProtection(int tx, int ty) {
    if (marshBlessingActive) return true;
    if ((inventory[ItemType.healingHerb] ?? 0) > 0 ||
        (inventory[ItemType.jungleNectar] ?? 0) > 0) {
      return true;
    }
    for (final crop in crops.values) {
      if ((crop.seedType == ItemType.healingHerbSeeds ||
              crop.seedType == ItemType.pitcherPlantSeeds) &&
          crop.growthProgress >= 0.30 &&
          (crop.tileX - tx).abs() <= 6 &&
          (crop.tileY - ty).abs() <= 5) {
        return true;
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

  bool _isBeePollinationNearby(int tx, int ty) {
    for (int dy = -6; dy <= 6; dy++) {
      for (int dx = -6; dx <= 6; dx++) {
        if (getBlock(tx + dx, ty + dy) == BlockType.beehive) return true;
      }
    }
    final wx = tx * tileSize;
    final wy = ty * tileSize;
    for (final a in animals) {
      if ((a.type == AnimalType.beeSwarm || a.type == AnimalType.toucan) &&
          (a.x - wx).abs() <= 180.0 &&
          (a.y - wy).abs() <= 180.0) {
        return true;
      }
    }
    return false;
  }

  bool _hasGlowBulbNearWater(int tx, int ty) {
    for (final crop in crops.values) {
      if (crop.seedType == ItemType.glowBulbSeeds &&
          crop.growthProgress >= 0.33 &&
          (crop.tileX - tx).abs() <= 5 &&
          (crop.tileY - ty).abs() <= 4) {
        return true;
      }
    }
    return false;
  }

  /// Casts the fishing line into a water block near ([targetTx], [targetTy])
  /// or reels in an active bite.
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
        if (_rng.nextDouble() < 0.45) {
          const riverSeeds = [
            ItemType.bananaSeeds,
            ItemType.glowBulbSeeds,
            ItemType.pitcherPlantSeeds,
          ];
          final bonusSeed = riverSeeds[_rng.nextInt(riverSeeds.length)];
          addItem(bonusSeed, 1);
          setBanner(
            '🐟 Caught a River Fish + 1x ${bonusSeed.icon} ${bonusSeed.label}!',
          );
        } else {
          setBanner('🐟 Caught a fresh River Fish! Roast it at a Campfire.');
        }
        milestoneCaughtFish = true;
        return true;
      } else {
        setBanner('Reeled in fishing line early.');
        return false;
      }
    }

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

    final glowLure = _hasGlowBulbNearWater(waterX, waterY);
    final baseWait = 2.2 + _rng.nextDouble() * 2.0;
    activeFishing = FishingState(
      bobberX: waterX * tileSize + tileSize * 0.5,
      bobberY: waterY * tileSize + tileSize * 0.4,
      waitTimer: glowLure ? baseWait * 0.6 : baseWait,
    );
    setBanner(
      glowLure
          ? '🎣 Cast line near 💡 Glow-Bulb! Bioluminescence lures fish faster!'
          : '🎣 Cast line into the river... wait for the splash!',
    );
    return true;
  }

  /// Performs a melee swing with the equipped tool/weapon against nearby
  /// dangerous animals or provoked bee swarms.
  bool attackNearbyAnimals() {
    swingAnimationTimer = 0.28;
    final damage = equippedItem.attackDamage;
    bool hitAny = false;

    for (int i = animals.length - 1; i >= 0; i--) {
      final a = animals[i];
      final dx = a.x - playerX;
      final dy = a.y - (playerY - 14.0);
      final dist = math.sqrt(dx * dx + dy * dy);
      if (a.type == AnimalType.toucan && dist <= 72.0) {
        a.y -= 10.0;
        a.facingRight = dx >= 0;
        a.showBadge('🦜 SCREAM!', duration: 2.2);
        emitSound(
          SoundCue.toucanScream,
          worldX: a.x,
          worldY: a.y,
          baseVolume: 0.95,
        );
        continue;
      }
      if (!a.type.hostileByDefault && !a.isAngry) continue;
      if (dist <= 68.0) {
        a.health -= damage;
        a.hurtFlashTimer = 0.25;
        a.vx = (dx >= 0 ? 1 : -1) * 160.0;
        a.vy = -120.0;
        if (a.type == AnimalType.beeSwarm) {
          a.isAngry = true;
          a.angryTimer = 8.0;
        }
        hitAny = true;
        if (a.health <= 0) {
          animals.removeAt(i);
          milestoneDefeatedPredator = true;
          if (a.type == AnimalType.piranha) {
            addItem(ItemType.rawFish, 1);
          } else if (a.type == AnimalType.beeSwarm) {
            addItem(ItemType.honeycomb, 1);
          } else if (a.type == AnimalType.snake) {
            addItem(ItemType.vineFiber, 1);
            addItem(ItemType.pitcherPlantSeeds, 1);
            addItem(ItemType.healingHerb, 1);
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

    final cropKey = '$tx,$ty';
    if (crops[cropKey]?.isMature == true) {
      interactOrPlaceAt(tx, ty);
      return;
    }

    final block = getBlock(tx, ty);
    if (block == BlockType.jungleShrine) {
      socketShardsIntoShrine();
      miningTarget = null;
      miningProgress = 0.0;
      return;
    }
    if (block == BlockType.totemPedestal) {
      claimTotemPedestalAt(tx, ty);
      miningTarget = null;
      miningProgress = 0.0;
      return;
    }
    if (block == BlockType.air ||
        block == BlockType.water ||
        block == BlockType.villageHutBlock) {
      miningTarget = null;
      miningProgress = 0.0;
      return;
    }

    // Beating out wildfire directly extinguishes it.
    if (block == BlockType.wildfire) {
      blocks[ty][tx] = BlockType.air;
      _fireBurnTicks.remove('$tx,$ty');
      setBanner('Beat out the flames!');
      return;
    }

    // Enforce tool progression gates on Iron Ore and Ancient Obsidian vaults!
    if (!canMineBlock(block)) {
      miningTarget = null;
      miningProgress = 0.0;
      swingAnimationTimer = 0.18;
      if (block == BlockType.ironOre) {
        setBanner(
          '⚒️ Crude Wood Pickaxe cannot mine Iron Ore! Craft a ⚒️ Stone Pickaxe (2 Wood + 3 Stone + 1 Vine) first.',
        );
      } else if (block == BlockType.ancientObsidian) {
        setBanner(
          '🔮 Ancient Obsidian is too hard! Craft a ⚒️ Stone Pickaxe or ⛏️ Iron Pickaxe to breach the vault!',
        );
      }
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
        final roll = _rng.nextDouble();
        if (roll < 0.45) {
          addItem(ItemType.berrySeeds, 1);
          setBanner('Gathered Jungle Dirt + 🌱 Berry Seeds!');
        } else if (roll < 0.68) {
          addItem(ItemType.healingHerbSeeds, 1);
          setBanner('Gathered Jungle Dirt + 🌿 Medicinal Herb Seeds!');
        } else if (roll < 0.85) {
          addItem(ItemType.thornVineSeeds, 1);
          setBanner('Gathered Jungle Dirt + 🌵 Briar Thorn Seeds!');
        }
      case BlockType.dirt:
      case BlockType.tilledSoil:
        addItem(ItemType.dirtBlock, 1);
      case BlockType.riverSilt:
        addItem(ItemType.riverSiltBlock, 1);
        if (_rng.nextDouble() < 0.45) {
          addItem(ItemType.bananaSeeds, 1);
          setBanner('Dug 🌊 Alluvial Silt Block + 🌾 Banana Seeds!');
        } else {
          setBanner(
            'Dug 🌊 Alluvial Silt Block (great for Bananas & Glow-Bulbs)!',
          );
        }
      case BlockType.peatBog:
        addItem(ItemType.peatBogBlock, 1);
        if (_rng.nextDouble() < 0.45) {
          addItem(ItemType.pitcherPlantSeeds, 1);
          setBanner('Dug 🌺 Mossy Peat Block + 🌺 Pitcher Plant Seeds!');
        } else {
          setBanner(
            'Dug 🌺 Mossy Peat Block (ideal for Pitcher Plants & Glow-Bulbs)!',
          );
        }
      case BlockType.volcanicAsh:
        addItem(ItemType.volcanicAshBlock, 1);
        if (_rng.nextDouble() < 0.45) {
          addItem(ItemType.mangoSeeds, 1);
          setBanner('Dug 🌋 Volcanic Ash Block + ✨ Golden Mango Seeds!');
        } else {
          setBanner(
            'Dug 🌋 Volcanic Ash Block (ideal for Briars, Mangoes & Herbs)!',
          );
        }
      case BlockType.stone:
      case BlockType.cloudStone:
        addItem(ItemType.stoneBlock, 1);
      case BlockType.ancientObsidian:
        addItem(ItemType.stoneBlock, 1);
        addItem(ItemType.coalItem, 1);
        setBanner('Breached 🔮 Ancient Obsidian Vault Wall!');
      case BlockType.totemPedestal:
        final shard = totemShardForPedestalAt(tx, ty);
        addItem(shard, 1);
        setBanner(
          '🏆 Recovered ${shard.icon} ${shard.label}! Return to the 🗿 Ancient Jungle Shrine (X:31)!',
        );
      case BlockType.coalOre:
        addItem(ItemType.coalItem, 1);
        addItem(ItemType.stoneBlock, 1);
        setBanner('Mined ⚫ Coal Lump!');
      case BlockType.ironOre:
        addItem(ItemType.ironOreItem, 1);
        setBanner('Mined 🔩 Iron Ore!');
      case BlockType.woodLog:
        addItem(ItemType.woodLogItem, 2);
        if (_rng.nextDouble() < 0.35) {
          addItem(ItemType.mahoganySapling, 1);
          setBanner('Chopped 🌲 Mahogany Logs + 🌳 Mahogany Sapling!');
        } else {
          setBanner('Chopped 🌲 Mahogany Logs!');
        }
      case BlockType.leaves:
        addItem(ItemType.thatchBundle, 2);
        final roll = _rng.nextDouble();
        if (roll < 0.40) {
          addItem(ItemType.banana, 1);
          addItem(ItemType.bananaSeeds, 1);
          setBanner('Gathered 🍃 Thatch + 🍌 Banana & Seeds!');
        } else if (roll < 0.70) {
          addItem(ItemType.mahoganySapling, 1);
          setBanner('Gathered 🍃 Thatch + 🌳 Mahogany Sapling!');
        }
      case BlockType.vine:
        addItem(ItemType.vineFiber, 2);
        final roll = _rng.nextDouble();
        if (roll < 0.35) {
          addItem(ItemType.thornVineSeeds, 1);
          setBanner('Harvested 🪢 Vine Fibers + 🌵 Briar Thorn Seeds!');
        } else if (roll < 0.60) {
          addItem(ItemType.pitcherPlantSeeds, 1);
          setBanner('Harvested 🪢 Vine Fibers + 🌺 Pitcher Plant Seeds!');
        } else {
          setBanner('Harvested 🪢 Vine Fibers!');
        }
      case BlockType.berryBush:
        addItem(ItemType.jungleBerry, 2);
        addItem(ItemType.berrySeeds, 2);
        if (_rng.nextDouble() < 0.35) {
          addItem(ItemType.glowBulbSeeds, 1);
          setBanner(
            'Gathered 🫐 Berries, 🌱 Berry Seeds & 💡 Glow-Bulb Spores!',
          );
        } else {
          setBanner('Gathered 🫐 Jungle Berries & 🌱 Berry Seeds!');
        }
      case BlockType.beehive:
        addItem(ItemType.honeycomb, 3);
        if (!hasBeeCalmingSmokeNear(tx, ty)) {
          _provokeBeesNear(tx, ty);
          setBanner(
            '🐝 Broke Beehive without smoke! Got 3x 🍯 Honeycomb, but bees are angry!',
          );
        } else {
          setBanner('💨 Safely harvested Beehive for 3x 🍯 Golden Honeycomb!');
        }
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
      case BlockType.wildfire:
      case BlockType.villageHutBlock:
      case BlockType.jungleShrine:
        break;
    }
  }

  /// Steps the cellular automata block physics once:
  ///
  /// 1. **Water Gravity & Lateral Flow**: [BlockType.water] falls into open
  ///    [BlockType.air] below, douses [BlockType.wildfire], and flows sideways
  ///    when blocked underneath.
  /// 2. **Fire Spread & Burnout**: [BlockType.wildfire] (and uncontained
  ///    [BlockType.campfire] touching foliage) spreads to neighboring blocks
  ///    according to [BlockType.flammability], and eventually burns out into
  ///    [BlockType.air] or coal.
  void stepBlockPhysics() {
    final playerChunk = _InfiniteTileRow.chunkIndexOf(playerTileX);
    final activeChunks = <int>{
      for (int c = playerChunk - 2; c <= playerChunk + 2; c++) c,
      ..._activePhysicsChunks,
    };
    final activeColumns = <int>[
      for (final c in activeChunks)
        for (int i = 0; i < chunkWidth; i++) c * chunkWidth + i,
    ];

    // 1. Water falls with gravity and flows horizontally (bottom-up scan).
    final movedWater = <(int, int)>{};
    for (int y = height - 2; y >= 1; y--) {
      final leftToRight = y.isEven;
      final colCount = activeColumns.length;
      for (int idx = 0; idx < colCount; idx++) {
        final x =
            leftToRight
                ? activeColumns[idx]
                : activeColumns[colCount - 1 - idx];
        if (blocks[y][x] != BlockType.water) continue;
        if (movedWater.contains((x, y))) continue;

        final below = blocks[y + 1][x];
        if (below == BlockType.wildfire) {
          blocks[y + 1][x] = BlockType.water;
          blocks[y][x] = BlockType.air;
          _fireBurnTicks.remove('$x,${y + 1}');
          movedWater.add((x, y + 1));
          continue;
        }
        if (below == BlockType.air) {
          blocks[y + 1][x] = BlockType.water;
          blocks[y][x] = BlockType.air;
          movedWater.add((x, y + 1));
          continue;
        }

        // If blocked below, extinguish adjacent fire or flow sideways into open air
        // when there is water pressure above or an open drop-off next to it.
        for (final dir in leftToRight ? const [-1, 1] : const [1, -1]) {
          final nx = x + dir;
          final side = blocks[y][nx];
          if (side == BlockType.wildfire) {
            blocks[y][nx] = BlockType.air;
            _fireBurnTicks.remove('$nx,$y');
          } else if (side == BlockType.air &&
              (blocks[y + 1][nx] == BlockType.air ||
                  blocks[y - 1][x] == BlockType.water)) {
            blocks[y][nx] = BlockType.water;
            blocks[y][x] = BlockType.air;
            movedWater.add((nx, y));
            break;
          }
        }
      }
    }

    // 2. Fire propagation & burnout.
    final newFires = <(int, int)>[];
    final extinguished = <(int, int)>[];

    for (int y = 1; y < height - 1; y++) {
      for (final x in activeColumns) {
        final b = blocks[y][x];
        if (b != BlockType.wildfire && b != BlockType.campfire) continue;

        // Check if water is touching this fire.
        bool touchingWater = false;
        for (final (dx, dy) in const [(0, -1), (0, 1), (-1, 0), (1, 0)]) {
          if (blocks[y + dy][x + dx] == BlockType.water) {
            touchingWater = true;
            break;
          }
        }

        if (b == BlockType.wildfire) {
          if (touchingWater ||
              (isRaining &&
                  !isTileShelteredFromRain(x, y) &&
                  _rng.nextDouble() < 0.35)) {
            extinguished.add((x, y));
            continue;
          }
          final key = '$x,$y';
          final ticks = (_fireBurnTicks[key] ?? 0) + 1;
          _fireBurnTicks[key] = ticks;
          if (ticks >= 7) {
            extinguished.add((x, y));
            continue;
          }
        }

        // Spread fire to adjacent flammable blocks.
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final nx = x + dx;
            final ny = y + dy;
            final nb = blocks[ny][nx];
            if (nb.flammability <= 0) continue;
            // Campfires only ignite immediately adjacent foliage (leaves/vines/bushes).
            if (b == BlockType.campfire &&
                nb != BlockType.leaves &&
                nb != BlockType.vine &&
                nb != BlockType.berryBush) {
              continue;
            }
            final spreadChance =
                nb.flammability * (b == BlockType.wildfire ? 0.38 : 0.12);
            if (_rng.nextDouble() < spreadChance) {
              newFires.add((nx, ny));
            }
          }
        }
      }
    }

    for (final (fx, fy) in extinguished) {
      if (blocks[fy][fx] == BlockType.wildfire) {
        blocks[fy][fx] = BlockType.air;
        _fireBurnTicks.remove('$fx,$fy');
      }
    }
    for (final (nx, ny) in newFires) {
      if (blocks[ny][nx] == BlockType.beehive) {
        _provokeBeesNear(nx, ny);
      }
      blocks[ny][nx] = BlockType.wildfire;
      _fireBurnTicks['$nx,$ny'] = 0;
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
  /// Updates cellular automata physics (water & fire), time of day, weather,
  /// hunger and cold survival gauges, planted crop growth (boosted by bee/toucan
  /// pollination and pitcher-plant fertilization), active plant defenses,
  /// fishing bobber, player movement physics, and wildlife ecology AI.
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

    // Stream new chunks ahead of the explorer in both West (-X) and East (+X) directions!
    ensureChunksAround(playerTileX, radiusChunks: 3);

    if (statusBannerTimer > 0) statusBannerTimer -= clampedDt;
    if (swingAnimationTimer > 0) swingAnimationTimer -= clampedDt;
    if (playerHurtFlashTimer > 0) playerHurtFlashTimer -= clampedDt;
    if (lastSoundTimer > 0) {
      lastSoundTimer = math.max(0.0, lastSoundTimer - clampedDt);
      if (lastSoundTimer <= 0) {
        lastSoundEvent = null;
      }
    }

    // Step cellular block physics (gravity water flow & spreading fire) at ~7 Hz.
    _physicsTickAccumulator += clampedDt;
    if (_physicsTickAccumulator >= 0.14) {
      _physicsTickAccumulator = 0.0;
      stepBlockPhysics();
    }

    // 1. Advance Day/Night cycle (1 full day = 150 seconds).
    final prevTime = timeOfDay;
    timeOfDay = (timeOfDay + clampedDt / 150.0) % 1.0;
    if (timeOfDay < prevTime) {
      dayCount++;
      setBanner('☀️ Dawn of Day $dayCount in the Jungle!');
    }

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

    hunger = (hunger - clampedDt * 0.95).clamp(0.0, 100.0);

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

    // Check if standing inside spreading wildfire.
    if (getBlock(playerTileX, playerTileY) == BlockType.wildfire ||
        getBlock(playerTileX, (playerY - 4) ~/ tileSize) ==
            BlockType.wildfire) {
      health = (health - clampedDt * 12.0).clamp(0.0, 100.0);
      playerHurtFlashTimer = 0.2;
      setBanner(
        '🔥 Burning in wildfire! Jump into water or pour a Water Bucket!',
      );
    }

    // Progression Gate 1: Pitch-Black Abyss (y >= abyssDepthY) drains warmth &
    // life unless illuminated by a Torch, Campfire, or bioluminescent Glow-Bulb!
    if (playerTileY >= abyssDepthY &&
        !hasAbyssLightAt(playerTileX, playerTileY)) {
      warmth = (warmth - clampedDt * 5.0).clamp(0.0, 100.0);
      health = (health - clampedDt * 3.8).clamp(0.0, 100.0);
      playerHurtFlashTimer = 0.2;
      setBanner(
        '🌑 Pitch-Black Abyss! Hold/place a 🕯️ Torch or plant 💡 Glow-Bulbs to light the deep caverns!',
      );
    }

    // Progression Gate 2: Toxic Viper Marsh Miasma drains life unless purified
    // by nearby Medicinal Herbs / Pitcher Plants or carried Healing Poultices!
    if (isInToxicMarshMiasma(playerTileX, playerTileY) &&
        !hasMarshMiasmaProtection(playerTileX, playerTileY)) {
      health = (health - clampedDt * 4.2).clamp(0.0, 100.0);
      playerHurtFlashTimer = 0.2;
      setBanner(
        '☠️ Toxic Viper Marsh Miasma! Plant 🌿 Medicinal Herbs / 🌺 Pitcher Plants nearby or carry 🌿 Healing Poultices!',
      );
    }

    if (hunger <= 0.0) {
      health = (health - clampedDt * 3.2).clamp(0.0, 100.0);
    }
    if (warmth <= 0.0) {
      health = (health - clampedDt * 3.8).clamp(0.0, 100.0);
    }
    if (hunger > 65.0 && warmth > 55.0 && health < 100.0) {
      health = (health + clampedDt * 1.2).clamp(0.0, 100.0);
    }

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

    // 3. Grow planted crops & process active plant traits.
    _updateCropsAndPlantEffects(clampedDt);

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

    // 6. Update & spawn wildlife (including bee/toucan pollination & monkey foraging).
    _updateAnimals(clampedDt);
  }

  void _updateCropsAndPlantEffects(double dt) {
    final growthMultiplier = (isNight ? 0.45 : 1.15) * (isRaining ? 1.35 : 1.0);
    final maturedSaplings = <(int, int)>[];

    for (final crop in List<CropPlot>.of(crops.values)) {
      if (crop.effectCooldown > 0) {
        crop.effectCooldown = math.max(0.0, crop.effectCooldown - dt);
      }
      if (!crop.isFertilized &&
          _hasNearbyPitcherFertilizer(crop.tileX, crop.tileY)) {
        crop.isFertilized = true;
      }

      if (!crop.isMature) {
        final climate = evaluateMicroclimate(crop.tileX, crop.tileY);
        crop.soilType = climate.soilType;
        final habitatMult = climate.growthMultiplierFor(crop.seedType);
        crop.lastHabitatMultiplier = habitatMult;

        final nearWater = climate.isHumidRiverbank;
        final beePollinated = _isBeePollinationNearby(crop.tileX, crop.tileY);
        final baseRate =
            (nearWater ? 0.048 : 0.032) * crop.seedType.seedGrowthFactor;
        final pollinationBoost =
            (beePollinated ? 1.5 : 1.0) * (crop.isPollinated ? 1.25 : 1.0);
        final fertilizerBoost = crop.isFertilized ? 1.6 : 1.0;

        // Shade-loving Glow-Bulbs and Pitcher Plants keep growing strongly at night
        // when in a shaded or bog microclimate!
        final effectiveDayNight =
            (isNight &&
                    climate.isShadedCanopyOrCave &&
                    (crop.seedType == ItemType.glowBulbSeeds ||
                        crop.seedType == ItemType.pitcherPlantSeeds))
                ? 1.10 * (isRaining ? 1.35 : 1.0)
                : growthMultiplier;

        final rate =
            baseRate *
            effectiveDayNight *
            habitatMult *
            pollinationBoost *
            fertilizerBoost;

        crop.growthProgress = (crop.growthProgress + dt * rate).clamp(0.0, 1.0);
      }

      // Update articulated vine/stem segment count as the plant matures.
      final targetVineSegments =
          crop.growthProgress >= 0.95
              ? 4
              : crop.growthProgress >= 0.72
              ? 3
              : crop.growthProgress >= 0.48
              ? 2
              : crop.growthProgress >= 0.24
              ? 1
              : 0;
      if (targetVineSegments > crop.vineSegments) {
        crop.vineSegments = targetVineSegments;
      }

      // Climbing vine tendrils: vining species grown beneath canopy leaves,
      // wooden trellises, or roofs extend climbable vine lianas upward!
      if (crop.isViningSpecies &&
          crop.growthProgress >= 0.58 &&
          crop.tileY >= 3 &&
          getBlock(crop.tileX, crop.tileY - 1) == BlockType.air) {
        final above2 = getBlock(crop.tileX, crop.tileY - 2);
        final above3 = getBlock(crop.tileX, crop.tileY - 3);
        final hasTrellisAbove =
            above2 == BlockType.leaves ||
            above2 == BlockType.woodPlank ||
            above2 == BlockType.thatchRoof ||
            above2 == BlockType.vine ||
            above3 == BlockType.leaves ||
            above3 == BlockType.woodPlank;
        if (hasTrellisAbove) {
          blocks[crop.tileY - 1][crop.tileX] = BlockType.vine;
          if (above2 == BlockType.air &&
              (above3 == BlockType.leaves || above3 == BlockType.woodPlank)) {
            blocks[crop.tileY - 2][crop.tileX] = BlockType.vine;
          }
        }
      }

      if (crop.isMature && crop.seedType == ItemType.mahoganySapling) {
        maturedSaplings.add((crop.tileX, crop.tileY));
      }

      // Active plant-animal interactions for defensive/carnivorous plants:
      if (crop.growthProgress >= 0.33 && crop.effectCooldown <= 0) {
        final plantWorldX = crop.tileX * tileSize + tileSize * 0.5;
        final plantWorldY = (crop.tileY + 1) * tileSize;

        if (crop.seedType == ItemType.thornVineSeeds) {
          // Briar Thorn-Vine pricks and knocks back hostile predators!
          for (int i = animals.length - 1; i >= 0; i--) {
            final animal = animals[i];
            if (animal.type != AnimalType.jaguar &&
                animal.type != AnimalType.snake) {
              continue;
            }
            final dx = animal.x - plantWorldX;
            final dy = animal.y - plantWorldY;
            if (dx.abs() <= 24.0 && dy.abs() <= 24.0) {
              final thornDamage = crop.isMature ? 12.0 : 8.0;
              animal.health -= thornDamage;
              animal.hurtFlashTimer = 0.3;
              final pushDir = dx >= 0 ? 1.0 : -1.0;
              animal.vx = pushDir * 155.0;
              animal.vy = -105.0;
              animal.facingRight = pushDir > 0;
              animal.showBadge('🌵 Pricked!');
              emitSound(
                animal.type == AnimalType.jaguar
                    ? SoundCue.jaguarRoar
                    : SoundCue.snakeHiss,
                worldX: animal.x,
                worldY: animal.y,
              );
              crop.effectCooldown = 1.1;
              milestonePlantAnimalInteraction = true;
              if (animal.health <= 0) {
                animals.removeAt(i);
                milestoneDefeatedPredator = true;
                addItem(ItemType.vineFiber, 2);
                setBanner(
                  '🌵 Briar Thorn-Vine defeated a ${animal.type.label}!',
                );
              }
              break;
            }
          }
        } else if (crop.seedType == ItemType.pitcherPlantSeeds &&
            crop.growthProgress >= 0.50) {
          // Carnivorous Pitcher Plant snaps shut on nearby Snakes or angry Bees,
          // digesting them and fertilizing all adjacent crops!
          for (int i = animals.length - 1; i >= 0; i--) {
            final animal = animals[i];
            final isTarget =
                animal.type == AnimalType.snake ||
                (animal.type == AnimalType.beeSwarm && animal.isAngry);
            if (!isTarget) continue;
            final dx = animal.x - plantWorldX;
            final dy = animal.y - plantWorldY;
            if (dx.abs() <= 26.0 && dy.abs() <= 26.0) {
              animal.health -= 14.0;
              animal.hurtFlashTimer = 0.35;
              animal.vx *= 0.2;
              animal.showBadge('🌺 Trapped!');
              emitSound(
                animal.type == AnimalType.snake
                    ? SoundCue.snakeHiss
                    : SoundCue.beeBuzzAngry,
                worldX: animal.x,
                worldY: animal.y,
              );
              crop.effectCooldown = 1.3;
              crop.isFertilized = true;
              crop.growthProgress = (crop.growthProgress + 0.25).clamp(
                0.0,
                1.0,
              );
              _fertilizeAdjacentCrops(crop.tileX, crop.tileY);
              milestonePlantAnimalInteraction = true;
              if (animal.health <= 0) {
                animals.removeAt(i);
                milestoneDefeatedPredator = true;
                addItem(ItemType.jungleNectar, 1);
                addItem(ItemType.pitcherPlantSeeds, 1);
                setBanner(
                  '🌺 Pitcher Plant digested a ${animal.type.label} & fertilized nearby soil (+1 🧪 Nectar)!',
                );
              } else {
                setBanner(
                  '🌺 Carnivorous Pitcher Plant snapped on a ${animal.type.label}, fertilizing adjacent crops!',
                );
              }
              break;
            }
          }
        }
      }
    }

    for (final (sx, sy) in maturedSaplings) {
      _growSaplingIntoMahoganyTree(sx, sy);
      setBanner(
        '🌳 A planted Mahogany Sapling grew into a towering canopy tree!',
      );
    }
  }

  void _fertilizeAdjacentCrops(int centerTx, int centerTy) {
    for (final other in crops.values) {
      if ((other.tileX - centerTx).abs() <= 3 &&
          (other.tileY - centerTy).abs() <= 2) {
        other.isFertilized = true;
      }
    }
  }

  /// Disperses and auto-sows a wild seed on an open grass or dirt tile near
  /// ([centerTx], [centerTy]) when an animal (monkey or toucan) feeds.
  bool _disperseWildSeedNear(int centerTx, int centerTy, ItemType seedType) {
    for (final offset in const [-2, 2, -3, 3, -1, 1, -4, 4]) {
      final tx = centerTx + offset;
      for (
        int ty = (centerTy - 3).clamp(2, height - 3);
        ty <= (centerTy + 4).clamp(2, height - 3);
        ty++
      ) {
        final ground = getBlock(tx, ty + 1);
        final air = getBlock(tx, ty);
        final soil = ground.soilType;
        final key = '$tx,$ty';
        if (air == BlockType.air && soil != null && !crops.containsKey(key)) {
          if (ground == BlockType.grass || ground == BlockType.dirt) {
            blocks[ty + 1][tx] = BlockType.tilledSoil;
          }
          final climate = evaluateMicroclimate(tx, ty);
          crops[key] = CropPlot(
            tileX: tx,
            tileY: ty,
            seedType: seedType,
            soilType: soil,
            lastHabitatMultiplier: climate.growthMultiplierFor(seedType),
            growthProgress: 0.15,
            isFertilized: true,
          );
          milestonePlantAnimalInteraction = true;
          return true;
        }
      }
    }
    return false;
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

    final nextX = playerX + playerVx * dt;
    ensureChunksAround(pixelToTile(nextX), radiusChunks: 3);
    if (!_collidesAt(nextX, playerY)) {
      playerX = nextX;
    } else {
      if (!_collidesAt(nextX, playerY - tileSize) &&
          _collidesAt(playerX, playerY + 2.0)) {
        playerX = nextX;
        playerY -= tileSize;
      } else {
        playerVx = 0.0;
      }
    }

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
    final leftTile = pixelToTile(px - halfW);
    final rightTile = pixelToTile(px + halfW);
    final topTile = pixelToTile(py - heightPx);
    final bottomTile = pixelToTile(py - 1.0);

    for (int ty = topTile; ty <= bottomTile; ty++) {
      for (int tx = leftTile; tx <= rightTile; tx++) {
        if (getBlock(tx, ty).isSolid) return true;
      }
    }
    return false;
  }

  CropPlot? _findNearbyHerbalWard(double worldX, double worldY) {
    for (final crop in crops.values) {
      if (crop.seedType == ItemType.healingHerbSeeds &&
          crop.growthProgress >= 0.33) {
        final cx = crop.tileX * tileSize + tileSize * 0.5;
        final cy = (crop.tileY + 1) * tileSize;
        if ((worldX - cx).abs() <= 132.0 && (worldY - cy).abs() <= 96.0) {
          return crop;
        }
      }
    }
    return null;
  }

  CropPlot? _findNearbyPitcherLure(double worldX, double worldY) {
    CropPlot? closest;
    double bestDist = 180.0;
    for (final crop in crops.values) {
      if (crop.seedType == ItemType.pitcherPlantSeeds &&
          crop.growthProgress >= 0.50) {
        final cx = crop.tileX * tileSize + tileSize * 0.5;
        final cy = (crop.tileY + 1) * tileSize;
        final d = math.sqrt(
          math.pow(worldX - cx, 2) + math.pow(worldY - cy, 2),
        );
        if (d < bestDist) {
          bestDist = d;
          closest = crop;
        }
      }
    }
    return closest;
  }

  void _updateAnimals(double dt) {
    _animalSpawnTimer -= dt;
    final landPredatorCount =
        animals.where((a) => a.type.hostileByDefault).length;
    final maxPredators = isNight ? 9 : 6;
    if (_animalSpawnTimer <= 0 && landPredatorCount < maxPredators) {
      _animalSpawnTimer = isNight ? 10.0 : 16.0;
      final offsetTiles = (_rng.nextBool() ? 1 : -1) * (14 + _rng.nextInt(12));
      final spawnTx = playerTileX + offsetTiles;
      final inVillage = biomeAt(spawnTx) == JungleBiome.nativeVillage;
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
          final type =
              (_rng.nextDouble() < (isNight ? 0.6 : 0.4))
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

    final playerInWater =
        getBlock(playerTileX, playerTileY) == BlockType.water ||
        getBlock(playerTileX, (playerY - 4) ~/ tileSize) == BlockType.water;

    for (final a in List<JungleAnimal>.of(animals)) {
      if (a.attackCooldown > 0) a.attackCooldown -= dt;
      if (a.hurtFlashTimer > 0) a.hurtFlashTimer -= dt;
      if (a.badgeTimer > 0) {
        a.badgeTimer -= dt;
        if (a.badgeTimer <= 0) a.activityBadge = null;
      }
      if (a.interactionTimer > 0) a.interactionTimer -= dt;
      a.patrolTimer -= dt;

      // 1. Flying Bee Swarm AI: orbits home beehive and visits flowering crops to pollinate!
      if (a.type == AnimalType.beeSwarm) {
        _updateBeeSwarm(a, dt, playerInWater: playerInWater);
        continue;
      }

      // 2. Flying Rainbow Toucan AI: visits blossoms/bushes, pollinates & disperses rare seeds!
      if (a.type == AnimalType.toucan) {
        _updateToucan(a, dt);
        continue;
      }

      // 3. Capuchin Monkey AI: forages ripe fruit & disperses seeds, or harvests crops when befriended!
      if (a.type == AnimalType.capuchinMonkey) {
        _updateCapuchinMonkey(a, dt);
        continue;
      }

      // 4. Aquatic Red-Bellied Piranha AI: swims back and forth across river
      // lagoons with vertical depth undulation, and darts after the explorer
      // when they step/swim into the water!
      if (a.type == AnimalType.piranha) {
        _updatePiranha(a, dt, playerInWater: playerInWater);
        continue;
      }

      // 5. Land Predators (Shadow Jaguar & Emerald Viper):
      final dxToPlayer = playerX - a.x;
      final dyToPlayer = playerY - a.y;
      final distToPlayer = math.sqrt(
        dxToPlayer * dxToPlayer + dyToPlayer * dyToPlayer,
      );

      // Emerald Viper plant interactions: repelled by Medicinal Herbs, lured by Pitcher Plants!
      bool snakeOverride = false;
      if (a.type == AnimalType.snake) {
        final repellingHerb = _findNearbyHerbalWard(a.x, a.y);
        if (repellingHerb != null) {
          final herbX = repellingHerb.tileX * tileSize + tileSize * 0.5;
          a.facingRight = a.x >= herbX;
          a.vx = (a.facingRight ? 1.25 : -1.25) * a.type.speed;
          a.showBadge('🌿 Repelled!', duration: 1.5);
          milestonePlantAnimalInteraction = true;
          snakeOverride = true;
        } else {
          final pitcherLure = _findNearbyPitcherLure(a.x, a.y);
          if (pitcherLure != null) {
            final lureX = pitcherLure.tileX * tileSize + tileSize * 0.5;
            a.facingRight = lureX >= a.x;
            a.vx = (a.facingRight ? 0.95 : -0.95) * a.type.speed;
            a.showBadge('🌺 Lured...', duration: 1.2);
            snakeOverride = true;
          }
        }
      }

      final aggroRange = isNight ? 240.0 : 165.0;
      if (!snakeOverride && distToPlayer < aggroRange) {
        a.facingRight = dxToPlayer >= 0;
        a.vx = (dxToPlayer >= 0 ? 1.0 : -1.0) * a.type.speed;
        // Emit a predator roar / hiss when lunging into pursuit!
        if (a.interactionTimer <= 0) {
          a.interactionTimer = 3.6 + _rng.nextDouble() * 1.8;
          if (a.type == AnimalType.jaguar) {
            a.showBadge('🐆 ROAR!', duration: 1.4);
            emitSound(SoundCue.jaguarRoar, worldX: a.x, worldY: a.y);
          } else if (a.type == AnimalType.snake) {
            emitSound(SoundCue.snakeHiss, worldX: a.x, worldY: a.y);
          }
        }
      } else if (!snakeOverride) {
        if (a.patrolTimer <= 0) {
          a.facingRight = _rng.nextBool();
          a.patrolTimer = 2.0 + _rng.nextDouble() * 2.5;
        }
        a.vx = (a.facingRight ? 0.55 : -0.55) * a.type.speed;
      }

      _moveLandOrAquaticAnimal(a, dt);

      if (!snakeOverride && distToPlayer < 24.0 && a.attackCooldown <= 0) {
        final midTx = pixelToTile((a.x + playerX) * 0.5);
        final midTy = pixelToTile(
          (a.y + playerY - 16.0) * 0.5,
        ).clamp(0, height - 1);
        if (!getBlock(midTx, midTy).isSolid) {
          a.attackCooldown = 1.35;
          health = (health - a.type.contactDamage).clamp(0.0, 100.0);
          playerHurtFlashTimer = 0.35;
          playerVx = (playerX >= a.x ? 1 : -1) * 175.0;
          playerVy = -130.0;
          if (a.type == AnimalType.jaguar) {
            a.showBadge('🐆 ROAR!', duration: 1.5);
            emitSound(
              SoundCue.jaguarRoar,
              worldX: a.x,
              worldY: a.y,
              baseVolume: 1.0,
            );
          } else if (a.type == AnimalType.snake) {
            a.showBadge('🐍 HISS!', duration: 1.5);
            emitSound(
              SoundCue.snakeHiss,
              worldX: a.x,
              worldY: a.y,
              baseVolume: 0.95,
            );
          }
          setBanner(
            '⚠️ Attacked by ${a.type.label} (-${a.type.contactDamage.round()} HP)! Plant 🌿 Herbs or 🌵 Briar Thorns for defense!',
          );
        }
      }
    }

    _updateSpatialBeeBuzzState();
  }

  void _updateSpatialBeeBuzzState() {
    double bestDist = 260.0;
    bool angry = false;
    double bestDx = 0.0;

    for (final a in animals) {
      if (a.type == AnimalType.beeSwarm) {
        final dx = a.x - playerX;
        final dy = a.y - (playerY - 16.0);
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < bestDist) {
          bestDist = d;
          angry = a.isAngry;
          bestDx = dx;
        }
      }
    }

    // Also check nearby hanging beehives within 5 tiles so hives gently hum.
    for (int dy = -4; dy <= 4; dy++) {
      for (int dx = -5; dx <= 5; dx++) {
        final tx = playerTileX + dx;
        final ty = (playerTileY + dy).clamp(0, height - 1);
        if (getBlock(tx, ty) == BlockType.beehive) {
          final wx = tx * tileSize + tileSize * 0.5;
          final wy = ty * tileSize + tileSize * 0.5;
          final d = math.sqrt(
            math.pow(wx - playerX, 2) + math.pow(wy - (playerY - 16.0), 2),
          );
          if (d < bestDist) {
            bestDist = d;
            bestDx = wx - playerX;
          }
        }
      }
    }

    if (bestDist < 260.0) {
      beeBuzzIntensity = (1.0 - (bestDist / 260.0)).clamp(0.0, 1.0);
      beeBuzzAngry = angry;
      beeBuzzPan = (bestDx / 200.0).clamp(-1.0, 1.0);
    } else {
      beeBuzzIntensity = 0.0;
      beeBuzzAngry = false;
      beeBuzzPan = 0.0;
    }
  }

  void _updateBeeSwarm(
    JungleAnimal a,
    double dt, {
    required bool playerInWater,
  }) {
    if (a.isAngry) {
      a.angryTimer -= dt;
      if (a.angryTimer <= 0 ||
          playerInWater ||
          hasBeeCalmingSmokeNear(playerTileX, playerTileY)) {
        a.isAngry = false;
      } else {
        final dx = playerX - a.x;
        final dy = (playerY - 18.0) - a.y;
        final dist = math.max(1.0, math.sqrt(dx * dx + dy * dy));
        a.facingRight = dx >= 0;
        a.x += (dx / dist) * a.type.speed * dt;
        a.y += (dy / dist) * a.type.speed * dt;
      }
    }

    if (!a.isAngry) {
      // Look for the closest flowering or growing crop to actively visit & pollinate!
      if (a.targetPlantTile == null && a.interactionTimer <= 0) {
        CropPlot? chosenCrop;
        double bestDist = 300.0;
        for (final crop in crops.values) {
          final cx = crop.tileX * tileSize + tileSize * 0.5;
          final cy = crop.tileY * tileSize + tileSize * 0.5;
          if ((cx - a.homeX).abs() <= 290.0 && (cy - a.homeY).abs() <= 220.0) {
            final d = (cx - a.x).abs() + (cy - a.y).abs();
            if (!crop.isPollinated && crop.isFlowering && d < bestDist) {
              bestDist = d;
              chosenCrop = crop;
            } else if (chosenCrop == null && d < bestDist) {
              chosenCrop = crop;
            }
          }
        }
        if (chosenCrop != null) {
          a.targetPlantTile = (chosenCrop.tileX, chosenCrop.tileY);
        } else {
          a.interactionTimer = 2.5;
        }
      }

      if (a.targetPlantTile case (final tx, final ty)) {
        final crop = crops['$tx,$ty'];
        if (crop == null) {
          a.targetPlantTile = null;
        } else {
          final targetX = tx * tileSize + tileSize * 0.5;
          final targetY = ty * tileSize + tileSize * 0.4;
          final dx = targetX - a.x;
          final dy = targetY - a.y;
          final dist = math.sqrt(dx * dx + dy * dy);
          a.facingRight = dx >= 0;
          if (dist > 12.0) {
            a.x += (dx / dist) * (a.type.speed * 0.78) * dt;
            a.y += (dy / dist) * (a.type.speed * 0.78) * dt;
          } else {
            // Reached the flower: pollinate it!
            crop.isPollinated = true;
            crop.growthProgress = (crop.growthProgress + 0.16).clamp(0.0, 1.0);
            a.showBadge('🌸 Pollinated!');
            a.targetPlantTile = null;
            a.interactionTimer = 4.0 + _rng.nextDouble() * 3.0;
            milestonePlantAnimalInteraction = true;
          }
        }
      } else {
        // Gentle figure-8 flight around home beehive.
        final orbitAngle = (timeOfDay * 600.0) + a.homeX * 0.1;
        final targetX = a.homeX + math.cos(orbitAngle) * 34.0;
        final targetY = a.homeY + math.sin(orbitAngle * 2.0) * 16.0;
        a.facingRight = targetX >= a.x;
        a.x += (targetX - a.x) * 3.0 * dt;
        a.y += (targetY - a.y) * 3.0 * dt;
      }
    }

    // Bee sting check when angry.
    if (a.isAngry && a.attackCooldown <= 0) {
      final distToPlayer = math.sqrt(
        math.pow(playerX - a.x, 2) + math.pow((playerY - 16.0) - a.y, 2),
      );
      if (distToPlayer < 22.0) {
        final midTx = pixelToTile((a.x + playerX) * 0.5);
        final midTy = pixelToTile(
          (a.y + playerY - 16.0) * 0.5,
        ).clamp(0, height - 1);
        if (!getBlock(midTx, midTy).isSolid) {
          a.attackCooldown = 1.2;
          health = (health - a.type.contactDamage).clamp(0.0, 100.0);
          playerHurtFlashTimer = 0.3;
          emitSound(
            SoundCue.beeBuzzAngry,
            worldX: a.x,
            worldY: a.y,
            baseVolume: 0.95,
          );
          setBanner(
            '🐝 Stung by Angry Bees (-${a.type.contactDamage.round()} HP)! Hold a 🕯️ Torch, plant 💡 Glow-Bulbs, or dive in water!',
          );
        }
      }
    }
  }

  void _updateToucan(JungleAnimal a, double dt) {
    // 0. Predator alarm scream: if a prowling Jaguar or Viper is near the
    // toucan, it lets out a piercing tropical alarm scream!
    if (a.patrolTimer <= 0) {
      for (final predator in animals) {
        if ((predator.type == AnimalType.jaguar ||
                predator.type == AnimalType.snake) &&
            (predator.x - a.x).abs() <= 185.0 &&
            (predator.y - a.y).abs() <= 140.0) {
          a.patrolTimer = 5.5 + _rng.nextDouble() * 3.0;
          a.showBadge('🦜 SCREAM! (${predator.type.label}!)', duration: 2.4);
          emitSound(
            SoundCue.toucanScream,
            worldX: a.x,
            worldY: a.y,
            baseVolume: 0.95,
          );
          break;
        }
      }
    }

    // 1. If the toucan has eaten a fruit and is carrying a seed, fly to open
    // fertile soil and sow it!
    if (a.carriedSeed case final seedToSow?) {
      if (a.targetPlantTile == null) {
        final centerTx = pixelToTile(a.x);
        final centerTy = pixelToTile(a.y).clamp(2, height - 4);
        final sowed = _disperseWildSeedNear(centerTx, centerTy, seedToSow);
        a.carriedSeed = null;
        a.interactionTimer = 5.5 + _rng.nextDouble() * 3.5;
        a.showBadge(
          sowed
              ? '🌱 Sowed ${seedToSow.icon}!'
              : '🦜 Digested ${seedToSow.icon}!',
          duration: 3.0,
        );
        return;
      }
      final (tx, ty) = a.targetPlantTile!;
      final targetX = tx * tileSize + tileSize * 0.5;
      final targetY = ty * tileSize;
      final dx = targetX - a.x;
      final dy = targetY - a.y;
      final dist = math.sqrt(dx * dx + dy * dy);
      a.facingRight = dx >= 0;
      if (dist > 14.0) {
        a.x += (dx / dist) * (a.type.speed * 0.9) * dt;
        a.y += (dy / dist) * (a.type.speed * 0.9) * dt;
      } else {
        final sowed = _disperseWildSeedNear(tx, ty, seedToSow);
        a.carriedSeed = null;
        a.targetPlantTile = null;
        a.interactionTimer = 5.5 + _rng.nextDouble() * 3.5;
        a.showBadge(
          sowed
              ? '🌱 Sowed ${seedToSow.icon}!'
              : '🦜 Dropped ${seedToSow.icon}!',
          duration: 3.0,
        );
      }
      return;
    }

    // 2. Otherwise, when hungry (interactionTimer <= 0), search for the closest
    // ripe fruit crop or wild berry bush to eat!
    if (a.targetPlantTile == null && a.interactionTimer <= 0) {
      CropPlot? ripeFruitCrop;
      double bestRipeDist = 360.0;
      CropPlot? floweringCrop;
      double bestFlowerDist = 360.0;
      for (final crop in crops.values) {
        final cx = crop.tileX * tileSize + tileSize * 0.5;
        final dx = (cx - a.x).abs();
        if (dx <= 360.0) {
          if (crop.isMature &&
              crop.seedType != ItemType.thornVineSeeds &&
              crop.seedType != ItemType.mahoganySapling &&
              dx < bestRipeDist) {
            bestRipeDist = dx;
            ripeFruitCrop = crop;
          } else if (!crop.isPollinated &&
              crop.isFlowering &&
              dx < bestFlowerDist) {
            bestFlowerDist = dx;
            floweringCrop = crop;
          }
        }
      }
      final chosenCrop = ripeFruitCrop ?? floweringCrop;
      if (chosenCrop != null) {
        a.targetPlantTile = (chosenCrop.tileX, chosenCrop.tileY);
      } else {
        // Search for a nearby wild berryBush block to eat berries from!
        final centerTx = pixelToTile(a.x);
        (int, int)? bushTile;
        for (int dx = -10; dx <= 10 && bushTile == null; dx++) {
          final tx = centerTx + dx;
          for (int ty = 12; ty < height - 6; ty++) {
            if (getBlock(tx, ty) == BlockType.berryBush) {
              bushTile = (tx, ty);
              break;
            }
          }
        }
        if (bushTile != null) {
          a.targetPlantTile = bushTile;
        } else {
          a.interactionTimer = 4.0 + _rng.nextDouble() * 3.0;
        }
      }
    }

    if (a.targetPlantTile case (final tx, final ty)) {
      final crop = crops['$tx,$ty'];
      final isBerryBush = getBlock(tx, ty) == BlockType.berryBush;
      if (crop == null && !isBerryBush) {
        a.targetPlantTile = null;
      } else {
        final targetX = tx * tileSize + tileSize * 0.5;
        final targetY = ty * tileSize;
        final dx = targetX - a.x;
        final dy = targetY - a.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        a.facingRight = dx >= 0;
        if (dist > 14.0) {
          a.x += (dx / dist) * (a.type.speed * 0.85) * dt;
          a.y += (dy / dist) * (a.type.speed * 0.85) * dt;
        } else {
          const exoticSeeds = [
            ItemType.berrySeeds,
            ItemType.mangoSeeds,
            ItemType.bananaSeeds,
            ItemType.glowBulbSeeds,
            ItemType.healingHerbSeeds,
            ItemType.pitcherPlantSeeds,
            ItemType.mahoganySapling,
          ];
          if (crop != null && crop.isMature) {
            // Toucan eats the ripe fruit from the crop and carries a seed to sow!
            final eatenFruit = crop.harvestedFruit;
            crop.growthProgress = 0.52;
            crop.isFertilized = true;
            crop.isPollinated = true;
            a.carriedSeed =
                _rng.nextDouble() < 0.5
                    ? crop.seedType
                    : exoticSeeds[_rng.nextInt(exoticSeeds.length)];
            a.showBadge('🥭 Ate ${eatenFruit.icon}!', duration: 2.8);
          } else if (crop != null) {
            crop.isPollinated = true;
            crop.growthProgress = (crop.growthProgress + 0.18).clamp(0.0, 1.0);
            a.carriedSeed = exoticSeeds[_rng.nextInt(exoticSeeds.length)];
            a.showBadge('🦜 Pollinated!', duration: 2.5);
          } else {
            // Toucan eats a wild berry from a jungle berryBush!
            a.carriedSeed = exoticSeeds[_rng.nextInt(exoticSeeds.length)];
            a.showBadge('🫐 Ate Wild Berry!', duration: 2.8);
          }
          // Pick an offset tile nearby to fly to and drop the digested seed.
          final dropTx = tx + (_rng.nextBool() ? 3 : -3);
          a.targetPlantTile = (dropTx, ty);
          milestonePlantAnimalInteraction = true;
          final ateRipeFruit = crop == null || crop.growthProgress == 0.52;
          emitSound(
            ateRipeFruit ? SoundCue.toucanScream : SoundCue.toucanCall,
            worldX: a.x,
            worldY: a.y,
          );
        }
      }
    } else {
      final flightAngle = (timeOfDay * 320.0) + a.homeX * 0.05;
      final targetX = a.homeX + math.sin(flightAngle) * 110.0;
      final targetY = a.homeY + math.cos(flightAngle * 1.7) * 22.0;
      a.facingRight = targetX >= a.x;
      a.x += (targetX - a.x) * 1.8 * dt;
      a.y += (targetY - a.y) * 1.8 * dt;

      // Periodic canopy scream/call when flying within earshot of the explorer!
      if (a.patrolTimer <= 0 && (a.x - playerX).abs() <= 320.0) {
        a.patrolTimer = 7.5 + _rng.nextDouble() * 5.5;
        final scream = _rng.nextBool();
        a.showBadge(scream ? '🦜 KREE-AAK!' : '🦜 Croak!', duration: 1.8);
        emitSound(
          scream ? SoundCue.toucanScream : SoundCue.toucanCall,
          worldX: a.x,
          worldY: a.y,
          baseVolume: 0.82,
        );
      }
    }
  }

  void _updateCapuchinMonkey(JungleAnimal a, double dt) {
    // Warn if a jaguar is prowling nearby!
    for (final predator in animals) {
      if (predator.type == AnimalType.jaguar &&
          (predator.x - a.x).abs() <= 160.0) {
        if (a.badgeTimer <= 0) {
          a.showBadge('🚨 Jaguar!', duration: 1.5);
        }
        break;
      }
    }

    // Look for the closest ripe crop to interact with when interactionTimer expires.
    if (a.targetPlantTile == null && a.interactionTimer <= 0) {
      CropPlot? chosenCrop;
      double bestDist = 280.0;
      for (final crop in crops.values) {
        final cx = crop.tileX * tileSize + tileSize * 0.5;
        final dx = (cx - a.x).abs();
        if (dx <= 280.0 && crop.isMature && dx < bestDist) {
          if (a.isTamed ||
              crop.seedType == ItemType.bananaSeeds ||
              crop.seedType == ItemType.berrySeeds ||
              crop.seedType == ItemType.mangoSeeds) {
            bestDist = dx;
            chosenCrop = crop;
          }
        }
      }
      if (chosenCrop != null) {
        a.targetPlantTile = (chosenCrop.tileX, chosenCrop.tileY);
      } else {
        a.interactionTimer = 2.0 + _rng.nextDouble() * 2.0;
      }
    }

    if (a.targetPlantTile case (final tx, final ty)) {
      final crop = crops['$tx,$ty'];
      if (crop == null || !crop.isMature) {
        a.targetPlantTile = null;
      } else {
        final targetX = tx * tileSize + tileSize * 0.5;
        final dx = targetX - a.x;
        a.facingRight = dx >= 0;
        if (dx.abs() > 18.0) {
          a.vx = (dx >= 0 ? 1.0 : -1.0) * a.type.speed;
        } else {
          a.vx = 0.0;
          if (a.isTamed) {
            // Befriended helper monkey harvests ripe crop into explorer's pack & replants!
            final product = crop.harvestedFruit;
            addItem(product, 2);
            addItem(crop.seedType, 1);
            crop.growthProgress = 0.45;
            crop.isFertilized = true;
            crop.isPollinated = false;
            milestoneHarvestedFruit = true;
            milestonePlantAnimalInteraction = true;
            a.showBadge('🧺 Harvested ${product.icon}!', duration: 3.0);
            setBanner(
              '🐒 Your befriended Capuchin Monkey harvested 2x ${product.icon} ${product.label} & replanted the plot!',
            );
          } else {
            // Wild monkey nibbles fruit, fertilizes the plot, and disperses a seed nearby!
            crop.growthProgress = 0.50;
            crop.isFertilized = true;
            final sowed = _disperseWildSeedNear(tx, ty, crop.seedType);
            milestonePlantAnimalInteraction = true;
            a.showBadge(
              sowed ? '🌱 Dispersed ${crop.seedType.icon}!' : '🍌 Foraging!',
              duration: 3.0,
            );
          }
          a.targetPlantTile = null;
          a.interactionTimer = 5.0 + _rng.nextDouble() * 3.0;
          emitSound(SoundCue.monkeyChatter, worldX: a.x, worldY: a.y);
        }
      }
    } else if (a.isTamed) {
      // Befriended monkey stays loosely near the explorer.
      final dxToPlayer = playerX - a.x;
      if (dxToPlayer.abs() > 96.0) {
        a.facingRight = dxToPlayer >= 0;
        a.vx = (dxToPlayer >= 0 ? 0.85 : -0.85) * a.type.speed;
      } else {
        if (a.patrolTimer <= 0) {
          a.facingRight = _rng.nextBool();
          a.patrolTimer = 2.2 + _rng.nextDouble() * 2.0;
        }
        a.vx = (a.facingRight ? 0.35 : -0.35) * a.type.speed;
      }
    } else {
      if (a.patrolTimer <= 0) {
        a.facingRight = _rng.nextBool();
        a.patrolTimer = 2.0 + _rng.nextDouble() * 2.5;
      }
      a.vx = (a.facingRight ? 0.55 : -0.55) * a.type.speed;
    }

    _moveLandOrAquaticAnimal(a, dt);
  }

  void _updatePiranha(
    JungleAnimal a,
    double dt, {
    required bool playerInWater,
  }) {
    // Ensure the piranha stays inside a water block; if displaced onto a bank,
    // relocate it to the nearest water tile in the lagoon.
    final curTx = pixelToTile(a.x);
    final curTy = pixelToTile(a.y - 6.0).clamp(0, height - 1);
    if (getBlock(curTx, curTy) != BlockType.water) {
      bool relocated = false;
      for (int r = 1; r <= 3 && !relocated; r++) {
        for (int dy = -r; dy <= r && !relocated; dy++) {
          for (int dx = -r; dx <= r && !relocated; dx++) {
            final nx = curTx + dx;
            final ny = (curTy + dy).clamp(0, height - 1);
            if (getBlock(nx, ny) == BlockType.water) {
              a.x = nx * tileSize + tileSize * 0.5;
              a.y = ny * tileSize + tileSize * 0.5;
              relocated = true;
            }
          }
        }
      }
      if (!relocated) return;
    }

    final calmed = _hasGlowBulbNearWater(curTx, curTy);
    if (calmed) {
      a.showBadge('💡 Calmed', duration: 1.5);
      milestonePlantAnimalInteraction = true;
    }

    final dxToPlayer = playerX - a.x;
    final dyToPlayer = (playerY - 12.0) - (a.y - 6.0);
    final distToPlayer = math.sqrt(
      dxToPlayer * dxToPlayer + dyToPlayer * dyToPlayer,
    );
    final aggroRange = isNight ? 240.0 : 175.0;

    // Only dart toward the explorer when the explorer is actually in the water!
    // When the explorer is on dry land, piranhas continuously patrol back and
    // forth across the full width of the river lagoon without getting pinned
    // against the riverbank.
    if (playerInWater && !calmed && distToPlayer < aggroRange) {
      if (dxToPlayer.abs() > 6.0) {
        a.facingRight = dxToPlayer >= 0;
      }
      a.vx = (a.facingRight ? 1.15 : -1.15) * a.type.speed;
      a.vy = (dyToPlayer * 2.2).clamp(-65.0, 65.0);
      if (a.interactionTimer <= 0) {
        a.interactionTimer = 2.8 + _rng.nextDouble() * 1.5;
        a.showBadge('🐟 SNAP!', duration: 1.1);
        emitSound(
          SoundCue.piranhaSplash,
          worldX: a.x,
          worldY: a.y,
          baseVolume: 0.75,
        );
      }
    } else {
      if (a.patrolTimer <= 0) {
        a.facingRight = !a.facingRight;
        a.patrolTimer = 4.5 + _rng.nextDouble() * 3.0;
      }
      final swimFactor = calmed ? 0.85 : 1.0;
      a.vx = (a.facingRight ? swimFactor : -swimFactor) * a.type.speed;
      final wavePhase = timeOfDay * 75.0 + a.homeX * 0.05;
      a.vy = math.sin(wavePhase) * 22.0;
    }

    // Advance horizontally through water, following sloped riverbed contours
    // and reversing cleanly only when reaching a solid riverbank.
    final nextX = a.x + a.vx * dt;
    final nextTx = pixelToTile(nextX);
    final lookAheadX = nextX + (a.facingRight ? 10.0 : -10.0);
    final frontTx = pixelToTile(lookAheadX);
    final swimTy = pixelToTile(a.y - 6.0).clamp(0, height - 1);

    if (getBlock(frontTx, swimTy) == BlockType.water &&
        getBlock(nextTx, swimTy) == BlockType.water) {
      a.x = nextX;
    } else if (swimTy - 1 >= 0 &&
        getBlock(frontTx, swimTy - 1) == BlockType.water &&
        getBlock(curTx, swimTy - 1) == BlockType.water) {
      a.y = (swimTy - 1) * tileSize + tileSize * 0.55;
      a.x = nextX;
    } else if (swimTy + 1 < height &&
        getBlock(frontTx, swimTy + 1) == BlockType.water &&
        getBlock(curTx, swimTy + 1) == BlockType.water) {
      a.y = (swimTy + 1) * tileSize + tileSize * 0.45;
      a.x = nextX;
    } else {
      a.facingRight = !a.facingRight;
      a.vx = -a.vx;
      a.patrolTimer = 4.5 + _rng.nextDouble() * 3.0;
      final revX = a.x + a.vx * dt;
      if (getBlock(pixelToTile(revX), swimTy) == BlockType.water) {
        a.x = revX;
      }
    }

    // Apply vertical swimming undulation within the water column.
    final nextY = a.y + a.vy * dt;
    final checkTx = pixelToTile(a.x);
    final nextTy = pixelToTile(nextY - 6.0).clamp(0, height - 1);
    final upperTy = pixelToTile(nextY - 12.0).clamp(0, height - 1);
    final lowerTy = pixelToTile(nextY + 1.0).clamp(0, height - 1);
    if (getBlock(checkTx, nextTy) == BlockType.water &&
        getBlock(checkTx, upperTy) == BlockType.water &&
        !getBlock(checkTx, lowerTy).isSolid) {
      a.y = nextY;
    }

    // Contact bite when explorer is in the water within striking range.
    if (playerInWater &&
        !calmed &&
        distToPlayer < 24.0 &&
        a.attackCooldown <= 0) {
      a.attackCooldown = 1.35;
      health = (health - a.type.contactDamage).clamp(0.0, 100.0);
      playerHurtFlashTimer = 0.35;
      playerVx = (playerX >= a.x ? 1 : -1) * 175.0;
      playerVy = -130.0;
      a.showBadge('🐟 SNAP!', duration: 1.4);
      emitSound(
        SoundCue.piranhaSplash,
        worldX: a.x,
        worldY: a.y,
        baseVolume: 0.90,
      );
      setBanner(
        '⚠️ Bitten by ${a.type.label} (-${a.type.contactDamage.round()} HP)! Plant 💡 Glow-Bulbs on the riverbank to calm piranhas!',
      );
    }
  }

  void _moveLandOrAquaticAnimal(JungleAnimal a, double dt) {
    if (a.type.aquatic) {
      final nextX = a.x + a.vx * dt;
      final tx = pixelToTile(nextX);
      final ty = pixelToTile(a.y - 8).clamp(0, height - 1);
      if (getBlock(tx, ty) == BlockType.water) {
        a.x = nextX;
      } else {
        a.facingRight = !a.facingRight;
      }
    } else {
      a.vy = (a.vy + 520.0 * dt).clamp(-260.0, 360.0);
      final nextX = a.x + a.vx * dt;
      final frontTx = pixelToTile(nextX + (a.facingRight ? 10 : -10));
      final bodyTy = pixelToTile(a.y - 10).clamp(0, height - 1);

      final frontBlock = getBlock(frontTx, bodyTy);
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
      final footTy = pixelToTile(nextY).clamp(0, height - 1);
      if (!getBlock(pixelToTile(a.x), footTy).isSolid) {
        a.y = nextY;
      } else {
        a.vy = 0.0;
      }
    }
  }
}
