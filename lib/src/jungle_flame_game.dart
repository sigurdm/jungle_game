import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart'
    show Colors, TextPainter, TextSpan, TextStyle, TextDirection;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEvent, KeyEventResult;

import 'models.dart';
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
/// beehives, and multi-layered character graphics procedurally on a [Canvas].
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

    final cam = cameraTopLeft;
    final worldTapX = cam.dx + pos.dx;
    final worldTapY = cam.dy + pos.dy;
    for (final a in worldState.animals) {
      final d = math.sqrt(
        math.pow(a.x - worldTapX, 2) + math.pow(a.y - worldTapY, 2),
      );
      if (d <= 36.0 && (a.type != AnimalType.beeSwarm || a.isAngry)) {
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
    final wallLinePaint =
        Paint()
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

    // 2. Render foreground blocks (including Beehives, Flowing Water & Wildfire).
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

    // 8. Render mining progress cracks on targeted tile.
    if (worldState.miningTarget != null && worldState.miningProgress > 0) {
      final (mtx, mty) = worldState.miningTarget!;
      final mRect = Rect.fromLTWH(
        mtx * JungleWorld.tileSize,
        mty * JungleWorld.tileSize,
        JungleWorld.tileSize,
        JungleWorld.tileSize,
      );
      final crackPaint =
          Paint()
            ..color = Colors.white.withValues(alpha: 0.7)
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

    final skyPaint =
        Paint()
          ..shader = Gradient.linear(Offset.zero, Offset(0, viewH), [
            topSky,
            bottomSky,
          ]);
    canvas.drawRect(Rect.fromLTWH(0, 0, viewW, viewH), skyPaint);

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

    final silhouettePaint =
        Paint()
          ..color =
              worldState.isNight
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
        // Individual grass blades along top edge.
        for (double gx = 3; gx < s - 3; gx += 6) {
          canvas.drawLine(
            Offset(left + gx, top + 2),
            Offset(left + gx + 1.5, top - 3),
            Paint()
              ..color = const Color(0xFF43A047)
              ..strokeWidth = 1.6,
          );
        }
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
        canvas.drawRect(Rect.fromLTWH(left + 18, top, 2, s), accent);
      case BlockType.leaves:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(1.0), const Radius.circular(6)),
          fill,
        );
        canvas.drawCircle(Offset(left + 12, top + 12), 5.0, accent);
        canvas.drawCircle(Offset(left + 21, top + 19), 4.0, accent);
      case BlockType.vine:
        final sway = math.sin(_animTime * 2.4 + ty * 0.6) * 2.0;
        canvas.drawRect(Rect.fromLTWH(left + 13 + sway, top, 5, s), fill);
        canvas.drawCircle(Offset(left + 15 + sway, top + 14), 3.5, accent);
      case BlockType.berryBush:
        canvas.drawOval(Rect.fromLTWH(left + 3, top + 6, s - 6, s - 6), fill);
        canvas.drawCircle(Offset(left + 11, top + 14), 3.4, accent);
        canvas.drawCircle(Offset(left + 20, top + 18), 3.4, accent);
        canvas.drawCircle(Offset(left + 15, top + 23), 3.4, accent);
      case BlockType.beehive:
        // Tiered golden honeycomb hive with entrance hole & dripping honey!
        final hiveRect = Rect.fromLTWH(left + 4, top + 3, s - 8, s - 6);
        canvas.drawOval(hiveRect, fill);
        final ribPaint =
            Paint()
              ..color = const Color(0xFFE65100)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6;
        for (double ry = top + 9; ry <= top + 23; ry += 5) {
          canvas.drawLine(
            Offset(left + 6, ry),
            Offset(left + s - 6, ry),
            ribPaint,
          );
        }
        // Dark hive entrance hole.
        canvas.drawCircle(
          Offset(left + s * 0.5, top + 18),
          3.8,
          Paint()..color = const Color(0xFF3E2723),
        );
        // Animated golden honey drop dripping from the bottom of the hive.
        final dropOffset = (_animTime * 9.0 + tx * 2.0) % 7.0;
        canvas.drawCircle(
          Offset(left + s * 0.5 + 4, top + s - 3 + dropOffset),
          2.3,
          Paint()..color = const Color(0xFFFFD54F),
        );
      case BlockType.wildfire:
        // Roaring spreading wildfire with multi-layered flame tongues & embers.
        final f1 = math.sin(_animTime * 16.0 + tx) * 4.0;
        final f2 = math.cos(_animTime * 20.0 + ty) * 3.5;
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
        // Rising smoke & spark ember.
        final emberY = top + 4 - ((_animTime * 28.0 + tx * 7) % 14.0);
        canvas.drawCircle(
          Offset(left + 16 + f1, emberY),
          2.0,
          Paint()..color = const Color(0xFFFFEA00),
        );
      case BlockType.water:
        final wave = math.sin(_animTime * 3.0 + tx * 0.7) * 2.0;
        final isFalling =
            ty + 1 < worldState.height &&
            worldState.getBlock(tx, ty + 1) == BlockType.air;
        canvas.drawRect(
          Rect.fromLTWH(left, top + (isFalling ? 0 : 2 + wave), s, s),
          fill,
        );
        canvas.drawRect(
          Rect.fromLTWH(left + 4, top + 5 + wave, s - 8, 3.0),
          accent,
        );
        if (isFalling) {
          // Waterfall foam streaks when water falls with gravity.
          canvas.drawLine(
            Offset(left + 10, top + 2),
            Offset(left + 10, top + s - 2),
            Paint()
              ..color = Colors.white70
              ..strokeWidth = 2.0,
          );
          canvas.drawLine(
            Offset(left + 21, top + 4),
            Offset(left + 21, top + s - 2),
            Paint()
              ..color = Colors.white70
              ..strokeWidth = 2.0,
          );
        }
      case BlockType.campfire:
        canvas.drawRect(
          Rect.fromLTWH(left + 5, top + 22, s - 10, 8),
          Paint()..color = const Color(0xFF5D4037),
        );
        final flicker = math.sin(_animTime * 12.0 + tx) * 3.0;
        final flamePath =
            Path()
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
    final stemPaint =
        Paint()
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
    final bob = math.sin(_animTime * 3.2 + v.x) * 1.2;
    // Legs & sandals.
    final legPaint = Paint()..color = const Color(0xFF8D6E63);
    canvas.drawRect(Rect.fromLTWH(v.x - 5, v.y - 9, 4, 9), legPaint);
    canvas.drawRect(Rect.fromLTWH(v.x + 1, v.y - 9, 4, 9), legPaint);

    // Carved wooden staff with glowing amber tip.
    canvas.drawLine(
      Offset(v.x + 11, v.y),
      Offset(v.x + 11, v.y - 34 + bob),
      Paint()
        ..color = const Color(0xFF5D4037)
        ..strokeWidth = 2.6,
    );
    canvas.drawCircle(
      Offset(v.x + 11, v.y - 36 + bob),
      3.8,
      Paint()..color = const Color(0xFFFFCA28),
    );

    // Patterned woven tunic & belt.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(v.x - 8, v.y - 25 + bob, 16, 17),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF00897B),
    );
    canvas.drawRect(
      Rect.fromLTWH(v.x - 8, v.y - 14 + bob, 16, 3),
      Paint()..color = const Color(0xFFFFB300),
    );
    // Beaded necklace.
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

    // Head, eyes, and ceremonial facial stripes.
    canvas.drawCircle(
      Offset(v.x, v.y - 31 + bob),
      7.2,
      Paint()..color = const Color(0xFFD7CCC8),
    );
    canvas.drawCircle(
      Offset(v.x - 2.5, v.y - 32 + bob),
      1.2,
      Paint()..color = Colors.black87,
    );
    canvas.drawCircle(
      Offset(v.x + 2.5, v.y - 32 + bob),
      1.2,
      Paint()..color = Colors.black87,
    );

    // Multi-feather Macaw Crown (crimson, gold, cyan plumes).
    for (final (angle, color) in const [
      (-0.45, Color(0xFFE53935)),
      (-0.15, Color(0xFFFFCA28)),
      (0.15, Color(0xFF29B6F6)),
      (0.45, Color(0xFFE53935)),
    ]) {
      final fx = v.x + math.sin(angle) * 11;
      final fy = v.y - 37 + bob - math.cos(angle) * 7;
      canvas.drawLine(
        Offset(v.x + math.sin(angle) * 4, v.y - 36 + bob),
        Offset(fx, fy),
        Paint()
          ..color = color
          ..strokeWidth = 2.6,
      );
    }

    // Floating villager name tag.
    final tp = TextPainter(
      text: TextSpan(
        text: v.name,
        style: const TextStyle(
          color: Color(0xFFFFF59D),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(v.x - tp.width * 0.5, v.y - 54 + bob));
  }

  void _renderAnimal(Canvas canvas, JungleAnimal a) {
    final flash = a.hurtFlashTimer > 0;
    final dir = a.facingRight ? 1.0 : -1.0;

    switch (a.type) {
      case AnimalType.beeSwarm:
        // Render a buzzing trio of striped honeybees with fluttering wings!
        for (int i = 0; i < 3; i++) {
          final phase = _animTime * 16.0 + i * 2.1;
          final bx = a.x + math.cos(phase * 0.7) * 9.0 * (i == 0 ? 0.3 : 1.0);
          final by =
              a.y - 10.0 + math.sin(phase * 1.1) * 6.0 * (i == 0 ? 0.3 : 1.0);

          // Angry crimson aura if provoked.
          if (a.isAngry) {
            canvas.drawCircle(
              Offset(bx, by),
              6.5,
              Paint()..color = const Color(0x44FF1744),
            );
          }

          // Translucent fluttering wings.
          final wingFlutter = math.sin(_animTime * 48.0 + i) * 3.0;
          final wingPaint = Paint()..color = const Color(0xCCFFFFFF);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(bx - 1.5, by - 4.0 + wingFlutter * 0.4),
              width: 5.5,
              height: 3.5,
            ),
            wingPaint,
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(bx + 1.5, by - 4.0 - wingFlutter * 0.4),
              width: 5.5,
              height: 3.5,
            ),
            wingPaint,
          );

          // Golden-yellow bee abdomen & black stripes.
          canvas.drawOval(
            Rect.fromCenter(center: Offset(bx, by), width: 9.0, height: 6.0),
            Paint()..color = flash ? Colors.redAccent : const Color(0xFFFFD600),
          );
          final stripePaint =
              Paint()
                ..color = const Color(0xFF212121)
                ..strokeWidth = 1.4;
          canvas.drawLine(
            Offset(bx - 1.5, by - 2.5),
            Offset(bx - 1.5, by + 2.5),
            stripePaint,
          );
          canvas.drawLine(
            Offset(bx + 1.5, by - 2.5),
            Offset(bx + 1.5, by + 2.5),
            stripePaint,
          );
        }

      case AnimalType.jaguar:
        final bodyColor = flash ? Colors.redAccent : const Color(0xFFFFB300);
        final legCycle = math.sin(_animTime * 15.0) * 4.5;
        final legPaint =
            Paint()
              ..color = const Color(0xFFE65100)
              ..strokeWidth = 3.5;

        // 4 Running legs.
        canvas.drawLine(
          Offset(a.x - 9, a.y - 8),
          Offset(a.x - 11 + legCycle, a.y),
          legPaint,
        );
        canvas.drawLine(
          Offset(a.x - 5, a.y - 8),
          Offset(a.x - 5 - legCycle, a.y),
          legPaint,
        );
        canvas.drawLine(
          Offset(a.x + 7, a.y - 8),
          Offset(a.x + 8 + legCycle, a.y),
          legPaint,
        );
        canvas.drawLine(
          Offset(a.x + 10, a.y - 8),
          Offset(a.x + 10 - legCycle, a.y),
          legPaint,
        );

        // Curved prowling jaguar tail with black tip.
        final tailPath =
            Path()
              ..moveTo(a.x - dir * 13, a.y - 14)
              ..quadraticBezierTo(
                a.x - dir * 22,
                a.y - 22 + math.sin(_animTime * 8.0) * 3.0,
                a.x - dir * 25,
                a.y - 16,
              );
        canvas.drawPath(
          tailPath,
          Paint()
            ..color = bodyColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0,
        );

        // Muscular body & head.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(a.x - 14, a.y - 18, 28, 12),
            const Radius.circular(6),
          ),
          Paint()..color = bodyColor,
        );
        canvas.drawCircle(
          Offset(a.x + dir * 13, a.y - 16),
          6.8,
          Paint()..color = bodyColor,
        );
        // Ears, glowing eye & rosette spots.
        canvas.drawCircle(
          Offset(a.x + dir * 11, a.y - 22),
          2.5,
          Paint()..color = const Color(0xFF3E2723),
        );
        canvas.drawCircle(
          Offset(a.x + dir * 15, a.y - 17),
          1.5,
          Paint()..color = const Color(0xFF76FF03),
        );
        for (final sx in const [-8.0, -2.0, 4.0]) {
          canvas.drawCircle(
            Offset(a.x + sx, a.y - 13),
            2.3,
            Paint()..color = const Color(0xFF3E2723),
          );
        }

      case AnimalType.snake:
        final snakeColor = flash ? Colors.redAccent : const Color(0xFF00E676);
        // Sinusoidal slithering segments.
        for (int seg = 0; seg < 5; seg++) {
          final sx = a.x - dir * (seg * 4.2) + dir * 6.0;
          final sy = a.y - 5.0 + math.sin(_animTime * 12.0 + seg * 0.9) * 2.2;
          canvas.drawCircle(
            Offset(sx, sy),
            4.5 - seg * 0.5,
            Paint()..color = snakeColor,
          );
        }
        // Raised head & flicking forked red tongue.
        final hx = a.x + dir * 9.0;
        final hy = a.y - 9.0;
        canvas.drawCircle(Offset(hx, hy), 4.8, Paint()..color = snakeColor);
        if ((_animTime * 6.0).floor().isEven) {
          canvas.drawLine(
            Offset(hx + dir * 4, hy),
            Offset(hx + dir * 9, hy - 1),
            Paint()
              ..color = Colors.redAccent
              ..strokeWidth = 1.2,
          );
        }

      case AnimalType.piranha:
        final fishColor = flash ? Colors.white : const Color(0xFF546E7A);
        canvas.drawOval(
          Rect.fromLTWH(a.x - 10, a.y - 11, 20, 12),
          Paint()..color = fishColor,
        );
        // Red belly & tail fin.
        canvas.drawArc(
          Rect.fromLTWH(a.x - 9, a.y - 9, 18, 9),
          0,
          math.pi,
          true,
          Paint()..color = const Color(0xFFE53935),
        );
        canvas.drawCircle(
          Offset(a.x + dir * 5, a.y - 6),
          1.6,
          Paint()..color = Colors.yellowAccent,
        );
    }

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
      worldState.playerX + (worldState.playerFacingRight ? 18 : -18),
      worldState.playerY - 22,
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

    // 1. Back Expedition Backpack & Bedroll (rendered behind torso).
    final packX = px - dir * 9.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(packX - 4.5, py - 25 + breath, 9, 13),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF5D4037),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(packX, py - 26.5 + breath),
        width: 9,
        height: 4.5,
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
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // 4. Front Leg & Laced Jungle Boot.
    _drawExplorerLeg(canvas, px + 2.5 + stride * 0.7, py, isFront: true);

    // 5. Detailed Safari Tunic / Woven Geometric Poncho + Utility Belt.
    final torsoRect = Rect.fromLTWH(px - 7.5, py - 25 + breath, 15, 15);
    final torsoColor =
        hurt
            ? Colors.redAccent
            : (worldState.hasWarmPoncho
                ? const Color(0xFFD84315)
                : const Color(0xFFA1887F));
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, const Radius.circular(4)),
      Paint()..color = torsoColor,
    );

    if (worldState.hasWarmPoncho && !hurt) {
      // Woven golden stripe & poncho trim.
      canvas.drawRect(
        Rect.fromLTWH(px - 7.5, py - 17 + breath, 15, 3),
        Paint()..color = const Color(0xFFFFCA28),
      );
    } else {
      // Leather belt & brass buckle + cross-body satchel strap.
      canvas.drawRect(
        Rect.fromLTWH(px - 7.5, py - 13.5 + breath, 15, 3),
        Paint()..color = const Color(0xFF3E2723),
      );
      canvas.drawRect(
        Rect.fromLTWH(px - 1.5 + dir * 2, py - 13.5 + breath, 3, 3),
        Paint()..color = const Color(0xFFFFD54F),
      );
    }

    // Red Explorer Neck Bandana / Scarf.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(px - 6, py - 26 + breath, 12, 3.2),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFC62828),
    );

    // 6. Detailed Head, Expressive Eyes (with periodic blink), & Explorer Pith Helmet.
    final headCenter = Offset(px, py - 31.5 + breath);
    canvas.drawCircle(
      headCenter,
      6.8,
      Paint()..color = const Color(0xFFFFCCBC),
    );
    // Ear & jawline shadow.
    canvas.drawCircle(
      Offset(px - dir * 4.5, py - 31.5 + breath),
      2.0,
      Paint()..color = const Color(0xFFE6A18C),
    );

    // Eye & Eyebrow (blinks briefly every 3.6 seconds).
    final isBlinking = (_animTime % 3.6) > 3.45;
    final eyeX = px + dir * 3.2;
    final eyeY = py - 32.0 + breath;
    if (isBlinking) {
      canvas.drawLine(
        Offset(eyeX - 1.5, eyeY),
        Offset(eyeX + 1.5, eyeY),
        Paint()
          ..color = const Color(0xFF3E2723)
          ..strokeWidth = 1.3,
      );
    } else {
      canvas.drawCircle(Offset(eyeX, eyeY), 1.9, Paint()..color = Colors.white);
      canvas.drawCircle(
        Offset(eyeX + dir * 0.5, eyeY),
        1.1,
        Paint()..color = const Color(0xFF212121),
      );
    }
    // Explorer Mustache / grin.
    canvas.drawLine(
      Offset(px + dir * 1.5, py - 28.5 + breath),
      Offset(px + dir * 5.0, py - 28.2 + breath),
      Paint()
        ..color = const Color(0xFF4E342E)
        ..strokeWidth = 1.6,
    );

    // 3D-Shaded Safari Pith Helmet (brim, dome, khaki band, and top button).
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(px, py - 34.5 + breath),
        width: 16.5,
        height: 11.5,
      ),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFFFBC02D),
    );
    // Helmet band.
    canvas.drawRect(
      Rect.fromLTWH(px - 7.5, py - 36.2 + breath, 15, 2.2),
      Paint()..color = const Color(0xFF6D4C41),
    );
    // Helmet wide sun brim.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(px + dir * 1.0, py - 34.5 + breath),
        width: 21.0,
        height: 4.8,
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
        ..strokeWidth = 3.8
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
    // Cargo shorts & lower leg.
    canvas.drawLine(
      Offset(worldState.playerX, footY - 11),
      Offset(footX, footY - 3),
      Paint()
        ..color = pantsColor
        ..strokeWidth = 4.4
        ..strokeCap = StrokeCap.round,
    );
    // Laced leather boot.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(footX - 3.0, footY - 4.0, 6.5, 4.2),
        const Radius.circular(1.5),
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
          Offset(dir * 10, -10),
          Paint()
            ..color = const Color(0xFF6D4C41)
            ..strokeWidth = 2.5,
        );
        final headColor =
            item == ItemType.stonePickaxe
                ? const Color(0xFFB0BEC5)
                : const Color(0xFF8D6E63);
        canvas.drawLine(
          Offset(dir * 6, -13),
          Offset(dir * 14, -7),
          Paint()
            ..color = headColor
            ..strokeWidth = 3.2,
        );
      case ItemType.woodSpear:
        canvas.drawLine(
          Offset(-dir * 4, 3),
          Offset(dir * 16, -9),
          Paint()
            ..color = const Color(0xFF6D4C41)
            ..strokeWidth = 2.4,
        );
        canvas.drawCircle(
          Offset(dir * 17, -9.5),
          2.8,
          Paint()..color = const Color(0xFFCFD8DC),
        );
      case ItemType.ironMachete:
        canvas.drawLine(
          Offset.zero,
          Offset(dir * 13, -8),
          Paint()
            ..color = const Color(0xFFECEFF1)
            ..strokeWidth = 3.5,
        );
      case ItemType.torchItem:
        canvas.drawLine(
          Offset.zero,
          Offset(dir * 6, -9),
          Paint()
            ..color = const Color(0xFF5D4037)
            ..strokeWidth = 2.6,
        );
        canvas.drawCircle(
          Offset(dir * 6, -11),
          4.0,
          Paint()..color = const Color(0xFFFFB300),
        );
      case ItemType.fishingRod:
        canvas.drawLine(
          Offset.zero,
          Offset(dir * 15, -12),
          Paint()
            ..color = const Color(0xFF8D6E63)
            ..strokeWidth = 2.0,
        );
      case ItemType.waterBucket:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(dir * 2, -2, 7, 7),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFF0288D1),
        );
      default:
        canvas.drawCircle(
          Offset(dir * 4, -2),
          3.5,
          Paint()..color = const Color(0xFFFFCA28),
        );
    }

    canvas.restore();
  }

  void _renderRainOverlay(Canvas canvas, double viewW, double viewH) {
    final rainPaint =
        Paint()
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
    final holdingTorch = worldState.equippedItem == ItemType.torchItem;
    final lightRadius =
        shelter.nearCampfire
            ? 195.0
            : ((shelter.nearTorch || holdingTorch) ? 155.0 : 105.0);

    final nightPaint =
        Paint()
          ..shader = Gradient.radial(playerScreen, lightRadius, [
            const Color(0x00000000),
            const Color(0xAA040814),
          ]);
    canvas.drawRect(Rect.fromLTWH(0, 0, viewW, viewH), nightPaint);
  }
}
