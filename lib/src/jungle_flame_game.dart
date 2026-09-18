import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEvent, KeyEventResult;

import 'models.dart';
import 'world_state.dart';

/// Action mode used when tapping or dragging on world tiles.
enum InteractionMode {
  /// Automatically mines blocks, harvests ripe crops, or uses the held item.
  smartAuto('⚡ Smart Auto'),

  /// Strictly mines foreground blocks or harvests crops.
  mineOnly('⛏️ Mine / Harvest'),

  /// Strictly places blocks/walls, sows seeds, or toggles doors.
  buildOrSow('🧱 Build / Sow');

  const InteractionMode(this.label);

  /// Display label for the HUD mode toggle button.
  final String label;
}

/// Flame 2D side-scrolling block survival game engine.
///
/// Renders the world procedurally on a [Canvas] and processes both keyboard/mouse
/// and mobile touch inputs.
final class JungleSurvivalGame extends FlameGame
    with TapCallbacks, DragCallbacks, KeyboardEvents {
  /// Creates a [JungleSurvivalGame] backed by [worldState].
  JungleSurvivalGame({required this.worldState, required this.onHudChanged});

  /// Underlying simulation state for the jungle world.
  final JungleWorld worldState;

  /// Callback invoked periodically to refresh the Flutter HUD overlay.
  final VoidCallback onHudChanged;

  /// Current tile interaction mode for taps and drags.
  InteractionMode interactionMode = InteractionMode.smartAuto;

  // Virtual mobile touch / keyboard directional state.
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

  /// Current camera top-left offset in world pixels.
  Offset get cameraTopLeft {
    final viewW = size.x > 0 ? size.x : 800.0;
    final viewH = size.y > 0 ? size.y : 500.0;
    final maxCamX = math.max(
      0.0,
      worldState.width * JungleWorld.tileSize - viewW,
    );
    final maxCamY = math.max(
      0.0,
      worldState.height * JungleWorld.tileSize - viewH,
    );
    final cx = (worldState.playerX - viewW * 0.5).clamp(0.0, maxCamX);
    final cy = (worldState.playerY - viewH * 0.54).clamp(0.0, maxCamY);
    return Offset(cx, cy);
  }

  /// Converts a screen-space point to world tile coordinates `(tx, ty)`.
  (int, int) screenToTile(Offset screenPoint) {
    final cam = cameraTopLeft;
    final wx = cam.dx + screenPoint.dx;
    final wy = cam.dy + screenPoint.dy;
    final tx = (wx ~/ JungleWorld.tileSize).clamp(0, worldState.width - 1);
    final ty = (wy ~/ JungleWorld.tileSize).clamp(0, worldState.height - 1);
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
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.keyE) {
        worldState.eatFood();
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
    final pos = Offset(event.localPosition.x, event.localPosition.y);
    _pointerScreenPos = pos;
    _pointerHeld = true;
    final (tx, ty) = screenToTile(pos);

    // Check if tapping near an animal to attack it first.
    final cam = cameraTopLeft;
    final worldTapX = cam.dx + pos.dx;
    final worldTapY = cam.dy + pos.dy;
    for (final a in worldState.animals) {
      final d = math.sqrt(
        math.pow(a.x - worldTapX, 2) + math.pow(a.y - worldTapY, 2),
      );
      if (d <= 36.0) {
        worldState.attackNearbyAnimals();
        onHudChanged();
        return;
      }
    }

    if (interactionMode == InteractionMode.mineOnly) {
      worldState.mineTileStep(tx, ty, 0.12);
    } else if (interactionMode == InteractionMode.buildOrSow) {
      worldState.interactOrPlaceAt(tx, ty);
    } else {
      // Smart Auto: try placing/sowing/harvesting/door-toggling first; if it
      // doesn't apply, begin mining the block.
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

  /// Performs the primary context action in front of the explorer (for mobile
  /// action button convenience).
  void performFrontAction() {
    if (worldState.attackNearbyAnimals()) {
      onHudChanged();
      return;
    }
    final dir = worldState.playerFacingRight ? 1 : -1;
    final tx = (worldState.playerTileX + dir).clamp(0, worldState.width - 1);
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

    if (_pointerHeld && _pointerScreenPos != null) {
      final (tx, ty) = screenToTile(_pointerScreenPos!);
      if (interactionMode == InteractionMode.buildOrSow) {
        worldState.interactOrPlaceAt(tx, ty);
      } else {
        final targetBlock = worldState.getBlock(tx, ty);
        if (targetBlock != BlockType.air && targetBlock != BlockType.water) {
          worldState.mineTileStep(tx, ty, dt);
        } else if (worldState.equippedItem.category == ItemCategory.building ||
            worldState.equippedItem.category == ItemCategory.seed) {
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

    final startTx = (cam.dx ~/ JungleWorld.tileSize - 1).clamp(
      0,
      worldState.width - 1,
    );
    final endTx = ((cam.dx + viewW) ~/ JungleWorld.tileSize + 2).clamp(
      0,
      worldState.width - 1,
    );
    final startTy = (cam.dy ~/ JungleWorld.tileSize - 1).clamp(
      0,
      worldState.height - 1,
    );
    final endTy = ((cam.dy + viewH) ~/ JungleWorld.tileSize + 2).clamp(
      0,
      worldState.height - 1,
    );

    // 1. Render background shelter walls.
    final wallPaint = Paint();
    final wallLinePaint = Paint()
      ..color = const Color(0x33000000)
      ..strokeWidth = 1.0;
    for (int ty = startTy; ty <= endTy; ty++) {
      for (int tx = startTx; tx <= endTx; tx++) {
        final wall = worldState.walls[ty][tx];
        if (wall != WallType.none) {
          final rect = Rect.fromLTWH(
            tx * JungleWorld.tileSize,
            ty * JungleWorld.tileSize,
            JungleWorld.tileSize,
            JungleWorld.tileSize,
          );
          wallPaint.color = wall.color;
          canvas.drawRect(rect, wallPaint);
          canvas.drawLine(
            Offset(rect.left, rect.center.dy),
            Offset(rect.right, rect.center.dy),
            wallLinePaint,
          );
        }
      }
    }

    // 2. Render foreground blocks.
    for (int ty = startTy; ty <= endTy; ty++) {
      for (int tx = startTx; tx <= endTx; tx++) {
        final block = worldState.blocks[ty][tx];
        if (block != BlockType.air) {
          _renderBlock(canvas, tx, ty, block);
        }
      }
    }

    // 3. Render growing crops on tilled soil.
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

    // 5. Render Dangerous Jungle Animals.
    for (final a in worldState.animals) {
      _renderAnimal(canvas, a);
    }

    // 6. Render Active Fishing Line & Bobber.
    if (worldState.activeFishing != null) {
      _renderFishingLine(canvas, worldState.activeFishing!);
    }

    // 7. Render the Explorer.
    _renderExplorer(canvas);

    // 8. Render mining progress cracks on targeted tile.
    if (worldState.miningTarget != null && worldState.miningProgress > 0) {
      final (mtx, mty) = worldState.miningTarget!;
      final mRect = Rect.fromLTWH(
        mtx * JungleWorld.tileSize,
        mty * JungleWorld.tileSize,
        JungleWorld.tileSize,
        JungleWorld.tileSize,
      );
      final crackPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(mRect.deflate(2.0), crackPaint);
      canvas.drawLine(
        mRect.topLeft,
        Offset(
          mRect.left + mRect.width * worldState.miningProgress,
          mRect.top + mRect.height * worldState.miningProgress,
        ),
        crackPaint,
      );
    }

    canvas.restore();

    // 9. Render rain droplets & night ambient darkness with warm campfire glow.
    if (worldState.isRaining) {
      _renderRainOverlay(canvas, viewW, viewH);
    }
    _renderNightAndWarmthLighting(canvas, viewW, viewH, cam);
  }

  void _renderSkyAndCanopyBackdrop(
    Canvas canvas,
    double viewW,
    double viewH,
    Offset cam,
  ) {
    final t = worldState.timeOfDay;
    Color topSky;
    Color bottomSky;
    if (t >= 0.23 && t <= 0.72) {
      topSky = const Color(0xFF1E88E5);
      bottomSky = const Color(0xFF81D4FA);
    } else if ((t > 0.72 && t <= 0.80) || (t >= 0.16 && t < 0.23)) {
      topSky = const Color(0xFF3949AB);
      bottomSky = const Color(0xFFFF7043);
    } else {
      topSky = const Color(0xFF090D16);
      bottomSky = const Color(0xFF1A233A);
    }

    final skyPaint = Paint()
      ..shader = Gradient.linear(Offset.zero, Offset(0, viewH), [
        topSky,
        bottomSky,
      ]);
    canvas.drawRect(Rect.fromLTWH(0, 0, viewW, viewH), skyPaint);

    // Sun / Moon arc.
    final sunAngle = (t - 0.2) * math.pi * 2.0;
    final orbX = viewW * 0.5 + math.cos(sunAngle) * (viewW * 0.36);
    final orbY = viewH * 0.42 - math.sin(sunAngle) * (viewH * 0.30);
    final isSun = math.sin(sunAngle) >= 0;
    canvas.drawCircle(
      Offset(orbX, orbY),
      isSun ? 24.0 : 18.0,
      Paint()
        ..color = isSun ? const Color(0xFFFFEE58) : const Color(0xFFE0E0E0),
    );

    // Parallax distant jungle silhouettes.
    final silhouettePaint = Paint()
      ..color = worldState.isNight
          ? const Color(0xFF0D1B12)
          : const Color(0xFF1B4326);
    final parallaxX = -(cam.dx * 0.2) % 120.0;
    for (double x = parallaxX - 120.0; x < viewW + 120.0; x += 120.0) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + 60.0, viewH * 0.62),
          width: 150.0,
          height: 120.0,
        ),
        silhouettePaint,
      );
    }
  }

  void _renderBlock(Canvas canvas, int tx, int ty, BlockType block) {
    const s = JungleWorld.tileSize;
    final left = tx * s;
    final top = ty * s;
    final rect = Rect.fromLTWH(left, top, s, s);
    final fill = Paint()..color = block.primaryColor;
    final accent = Paint()..color = block.accentColor;

    switch (block) {
      case BlockType.grass:
        canvas.drawRect(rect, Paint()..color = BlockType.dirt.primaryColor);
        canvas.drawRect(Rect.fromLTWH(left, top, s, 8.0), fill);
      case BlockType.tilledSoil:
        canvas.drawRect(rect, fill);
        for (double dx = 4; dx < s; dx += 8) {
          canvas.drawRect(Rect.fromLTWH(left + dx, top + 2, 4, 5), accent);
        }
      case BlockType.coalOre:
      case BlockType.ironOre:
        canvas.drawRect(rect, fill);
        canvas.drawCircle(Offset(left + 10, top + 11), 4.0, accent);
        canvas.drawCircle(Offset(left + 22, top + 20), 4.5, accent);
        canvas.drawCircle(Offset(left + 14, top + 24), 3.0, accent);
      case BlockType.woodLog:
        canvas.drawRect(Rect.fromLTWH(left + 6, top, s - 12, s), fill);
        canvas.drawRect(Rect.fromLTWH(left + 10, top, 3, s), accent);
      case BlockType.leaves:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(1.0), const Radius.circular(6)),
          fill,
        );
        canvas.drawCircle(Offset(left + 12, top + 12), 5.0, accent);
      case BlockType.vine:
        final sway = math.sin(_animTime * 2.4 + ty * 0.6) * 2.0;
        canvas.drawRect(Rect.fromLTWH(left + 13 + sway, top, 5, s), fill);
        canvas.drawCircle(Offset(left + 15 + sway, top + 14), 3.5, accent);
      case BlockType.berryBush:
        canvas.drawOval(Rect.fromLTWH(left + 3, top + 6, s - 6, s - 6), fill);
        canvas.drawCircle(Offset(left + 11, top + 14), 3.2, accent);
        canvas.drawCircle(Offset(left + 20, top + 18), 3.2, accent);
        canvas.drawCircle(Offset(left + 15, top + 23), 3.2, accent);
      case BlockType.water:
        final wave = math.sin(_animTime * 3.0 + tx * 0.7) * 2.0;
        canvas.drawRect(
          Rect.fromLTWH(left, top + 2 + wave, s, s - 2 - wave),
          fill,
        );
        canvas.drawRect(
          Rect.fromLTWH(left + 4, top + 5 + wave, s - 8, 3.0),
          accent,
        );
      case BlockType.campfire:
        // Stone & log base + animated flickering flame.
        canvas.drawRect(
          Rect.fromLTWH(left + 5, top + 22, s - 10, 8),
          Paint()..color = const Color(0xFF5D4037),
        );
        final flicker = math.sin(_animTime * 12.0 + tx) * 3.0;
        final flamePath = Path()
          ..moveTo(left + 8, top + 24)
          ..lineTo(left + 16, top + 6 + flicker)
          ..lineTo(left + 24, top + 24)
          ..close();
        canvas.drawPath(flamePath, fill);
        canvas.drawCircle(Offset(left + 16, top + 18), 5.0, accent);
      case BlockType.torch:
        canvas.drawRect(
          Rect.fromLTWH(left + 14, top + 12, 4, 16),
          Paint()..color = const Color(0xFF6D4C41),
        );
        canvas.drawCircle(
          Offset(left + 16, top + 10 + math.sin(_animTime * 10.0) * 1.5),
          5.0,
          fill,
        );
      case BlockType.doorClosed:
        canvas.drawRect(Rect.fromLTWH(left + 8, top, s - 16, s), fill);
        canvas.drawCircle(Offset(left + 19, top + 16), 2.5, accent);
      case BlockType.doorOpen:
        canvas.drawRect(Rect.fromLTWH(left + 2, top, 6, s), fill);
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

  void _renderCrop(Canvas canvas, CropPlot crop) {
    const s = JungleWorld.tileSize;
    final cx = crop.tileX * s + s * 0.5;
    final bottomY = (crop.tileY + 1) * s;
    final stemHeight = 7.0 + crop.growthProgress * 20.0;
    final stemPaint = Paint()
      ..color = const Color(0xFF66BB6A)
      ..strokeWidth = 3.0;
    canvas.drawLine(
      Offset(cx, bottomY),
      Offset(cx, bottomY - stemHeight),
      stemPaint,
    );
    if (crop.stage >= 1) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx - 5, bottomY - stemHeight * 0.6),
          width: 8,
          height: 5,
        ),
        stemPaint,
      );
    }
    if (crop.isMature) {
      final fruitColor = switch (crop.seedType) {
        ItemType.bananaSeeds => const Color(0xFFFFEE58),
        ItemType.mangoSeeds => const Color(0xFFFFA726),
        _ => const Color(0xFFEF5350),
      };
      canvas.drawCircle(
        Offset(cx, bottomY - stemHeight - 3),
        5.5,
        Paint()..color = fruitColor,
      );
    }
  }

  void _renderVillager(Canvas canvas, NativeVillager v) {
    // Legs & woven tunic.
    canvas.drawRect(
      Rect.fromLTWH(v.x - 7, v.y - 24, 14, 18),
      Paint()..color = const Color(0xFF26A69A),
    );
    // Head.
    canvas.drawCircle(
      Offset(v.x, v.y - 30),
      7.0,
      Paint()..color = const Color(0xFFD7CCC8),
    );
    // Feathered jungle crown.
    canvas.drawArc(
      Rect.fromCenter(center: Offset(v.x, v.y - 35), width: 16, height: 10),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFFFFCA28),
    );
  }

  void _renderAnimal(Canvas canvas, JungleAnimal a) {
    final flash = a.hurtFlashTimer > 0;
    switch (a.type) {
      case AnimalType.jaguar:
        final bodyColor = flash ? Colors.redAccent : const Color(0xFFFFB300);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(a.x - 14, a.y - 18, 28, 14),
            const Radius.circular(5),
          ),
          Paint()..color = bodyColor,
        );
        // Jaguar spots & head.
        canvas.drawCircle(
          Offset(a.x + (a.facingRight ? 12 : -12), a.y - 16),
          6.5,
          Paint()..color = bodyColor,
        );
        canvas.drawCircle(
          Offset(a.x - 4, a.y - 12),
          2.2,
          Paint()..color = const Color(0xFF3E2723),
        );
        canvas.drawCircle(
          Offset(a.x + 4, a.y - 11),
          2.2,
          Paint()..color = const Color(0xFF3E2723),
        );
      case AnimalType.snake:
        final snakeColor = flash ? Colors.redAccent : const Color(0xFF00E676);
        canvas.drawOval(
          Rect.fromLTWH(a.x - 11, a.y - 10, 22, 9),
          Paint()..color = snakeColor,
        );
        canvas.drawCircle(
          Offset(a.x + (a.facingRight ? 9 : -9), a.y - 9),
          4.5,
          Paint()..color = snakeColor,
        );
      case AnimalType.piranha:
        final fishColor = flash ? Colors.white : const Color(0xFFE53935);
        canvas.drawOval(
          Rect.fromLTWH(a.x - 9, a.y - 10, 18, 11),
          Paint()..color = fishColor,
        );
    }

    // Health bar if injured.
    if (a.health < a.type.maxHealth) {
      final pct = (a.health / a.type.maxHealth).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(a.x - 14, a.y - 28, 28, 4),
        Paint()..color = Colors.black54,
      );
      canvas.drawRect(
        Rect.fromLTWH(a.x - 14, a.y - 28, 28 * pct, 4),
        Paint()..color = Colors.redAccent,
      );
    }
  }

  void _renderFishingLine(Canvas canvas, FishingState fish) {
    final rodTip = Offset(
      worldState.playerX + (worldState.playerFacingRight ? 14 : -14),
      worldState.playerY - 18,
    );
    final bobberOffset = Offset(
      fish.bobberX,
      fish.bobberY + (fish.hasBite ? math.sin(_animTime * 28.0) * 4.5 : 0.0),
    );
    canvas.drawLine(
      rodTip,
      bobberOffset,
      Paint()
        ..color = Colors.white70
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(
      bobberOffset,
      fish.hasBite ? 6.0 : 4.2,
      Paint()
        ..color = fish.hasBite
            ? const Color(0xFFFFEB3B)
            : const Color(0xFFE53935),
    );
  }

  void _renderExplorer(Canvas canvas) {
    final px = worldState.playerX;
    final py = worldState.playerY;
    final hurt = worldState.playerHurtFlashTimer > 0;

    // Legs.
    final stride = worldState.playerVx.abs() > 5
        ? math.sin(_animTime * 14.0) * 4.0
        : 0.0;
    final legPaint = Paint()..color = const Color(0xFF4E342E);
    canvas.drawRect(Rect.fromLTWH(px - 6 + stride, py - 10, 5, 10), legPaint);
    canvas.drawRect(Rect.fromLTWH(px + 1 - stride, py - 10, 5, 10), legPaint);

    // Torso (or Warm Poncho if owned).
    final torsoColor = hurt
        ? Colors.redAccent
        : (worldState.hasWarmPoncho
              ? const Color(0xFFD84315)
              : const Color(0xFF8D6E63));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(px - 8, py - 24, 16, 15),
        const Radius.circular(4),
      ),
      Paint()..color = torsoColor,
    );

    // Head & Explorer Pith Helmet.
    canvas.drawCircle(
      Offset(px, py - 29),
      6.5,
      Paint()..color = const Color(0xFFFFCCBC),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(px, py - 34), width: 19, height: 6),
      Paint()..color = const Color(0xFFFBC02D),
    );

    // Tool / Weapon swing arc.
    if (worldState.swingAnimationTimer > 0) {
      final dir = worldState.playerFacingRight ? 1.0 : -1.0;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(px + dir * 14, py - 18),
          width: 28,
          height: 28,
        ),
        -0.8,
        1.6,
        false,
        Paint()
          ..color = Colors.white70
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );
    }
  }

  void _renderRainOverlay(Canvas canvas, double viewW, double viewH) {
    final rainPaint = Paint()
      ..color = const Color(0x66B3E5FC)
      ..strokeWidth = 1.5;
    final shift = (_animTime * 360.0) % 40.0;
    for (double x = -20; x < viewW + 20; x += 28) {
      for (double y = shift - 40; y < viewH; y += 40) {
        canvas.drawLine(Offset(x, y), Offset(x - 5, y + 14), rainPaint);
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
    final lightRadius = shelter.nearCampfire
        ? 195.0
        : (shelter.nearTorch ? 145.0 : 105.0);

    final nightPaint = Paint()
      ..shader = Gradient.radial(playerScreen, lightRadius, [
        const Color(0x00000000),
        const Color(0xAA040814),
      ]);
    canvas.drawRect(Rect.fromLTWH(0, 0, viewW, viewH), nightPaint);
  }
}
