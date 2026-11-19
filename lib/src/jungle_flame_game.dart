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

    // 3. Render growing crops on tilled/specialized soil (generous padded bounds
    // for 5-tile-wide bushy spreaders and 6-tile-tall palms & climbers).
    for (final crop in worldState.crops.values) {
      if (crop.tileX >= startTx - 5 &&
          crop.tileX <= endTx + 5 &&
          crop.tileY >= startTy - 8 &&
          crop.tileY <= endTy + 8) {
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
      _renderRainOverlay(canvas, viewW, viewH, cam);
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
        // Branching woody shrub stems + layered foliage + realistic drupelet berry clusters.
        final twigPaint =
            Paint()
              ..color = const Color(0xFF4E342E)
              ..strokeWidth = 2.2
              ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(left + 16, top + s),
          Offset(left + 10, top + 14),
          twigPaint,
        );
        canvas.drawLine(
          Offset(left + 16, top + s),
          Offset(left + 22, top + 15),
          twigPaint,
        );
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
          (9.5, 14.5),
          (21.5, 16.0),
          (15.5, 22.0),
        ]) {
          _drawRealisticBerryCluster(
            canvas,
            Offset(left + bx, top + by),
            scale: 0.88,
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

      case BlockType.ancientObsidian:
        canvas.drawRect(
          rect,
          Paint()
            ..shader =
                Gradient.linear(Offset(left, top), Offset(left + s, top + s), [
                  const Color(0xFF211333),
                  const Color(0xFF12081F),
                  const Color(0xFF311B92),
                ]),
        );
        final pulse = 0.55 + 0.45 * math.sin(_animTime * 3.2 + h * 0.4);
        final runePaint =
            Paint()
              ..color = Color.fromARGB(
                (150 + 95 * pulse).round().clamp(0, 255),
                179,
                136,
                255,
              )
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6;
        canvas.drawRect(rect.deflate(2.5), runePaint);
        canvas.drawLine(
          Offset(left + 7, top + 8),
          Offset(left + s - 7, top + s - 8),
          runePaint,
        );
        canvas.drawCircle(
          Offset(left + s * 0.5, top + s * 0.5),
          3.2,
          Paint()..color = const Color(0xFFE040FB).withValues(alpha: pulse),
        );

      case BlockType.cloudStone:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(0.8), const Radius.circular(4)),
          Paint()
            ..shader = Gradient.linear(
              Offset(left, top),
              Offset(left, top + s),
              [const Color(0xFFF5FDFF), const Color(0xFFB2EBF2)],
            ),
        );
        canvas.drawRect(
          Rect.fromLTWH(left + 2, top + 2, s - 4, 4),
          Paint()..color = const Color(0xFFFFD54F),
        );
        canvas.drawLine(
          Offset(left + 4, top + s * 0.55),
          Offset(left + s - 4, top + s * 0.55),
          Paint()
            ..color = const Color(0xFF00ACC1)
            ..strokeWidth = 1.5,
        );

      case BlockType.totemPedestal:
        // Carved stone altar base.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left + 3, top + 14, s - 6, s - 14),
            const Radius.circular(3),
          ),
          Paint()..color = const Color(0xFF37474F),
        );
        canvas.drawRect(
          Rect.fromLTWH(left + 1, top + 12, s - 2, 5),
          Paint()..color = const Color(0xFFFFCA28),
        );
        final shard = worldState.totemShardForPedestalAt(tx, ty);
        final bob = math.sin(_animTime * 3.8 + tx) * 3.0;
        final orbCenter = Offset(left + s * 0.5, top + 3.0 + bob);
        final orbColor = switch (shard) {
          ItemType.skyTotemShard => const Color(0xFF40C4FF),
          ItemType.marshTotemShard => const Color(0xFF69F0AE),
          ItemType.abyssTotemShard => const Color(0xFFE040FB),
          _ => const Color(0xFFFFD54F),
        };
        canvas.drawCircle(
          orbCenter,
          12.0,
          Paint()
            ..shader = Gradient.radial(orbCenter, 12.0, [
              orbColor.withValues(alpha: 0.78),
              orbColor.withValues(alpha: 0.0),
            ]),
        );
        final diamond =
            Path()
              ..moveTo(orbCenter.dx, orbCenter.dy - 7.5)
              ..lineTo(orbCenter.dx + 6.0, orbCenter.dy)
              ..lineTo(orbCenter.dx, orbCenter.dy + 7.5)
              ..lineTo(orbCenter.dx - 6.0, orbCenter.dy)
              ..close();
        canvas.drawPath(diamond, Paint()..color = orbColor);
        canvas.drawPath(
          diamond,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
        // If this is the Marsh Totem Pedestal (surface level), render toxic green miasma mist around it!
        if (shard == ItemType.marshTotemShard) {
          for (int m = -3; m <= 3; m++) {
            final mx =
                left + s * 0.5 + m * 24.0 + math.sin(_animTime * 1.8 + m) * 8.0;
            final my = top + 8.0 + math.cos(_animTime * 2.2 + m * 1.4) * 6.0;
            canvas.drawCircle(
              Offset(mx, my),
              18.0,
              Paint()
                ..shader = Gradient.radial(Offset(mx, my), 18.0, [
                  const Color(0x5576FF03),
                  const Color(0x0076FF03),
                ]),
            );
          }
        }

      case BlockType.jungleShrine:
        final awakened = worldState.shrineAwakened;
        if (awakened) {
          // Golden-emerald sky beam shooting into the canopy!
          canvas.drawRect(
            Rect.fromLTWH(left + 4, top - 320, s - 8, 320 + s),
            Paint()
              ..shader = Gradient.linear(
                Offset(left + s * 0.5, top),
                Offset(left + s * 0.5, top - 320),
                [const Color(0x8800E676), const Color(0x00FFD54F)],
              ),
          );
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left + 2, top - 10, s - 4, s + 10),
            const Radius.circular(5),
          ),
          Paint()
            ..shader = Gradient.linear(
              Offset(left, top - 10),
              Offset(left, top + s),
              [const Color(0xFF455A64), const Color(0xFF263238)],
            ),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left + 4, top - 8, s - 8, s + 6),
            const Radius.circular(4),
          ),
          Paint()
            ..color =
                awakened ? const Color(0xFF00E676) : const Color(0xFFFFB300)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8,
        );
        // 3 Totem Shard sockets along the shrine obelisk.
        final sockets = [
          (
            ItemType.skyTotemShard,
            Offset(left + s * 0.5, top - 1),
            const Color(0xFF40C4FF),
          ),
          (
            ItemType.marshTotemShard,
            Offset(left + s * 0.32, top + 13),
            const Color(0xFF69F0AE),
          ),
          (
            ItemType.abyssTotemShard,
            Offset(left + s * 0.68, top + 13),
            const Color(0xFFE040FB),
          ),
        ];
        for (final (shardItem, pos, activeColor) in sockets) {
          final isLit = worldState.socketedTotemShards.contains(shardItem);
          canvas.drawCircle(
            pos,
            4.2,
            Paint()..color = isLit ? activeColor : const Color(0xFF1C262B),
          );
        }

      case BlockType.overgrownStalk:
        // Soft dappled organic canopy depth behind large multi-tile plants
        // (no boxy square borders so tall palms, bushes & climbers shine cleanly).
        canvas.drawCircle(
          Offset(left + s * 0.5, top + s * 0.5),
          13.5,
          Paint()
            ..shader = Gradient.radial(
              Offset(left + s * 0.5, top + s * 0.5),
              14.0,
              [const Color(0x361B5E20), const Color(0x001B5E20)],
            ),
        );
        for (final (lx, ly, ang) in const [
          (10.0, 12.0, -0.75),
          (22.0, 14.0, 0.75),
          (15.0, 22.0, -0.35),
        ]) {
          _drawVeinedLeaf(
            canvas,
            Offset(left + lx, top + ly),
            angle: ang,
            length: 7.2,
            leafColor: const Color(0x88388E3C),
            veinColor: const Color(0x88A5D6A7),
          );
        }

      case BlockType.thornyBriar:
        // Organic interlacing thorny briar canes (pass-through for explorer,
        // blocks predators) without boxy tile frames.
        canvas.drawCircle(
          Offset(left + s * 0.5, top + s * 0.5),
          14.5,
          Paint()
            ..shader = Gradient.radial(
              Offset(left + s * 0.5, top + s * 0.5),
              15.0,
              [const Color(0x55263218), const Color(0x00263218)],
            ),
        );
        final canePaint =
            Paint()
              ..color = const Color(0xCC33691E)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.8
              ..strokeCap = StrokeCap.round;
        final cane1 =
            Path()
              ..moveTo(left + 3, top + s - 4)
              ..quadraticBezierTo(
                left + s * 0.5,
                top + s * 0.35,
                left + s - 3,
                top + 4,
              );
        final cane2 =
            Path()
              ..moveTo(left + s - 3, top + s - 4)
              ..quadraticBezierTo(
                left + s * 0.5,
                top + s * 0.65,
                left + 3,
                top + 4,
              );
        canvas.drawPath(cane1, canePaint);
        canvas.drawPath(cane2, canePaint);
        for (final (txOff, tyOff, dir) in const [
          (9.0, 10.0, -1.0),
          (23.0, 10.0, 1.0),
          (16.0, 17.0, 1.0),
          (10.0, 24.0, -1.0),
          (22.0, 23.0, 1.0),
        ]) {
          _drawCurvedRoseThorn(canvas, Offset(left + txOff, top + tyOff), dir);
        }

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
    final sway = math.sin(_animTime * 2.4 + crop.tileX * 0.85) * 2.6;

    // Respect overhead ceilings and canopy obstacles so tall palms, trees,
    // and climbers stay organically framed beneath caves, roofs, and leaves.
    int openHeadroomTiles = crop.seedType.maxPlantHeightTiles;
    for (int dy = 1; dy < openHeadroomTiles; dy++) {
      final checkY = crop.tileY - dy;
      if (checkY < 1) {
        openHeadroomTiles = dy;
        break;
      }
      final checkBlock = worldState.getBlock(crop.tileX, checkY);
      final isOwnTile =
          crop.overgrownTiles.contains((crop.tileX, checkY)) ||
          crop.climbedVineTiles.contains((crop.tileX, checkY));
      if (checkBlock != BlockType.air && !isOwnTile) {
        openHeadroomTiles = dy;
        break;
      }
    }
    if (crop.seedType.plantGrowthHabit == PlantGrowthHabit.climber &&
        crop.climbedHeight > 0 &&
        crop.hasOvergrowth) {
      openHeadroomTiles = math.min<int>(openHeadroomTiles, crop.climbedHeight);
    }
    final ceilingMaxPx = openHeadroomTiles * s - 4.0;
    final effectiveScale = crop.effectiveGrowthScale; // 0.0..1.50
    final normalizedScale = (effectiveScale / 1.50).clamp(0.0, 1.0);
    final baseProgress = crop.establishedGrowthProgress;
    final lush = crop.lushGrowth;

    final targetMaxPx = switch (crop.seedType) {
      ItemType.bananaSeeds => 148.0 + lush * 46.0, // ~4.6 to 6.1 tiles tall
      ItemType.thornVineSeeds =>
        crop.climbAttachDirection != 0 || crop.climbedHeight >= 4
            ? 142.0 +
                lush *
                    50.0 // ~4.5 to 6.0 tiles climbing
            : 108.0 + lush * 42.0,
      ItemType.mangoSeeds => 126.0 + lush * 36.0, // ~4.0 to 5.1 tiles tall
      ItemType.pitcherPlantSeeds =>
        crop.climbAttachDirection != 0 || crop.climbedHeight >= 3
            ? 122.0 +
                lush *
                    42.0 // ~3.8 to 5.1 tiles climbing
            : 94.0 + lush * 34.0,
      ItemType.glowBulbSeeds =>
        crop.climbAttachDirection != 0 || crop.climbedHeight >= 3
            ? 106.0 +
                lush *
                    32.0 // ~3.3 to 4.3 tiles climbing
            : 84.0 + lush * 26.0,
      ItemType.mahoganySapling => 112.0,
      ItemType.berrySeeds => 68.0 + lush * 24.0, // ~2.1 to 2.9 tiles tall bushy
      ItemType.healingHerbSeeds => 66.0 + lush * 26.0,
      _ => 58.0,
    };
    final clampedMaxPx = math.min(targetMaxPx, ceilingMaxPx);
    final stemHeight =
        (9.0 + math.pow(baseProgress, 1.06) * (clampedMaxPx - 9.0))
            .clamp(9.0, math.max(9.0, ceilingMaxPx))
            .toDouble();
    final spreadScale =
        1.0 +
        baseProgress * (crop.seedType.maxPlantWidthTiles >= 5 ? 1.85 : 1.15) +
        lush * (crop.seedType.maxPlantWidthTiles >= 5 ? 0.95 : 0.45);

    // 1. Fertilized soil nutrient shimmer or habitat thriving/struggling aura at the base.
    if (crop.isFertilized) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, bottomY - 1.5),
          width: 24.0 * spreadScale,
          height: 5.5,
        ),
        Paint()..color = const Color(0x88FFD54F),
      );
    }
    if (crop.lastHabitatMultiplier >= 1.35) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, bottomY - 2.0),
          width: 26.0 * spreadScale,
          height: 6.0,
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

    // 2. Pollinated golden pollen sparkles floating around the multi-tile plant.
    if (crop.isPollinated) {
      for (int i = 0; i < 6; i++) {
        final angle = _animTime * 3.5 + i * 1.05;
        final px = cx + math.cos(angle) * (14.0 * spreadScale);
        final py = bottomY - stemHeight * 0.65 + math.sin(angle * 1.4) * 12.0;
        canvas.drawCircle(
          Offset(px, py),
          2.1,
          Paint()..color = const Color(0xFFFFEA00),
        );
      }
    }

    final stemPaint =
        Paint()
          ..color = const Color(0xFF43A047)
          ..strokeWidth = 3.6
          ..strokeCap = StrokeCap.round;

    switch (crop.seedType) {
      case ItemType.berrySeeds:
        // Lush 5-tile-wide × 3-tile-tall sprawling bramble thicket with
        // terrain-hugging runners, 5 arching canes, layered foliage billows,
        // and abundant drupelet berry clusters!
        final leftReachPx = (22.0 +
                baseProgress * 28.0 +
                crop.spreadLeft * 20.0 +
                lush * 12.0)
            .clamp(16.0, 82.0);
        final rightReachPx = (22.0 +
                baseProgress * 28.0 +
                crop.spreadRight * 20.0 +
                lush * 12.0)
            .clamp(16.0, 82.0);
        _drawCreepingStolons(
          canvas,
          cx,
          bottomY,
          effectiveScale,
          const Color(0xFF33691E),
          leftReach: leftReachPx,
          rightReach: rightReachPx,
        );

        // Background shadow billows across the full bush width.
        if (baseProgress >= 0.35) {
          final bushMounds = <(double, double, double, double)>[
            (
              0.0,
              stemHeight * 0.56,
              36.0 + baseProgress * 28.0,
              stemHeight * 0.66,
            ),
            if (baseProgress >= 0.55) ...[
              (
                -leftReachPx * 0.48,
                stemHeight * 0.42,
                34.0 + lush * 16.0,
                stemHeight * 0.56,
              ),
              (
                rightReachPx * 0.48,
                stemHeight * 0.42,
                34.0 + lush * 16.0,
                stemHeight * 0.56,
              ),
            ],
            if (crop.spreadLeft >= 2 || lush >= 0.30)
              (
                -leftReachPx * 0.84,
                stemHeight * 0.28,
                30.0 + lush * 14.0,
                stemHeight * 0.42,
              ),
            if (crop.spreadRight >= 2 || lush >= 0.30)
              (
                rightReachPx * 0.84,
                stemHeight * 0.28,
                30.0 + lush * 14.0,
                stemHeight * 0.42,
              ),
          ];
          for (final (ox, oy, w, h) in bushMounds) {
            final center = Offset(cx + ox + sway * 0.35, bottomY - oy);
            canvas.drawOval(
              Rect.fromCenter(center: center, width: w, height: h),
              Paint()..color = const Color(0xFF1B5E20),
            );
            canvas.drawOval(
              Rect.fromCenter(
                center: center.translate(-2.0, -3.5),
                width: w * 0.78,
                height: h * 0.74,
              ),
              Paint()..color = const Color(0xFF2E7D32),
            );
            canvas.drawOval(
              Rect.fromCenter(
                center: center.translate(-4.0, -6.5),
                width: w * 0.50,
                height: h * 0.46,
              ),
              Paint()..color = const Color(0xFF43A047),
            );
          }
        }

        final topPos = _drawArticulatedPlantStem(
          canvas,
          cx: cx,
          bottomY: bottomY,
          height: stemHeight,
          sway: sway,
          progress: baseProgress,
          nodeCount: crop.stemNodeCount,
          stemColor: const Color(0xFF388E3C),
          leafColor: const Color(0xFF2E7D32),
          veinColor: const Color(0xFFA5D6A7),
          drawTendrils: true,
        );
        // Arching side canes fanning outward across the 5-tile bramble mound.
        if (baseProgress >= 0.50) {
          final caneSpecs = <(double, double, double)>[
            (-leftReachPx * 0.46, stemHeight * 0.78, -5.0),
            (rightReachPx * 0.46, stemHeight * 0.78, 5.0),
            if (crop.spreadLeft >= 2 || lush >= 0.28)
              (-leftReachPx * 0.82, stemHeight * 0.54, -8.0),
            if (crop.spreadRight >= 2 || lush >= 0.28)
              (rightReachPx * 0.82, stemHeight * 0.54, 8.0),
          ];
          for (final (offsetX, caneH, lean) in caneSpecs) {
            _drawArticulatedPlantStem(
              canvas,
              cx: cx + offsetX,
              bottomY: bottomY,
              height: caneH,
              sway: sway + lean,
              progress: baseProgress,
              nodeCount: math.max(2, crop.stemNodeCount - 1),
              stemColor: const Color(0xFF2E7D32),
              leafColor: const Color(0xFF388E3C),
              veinColor: const Color(0xFFC8E6C9),
              drawTendrils: true,
            );
          }
        }

        if (crop.stage == 2) {
          for (final (ox, oy) in [
            (-leftReachPx * 0.72, 0.34),
            (-leftReachPx * 0.38, 0.58),
            (-8.0, 0.82),
            (8.0, 0.76),
            (rightReachPx * 0.38, 0.56),
            (rightReachPx * 0.72, 0.34),
            (0.0, 0.44),
          ]) {
            _drawBotanicalBlossom(
              canvas,
              Offset(cx + ox + sway * 0.35, bottomY - stemHeight * oy),
              petalColor: const Color(0xFFFFF9C4),
              centerColor: const Color(0xFFFFB300),
            );
          }
        } else if (crop.isMature) {
          final berrySpots = <(double, double)>[
            (-leftReachPx * 0.45, 0.48),
            (-leftReachPx * 0.24, 0.72),
            (0.0, 0.52),
            (4.5, 0.86),
            (rightReachPx * 0.26, 0.70),
            (rightReachPx * 0.46, 0.46),
            (-leftReachPx * 0.14, 0.30),
            (rightReachPx * 0.16, 0.32),
            if (crop.spreadLeft >= 2 || lush >= 0.28) ...[
              (-leftReachPx * 0.78, 0.32),
              (-leftReachPx * 0.66, 0.50),
            ],
            if (crop.spreadRight >= 2 || lush >= 0.28) ...[
              (rightReachPx * 0.78, 0.32),
              (rightReachPx * 0.66, 0.50),
            ],
          ];
          for (final (ox, oy) in berrySpots) {
            _drawRealisticBerryCluster(
              canvas,
              Offset(topPos.dx + ox - sway * 0.2, bottomY - stemHeight * oy),
              scale: 1.08 + lush * 0.14,
            );
          }
        }

      case ItemType.bananaSeeds:
        // Towering 5-6 tile tall curved Banana Palm with ringed pseudo-stem,
        // sweeping 5-tile-wide crown of 10 broad veined tropical fronds,
        // hanging banana bunches, & sprouting daughter sucker shoot at base!
        final leanDir = crop.tileX.isEven ? 1.0 : -1.0;
        final trunkLean = leanDir * (6.0 + baseProgress * 12.0 + lush * 8.0);
        final topX = cx + trunkLean + sway * 0.85;
        final topY = bottomY - stemHeight;
        final midCtrlX = cx + trunkLean * 0.28 + sway * 0.3;
        final midCtrlY = bottomY - stemHeight * 0.48;
        final baseHalfW = 4.2 + baseProgress * 3.8 + lush * 1.6;
        final topHalfW = 2.2 + baseProgress * 1.8 + lush * 0.6;

        // Basal daughter banana sucker shoot when established!
        if (effectiveScale >= 0.88) {
          final suckerDir = -leanDir;
          final suckerH = stemHeight * (0.34 + lush * 0.08);
          final suckerTop = Offset(
            cx + suckerDir * (14.0 + lush * 6.0) + sway * 0.35,
            bottomY - suckerH,
          );
          canvas.drawPath(
            Path()
              ..moveTo(cx + suckerDir * 3.0, bottomY)
              ..quadraticBezierTo(
                cx + suckerDir * 9.0,
                bottomY - suckerH * 0.5,
                suckerTop.dx,
                suckerTop.dy,
              ),
            Paint()
              ..color = const Color(0xFF558B2F)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4.2
              ..strokeCap = StrokeCap.round,
          );
          for (final (sDir, sLift, sLen) in [
            (suckerDir, -7.0, 26.0 + lush * 8.0),
            (suckerDir * 0.55, -14.0, 22.0 + lush * 6.0),
            (-suckerDir * 0.65, -11.0, 18.0 + lush * 5.0),
          ]) {
            final sEnd = Offset(
              suckerTop.dx + sDir * sLen,
              suckerTop.dy - sLift * 0.35 + 5.0,
            );
            final sCtrl = Offset(
              suckerTop.dx + sDir * sLen * 0.55,
              suckerTop.dy + sLift,
            );
            final sBlade =
                Path()
                  ..moveTo(suckerTop.dx, suckerTop.dy + 1.0)
                  ..quadraticBezierTo(
                    sCtrl.dx,
                    sCtrl.dy - 3.6,
                    sEnd.dx,
                    sEnd.dy,
                  )
                  ..quadraticBezierTo(
                    sCtrl.dx,
                    sCtrl.dy + 2.8,
                    suckerTop.dx,
                    suckerTop.dy + 3.5,
                  )
                  ..close();
            canvas.drawPath(sBlade, Paint()..color = const Color(0xFF689F38));
          }
        }

        // Curved tapered palm trunk with 3-stop bark shading.
        final trunkPath =
            Path()
              ..moveTo(cx - baseHalfW, bottomY)
              ..quadraticBezierTo(
                midCtrlX - baseHalfW * 0.68,
                midCtrlY,
                topX - topHalfW,
                topY,
              )
              ..lineTo(topX + topHalfW, topY)
              ..quadraticBezierTo(
                midCtrlX + baseHalfW * 0.68,
                midCtrlY,
                cx + baseHalfW,
                bottomY,
              )
              ..close();
        canvas.drawPath(
          trunkPath,
          Paint()
            ..shader = Gradient.linear(
              Offset(cx - baseHalfW, bottomY),
              Offset(cx + baseHalfW + trunkLean * 0.4, bottomY),
              [
                const Color(0xFF33691E),
                const Color(0xFF7CB342),
                const Color(0xFF5D4037),
              ],
              [0.0, 0.42, 1.0],
            ),
        );

        // Sheathing palm leaf-scar rings curving along the tall trunk.
        final ringCount = (stemHeight / 7.5).floor();
        for (int r = 1; r < ringCount; r++) {
          final t = r / ringCount;
          final omt = 1.0 - t;
          final rx = omt * omt * cx + 2 * omt * t * midCtrlX + t * t * topX;
          final ry =
              omt * omt * bottomY + 2 * omt * t * midCtrlY + t * t * topY;
          final ringW = baseHalfW + (topHalfW - baseHalfW) * t;
          canvas.drawLine(
            Offset(rx - ringW * 0.92, ry),
            Offset(rx + ringW * 0.92, ry),
            Paint()
              ..color = const Color(0x992E4C14)
              ..strokeWidth = 1.5,
          );
        }

        // Broad sweeping palm frond crown (10 fronds spanning up to 5 tiles wide!).
        if (baseProgress >= 0.30) {
          final crownScale = 0.42 + baseProgress * 0.58 + lush * 0.34;
          for (final (dirFrond, lift, len, droop, isDark) in const [
            (-1.0, -6.0, 56.0, 18.0, true),
            (1.0, -6.0, 56.0, 18.0, true),
            (-0.92, -16.0, 52.0, 10.0, false),
            (0.92, -16.0, 52.0, 10.0, false),
            (-0.74, -24.0, 44.0, 2.0, true),
            (0.74, -24.0, 44.0, 2.0, true),
            (-0.48, -30.0, 34.0, -6.0, false),
            (0.48, -30.0, 34.0, -6.0, false),
            (-0.20, -34.0, 24.0, -14.0, false),
            (0.20, -34.0, 24.0, -14.0, false),
          ]) {
            final scaledLen = len * crownScale;
            final endX = topX + dirFrond * scaledLen;
            final endY = topY + droop * crownScale;
            final ctrlX = topX + dirFrond * scaledLen * 0.55;
            final ctrlY = topY + lift * crownScale;
            final bladePath =
                Path()
                  ..moveTo(topX, topY + 1.5)
                  ..quadraticBezierTo(ctrlX, ctrlY - 6.2, endX, endY)
                  ..quadraticBezierTo(ctrlX, ctrlY + 4.8, topX, topY + 5.0)
                  ..close();
            canvas.drawPath(
              bladePath,
              Paint()
                ..color =
                    isDark ? const Color(0xFF558B2F) : const Color(0xFF8BC34A),
            );
            final midrib =
                Path()
                  ..moveTo(topX, topY + 2.8)
                  ..quadraticBezierTo(ctrlX, ctrlY - 0.6, endX, endY);
            canvas.drawPath(
              midrib,
              Paint()
                ..color = const Color(0xFFDCEDC8)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
          }
        }
        if (crop.stage == 2) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(topX + 6.0, topY + 11.0),
              width: 7.0,
              height: 11.5,
            ),
            Paint()..color = const Color(0xFF880E4F),
          );
        } else if (crop.isMature) {
          _drawRealisticBananaBunch(canvas, Offset(topX - 9.0, topY + 5.0));
          _drawRealisticBananaBunch(canvas, Offset(topX + 9.0, topY + 7.5));
          if (lush >= 0.25) {
            _drawRealisticBananaBunch(canvas, Offset(topX - 1.0, topY + 14.0));
          }
          // Dangling crimson inflorescence bell below the banana hands.
          canvas.drawLine(
            Offset(topX + 1.0, topY + 15.0),
            Offset(topX + 2.5, topY + 27.0),
            Paint()
              ..color = const Color(0xFF558B2F)
              ..strokeWidth = 1.8,
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(topX + 2.5, topY + 30.0),
              width: 6.2,
              height: 9.8,
            ),
            Paint()..color = const Color(0xFF880E4F),
          );
        }

      case ItemType.mangoSeeds:
        // Broad 5-tile-tall × 5-tile-wide fruiting Mango Orchard Tree with
        // flared roots, gnarled trunk, 4 forked boughs, lush multi-lobed
        // tropical canopy, & abundant golden-crimson mangoes!
        final topX = cx + sway * 0.40;
        final topY = bottomY - stemHeight;
        final boughScale = baseProgress + lush * 0.42;

        // Flared buttress root base.
        final rootPath =
            Path()
              ..moveTo(cx - 8.5 * boughScale, bottomY)
              ..quadraticBezierTo(
                cx - 3.5 * boughScale,
                bottomY - 14.0,
                cx - 3.2,
                bottomY - stemHeight * 0.25,
              )
              ..lineTo(cx + 3.2, bottomY - stemHeight * 0.25)
              ..quadraticBezierTo(
                cx + 3.5 * boughScale,
                bottomY - 14.0,
                cx + 8.5 * boughScale,
                bottomY,
              )
              ..close();
        canvas.drawPath(rootPath, Paint()..color = const Color(0xFF4E342E));

        final trunkPaint =
            Paint()
              ..color = const Color(0xFF5D4037)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5.0 + baseProgress * 4.5 + lush * 2.2
              ..strokeCap = StrokeCap.round;
        final trunkPath =
            Path()
              ..moveTo(cx, bottomY)
              ..quadraticBezierTo(
                cx - 4.5,
                bottomY - stemHeight * 0.48,
                topX,
                topY + 10.0,
              );
        canvas.drawPath(trunkPath, trunkPaint);

        if (baseProgress >= 0.30) {
          final wideBough = (30.0 + baseProgress * 22.0 + lush * 22.0).clamp(
            18.0,
            74.0,
          );
          final branchPaint =
              Paint()
                ..color = const Color(0xFF6D4C41)
                ..strokeWidth = 3.8 + baseProgress * 1.8 + lush * 1.0
                ..strokeCap = StrokeCap.round;
          // Lower sweeping boughs + upper forked crown limbs.
          final forkY = topY + stemHeight * 0.30;
          canvas.drawLine(
            Offset(topX, forkY),
            Offset(topX - wideBough, topY + 14.0),
            branchPaint,
          );
          canvas.drawLine(
            Offset(topX, forkY - 2.0),
            Offset(topX + wideBough, topY + 12.0),
            branchPaint,
          );
          canvas.drawLine(
            Offset(topX, topY + 18.0),
            Offset(topX - wideBough * 0.62, topY - 4.0),
            branchPaint,
          );
          canvas.drawLine(
            Offset(topX, topY + 18.0),
            Offset(topX + wideBough * 0.62, topY - 4.0),
            branchPaint,
          );

          // Multi-layered broad umbrella canopy spanning up to 5 tiles.
          final r = 13.0 + baseProgress * 16.0 + lush * 8.0;
          final canopyLobes = <(double, double, double, Color)>[
            (-wideBough * 0.82, 12.0, r * 0.82, const Color(0xFF1B5E20)),
            (wideBough * 0.82, 10.0, r * 0.82, const Color(0xFF1B5E20)),
            (-wideBough * 0.42, -2.0, r * 0.94, const Color(0xFF2E7D32)),
            (wideBough * 0.42, -2.0, r * 0.94, const Color(0xFF2E7D32)),
            (0.0, -10.0, r * 1.05, const Color(0xFF2E7D32)),
            (-wideBough * 0.25, -8.0, r * 0.68, const Color(0xFF43A047)),
            (wideBough * 0.22, -12.0, r * 0.62, const Color(0xFF66BB6A)),
          ];
          for (final (ox, oy, rad, color) in canopyLobes) {
            canvas.drawCircle(
              Offset(topX + ox, topY + oy),
              rad,
              Paint()..color = color,
            );
          }

          if (crop.stage == 2) {
            for (final (ox, oy) in [
              (-wideBough * 0.72, 12.0),
              (-wideBough * 0.35, 0.0),
              (0.0, -6.0),
              (wideBough * 0.35, 0.0),
              (wideBough * 0.72, 10.0),
            ]) {
              _drawBotanicalBlossom(
                canvas,
                Offset(topX + ox, topY + oy),
                petalColor: const Color(0xFFFFF8E1),
                centerColor: const Color(0xFFFF8F00),
              );
            }
          } else if (crop.isMature) {
            for (final (ox, oy) in [
              (-wideBough * 0.78, 18.0),
              (-wideBough * 0.45, 9.0),
              (-12.0, 2.0),
              (2.0, 5.0),
              (15.0, -1.0),
              (wideBough * 0.45, 8.0),
              (wideBough * 0.78, 16.0),
              if (lush >= 0.30) ...[
                (-wideBough * 0.22, 16.0),
                (wideBough * 0.24, 15.0),
              ],
            ]) {
              _drawRealisticMango(canvas, Offset(topX + ox, topY + oy));
            }
          }
        }

      case ItemType.healingHerbSeeds:
        // Lush 5-tile-wide × 3-tile-tall billowing medicinal herb bush with
        // 7 wide-fanned aromatic stems, broad emerald ward aura, & blossom whorls!
        final auraRadius = 18.0 + baseProgress * 18.0 + lush * 14.0;
        if (baseProgress >= 0.30) {
          canvas.drawCircle(
            Offset(cx, bottomY - stemHeight * 0.42),
            auraRadius + math.sin(_animTime * 4.0) * 3.2,
            Paint()
              ..shader = Gradient.radial(
                Offset(cx, bottomY - stemHeight * 0.42),
                auraRadius + 4.0,
                [const Color(0x5200E676), const Color(0x0000E676)],
              ),
          );
        }
        final herbStems = <(double, double)>[
          (-0.52, 0.80),
          (0.0, 1.0),
          (0.52, 0.80),
          if (baseProgress >= 0.65) ...[(-0.92, 0.74), (0.92, 0.74)],
          if (lush >= 0.28 ||
              crop.spreadLeft >= 2 ||
              crop.spreadRight >= 2) ...[
            (-1.18, 0.66),
            (1.18, 0.66),
          ],
        ];
        for (final (angle, lenScale) in herbStems) {
          final branchH = stemHeight * lenScale;
          final tipX = cx + math.sin(angle + sway * 0.04) * branchH * 0.88;
          final tipY = bottomY - math.cos(angle * 0.72) * branchH;
          final stemPath =
              Path()
                ..moveTo(cx, bottomY)
                ..quadraticBezierTo(
                  (cx + tipX) * 0.5 - angle * 4.5,
                  (bottomY + tipY) * 0.5 + 3.0,
                  tipX,
                  tipY,
                );
          canvas.drawPath(
            stemPath,
            Paint()
              ..color = const Color(0xFF00C853)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.8 + lush * 0.8
              ..strokeCap = StrokeCap.round,
          );
          if (baseProgress >= 0.30) {
            for (final frac in const [0.32, 0.58, 0.82]) {
              final lx = cx + (tipX - cx) * frac;
              final ly = bottomY + (tipY - bottomY) * frac;
              final leafLen = (7.0 + baseProgress * 4.5 + lush * 3.0);
              _drawVeinedLeaf(
                canvas,
                Offset(lx, ly),
                angle: angle - 0.85,
                length: leafLen,
                leafColor: const Color(0xFF69F0AE),
                veinColor: const Color(0xFFE0F2F1),
              );
              _drawVeinedLeaf(
                canvas,
                Offset(lx, ly),
                angle: angle + 0.85,
                length: leafLen,
                leafColor: const Color(0xFF00E676),
                veinColor: const Color(0xFFE0F2F1),
              );
            }
          }
          if (crop.isMature) {
            for (int w = 0; w < 4; w++) {
              final wy = tipY + w * 2.8;
              canvas.drawOval(
                Rect.fromCenter(
                  center: Offset(tipX, wy),
                  width: 7.4 - w * 0.9,
                  height: 3.4,
                ),
                Paint()..color = const Color(0xFFB9F6CA),
              );
              canvas.drawCircle(
                Offset(tipX, wy),
                1.4,
                Paint()..color = const Color(0xFFE1BEE7),
              );
            }
          }
        }

      case ItemType.glowBulbSeeds:
        // Climbing bioluminescent lantern liana (3.5-4.4 tiles tall!) that
        // hugs cave walls, tree trunks, or canopies and hangs 4-5 glowing bulbs!
        final attachShift = crop.climbAttachDirection * 9.0;
        _drawCreepingStolons(
          canvas,
          cx,
          bottomY,
          effectiveScale,
          const Color(0xFF00796B),
        );
        // Ambient bioluminescent cave aura when big/lush.
        if (baseProgress >= 0.45) {
          final haloR = 32.0 + baseProgress * 22.0 + lush * 24.0;
          canvas.drawCircle(
            Offset(cx + attachShift * 0.5, bottomY - stemHeight * 0.58),
            haloR,
            Paint()
              ..shader = Gradient.radial(
                Offset(cx + attachShift * 0.5, bottomY - stemHeight * 0.58),
                haloR,
                [const Color(0x3640C4FF), const Color(0x0040C4FF)],
              ),
          );
        }
        final bulbCenter = _drawArticulatedPlantStem(
          canvas,
          cx: cx + attachShift * 0.45,
          bottomY: bottomY,
          height: stemHeight,
          sway: sway * (crop.climbAttachDirection != 0 ? 0.35 : 1.0),
          progress: baseProgress,
          nodeCount: crop.stemNodeCount,
          stemColor: const Color(0xFF00897B),
          leafColor: const Color(0xFF26A69A),
          veinColor: const Color(0xFF80CBC4),
          drawTendrils: true,
        );
        final outDir =
            crop.climbAttachDirection != 0
                ? -crop.climbAttachDirection.toDouble()
                : 1.0;
        if (baseProgress >= 0.55) {
          final lanternNodes = <(double, double, double)>[
            (outDir * (18.0 + lush * 10.0), 0.72, 0.58),
            (-outDir * (15.0 + lush * 8.0), 0.50, 0.36),
            if (effectiveScale >= 0.95)
              (outDir * (22.0 + lush * 10.0), 0.38, 0.26),
            if (lush >= 0.30) (-outDir * 18.0, 0.84, 0.72),
          ];
          for (final (ox, hFrac, anchorFrac) in lanternNodes) {
            final sideCenter = Offset(
              cx + attachShift * 0.35 + ox + sway * 0.4,
              bottomY - stemHeight * hFrac,
            );
            canvas.drawPath(
              Path()
                ..moveTo(
                  cx + attachShift * 0.45,
                  bottomY - stemHeight * anchorFrac,
                )
                ..quadraticBezierTo(
                  (cx + sideCenter.dx) * 0.5,
                  sideCenter.dy - 8.0,
                  sideCenter.dx,
                  sideCenter.dy,
                ),
              Paint()
                ..color = const Color(0xFF00897B)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.4
                ..strokeCap = StrokeCap.round,
            );
            _drawRealisticGlowFruit(canvas, sideCenter, crop);
          }
        }
        _drawRealisticGlowFruit(canvas, bulbCenter, crop);

      case ItemType.thornVineSeeds:
        // Towering 5-6 tile climbing double-helix Briar Vine that wraps up
        // adjacent walls & tree trunks while sprawling 5 tiles wide at the base!
        final attachShift = crop.climbAttachDirection * 9.5;
        final leftBriarPx = (24.0 +
                baseProgress * 22.0 +
                crop.spreadLeft * 20.0 +
                lush * 10.0)
            .clamp(18.0, 76.0);
        final rightBriarPx = (24.0 +
                baseProgress * 22.0 +
                crop.spreadRight * 20.0 +
                lush * 10.0)
            .clamp(18.0, 76.0);
        _drawCreepingStolons(
          canvas,
          cx,
          bottomY,
          effectiveScale,
          const Color(0xFF33691E),
          leftReach: leftBriarPx,
          rightReach: rightBriarPx,
        );

        final climbSway = sway * (crop.climbAttachDirection != 0 ? 0.35 : 1.0);
        final steps = (8 + (stemHeight / 18.0).floor()).clamp(8, 16);
        for (final strand in const [-1.0, 1.0]) {
          final vPath = Path()..moveTo(cx + strand * 6.5, bottomY);
          for (int i = 1; i <= steps; i++) {
            final frac = i / steps;
            final twist =
                math.sin(frac * math.pi * 4.2 + (strand < 0 ? 0.0 : math.pi)) *
                (8.0 + normalizedScale * 4.5);
            final vx = cx + attachShift * frac + twist + climbSway * frac;
            final vy = bottomY - stemHeight * frac;
            vPath.lineTo(vx, vy);

            final thornDir = twist >= 0 ? 1.0 : -1.0;
            _drawCurvedRoseThorn(canvas, Offset(vx, vy), thornDir);
            if (crop.climbAttachDirection != 0 && i % 3 == 0) {
              // Grasping tendrils latching straight onto the wall/tree trunk!
              _drawSpiralTendril(
                canvas,
                Offset(vx, vy),
                dir: crop.climbAttachDirection.toDouble(),
                color: const Color(0xFF689F38),
              );
            }
          }
          canvas.drawPath(
            vPath,
            Paint()
              ..color =
                  strand < 0 ? const Color(0xFF33691E) : const Color(0xFF558B2F)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.5 + lush * 0.8
              ..strokeCap = StrokeCap.round,
          );
        }

        // Wide double-tiered sweeping thorny arches across up to 5 tiles!
        if (baseProgress >= 0.55) {
          final arches = <(double, double, double)>[
            (-leftBriarPx * 0.56, 0.42, 0.66),
            (rightBriarPx * 0.56, 0.42, 0.66),
            if (crop.spreadLeft >= 2 || lush >= 0.25)
              (-leftBriarPx * 0.94, 0.26, 0.44),
            if (crop.spreadRight >= 2 || lush >= 0.25)
              (rightBriarPx * 0.94, 0.26, 0.44),
          ];
          for (final (targetDx, startFrac, peakFrac) in arches) {
            final sideDir = targetDx < 0 ? -1.0 : 1.0;
            final sideX = cx + targetDx;
            final peakY = bottomY - stemHeight * peakFrac;
            final archPath =
                Path()
                  ..moveTo(cx, bottomY - stemHeight * startFrac)
                  ..quadraticBezierTo(
                    (cx + sideX) * 0.5,
                    peakY - 10.0,
                    sideX,
                    bottomY - 4.0,
                  );
            canvas.drawPath(
              archPath,
              Paint()
                ..color = const Color(0xFF33691E)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.1
                ..strokeCap = StrokeCap.round,
            );
            _drawCurvedRoseThorn(
              canvas,
              Offset((cx + sideX) * 0.5, peakY - 2.0),
              sideDir,
            );
            _drawCurvedRoseThorn(
              canvas,
              Offset(
                cx + targetDx * 0.78,
                bottomY - stemHeight * peakFrac * 0.45,
              ),
              sideDir,
            );
          }
        }
        if (crop.isMature) {
          for (final (ox, oy) in [
            (-leftBriarPx * 0.42, 0.44),
            (-7.5, 0.68),
            (7.5, 0.82),
            (rightBriarPx * 0.42, 0.44),
            if (lush >= 0.25) ...[(-6.0, 0.94), (8.0, 0.56)],
          ]) {
            final hx = cx + attachShift * oy + ox + climbSway * oy;
            final hy = bottomY - stemHeight * oy;
            canvas.drawOval(
              Rect.fromCenter(center: Offset(hx, hy), width: 5.8, height: 7.8),
              Paint()..color = const Color(0xFFD50000),
            );
            canvas.drawCircle(
              Offset(hx - 0.9, hy - 1.4),
              1.3,
              Paint()..color = const Color(0xFFFF8A80),
            );
          }
        }

      case ItemType.pitcherPlantSeeds:
        // Climbing Nepenthes Pitcher Vine (4-5 tiles tall!) wrapping upward
        // along tree trunks, cliffs, or trellises with 5-6 hanging pitchers!
        final attachShift = crop.climbAttachDirection * 9.0;
        final outDir =
            crop.climbAttachDirection != 0
                ? -crop.climbAttachDirection.toDouble()
                : 1.0;
        _drawCreepingStolons(
          canvas,
          cx,
          bottomY,
          effectiveScale,
          const Color(0xFF2E7D32),
        );
        final topPos = _drawArticulatedPlantStem(
          canvas,
          cx: cx + attachShift * 0.45,
          bottomY: bottomY,
          height: stemHeight,
          sway: sway * (crop.climbAttachDirection != 0 ? 0.35 : 1.0),
          progress: baseProgress,
          nodeCount: crop.stemNodeCount,
          stemColor: const Color(0xFF388E3C),
          leafColor: const Color(0xFF43A047),
          veinColor: const Color(0xFFC8E6C9),
          drawTendrils: true,
        );
        if (baseProgress >= 0.35) {
          final pitcherSpecs = <(double, double)>[
            (outDir * 10.0, 0.84),
            if (baseProgress >= 0.60) ...[
              (-outDir * (14.0 + lush * 6.0), 0.58),
              (outDir * (19.0 + lush * 10.0), 0.48),
            ],
            if (effectiveScale >= 0.95) ...[
              (outDir * (22.0 + lush * 10.0), 0.72),
              (-outDir * 16.0, 0.32),
            ],
            if (lush >= 0.35) (outDir * 14.0, 0.94),
          ];
          for (final (ox, hFrac) in pitcherSpecs) {
            final anchorX =
                cx + attachShift * 0.45 + (topPos.dx - cx) * hFrac * 0.3;
            final anchorY = bottomY - stemHeight * hFrac;
            final pitcherPos = Offset(anchorX + ox, anchorY + 10.0);
            canvas.drawPath(
              Path()
                ..moveTo(anchorX, anchorY - 2.0)
                ..quadraticBezierTo(
                  (anchorX + pitcherPos.dx) * 0.5,
                  anchorY - 9.0,
                  pitcherPos.dx,
                  pitcherPos.dy - 6.0,
                ),
              Paint()
                ..color = const Color(0xFF66BB6A)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.8
                ..strokeCap = StrokeCap.round,
            );
            _drawRealisticPitcher(canvas, pitcherPos, crop);
          }
        }

      case ItemType.mahoganySapling:
        final topX = cx + sway * 0.35;
        final topY = bottomY - stemHeight;
        final saplingW = 4.5 + baseProgress * 3.5;
        final saplingTrunk =
            Path()
              ..moveTo(cx - saplingW, bottomY)
              ..quadraticBezierTo(
                cx - saplingW * 0.42,
                bottomY - stemHeight * 0.45,
                topX - 2.2,
                topY,
              )
              ..lineTo(topX + 2.2, topY)
              ..quadraticBezierTo(
                cx + saplingW * 0.42,
                bottomY - stemHeight * 0.45,
                cx + saplingW,
                bottomY,
              )
              ..close();
        canvas.drawPath(saplingTrunk, Paint()..color = const Color(0xFF5D4037));
        if (crop.stage >= 1) {
          final branchLen = 12.0 + baseProgress * 18.0;
          final bPaint =
              Paint()
                ..color = const Color(0xFF4E342E)
                ..strokeWidth = 3.0
                ..strokeCap = StrokeCap.round;
          canvas.drawLine(
            Offset(topX, topY + 12.0),
            Offset(topX - branchLen, topY + 2.0),
            bPaint,
          );
          canvas.drawLine(
            Offset(topX, topY + 10.0),
            Offset(topX + branchLen, topY + 1.0),
            bPaint,
          );
        }
        final crownR = 8.0 + baseProgress * 12.0;
        canvas.drawCircle(
          Offset(topX - 10.0 * baseProgress, topY + 3.0),
          crownR * 0.85,
          Paint()..color = const Color(0xFF1B5E20),
        );
        canvas.drawCircle(
          Offset(topX + 10.0 * baseProgress, topY + 3.0),
          crownR * 0.85,
          Paint()..color = const Color(0xFF2E7D32),
        );
        canvas.drawCircle(
          Offset(topX, topY - 4.0),
          crownR,
          Paint()..color = const Color(0xFF388E3C),
        );
        canvas.drawCircle(
          Offset(topX - 3.0, topY - 6.0),
          crownR * 0.62,
          Paint()..color = const Color(0xFF66BB6A),
        );

      default:
        canvas.drawLine(
          Offset(cx, bottomY),
          Offset(cx, bottomY - stemHeight),
          stemPaint,
        );
    }
  }

  /// Draws creeping basal stolon runner vines along the ground from the plant's crown.
  void _drawCreepingStolons(
    Canvas canvas,
    double cx,
    double bottomY,
    double progress,
    Color vineColor, {
    double? leftReach,
    double? rightReach,
  }) {
    if (progress < 0.25) return;
    final defaultReach = (progress - 0.20) * 24.0;
    final stolonPaint =
        Paint()
          ..color = vineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.3
          ..strokeCap = StrokeCap.round;
    for (final (dir, reach) in [
      (-1.0, leftReach ?? defaultReach),
      (1.0, rightReach ?? defaultReach),
    ]) {
      final path =
          Path()
            ..moveTo(cx, bottomY - 1.2)
            ..quadraticBezierTo(
              cx + dir * reach * 0.48,
              bottomY - 6.5,
              cx + dir * reach,
              bottomY - 1.4,
            );
      canvas.drawPath(path, stolonPaint);
      if (progress >= 0.55) {
        for (final frac in const [0.42, 0.78]) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(cx + dir * reach * frac, bottomY - 4.2),
              width: 6.0,
              height: 3.2,
            ),
            Paint()..color = const Color(0xFF66BB6A),
          );
        }
      }
    }
  }

  /// Draws an S-curved articulated stem with internode rings, veined leaves on
  /// petioles, and optional curling spiral vine tendrils. Returns the stem apex.
  Offset _drawArticulatedPlantStem(
    Canvas canvas, {
    required double cx,
    required double bottomY,
    required double height,
    required double sway,
    required double progress,
    required int nodeCount,
    required Color stemColor,
    required Color leafColor,
    required Color veinColor,
    required bool drawTendrils,
  }) {
    final topX = cx + sway * 0.55;
    final topY = bottomY - height;
    final ctrl1 = Offset(cx - 4.5 * progress, bottomY - height * 0.35);
    final ctrl2 = Offset(
      cx + 4.5 * progress + sway * 0.3,
      bottomY - height * 0.70,
    );

    final stemPath =
        Path()
          ..moveTo(cx, bottomY)
          ..cubicTo(ctrl1.dx, ctrl1.dy, ctrl2.dx, ctrl2.dy, topX, topY);
    canvas.drawPath(
      stemPath,
      Paint()
        ..color = stemColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );

    // Draw nodes, alternating lateral petioles + veined leaves, and curling tendrils.
    for (int n = 1; n <= nodeCount; n++) {
      final t = (n / (nodeCount + 0.5)).clamp(0.15, 0.92);
      final omt = 1.0 - t;
      final nx =
          omt * omt * omt * cx +
          3 * omt * omt * t * ctrl1.dx +
          3 * omt * t * t * ctrl2.dx +
          t * t * t * topX;
      final ny =
          omt * omt * omt * bottomY +
          3 * omt * omt * t * ctrl1.dy +
          3 * omt * t * t * ctrl2.dy +
          t * t * t * topY;

      // Node ring swelling.
      canvas.drawCircle(
        Offset(nx, ny),
        1.9,
        Paint()..color = const Color(0xFF1B5E20),
      );

      final side = n.isEven ? 1.0 : -1.0;
      final leafLen = (4.5 + progress * 4.5) * (1.0 - t * 0.25);
      _drawVeinedLeaf(
        canvas,
        Offset(nx, ny),
        angle: side * 0.95,
        length: leafLen,
        leafColor: leafColor,
        veinColor: veinColor,
      );

      if (drawTendrils && progress >= 0.45 && n >= 2) {
        _drawSpiralTendril(
          canvas,
          Offset(nx + side * 2.5, ny - 1.5),
          dir: -side,
          color: veinColor,
        );
      }
    }

    return Offset(topX, topY);
  }

  /// Draws a botanical leaf on a short petiole with a central midrib vein.
  void _drawVeinedLeaf(
    Canvas canvas,
    Offset origin, {
    required double angle,
    required double length,
    required Color leafColor,
    required Color veinColor,
  }) {
    final tip = Offset(
      origin.dx + math.sin(angle) * length,
      origin.dy - math.cos(angle) * length * 0.55,
    );
    final perp = Offset(math.cos(angle) * 2.6, math.sin(angle) * 2.6);
    final mid = Offset((origin.dx + tip.dx) * 0.5, (origin.dy + tip.dy) * 0.5);
    final leafPath =
        Path()
          ..moveTo(origin.dx, origin.dy)
          ..quadraticBezierTo(
            mid.dx + perp.dx,
            mid.dy - perp.dy,
            tip.dx,
            tip.dy,
          )
          ..quadraticBezierTo(
            mid.dx - perp.dx,
            mid.dy + perp.dy,
            origin.dx,
            origin.dy,
          )
          ..close();
    canvas.drawPath(leafPath, Paint()..color = leafColor);
    canvas.drawLine(
      origin,
      tip,
      Paint()
        ..color = veinColor
        ..strokeWidth = 0.9,
    );
  }

  /// Draws a delicate coiling botanical vine tendril extending from a stem node.
  void _drawSpiralTendril(
    Canvas canvas,
    Offset start, {
    required double dir,
    required Color color,
  }) {
    final path =
        Path()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(
            start.dx + dir * 5.5,
            start.dy - 4.0,
            start.dx + dir * 8.0,
            start.dy - 1.0,
          )
          ..arcToPoint(
            Offset(start.dx + dir * 6.0, start.dy - 3.5),
            radius: const Radius.circular(2.2),
            clockwise: dir > 0,
          );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawCurvedRoseThorn(Canvas canvas, Offset node, double dir) {
    final path =
        Path()
          ..moveTo(node.dx, node.dy - 1.8)
          ..quadraticBezierTo(
            node.dx + dir * 3.5,
            node.dy - 1.0,
            node.dx + dir * 4.8,
            node.dy + 1.5,
          )
          ..lineTo(node.dx, node.dy + 1.4)
          ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFF1744));
  }

  void _drawBotanicalBlossom(
    Canvas canvas,
    Offset center, {
    required Color petalColor,
    required Color centerColor,
  }) {
    for (int p = 0; p < 5; p++) {
      final a = p * (math.pi * 2.0 / 5.0);
      canvas.drawCircle(
        Offset(center.dx + math.cos(a) * 2.3, center.dy + math.sin(a) * 2.3),
        1.7,
        Paint()..color = petalColor,
      );
    }
    canvas.drawCircle(center, 1.4, Paint()..color = centerColor);
  }

  /// Renders a realistic clustered drupelet berry with pedicel, green sepal
  /// calyx, shaded ruby-violet drupelets, and dual specular glints.
  void _drawRealisticBerryCluster(
    Canvas canvas,
    Offset center, {
    double scale = 1.0,
  }) {
    // Slender pedicel stem & green star-shaped calyx cap.
    canvas.drawLine(
      Offset(center.dx, center.dy - 5.2 * scale),
      Offset(center.dx, center.dy - 2.6 * scale),
      Paint()
        ..color = const Color(0xFF33691E)
        ..strokeWidth = 1.2 * scale,
    );
    // 4 overlapping 3D shaded drupelet spheres.
    for (final (dx, dy, r) in const [
      (-1.5, 0.4, 2.3),
      (1.5, 0.4, 2.3),
      (0.0, 1.8, 2.4),
      (0.0, -0.7, 2.5),
    ]) {
      final dc = Offset(center.dx + dx * scale, center.dy + dy * scale);
      final rad = r * scale;
      canvas.drawCircle(
        dc,
        rad,
        Paint()
          ..shader = Gradient.radial(
            dc.translate(-rad * 0.3, -rad * 0.3),
            rad * 1.3,
            [
              const Color(0xFFFF1744),
              const Color(0xFFC62828),
              const Color(0xFF4A0E2E),
            ],
            [0.0, 0.62, 1.0],
          ),
      );
      canvas.drawCircle(
        dc.translate(-rad * 0.35, -rad * 0.35),
        rad * 0.32,
        Paint()..color = const Color(0xDDFFFFFF),
      );
    }
    // Green sepal crown on top of the berry cluster.
    final calyxPath =
        Path()
          ..moveTo(center.dx - 2.6 * scale, center.dy - 2.8 * scale)
          ..lineTo(center.dx, center.dy - 1.4 * scale)
          ..lineTo(center.dx + 2.6 * scale, center.dy - 2.8 * scale)
          ..lineTo(center.dx, center.dy - 3.6 * scale)
          ..close();
    canvas.drawPath(calyxPath, Paint()..color = const Color(0xFF66BB6A));
  }

  /// Renders a curved fruiting banana rachis with tiered crescent banana hands
  /// and a hanging crimson-purple banana heart (male inflorescence bell).
  void _drawRealisticBananaBunch(Canvas canvas, Offset crown) {
    // Curved green-brown fruiting rachis stalk.
    final rachisPath =
        Path()
          ..moveTo(crown.dx, crown.dy)
          ..quadraticBezierTo(
            crown.dx + 5.5,
            crown.dy + 6.0,
            crown.dx + 3.5,
            crown.dy + 15.5,
          );
    canvas.drawPath(
      rachisPath,
      Paint()
        ..color = const Color(0xFF558B2F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    // Tiered hands of curved crescent banana fingers.
    for (final (ox, oy, angle) in const [
      (-4.2, 2.5, -0.35),
      (-1.5, 3.2, -0.15),
      (1.5, 3.5, 0.12),
      (4.2, 3.0, 0.32),
      (-2.5, 7.5, -0.22),
      (0.8, 8.0, 0.08),
      (3.6, 7.6, 0.28),
    ]) {
      _drawRealisticBananaFinger(
        canvas,
        Offset(crown.dx + ox, crown.dy + oy),
        angle: angle,
      );
    }

    // Hanging crimson-purple teardrop banana heart (bell) at the tip of the rachis!
    final bellCenter = Offset(crown.dx + 3.5, crown.dy + 16.5);
    final bellPath =
        Path()
          ..moveTo(bellCenter.dx, bellCenter.dy - 2.8)
          ..quadraticBezierTo(
            bellCenter.dx + 3.2,
            bellCenter.dy,
            bellCenter.dx,
            bellCenter.dy + 3.8,
          )
          ..quadraticBezierTo(
            bellCenter.dx - 3.2,
            bellCenter.dy,
            bellCenter.dx,
            bellCenter.dy - 2.8,
          )
          ..close();
    canvas.drawPath(
      bellPath,
      Paint()
        ..shader = Gradient.linear(
          bellCenter.translate(0, -3),
          bellCenter.translate(0, 4),
          [const Color(0xFFAD1457), const Color(0xFF4A148C)],
        ),
    );
  }

  void _drawRealisticBananaFinger(
    Canvas canvas,
    Offset top, {
    required double angle,
  }) {
    canvas.save();
    canvas.translate(top.dx, top.dy);
    canvas.rotate(angle);
    final fingerPath =
        Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(2.8, 3.8, 1.2, 8.2)
          ..quadraticBezierTo(-1.2, 4.2, -1.2, 0.4)
          ..close();
    canvas.drawPath(
      fingerPath,
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          const Offset(1.2, 8.2),
          [
            const Color(0xFFAED581),
            const Color(0xFFFFEE58),
            const Color(0xFFFBC02D),
          ],
          [0.0, 0.28, 1.0],
        ),
    );
    // Dark floral remnant tip at bottom of banana finger.
    canvas.drawCircle(
      const Offset(1.1, 8.0),
      0.7,
      Paint()..color = const Color(0xFF3E2723),
    );
    canvas.restore();
  }

  /// Renders an asymmetric kidney-ovoid Mangifera mango drupe with a woody
  /// pedicel, crimson-to-golden-to-lime tropical blush, lenticels, & sheen.
  void _drawRealisticMango(Canvas canvas, Offset center) {
    // Woody pedicel & tiny leaf.
    canvas.drawLine(
      Offset(center.dx, center.dy - 6.0),
      Offset(center.dx, center.dy - 3.5),
      Paint()
        ..color = const Color(0xFF5D4037)
        ..strokeWidth = 1.3,
    );
    // Asymmetric kidney-ovoid mango contour with curved lower beak.
    final mangoPath =
        Path()
          ..moveTo(center.dx, center.dy - 4.2)
          ..cubicTo(
            center.dx + 4.8,
            center.dy - 4.0,
            center.dx + 4.5,
            center.dy + 2.5,
            center.dx + 1.4,
            center.dy + 5.0,
          )
          ..quadraticBezierTo(
            center.dx - 0.5,
            center.dy + 5.6,
            center.dx - 1.8,
            center.dy + 4.0,
          )
          ..cubicTo(
            center.dx - 4.2,
            center.dy + 1.5,
            center.dx - 4.2,
            center.dy - 3.8,
            center.dx,
            center.dy - 4.2,
          )
          ..close();
    final bounds = Rect.fromCenter(center: center, width: 8.5, height: 9.5);
    canvas.drawPath(
      mangoPath,
      Paint()
        ..shader = Gradient.linear(
          bounds.topLeft,
          bounds.bottomRight,
          [
            const Color(0xFFE53935),
            const Color(0xFFFFB300),
            const Color(0xFFC0CA33),
          ],
          [0.0, 0.58, 1.0],
        ),
    );
    // Curved specular highlight along upper shoulder + lenticel dots.
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-1.3, -1.6),
        width: 2.0,
        height: 3.4,
      ),
      Paint()..color = const Color(0x99FFFFFF),
    );
    canvas.drawCircle(
      center.translate(1.2, 1.4),
      0.5,
      Paint()..color = const Color(0x88FFF9C4),
    );
  }

  /// Renders a ribbed translucent bioluminescent lantern fruit with veined
  /// basal calyx sepals and internal glowing seed filaments.
  void _drawRealisticGlowFruit(
    Canvas canvas,
    Offset bulbCenter,
    CropPlot crop,
  ) {
    final glowRadius =
        12.0 + crop.growthProgress * 13.0 + math.sin(_animTime * 5.0) * 2.5;
    canvas.drawCircle(
      bulbCenter,
      glowRadius,
      Paint()
        ..shader = Gradient.radial(
          bulbCenter,
          glowRadius,
          [
            const Color(0x7700E5FF),
            const Color(0x2276FF03),
            const Color(0x0000E5FF),
          ],
          [0.0, 0.55, 1.0],
        ),
    );
    // Veined chalice sepals cradling the lantern fruit.
    for (final dir in const [-1.0, 1.0]) {
      _drawVeinedLeaf(
        canvas,
        bulbCenter.translate(0, 3.0),
        angle: dir * 1.15,
        length: 6.5,
        leafColor: const Color(0xFF00897B),
        veinColor: const Color(0xFF80CBC4),
      );
    }
    final podW = 7.5 + crop.growthProgress * 5.5;
    final podH = 9.0 + crop.growthProgress * 6.5;
    final podRect = Rect.fromCenter(
      center: bulbCenter,
      width: podW,
      height: podH,
    );
    canvas.drawOval(
      podRect,
      Paint()
        ..shader = Gradient.radial(
          bulbCenter,
          podH * 0.6,
          [
            Colors.white,
            crop.isMature ? const Color(0xFF76FF03) : const Color(0xFF00E5FF),
            const Color(0xFF00838F),
          ],
          [0.0, 0.55, 1.0],
        ),
    );
    // Longitudinal lantern ribs.
    for (final rx in const [-0.28, 0.0, 0.28]) {
      canvas.drawArc(
        Rect.fromCenter(
          center: bulbCenter.translate(podW * rx, 0),
          width: podW * 0.45,
          height: podH * 0.92,
        ),
        -math.pi * 0.5,
        math.pi,
        false,
        Paint()
          ..color = const Color(0x88E0F7FA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
    }
  }

  /// Renders a detailed Nepenthes carnivorous pitcher with looped tendril,
  /// fringed ventral wings, striped peristome lip, veined hood, & golden nectar.
  void _drawRealisticPitcher(Canvas canvas, Offset center, CropPlot crop) {
    final cupW = 11.5 + crop.growthProgress * 4.5;
    final cupH = 14.0 + crop.growthProgress * 6.5;
    final cupRect = Rect.fromCenter(center: center, width: cupW, height: cupH);

    // Mottled crimson-burgundy ascidium trap body.
    canvas.drawOval(
      cupRect,
      Paint()
        ..shader = Gradient.linear(
          cupRect.topCenter,
          cupRect.bottomCenter,
          [
            const Color(0xFFBA68C8),
            const Color(0xFF8E24AA),
            const Color(0xFF4A148C),
          ],
          [0.0, 0.5, 1.0],
        ),
    );
    // Botanical mottling blotches & fringed ventral wings.
    for (final (bx, by) in const [(-2.5, 1.5), (2.2, 3.2), (-1.0, -1.5)]) {
      canvas.drawCircle(
        center.translate(bx, by),
        1.4,
        Paint()..color = const Color(0x66311B92),
      );
    }
    // Golden digestive nectar meniscus glowing inside the throat when mature!
    if (crop.isMature || crop.isFertilized) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, cupRect.top + 3.2),
          width: cupW * 0.72,
          height: 3.0,
        ),
        Paint()..color = const Color(0xFFFFD54F),
      );
    }
    // Ribbed lime-and-crimson striped peristome collar.
    final peristomeRect = Rect.fromCenter(
      center: Offset(center.dx, cupRect.top + 1.8),
      width: cupW + 3.0,
      height: 4.6,
    );
    canvas.drawOval(peristomeRect, Paint()..color = const Color(0xFFC6FF00));
    for (double sx = -cupW * 0.4; sx <= cupW * 0.4; sx += 3.0) {
      canvas.drawLine(
        Offset(center.dx + sx, peristomeRect.top + 0.5),
        Offset(center.dx + sx, peristomeRect.bottom - 0.5),
        Paint()
          ..color = const Color(0xFFAD1457)
          ..strokeWidth = 1.1,
      );
    }
    // Veined operculum hood arching over the mouth + glistening nectar bead.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx + 2.0, cupRect.top - 3.8),
        width: cupW * 0.95,
        height: 7.0,
      ),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFFCE93D8),
    );
    canvas.drawCircle(
      Offset(center.dx - cupW * 0.35, cupRect.top + 3.6),
      1.3,
      Paint()..color = const Color(0xFFFFEA00),
    );
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
        // Multi-color gradient rainbow beak (opens wide with acoustic rings when screaming/calling!).
        final isScreaming =
            a.badgeTimer > 0 &&
            (a.activityBadge?.contains('SCREAM') == true ||
                a.activityBadge?.contains('KREE') == true ||
                a.activityBadge?.contains('Ate') == true);
        final jawOpen = isScreaming ? 2.8 : 0.0;
        final beakRect = Rect.fromLTWH(a.x + dir * 5, bodyY - 6, dir * 13, 8);
        final upperBeak =
            Path()
              ..moveTo(a.x + dir * 6, bodyY - 5.5 - jawOpen * 0.4)
              ..quadraticBezierTo(
                a.x + dir * 17,
                bodyY - 5.5 - jawOpen * 0.6,
                a.x + dir * 18,
                bodyY - 0.5 - jawOpen * 0.5,
              )
              ..lineTo(a.x + dir * 6, bodyY - 0.2)
              ..close();
        canvas.drawPath(
          upperBeak,
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
        // Lower mandible (pivots downward when screaming or holding fruit).
        final lowerBeak =
            Path()
              ..moveTo(a.x + dir * 6, bodyY - 0.2)
              ..lineTo(a.x + dir * 15.5, bodyY + 1.2 + jawOpen)
              ..lineTo(a.x + dir * 6, bodyY + 2.2 + jawOpen * 0.5)
              ..close();
        canvas.drawPath(lowerBeak, Paint()..color = const Color(0xFFFF6D00));

        if (isScreaming) {
          for (int ring = 1; ring <= 2; ring++) {
            final r = 8.0 + ((_animTime * 26.0 + ring * 6.0) % 15.0);
            canvas.drawCircle(
              Offset(a.x + dir * 16.0, bodyY - 1.0),
              r,
              Paint()
                ..color = const Color(0x8800E5FF)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.6,
            );
          }
        }
        if (a.carriedSeed != null) {
          _drawRealisticBerryCluster(
            canvas,
            Offset(a.x + dir * 14.5, bodyY + 1.5),
            scale: 0.72,
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
        // Red-Bellied Piranha with animated tail fin, dorsal/pectoral fins,
        // metallic scales, sharp teeth, and trailing underwater bubbles.
        final fishColor = flash ? Colors.white : const Color(0xFF546E7A);
        final swimPhase = _animTime * 22.0 + a.homeX * 0.05;
        final tailWag = math.sin(swimPhase) * 3.0;
        final bodyBob = math.cos(swimPhase * 0.5) * 1.4;
        final fy = a.y + bodyBob;

        // Trailing underwater air bubbles behind the swimming fish.
        for (int b = 0; b < 2; b++) {
          final bPhase = (_animTime * 1.8 + b * 0.5 + a.homeX * 0.01) % 1.0;
          final bx = a.x - dir * (13.0 + bPhase * 12.0);
          final by =
              fy - 5.0 - bPhase * 8.0 + math.sin(bPhase * math.pi * 2) * 1.5;
          canvas.drawCircle(
            Offset(bx, by),
            1.6 * (1.0 - bPhase * 0.4),
            Paint()
              ..color = Colors.lightBlueAccent.withValues(
                alpha: (1.0 - bPhase) * 0.55,
              )
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.9,
          );
        }

        // Forked caudal tail fin.
        final tailPath =
            Path()
              ..moveTo(a.x - dir * 8, fy - 5)
              ..lineTo(a.x - dir * 15, fy - 11 + tailWag)
              ..lineTo(a.x - dir * 12, fy - 5 + tailWag * 0.5)
              ..lineTo(a.x - dir * 15, fy + 1 + tailWag)
              ..close();
        canvas.drawPath(tailPath, Paint()..color = const Color(0xFF37474F));

        // Dorsal fin.
        final dorsalPath =
            Path()
              ..moveTo(a.x - dir * 3, fy - 10)
              ..lineTo(a.x - dir * 6, fy - 15 - tailWag * 0.25)
              ..lineTo(a.x + dir * 2, fy - 10.5)
              ..close();
        canvas.drawPath(dorsalPath, Paint()..color = const Color(0xFF455A64));

        // Main body & crimson-orange belly.
        canvas.drawOval(
          Rect.fromLTWH(a.x - 10, fy - 11, 20, 12),
          Paint()..color = fishColor,
        );
        canvas.drawArc(
          Rect.fromLTWH(a.x - 9, fy - 9, 18, 9),
          0,
          math.pi,
          true,
          Paint()..color = const Color(0xFFE53935),
        );

        // Fluttering pectoral fin.
        final pecY = fy - 4.0 + math.sin(swimPhase + 1.2) * 1.5;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(a.x - dir * 1.5, pecY),
            width: 5.5,
            height: 2.8,
          ),
          Paint()..color = const Color(0xCCFF7043),
        );

        // Fierce golden eye & lower jaw teeth.
        canvas.drawCircle(
          Offset(a.x + dir * 5, fy - 6.5),
          1.9,
          Paint()..color = Colors.yellowAccent,
        );
        canvas.drawCircle(
          Offset(a.x + dir * 5.5, fy - 6.5),
          0.85,
          Paint()..color = Colors.black,
        );
        for (int t = 0; t < 3; t++) {
          final tx = a.x + dir * (4.2 + t * 1.6);
          canvas.drawCircle(
            Offset(tx, fy - 2.8),
            0.75,
            Paint()..color = const Color(0xFFFFFDE7),
          );
        }
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
      case ItemType.ironPickaxe:
        canvas.drawLine(
          Offset.zero,
          Offset(dir * 11, -11),
          Paint()
            ..color = const Color(0xFF6D4C41)
            ..strokeWidth = 2.8
            ..strokeCap = StrokeCap.round,
        );
        final headColor = switch (item) {
          ItemType.ironPickaxe => const Color(0xFF40C4FF),
          ItemType.stonePickaxe => const Color(0xFFCFD8DC),
          _ => const Color(0xFF8D6E63),
        };
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

  void _renderRainOverlay(
    Canvas canvas,
    double viewW,
    double viewH,
    Offset cam,
  ) {
    const s = JungleWorld.tileSize;
    final rainPaint =
        Paint()
          ..color = const Color(0x77B3E5FC)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
    final shift = (_animTime * 380.0) % 40.0;
    for (double x = -20; x < viewW + 20; x += 26) {
      for (double y = shift - 40; y < viewH; y += 38) {
        final worldX = x + cam.dx;
        final worldY = y + cam.dy;
        final tx = JungleWorld.pixelToTile(worldX);
        final ty = (worldY / s).floor();
        // Never draw rain inside roofed huts, enclosed shelters, or caves!
        if (worldState.isTileShelteredFromRain(tx, ty)) {
          continue;
        }
        final endTx = JungleWorld.pixelToTile(worldX - 6);
        final endTy = ((worldY + 15) / s).floor();
        if (worldState.isTileShelteredFromRain(endTx, endTy)) {
          continue;
        }
        canvas.drawLine(Offset(x, y), Offset(x - 6, y + 15), rainPaint);
      }
    }

    // Draw tiny raindrop splash ripples along exposed hut roofs and ground!
    final splashPaint =
        Paint()
          ..color = const Color(0x99E1F5FE)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
    final startTx = (cam.dx / s).floor() - 1;
    final endTx = ((cam.dx + viewW) / s).ceil() + 1;
    final startTy = ((cam.dy / s).floor() - 1).clamp(1, worldState.height - 1);
    final endTy = (((cam.dy + viewH) / s).ceil() + 1).clamp(
      1,
      worldState.height - 1,
    );
    for (int tx = startTx; tx <= endTx; tx++) {
      for (int ty = startTy; ty <= endTy; ty++) {
        if (worldState.getBlock(tx, ty).countsAsRoof &&
            !worldState.isTileShelteredFromRain(tx, ty - 1)) {
          final phase = (_animTime * 9.0 + tx * 1.7) % 1.0;
          if (phase < 0.55) {
            final sx = tx * s + 8.0 + ((tx * 13).abs() % 16) - cam.dx;
            final sy = ty * s - cam.dy;
            final spread = phase * 6.5;
            canvas.drawLine(
              Offset(sx, sy),
              Offset(sx - spread, sy - 3.5 * (1.0 - phase)),
              splashPaint,
            );
            canvas.drawLine(
              Offset(sx, sy),
              Offset(sx + spread, sy - 3.5 * (1.0 - phase)),
              splashPaint,
            );
          }
          break;
        }
      }
    }
  }

  void _renderNightAndWarmthLighting(
    Canvas canvas,
    double viewW,
    double viewH,
    Offset cam,
  ) {
    final inDeepAbyss =
        worldState.playerTileY >= 29 && !worldState.abyssBlessingActive;
    if (!worldState.isNight && !inDeepAbyss) return;
    final playerScreen = Offset(
      worldState.playerX - cam.dx,
      worldState.playerY - 16.0 - cam.dy,
    );
    final shelter = worldState.evaluateShelterStatus(
      worldState.playerTileX,
      worldState.playerTileY,
    );
    final holdingTorch = worldState.equippedItem == ItemType.torchItem;
    final hasAbyssLight = worldState.hasAbyssLightAt(
      worldState.playerTileX,
      worldState.playerTileY,
    );
    final lightRadius =
        shelter.nearCampfire
            ? 210.0
            : ((shelter.nearTorch || holdingTorch || hasAbyssLight)
                ? 175.0
                : (inDeepAbyss ? 68.0 : 115.0));
    final darknessColor =
        inDeepAbyss ? const Color(0xDD03020B) : const Color(0xAA040814);

    final nightPaint =
        Paint()
          ..shader = Gradient.radial(playerScreen, lightRadius, [
            const Color(0x00000000),
            darknessColor,
          ]);
    canvas.drawRect(Rect.fromLTWH(0, 0, viewW, viewH), nightPaint);

    // Bioluminescent Glow-Bulb crops radiate soft cyan-lime halos at night or in caves!
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
