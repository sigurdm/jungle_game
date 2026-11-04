import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'jungle_flame_game.dart';
import 'models.dart';
import 'sound_synthesizer.dart';
import 'world_state.dart';

/// Main interactive screen hosting the [JungleSurvivalGame] canvas and HUD.
final class JungleSurvivalScreen extends StatefulWidget {
  /// Creates the main jungle survival game screen.
  const JungleSurvivalScreen({super.key});

  @override
  State<JungleSurvivalScreen> createState() => _JungleSurvivalScreenState();
}

final class _JungleSurvivalScreenState extends State<JungleSurvivalScreen> {
  late JungleWorld _world;
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

  void _regenerateWorldWithSeed([int? customSeed]) {
    setState(() {
      _world = JungleWorld.generate(seed: customSeed);
      _game.worldState = _world;
      _world.setBanner(
        '🌍 Generated new infinite jungle world (Seed #${_world.worldSeed})! Walk West or East to stream new biomes!',
      );
    });
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
              Builder(
                builder: (_) {
                  final climate = _world.evaluateMicroclimate(
                    _world.playerTileX,
                    _world.playerTileY,
                  );
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B3B2B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.tealAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '${_world.currentBiome.icon} ${_world.currentBiome.label} • ${climate.soilType.icon} ${climate.soilType.label} • ${climate.microclimateLabel} • X:${_world.playerTileX}',
                      style: const TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
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
                label:
                    '🌱 Seeds (${_world.sowedSeedVarieties.length}/${ItemType.allSeedVarieties.length})',
                color: const Color(0xFF2E7D32),
                onPressed: _openSeedPouchModal,
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
                label: '🌍 World (#${_world.worldSeed})',
                color: const Color(0xFF0277BD),
                onPressed: _openWorldGeneratorModal,
              ),
              _HudChipButton(
                label:
                    !_world.soundEnabled
                        ? '🔇 Sound: OFF'
                        : (_world.lastSoundEvent != null
                            ? '🔊 ${_world.lastSoundEvent!.badgeText}'
                            : (_world.beeBuzzIntensity > 0.08
                                ? '🔊 🐝 Buzz (${(_world.beeBuzzIntensity * 100).round()}%)'
                                : '🔊 Sound: ON')),
                color:
                    !_world.soundEnabled
                        ? const Color(0xFF455A64)
                        : const Color(0xFF00695C),
                onPressed: _openSoundModal,
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

  void _openSoundModal() {
    _game.soundscape.unlockAudio();
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
                            '🔊 Procedural Jungle Soundscape & Synth',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Switch(
                            value: _world.soundEnabled,
                            activeThumbColor: Colors.tealAccent,
                            onChanged: (val) {
                              setState(() {
                                _world.soundEnabled = val;
                              });
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),
                      Text(
                        'All sounds are 2-channel stereo relative to the explorer (equal-power panning + interaural Haas delay). Walk left or right of beehives, roaring jaguars, and wildlife to hear them pan across your ears!',
                        style: TextStyle(
                          color: Colors.greenAccent.shade100,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Live Bee Proximity Buzz: ${(_world.beeBuzzIntensity * 100).round()}% • Stereo Pan: ${_world.beeBuzzPan <= -0.15 ? "◀ Left (${(_world.beeBuzzPan * 100).round()}%)" : (_world.beeBuzzPan >= 0.15 ? "Right ▶ (+${(_world.beeBuzzPan * 100).round()}%)" : "● Center")} ${_world.beeBuzzAngry ? "(⚠️ Angry Swarm!)" : ""}',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          controller: controller,
                          itemCount: SoundCue.values.length,
                          itemBuilder: (_, idx) {
                            final cue = SoundCue.values[idx];
                            final samples =
                                JungleSoundSynthesizer.synthesizeSamples(cue);
                            final zcrHz =
                                JungleSoundSynthesizer.estimateZeroCrossingHz(
                                  samples,
                                ).round();
                            void auditionAtPan(double panValue) {
                              _world.soundEnabled = true;
                              final ev = SoundEvent(
                                cue: cue,
                                volume: 0.90,
                                pan: panValue,
                              );
                              _world.lastSoundEvent = ev;
                              _world.lastSoundTimer = 2.4;
                              _game.soundscape.playEvent(
                                ev,
                                soundEnabled: true,
                              );
                              setModalState(() {});
                              setState(() {});
                            }

                            return Card(
                              color: const Color(0xFF1E2C34),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Text(
                                  cue.icon,
                                  style: const TextStyle(fontSize: 26),
                                ),
                                title: Text(
                                  cue.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Duration: ${(cue.defaultDuration * 1000).round()} ms  •  ~$zcrHz Hz  •  2ch Stereo',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11.5,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Play Left of Explorer (-0.8)',
                                      icon: const Text(
                                        '◀ L',
                                        style: TextStyle(
                                          color: Colors.cyanAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      onPressed: () => auditionAtPan(-0.8),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF00796B,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                      ),
                                      onPressed: () => auditionAtPan(0.0),
                                      child: const Text('● Play'),
                                    ),
                                    IconButton(
                                      tooltip: 'Play Right of Explorer (+0.8)',
                                      icon: const Text(
                                        'R ▶',
                                        style: TextStyle(
                                          color: Colors.cyanAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      onPressed: () => auditionAtPan(0.8),
                                    ),
                                  ],
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
              label: '🌱 Next Seed',
              color: const Color(0xFF33691E),
              onTap: () {
                _world.cycleEquippedSeed();
                setState(() {});
              },
            ),
            const SizedBox(width: 8),
            _TapActionButton(
              label: '🐒 Feed',
              color: const Color(0xFF6A1B9A),
              onTap: () {
                _world.feedNearbyWildlife();
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

  void _openSeedPouchModal() {
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
            final localClimate = _world.evaluateMicroclimate(
              _world.playerTileX,
              _world.playerTileY,
            );
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.76,
              maxChildSize: 0.92,
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
                            '🌱 Seed Pouch, Soils & Microclimates (${_world.sowedSeedVarieties.length}/${ItemType.allSeedVarieties.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
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
                        'Here at X:${_world.playerTileX}: ${localClimate.soilType.icon} ${localClimate.soilType.label}  •  ${localClimate.microclimateLabel}',
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        localClimate.soilType.summary,
                        style: TextStyle(
                          color: Colors.greenAccent.shade100,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          controller: controller,
                          itemCount: ItemType.allSeedVarieties.length,
                          itemBuilder: (_, idx) {
                            final seed = ItemType.allSeedVarieties[idx];
                            final count = _world.inventory[seed] ?? 0;
                            final sowedBefore = _world.sowedSeedVarieties
                                .contains(seed);
                            final isEquipped = _world.equippedItem == seed;
                            final product = seed.harvestedProduct;
                            final localAffinity = localClimate.affinityBadgeFor(
                              seed,
                            );

                            return Card(
                              color:
                                  isEquipped
                                      ? const Color(0xFF1F3828)
                                      : const Color(0xFF1E2C34),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Text(
                                  seed.icon,
                                  style: const TextStyle(fontSize: 28),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${seed.label} (x$count)',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF263238),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Here: $localAffinity',
                                        style: const TextStyle(
                                          color: Colors.lightGreenAccent,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (sowedBefore)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2E7D32),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Text(
                                          '✓ Sowed',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 3),
                                    Text(
                                      seed.ecologyNote ?? '',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '🌍 Habitat: ${seed.preferredHabitatNote}',
                                      style: const TextStyle(
                                        color: Colors.cyanAccent,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Harvests: ${product.icon} ${product.label}  •  Base Speed: ${(seed.seedGrowthFactor * 100).round()}%${seed.regrowsOnHarvest ? "  •  ♻️ Perennial (regrows)" : "  •  🌳 Grows Canopy Tree"}',
                                      style: const TextStyle(
                                        color: Colors.amberAccent,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        count > 0
                                            ? const Color(0xFF2E7D32)
                                            : Colors.grey.shade800,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed:
                                      count > 0
                                          ? () {
                                            _world.equipSeedVariety(seed);
                                            setModalState(() {});
                                            setState(() {});
                                            Navigator.pop(context);
                                          }
                                          : null,
                                  child: Text(isEquipped ? 'Equipped' : 'Sow'),
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
                            '🔨 Jungle Crafting, Seeds & Shelter Workshop',
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
                        'Tip: Craft specialized seeds (🌿 Herb, 🌵 Briar Thorn, 💡 Glow-Bulb, 🌺 Pitcher, 🌳 Sapling) or build warm shelters!',
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
                        Text(
                          'Discovered Native Villages (${_world.villagers.length} found so far — more generate infinitely as you explore West & East!):',
                          style: const TextStyle(
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
                                  '🛖 ${v.name} — ${v.role} (X:${JungleWorld.pixelToTile(v.x)})',
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

  void _openWorldGeneratorModal() {
    final seedController = TextEditingController(
      text: _world.worldSeed.toString(),
    );
    final (minTileX, maxTileX) = _world.generatedTileBounds;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141E24),
          title: const Text(
            '🌍 Infinite Procedural World Generator',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Current Seed: #${_world.worldSeed}\n'
                  'Current Biome: ${_world.currentBiome.icon} ${_world.currentBiome.label}\n'
                  'Explorer Position: Tile X=${_world.playerTileX}, Y=${_world.playerTileY}\n'
                  'Streamed Chunks: ${_world.generatedChunkCount} chunks (${_world.exploredTileSpan} tiles: X=$minTileX..$maxTileX)\n'
                  'Discovered Villages: ${_world.villagers.length} • Wild/Planted Crops: ${_world.crops.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                const Text(
                  'As you walk West (-X) or East (+X), new 16-tile chunks are generated on the fly with seamless elevation transitions across 5 biomes:\n'
                  '• 🌴 Emerald Canopy • 🏞️ River Lagoon • 🌺 Wild Botanical Grove\n'
                  '• ⛰️ Mist Highlands • 🛖 Native Village',
                  style: TextStyle(color: Colors.tealAccent, fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: seedController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Custom World Seed (Integer)',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.tealAccent),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final parsed = int.tryParse(seedController.text.trim());
                Navigator.pop(ctx);
                _regenerateWorldWithSeed(parsed);
              },
              child: const Text('Load Seed'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0277BD),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _regenerateWorldWithSeed();
              },
              child: const Text('🎲 Random New World'),
            ),
          ],
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
            '🌱 Gather Wild Seeds from Bushes, Vines, or Grass',
            _world.milestoneGatheredSeeds,
          ),
          (
            '🌾 Sow Crops on Tilled Soil (${_world.sowedSeedVarieties.length}/${ItemType.allSeedVarieties.length} seed varieties sowed)',
            _world.milestoneSowedCrop,
          ),
          (
            '🌸 Trigger a Plant-Animal Interaction (Pollination, Snake Ward, Briar, Pitcher)',
            _world.milestonePlantAnimalInteraction,
          ),
          (
            '🐒 Befriend a Capuchin Monkey with Bananas or Berries',
            _world.milestoneBefriendedMonkey,
          ),
          (
            '🍌 Harvest Ripe Fruit or Nectar from a Grown Crop',
            _world.milestoneHarvestedFruit,
          ),
          (
            '🍯 Harvest Golden Honeycomb from a Beehive (use 🕯️ Torch or 💡 Glow-Bulb!)',
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
            '📓 Explorer Survival Journal & Ecology Guide',
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
                  'Plant-Animal Interactions & Controls:',
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '• Tap "🌱 Seeds" (or press R) to choose from 8 seed varieties: Berry, Banana, Mango, Medicinal Herb (repels 🐍 Vipers), Glow-Bulb (night light & calms 🐝 Bees), Briar Thorn (pricks 🐆 Jaguars), Pitcher Plant (traps snakes & fertilizes crops), and Mahogany Sapling (grows full trees).\n'
                  '• Tap a 🐒 Capuchin Monkey or 🦜 Rainbow Toucan (or tap "🐒 Feed") while carrying fruit to befriend monkeys into crop-harvesting helpers!\n'
                  '• Desktop Keys: A/D Move, W/Space Jump/Swim/Climb, R Cycle Seed, E Eat, F Fish, Q Attack.',
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
