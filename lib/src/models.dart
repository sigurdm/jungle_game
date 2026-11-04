import 'dart:ui';

/// Foreground block types in the 2D side-scrolling jungle world.
///
/// Each tile cell in the foreground grid contains exactly one [BlockType].
/// Solid blocks prevent player and land-animal movement, whereas non-solid
/// blocks (such as [air], [water], [vine], [torch], [campfire], [wildfire],
/// and [beehive]) allow entities to pass through.
enum BlockType {
  /// Empty space.
  air(
    label: 'Air',
    isSolid: false,
    hardness: 0.0,
    flammability: 0.0,
    primaryColor: Color(0x00000000),
    accentColor: Color(0x00000000),
  ),

  /// Lush jungle surface turf that can be tilled or mined for dirt and seeds.
  grass(
    label: 'Jungle Grass',
    isSolid: true,
    hardness: 0.45,
    flammability: 0.15,
    primaryColor: Color(0xFF2E7D32),
    accentColor: Color(0xFF5D4037),
  ),

  /// Rich jungle soil below the surface turf.
  dirt(
    label: 'Jungle Dirt',
    isSolid: true,
    hardness: 0.4,
    flammability: 0.0,
    primaryColor: Color(0xFF6D4C41),
    accentColor: Color(0xFF4E342E),
  ),

  /// Tilled farmland capable of growing sowed crop seeds.
  tilledSoil(
    label: 'Tilled Soil',
    isSolid: true,
    hardness: 0.4,
    flammability: 0.0,
    primaryColor: Color(0xFF4E342E),
    accentColor: Color(0xFF3E2723),
  ),

  /// Moisture-retaining mineral silt found along river lagoons and cavern pools.
  riverSilt(
    label: 'Alluvial River Silt',
    isSolid: true,
    hardness: 0.38,
    flammability: 0.0,
    primaryColor: Color(0xFF37474F),
    accentColor: Color(0xFF26C6DA),
  ),

  /// Acidic, spongy moss-peat soil found in botanical groves and shaded bogs.
  peatBog(
    label: 'Mossy Peat Bog',
    isSolid: true,
    hardness: 0.35,
    flammability: 0.10,
    primaryColor: Color(0xFF3B2840),
    accentColor: Color(0xFF76FF03),
  ),

  /// Warm, mineral-dense volcanic ash soil found on misty highland ridges.
  volcanicAsh(
    label: 'Volcanic Highland Ash',
    isSolid: true,
    hardness: 0.50,
    flammability: 0.0,
    primaryColor: Color(0xFF2D272C),
    accentColor: Color(0xFFFF8F00),
  ),

  /// Dense underground stone requiring a pickaxe for fast mining.
  stone(
    label: 'Jungle Stone',
    isSolid: true,
    hardness: 1.1,
    flammability: 0.0,
    primaryColor: Color(0xFF607D8B),
    accentColor: Color(0xFF455A64),
  ),

  /// Coal vein embedded in stone, useful for crafting torches and campfires.
  coalOre(
    label: 'Coal Ore',
    isSolid: true,
    hardness: 1.3,
    flammability: 0.0,
    primaryColor: Color(0xFF546E7A),
    accentColor: Color(0xFF212121),
  ),

  /// Iron ore vein embedded in deep underground stone.
  ironOre(
    label: 'Iron Ore',
    isSolid: true,
    hardness: 1.6,
    flammability: 0.0,
    primaryColor: Color(0xFF546E7A),
    accentColor: Color(0xFFD7CCC8),
  ),

  /// Mahogany tree trunk that can be chopped for wood logs.
  woodLog(
    label: 'Mahogany Log',
    isSolid: false,
    hardness: 0.65,
    flammability: 0.45,
    primaryColor: Color(0xFF5D4037),
    accentColor: Color(0xFF3E2723),
  ),

  /// Jungle tree canopy leaves that drop thatch bundles, fruits, and seeds.
  leaves(
    label: 'Canopy Leaves',
    isSolid: false,
    hardness: 0.25,
    flammability: 0.85,
    primaryColor: Color(0xFF1B5E20),
    accentColor: Color(0xFF43A047),
  ),

  /// Climbable hanging jungle vine that drops vine fibers and wild seeds.
  vine(
    label: 'Jungle Vine',
    isSolid: false,
    hardness: 0.2,
    flammability: 0.75,
    primaryColor: Color(0xFF388E3C),
    accentColor: Color(0xFF81C784),
  ),

  /// Wild berry bush on the jungle floor that drops berries and berry seeds.
  berryBush(
    label: 'Wild Fruit Bush',
    isSolid: false,
    hardness: 0.25,
    flammability: 0.70,
    primaryColor: Color(0xFF2E7D32),
    accentColor: Color(0xFFE53935),
  ),

  /// River or lagoon water block that flows with gravity, extinguishes fire,
  /// and supports swimming and fishing.
  water(
    label: 'River Water',
    isSolid: false,
    hardness: 0.0,
    flammability: 0.0,
    primaryColor: Color(0xB30288D1),
    accentColor: Color(0xB34FC3F7),
  ),

  /// Crafted solid wood plank block used for shelter walls, floors, and roofs.
  woodPlank(
    label: 'Wood Plank',
    isSolid: true,
    hardness: 0.6,
    flammability: 0.35,
    primaryColor: Color(0xFF8D6E63),
    accentColor: Color(0xFF5D4037),
  ),

  /// Crafted insulated thatch roof block that keeps out rain and night chill.
  thatchRoof(
    label: 'Thatch Roof',
    isSolid: true,
    hardness: 0.45,
    flammability: 0.65,
    primaryColor: Color(0xFFC0CA33),
    accentColor: Color(0xFF9E9D24),
  ),

  /// Closed shelter door that blocks dangerous animals and insulates shelters.
  doorClosed(
    label: 'Closed Door',
    isSolid: true,
    hardness: 0.6,
    flammability: 0.30,
    primaryColor: Color(0xFF795548),
    accentColor: Color(0xFFFFB300),
  ),

  /// Open shelter door that allows the explorer to walk through.
  doorOpen(
    label: 'Open Door',
    isSolid: false,
    hardness: 0.6,
    flammability: 0.30,
    primaryColor: Color(0x99795548),
    accentColor: Color(0xFFFFB300),
  ),

  /// Placed campfire that radiates strong heat and allows cooking raw fish.
  campfire(
    label: 'Campfire',
    isSolid: false,
    hardness: 0.4,
    flammability: 0.0,
    primaryColor: Color(0xFFFF6F00),
    accentColor: Color(0xFFFFCA28),
  ),

  /// Placed torch that illuminates surroundings, calms bees with smoke, and
  /// provides mild warmth.
  torch(
    label: 'Torch',
    isSolid: false,
    hardness: 0.15,
    flammability: 0.0,
    primaryColor: Color(0xFFFFB300),
    accentColor: Color(0xFFFFF176),
  ),

  /// Active spreading wildfire that consumes flammable foliage and wood unless
  /// doused by water or rain.
  wildfire(
    label: 'Spreading Wildfire',
    isSolid: false,
    hardness: 0.1,
    flammability: 0.0,
    primaryColor: Color(0xFFFF3D00),
    accentColor: Color(0xFFFFEA00),
  ),

  /// Golden honeycomb beehive hanging beneath tree canopies or placed near
  /// crops to produce honey and pollinate farms.
  beehive(
    label: 'Honeycomb Beehive',
    isSolid: false,
    hardness: 0.45,
    flammability: 0.50,
    primaryColor: Color(0xFFFFB300),
    accentColor: Color(0xFFFF8F00),
  ),

  /// Indestructible or sturdy native village structure timber.
  villageHutBlock(
    label: 'Village Timber',
    isSolid: true,
    hardness: 2.5,
    flammability: 0.0,
    primaryColor: Color(0xFF6D4C41),
    accentColor: Color(0xFFFFCC80),
  );

  const BlockType({
    required this.label,
    required this.isSolid,
    required this.hardness,
    required this.flammability,
    required this.primaryColor,
    required this.accentColor,
  });

  /// Human-readable display name of the block.
  final String label;

  /// Whether entities collide with this block.
  final bool isSolid;

  /// Base time in seconds required to break this block by hand.
  final double hardness;

  /// Probability factor (`0.0..1.0`) that adjacent fire ignites this block.
  final double flammability;

  /// Primary fill color for procedural tile rendering.
  final Color primaryColor;

  /// Secondary accent color for procedural tile rendering.
  final Color accentColor;

  /// Whether this block acts as an overhead roof for cold shelter calculation.
  bool get countsAsRoof =>
      isSolid ||
      this == BlockType.woodPlank ||
      this == BlockType.thatchRoof ||
      this == BlockType.villageHutBlock;

  /// Whether seeds and saplings can be sowed on this ground block.
  bool get isSowableSoil => soilType != null;

  /// The [SoilType] corresponding to this ground block, or `null` if not soil.
  SoilType? get soilType => switch (this) {
    BlockType.grass ||
    BlockType.dirt ||
    BlockType.tilledSoil => SoilType.jungleLoam,
    BlockType.riverSilt => SoilType.riverSilt,
    BlockType.peatBog => SoilType.peatBog,
    BlockType.volcanicAsh => SoilType.volcanicAsh,
    _ => null,
  };
}

/// Distinct soil substrates that favor or hinder different plant varieties.
enum SoilType {
  /// Balanced humus-rich rainforest loam (`grass`, `dirt`, `tilledSoil`).
  jungleLoam(
    label: 'Jungle Loam',
    icon: '🌱',
    summary: 'Balanced humus soil. Great for Berries, Bananas & Mahogany.',
  ),

  /// Wet mineral-rich river silt (`BlockType.riverSilt`).
  riverSilt(
    label: 'Alluvial River Silt',
    icon: '🌊',
    summary:
        'Moisture-rich floodplain silt. Boosts Bananas, Glow-Bulbs & Mangoes; waterlogs Briars & Herbs.',
  ),

  /// Spongy, acidic bog peat (`BlockType.peatBog`).
  peatBog(
    label: 'Mossy Peat Bog',
    icon: '🌺',
    summary:
        'Acidic bog substrate. Ideal for Pitcher Plants, Glow-Bulbs & Herbs; too acidic for Mangoes & Bananas.',
  ),

  /// Mineral-dense dark volcanic ash (`BlockType.volcanicAsh`).
  volcanicAsh(
    label: 'Volcanic Highland Ash',
    icon: '🌋',
    summary:
        'Warm mineral ash. Ideal for Briar Thorns, Golden Mangoes, Herbs & Mahogany; dries out Bog plants.',
  );

  const SoilType({
    required this.label,
    required this.icon,
    required this.summary,
  });

  /// Display name of the soil substrate.
  final String label;

  /// Emoji badge representing the soil.
  final String icon;

  /// Short description of which plants thrive or struggle in this soil.
  final String summary;

  /// Returns the base growth rate multiplier (`0.45..1.80`) for [seedType] when
  /// planted in this soil.
  double soilMultiplierFor(ItemType seedType) => switch (this) {
    SoilType.jungleLoam => switch (seedType) {
      ItemType.berrySeeds => 1.35,
      ItemType.bananaSeeds => 1.25,
      ItemType.mahoganySapling => 1.45,
      ItemType.mangoSeeds => 1.05,
      ItemType.healingHerbSeeds => 1.15,
      ItemType.thornVineSeeds => 1.15,
      ItemType.glowBulbSeeds => 0.80,
      ItemType.pitcherPlantSeeds => 0.78,
      _ => 1.0,
    },
    SoilType.riverSilt => switch (seedType) {
      ItemType.bananaSeeds => 1.65,
      ItemType.glowBulbSeeds => 1.55,
      ItemType.mangoSeeds => 1.45,
      ItemType.pitcherPlantSeeds => 1.40,
      ItemType.berrySeeds => 1.15,
      ItemType.mahoganySapling => 1.10,
      ItemType.healingHerbSeeds => 0.58,
      ItemType.thornVineSeeds => 0.50,
      _ => 1.0,
    },
    SoilType.peatBog => switch (seedType) {
      ItemType.pitcherPlantSeeds => 1.80,
      ItemType.glowBulbSeeds => 1.75,
      ItemType.healingHerbSeeds => 1.55,
      ItemType.berrySeeds => 0.95,
      ItemType.bananaSeeds => 0.62,
      ItemType.mahoganySapling => 0.60,
      ItemType.thornVineSeeds => 0.58,
      ItemType.mangoSeeds => 0.52,
      _ => 1.0,
    },
    SoilType.volcanicAsh => switch (seedType) {
      ItemType.thornVineSeeds => 1.70,
      ItemType.mangoSeeds => 1.60,
      ItemType.healingHerbSeeds => 1.50,
      ItemType.mahoganySapling => 1.40,
      ItemType.berrySeeds => 0.58,
      ItemType.bananaSeeds => 0.55,
      ItemType.glowBulbSeeds => 0.48,
      ItemType.pitcherPlantSeeds => 0.45,
      _ => 1.0,
    },
  };
}

/// Background wall types used to enclose interior shelter spaces in 2D.
///
/// In a side-scrolling 2D block game, background walls allow the explorer to
/// walk freely inside a room while insulating the interior from cold night air.
enum WallType {
  /// Open air background (not enclosed).
  none('Open Sky', Color(0x00000000)),

  /// Natural underground dirt/stone cavern background wall.
  dirtWall('Cavern Wall', Color(0xFF3E2723)),

  /// Crafted wooden background wall that insulates player-built shelters.
  woodWall('Wood Wall', Color(0xFF4E342E)),

  /// Crafted woven thatch background wall that insulates player-built shelters.
  thatchWall('Thatch Wall', Color(0xFF827717)),

  /// Native village bamboo/thatch wall.
  villageWall('Village Wall', Color(0xFF5D4037));

  const WallType(this.label, this.color);

  /// Display name of the background wall.
  final String label;

  /// Procedural fill color rendered behind foreground tiles.
  final Color color;

  /// Whether this background wall insulates against cold night temperatures.
  bool get providesInsulation => this != WallType.none;
}

/// Surface biome zones generated procedurally across the horizontal world.
enum JungleBiome {
  /// Dense mahogany canopy with hanging vines, beehives, monkeys, and toucans.
  canopyForest(label: 'Emerald Canopy', icon: '🌴', elevationOffset: 0.0),

  /// Low-lying river lagoon and wetland basin with fish, glow-bulbs, and piranhas.
  riverLagoon(label: 'River Lagoon', icon: '🏞️', elevationOffset: 5.5),

  /// Sunlit botanical clearing where wild crops and exotic seeds grow naturally.
  botanicalClearing(
    label: 'Wild Botanical Grove',
    icon: '🌺',
    elevationOffset: -0.5,
  ),

  /// Elevated misty jungle highland with stone cliffs, mango trees, and beehives.
  mistHighlands(label: 'Mist Highlands', icon: '⛰️', elevationOffset: -4.5),

  /// Flat stilt-hut clearing inhabited by friendly native villagers.
  nativeVillage(label: 'Native Village', icon: '🛖', elevationOffset: -1.0);

  const JungleBiome({
    required this.label,
    required this.icon,
    required this.elevationOffset,
  });

  /// Display name of the biome shown in the explorer HUD.
  final String label;

  /// Emoji badge representing the biome.
  final String icon;

  /// Relative vertical tile offset applied to the base surface elevation.
  final double elevationOffset;
}

/// Categories of inventory items held in the explorer's hotbar and pack.
enum ItemCategory {
  /// Mining, chopping, water bucket, and fishing tools.
  tool,

  /// Melee weapons used to defend against dangerous animals.
  weapon,

  /// Plantable crop seeds and saplings that can be sowed on dirt or grass.
  seed,

  /// Edible fruits, honey, nectar, cooked fish, and healing herbs.
  food,

  /// Placeable foreground blocks, beehives, doors, campfires, and walls.
  building,

  /// Raw crafting materials and wearable survival gear.
  material,
}

/// All collectible, craftable, and tradeable items in the game.
enum ItemType {
  // Tools & Weapons
  /// Starter wooden pickaxe for mining dirt, wood, and soft stone.
  woodPickaxe(
    label: 'Wood Pickaxe',
    icon: '⛏️',
    category: ItemCategory.tool,
    miningSpeedMultiplier: 1.8,
    attackDamage: 10.0,
  ),

  /// Upgraded stone pickaxe for mining coal and iron ore quickly.
  stonePickaxe(
    label: 'Stone Pickaxe',
    icon: '⚒️',
    category: ItemCategory.tool,
    miningSpeedMultiplier: 3.0,
    attackDamage: 14.0,
  ),

  /// Crafted wooden spear with extended reach against jaguars and snakes.
  woodSpear(
    label: 'Jungle Spear',
    icon: '🔱',
    category: ItemCategory.weapon,
    miningSpeedMultiplier: 1.0,
    attackDamage: 24.0,
  ),

  /// Forged or traded iron machete that clears foliage and deals heavy damage.
  ironMachete(
    label: 'Iron Machete',
    icon: '🗡️',
    category: ItemCategory.weapon,
    miningSpeedMultiplier: 2.4,
    attackDamage: 38.0,
  ),

  /// Crafted bamboo and vine fishing rod for catching river fish.
  fishingRod(
    label: 'Fishing Rod',
    icon: '🎣',
    category: ItemCategory.tool,
    miningSpeedMultiplier: 1.0,
    attackDamage: 6.0,
  ),

  /// Bamboo water bucket that scoops water or pours flowing water to douse fires.
  waterBucket(
    label: 'Water Bucket',
    icon: '🪣',
    category: ItemCategory.tool,
    placedBlock: BlockType.water,
  ),

  // Seeds & Saplings (8 distinct ecological plant varieties)
  /// Fast-growing wild jungle berry seeds that attract seed-dispersing wildlife.
  berrySeeds(
    label: 'Berry Seeds',
    icon: '🌱',
    category: ItemCategory.seed,
    seedGrowthFactor: 1.25,
    regrowsOnHarvest: true,
    ecologyNote:
        'Fast perennial bush. Attracts 🦜 Toucans & 🐒 Monkeys that disperse new seeds nearby.',
  ),

  /// Nutritious banana tree shoot seeds loved by capuchin monkeys.
  bananaSeeds(
    label: 'Banana Seeds',
    icon: '🌾',
    category: ItemCategory.seed,
    seedGrowthFactor: 1.0,
    regrowsOnHarvest: true,
    ecologyNote:
        'Tall banana palm. Favorite treat of 🐒 Monkeys—feed them bananas to befriend a farm helper!',
  ),

  /// Prized golden mango seeds obtained by trading with native villagers.
  mangoSeeds(
    label: 'Golden Mango Seeds',
    icon: '✨',
    category: ItemCategory.seed,
    seedGrowthFactor: 0.85,
    regrowsOnHarvest: true,
    ecologyNote:
        'Fragrant blossoms draw 🐝 Bees & 🦜 Toucans for cross-pollination and bonus golden mangoes.',
  ),

  /// Aromatic medicinal herb seeds whose scent wards off venomous snakes.
  healingHerbSeeds(
    label: 'Medicinal Herb Seeds',
    icon: '🌿',
    category: ItemCategory.seed,
    seedGrowthFactor: 1.15,
    regrowsOnHarvest: true,
    ecologyNote:
        'Yields healing poultices and emits a pungent herbal aura that repels 🐍 Emerald Vipers within 4 tiles!',
  ),

  /// Bioluminescent glow-bulb spores that illuminate the night and calm bees.
  glowBulbSeeds(
    label: 'Glow-Bulb Spores',
    icon: '💡',
    category: ItemCategory.seed,
    seedGrowthFactor: 1.1,
    regrowsOnHarvest: true,
    ecologyNote:
        'Shines with bioluminescent light at night, calms 🐝 Bees, and lures river fish while soothing 🐟 Piranhas.',
  ),

  /// Spiky briar thorn-vine seeds that form a defensive living hedge.
  thornVineSeeds(
    label: 'Briar Thorn Seeds',
    icon: '🌵',
    category: ItemCategory.seed,
    seedGrowthFactor: 1.2,
    regrowsOnHarvest: true,
    ecologyNote:
        'Defensive thorny hedge that pricks and knocks back hostile 🐆 Jaguars and 🐍 Vipers without blocking you.',
  ),

  /// Carnivorous jungle pitcher plant seeds that trap snakes and fertilize soil.
  pitcherPlantSeeds(
    label: 'Pitcher Plant Seeds',
    icon: '🌺',
    category: ItemCategory.seed,
    seedGrowthFactor: 0.95,
    regrowsOnHarvest: true,
    ecologyNote:
        'Carnivorous plant that lures & digests nearby 🐍 Vipers, secreting nectar and fertilizing adjacent crops (+60% growth)!',
  ),

  /// Mahogany tree sapling that grows into a full multi-tile canopy tree.
  mahoganySapling(
    label: 'Mahogany Sapling',
    icon: '🌳',
    category: ItemCategory.seed,
    seedGrowthFactor: 0.75,
    regrowsOnHarvest: false,
    ecologyNote:
        'Bursts into a full Mahogany Tree with canopy leaves, vines, and a chance to attract a wild 🪹 Beehive & 🐝 Bees!',
  ),

  // Fruits, Honey & Food
  /// Sweet wild berries that restore moderate hunger.
  jungleBerry(
    label: 'Jungle Berries',
    icon: '🫐',
    category: ItemCategory.food,
    hungerRestore: 18.0,
    healthRestore: 5.0,
  ),

  /// Energy-rich jungle banana harvested from crops or canopy trees.
  banana(
    label: 'Ripe Banana',
    icon: '🍌',
    category: ItemCategory.food,
    hungerRestore: 28.0,
    healthRestore: 8.0,
  ),

  /// Sweet golden mango prized by explorers and villagers alike.
  mango(
    label: 'Golden Mango',
    icon: '🥭',
    category: ItemCategory.food,
    hungerRestore: 42.0,
    healthRestore: 16.0,
  ),

  /// Exotic papaya fruit traded in native villages.
  papaya(
    label: 'Jungle Papaya',
    icon: '🍈',
    category: ItemCategory.food,
    hungerRestore: 36.0,
    healthRestore: 14.0,
  ),

  /// Bioluminescent fruit harvested from glow-bulb plants; warms the body.
  glowFruit(
    label: 'Glow-Lotus Fruit',
    icon: '🍐',
    category: ItemCategory.food,
    hungerRestore: 24.0,
    healthRestore: 18.0,
    warmthRestore: 22.0,
  ),

  /// Sweet enzymatic nectar harvested from carnivorous pitcher plants.
  jungleNectar(
    label: 'Pitcher Nectar',
    icon: '🧪',
    category: ItemCategory.food,
    hungerRestore: 22.0,
    healthRestore: 32.0,
    warmthRestore: 12.0,
  ),

  /// Pure golden honeycomb harvested from jungle beehives.
  honeycomb(
    label: 'Golden Honeycomb',
    icon: '🍯',
    category: ItemCategory.food,
    hungerRestore: 35.0,
    healthRestore: 28.0,
    warmthRestore: 12.0,
  ),

  /// Freshly caught raw river fish (best cooked at a campfire).
  rawFish(
    label: 'Raw River Fish',
    icon: '🐟',
    category: ItemCategory.food,
    hungerRestore: 14.0,
    healthRestore: 2.0,
  ),

  /// Hot campfire-roasted fish that restores hunger, health, and warmth.
  cookedFish(
    label: 'Roasted Fish',
    icon: '🐠',
    category: ItemCategory.food,
    hungerRestore: 48.0,
    healthRestore: 20.0,
    warmthRestore: 18.0,
  ),

  /// Medicinal jungle herb poultice that restores life points rapidly.
  healingHerb(
    label: 'Healing Poultice',
    icon: '🌿',
    category: ItemCategory.food,
    hungerRestore: 8.0,
    healthRestore: 40.0,
  ),

  // Building Blocks & Shelter Components
  /// Placeable wooden plank block for shelter roofs and walls.
  woodPlankItem(
    label: 'Wood Plank Block',
    icon: '🪵',
    category: ItemCategory.building,
    placedBlock: BlockType.woodPlank,
  ),

  /// Placeable insulated thatch roof block.
  thatchRoofItem(
    label: 'Thatch Roof Block',
    icon: '🛖',
    category: ItemCategory.building,
    placedBlock: BlockType.thatchRoof,
  ),

  /// Placeable wooden background wall for enclosing warm rooms.
  woodWallItem(
    label: 'Wood Background Wall',
    icon: '🧱',
    category: ItemCategory.building,
    placedWall: WallType.woodWall,
  ),

  /// Placeable thatch background wall for enclosing warm rooms.
  thatchWallItem(
    label: 'Thatch Background Wall',
    icon: '🎋',
    category: ItemCategory.building,
    placedWall: WallType.thatchWall,
  ),

  /// Placeable shelter door that keeps predators out and warmth inside.
  doorItem(
    label: 'Shelter Door',
    icon: '🚪',
    category: ItemCategory.building,
    placedBlock: BlockType.doorClosed,
  ),

  /// Placeable campfire that warms shelters, calms bees, and cooks fish.
  campfireItem(
    label: 'Campfire',
    icon: '🔥',
    category: ItemCategory.building,
    placedBlock: BlockType.campfire,
  ),

  /// Placeable torch that lights up caverns, calms bees, and warms huts.
  torchItem(
    label: 'Jungle Torch',
    icon: '🕯️',
    category: ItemCategory.building,
    placedBlock: BlockType.torch,
  ),

  /// Craftable wooden apiary beehive that produces honey and pollinates crops.
  woodenBeehiveItem(
    label: 'Crafted Beehive',
    icon: '🪹',
    category: ItemCategory.building,
    placedBlock: BlockType.beehive,
  ),

  /// Placeable dirt block for terraforming or farming plots.
  dirtBlock(
    label: 'Jungle Loam Block',
    icon: '🟫',
    category: ItemCategory.building,
    placedBlock: BlockType.dirt,
  ),

  /// Placeable alluvial river silt block for moisture-loving crops.
  riverSiltBlock(
    label: 'Alluvial Silt Block',
    icon: '🌊',
    category: ItemCategory.building,
    placedBlock: BlockType.riverSilt,
  ),

  /// Placeable mossy peat bog block for carnivorous & bioluminescent plants.
  peatBogBlock(
    label: 'Mossy Peat Block',
    icon: '🌺',
    category: ItemCategory.building,
    placedBlock: BlockType.peatBog,
  ),

  /// Placeable volcanic highland ash block for briar thorns, mangoes & herbs.
  volcanicAshBlock(
    label: 'Volcanic Ash Block',
    icon: '🌋',
    category: ItemCategory.building,
    placedBlock: BlockType.volcanicAsh,
  ),

  /// Placeable stone block for sturdy fireproof walls.
  stoneBlock(
    label: 'Stone Block',
    icon: '🪨',
    category: ItemCategory.building,
    placedBlock: BlockType.stone,
  ),

  // Raw Resources & Gear
  /// Raw mahogany timber harvested from trees.
  woodLogItem(
    label: 'Mahogany Log',
    icon: '🌲',
    category: ItemCategory.material,
  ),

  /// Strong vine cordage harvested from hanging jungle vines.
  vineFiber(label: 'Vine Fiber', icon: '🪢', category: ItemCategory.material),

  /// Dried palm and canopy leaves used for thatch roofing.
  thatchBundle(
    label: 'Thatch Bundle',
    icon: '🍃',
    category: ItemCategory.material,
  ),

  /// Mined coal chunk for campfires and torches.
  coalItem(label: 'Coal Lump', icon: '⚫', category: ItemCategory.material),

  /// Mined iron ore chunk for crafting or village trading.
  ironOreItem(label: 'Iron Ore', icon: '🔩', category: ItemCategory.material),

  /// Woven wool/fiber jungle poncho that halves night cold heat loss.
  warmPoncho(
    label: 'Warm Jungle Poncho',
    icon: '🧥',
    category: ItemCategory.material,
  );

  const ItemType({
    required this.label,
    required this.icon,
    required this.category,
    this.miningSpeedMultiplier = 1.0,
    this.attackDamage = 6.0,
    this.hungerRestore = 0.0,
    this.healthRestore = 0.0,
    this.warmthRestore = 0.0,
    this.placedBlock,
    this.placedWall,
    this.seedGrowthFactor = 1.0,
    this.regrowsOnHarvest = false,
    this.ecologyNote,
  });

  /// Ordered list of all sowable seed and sapling varieties in the game.
  static const List<ItemType> allSeedVarieties = [
    ItemType.berrySeeds,
    ItemType.bananaSeeds,
    ItemType.mangoSeeds,
    ItemType.healingHerbSeeds,
    ItemType.glowBulbSeeds,
    ItemType.thornVineSeeds,
    ItemType.pitcherPlantSeeds,
    ItemType.mahoganySapling,
  ];

  /// Display name of the item.
  final String label;

  /// Emoji badge representing the item in hotbar and menus.
  final String icon;

  /// Functional category of the item.
  final ItemCategory category;

  /// Multiplier applied to block mining speed when equipped.
  final double miningSpeedMultiplier;

  /// Melee damage dealt to dangerous animals when attacking with this item.
  final double attackDamage;

  /// Hunger points restored (0–100 scale) when consumed.
  final double hungerRestore;

  /// Life points restored (0–100 scale) when consumed.
  final double healthRestore;

  /// Body warmth points restored (0–100 scale) when consumed.
  final double warmthRestore;

  /// Foreground block placed when using this item, or `null` if not a block.
  final BlockType? placedBlock;

  /// Background wall placed when using this item, or `null` if not a wall.
  final WallType? placedWall;

  /// Relative growth speed multiplier when sowed as a [CropPlot].
  final double seedGrowthFactor;

  /// Whether harvesting this crop leaves a perennial rootstock that regrows.
  final bool regrowsOnHarvest;

  /// Botanical and ecological description of how this seed interacts with wildlife.
  final String? ecologyNote;

  /// Whether this item can be eaten by the explorer.
  bool get isEdible => hungerRestore > 0 || healthRestore > 0;

  /// Primary item yielded when a mature crop of this seed type is harvested.
  ItemType get harvestedProduct => switch (this) {
    ItemType.bananaSeeds => ItemType.banana,
    ItemType.mangoSeeds => ItemType.mango,
    ItemType.healingHerbSeeds => ItemType.healingHerb,
    ItemType.glowBulbSeeds => ItemType.glowFruit,
    ItemType.thornVineSeeds => ItemType.vineFiber,
    ItemType.pitcherPlantSeeds => ItemType.jungleNectar,
    ItemType.mahoganySapling => ItemType.woodLogItem,
    _ => ItemType.jungleBerry,
  };

  /// Guide describing which soil type and microclimate this seed prefers and
  /// dislikes.
  String get preferredHabitatNote => switch (this) {
    ItemType.berrySeeds =>
      'Thrives in 🌱 Jungle Loam & ☀️ Sunlit clearings; struggles in dry 🌋 Volcanic Ash.',
    ItemType.bananaSeeds =>
      'Thrives in 🌊 Alluvial River Silt & humid riverbanks; struggles in acidic 🌺 Peat Bog or cold highlands.',
    ItemType.mangoSeeds =>
      'Thrives in 🌋 Volcanic Ash or 🌊 River Silt under ☀️ bright sun; rots in shaded 🌺 Peat Bog.',
    ItemType.healingHerbSeeds =>
      'Thrives in 🌺 Peat Bog & ⛰️ Highland Ash; waterlogs in 🌊 River Silt.',
    ItemType.glowBulbSeeds =>
      'Thrives in 🌺 Mossy Peat Bog, 🌊 River Silt & 🌫️ Shaded Caves; dries out in 🌋 Volcanic Ash.',
    ItemType.thornVineSeeds =>
      'Thrives in 🌋 Volcanic Ash & ⛰️ dry Highland crags; struggles in soggy 🌊 River Silt.',
    ItemType.pitcherPlantSeeds =>
      'Thrives in 🌺 Mossy Peat Bog & humid/shaded wetlands; desiccates in 🌋 Volcanic Ash.',
    ItemType.mahoganySapling =>
      'Thrives in 🌱 Jungle Loam & 🌋 Volcanic Ash; struggles to root in soft 🌺 Peat Bog.',
    _ => '',
  };
}

/// Snapshot of the soil substrate and local microclimate at a world tile.
final class MicroclimateProfile {
  /// Creates an immutable microclimate evaluation for a tile.
  const MicroclimateProfile({
    required this.soilType,
    required this.biome,
    required this.isHumidRiverbank,
    required this.isShadedCanopyOrCave,
    required this.isHighAltitude,
    required this.isWarmedByFire,
  });

  /// Underlying soil substrate at the tile.
  final SoilType soilType;

  /// Surface biome zone containing the tile.
  final JungleBiome biome;

  /// Whether river/lagoon water is within 2 tiles or rain is falling.
  final bool isHumidRiverbank;

  /// Whether overhead canopy leaves or cavern stone shade this tile.
  final bool isShadedCanopyOrCave;

  /// Whether the tile sits on an elevated highland ridge (`ty <= 17`).
  final bool isHighAltitude;

  /// Whether a placed campfire or torch warms the immediate surroundings.
  final bool isWarmedByFire;

  /// Short label naming the local microclimate.
  String get microclimateLabel {
    if (isShadedCanopyOrCave && isHumidRiverbank) {
      return '🌫️ Humid Cavern / Bog Grotto';
    }
    if (isShadedCanopyOrCave) {
      return '🌿 Shaded Understory';
    }
    if (isHighAltitude && isWarmedByFire) {
      return '🔥 Warmed Highland Terrace';
    }
    if (isHighAltitude) {
      return '⛰️ Crisp Highland Ridge';
    }
    if (isHumidRiverbank) {
      return '🌊 Humid Riverbank';
    }
    return '☀️ Sunlit Clearing';
  }

  /// Computes the combined soil + microclimate growth rate multiplier for
  /// [seedType] at this tile.
  double growthMultiplierFor(ItemType seedType) {
    double mult = soilType.soilMultiplierFor(seedType);

    // 1. Shade vs. Direct Sunlight microclimate effect.
    if (isShadedCanopyOrCave) {
      mult *= switch (seedType) {
        ItemType.glowBulbSeeds => 1.35,
        ItemType.pitcherPlantSeeds => 1.25,
        ItemType.healingHerbSeeds => 1.10,
        ItemType.mangoSeeds => 0.68,
        ItemType.bananaSeeds => 0.75,
        _ => 0.95,
      };
    } else {
      mult *= switch (seedType) {
        ItemType.mangoSeeds => 1.22,
        ItemType.bananaSeeds => 1.18,
        ItemType.berrySeeds => 1.12,
        _ => 1.0,
      };
    }

    // 2. Humidity / Riverbank proximity effect.
    if (isHumidRiverbank) {
      mult *= switch (seedType) {
        ItemType.pitcherPlantSeeds => 1.28,
        ItemType.bananaSeeds => 1.22,
        ItemType.glowBulbSeeds => 1.22,
        ItemType.thornVineSeeds => 0.78,
        _ => 1.05,
      };
    }

    // 3. Highland elevation & thermal warmth effect.
    if (isHighAltitude) {
      mult *= switch (seedType) {
        ItemType.thornVineSeeds => 1.25,
        ItemType.healingHerbSeeds => 1.20,
        ItemType.mahoganySapling => 1.18,
        ItemType.bananaSeeds => isWarmedByFire ? 1.05 : 0.72,
        ItemType.pitcherPlantSeeds => isWarmedByFire ? 1.0 : 0.75,
        _ => 1.0,
      };
    } else if (isWarmedByFire) {
      mult *= switch (seedType) {
        ItemType.mangoSeeds => 1.18,
        ItemType.bananaSeeds => 1.15,
        _ => 1.05,
      };
    }

    return mult.clamp(0.35, 2.50);
  }

  /// Human-readable rating badge for how well [seedType] grows here.
  String affinityBadgeFor(ItemType seedType) {
    final m = growthMultiplierFor(seedType);
    final pct = '${m.toStringAsFixed(2)}x';
    if (m >= 1.35) return '🌟 Thriving ($pct)';
    if (m >= 0.90) return '✅ Suitable ($pct)';
    return '⚠️ Poor Fit ($pct)';
  }
}

/// Represents a planted crop or sapling growing on a sowable soil tile.
///
/// {@example example/world_simulation_example.dart}
final class CropPlot {
  /// Creates a crop plot at tile coordinates ([tileX], [tileY]).
  ///
  /// It is an error if [growthProgress] is outside the range `0.0..1.0`.
  CropPlot({
    required this.tileX,
    required this.tileY,
    required this.seedType,
    this.soilType = SoilType.jungleLoam,
    this.lastHabitatMultiplier = 1.0,
    this.growthProgress = 0.0,
    this.isPollinated = false,
    this.isFertilized = false,
    this.effectCooldown = 0.0,
    this.vineSegments = 0,
  }) {
    if (growthProgress < 0.0 || growthProgress > 1.0) {
      throw ArgumentError.value(
        growthProgress,
        'growthProgress',
        'Must be between 0.0 and 1.0 inclusive.',
      );
    }
  }

  /// Horizontal grid coordinate of the crop.
  final int tileX;

  /// Vertical grid coordinate of the crop (the air tile above tilled soil).
  final int tileY;

  /// The seed or sapling variety planted in this plot.
  final ItemType seedType;

  /// Soil substrate directly beneath this crop plot.
  SoilType soilType;

  /// Most recently evaluated soil + microclimate growth multiplier (`0.35..2.50`).
  double lastHabitatMultiplier;

  /// Normalized growth progress from `0.0` (freshly sowed) to `1.0` (ripe).
  double growthProgress;

  /// Whether a [AnimalType.beeSwarm] or [AnimalType.toucan] has directly
  /// pollinated this plant's blossoms, granting bonus harvest yields.
  bool isPollinated;

  /// Whether this plot has been enriched by adjacent [ItemType.pitcherPlantSeeds]
  /// digestion or wildlife droppings, boosting growth speed by +60%.
  bool isFertilized;

  /// Cooldown timer in seconds for active plant defenses (such as
  /// [ItemType.thornVineSeeds] pricking predators or [ItemType.pitcherPlantSeeds]
  /// digesting snakes).
  double effectCooldown;

  /// Number of climbing or creeping vine/runner segments (`0..4`) sprouted by
  /// this plant as it matures.
  int vineSegments;

  /// Whether this plant species naturally extends climbing tendrils and
  /// creeping stolon vines as it grows.
  bool get isViningSpecies =>
      seedType == ItemType.thornVineSeeds ||
      seedType == ItemType.berrySeeds ||
      seedType == ItemType.pitcherPlantSeeds ||
      seedType == ItemType.glowBulbSeeds;

  /// Number of articulated stem/vine nodes visible at the current
  /// [growthProgress] (`1..5`).
  int get stemNodeCount =>
      (1 + (growthProgress * 4.0).floor() + (vineSegments > 0 ? 1 : 0)).clamp(
        1,
        6,
      );

  /// Discrete visual growth stage in `0..3` (`0` = seed, `2` = flowering, `3` = ripe).
  int get stage {
    if (growthProgress >= 1.0) return 3;
    if (growthProgress >= 0.66) return 2;
    if (growthProgress >= 0.33) return 1;
    return 0;
  }

  /// Whether the crop is in its flowering or ripe stage (`stage >= 2`) and can
  /// be visited by bees and toucans for pollination.
  bool get isFlowering => growthProgress >= 0.60;

  /// Whether the crop has reached maturity and can be harvested.
  bool get isMature => growthProgress >= 1.0;

  /// The primary item yielded when this crop is harvested at maturity.
  ItemType get harvestedFruit => seedType.harvestedProduct;
}

/// Defines a crafting recipe available to the explorer.
final class CraftingRecipe {
  /// Creates an immutable crafting recipe definition.
  CraftingRecipe({
    required this.output,
    required this.outputCount,
    required Map<ItemType, int> ingredients,
    required this.description,
    this.requiresCampfire = false,
  }) : ingredients = Map<ItemType, int>.unmodifiable(ingredients);

  /// Item produced by crafting this recipe.
  final ItemType output;

  /// Quantity of [output] added to the inventory per craft.
  final int outputCount;

  /// Required item counts consumed from the inventory.
  final Map<ItemType, int> ingredients;

  /// Short tooltip explaining how the crafted item helps in jungle survival.
  final String description;

  /// Whether the explorer must stand near an active [BlockType.campfire].
  final bool requiresCampfire;
}

/// Defines a barter trade offered by a [NativeVillager].
final class VillageTrade {
  /// Creates a barter offer exchanging [costCount] of [costItem] for
  /// [rewardCount] of [rewardItem].
  const VillageTrade({
    required this.costItem,
    required this.costCount,
    required this.rewardItem,
    required this.rewardCount,
    required this.note,
  });

  /// The fruit or resource requested by the villager.
  final ItemType costItem;

  /// Quantity of [costItem] required.
  final int costCount;

  /// The item given to the explorer upon completing the trade.
  final ItemType rewardItem;

  /// Quantity of [rewardItem] granted.
  final int rewardCount;

  /// Lore or helpful explanation of the trade.
  final String note;
}

/// Species of wildlife encountered by the explorer in the jungle.
enum AnimalType {
  /// Fast, agile spotted predator that prowls the jungle floor and leaps.
  jaguar(
    label: 'Shadow Jaguar',
    maxHealth: 52.0,
    speed: 92.0,
    contactDamage: 14.0,
    aquatic: false,
    flying: false,
    hostileByDefault: true,
  ),

  /// Venomous emerald pit viper that slithers through tall grass, is repelled
  /// by medicinal herbs, and is lured into carnivorous pitcher plants.
  snake(
    label: 'Emerald Viper',
    maxHealth: 28.0,
    speed: 60.0,
    contactDamage: 10.0,
    aquatic: false,
    flying: false,
    hostileByDefault: true,
  ),

  /// Aggressive river piranha that patrols jungle water lagoons.
  piranha(
    label: 'Red-Bellied Piranha',
    maxHealth: 22.0,
    speed: 74.0,
    contactDamage: 9.0,
    aquatic: true,
    flying: false,
    hostileByDefault: true,
  ),

  /// Buzzing honeybee swarm that flies to flowering crops to pollinate them
  /// and guards its home beehive.
  beeSwarm(
    label: 'Jungle Bee Swarm',
    maxHealth: 18.0,
    speed: 105.0,
    contactDamage: 6.0,
    aquatic: false,
    flying: true,
    hostileByDefault: false,
  ),

  /// Curious fruit-foraging primate that disperses seeds and, once befriended
  /// with bananas or berries, harvests ripe crops for the explorer.
  capuchinMonkey(
    label: 'Capuchin Monkey',
    maxHealth: 30.0,
    speed: 84.0,
    contactDamage: 0.0,
    aquatic: false,
    flying: false,
    hostileByDefault: false,
  ),

  /// Colorful frugivorous canopy bird that eats ripe fruits from crops and
  /// wild berry bushes, then flies off to drop and sow fertilized seeds.
  toucan(
    label: 'Rainbow Toucan',
    maxHealth: 20.0,
    speed: 96.0,
    contactDamage: 0.0,
    aquatic: false,
    flying: true,
    hostileByDefault: false,
  );

  const AnimalType({
    required this.label,
    required this.maxHealth,
    required this.speed,
    required this.contactDamage,
    required this.aquatic,
    required this.flying,
    required this.hostileByDefault,
  });

  /// Display name of the animal species.
  final String label;

  /// Starting life points of the animal.
  final double maxHealth;

  /// Movement speed in world pixels per second.
  final double speed;

  /// Life points deducted from the explorer upon an unblocked hit/sting.
  final double contactDamage;

  /// Whether this creature lives exclusively inside [BlockType.water] tiles.
  final bool aquatic;

  /// Whether this creature flies in the air (such as [beeSwarm] or [toucan]).
  final bool flying;

  /// Whether this creature attacks the explorer unprovoked.
  final bool hostileByDefault;
}

/// Active wildlife entity (predator, pollinator, or seed-dispersing animal)
/// in the jungle world.
final class JungleAnimal {
  /// Creates a wildlife instance at world pixel position ([x], [y]).
  JungleAnimal({
    required this.type,
    required this.x,
    required this.y,
    this.vx = 0.0,
    this.vy = 0.0,
    this.facingRight = true,
    double? homeX,
    double? homeY,
    this.isAngry = false,
    this.isTamed = false,
    this.interactionTimer = 2.0,
    this.targetPlantTile,
    this.carriedSeed,
    this.activityBadge,
    this.badgeTimer = 0.0,
  }) : health = type.maxHealth,
       homeX = homeX ?? x,
       homeY = homeY ?? y;

  /// Species configuration of this animal.
  final AnimalType type;

  /// World horizontal position in pixels.
  double x;

  /// World vertical position in pixels.
  double y;

  /// Anchor horizontal position (e.g. home beehive or canopy roost).
  double homeX;

  /// Anchor vertical position (e.g. home beehive or canopy roost).
  double homeY;

  /// Horizontal velocity in pixels per second.
  double vx;

  /// Vertical velocity in pixels per second.
  double vy;

  /// Current hit points remaining.
  double health;

  /// Direction the animal is currently facing.
  bool facingRight;

  /// Whether this creature is currently provoked (used for bee swarms when
  /// their hive is disturbed without smoke).
  bool isAngry;

  /// Remaining seconds before a provoked bee swarm calms down.
  double angryTimer = 0.0;

  /// Whether this animal has been befriended by the explorer (e.g. a
  /// [AnimalType.capuchinMonkey] fed with fruit that now helps tend crops).
  bool isTamed;

  /// Timer in seconds until the animal's next plant interaction (pollination,
  /// fruit foraging, or seed dispersal).
  double interactionTimer;

  /// Grid coordinates `(tileX, tileY)` of a plant or crop the animal is
  /// currently visiting, or `null` if patrolling freely.
  (int, int)? targetPlantTile;

  /// Seed currently carried in the animal's beak or gut after eating a fruit
  /// (used by [AnimalType.toucan] before dispersing it onto fertile soil).
  ItemType? carriedSeed;

  /// Short floating badge describing an active ecological interaction
  /// (such as `'🌸 Pollinating'`, `'🌱 Sowing'`, or `'🌿 Repelled!'`).
  String? activityBadge;

  /// Remaining seconds to display [activityBadge] above the animal.
  double badgeTimer;

  /// Cooldown timer before the animal can deal another melee bite or sting.
  double attackCooldown = 0.0;

  /// Brief red flash timer when hit by the explorer's weapon or thorny plants.
  double hurtFlashTimer = 0.0;

  /// Direction change timer for idle patrolling.
  double patrolTimer = 2.0;

  /// Sets a floating [badge] above this animal for [duration] seconds.
  void showBadge(String badge, {double duration = 2.4}) {
    activityBadge = badge;
    badgeTimer = duration;
  }
}

/// Friendly indigenous villager living in a thatched stilt village.
final class NativeVillager {
  /// Creates a native villager NPC at world pixel coordinates ([x], [y]).
  NativeVillager({
    required this.name,
    required this.role,
    required this.x,
    required this.y,
    required this.greeting,
    required List<VillageTrade> trades,
  }) : trades = List<VillageTrade>.unmodifiable(trades);

  /// Personal name of the villager.
  final String name;

  /// Village role title (e.g. Master Botanist, River Hunter).
  final String role;

  /// World horizontal position in pixels.
  final double x;

  /// World vertical position in pixels.
  final double y;

  /// Friendly dialogue shown when the explorer approaches.
  final String greeting;

  /// List of fruit-for-goods trades offered by this villager.
  final List<VillageTrade> trades;
}

/// Snapshot of the explorer's current shelter and thermal environment.
///
/// Computed in $O(R)$ time where $R$ is the local shelter inspection radius.
///
/// {@example example/world_simulation_example.dart}
final class ShelterEvaluation {
  /// Creates an immutable shelter evaluation result.
  const ShelterEvaluation({
    required this.hasRoof,
    required this.hasBackgroundWalls,
    required this.hasSideEnclosure,
    required this.nearCampfire,
    required this.nearTorch,
    required this.ambientTemperatureCelsius,
  });

  /// Whether solid roof blocks protect the explorer from sky exposure.
  final bool hasRoof;

  /// Whether background walls insulate the tile the explorer occupies.
  final bool hasBackgroundWalls;

  /// Whether side walls or closed doors block horizontal wind drafts.
  final bool hasSideEnclosure;

  /// Whether an active [BlockType.campfire] is within 5 tiles.
  final bool nearCampfire;

  /// Whether a [BlockType.torch] is within 4 tiles.
  final bool nearTorch;

  /// Effective local temperature in degrees Celsius after shelter modifiers.
  final double ambientTemperatureCelsius;

  /// Whether the structure qualifies as a complete cold-protecting shelter.
  bool get isCompleteShelter =>
      hasRoof && (hasBackgroundWalls || hasSideEnclosure);
}

/// Active fishing cast state when the explorer uses a [ItemType.fishingRod].
final class FishingState {
  /// Creates a fishing state with bobber at world pixel position ([bobberX], [bobberY]).
  FishingState({
    required this.bobberX,
    required this.bobberY,
    this.waitTimer = 3.0,
    this.hasBite = false,
    this.biteWindowRemaining = 0.0,
  });

  /// Horizontal pixel position of the bobber in water.
  double bobberX;

  /// Vertical pixel position of the bobber in water.
  double bobberY;

  /// Countdown in seconds until a river fish bites the hook.
  double waitTimer;

  /// Whether a fish is currently biting and ready to be reeled in.
  bool hasBite;

  /// Seconds remaining before the biting fish escapes.
  double biteWindowRemaining;
}
