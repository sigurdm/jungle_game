import 'dart:ui';

/// Foreground block types in the 2D side-scrolling jungle world.
///
/// Each tile cell in the foreground grid contains exactly one [BlockType].
/// Solid blocks prevent player and land-animal movement, whereas non-solid
/// blocks (such as [air], [water], [vine], [torch], and [campfire]) allow
/// entities to pass through.
enum BlockType {
  /// Empty space.
  air(
    label: 'Air',
    isSolid: false,
    hardness: 0.0,
    primaryColor: Color(0x00000000),
    accentColor: Color(0x00000000),
  ),

  /// Lush jungle surface turf that can be tilled or mined for dirt and seeds.
  grass(
    label: 'Jungle Grass',
    isSolid: true,
    hardness: 0.45,
    primaryColor: Color(0xFF2E7D32),
    accentColor: Color(0xFF5D4037),
  ),

  /// Rich jungle soil below the surface turf.
  dirt(
    label: 'Jungle Dirt',
    isSolid: true,
    hardness: 0.4,
    primaryColor: Color(0xFF6D4C41),
    accentColor: Color(0xFF4E342E),
  ),

  /// Tilled farmland capable of growing sowed crop seeds.
  tilledSoil(
    label: 'Tilled Soil',
    isSolid: true,
    hardness: 0.4,
    primaryColor: Color(0xFF4E342E),
    accentColor: Color(0xFF3E2723),
  ),

  /// Dense underground stone requiring a pickaxe for fast mining.
  stone(
    label: 'Jungle Stone',
    isSolid: true,
    hardness: 1.1,
    primaryColor: Color(0xFF607D8B),
    accentColor: Color(0xFF455A64),
  ),

  /// Coal vein embedded in stone, useful for crafting torches and campfires.
  coalOre(
    label: 'Coal Ore',
    isSolid: true,
    hardness: 1.3,
    primaryColor: Color(0xFF546E7A),
    accentColor: Color(0xFF212121),
  ),

  /// Iron ore vein embedded in deep underground stone.
  ironOre(
    label: 'Iron Ore',
    isSolid: true,
    hardness: 1.6,
    primaryColor: Color(0xFF546E7A),
    accentColor: Color(0xFFD7CCC8),
  ),

  /// Mahogany tree trunk that can be chopped for wood logs.
  woodLog(
    label: 'Mahogany Log',
    isSolid: false,
    hardness: 0.65,
    primaryColor: Color(0xFF5D4037),
    accentColor: Color(0xFF3E2723),
  ),

  /// Jungle tree canopy leaves that drop thatch bundles, fruits, and seeds.
  leaves(
    label: 'Canopy Leaves',
    isSolid: false,
    hardness: 0.25,
    primaryColor: Color(0xFF1B5E20),
    accentColor: Color(0xFF43A047),
  ),

  /// Climbable hanging jungle vine that drops vine fibers and wild seeds.
  vine(
    label: 'Jungle Vine',
    isSolid: false,
    hardness: 0.2,
    primaryColor: Color(0xFF388E3C),
    accentColor: Color(0xFF81C784),
  ),

  /// Wild berry bush on the jungle floor that drops berries and berry seeds.
  berryBush(
    label: 'Wild Fruit Bush',
    isSolid: false,
    hardness: 0.25,
    primaryColor: Color(0xFF2E7D32),
    accentColor: Color(0xFFE53935),
  ),

  /// River or lagoon water block that supports swimming and fishing.
  water(
    label: 'River Water',
    isSolid: false,
    hardness: 0.0,
    primaryColor: Color(0xB30288D1),
    accentColor: Color(0xB34FC3F7),
  ),

  /// Crafted solid wood plank block used for shelter walls, floors, and roofs.
  woodPlank(
    label: 'Wood Plank',
    isSolid: true,
    hardness: 0.6,
    primaryColor: Color(0xFF8D6E63),
    accentColor: Color(0xFF5D4037),
  ),

  /// Crafted insulated thatch roof block that keeps out rain and night chill.
  thatchRoof(
    label: 'Thatch Roof',
    isSolid: true,
    hardness: 0.45,
    primaryColor: Color(0xFFC0CA33),
    accentColor: Color(0xFF9E9D24),
  ),

  /// Closed shelter door that blocks dangerous animals and insulates shelters.
  doorClosed(
    label: 'Closed Door',
    isSolid: true,
    hardness: 0.6,
    primaryColor: Color(0xFF795548),
    accentColor: Color(0xFFFFB300),
  ),

  /// Open shelter door that allows the explorer to walk through.
  doorOpen(
    label: 'Open Door',
    isSolid: false,
    hardness: 0.6,
    primaryColor: Color(0x99795548),
    accentColor: Color(0xFFFFB300),
  ),

  /// Placed campfire that radiates strong heat and allows cooking raw fish.
  campfire(
    label: 'Campfire',
    isSolid: false,
    hardness: 0.4,
    primaryColor: Color(0xFFFF6F00),
    accentColor: Color(0xFFFFCA28),
  ),

  /// Placed torch that illuminates surroundings and provides mild warmth.
  torch(
    label: 'Torch',
    isSolid: false,
    hardness: 0.15,
    primaryColor: Color(0xFFFFB300),
    accentColor: Color(0xFFFFF176),
  ),

  /// Indestructible or sturdy native village structure timber.
  villageHutBlock(
    label: 'Village Timber',
    isSolid: true,
    hardness: 2.5,
    primaryColor: Color(0xFF6D4C41),
    accentColor: Color(0xFFFFCC80),
  );

  const BlockType({
    required this.label,
    required this.isSolid,
    required this.hardness,
    required this.primaryColor,
    required this.accentColor,
  });

  /// Human-readable display name of the block.
  final String label;

  /// Whether entities collide with this block.
  final bool isSolid;

  /// Base time in seconds required to break this block by hand.
  final double hardness;

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

/// Categories of inventory items held in the explorer's hotbar and pack.
enum ItemCategory {
  /// Mining, chopping, and fishing tools.
  tool,

  /// Melee weapons used to defend against dangerous animals.
  weapon,

  /// Plantable crop seeds that can be sowed on dirt or grass.
  seed,

  /// Edible fruits, cooked fish, and healing herbs.
  food,

  /// Placeable foreground blocks, doors, campfires, and background walls.
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

  // Seeds
  /// Fast-growing wild jungle berry seeds.
  berrySeeds(label: 'Berry Seeds', icon: '🌱', category: ItemCategory.seed),

  /// Nutritious banana tree shoot seeds.
  bananaSeeds(label: 'Banana Seeds', icon: '🌾', category: ItemCategory.seed),

  /// Prized golden mango seeds obtained by trading with native villagers.
  mangoSeeds(
    label: 'Golden Mango Seeds',
    icon: '✨',
    category: ItemCategory.seed,
  ),

  // Fruits & Food
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

  /// Placeable campfire that warms shelters and cooks fish.
  campfireItem(
    label: 'Campfire',
    icon: '🔥',
    category: ItemCategory.building,
    placedBlock: BlockType.campfire,
  ),

  /// Placeable torch that lights up caverns and shelters.
  torchItem(
    label: 'Jungle Torch',
    icon: '🕯️',
    category: ItemCategory.building,
    placedBlock: BlockType.torch,
  ),

  /// Placeable dirt block for terraforming or farming plots.
  dirtBlock(
    label: 'Dirt Block',
    icon: '🟫',
    category: ItemCategory.building,
    placedBlock: BlockType.dirt,
  ),

  /// Placeable stone block for sturdy walls.
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
  });

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

  /// Whether this item can be eaten by the explorer.
  bool get isEdible => hungerRestore > 0 || healthRestore > 0;
}

/// Represents a planted crop growing on a [BlockType.tilledSoil] tile.
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
    this.growthProgress = 0.0,
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

  /// The seed variety planted in this plot.
  final ItemType seedType;

  /// Normalized growth progress from `0.0` (freshly sowed) to `1.0` (ripe).
  double growthProgress;

  /// Discrete visual growth stage in `0..3` (`0` = seed, `3` = ready to harvest).
  int get stage {
    if (growthProgress >= 1.0) return 3;
    if (growthProgress >= 0.66) return 2;
    if (growthProgress >= 0.33) return 1;
    return 0;
  }

  /// Whether the crop has reached maturity and can be harvested for fruit.
  bool get isMature => growthProgress >= 1.0;

  /// The fruit item yielded when this crop is harvested at maturity.
  ItemType get harvestedFruit {
    switch (seedType) {
      case ItemType.bananaSeeds:
        return ItemType.banana;
      case ItemType.mangoSeeds:
        return ItemType.mango;
      default:
        return ItemType.jungleBerry;
    }
  }
}

/// Defines a crafting recipe available to the explorer.
final class CraftingRecipe {
  /// Creates an immutable crafting recipe definition.
  const CraftingRecipe({
    required this.output,
    required this.outputCount,
    required this.ingredients,
    required this.description,
    this.requiresCampfire = false,
  });

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

/// Species of dangerous jungle wildlife encountered by the explorer.
enum AnimalType {
  /// Fast, agile spotted predator that prowls the jungle floor and leaps.
  jaguar(
    label: 'Shadow Jaguar',
    maxHealth: 52.0,
    speed: 92.0,
    contactDamage: 14.0,
    aquatic: false,
  ),

  /// Venomous emerald pit viper that slithers through tall grass.
  snake(
    label: 'Emerald Viper',
    maxHealth: 28.0,
    speed: 60.0,
    contactDamage: 10.0,
    aquatic: false,
  ),

  /// Aggressive river piranha that patrols jungle water lagoons.
  piranha(
    label: 'Red-Bellied Piranha',
    maxHealth: 22.0,
    speed: 74.0,
    contactDamage: 9.0,
    aquatic: true,
  );

  const AnimalType({
    required this.label,
    required this.maxHealth,
    required this.speed,
    required this.contactDamage,
    required this.aquatic,
  });

  /// Display name of the animal species.
  final String label;

  /// Starting life points of the animal.
  final double maxHealth;

  /// Horizontal movement speed in world pixels per second.
  final double speed;

  /// Life points deducted from the explorer upon an unblocked bite/claw hit.
  final double contactDamage;

  /// Whether this creature lives exclusively inside [BlockType.water] tiles.
  final bool aquatic;
}

/// Active dangerous animal entity in the jungle world.
final class JungleAnimal {
  /// Creates a dangerous animal instance at world pixel position ([x], [y]).
  JungleAnimal({
    required this.type,
    required this.x,
    required this.y,
    this.vx = 0.0,
    this.vy = 0.0,
    this.facingRight = true,
  }) : health = type.maxHealth;

  /// Species configuration of this animal.
  final AnimalType type;

  /// World horizontal position in pixels.
  double x;

  /// World vertical position in pixels.
  double y;

  /// Horizontal velocity in pixels per second.
  double vx;

  /// Vertical velocity in pixels per second.
  double vy;

  /// Current hit points remaining.
  double health;

  /// Direction the animal is currently facing.
  bool facingRight;

  /// Cooldown timer before the animal can deal another melee bite.
  double attackCooldown = 0.0;

  /// Brief red flash timer when hit by the explorer's weapon.
  double hurtFlashTimer = 0.0;

  /// Direction change timer for idle patrolling.
  double patrolTimer = 2.0;
}

/// Friendly indigenous villager living in a thatched stilt village.
final class NativeVillager {
  /// Creates a native villager NPC at world pixel coordinates ([x], [y]).
  const NativeVillager({
    required this.name,
    required this.role,
    required this.x,
    required this.y,
    required this.greeting,
    required this.trades,
  });

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
