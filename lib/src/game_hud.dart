import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'jungle_flame_game.dart';
import 'models.dart';
import 'world_state.dart';

/// Main interactive screen hosting the [JungleSurvivalGame] canvas and HUD.
final class JungleSurvivalScreen extends StatefulWidget {
  /// Creates the main jungle survival game screen.
  const JungleSurvivalScreen({super.key});

  @override
  State<JungleSurvivalScreen> createState() => _JungleSurvivalScreenState();
}

final class _JungleSurvivalScreenState extends State<JungleSurvivalScreen> {
  late final JungleWorld _world;
  late final JungleSurvivalGame _game;
  bool _showMobileControls = true;

  @override
  void initState() {
    super.initState();
    _world = JungleWorld.generate();
    _game = JungleSurvivalGame(
      worldState: _world,
      onHudChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final shelter = _world.evaluateShelterStatus(
      _world.playerTileX,
      _world.playerTileY,
    );
    final villager = _world.nearbyVillager;
    final fishing = _world.activeFishing;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Flame 2D Side-Scrolling Block World Canvas.
            Positioned.fill(child: GameWidget<JungleSurvivalGame>(game: _game)),

            // 2. Top Survival Status & Action Bar.
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopStatsPanel(shelter, villager),
                  if (_world.statusBannerTimer > 0) ...[
                    const SizedBox(height: 6),
                    _buildStatusBanner(fishing),
                  ],
                ],
              ),
            ),

            // 3. Mobile On-Screen Touch Controls (Left D-Pad + Right Jump/Actions).
            if (_showMobileControls) ...[
              Positioned(left: 12, bottom: 86, child: _buildTouchDpad()),
              Positioned(
                right: 12,
                bottom: 86,
                child: _buildTouchActionButtons(fishing),
              ),
            ],

            // 4. Bottom 10-Slot Hotbar & Mode Switcher.
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: _buildBottomHotbar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStatsPanel(
    ShelterEvaluation shelter,
    NativeVillager? villager,
  ) {
    final tempStr = '${shelter.ambientTemperatureCelsius.round()}°C';
    final shelterBadgeText =
        shelter.isCompleteShelter
            ? (shelter.nearCampfire
                ? '🏠 Warm Shelter + 🔥'
                : '🏠 Enclosed Shelter')
            : (shelter.nearCampfire
                ? '🔥 By Campfire (No Roof)'
                : (_world.isNight
                    ? '❄️ Cold Night! Build Shelter'
                    : '🌴 Open Jungle'));
    final shelterBadgeColor =
        shelter.isCompleteShelter
            ? const Color(0xFF2E7D32)
            : (shelter.nearCampfire
                ? const Color(0xFFEF6C00)
                : (_world.isNight
                    ? const Color(0xFFC62828)
                    : const Color(0xFF37474F)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCC101820),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Survival Meters: Life, Hunger, Warmth.
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _StatBar(
                icon: '❤️',
                label: 'Life',
                value: _world.health,
                color: const Color(0xFFE53935),
              ),
              _StatBar(
                icon: '🍌',
                label: 'Food',
                value: _world.hunger,
                color: const Color(0xFFFFB300),
              ),
              _StatBar(
                icon: '🔥',
                label: 'Warmth',
                value: _world.warmth,
                color: const Color(0xFF29B6F6),
              ),
            ],
          ),

          // Day/Night + Temperature + Shelter Pill.
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_world.isNight ? "🌙 Night" : "☀️ Day"} ${_world.dayCount} • $tempStr ${_world.isRaining ? "🌧️" : ""}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: shelterBadgeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  shelterBadgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // Action Menu Buttons.
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _HudChipButton(
                label: '🍌 Eat',
                color: const Color(0xFF388E3C),
                onPressed: () {
                  _world.eatFood();
                  setState(() {});
                },
              ),
              _HudChipButton(
                label: '🔨 Craft Shelter & Tools',
                color: const Color(0xFFD84315),
                onPressed: _openCraftingModal,
              ),
              _HudChipButton(
                label:
                    villager != null
                        ? '🤝 Trade (${villager.name})'
                        : '🤝 Village Trade',
                color:
                    villager != null
                        ? const Color(0xFF00897B)
                        : const Color(0xFF455A64),
                onPressed: _openVillageTradeModal,
              ),
              _HudChipButton(
                label: '📓 Journal',
                color: const Color(0xFF5E35B1),
                onPressed: _openJournalModal,
              ),
              _HudChipButton(
                label: _showMobileControls ? '📱 Pad: ON' : '📱 Pad: OFF',
                color: const Color(0xFF37474F),
                onPressed: () {
                  setState(() {
                    _showMobileControls = !_showMobileControls;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(FishingState? fishing) {
    final hasBite = fishing?.hasBite ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: hasBite ? const Color(0xFFE65100) : const Color(0xD91B3022),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasBite ? Colors.yellowAccent : Colors.greenAccent,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _world.statusMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (hasBite)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellowAccent,
                foregroundColor: Colors.black,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () {
                _world.toggleFishingCast();
                setState(() {});
              },
              child: const Text('🎣 REEL IN FISH!'),
            ),
        ],
      ),
    );
  }

  Widget _buildTouchDpad() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HoldTouchButton(
            label: '▲',
            tooltip: 'Climb Vine / Swim Up / Jump',
            onChanged: (v) => _game.inputJump = v,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HoldTouchButton(
                label: '◀',
                tooltip: 'Move Left',
                onChanged: (v) => _game.inputLeft = v,
              ),
              const SizedBox(width: 14),
              _HoldTouchButton(
                label: '▶',
                tooltip: 'Move Right',
                onChanged: (v) => _game.inputRight = v,
              ),
            ],
          ),
          const SizedBox(height: 4),
          _HoldTouchButton(
            label: '▼',
            tooltip: 'Climb Down Vine',
            onChanged: (v) => _game.inputDown = v,
          ),
        ],
      ),
    );
  }

  Widget _buildTouchActionButtons(FishingState? fishing) {
    final isBiting = fishing?.hasBite ?? false;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TapActionButton(
              label: isBiting ? '🎣 REEL!' : '🎣 Fish',
              color:
                  isBiting ? const Color(0xFFFFB300) : const Color(0xFF0277BD),
              onTap: () {
                _world.toggleFishingCast();
                setState(() {});
              },
            ),
            const SizedBox(width: 8),
            _TapActionButton(
              label: '🗡️ Attack',
              color: const Color(0xFFC62828),
              onTap: () {
                _world.attackNearbyAnimals();
                setState(() {});
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TapActionButton(
              label: '⚡ Use / Sow',
              color: const Color(0xFF2E7D32),
              onTap: _game.performFrontAction,
            ),
            const SizedBox(width: 8),
            _HoldTouchButton(
              label: 'JUMP',
              width: 68,
              height: 48,
              color: const Color(0xFFEF6C00),
              tooltip: 'Jump / Swim',
              onChanged: (v) => _game.inputJump = v,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomHotbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xD9101820),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          // Mode Toggle Button (Smart Auto / Mine / Build & Sow).
          InkWell(
            onTap: () {
              setState(() {
                final nextIdx =
                    (_game.interactionMode.index + 1) %
                    InteractionMode.values.length;
                _game.interactionMode = InteractionMode.values[nextIdx];
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF263238),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amberAccent),
              ),
              child: Text(
                _game.interactionMode.label,
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Scrollable 10-slot Hotbar.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_world.hotbar.length, (index) {
                  final item = _world.hotbar[index];
                  final count = _world.inventory[item] ?? 0;
                  final selected = _world.selectedHotbarIndex == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _world.selectedHotbarIndex = index;
                      });
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            selected
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFF1C262B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              selected
                                  ? Colors.lightGreenAccent
                                  : Colors.white24,
                          width: selected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(item.icon, style: const TextStyle(fontSize: 18)),
                          Text(
                            'x$count',
                            style: TextStyle(
                              color: count > 0 ? Colors.white : Colors.white38,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openCraftingModal() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141E24),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final shelter = _world.evaluateShelterStatus(
              _world.playerTileX,
              _world.playerTileY,
            );
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.68,
              maxChildSize: 0.88,
              builder: (_, controller) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '🔨 Jungle Crafting & Shelter Workshop',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      Text(
                        'Tip: To protect from night cold, place Wood Planks / Thatch Roof overhead, fill the room with Background Walls, add a Door, and light a Campfire inside!',
                        style: TextStyle(
                          color: Colors.greenAccent.shade100,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          controller: controller,
                          itemCount: JungleWorld.recipes.length,
                          itemBuilder: (_, idx) {
                            final r = JungleWorld.recipes[idx];
                            final canAfford = r.ingredients.entries.every(
                              (e) => (_world.inventory[e.key] ?? 0) >= e.value,
                            );
                            final hasFire =
                                !r.requiresCampfire || shelter.nearCampfire;
                            final ready = canAfford && hasFire;

                            final reqText = r.ingredients.entries
                                .map(
                                  (e) =>
                                      '${e.key.icon} ${e.key.label}: ${_world.inventory[e.key] ?? 0}/${e.value}',
                                )
                                .join('  •  ');

                            return Card(
                              color: const Color(0xFF1E2C34),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Text(
                                  r.output.icon,
                                  style: const TextStyle(fontSize: 26),
                                ),
                                title: Text(
                                  '${r.output.label} (x${r.outputCount})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.description,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      reqText +
                                          (r.requiresCampfire
                                              ? '  •  🔥 Requires nearby Campfire'
                                              : ''),
                                      style: TextStyle(
                                        color:
                                            ready
                                                ? Colors.lightGreenAccent
                                                : Colors.orangeAccent,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        ready
                                            ? const Color(0xFF2E7D32)
                                            : Colors.grey.shade800,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    if (_world.craft(r)) {
                                      setModalState(() {});
                                      setState(() {});
                                    }
                                  },
                                  child: const Text('Craft'),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _openVillageTradeModal() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141E24),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final near = _world.nearbyVillager;
            final displayedVillagers = near != null ? [near] : _world.villagers;
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.62,
              maxChildSize: 0.85,
              builder: (_, controller) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            near != null
                                ? '🤝 Trading with ${near.name} (${near.role})'
                                : '🤝 Native Jungle Villages (Barter Market)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      if (near != null)
                        Text(
                          '"${near.greeting}"',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        const Text(
                          'Native Villages are located at tile X=38 (West Village) and X=120 (East Village). You can trade harvested fruits and fish with them:',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView(
                          controller: controller,
                          children: [
                            for (final v in displayedVillagers) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Text(
                                  '🛖 ${v.name} — ${v.role}',
                                  style: const TextStyle(
                                    color: Colors.tealAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              for (final t in v.trades)
                                Card(
                                  color: const Color(0xFF1E2C34),
                                  child: ListTile(
                                    leading: Text(
                                      t.rewardItem.icon,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    title: Text(
                                      'Get ${t.rewardCount}x ${t.rewardItem.label}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Cost: ${t.costCount}x ${t.costItem.icon} ${t.costItem.label} (You have: ${_world.inventory[t.costItem] ?? 0})\n${t.note}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            (_world.inventory[t.costItem] ??
                                                        0) >=
                                                    t.costCount
                                                ? const Color(0xFF00897B)
                                                : Colors.grey.shade800,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        if (_world.executeTrade(t)) {
                                          setModalState(() {});
                                          setState(() {});
                                        }
                                      },
                                      child: const Text('Trade'),
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _openJournalModal() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final milestones = [
          (
            '🌱 Gather Wild Seeds from Bushes or Grass',
            _world.milestoneGatheredSeeds,
          ),
          ('🌾 Sow Seeds onto Tilled Jungle Soil', _world.milestoneSowedCrop),
          (
            '🍌 Harvest Ripe Fruit from a Grown Crop',
            _world.milestoneHarvestedFruit,
          ),
          (
            '🍯 Harvest Golden Honeycomb from a Beehive (use 🕯️ Torch smoke!)',
            _world.milestoneHarvestedHoney,
          ),
          (
            '🏠 Build & Stand Inside a Warm Campfire Shelter',
            _world.milestoneBuiltShelter,
          ),
          (
            '🎣 Catch a River Fish with a Fishing Rod',
            _world.milestoneCaughtFish,
          ),
          (
            '🤝 Trade Fruits or Honey with a Native Villager',
            _world.milestoneTradedWithNatives,
          ),
          (
            '🔱 Defeat a Dangerous Jungle Predator',
            _world.milestoneDefeatedPredator,
          ),
        ];
        return AlertDialog(
          backgroundColor: const Color(0xFF182228),
          title: const Text(
            '📓 Explorer Survival Journal & Controls',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Explorer Milestones:',
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                for (final (title, done) in milestones)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          done
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color:
                              done ? Colors.lightGreenAccent : Colors.white38,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: done ? Colors.white : Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(color: Colors.white24, height: 22),
                const Text(
                  'Controls (Mobile Touch & Desktop):',
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '• Tap / Hold any tile within reach to Mine, Sow Seeds, Harvest Ripe Crops, or Place Shelter Blocks & Walls.\n'
                  '• Desktop Keys: A/D or Left/Right to Move, W/Space to Jump/Swim/Climb Vines, E to Eat Food, F to Cast/Reel Fishing Rod, Q to Attack.\n'
                  '• Mobile Pad: Use the on-screen D-Pad + JUMP / USE / FISH / ATTACK buttons.',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Resume Exploration'),
            ),
          ],
        );
      },
    );
  }
}

final class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final String icon;
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = (value / 100.0).clamp(0.0, 1.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label ${value.round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              width: 68,
              height: 7,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

final class _HudChipButton extends StatelessWidget {
  const _HudChipButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

final class _HoldTouchButton extends StatelessWidget {
  const _HoldTouchButton({
    required this.label,
    required this.tooltip,
    required this.onChanged,
    this.width = 44,
    this.height = 42,
    this.color = const Color(0xAA263238),
  });

  final String label;
  final String tooltip;
  final ValueChanged<bool> onChanged;
  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => onChanged(true),
      onPointerUp: (_) => onChanged(false),
      onPointerCancel: (_) => onChanged(false),
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white38),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

final class _TapActionButton extends StatelessWidget {
  const _TapActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white38),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}
