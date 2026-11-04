import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart'
    show Colors, TextPainter, TextSpan, TextStyle, TextDirection;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEvent, KeyEventResult;

import 'models.dart';
import 'sound_synthesizer.dart';
import 'world_state.dart';

/// Action mode used when tapping or dragging on world tiles.
enum InteractionMode {
  /// Automatically mines blocks, harvests ripe crops/honey, or uses held item.
  smartAuto('⚡ Smart Auto'),

  /// Strictly mines foreground blocks or harvests crops.
  mineOnly('⛏️ Mine / Harvest'),

  /// Strictly places blocks/walls, sows seeds, pours water, or toggles doors.
  buildOrSow('🧱 Build / Sow');

  const InteractionMode(this.label);

  /// Display label for the HUD mode toggle button.
  final String label;
}

/// Flame 2D side-scrolling block survival game engine.
///
/// Renders the world, physics effects (falling water, spreading wildfire),
/// beehives, 8 distinct botanical crop varieties, and multi-layered character
/// and wildlife graphics procedurally on a [Canvas].
final class JungleSurvivalGame extends FlameGame
    with TapCallbacks, DragCallbacks, KeyboardEvents {
  /// Creates a [JungleSurvivalGame] backed by [worldState].
  JungleSurvivalGame({required this.worldState, required this.onHudChanged});

  /// Underlying simulation state for the jungle world.
  JungleWorld worldState;

  /// Callback invoked periodically to refresh the Flutter HUD overlay.
  final VoidCallback onHudChanged;

  /// Procedural soundscape synthesizer and Web Audio controller.
  final JungleSoundscape soundscape = JungleSoundscape();

  /// Current tile interaction mode for taps and drags.
  InteractionMode interactionMode = InteractionMode.smartAuto;

  /// Whether left movement is active (via keyboard or mobile button).
  bool inputLeft = false;

  /// Whether right movement is active (via keyboard or mobile button).
  bool inputRight = false;

  /// Whether jump / swim-up / vine-climb-up is active.
  bool inputJump = false;

  /// Whether vine-climb-down is active.
  bool inputDown = false;

  final Set<LogicalKeyboardKey> _keysPressed = {};
  Offset? _pointerScreenPos;
  bool _pointerHeld = false;
  double _hudNotifyAccumulator = 0.0;
  double _animTime = 0.0;

  /// Current camera top-left offset in world pixels (horizontally unbounded).
  Offset get cameraTopLeft {
    final viewW = size.x > 0 ? size.x : 800.0;
    final viewH = size.y > 0 ? size.y : 500.0;
    final maxCamY = math.max(
      0.0,
      worldState.height * JungleWorld.tileSize - viewH,
    );
    final cx = worldState.playerX - viewW * 0.5;
    final cy = (worldState.playerY - viewH * 0.54).clamp(0.0, maxCamY);
    return Offset(cx, cy);
  }

  /// Converts a screen-space point to world tile coordinates `(tx, ty)`.
  (int, int) screenToTile(Offset screenPoint) {
    final cam = cameraTopLeft;
    final wx = cam.dx + screenPoint.dx;
    final wy = cam.dy + screenPoint.dy;
    final tx = JungleWorld.pixelToTile(wx);
    final ty = JungleWorld.pixelToTile(wy).clamp(0, worldState.height - 1);
    return (tx, ty);
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    _keysPressed
      ..clear()
      ..addAll(keysPressed);

    if (event is KeyDownEvent) {
      soundscape.unlockAudio();
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.keyE) {
        worldState.eatFood();
        onHudChanged();
      } else if (key == LogicalKeyboardKey.keyR) {
        worldState.cycleEquippedSeed();
        onHudChanged();
      } else if (key == LogicalKeyboardKey.keyF) {
        worldState.toggleFishingCast();
        onHudChanged();
      } else if (key == LogicalKeyboardKey.keyQ) {
        worldState.attackNearbyAnimals();
        onHudChanged();
      } else if (key == LogicalKeyboardKey.digit1) {
        worldState.selectedHotbarIndex = 0;
        onHudChanged();
      } else if (key == LogicalKeyboardKey.digit2) {
        worldState.selectedHotbarIndex = 1;
        onHudChanged();
      } else if (key == LogicalKeyboardKey.digit3) {
        worldState.selectedHotbarIndex = 2;
        onHudChanged();
      } else if (key == LogicalKeyboardKey.digit4) {
        worldState.selectedHotbarIndex = 3;
        onHudChanged();
      } else if (key == LogicalKeyboardKey.digit5) {
        worldState.selectedHotbarIndex = 4;
        onHudChanged();
      } else if (key == LogicalKeyboardKey.digit6) {
        worldState.selectedHotbarIndex = 5;
        onHudChanged();
      } else if (key == LogicalKeyboardKey.digit7) {
        worldState.selectedHotbarIndex = 6;
        onHudChanged();
      } else if (key == LogicalKeyboardKey.digit8) {
        worldState.selectedHotbarIndex = 7;
        onHudChanged();
      } else if (key == LogicalKeyboardKey.digit9) {
        worldState.selectedHotbarIndex = 8;
        onHudChanged();
      } else if (key == LogicalKeyboardKey.digit0) {
        worldState.selectedHotbarIndex = 9;
        onHudChanged();
      }
    }
    return KeyEventResult.handled;
  }

  @override
  void onTapDown(TapDownEvent event) {
    soundscape.unlockAudio();
    final pos = Offset(event.localPosition.x, event.localPosition.y);
    _pointerScreenPos = pos;
    _pointerHeld = true;
    final (tx, ty) = screenToTile(pos);

    final cam = cameraTopLeft;
    final worldTapX = cam.dx + pos.dx;
    final worldTapY = cam.dy + pos.dy;
    for (final a in worldState.animals) {
      final d = math.sqrt(
        math.pow(a.x - worldTapX, 2) + math.pow(a.y - worldTapY, 2),
      );
      if (d <= 36.0) {
        if (a.type == AnimalType.capuchinMonkey ||
            a.type == AnimalType.toucan) {
          worldState.feedNearbyWildlife(a);
          onHudChanged();
          return;
        }
        if (a.type.hostileByDefault || a.isAngry) {
          worldState.attackNearbyAnimals();
          onHudChanged();
          return;
        }
      }
    }

    if (interactionMode == InteractionMode.mineOnly) {
      worldState.mineTileStep(tx, ty, 0.12);
    } else if (interactionMode == InteractionMode.buildOrSow) {
      worldState.interactOrPlaceAt(tx, ty);
    } else {
      final didInteract = worldState.interactOrPlaceAt(tx, ty);
      if (!didInteract) {
        worldState.mineTileStep(tx, ty, 0.12);
      }
    }
    onHudChanged();
  }

  @override
  void onTapUp(TapUpEvent event) {
    _pointerHeld = false;
    worldState.miningTarget = null;
    worldState.miningProgress = 0.0;
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _pointerHeld = false;
    worldState.miningTarget = null;
    worldState.miningProgress = 0.0;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _pointerScreenPos = Offset(event.localPosition.x, event.localPosition.y);
    _pointerHeld = true;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    _pointerScreenPos = Offset(
      event.localEndPosition.x,
      event.localEndPosition.y,
    );
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _pointerHeld = false;
    worldState.miningTarget = null;
    worldState.miningProgress = 0.0;
  }

  /// Performs the primary context action in front of the explorer.
  void performFrontAction() {
    if (worldState.attackNearbyAnimals()) {
      onHudChanged();
      return;
    }
    if (worldState.feedNearbyWildlife()) {
      onHudChanged();
      return;
    }
    final dir = worldState.playerFacingRight ? 1 : -1;
    final tx = worldState.playerTileX + dir;
    final ty = worldState.playerTileY;
    if (!worldState.interactOrPlaceAt(tx, ty)) {
      worldState.mineTileStep(tx, ty, 0.22);
    }
    onHudChanged();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animTime += dt;

    final kbLeft =
        _keysPressed.contains(LogicalKeyboardKey.keyA) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowLeft);
    final kbRight =
        _keysPressed.contains(LogicalKeyboardKey.keyD) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowRight);
    final kbJump =
        _keysPressed.contains(LogicalKeyboardKey.space) ||
        _keysPressed.contains(LogicalKeyboardKey.keyW) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowUp);
    final kbDown =
        _keysPressed.contains(LogicalKeyboardKey.keyS) ||
        _keysPressed.contains(LogicalKeyboardKey.arrowDown);

    worldState.update(
      dt,
      moveLeft: inputLeft || kbLeft,
      moveRight: inputRight || kbRight,
      jumpOrSwimUp: inputJump || kbJump,
      climbDown: inputDown || kbDown,
    );

    if (worldState.pendingSoundEvents.isNotEmpty) {
      for (final event in worldState.pendingSoundEvents) {
        soundscape.playEvent(event, soundEnabled: worldState.soundEnabled);
      }
      worldState.pendingSoundEvents.clear();
    }
    soundscape.updateAmbientBeeBuzz(
      dt,
      soundEnabled: worldState.soundEnabled,
      intensity: worldState.beeBuzzIntensity,
      isAngry: worldState.beeBuzzAngry,
      pan: worldState.beeBuzzPan,
    );

    if (_pointerHeld && _pointerScreenPos != null) {
      final (tx, ty) = screenToTile(_pointerScreenPos!);
      if (interactionMode == InteractionMode.buildOrSow) {
        worldState.interactOrPlaceAt(tx, ty);
      } else {
        final targetBlock = worldState.getBlock(tx, ty);
        if (targetBlock != BlockType.air && targetBlock != BlockType.water) {
          worldState.mineTileStep(tx, ty, dt);
        } else if (worldState.equippedItem.category == ItemCategory.building ||
            worldState.equippedItem.category == ItemCategory.seed ||
            worldState.equippedItem == ItemType.waterBucket) {
          worldState.interactOrPlaceAt(tx, ty);
        }
      }
    }

    _hudNotifyAccumulator += dt;
    if (_hudNotifyAccumulator >= 0.15) {
      _hudNotifyAccumulator = 0.0;
      onHudChanged();
    }
  }

  int _tileHash(int tx, int ty) {
    int h = tx * 374761393 + ty * 668265263 + worldState.worldSeed * 198491317;
    h = (h ^ (h >> 13)) * 1274126177;
    return (h ^ (h >> 16)) & 0x7FFFFFFF;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final viewW = size.x;
    final viewH = size.y;
    if (viewW <= 0 || viewH <= 0) return;

    final cam = cameraTopLeft;
    _renderSkyAndCanopyBackdrop(canvas, viewW, viewH, cam);

    canvas.save();
    canvas.translate(-cam.dx, -cam.dy);

    final startTx = JungleWorld.pixelToTile(cam.dx) - 1;
    final endTx = JungleWorld.pixelToTile(cam.dx + viewW) + 2;
    final startTy = (JungleWorld.pixelToTile(cam.dy) - 1).clamp(
      0,
      worldState.height - 1,
    );
    final endTy = (JungleWorld.pixelToTile(cam.dy + viewH) + 2).clamp(
      0,
      worldState.height - 1,
    );

    // 1. Render textured background shelter walls with masonry/plank bevels.
    for (int ty = startTy; ty <= endTy; ty++) {
      for (int tx = startTx; tx <= endTx; tx++) {
        final wall = worldState.walls[ty][tx];
        if (wall != WallType.none) {
          _renderWall(canvas, tx, ty, wall);
        }
      }
    }

    // 2. Render foreground blocks (including Beehives, Flowing Water & Wildfire).
    for (int ty = startTy; ty <= endTy; ty++) {
      for (int tx = startTx; tx <= endTx; tx++) {
        final block = worldState.blocks[ty][tx];
        if (block != BlockType.air) {
          _renderBlock(canvas, tx, ty, block);
        }
      }
    }

    // 3. Render growing crops on tilled/specialized soil.
    for (final crop in worldState.crops.values) {
      if (crop.tileX >= startTx &&
          crop.tileX <= endTx &&
          crop.tileY >= startTy &&
          crop.tileY <= endTy) {
        _renderCrop(canvas, crop);
      }
    }

    // 4. Render Native Villagers & speech prompts.
    for (final v in worldState.villagers) {
      _renderVillager(canvas, v);
    }

    // 5. Render Wildlife & Buzzing Bee Swarms.
    for (final a in worldState.animals) {
      _renderAnimal(canvas, a);
    }

    // 6. Render Active Fishing Line & Bobber.
    if (worldState.activeFishing != null) {
      _renderFishingLine(canvas, worldState.activeFishing!);
    }

    // 7. Render the Detailed Explorer Character & Equipped Tool/Weapon.
    _renderExplorer(canvas);

    // 8. Render jagged mining fracture cracks on targeted tile.
    if (worldState.miningTarget != null && worldState.miningProgress > 0) {
      final (mtx, mty) = worldState.miningTarget!;
      final mRect = Rect.fromLTWH(
        mtx * JungleWorld.tileSize,
        mty * JungleWorld.tileSize,
        JungleWorld.tileSize,
        JungleWorld.tileSize,
      );
      final prog = worldState.miningProgress.clamp(0.0, 1.0);
      final crackPaint =
          Paint()
            ..color = Colors.white.withValues(alpha: 0.78)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8;
      canvas.drawRRect(
        RRect.fromRectAndRadius(mRect.deflate(1.5), const Radius.circular(3)),
        crackPaint,
      );
      final cx = mRect.center.dx;
      final cy = mRect.center.dy;
      for (final (dx, dy) in const [
        (-12.0, -11.0),
        (13.0, -9.0),
        (-10.0, 12.0),
        (11.0, 13.0),
        (2.0, -14.0),
      ]) {
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx + dx * prog, cy + dy * prog),
          crackPaint,
        );
      }
    }

    canvas.restore();

    // 9. Render floating pollen/fireflies, rain droplets & night ambient lighting.
    _renderAtmosphericParticles(canvas, viewW, viewH, cam);
    if (worldState.isRaining) {
      _renderRainOverlay(canvas, viewW, viewH);
    }
    _renderNightAndWarmthLighting(canvas, viewW, viewH, cam);
  }

  void _renderWall(Canvas canvas, int tx, int ty, WallType wall) {
    const s = JungleWorld.tileSize;
    final left = tx * s;
    final top = ty * s;
    final rect = Rect.fromLTWH(left, top, s, s);
    canvas.drawRect(rect, Paint()..color = wall.color);

    if (wall == WallType.woodWall) {
      final plankHighlight = Paint()..color = const Color(0x28FFCC80);
      final plankShadow =
          Paint()
            ..color = const Color(0x551B0F0A)
            ..strokeWidth = 1.2;
      for (double py = 0; py < s; py += 8) {
        canvas.drawRect(Rect.fromLTWH(left, top + py, s, 2.0), plankHighlight);
        canvas.drawLine(
          Offset(left, top + py + 7.5),
          Offset(left + s, top + py + 7.5),
          plankShadow,
        );
      }
      final jointX = left + ((ty.isEven ? 10.0 : 22.0));
      canvas.drawLine(
        Offset(jointX, top),
        Offset(jointX, top + s),
        plankShadow,
      );
    } else if (wall == WallType.dirtWall) {
      // Natural cavern rock/earth strata with embedded mineral flecks.
      final strata =
          Paint()
            ..color = const Color(0x55221410)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4;
      final bevel = Paint()..color = const Color(0x1ECFD8DC);
      canvas.drawRect(Rect.fromLTWH(left + 2, top + 2, 13, 12), bevel);
      canvas.drawRect(Rect.fromLTWH(left + 17, top + 2, 13, 12), bevel);
      canvas.drawRect(Rect.fromLTWH(left + 6, top + 16, 18, 13), bevel);
      canvas.drawLine(
        Offset(left, top + 15),
        Offset(left + s, top + 15),
        strata,
      );
      canvas.drawLine(
        Offset(left + 16, top),
        Offset(left + 16, top + 15),
        strata,
      );
      canvas.drawLine(
        Offset(left + 8, top + 15),
        Offset(left + 8, top + s),
        strata,
      );
    } else if (wall == WallType.thatchWall || wall == WallType.villageWall) {
      // Woven diagonal bamboo & palm-thatch lattice.
      final weaveLight =
          Paint()
            ..color = const Color(0x33FFE082)
            ..strokeWidth = 1.4;
      final weaveDark =
          Paint()
            ..color = const Color(0x442E1C10)
            ..strokeWidth = 1.4;
      for (double d = 4; d < s; d += 8) {
        canvas.drawLine(
          Offset(left + d, top),
          Offset(left, top + d),
          weaveLight,
        );
        canvas.drawLine(
          Offset(left + s, top + d),
          Offset(left + d, top + s),
          weaveLight,
        );
        canvas.drawLine(
          Offset(left + s - d, top),
          Offset(left + s, top + d),
          weaveDark,
        );
      }
    }
  }

  void _renderSkyAndCanopyBackdrop(
    Canvas canvas,
    double viewW,
    double viewH,
    Offset cam,
  ) {
    final t = worldState.timeOfDay;
    Color topSky;
    Color midSky;
    Color bottomSky;
    if (t >= 0.23 && t <= 0.72) {
      topSky = const Color(0xFF0D47A1);
      midSky = const Color(0xFF1E88E5);
      bottomSky = const Color(0xFFB3E5FC);
    } else if ((t > 0.72 && t <= 0.80) || (t >= 0.16 && t < 0.23)) {
      topSky = const Color(0xFF1A237E);
      midSky = const Color(0xFF8E24AA);
      bottomSky = const Color(0xFFFF7043);
    } else {
      topSky = const Color(0xFF040711);
      midSky = const Color(0xFF0D1528);
      bottomSky = const Color(0xFF1B2A47);
    }

    final skyPaint =
        Paint()
          ..shader = Gradient.linear(
            Offset.zero,
            Offset(0, viewH),
            [topSky, midSky, bottomSky],
            [0.0, 0.52, 1.0],
          );
    canvas.drawRect(Rect.fromLTWH(0, 0, viewW, viewH), skyPaint);

    // 1. Twinkling starfield at night/dusk.
    if (worldState.isNight) {
      for (int i = 0; i < 42; i++) {
        final sx = ((i * 173.3 + 29.0) % viewW);
        final sy = ((i * 97.7 + 13.0) % (viewH * 0.55));
        final twinkle =
            0.35 + 0.65 * (0.5 + 0.5 * math.sin(_animTime * 3.2 + i * 1.7));
        final radius = (i % 5 == 0) ? 1.8 : 1.1;
        canvas.drawCircle(
          Offset(sx, sy),
          radius,
          Paint()..color = Colors.white.withValues(alpha: twinkle * 0.85),
        );
      }
    }

    // 2. High-definition Sun (with corona & volumetric sunbeams) or cratered Moon.
    final sunAngle = (t - 0.2) * math.pi * 2.0;
    final orbX = viewW * 0.5 + math.cos(sunAngle) * (viewW * 0.36);
    final orbY = viewH * 0.38 - math.sin(sunAngle) * (viewH * 0.28);
    final isSun = math.sin(sunAngle) >= 0;
    final orbCenter = Offset(orbX, orbY);

    if (isSun) {
      // Volumetric diagonal crepuscular god-rays filtering down into the jungle.
      for (int r = -2; r <= 2; r++) {
        final raySpread = r * 75.0;
        final rayPath =
            Path()
              ..moveTo(orbX - 14, orbY)
              ..lineTo(orbX + 14, orbY)
              ..lineTo(orbX + raySpread + 95, viewH)
              ..lineTo(orbX + raySpread - 95, viewH)
              ..close();
        canvas.drawPath(
          rayPath,
          Paint()
            ..shader = Gradient.linear(
              orbCenter,
              Offset(orbX + raySpread, viewH),
              [const Color(0x1EFFF59D), const Color(0x00FFF59D)],
            ),
        );
      }
      // Multi-ring solar corona + bright core.
      canvas.drawCircle(
        orbCenter,
        58.0,
        Paint()
          ..shader = Gradient.radial(orbCenter, 58.0, [
            const Color(0x55FFF176),
            const Color(0x00FFF176),
          ]),
      );
      canvas.drawCircle(
        orbCenter,
        26.0,
        Paint()..color = const Color(0xFFFFF59D),
      );
      canvas.drawCircle(
        orbCenter,
        20.0,
        Paint()..color = const Color(0xFFFFFFFF),
      );
    } else {
      // Lunar halo + cratered crescent moon.
      canvas.drawCircle(
        orbCenter,
        46.0,
        Paint()
          ..shader = Gradient.radial(orbCenter, 46.0, [
            const Color(0x38B3E5FC),
            const Color(0x00B3E5FC),
          ]),
      );
      canvas.drawCircle(
        orbCenter,
        19.0,
        Paint()..color = const Color(0xFFECEFF1),
      );
      canvas.drawCircle(
        Offset(orbX - 5, orbY - 4),
        3.5,
        Paint()..color = const Color(0xFFB0BEC5),
      );
      canvas.drawCircle(
        Offset(orbX + 6, orbY + 5),
        4.5,
        Paint()..color = const Color(0xFFB0BEC5),
      );
      canvas.drawCircle(
        Offset(orbX + 2, orbY - 7),
        2.2,
        Paint()..color = const Color(0xFFB0BEC5),
      );
    }

    // 3. Soft drifting tropical clouds (0.08x parallax + wind drift).
    final cloudShift = -((cam.dx * 0.08 + _animTime * 8.0) % 260.0);
    final cloudColor =
        worldState.isNight ? const Color(0x2437474F) : const Color(0x48FFFFFF);
    for (double cx = cloudShift - 260.0; cx < viewW + 260.0; cx += 260.0) {
      final cy = viewH * 0.22 + math.sin(cx * 0.01) * 18.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx + 90, cy), width: 130, height: 28),
          const Radius.circular(14),
        ),
        Paint()..color = cloudColor,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + 70, cy - 10),
          width: 64,
          height: 32,
        ),
        Paint()..color = cloudColor,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + 112, cy - 7),
          width: 52,
          height: 26,
        ),
        Paint()..color = cloudColor,
      );
    }

    // 4. Parallax Layer 1 (Far 0.12x): Misty Highland Mountain Ridges.
    final ridgeColor =
        worldState.isNight
            ? const Color(0xFF0A141D)
            : const Color(0xFF2E5B58).withValues(alpha: 0.55);
    final ridgePath = Path()..moveTo(0, viewH);
    final farShift = cam.dx * 0.12;
    for (double x = 0; x <= viewW + 40; x += 40) {
      final wx = x + farShift;
      final ridgeY =
          viewH * 0.50 +
          math.sin(wx * 0.0065) * 44.0 +
          math.cos(wx * 0.015) * 22.0;
      ridgePath.lineTo(x, ridgeY);
    }
    ridgePath
      ..lineTo(viewW, viewH)
      ..close();
    canvas.drawPath(ridgePath, Paint()..color = ridgeColor);

    // 5. Parallax Layer 2 (Mid 0.24x): Giant Emergent Rainforest Trees & Lianas.
    final midTrunkColor =
        worldState.isNight ? const Color(0xFF0B1911) : const Color(0xFF1E3F29);
    final midCrownColor =
        worldState.isNight ? const Color(0xFF0D2116) : const Color(0xFF1B4D2E);
    final midHighlightColor =
        worldState.isNight ? const Color(0xFF143020) : const Color(0xFF2E6B3E);
    final midParallax = -(cam.dx * 0.24) % 180.0;
    for (double x = midParallax - 180.0; x < viewW + 180.0; x += 180.0) {
      final treeX = x + 90.0;
      final crownY = viewH * 0.56;
      // Emergent trunk with flared buttress roots.
      final trunkPath =
          Path()
            ..moveTo(treeX - 18, viewH)
            ..quadraticBezierTo(treeX - 9, crownY + 60, treeX - 8, crownY)
            ..lineTo(treeX + 8, crownY)
            ..quadraticBezierTo(treeX + 9, crownY + 60, treeX + 18, viewH)
            ..close();
      canvas.drawPath(trunkPath, Paint()..color = midTrunkColor);

      // Multi-lobed rainforest canopy crown.
      canvas.drawOval(
        Rect.fromCenter(center: Offset(treeX, crownY), width: 165, height: 88),
        Paint()..color = midCrownColor,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(treeX - 36, crownY - 14),
          width: 96,
          height: 58,
        ),
        Paint()..color = midHighlightColor,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(treeX + 38, crownY - 10),
          width: 104,
          height: 62,
        ),
        Paint()..color = midHighlightColor,
      );

      // Swaying background hanging vines.
      for (final vOffset in const [-48.0, 28.0, 56.0]) {
        final sway = math.sin(_animTime * 1.6 + vOffset) * 5.0;
        final vPath =
            Path()
              ..moveTo(treeX + vOffset, crownY + 20)
              ..quadraticBezierTo(
                treeX + vOffset + sway,
                crownY + 75,
                treeX + vOffset + sway * 0.6,
                crownY + 130,
              );
        canvas.drawPath(
          vPath,
          Paint()
            ..color = midTrunkColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }
    }

    // 6. Atmospheric tropical mist band near the horizon.
    canvas.drawRect(
      Rect.fromLTWH(0, viewH * 0.55, viewW, viewH * 0.25),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, viewH * 0.55),
          Offset(0, viewH * 0.80),
          [
            const Color(0x00FFFFFF),
            worldState.isNight
                ? const Color(0x1826A69A)
                : const Color(0x22B2DFDB),
            const Color(0x00FFFFFF),
          ],
          [0.0, 0.5, 1.0],
        ),
    );
  }

  void _renderBlock(Canvas canvas, int tx, int ty, BlockType block) {
    const s = JungleWorld.tileSize;
    final left = tx * s;
    final top = ty * s;
    final rect = Rect.fromLTWH(left, top, s, s);
    final fill = Paint()..color = block.primaryColor;
    final accent = Paint()..color = block.accentColor;
    final h = _tileHash(tx, ty);

    switch (block) {
      case BlockType.grass:
        // Rich shaded loam base with pebbles + rootlets.
        _drawDetailedDirtBase(canvas, rect, left, top, h);
        // Drop shadow under grass turf lip.
        canvas.drawRect(
          Rect.fromLTWH(left, top + 8.0, s, 3.0),
          Paint()..color = const Color(0x44000000),
        );
        // Lush multi-tone grass mantle with scalloped overhang.
        final turfGradient =
            Paint()
              ..shader = Gradient.linear(
                Offset(left, top),
                Offset(left, top + 9.0),
                [const Color(0xFF66BB6A), const Color(0xFF2E7D32)],
              );
        canvas.drawRect(Rect.fromLTWH(left, top, s, 8.5), turfGradient);
        for (int i = 0; i < 4; i++) {
          canvas.drawCircle(
            Offset(left + 4.0 + i * 8.0, top + 8.0),
            3.2,
            Paint()..color = const Color(0xFF2E7D32),
          );
        }
        // Individual swaying grass blades + occasional tiny wildflower!
        final breeze = math.sin(_animTime * 2.6 + tx * 0.7) * 1.6;
        for (int b = 0; b < 6; b++) {
          final gx = left + 3.0 + b * 5.2;
          final bladeH = 3.5 + ((h >> (b * 2)) & 3) * 1.1;
          canvas.drawLine(
            Offset(gx, top + 2.0),
            Offset(gx + breeze, top - bladeH),
            Paint()
              ..color =
                  b.isEven ? const Color(0xFF81C784) : const Color(0xFF43A047)
              ..strokeWidth = 1.6
              ..strokeCap = StrokeCap.round,
          );
        }
        if (h % 5 == 0) {
          final fx = left + 8.0 + (h % 16);
          final flowerColor =
              (h % 2 == 0) ? const Color(0xFFFF80AB) : const Color(0xFFFFF176);
          canvas.drawCircle(
            Offset(fx + breeze * 0.5, top - 2.2),
            2.1,
            Paint()..color = flowerColor,
          );
          canvas.drawCircle(
            Offset(fx + breeze * 0.5, top - 2.2),
            0.9,
            Paint()..color = const Color(0xFFFF6F00),
          );
        }

      case BlockType.dirt:
        _drawDetailedDirtBase(canvas, rect, left, top, h);

      case BlockType.tilledSoil:
        _drawDetailedDirtBase(canvas, rect, left, top, h);
        // Sculpted 3D ploughed soil ridges and dark moisture troughs.
        canvas.drawRect(
          Rect.fromLTWH(left, top, s, 9.0),
          Paint()..color = const Color(0xFF3E2723),
        );
        for (double dx = 2; dx < s - 2; dx += 7.5) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(left + dx, top - 1.5, 5.0, 7.5),
              const Radius.circular(2.5),
            ),
            Paint()..color = const Color(0xFF795548),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(left + dx + 0.8, top - 1.0, 3.2, 2.5),
              const Radius.circular(1.2),
            ),
            Paint()..color = const Color(0xFFA1887F),
          );
        }

      case BlockType.riverSilt:
        // Wet gradient silt with glistening cyan mineral sheen & smooth pebbles.
        canvas.drawRect(
          rect,
          Paint()
            ..shader = Gradient.linear(
              Offset(left, top),
              Offset(left, top + s),
              [const Color(0xFF455A64), const Color(0xFF263238)],
            ),
        );
        canvas.drawRect(
          Rect.fromLTWH(left, top, s, 6.0),
          Paint()
            ..shader = Gradient.linear(
              Offset(left, top),
              Offset(left, top + 6.0),
              [const Color(0xFF26C6DA), const Color(0xFF00838F)],
            ),
        );
        for (int i = 0; i < 4; i++) {
          final px = left + 4.0 + ((h >> (i * 3)) % 22);
          final py = top + 9.0 + i * 5.2;
          canvas.drawOval(
            Rect.fromCenter(center: Offset(px, py), width: 6.5, height: 3.5),
            Paint()
              ..color =
                  i.isEven ? const Color(0xFF80DEEA) : const Color(0xFF546E7A),
          );
        }

      case BlockType.peatBog:
        // Rich acidic peat with glowing chartreuse sphagnum moss cushions.
        canvas.drawRect(
          rect,
          Paint()
            ..shader = Gradient.linear(
              Offset(left, top),
              Offset(left, top + s),
              [const Color(0xFF4A2545), const Color(0xFF2A1528)],
            ),
        );
        canvas.drawRect(Rect.fromLTWH(left, top, s, 6.5), accent);
        for (double gx = 3; gx < s - 2; gx += 5.5) {
          canvas.drawCircle(
            Offset(left + gx, top + 2.5),
            3.0,
            Paint()..color = const Color(0xFF9CCC65),
          );
          canvas.drawCircle(
            Offset(left + gx - 0.6, top + 1.5),
            1.4,
            Paint()..color = const Color(0xFFDCE775),
          );
        }
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(left + 10, top + 16),
            width: 8,
            height: 4.5,
          ),
          Paint()..color = const Color(0xFF1F0D1D),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(left + 22, top + 23),
            width: 7,
            height: 4.0,
          ),
          Paint()..color = const Color(0xFF1F0D1D),
        );

      case BlockType.volcanicAsh:
        // Dark basalt tephra with glowing ember fissures & mineral crystals.
        canvas.drawRect(
          rect,
          Paint()
            ..shader = Gradient.linear(
              Offset(left, top),
              Offset(left, top + s),
              [const Color(0xFF37474F), const Color(0xFF1C262B)],
            ),
        );
        canvas.drawRect(
          Rect.fromLTWH(left, top, s, 5.0),
          Paint()..color = const Color(0xFF546E7A),
        );
        final fissurePath =
            Path()
              ..moveTo(left + 6, top + 10)
              ..lineTo(left + 15, top + 17)
              ..lineTo(left + 25, top + 13);
        canvas.drawPath(
          fissurePath,
          Paint()
            ..color = const Color(0xFFFF7043)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
        canvas.drawCircle(Offset(left + 9, top + 22), 2.4, accent);
        canvas.drawCircle(
          Offset(left + 22, top + 24),
          2.0,
          Paint()..color = const Color(0xFFFFCA28),
        );

      case BlockType.stone:
      case BlockType.coalOre:
      case BlockType.ironOre:
        // Faceted rock block with bevels, strata cracks, and gleaming ore crystals.
        canvas.drawRect(
          rect,
          Paint()
            ..shader = Gradient.linear(
              Offset(left, top),
              Offset(left + s, top + s),
              [const Color(0xFF78909C), const Color(0xFF455A64)],
            ),
        );
        // Top-left highlight bevel & bottom-right shadow bevel.
        canvas.drawLine(
          Offset(left + 1, top + 1),
          Offset(left + s - 1, top + 1),
          Paint()..color = const Color(0x44ECEFF1),
        );
        canvas.drawLine(
          Offset(left + 1, top + s - 1),
          Offset(left + s - 1, top + s - 1),
          Paint()..color = const Color(0x66102027),
        );
        // Rock fracture line.
        canvas.drawLine(
          Offset(left + 5 + (h % 6), top + 7),
          Offset(left + 22 - (h % 5), top + 19),
          Paint()
            ..color = const Color(0x55263238)
            ..strokeWidth = 1.4,
        );
        if (block == BlockType.coalOre || block == BlockType.ironOre) {
          final isIron = block == BlockType.ironOre;
          final glintColor =
              isIron ? const Color(0xFFFFF8E1) : const Color(0xFF546E7A);
          for (final (ox, oy, rad) in const [
            (9.0, 10.0, 4.2),
            (22.0, 14.0, 3.8),
            (14.0, 23.0, 4.5),
            (24.0, 25.0, 2.8),
          ]) {
            canvas.drawCircle(Offset(left + ox, top + oy), rad, accent);
            canvas.drawCircle(
              Offset(left + ox - 1.2, top + oy - 1.2),
              rad * 0.38,
              Paint()..color = glintColor,
            );
          }
        }

      case BlockType.woodLog:
        // Cylindrical shaded mahogany trunk with vertical bark ridges.
        final logRect = Rect.fromLTWH(left + 5, top, s - 10, s);
        canvas.drawRect(
          logRect,
          Paint()
            ..shader = Gradient.linear(
              Offset(logRect.left, top),
              Offset(logRect.right, top),
              [
                const Color(0xFF3E2723),
                const Color(0xFF6D4C41),
                const Color(0xFF4E342E),
                const Color(0xFF271914),
              ],
              [0.0, 0.35, 0.72, 1.0],
            ),
        );
        final barkLine =
            Paint()
              ..color = const Color(0x66271914)
              ..strokeWidth = 1.3;
        canvas.drawLine(
          Offset(left + 10, top),
          Offset(left + 10, top + s),
          barkLine,
        );
        canvas.drawLine(
          Offset(left + 16, top),
          Offset(left + 16, top + s),
          barkLine,
        );
        canvas.drawLine(
          Offset(left + 21, top),
          Offset(left + 21, top + s),
          barkLine,
        );
        if (h % 3 == 0) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(left + 14, top + 16),
              width: 5,
              height: 7,
            ),
            Paint()..color = const Color(0xFF271914),
          );
        }

      case BlockType.leaves:
        // Lush multi-layered canopy leaf clusters with sunlit highlights.
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(0.5), const Radius.circular(7)),
          Paint()..color = const Color(0xFF1B5E20),
        );
        canvas.drawCircle(
          Offset(left + 10, top + 11),
          9.0,
          Paint()..color = const Color(0xFF2E7D32),
        );
        canvas.drawCircle(
          Offset(left + 22, top + 13),
          8.5,
          Paint()..color = const Color(0xFF388E3C),
        );
        canvas.drawCircle(
          Offset(left + 15, top + 22),
          8.5,
          Paint()..color = const Color(0xFF2E7D32),
        );
        canvas.drawCircle(
          Offset(left + 11, top + 9),
          4.5,
          Paint()..color = const Color(0xFF66BB6A),
        );
        canvas.drawCircle(
          Offset(left + 21, top + 11),
          4.0,
          Paint()..color = const Color(0xFF81C784),
        );

      case BlockType.vine:
        final sway = math.sin(_animTime * 2.4 + ty * 0.6) * 2.2;
        final vinePath =
            Path()
              ..moveTo(left + 16, top)
              ..quadraticBezierTo(
                left + 16 + sway,
                top + s * 0.5,
                left + 16 - sway * 0.5,
                top + s,
              );
        canvas.drawPath(
          vinePath,
          Paint()
            ..color = const Color(0xFF33691E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.8,
        );
        // Alternating heart-shaped liana leaves.
        for (final (ly, dirLeaf) in const [(8.0, -1.0), (20.0, 1.0)]) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(left + 16 + sway * 0.6 + dirLeaf * 5.0, top + ly),
              width: 7.5,
              height: 4.8,
            ),
            Paint()..color = const Color(0xFF7CB342),
          );
        }

      case BlockType.berryBush:
        // Multi-layered bush foliage + glossy 3D ruby berries with white specular dots.
        canvas.drawOval(
          Rect.fromLTWH(left + 2, top + 7, s - 4, s - 6),
          Paint()..color = const Color(0xFF1B5E20),
        );
        canvas.drawCircle(
          Offset(left + 11, top + 14),
          8.0,
          Paint()..color = const Color(0xFF2E7D32),
        );
        canvas.drawCircle(
          Offset(left + 21, top + 15),
          7.5,
          Paint()..color = const Color(0xFF388E3C),
        );
        for (final (bx, by) in const [
          (10.0, 14.0),
          (21.0, 16.0),
          (15.0, 22.0),
          (17.0, 11.0),
        ]) {
          canvas.drawCircle(
            Offset(left + bx, top + by),
            3.5,
            Paint()..color = const Color(0xFFC62828),
          );
          canvas.drawCircle(
            Offset(left + bx - 0.5, top + by - 0.5),
            2.6,
            Paint()..color = const Color(0xFFFF1744),
          );
          canvas.drawCircle(
            Offset(left + bx - 1.2, top + by - 1.2),
            0.9,
            Paint()..color = Colors.white,
          );
        }

      case BlockType.beehive:
        // Tiered golden honeycomb hive with shaded ribs, entrance, & dripping honey.
        for (int tier = 0; tier < 4; tier++) {
          final tw = s - 8.0 - (tier - 1.5).abs() * 3.2;
          final tyOffset = top + 5.0 + tier * 5.5;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(left + s * 0.5, tyOffset),
                width: tw,
                height: 6.8,
              ),
              const Radius.circular(3.5),
            ),
            Paint()
              ..color =
                  tier.isEven
                      ? const Color(0xFFFFB300)
                      : const Color(0xFFFF8F00),
          );
        }
        canvas.drawCircle(
          Offset(left + s * 0.5, top + 18),
          4.0,
          Paint()..color = const Color(0xFF3E2723),
        );
        final dropOffset = (_animTime * 9.0 + tx * 2.0) % 7.0;
        canvas.drawCircle(
          Offset(left + s * 0.5 + 4, top + s - 3 + dropOffset),
          2.4,
          Paint()..color = const Color(0xFFFFD54F),
        );
        canvas.drawCircle(
          Offset(left + s * 0.5 + 3.3, top + s - 3.6 + dropOffset),
          0.9,
          Paint()..color = Colors.white,
        );

      case BlockType.wildfire:
        final f1 = math.sin(_animTime * 16.0 + tx) * 4.0;
        final f2 = math.cos(_animTime * 20.0 + ty) * 3.5;
        // Soft fire glow halo.
        canvas.drawCircle(
          Offset(left + 16, top + 16),
          24.0,
          Paint()
            ..shader = Gradient.radial(Offset(left + 16, top + 16), 24.0, [
              const Color(0x55FF6D00),
              const Color(0x00FF6D00),
            ]),
        );
        final outerFlame =
            Path()
              ..moveTo(left + 3, top + s)
              ..lineTo(left + 8, top + 8 + f1)
              ..lineTo(left + 16, top + 2 + f2)
              ..lineTo(left + 24, top + 9 - f1)
              ..lineTo(left + s - 3, top + s)
              ..close();
        canvas.drawPath(outerFlame, fill);
        final innerFlame =
            Path()
              ..moveTo(left + 8, top + s)
              ..lineTo(left + 16, top + 10 + f2)
              ..lineTo(left + 24, top + s)
              ..close();
        canvas.drawPath(innerFlame, accent);
        final emberY = top + 4 - ((_animTime * 28.0 + tx * 7) % 14.0);
        canvas.drawCircle(
          Offset(left + 16 + f1, emberY),
          2.0,
          Paint()..color = const Color(0xFFFFEA00),
        );

      case BlockType.water:
        final wave = math.sin(_animTime * 3.2 + tx * 0.7) * 2.0;
        final isFalling =
            ty + 1 < worldState.height &&
            worldState.getBlock(tx, ty + 1) == BlockType.air;
        final isSurface =
            ty == 0 || worldState.getBlock(tx, ty - 1) != BlockType.water;
        final topY = top + (isFalling ? 0.0 : (isSurface ? 2.5 + wave : 0.0));
        final waterRect = Rect.fromLTWH(left, topY, s, s - (topY - top));
        canvas.drawRect(
          waterRect,
          Paint()
            ..shader = Gradient.linear(
              Offset(left, top),
              Offset(left, top + s),
              [const Color(0xCC29B6F6), const Color(0xDD0277BD)],
            ),
        );
        if (isSurface && !isFalling) {
          // Sparkling surface foam crest.
          canvas.drawRect(
            Rect.fromLTWH(left + 2, topY, s - 4, 2.8),
            Paint()..color = const Color(0xAAFFFFFF),
          );
        }
        // Subsurface shimmering caustic wave ribbon.
        final causticX = left + 6.0 + math.sin(_animTime * 2.5 + ty) * 4.0;
        canvas.drawLine(
          Offset(causticX, topY + 9),
          Offset(causticX + 14, topY + 7),
          Paint()
            ..color = const Color(0x5581D4FA)
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round,
        );
        if (isFalling) {
          canvas.drawLine(
            Offset(left + 10, top + 2),
            Offset(left + 10, top + s - 2),
            Paint()
              ..color = Colors.white70
              ..strokeWidth = 2.2,
          );
          canvas.drawLine(
            Offset(left + 21, top + 4),
            Offset(left + 21, top + s - 2),
            Paint()
              ..color = Colors.white70
              ..strokeWidth = 2.2,
          );
        }

      case BlockType.campfire:
        // Warm glow halo + crossed logs + ember bed + 3-layer flame.
        canvas.drawCircle(
          Offset(left + 16, top + 18),
          22.0,
          Paint()
            ..shader = Gradient.radial(Offset(left + 16, top + 18), 22.0, [
              const Color(0x44FF9100),
              const Color(0x00FF9100),
            ]),
        );
        canvas.drawLine(
          Offset(left + 4, top + 28),
          Offset(left + 28, top + 22),
          Paint()
            ..color = const Color(0xFF4E342E)
            ..strokeWidth = 4.5
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          Offset(left + 28, top + 28),
          Offset(left + 4, top + 22),
          Paint()
            ..color = const Color(0xFF5D4037)
            ..strokeWidth = 4.5
            ..strokeCap = StrokeCap.round,
        );
        final flicker = math.sin(_animTime * 12.0 + tx) * 3.0;
        final flamePath =
            Path()
              ..moveTo(left + 7, top + 24)
              ..quadraticBezierTo(
                left + 10,
                top + 12,
                left + 16,
                top + 5 + flicker,
              )
              ..quadraticBezierTo(left + 22, top + 12, left + 25, top + 24)
              ..close();
        canvas.drawPath(flamePath, fill);
        canvas.drawCircle(Offset(left + 16, top + 18), 5.2, accent);
        canvas.drawCircle(
          Offset(left + 16, top + 19),
          2.6,
          Paint()..color = Colors.white,
        );

      case BlockType.torch:
        final flickerY = math.sin(_animTime * 11.0 + tx) * 1.5;
        canvas.drawCircle(
          Offset(left + 16, top + 10 + flickerY),
          14.0,
          Paint()
            ..shader = Gradient.radial(
              Offset(left + 16, top + 10 + flickerY),
              14.0,
              [const Color(0x55FFD54F), const Color(0x00FFD54F)],
            ),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left + 14, top + 12, 4, 16),
            const Radius.circular(1.5),
          ),
          Paint()..color = const Color(0xFF6D4C41),
        );
        canvas.drawCircle(Offset(left + 16, top + 10 + flickerY), 5.0, fill);
        canvas.drawCircle(
          Offset(left + 16, top + 10 + flickerY),
          2.4,
          Paint()..color = const Color(0xFFFFFFFF),
        );

      case BlockType.thatchRoof:
        // Layered golden palm-thatch bundles with diagonal weave & overhanging eaves.
        canvas.drawRect(
          rect,
          Paint()
            ..shader = Gradient.linear(
              Offset(left, top),
              Offset(left, top + s),
              [const Color(0xFFD4AC0D), const Color(0xFF9A7D0A)],
            ),
        );
        final strawPaint =
            Paint()
              ..color = const Color(0xFFF7DC6F)
              ..strokeWidth = 1.4;
        for (double sx = 3; sx < s; sx += 5.5) {
          canvas.drawLine(
            Offset(left + sx, top + 2),
            Offset(left + sx - 2, top + s - 1),
            strawPaint,
          );
        }
        canvas.drawLine(
          Offset(left, top + 10),
          Offset(left + s, top + 10),
          Paint()
            ..color = const Color(0xFF7D6608)
            ..strokeWidth = 1.8,
        );
        canvas.drawLine(
          Offset(left, top + 21),
          Offset(left + s, top + 21),
          Paint()
            ..color = const Color(0xFF7D6608)
            ..strokeWidth = 1.8,
        );

      case BlockType.woodPlank:
      case BlockType.villageHutBlock:
        canvas.drawRect(
          rect,
          Paint()
            ..shader = Gradient.linear(
              Offset(left, top),
              Offset(left, top + s),
              [block.primaryColor, const Color(0xFF4E342E)],
            ),
        );
        for (double py = 8; py < s; py += 8) {
          canvas.drawLine(
            Offset(left, top + py),
            Offset(left + s, top + py),
            Paint()
              ..color = const Color(0x55271914)
              ..strokeWidth = 1.4,
          );
        }
        if (block == BlockType.villageHutBlock) {
          // Carved geometric tribal chevron band.
          canvas.drawRect(
            Rect.fromLTWH(left, top + 12, s, 6),
            Paint()..color = const Color(0xFFFFB300),
          );
        }

      case BlockType.doorClosed:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left + 7, top, s - 14, s),
            const Radius.circular(2),
          ),
          fill,
        );
        canvas.drawRect(
          Rect.fromLTWH(left + 10, top + 3, s - 20, 11),
          Paint()..color = const Color(0xFF4E342E),
        );
        canvas.drawRect(
          Rect.fromLTWH(left + 10, top + 17, s - 20, 11),
          Paint()..color = const Color(0xFF4E342E),
        );
        canvas.drawCircle(Offset(left + 20, top + 16), 2.6, accent);
      case BlockType.doorOpen:
        canvas.drawRect(Rect.fromLTWH(left + 2, top, 7, s), fill);
      default:
        canvas.drawRect(rect, fill);
        canvas.drawRect(
          rect.deflate(3.0),
          Paint()
            ..color = block.accentColor.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
    }
  }

  void _drawDetailedDirtBase(
    Canvas canvas,
    Rect rect,
    double left,
    double top,
    int h,
  ) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = Gradient.linear(
          Offset(left, top),
          Offset(left, top + rect.height),
          [const Color(0xFF6D4C41), const Color(0xFF4E342E)],
        ),
    );
    // Subsoil pebbles & organic loam speckles.
    for (int i = 0; i < 3; i++) {
      final px = left + 5.0 + ((h >> (i * 4)) % 21);
      final py = top + 11.0 + i * 6.5;
      canvas.drawCircle(
        Offset(px, py),
        1.8 + (i % 2) * 0.7,
        Paint()
          ..color =
              i.isEven ? const Color(0xFF3E2723) : const Color(0xFF8D6E63),
      );
    }
  }

  void _renderCrop(Canvas canvas, CropPlot crop) {
    const s = JungleWorld.tileSize;
    final cx = crop.tileX * s + s * 0.5;
    final bottomY = (crop.tileY + 1) * s;
    final sway = math.sin(_animTime * 2.8 + crop.tileX) * 1.8;
    final stemHeight = 7.0 + crop.growthProgress * 21.0;

    // 1. Fertilized soil nutrient shimmer or habitat thriving/struggling aura at the base.
    if (crop.isFertilized) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, bottomY - 1.5),
          width: 24.0,
          height: 5.0,
        ),
        Paint()..color = const Color(0x88FFD54F),
      );
    }
    if (crop.lastHabitatMultiplier >= 1.35) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, bottomY - 2.0),
          width: 26.0,
          height: 5.5,
        ),
        Paint()..color = const Color(0x6600E676),
      );
    } else if (crop.lastHabitatMultiplier <= 0.70) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, bottomY - 2.0),
          width: 20.0,
          height: 4.0,
        ),
        Paint()..color = const Color(0x66FF7043),
      );
    }

    // 2. Pollinated golden pollen sparkles floating around the plant.
    if (crop.isPollinated) {
      for (int i = 0; i < 4; i++) {
        final angle = _animTime * 3.5 + i * 1.6;
        final px = cx + math.cos(angle) * 9.5;
        final py = bottomY - stemHeight * 0.65 + math.sin(angle * 1.4) * 5.5;
        canvas.drawCircle(
          Offset(px, py),
          1.9,
          Paint()..color = const Color(0xFFFFEA00),
        );
      }
    }

    final stemPaint =
        Paint()
          ..color = const Color(0xFF43A047)
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round;

    switch (crop.seedType) {
      case ItemType.berrySeeds:
        // Curved woody shrub stem + layered foliage + 5-petal blossoms or 3D glossy berries.
        canvas.drawLine(
          Offset(cx, bottomY),
          Offset(cx + sway * 0.5, bottomY - stemHeight),
          stemPaint,
        );
        if (crop.stage >= 1) {
          final crownCenter = Offset(
            cx + sway * 0.35,
            bottomY - stemHeight * 0.65,
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: crownCenter,
              width: 16.0 + crop.growthProgress * 7.0,
              height: 11.0 + crop.growthProgress * 5.0,
            ),
            Paint()..color = const Color(0xFF1B5E20),
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: crownCenter.translate(-2, -1.5),
              width: 11.0 + crop.growthProgress * 5.0,
              height: 7.5 + crop.growthProgress * 3.5,
            ),
            Paint()..color = const Color(0xFF388E3C),
          );
        }
        if (crop.stage == 2) {
          for (final (ox, oy) in const [
            (-4.5, 0.72),
            (4.5, 0.60),
            (0.0, 0.45),
          ]) {
            final fx = cx + ox + sway * 0.3;
            final fy = bottomY - stemHeight * oy;
            canvas.drawCircle(
              Offset(fx, fy),
              2.8,
              Paint()..color = Colors.white,
            );
            canvas.drawCircle(
              Offset(fx, fy),
              1.1,
              Paint()..color = const Color(0xFFFFD54F),
            );
          }
        } else if (crop.isMature) {
          for (final (ox, oy) in const [
            (-5.0, 0.75),
            (4.5, 0.66),
            (-0.5, 0.48),
            (3.5, 0.85),
          ]) {
            final bx = cx + ox + sway * 0.35;
            final by = bottomY - stemHeight * oy;
            canvas.drawCircle(
              Offset(bx, by),
              3.5,
              Paint()..color = const Color(0xFFB71C1C),
            );
            canvas.drawCircle(
              Offset(bx - 0.4, by - 0.4),
              2.6,
              Paint()..color = const Color(0xFFFF1744),
            );
            canvas.drawCircle(
              Offset(bx - 1.1, by - 1.1),
              0.9,
              Paint()..color = Colors.white,
            );
          }
        }

      case ItemType.bananaSeeds:
        // Ringed banana pseudo-stem + broad arching palm fronds + hanging banana hands.
        final topX = cx + sway * 0.4;
        final topY = bottomY - stemHeight;
        canvas.drawLine(
          Offset(cx, bottomY),
          Offset(topX, topY),
          Paint()
            ..color = const Color(0xFF558B2F)
            ..strokeWidth = 4.8
            ..strokeCap = StrokeCap.round,
        );
        if (crop.stage >= 1) {
          for (final dirFrond in const [-1.0, 1.0, -0.55, 0.55]) {
            final frondPath =
                Path()
                  ..moveTo(topX, topY + 2)
                  ..quadraticBezierTo(
                    topX + dirFrond * 9.0,
                    topY - 5.0,
                    topX + dirFrond * 15.0,
                    topY + 4.0,
                  );
            canvas.drawPath(
              frondPath,
              Paint()
                ..color =
                    dirFrond.abs() > 0.8
                        ? const Color(0xFF7CB342)
                        : const Color(0xFF9CCC65)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.2
                ..strokeCap = StrokeCap.round,
            );
          }
        }
        if (crop.isMature) {
          for (final ox in const [-4.0, -1.0, 2.5, 5.0]) {
            final bx = topX + ox;
            final by = bottomY - stemHeight * 0.65;
            canvas.drawOval(
              Rect.fromCenter(center: Offset(bx, by), width: 4.5, height: 8.5),
              Paint()..color = const Color(0xFFFBC02D),
            );
            canvas.drawOval(
              Rect.fromCenter(
                center: Offset(bx - 0.5, by - 0.5),
                width: 2.8,
                height: 6.5,
              ),
              Paint()..color = const Color(0xFFFFF176),
            );
          }
        }

      case ItemType.mangoSeeds:
        final topX = cx + sway * 0.4;
        final topY = bottomY - stemHeight;
        canvas.drawLine(
          Offset(cx, bottomY),
          Offset(topX, topY),
          Paint()
            ..color = const Color(0xFF5D4037)
            ..strokeWidth = 3.8
            ..strokeCap = StrokeCap.round,
        );
        if (crop.stage >= 1) {
          final r = 7.5 + crop.growthProgress * 4.5;
          canvas.drawCircle(
            Offset(topX, topY),
            r,
            Paint()..color = const Color(0xFF1B5E20),
          );
          canvas.drawCircle(
            Offset(topX - 2, topY - 2),
            r * 0.72,
            Paint()..color = const Color(0xFF43A047),
          );
        }
        if (crop.isMature) {
          for (final (ox, oy) in const [(-4.0, 2.0), (4.2, 3.0)]) {
            final mx = topX + ox;
            final my = topY + oy;
            final mRect = Rect.fromCenter(
              center: Offset(mx, my),
              width: 7.0,
              height: 8.8,
            );
            canvas.drawOval(
              mRect,
              Paint()
                ..shader = Gradient.linear(mRect.topLeft, mRect.bottomRight, [
                  const Color(0xFFFF5252),
                  const Color(0xFFFFCA28),
                ]),
            );
            canvas.drawCircle(
              Offset(mx - 1.2, my - 1.8),
              1.1,
              Paint()..color = Colors.white70,
            );
          }
        }

      case ItemType.healingHerbSeeds:
        // Aromatic rosette with pulsing emerald ward aura & rising scent motes.
        if (crop.stage >= 1) {
          canvas.drawCircle(
            Offset(cx, bottomY - 10),
            13.0 + math.sin(_animTime * 4.0) * 2.2,
            Paint()
              ..shader = Gradient.radial(Offset(cx, bottomY - 10), 15.0, [
                const Color(0x4400E676),
                const Color(0x0000E676),
              ]),
          );
        }
        for (final angle in const [-0.62, -0.32, 0.0, 0.32, 0.62]) {
          final bx = cx + math.sin(angle + sway * 0.04) * stemHeight * 0.75;
          final by = bottomY - math.cos(angle) * stemHeight * 0.88;
          canvas.drawLine(
            Offset(cx, bottomY),
            Offset(bx, by),
            Paint()
              ..color =
                  angle.abs() < 0.2
                      ? const Color(0xFF69F0AE)
                      : const Color(0xFF00C853)
              ..strokeWidth = 3.2
              ..strokeCap = StrokeCap.round,
          );
        }
        if (crop.isMature) {
          canvas.drawCircle(
            Offset(cx, bottomY - stemHeight * 0.92),
            4.5,
            Paint()..color = const Color(0xFFB9F6CA),
          );
          canvas.drawCircle(
            Offset(cx, bottomY - stemHeight * 0.92),
            2.0,
            Paint()..color = Colors.white,
          );
        }

      case ItemType.glowBulbSeeds:
        // Bioluminescent lotus stem, chalice petals, & multi-halo glowing orb!
        final bulbCenter = Offset(cx + sway * 0.5, bottomY - stemHeight);
        final glowRadius =
            11.0 + crop.growthProgress * 12.0 + math.sin(_animTime * 5.0) * 2.5;
        canvas.drawCircle(
          bulbCenter,
          glowRadius,
          Paint()
            ..shader = Gradient.radial(bulbCenter, glowRadius, [
              const Color(0x6600E5FF),
              const Color(0x0000E5FF),
            ]),
        );
        canvas.drawLine(
          Offset(cx, bottomY),
          bulbCenter,
          Paint()
            ..color = const Color(0xFF00897B)
            ..strokeWidth = 3.0,
        );
        // Lotus chalice leaves cradling the glowing bulb.
        canvas.drawOval(
          Rect.fromCenter(
            center: bulbCenter.translate(-3.5, 2.5),
            width: 6.5,
            height: 3.2,
          ),
          Paint()..color = const Color(0xFF26A69A),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: bulbCenter.translate(3.5, 2.5),
            width: 6.5,
            height: 3.2,
          ),
          Paint()..color = const Color(0xFF26A69A),
        );
        canvas.drawCircle(
          bulbCenter,
          4.0 + crop.growthProgress * 3.8,
          Paint()
            ..color =
                crop.isMature
                    ? const Color(0xFF76FF03)
                    : const Color(0xFF00E5FF),
        );
        canvas.drawCircle(
          bulbCenter.translate(-1.0, -1.0),
          1.8 + crop.growthProgress * 1.4,
          Paint()..color = Colors.white,
        );

      case ItemType.thornVineSeeds:
        // Intertwined defensive briar vines with razor-sharp crimson thorns.
        final briarPaint =
            Paint()
              ..color = const Color(0xFF33691E)
              ..strokeWidth = 3.0
              ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(cx - 6, bottomY),
          Offset(cx + 5 + sway, bottomY - stemHeight),
          briarPaint,
        );
        canvas.drawLine(
          Offset(cx + 6, bottomY),
          Offset(cx - 5 + sway, bottomY - stemHeight),
          briarPaint,
        );
        final thornPaint = Paint()..color = const Color(0xFFFF1744);
        for (double h = 5; h <= stemHeight; h += 5.5) {
          canvas.drawCircle(Offset(cx - 5, bottomY - h), 2.2, thornPaint);
          canvas.drawCircle(Offset(cx + 5, bottomY - h), 2.2, thornPaint);
        }

      case ItemType.pitcherPlantSeeds:
        // Carnivorous Nepenthes pitcher cup with ribbed peristome & overarching hood.
        canvas.drawLine(
          Offset(cx, bottomY),
          Offset(cx, bottomY - stemHeight * 0.6),
          stemPaint,
        );
        if (crop.stage >= 1) {
          final cupRect = Rect.fromCenter(
            center: Offset(cx + sway * 0.5, bottomY - stemHeight * 0.65),
            width: 11.0 + crop.growthProgress * 4.5,
            height: 13.0 + crop.growthProgress * 6.5,
          );
          canvas.drawOval(
            cupRect,
            Paint()
              ..shader = Gradient.linear(
                cupRect.topCenter,
                cupRect.bottomCenter,
                [const Color(0xFFAB47BC), const Color(0xFF4A148C)],
              ),
          );
          // Ribbed lime-green nectar peristome collar.
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(cupRect.center.dx, cupRect.top + 2),
              width: cupRect.width + 2.5,
              height: 4.5,
            ),
            Paint()..color = const Color(0xFFC6FF00),
          );
          // Pitcher lid/hood.
          canvas.drawArc(
            Rect.fromCenter(
              center: Offset(cupRect.center.dx + 2, cupRect.top - 3.5),
              width: 11,
              height: 6.5,
            ),
            math.pi,
            math.pi,
            true,
            Paint()..color = const Color(0xFFCE93D8),
          );
        }

      case ItemType.mahoganySapling:
        final topY = bottomY - stemHeight;
        canvas.drawLine(
          Offset(cx, bottomY),
          Offset(cx, topY),
          Paint()
            ..color = const Color(0xFF5D4037)
            ..strokeWidth = 4.2
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(
          Offset(cx, topY),
          6.5 + crop.growthProgress * 6.5,
          Paint()..color = const Color(0xFF1B5E20),
        );
        canvas.drawCircle(
          Offset(cx - 2, topY - 2),
          4.0 + crop.growthProgress * 4.0,
          Paint()..color = const Color(0xFF43A047),
        );

      default:
        canvas.drawLine(
          Offset(cx, bottomY),
          Offset(cx, bottomY - stemHeight),
          stemPaint,
        );
    }
  }

  void _renderVillager(Canvas canvas, NativeVillager v) {
    final bob = math.sin(_animTime * 3.2 + v.x) * 1.2;
    // Soft ground contact shadow.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(v.x, v.y), width: 20, height: 5),
      Paint()..color = const Color(0x44000000),
    );
    final legPaint = Paint()..color = const Color(0xFF8D6E63);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(v.x - 5, v.y - 9, 4, 9),
        const Radius.circular(1.5),
      ),
      legPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(v.x + 1, v.y - 9, 4, 9),
        const Radius.circular(1.5),
      ),
      legPaint,
    );

    // Carved wooden ceremonial staff with glowing amber crystal.
    canvas.drawLine(
      Offset(v.x + 11, v.y),
      Offset(v.x + 11, v.y - 34 + bob),
      Paint()
        ..color = const Color(0xFF5D4037)
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(v.x + 11, v.y - 36 + bob),
      4.5,
      Paint()..color = const Color(0xFFFFCA28),
    );
    canvas.drawCircle(
      Offset(v.x + 10.2, v.y - 36.8 + bob),
      1.6,
      Paint()..color = Colors.white,
    );

    // Woven emerald tunic with golden geometric sash.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(v.x - 8, v.y - 25 + bob, 16, 17),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF00897B),
    );
    canvas.drawRect(
      Rect.fromLTWH(v.x - 8, v.y - 14 + bob, 16, 3.2),
      Paint()..color = const Color(0xFFFFB300),
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(v.x, v.y - 24 + bob),
        width: 10,
        height: 6,
      ),
      0,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFFFFEA00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // Head, warm facial features, and vibrant macaw-feather headdress.
    canvas.drawCircle(
      Offset(v.x, v.y - 31 + bob),
      7.4,
      Paint()..color = const Color(0xFFD7CCC8),
    );
    canvas.drawCircle(
      Offset(v.x - 2.5, v.y - 32 + bob),
      1.3,
      Paint()..color = Colors.black87,
    );
    canvas.drawCircle(
      Offset(v.x + 2.5, v.y - 32 + bob),
      1.3,
      Paint()..color = Colors.black87,
    );

    for (final (angle, color) in const [
      (-0.52, Color(0xFFE53935)),
      (-0.25, Color(0xFFFFCA28)),
      (0.0, Color(0xFF00E676)),
      (0.25, Color(0xFF29B6F6)),
      (0.52, Color(0xFFE53935)),
    ]) {
      final fx = v.x + math.sin(angle) * 12;
      final fy = v.y - 37 + bob - math.cos(angle) * 8;
      canvas.drawLine(
        Offset(v.x + math.sin(angle) * 4, v.y - 36 + bob),
        Offset(fx, fy),
        Paint()
          ..color = color
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round,
      );
    }

    final tp = TextPainter(
      text: TextSpan(
        text: v.name,
        style: const TextStyle(
          color: Color(0xFFFFF59D),
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(v.x - tp.width * 0.5, v.y - 55 + bob));
  }

  void _renderAnimal(Canvas canvas, JungleAnimal a) {
    final flash = a.hurtFlashTimer > 0;
    final dir = a.facingRight ? 1.0 : -1.0;

    // Ground contact shadow for land wildlife.
    if (!a.type.flying && !a.type.aquatic) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(a.x, a.y), width: 22, height: 5),
        Paint()..color = const Color(0x40000000),
      );
    }

    switch (a.type) {
      case AnimalType.beeSwarm:
        // Pulsing acoustic buzz ripple around the swarm.
        final buzzPulse = 10.0 + ((_animTime * 22.0) % 10.0);
        canvas.drawCircle(
          Offset(a.x, a.y - 10.0),
          buzzPulse,
          Paint()
            ..color =
                a.isAngry ? const Color(0x44FF5252) : const Color(0x33FFD54F)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3,
        );
        for (int i = 0; i < 3; i++) {
          final phase = _animTime * 16.0 + i * 2.1;
          final bx = a.x + math.cos(phase * 0.7) * 9.0 * (i == 0 ? 0.3 : 1.0);
          final by =
              a.y - 10.0 + math.sin(phase * 1.1) * 6.0 * (i == 0 ? 0.3 : 1.0);

          if (a.isAngry) {
            canvas.drawCircle(
              Offset(bx, by),
              7.0,
              Paint()..color = const Color(0x44FF1744),
            );
          }

          final wingFlutter = math.sin(_animTime * 48.0 + i) * 3.2;
          final wingPaint = Paint()..color = const Color(0xDDFFFFFF);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(bx - 1.5, by - 4.2 + wingFlutter * 0.4),
              width: 6.0,
              height: 3.8,
            ),
            wingPaint,
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(bx + 1.5, by - 4.2 - wingFlutter * 0.4),
              width: 6.0,
              height: 3.8,
            ),
            wingPaint,
          );

          canvas.drawOval(
            Rect.fromCenter(center: Offset(bx, by), width: 9.5, height: 6.4),
            Paint()..color = flash ? Colors.redAccent : const Color(0xFFFFD600),
          );
          final stripePaint =
              Paint()
                ..color = const Color(0xFF212121)
                ..strokeWidth = 1.5;
          canvas.drawLine(
            Offset(bx - 1.6, by - 2.6),
            Offset(bx - 1.6, by + 2.6),
            stripePaint,
          );
          canvas.drawLine(
            Offset(bx + 1.6, by - 2.6),
            Offset(bx + 1.6, by + 2.6),
            stripePaint,
          );
        }

      case AnimalType.capuchinMonkey:
        // Agile Capuchin Monkey with curled prehensile tail, tufted ears,
        // expressive cream face, and red bandana when befriended!
        final furColor = flash ? Colors.redAccent : const Color(0xFF4E342E);
        final creamColor = const Color(0xFFFFECB3);
        final hop = math.sin(_animTime * 11.0 + a.x * 0.1).abs() * 2.5;

        final tailPath =
            Path()
              ..moveTo(a.x - dir * 6, a.y - 10 - hop)
              ..quadraticBezierTo(
                a.x - dir * 17,
                a.y - 23 - hop,
                a.x - dir * 12,
                a.y - 27 - hop,
              );
        canvas.drawPath(
          tailPath,
          Paint()
            ..color = furColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8
            ..strokeCap = StrokeCap.round,
        );

        // Limbs.
        final limbPaint =
            Paint()
              ..color = furColor
              ..strokeWidth = 3.0
              ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(a.x - 3, a.y - 8 - hop),
          Offset(a.x - 4.5, a.y),
          limbPaint,
        );
        canvas.drawLine(
          Offset(a.x + 3, a.y - 8 - hop),
          Offset(a.x + 4.5, a.y),
          limbPaint,
        );

        // Shaded torso & cream belly.
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(a.x, a.y - 12.5 - hop),
            width: 13,
            height: 14,
          ),
          Paint()..color = furColor,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(a.x + dir * 2, a.y - 12.5 - hop),
            width: 7.5,
            height: 9.5,
          ),
          Paint()..color = creamColor,
        );

        if (a.isTamed) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(a.x - 5.5, a.y - 18.5 - hop, 11, 3.0),
              const Radius.circular(1.5),
            ),
            Paint()..color = const Color(0xFFE53935),
          );
        }

        // Head, round ear, cream facial mask, & glossy eye.
        canvas.drawCircle(
          Offset(a.x - dir * 2.5, a.y - 21.5 - hop),
          2.4,
          Paint()..color = creamColor,
        );
        canvas.drawCircle(
          Offset(a.x + dir * 2, a.y - 21.5 - hop),
          6.2,
          Paint()..color = furColor,
        );
        canvas.drawCircle(
          Offset(a.x + dir * 3.6, a.y - 21.0 - hop),
          4.5,
          Paint()..color = creamColor,
        );
        canvas.drawCircle(
          Offset(a.x + dir * 4.8, a.y - 22.0 - hop),
          1.3,
          Paint()..color = Colors.black87,
        );
        canvas.drawCircle(
          Offset(a.x + dir * 4.5, a.y - 22.4 - hop),
          0.5,
          Paint()..color = Colors.white,
        );

      case AnimalType.toucan:
        // High-def Rainbow Toucan with glossy plumage, crimson-bordered golden
        // bib, cyan eye ring, and gradient rainbow bill!
        final flap = math.sin(_animTime * 20.0 + a.x * 0.1) * 5.5;
        final bodyY = a.y - 8.0;
        // Tail feathers.
        canvas.drawLine(
          Offset(a.x - dir * 6, bodyY + 1),
          Offset(a.x - dir * 14, bodyY + 4),
          Paint()
            ..color = const Color(0xFF101820)
            ..strokeWidth = 3.6
            ..strokeCap = StrokeCap.round,
        );
        // Glossy black body.
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(a.x, bodyY),
            width: 16.0,
            height: 10.5,
          ),
          Paint()..color = const Color(0xFF1A1A1A),
        );
        // Golden throat patch with crimson lower border.
        canvas.drawCircle(
          Offset(a.x + dir * 4.2, bodyY - 1.2),
          4.5,
          Paint()..color = const Color(0xFFFFEE58),
        );
        // Flapping wing with slate-blue sheen.
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(a.x - dir * 1, bodyY - 2 + flap * 0.5),
            width: 10.0,
            height: 6.4,
          ),
          Paint()..color = const Color(0xFF37474F),
        );
        // Multi-color gradient rainbow beak!
        final beakRect = Rect.fromLTWH(a.x + dir * 5, bodyY - 6, dir * 13, 7);
        final beakPath =
            Path()
              ..moveTo(a.x + dir * 6, bodyY - 5.5)
              ..quadraticBezierTo(
                a.x + dir * 17,
                bodyY - 5.5,
                a.x + dir * 18,
                bodyY + 0.5,
              )
              ..lineTo(a.x + dir * 6, bodyY + 1.2)
              ..close();
        canvas.drawPath(
          beakPath,
          Paint()
            ..shader = Gradient.linear(
              beakRect.topLeft,
              beakRect.bottomRight,
              [
                const Color(0xFFC6FF00),
                const Color(0xFFFF9100),
                const Color(0xFFD50000),
              ],
              [0.0, 0.65, 1.0],
            ),
        );
        if (a.carriedSeed != null) {
          canvas.drawCircle(
            Offset(a.x + dir * 14.5, bodyY + 1.8),
            3.0,
            Paint()..color = const Color(0xFFE91E63),
          );
        }
        canvas.drawCircle(
          Offset(a.x + dir * 4.6, bodyY - 3.2),
          1.8,
          Paint()..color = const Color(0xFF00E5FF),
        );
        canvas.drawCircle(
          Offset(a.x + dir * 4.6, bodyY - 3.2),
          0.9,
          Paint()..color = Colors.black,
        );

      case AnimalType.jaguar:
        // Muscular Shadow Jaguar with golden coat, rosette spots, glowing eyes,
        // and open roaring fangs when lunging!
        final isRoaring =
            a.badgeTimer > 0 && (a.activityBadge?.contains('ROAR') ?? false);
        final bodyColor = flash ? Colors.redAccent : const Color(0xFFFFB300);
        final legCycle = math.sin(_animTime * 15.0) * 5.0;
        final legPaint =
            Paint()
              ..color = const Color(0xFFE65100)
              ..strokeWidth = 3.8
              ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          Offset(a.x - 10, a.y - 9),
          Offset(a.x - 12 + legCycle, a.y),
          legPaint,
        );
        canvas.drawLine(
          Offset(a.x - 5, a.y - 9),
          Offset(a.x - 5 - legCycle, a.y),
          legPaint,
        );
        canvas.drawLine(
          Offset(a.x + 7, a.y - 9),
          Offset(a.x + 9 + legCycle, a.y),
          legPaint,
        );
        canvas.drawLine(
          Offset(a.x + 11, a.y - 9),
          Offset(a.x + 11 - legCycle, a.y),
          legPaint,
        );

        final tailPath =
            Path()
              ..moveTo(a.x - dir * 14, a.y - 14)
              ..quadraticBezierTo(
                a.x - dir * 23,
                a.y - 23 + math.sin(_animTime * 8.0) * 3.0,
                a.x - dir * 27,
                a.y - 16,
              );
        canvas.drawPath(
          tailPath,
          Paint()
            ..color = bodyColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2
            ..strokeCap = StrokeCap.round,
        );

        // Muscular shaded torso + cream underbelly highlight.
        final torsoRect = Rect.fromLTWH(a.x - 15, a.y - 19, 30, 13);
        canvas.drawRRect(
          RRect.fromRectAndRadius(torsoRect, const Radius.circular(6.5)),
          Paint()
            ..shader = Gradient.linear(
              torsoRect.topCenter,
              torsoRect.bottomCenter,
              [bodyColor, const Color(0xFFF57C00)],
            ),
        );
        // Jaguar rosettes (dark outer ring with warm tawny center).
        for (final (rx, ry) in const [
          (-9.0, -14.0),
          (-3.0, -12.0),
          (3.5, -14.5),
          (8.0, -11.5),
        ]) {
          canvas.drawCircle(
            Offset(a.x + rx, a.y + ry),
            2.6,
            Paint()..color = const Color(0xFF3E2723),
          );
          canvas.drawCircle(
            Offset(a.x + rx, a.y + ry),
            1.1,
            Paint()..color = const Color(0xFFE65100),
          );
        }

        // Head, rounded ears, glowing predator eye, & roaring fangs!
        final headX = a.x + dir * 14.0;
        final headY = a.y - 16.5;
        canvas.drawCircle(
          Offset(headX - dir * 2.5, headY - 6.0),
          2.8,
          Paint()..color = const Color(0xFF3E2723),
        );
        canvas.drawCircle(
          Offset(headX, headY),
          7.2,
          Paint()..color = bodyColor,
        );
        canvas.drawCircle(
          Offset(headX + dir * 2.2, headY - 1.2),
          1.7,
          Paint()..color = const Color(0xFF76FF03),
        );
        if (isRoaring) {
          // Open roaring maw with white fangs & shockwave rings!
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(headX + dir * 4.8, headY + 2.5),
              width: 6.5,
              height: 4.8,
            ),
            Paint()..color = const Color(0xFFB71C1C),
          );
          canvas.drawCircle(
            Offset(headX + dir * 6.0, headY + 1.0),
            1.1,
            Paint()..color = Colors.white,
          );
          for (int ring = 1; ring <= 2; ring++) {
            final r = 10.0 + ((_animTime * 28.0 + ring * 7.0) % 18.0);
            canvas.drawCircle(
              Offset(headX + dir * 3.0, headY),
              r,
              Paint()
                ..color = const Color(0x88FF6E40)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.0,
            );
          }
        }

      case AnimalType.snake:
        // Emerald Viper with shaded dorsal scales, golden slit eye & forked tongue.
        final snakeColor = flash ? Colors.redAccent : const Color(0xFF00E676);
        for (int seg = 5; seg >= 0; seg--) {
          final sx = a.x - dir * (seg * 4.0) + dir * 6.0;
          final sy = a.y - 5.0 + math.sin(_animTime * 12.0 + seg * 0.9) * 2.2;
          canvas.drawCircle(
            Offset(sx, sy),
            4.8 - seg * 0.45,
            Paint()..color = seg.isEven ? snakeColor : const Color(0xFF00B248),
          );
        }
        final hx = a.x + dir * 9.5;
        final hy = a.y - 9.0;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(hx, hy), width: 10.5, height: 7.5),
          Paint()..color = snakeColor,
        );
        canvas.drawCircle(
          Offset(hx + dir * 2.0, hy - 1.2),
          1.4,
          Paint()..color = const Color(0xFFFFEA00),
        );
        if ((_animTime * 7.0).floor().isEven) {
          canvas.drawLine(
            Offset(hx + dir * 5, hy),
            Offset(hx + dir * 10, hy - 1),
            Paint()
              ..color = const Color(0xFFFF1744)
              ..strokeWidth = 1.3,
          );
        }

      case AnimalType.piranha:
        // Red-Bellied Piranha with tail fin, metallic scales, & sharp teeth.
        final fishColor = flash ? Colors.white : const Color(0xFF546E7A);
        final tailWag = math.sin(_animTime * 22.0) * 2.5;
        final tailPath =
            Path()
              ..moveTo(a.x - dir * 8, a.y - 5)
              ..lineTo(a.x - dir * 14, a.y - 10 + tailWag)
              ..lineTo(a.x - dir * 14, a.y + tailWag)
              ..close();
        canvas.drawPath(tailPath, Paint()..color = const Color(0xFF37474F));
        canvas.drawOval(
          Rect.fromLTWH(a.x - 10, a.y - 11, 20, 12),
          Paint()..color = fishColor,
        );
        canvas.drawArc(
          Rect.fromLTWH(a.x - 9, a.y - 9, 18, 9),
          0,
          math.pi,
          true,
          Paint()..color = const Color(0xFFE53935),
        );
        canvas.drawCircle(
          Offset(a.x + dir * 5, a.y - 6.5),
          1.8,
          Paint()..color = Colors.yellowAccent,
        );
        canvas.drawCircle(
          Offset(a.x + dir * 5.4, a.y - 6.5),
          0.8,
          Paint()..color = Colors.black,
        );
    }

    if (a.health < a.type.maxHealth) {
      final pct = (a.health / a.type.maxHealth).clamp(0.0, 1.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(a.x - 14, a.y - 29, 28, 4.5),
          const Radius.circular(2),
        ),
        Paint()..color = Colors.black54,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(a.x - 14, a.y - 29, 28 * pct, 4.5),
          const Radius.circular(2),
        ),
        Paint()..color = Colors.redAccent,
      );
    }

    final badgeText = a.activityBadge ?? (a.isTamed ? '💚 Helper' : null);
    if (badgeText != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: badgeText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final badgeRect = Rect.fromCenter(
        center: Offset(a.x, a.y - 37),
        width: tp.width + 8,
        height: tp.height + 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(badgeRect, const Radius.circular(6)),
        Paint()..color = const Color(0xCC102018),
      );
      tp.paint(
        canvas,
        Offset(a.x - tp.width * 0.5, a.y - 37 - tp.height * 0.5),
      );
    }
  }

  void _renderFishingLine(Canvas canvas, FishingState fish) {
    final rodTip = Offset(
      worldState.playerX + (worldState.playerFacingRight ? 18 : -18),
      worldState.playerY - 22,
    );
    final bobberOffset = Offset(
      fish.bobberX,
      fish.bobberY + (fish.hasBite ? math.sin(_animTime * 28.0) * 4.5 : 0.0),
    );
    final linePath =
        Path()
          ..moveTo(rodTip.dx, rodTip.dy)
          ..quadraticBezierTo(
            (rodTip.dx + bobberOffset.dx) * 0.5,
            math.max(rodTip.dy, bobberOffset.dy) + 10.0,
            bobberOffset.dx,
            bobberOffset.dy,
          );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    // Water ripple rings around bobber.
    canvas.drawOval(
      Rect.fromCenter(
        center: bobberOffset.translate(0, 2),
        width: fish.hasBite ? 18.0 : 11.0,
        height: 4.5,
      ),
      Paint()
        ..color = const Color(0x88B3E5FC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      bobberOffset,
      fish.hasBite ? 6.0 : 4.4,
      Paint()
        ..color =
            fish.hasBite ? const Color(0xFFFFEB3B) : const Color(0xFFE53935),
    );
  }

  void _renderExplorer(Canvas canvas) {
    final px = worldState.playerX;
    final py = worldState.playerY;
    final dir = worldState.playerFacingRight ? 1.0 : -1.0;
    final hurt = worldState.playerHurtFlashTimer > 0;
    final moving = worldState.playerVx.abs() > 5.0;
    final stride = moving ? math.sin(_animTime * 15.0) * 5.0 : 0.0;
    final breath = math.sin(_animTime * 3.5) * 0.7;

    // Ground contact shadow beneath explorer.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(px, py), width: 22, height: 5.5),
      Paint()..color = const Color(0x44000000),
    );

    // 1. Back Expedition Backpack, Brass Buckles & Rolled Canvas Bedroll.
    final packX = px - dir * 9.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(packX - 5.0, py - 25.5 + breath, 10, 14),
        const Radius.circular(3.5),
      ),
      Paint()..color = const Color(0xFF4E342E),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(packX - 4.0, py - 22.0 + breath, 8, 5),
        const Radius.circular(2.0),
      ),
      Paint()..color = const Color(0xFF6D4C41),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(packX, py - 27.0 + breath),
        width: 10,
        height: 5.0,
      ),
      Paint()..color = const Color(0xFF2E7D32),
    );

    // 2. Back Leg & Laced Jungle Boot.
    _drawExplorerLeg(canvas, px - 2.5 - stride * 0.7, py, isFront: false);

    // 3. Back Arm.
    canvas.drawLine(
      Offset(px - dir * 3, py - 22 + breath),
      Offset(px - dir * 5 - stride * 0.6, py - 13 + breath),
      Paint()
        ..color = const Color(0xFFD7A98C)
        ..strokeWidth = 3.8
        ..strokeCap = StrokeCap.round,
    );

    // 4. Front Leg & Laced Jungle Boot.
    _drawExplorerLeg(canvas, px + 2.5 + stride * 0.7, py, isFront: true);

    // 5. Shaded Safari Tunic / Woven Geometric Poncho + Utility Belt.
    final torsoRect = Rect.fromLTWH(px - 8.0, py - 25.5 + breath, 16, 15.5);
    final torsoTop =
        hurt
            ? Colors.redAccent
            : (worldState.hasWarmPoncho
                ? const Color(0xFFE64A19)
                : const Color(0xFFBCAAA4));
    final torsoBottom =
        hurt
            ? Colors.red
            : (worldState.hasWarmPoncho
                ? const Color(0xFFBF360C)
                : const Color(0xFF8D6E63));
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, const Radius.circular(4.5)),
      Paint()
        ..shader = Gradient.linear(
          torsoRect.topCenter,
          torsoRect.bottomCenter,
          [torsoTop, torsoBottom],
        ),
    );

    if (worldState.hasWarmPoncho && !hurt) {
      canvas.drawRect(
        Rect.fromLTWH(px - 8.0, py - 17.5 + breath, 16, 3.2),
        Paint()..color = const Color(0xFFFFCA28),
      );
    } else {
      canvas.drawRect(
        Rect.fromLTWH(px - 8.0, py - 13.5 + breath, 16, 3.2),
        Paint()..color = const Color(0xFF3E2723),
      );
      canvas.drawRect(
        Rect.fromLTWH(px - 1.5 + dir * 2, py - 13.5 + breath, 3.4, 3.2),
        Paint()..color = const Color(0xFFFFD54F),
      );
    }

    // Explorer Red Neck Bandana / Scarf.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(px - 6.5, py - 26.5 + breath, 13, 3.4),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFC62828),
    );

    // 6. Detailed Head, Expressive Eyes, & Shaded Pith Helmet.
    final headCenter = Offset(px, py - 31.5 + breath);
    canvas.drawCircle(
      headCenter,
      7.0,
      Paint()..color = const Color(0xFFFFCCBC),
    );
    canvas.drawCircle(
      Offset(px + dir * 3.0, py - 30.0 + breath),
      1.8,
      Paint()..color = const Color(0xFFFFAB91),
    );

    final isBlinking = (_animTime % 3.6) > 3.45;
    final eyeX = px + dir * 3.2;
    final eyeY = py - 32.0 + breath;
    if (isBlinking) {
      canvas.drawLine(
        Offset(eyeX - 1.6, eyeY),
        Offset(eyeX + 1.6, eyeY),
        Paint()
          ..color = const Color(0xFF3E2723)
          ..strokeWidth = 1.4,
      );
    } else {
      canvas.drawCircle(Offset(eyeX, eyeY), 2.0, Paint()..color = Colors.white);
      canvas.drawCircle(
        Offset(eyeX + dir * 0.5, eyeY),
        1.15,
        Paint()..color = const Color(0xFF212121),
      );
      canvas.drawCircle(
        Offset(eyeX + dir * 0.2, eyeY - 0.4),
        0.45,
        Paint()..color = Colors.white,
      );
    }

    // Sunlit Pith Helmet with leather band.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(px, py - 34.5 + breath),
        width: 17.5,
        height: 12.0,
      ),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFFFDD835),
    );
    canvas.drawRect(
      Rect.fromLTWH(px - 8.0, py - 36.2 + breath, 16, 2.4),
      Paint()..color = const Color(0xFF5D4037),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(px + dir * 1.0, py - 34.5 + breath),
        width: 22.0,
        height: 5.0,
      ),
      Paint()..color = const Color(0xFFF9A825),
    );

    // 7. Front Arm & Equipped Tool / Weapon in Hand!
    final swingAngle =
        worldState.swingAnimationTimer > 0
            ? math.sin(worldState.swingAnimationTimer * math.pi * 4.0) *
                1.1 *
                dir
            : (moving ? -stride * 0.06 : 0.0);
    final shoulder = Offset(px + dir * 2.5, py - 21.5 + breath);
    final handOffset = Offset(
      shoulder.dx +
          dir * 7.5 * math.cos(swingAngle) -
          3.0 * math.sin(swingAngle),
      shoulder.dy +
          4.5 * math.cos(swingAngle) +
          dir * 7.5 * math.sin(swingAngle),
    );
    canvas.drawLine(
      shoulder,
      handOffset,
      Paint()
        ..color = const Color(0xFFFFCCBC)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round,
    );
    _renderHeldEquipment(canvas, handOffset, dir, swingAngle);
  }

  void _drawExplorerLeg(
    Canvas canvas,
    double footX,
    double footY, {
    required bool isFront,
  }) {
    final pantsColor =
        isFront ? const Color(0xFF5D4037) : const Color(0xFF4E342E);
    canvas.drawLine(
      Offset(worldState.playerX, footY - 11),
      Offset(footX, footY - 3),
      Paint()
        ..color = pantsColor
        ..strokeWidth = 4.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(footX - 3.2, footY - 4.2, 7.0, 4.4),
        const Radius.circular(1.8),
      ),
      Paint()..color = const Color(0xFF271914),
    );
  }

  void _renderHeldEquipment(
    Canvas canvas,
    Offset hand,
    double dir,
    double swingAngle,
  ) {
    final item = worldState.equippedItem;
    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.rotate(swingAngle);

    switch (item) {
      case ItemType.woodPickaxe:
      case ItemType.stonePickaxe:
        canvas.drawLine(
          Offset.zero,
          Offset(dir * 11, -11),
          Paint()
            ..color = const Color(0xFF6D4C41)
            ..strokeWidth = 2.8
            ..strokeCap = StrokeCap.round,
        );
        final headColor =
            item == ItemType.stonePickaxe
                ? const Color(0xFFCFD8DC)
                : const Color(0xFF8D6E63);
        canvas.drawLine(
          Offset(dir * 6, -14),
          Offset(dir * 15, -7),
          Paint()
            ..color = headColor
            ..strokeWidth = 3.6
            ..strokeCap = StrokeCap.round,
        );
      case ItemType.woodSpear:
        canvas.drawLine(
          Offset(-dir * 4, 3),
          Offset(dir * 17, -10),
          Paint()
            ..color = const Color(0xFF6D4C41)
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(
          Offset(dir * 18, -10.5),
          3.2,
          Paint()..color = const Color(0xFFECEFF1),
        );
      case ItemType.ironMachete:
        canvas.drawLine(
          Offset.zero,
          Offset(dir * 14, -9),
          Paint()
            ..color = const Color(0xFFECEFF1)
            ..strokeWidth = 3.8
            ..strokeCap = StrokeCap.round,
        );
      case ItemType.torchItem:
        canvas.drawLine(
          Offset.zero,
          Offset(dir * 6, -9),
          Paint()
            ..color = const Color(0xFF5D4037)
            ..strokeWidth = 2.8,
        );
        canvas.drawCircle(
          Offset(dir * 6, -11.5),
          4.5,
          Paint()..color = const Color(0xFFFFB300),
        );
        canvas.drawCircle(
          Offset(dir * 6, -11.5),
          2.0,
          Paint()..color = Colors.white,
        );
      case ItemType.fishingRod:
        canvas.drawLine(
          Offset.zero,
          Offset(dir * 16, -13),
          Paint()
            ..color = const Color(0xFF8D6E63)
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round,
        );
      case ItemType.waterBucket:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(dir * 2, -2, 7.5, 7.5),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFF0288D1),
        );
      default:
        canvas.drawCircle(
          Offset(dir * 4, -2),
          3.8,
          Paint()..color = const Color(0xFFFFCA28),
        );
    }

    canvas.restore();
  }

  void _renderAtmosphericParticles(
    Canvas canvas,
    double viewW,
    double viewH,
    Offset cam,
  ) {
    final isNight = worldState.isNight;
    // Floating golden sunlit pollen motes by day, glowing chartreuse fireflies at night!
    for (int i = 0; i < 24; i++) {
      final baseX = (i * 97.0 - cam.dx * 0.45) % viewW;
      final px =
          (baseX < 0 ? baseX + viewW : baseX) +
          math.sin(_animTime * 1.8 + i) * 14.0;
      final baseY = (i * 53.0 - cam.dy * 0.25) % (viewH * 0.85);
      final py =
          (baseY < 0 ? baseY + viewH * 0.85 : baseY) +
          math.cos(_animTime * 1.4 + i * 0.7) * 10.0;
      final pulse =
          0.4 + 0.6 * (0.5 + 0.5 * math.sin(_animTime * 3.6 + i * 1.3));

      if (isNight) {
        canvas.drawCircle(
          Offset(px, py),
          6.0 * pulse,
          Paint()..color = const Color(0x33C6FF00),
        );
        canvas.drawCircle(
          Offset(px, py),
          1.8,
          Paint()..color = const Color(0xddEEFF41),
        );
      } else {
        canvas.drawCircle(
          Offset(px, py),
          1.5 * pulse,
          Paint()..color = const Color(0x66FFF59D),
        );
      }
    }
  }

  void _renderRainOverlay(Canvas canvas, double viewW, double viewH) {
    final rainPaint =
        Paint()
          ..color = const Color(0x77B3E5FC)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
    final shift = (_animTime * 380.0) % 40.0;
    for (double x = -20; x < viewW + 20; x += 26) {
      for (double y = shift - 40; y < viewH; y += 38) {
        canvas.drawLine(Offset(x, y), Offset(x - 6, y + 15), rainPaint);
      }
    }
  }

  void _renderNightAndWarmthLighting(
    Canvas canvas,
    double viewW,
    double viewH,
    Offset cam,
  ) {
    if (!worldState.isNight) return;
    final playerScreen = Offset(
      worldState.playerX - cam.dx,
      worldState.playerY - 16.0 - cam.dy,
    );
    final shelter = worldState.evaluateShelterStatus(
      worldState.playerTileX,
      worldState.playerTileY,
    );
    final holdingTorch = worldState.equippedItem == ItemType.torchItem;
    final lightRadius =
        shelter.nearCampfire
            ? 210.0
            : ((shelter.nearTorch || holdingTorch) ? 165.0 : 115.0);

    final nightPaint =
        Paint()
          ..shader = Gradient.radial(playerScreen, lightRadius, [
            const Color(0x00000000),
            const Color(0xAA040814),
          ]);
    canvas.drawRect(Rect.fromLTWH(0, 0, viewW, viewH), nightPaint);

    // Bioluminescent Glow-Bulb crops radiate soft cyan-lime halos at night!
    for (final crop in worldState.crops.values) {
      if (crop.seedType == ItemType.glowBulbSeeds &&
          crop.growthProgress >= 0.33) {
        final gx = crop.tileX * JungleWorld.tileSize + 16.0 - cam.dx;
        final gy = crop.tileY * JungleWorld.tileSize + 16.0 - cam.dy;
        if (gx >= -80 && gx <= viewW + 80 && gy >= -80 && gy <= viewH + 80) {
          final radius = 46.0 + crop.growthProgress * 38.0;
          canvas.drawCircle(
            Offset(gx, gy),
            radius,
            Paint()
              ..shader = Gradient.radial(Offset(gx, gy), radius, [
                const Color(0x6600E5FF),
                const Color(0x0000E5FF),
              ]),
          );
        }
      }
    }
  }
}
