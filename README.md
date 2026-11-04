# Jungle Survival 2D (`jungle_game`)

A 2D side-scrolling block survival, botany, and living-ecosystem game built with **Flutter** and **Flame**.

## Core Features

### 🌱 8 Sowable Seed & Sapling Varieties
Sow diverse seeds onto jungle grass or dirt (`BlockType.tilledSoil`), track all 8 varieties in the **Seed Pouch (`🌱 Seeds`)**, or press `R` (`🌱 Next Seed`) to cycle seeds on the fly:
1. **🌱 Berry Seeds (`ItemType.berrySeeds`)**: Fast-growing perennial shrub yielding `🫐 Jungle Berries`. Attracts **Rainbow Toucans** and **Capuchin Monkeys** that disperse new seeds nearby.
2. **🌾 Banana Seeds (`ItemType.bananaSeeds`)**: Tall tropical banana palm yielding `🍌 Ripe Bananas`—the favorite treat for befriending **Capuchin Monkeys**.
3. **✨ Golden Mango Seeds (`ItemType.mangoSeeds`)**: High-energy fruit crop whose fragrant blossoms attract **Bees** and **Toucans** for cross-pollination.
4. **🌿 Medicinal Herb Seeds (`ItemType.healingHerbSeeds`)**: Yields `🌿 Healing Poultices` (`+40 HP`) and emits an aromatic aura that **repels venomous 🐍 Emerald Vipers** within 4 tiles.
5. **💡 Glow-Bulb Spores (`ItemType.glowBulbSeeds`)**: Bioluminescent lotus plant that **illuminates the night**, radiates gentle warmth, **calms 🐝 Bees** for safe honeycomb harvesting, and **lures river fish** while pacifying **🐟 Piranhas**.
6. **🌵 Briar Thorn Seeds (`ItemType.thornVineSeeds`)**: Living defensive thorny hedge that **pricks and knocks back prowling 🐆 Jaguars and 🐍 Vipers** without blocking the explorer.
7. **🌺 Pitcher Plant Seeds (`ItemType.pitcherPlantSeeds`)**: Carnivorous jungle plant that **lures and digests nearby 🐍 Vipers**, harvesting `🧪 Pitcher Nectar` and **fertilizing adjacent crops (`+60%` growth speed)**.
8. **🌳 Mahogany Sapling (`ItemType.mahoganySapling`)**: Grows into a full multi-tile **Mahogany Canopy Tree** with climbable vines and a chance to attract a wild **🪹 Beehive & 🐝 Bee Swarm**.

### 🐒 Living Plant-Animal Ecosystem Interactions
- **🐝 Honeybee Swarms (`AnimalType.beeSwarm`)**: Actively fly out from beehives to visit flowering crops (`stage >= 2`), pollinating blossoms (`🌸 Pollinated!`) for bonus harvest yields and rare cross-pollinated seed discoveries.
- **🐒 Capuchin Monkeys (`AnimalType.capuchinMonkey`)**: Wild monkeys forage ripe berries/bananas and disperse fertilized seeds onto nearby soil. **Feed a monkey fruit** (tap it or press `🐒 Feed`) to befriend it (`💚 Helper`)—befriended monkeys automatically harvest ripe crops into your pack, replant the plot, and chatter warnings when jaguars approach!
- **🦜 Rainbow Toucans (`AnimalType.toucan`)**: Frugivorous canopy birds that swoop down to eat ripe fruits from crops (`🫐 Berries`, `🥭 Mangoes`, `🍌 Bananas`, `🍐 Glow-Fruit`) and wild berry bushes, carry the fruit in their rainbow beak, and fly to open fertile grass to drop and sow fertilized seeds. You can also hand-feed them fruit!
- **🐍 Emerald Vipers & 🐆 Shadow Jaguars**: React dynamically to your garden—vipers flee from **Medicinal Herbs** and are lured into **Carnivorous Pitcher Plants**, while jaguars are pricked and repelled by **Briar Thorn-Vines**.

### 🌍 Infinite Bidirectional World Generation, Soils & Microclimates
- **Infinite Chunk Streaming (`_InfiniteTileRow`, `ensureChunkGenerated`)**: Streams 16-tile horizontal chunks on the fly in both **West (`-∞`)** and **East (`+∞`)** directions across 5 distinct biomes (`🌿 Lush Canopy`, `🌊 River Lagoon`, `🌺 Wild Botanical Grove`, `⛰️ Mist Highlands`, `🏕️ Native Village`).
- **4 Soil Substrates (`SoilType`) & Microclimates (`MicroclimateProfile`)**: Sow seeds in **🌱 Jungle Loam**, **🌊 Alluvial River Silt**, **🌺 Mossy Peat Bog**, or **🌋 Volcanic Highland Ash** (and collect/craft soil blocks to build specialized garden beds). Each tile evaluates shade, riverbank humidity, highland altitude, and campfire warmth to scale per-plant growth speed (`0.35x..2.50x`) and harvest yields.

### 🔊 Procedural Audio Synthesizer (`JungleSoundSynthesizer`, `JungleSoundscape`)
- **Zero-Dependency DSP Synthesis**: Synthesizes real-time PCM/WAV waveforms and plays them through the browser's Web Audio API (`AudioContext`), including **continuous spatial bee buzzing** (FM wingbeat harmonics that swell with proximity and shift higher when a swarm is angry), **attacking Shadow Jaguar roars** (pitch-dropping sawtooth + vocal-tract formants + breath turbulence), **Emerald Viper hisses**, **Toucan calls**, and **Capuchin Monkey chatter**.

## Running & Testing

```bash
flutter pub get
flutter test
flutter run -d chrome
```
