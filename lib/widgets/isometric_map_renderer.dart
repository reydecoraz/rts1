import 'dart:math';
import 'package:flutter/material.dart';
import '../models/map_grid.dart';
import '../models/biome_type.dart';
import '../models/resource_type.dart';
import '../models/building.dart';
import '../models/unit.dart';
import '../utils/constants.dart';

class IsometricMapPainter extends CustomPainter {
  final MapGrid grid;
  final int? hoveredTileX;
  final int? hoveredTileY;
  final Offset? selectionStart;
  final Offset? selectionEnd;
  final Building? selectedBuilding;
  final List<Unit> units;
  final List<Unit> selectedUnits;
  final List<Projectile> projectiles;
  final List<(int, int)> wallPreviewTiles;

  IsometricMapPainter({
    required this.grid,
    this.hoveredTileX,
    this.hoveredTileY,
    this.selectionStart,
    this.selectionEnd,
    this.selectedBuilding,
    required this.units,
    required this.selectedUnits,
    this.projectiles = const [],
    this.wallPreviewTiles = const [],
  });

  double _screenX(num gx, num gy) {
    final double offsetX = (grid.width * MapConstants.tileWidth) / 2;
    return (gx - gy) * (MapConstants.tileWidth / 2) + offsetX;
  }

  double _screenY(num gx, num gy) {
    return (gx + gy) * (MapConstants.tileHeight / 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (int x = 0; x < grid.width; x++) {
      for (int y = 0; y < grid.height; y++) {
        final tile = grid.getTile(x, y);
        final sx = _screenX(x, y);
        final sy = _screenY(x, y);
        final bool isHovered = x == hoveredTileX && y == hoveredTileY;

        // Niebla de Guerra
        if (!tile.isExplored) {
           _drawUnknownTile(canvas, sx, sy);
           continue; // No dibujar nada más encima de lo inexplorado (totalmente negro)
        }

        _drawTile(canvas, sx, sy, tile.biome, isHovered);

        if (!tile.isVisible) {
           // Capa gris encima para "explorado pero no visible" (Fog of War)
           _drawFogOverlay(canvas, sx, sy);
        }

        // Si está explorado, dibujamos recursos (estos no cambian)
        if (tile.resource != null) {
          _drawResource(canvas, sx, sy, tile.resource!.type);
        }
        
        // Solo dibujamos edificios si la zona es visible o si el edificio nos pertenece
        if (tile.building != null) {
          if (tile.isVisible || tile.building!.playerId == 0) {
              _drawBuilding(canvas, sx, sy, tile.building!);
              
              // Debug/Visual line for extraction
              if (tile.building!.targetExtractX != null && tile.building!.targetExtractY != null) {
                 final targetSx = _screenX(tile.building!.targetExtractX!, tile.building!.targetExtractY!);
                 final targetSy = _screenY(tile.building!.targetExtractX!, tile.building!.targetExtractY!);
                 
                 final paint = Paint()
                    ..color = Colors.lightBlueAccent.withOpacity(0.7)
                    ..strokeWidth = 2
                    ..style = PaintingStyle.stroke;

                 final double halfH = MapConstants.tileHeight / 2;
                 final Offset origin = Offset(sx, sy + halfH);
                 final Offset destination = Offset(targetSx, targetSy + halfH);

                 canvas.drawLine(origin, destination, paint);
                 canvas.drawCircle(destination, 4, Paint()..color = Colors.red..style = PaintingStyle.fill);
                 canvas.drawCircle(origin, 3, Paint()..color = Colors.green..style = PaintingStyle.fill);
              }
          }
        }
      }
    }

    // Dibujar previsualización de muros (ghosts)
    for (final (px, py) in wallPreviewTiles) {
      final sx = _screenX(px, py);
      final sy = _screenY(px, py);
      _drawWallPreview(canvas, sx, sy);
    }

    // Dibujar unidades
    for (var unit in units) {
      if (!grid.isValid(unit.x.toInt(), unit.y.toInt())) continue;
      final tile = grid.getTile(unit.x.toInt(), unit.y.toInt());
      
      // Si la unidad es del jugador 0 siempre se dibuja, si es enemiga, solo si el tile es visible.
      if (unit.playerId == 0 || tile.isVisible) {
         _drawUnit(canvas, unit);
      }
    }

    // Dibujar proyectiles (encima de unidades)
    for (final proj in projectiles) {
      _drawProjectile(canvas, proj);
    }

    // Dibujar línea de punto de reunión
    if (selectedBuilding != null && selectedBuilding!.rallyPointX != null && selectedBuilding!.rallyPointY != null) {
      _drawRallyPoint(canvas);
    }

    // Dibujar el overlay de selección si existe
    if (selectionStart != null && selectionEnd != null) {
      _drawSelectionOverlay(canvas);
    }
  }

  void _drawUnknownTile(Canvas canvas, double cx, double cy) {
    final path = Path()
      ..moveTo(cx, cy)
      ..lineTo(cx + MapConstants.tileWidth / 2, cy + MapConstants.tileHeight / 2)
      ..lineTo(cx, cy + MapConstants.tileHeight)
      ..lineTo(cx - MapConstants.tileWidth / 2, cy + MapConstants.tileHeight / 2)
      ..close();
    
    final paint = Paint()..color = Colors.black..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  void _drawFogOverlay(Canvas canvas, double cx, double cy) {
    final path = Path()
      ..moveTo(cx, cy)
      ..lineTo(cx + MapConstants.tileWidth / 2, cy + MapConstants.tileHeight / 2)
      ..lineTo(cx, cy + MapConstants.tileHeight)
      ..lineTo(cx - MapConstants.tileWidth / 2, cy + MapConstants.tileHeight / 2)
      ..close();
    
    final paint = Paint()..color = Colors.black.withOpacity(0.5)..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  // ─── Unit Icons ──────────────────────────────────────────────
  /// Infantry: Warrior with sword and shield
  void _drawWarrior(Canvas canvas, double sx, double sy, Color color, Color shadow) {
    final fill = Paint()..color = color..style = PaintingStyle.fill;
    final dark = Paint()..color = shadow..style = PaintingStyle.fill;
    final line = Paint()..color = shadow..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeCap = StrokeCap.round;

    // Shadow ellipse
    canvas.drawOval(Rect.fromCenter(center: Offset(sx, sy + 1), width: 14, height: 5), dark);
    // Body / torso
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(sx - 1, sy - 8), width: 7, height: 10), const Radius.circular(2)), fill);
    // Head with helmet
    canvas.drawCircle(Offset(sx - 1, sy - 16), 4, fill);
    final helmetPath = Path()
      ..moveTo(sx - 5, sy - 16)
      ..lineTo(sx - 5, sy - 19)
      ..lineTo(sx + 3, sy - 19)
      ..lineTo(sx + 3, sy - 14)
      ..lineTo(sx - 5, sy - 14)
      ..close();
    canvas.drawPath(helmetPath, dark);
    // Sword (right side)
    canvas.drawLine(Offset(sx + 4, sy - 5), Offset(sx + 4, sy - 20), Paint()..color = Colors.grey[300]!..strokeWidth = 1.5..style = PaintingStyle.stroke);
    canvas.drawLine(Offset(sx + 2, sy - 15), Offset(sx + 7, sy - 15), line); // crossguard
    // Shield (left side)
    final shieldPath = Path()
      ..moveTo(sx - 7, sy - 13)
      ..lineTo(sx - 7, sy - 5)
      ..lineTo(sx - 4, sy - 2)
      ..lineTo(sx - 4, sy - 13)
      ..close();
    canvas.drawPath(shieldPath, dark);
    canvas.drawPath(shieldPath, line..style = PaintingStyle.stroke);
    // Legs
    canvas.drawLine(Offset(sx - 2, sy - 3), Offset(sx - 2, sy + 3), line);
    canvas.drawLine(Offset(sx + 0, sy - 3), Offset(sx + 0, sy + 3), line);
  }

  /// Ranged: Archer with bow raised
  void _drawArcher(Canvas canvas, double sx, double sy, Color color, Color shadow) {
    final fill = Paint()..color = color..style = PaintingStyle.fill;
    final dark = Paint()..color = shadow..style = PaintingStyle.fill;
    final line = Paint()..color = shadow..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeCap = StrokeCap.round;

    canvas.drawOval(Rect.fromCenter(center: Offset(sx, sy + 1), width: 12, height: 4), dark);
    // Body
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(sx, sy - 8), width: 6, height: 9), const Radius.circular(2)), fill);
    // Hood/head
    final hoodPath = Path()
      ..moveTo(sx, sy - 21)
      ..lineTo(sx - 4, sy - 15)
      ..lineTo(sx + 4, sy - 15)
      ..close();
    canvas.drawPath(hoodPath, dark);
    canvas.drawCircle(Offset(sx, sy - 16), 3.5, fill);
    // Bow (curved arc on the left)
    final bowPaint = Paint()..color = Colors.brown[400]!..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round;
    final bowPath = Path();
    bowPath.moveTo(sx - 6, sy - 18);
    bowPath.quadraticBezierTo(sx - 12, sy - 10, sx - 6, sy - 2);
    canvas.drawPath(bowPath, bowPaint);
    // Bow string
    canvas.drawLine(Offset(sx - 6, sy - 18), Offset(sx - 6, sy - 2), Paint()..color = Colors.white60..strokeWidth = 0.8..style = PaintingStyle.stroke);
    // Arrow nocked
    canvas.drawLine(Offset(sx - 5, sy - 10), Offset(sx + 5, sy - 12),
        Paint()..color = Colors.amber[200]!..strokeWidth = 1.2..style = PaintingStyle.stroke);
    // Legs
    canvas.drawLine(Offset(sx - 1, sy - 3), Offset(sx - 1, sy + 3), line);
    canvas.drawLine(Offset(sx + 1, sy - 3), Offset(sx + 1, sy + 3), line);
  }

  /// Cavalry: Knight on horseback
  void _drawCavalry(Canvas canvas, double sx, double sy, Color color, Color shadow) {
    final fill = Paint()..color = color..style = PaintingStyle.fill;
    final dark = Paint()..color = shadow..style = PaintingStyle.fill;
    final brown = Paint()..color = const Color(0xFF8B5E3C)..style = PaintingStyle.fill;
    final outline = Paint()..color = shadow..style = PaintingStyle.stroke..strokeWidth = 1.0;

    // Horse body
    final horsePath = Path()
      ..moveTo(sx - 8, sy - 2)
      ..quadraticBezierTo(sx, sy - 8, sx + 8, sy - 4)
      ..lineTo(sx + 8, sy + 2)
      ..lineTo(sx - 8, sy + 2)
      ..close();
    canvas.drawPath(horsePath, brown);
    canvas.drawPath(horsePath, outline);
    // Horse head & neck
    final neckPath = Path()
      ..moveTo(sx + 4, sy - 4)
      ..quadraticBezierTo(sx + 10, sy - 12, sx + 6, sy - 18)
      ..lineTo(sx + 10, sy - 18)
      ..lineTo(sx + 14, sy - 10)
      ..lineTo(sx + 8, sy - 2)
      ..close();
    canvas.drawPath(neckPath, brown);
    // Legs
    canvas.drawLine(Offset(sx - 6, sy + 2), Offset(sx - 5, sy + 8), outline);
    canvas.drawLine(Offset(sx - 2, sy + 2), Offset(sx - 1, sy + 8), outline);
    canvas.drawLine(Offset(sx + 2, sy + 2), Offset(sx + 3, sy + 8), outline);
    canvas.drawLine(Offset(sx + 6, sy + 2), Offset(sx + 7, sy + 8), outline);
    // Rider body
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(sx, sy - 12), width: 7, height: 8), const Radius.circular(2)), fill);
    // Rider head with plumed helm
    canvas.drawCircle(Offset(sx, sy - 18), 3.5, fill);
    final plumePath = Path()
      ..moveTo(sx, sy - 21)
      ..lineTo(sx - 2, sy - 26)
      ..lineTo(sx + 2, sy - 24)
      ..lineTo(sx + 1, sy - 21)
      ..close();
    canvas.drawPath(plumePath, Paint()..color = Colors.red[400]!..style = PaintingStyle.fill);
    // Lance
    canvas.drawLine(Offset(sx + 2, sy - 18), Offset(sx + 14, sy - 26),
        Paint()..color = Colors.brown[200]!..strokeWidth = 1.5..style = PaintingStyle.stroke);
    canvas.drawCircle(Offset(sx + 14, sy - 26), 2, dark); // lance tip
    // Shadow
    canvas.drawOval(Rect.fromCenter(center: Offset(sx, sy + 9), width: 20, height: 6), dark);
  }

  /// Siege: Cannon on wheels
  void _drawCannon(Canvas canvas, double sx, double sy, Color color, Color shadow) {
    final dark = Paint()..color = shadow..style = PaintingStyle.fill;
    final metal = Paint()..color = Colors.grey[600]!..style = PaintingStyle.fill;
    final woodColor = const Color(0xFF6B3C1A);
    final wood = Paint()..color = woodColor..style = PaintingStyle.fill;
    final outline = Paint()..color = Colors.black54..style = PaintingStyle.stroke..strokeWidth = 0.8;

    // Shadow
    canvas.drawOval(Rect.fromCenter(center: Offset(sx, sy + 4), width: 24, height: 6), dark);

    // Wheels (two circles)
    canvas.drawCircle(Offset(sx - 8, sy + 2), 5, wood);
    canvas.drawCircle(Offset(sx - 8, sy + 2), 5, outline);
    canvas.drawLine(Offset(sx - 8, sy - 3), Offset(sx - 8, sy + 7), outline); // spokes
    canvas.drawLine(Offset(sx - 13, sy + 2), Offset(sx - 3, sy + 2), outline);
    canvas.drawCircle(Offset(sx + 8, sy + 2), 5, wood);
    canvas.drawCircle(Offset(sx + 8, sy + 2), 5, outline);
    canvas.drawLine(Offset(sx + 8, sy - 3), Offset(sx + 8, sy + 7), outline);
    canvas.drawLine(Offset(sx + 3, sy + 2), Offset(sx + 13, sy + 2), outline);

    // Carriage / axle
    canvas.drawRect(Rect.fromCenter(center: Offset(sx, sy + 2), width: 18, height: 4), wood);

    // Cannon barrel
    final barrelPath = Path()
      ..moveTo(sx - 3, sy - 3)
      ..lineTo(sx - 2, sy - 14)
      ..lineTo(sx + 2, sy - 14)
      ..lineTo(sx + 3, sy - 3)
      ..close();
    canvas.drawPath(barrelPath, metal);
    canvas.drawPath(barrelPath, outline);
    // Barrel ring bands
    canvas.drawLine(Offset(sx - 3, sy - 6), Offset(sx + 3, sy - 6), outline);
    canvas.drawLine(Offset(sx - 2.5, sy - 10), Offset(sx + 2.5, sy - 10), outline);
    // Muzzle opening
    canvas.drawOval(Rect.fromCenter(center: Offset(sx, sy - 14), width: 5, height: 3), dark);
    // Cannonball beside
    canvas.drawCircle(Offset(sx - 7, sy - 6), 2.5, metal);
  }

  void _drawProjectile(Canvas canvas, Projectile proj) {
    final double sx = _screenX(proj.x, proj.y);
    final double sy = _screenY(proj.x, proj.y) + MapConstants.tileHeight / 2;

    if (proj.type == ProjectileType.arrow) {
      // Draw a short arrow line in the direction of travel
      final double destSx = _screenX(proj.targetX, proj.targetY);
      final double destSy = _screenY(proj.targetX, proj.targetY) + MapConstants.tileHeight / 2;

      final double dx = destSx - sx;
      final double dy = destSy - sy;
      final double len = sqrt(dx * dx + dy * dy);
      if (len < 1) return;

      // Arrow shaft: a short line in direction of travel
      const double shaftLen = 9.0;
      final double nx = dx / len;
      final double ny = dy / len;

      final Offset tip = Offset(sx, sy);
      final Offset tail = Offset(sx - nx * shaftLen, sy - ny * shaftLen);

      final arrowPaint = Paint()
        ..color = const Color(0xFFFFEE88)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(tail, tip, arrowPaint);

      // Arrowhead
      final double angle = atan2(dy, dx);
      const double headLen = 5.0;
      canvas.drawLine(
        tip,
        Offset(sx - headLen * cos(angle - pi / 5), sy - headLen * sin(angle - pi / 5)),
        arrowPaint,
      );
      canvas.drawLine(
        tip,
        Offset(sx - headLen * cos(angle + pi / 5), sy - headLen * sin(angle + pi / 5)),
        arrowPaint,
      );
    } else {
      // Cannonball: dark sphere with a glowing core
      const double r = 3.5;

      // Shadow
      canvas.drawCircle(
        Offset(sx + 2, sy + 2),
        r,
        Paint()..color = Colors.black38,
      );

      // Ball body
      final ballPaint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.grey[300]!, Colors.grey[700]!],
          center: const Alignment(-0.4, -0.4),
        ).createShader(Rect.fromCircle(center: Offset(sx, sy), radius: r));
      canvas.drawCircle(Offset(sx, sy), r, ballPaint);

      // Subtle smoke trail
      final trailPaint = Paint()
        ..color = Colors.white.withOpacity(0.20)
        ..style = PaintingStyle.fill;
      final double destSx2 = _screenX(proj.targetX, proj.targetY);
      final double destSy2 = _screenY(proj.targetX, proj.targetY) + MapConstants.tileHeight / 2;
      final double dx2 = sx - destSx2;
      final double dy2 = sy - destSy2;
      final double len2 = sqrt(dx2 * dx2 + dy2 * dy2);
      if (len2 > 1) {
        final double nx2 = dx2 / len2;
        final double ny2 = dy2 / len2;
        for (int i = 1; i <= 3; i++) {
          canvas.drawCircle(
            Offset(sx + nx2 * i * 3, sy + ny2 * i * 3),
            r - i * 0.7,
            Paint()..color = Colors.white.withOpacity(0.10 / i),
          );
        }
      }
    }
  }


  // ─── Dispatch ──────────────────────────────────────────
  void _drawUnit(Canvas canvas, Unit unit) {
    final double bob = (unit.state == UnitState.moving) 
        ? sin(unit.visualTime * 12) * 2.0 
        : 0.0;
        
    final sx = _screenX(unit.x, unit.y);
    final sy = _screenY(unit.x, unit.y) + MapConstants.tileHeight / 2.5 + bob;

    final isSelected = selectedUnits.contains(unit);
    if (isSelected) {
      canvas.drawCircle(Offset(sx, sy + 5), 10, Paint()..color = Colors.greenAccent..style = PaintingStyle.stroke..strokeWidth = 2);
    }

    final List<Color> palette = [
      Colors.blue[600]!,   // Player 0
      Colors.red[600]!,    // Player 1
      Colors.green[600]!,  // Player 2
      Colors.purple[600]!, // Player 3
      Colors.orange[600]!, // Player 4
      Colors.teal[600]!,   // Player 5
      Colors.yellow[600]!, // Player 6
      Colors.pink[600]!,   // Player 7
    ];
    
    final Color playerColor = palette[unit.playerId % palette.length];
    final Color shadowColor = playerColor.withOpacity(0.8);

    switch (unit.category) {
      case UnitCategory.ranged:
        _drawArcher(canvas, sx, sy, playerColor, shadowColor);
        break;
      case UnitCategory.cavalry:
        _drawCavalry(canvas, sx, sy, playerColor, shadowColor);
        break;
      case UnitCategory.siege:
        _drawCannon(canvas, sx, sy, playerColor, shadowColor);
        break;
      default:
        _drawWarrior(canvas, sx, sy, playerColor, shadowColor);
    }

    // Barra de vida (siempre visible)
    double healthRatio = (unit.currentHealth / unit.currentStats.maxHealth).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(sx - 8, sy - 28, 16, 3), Paint()..color = Colors.red);
    canvas.drawRect(Rect.fromLTWH(sx - 8, sy - 28, 16 * healthRatio, 3), Paint()..color = Colors.green);
  }

  void _drawRallyPoint(Canvas canvas) {
    if (selectedBuilding == null) return;
    int? bx, by;
    for (int x = 0; x < grid.width; x++) {
      for (int y = 0; y < grid.height; y++) {
        if (grid.getTile(x, y).building == selectedBuilding) {
          bx = x;
          by = y;
          break;
        }
      }
      if (bx != null) break;
    }
    
    if (bx == null || by == null) return;

    final double startX = _screenX(bx, by);
    final double startY = _screenY(bx, by) + (MapConstants.tileHeight / 2);

    final double targetX = _screenX(selectedBuilding!.rallyPointX!, selectedBuilding!.rallyPointY!);
    final double targetY = _screenY(selectedBuilding!.rallyPointX!, selectedBuilding!.rallyPointY!) + (MapConstants.tileHeight / 2);

    final linePaint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw dotted line
    _drawDashedLine(canvas, Offset(startX, startY), Offset(targetX, targetY), linePaint);
    
    // Draw rally point flag/marker
    final circlePaint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    
    final borderPaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
      
    final origin = Offset(targetX, targetY);
    canvas.drawCircle(origin, 8, circlePaint);
    canvas.drawCircle(origin, 8, borderPaint);
    
    // Cruz interior
    canvas.drawLine(Offset(targetX - 4, targetY - 4), Offset(targetX + 4, targetY + 4), borderPaint);
    canvas.drawLine(Offset(targetX + 4, targetY - 4), Offset(targetX - 4, targetY + 4), borderPaint);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    var max = (p2 - p1).distance;
    var dashWidth = 5.0;
    var dashSpace = 5.0;
    double startY = 0.0;
    
    // normalized vector
    var dx = (p2.dx - p1.dx) / max;
    var dy = (p2.dy - p1.dy) / max;
    
    while (startY < max) {
      var drawWidth = dashWidth;
      if (startY + drawWidth > max) drawWidth = max - startY;
      canvas.drawLine(
        Offset(p1.dx + dx * startY, p1.dy + dy * startY),
        Offset(p1.dx + dx * (startY + drawWidth), p1.dy + dy * (startY + drawWidth)),
        paint
      );
      startY += dashWidth + dashSpace;
    }
  }

  void _drawSelectionOverlay(Canvas canvas) {
    // Rectángulo libre en pixel-space (no tile-snapped)
    final Rect rect = Rect.fromPoints(selectionStart!, selectionEnd!);

    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.greenAccent.withOpacity(0.2)
        ..style = PaintingStyle.fill,
    );

    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawTile(Canvas canvas, double cx, double cy, BiomeType biome, bool isHovered) {
    final paint = Paint()..style = PaintingStyle.fill;

    switch (biome) {
      case BiomeType.grass:
        paint.color = Colors.green[600]!;
        break;
      case BiomeType.desert:
        paint.color = Colors.orange[200]!;
        break;
      case BiomeType.water:
        paint.color = Colors.blue[600]!;
        break;
      case BiomeType.snow:
        paint.color = Colors.white;
        break;
      case BiomeType.mountain:
        paint.color = Colors.grey[700]!;
        break;
    }

    final path = _tilePath(cx, cy);
    canvas.drawPath(path, paint);

    // Borde sutil
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black12
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    // Highlight de preview
    if (isHovered) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.cyanAccent.withOpacity(0.35)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.cyanAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  Path _tilePath(double cx, double cy) {
    final path = Path();
    path.moveTo(cx, cy);
    path.lineTo(cx + MapConstants.tileWidth / 2, cy + MapConstants.tileHeight / 2);
    path.lineTo(cx, cy + MapConstants.tileHeight);
    path.lineTo(cx - MapConstants.tileWidth / 2, cy + MapConstants.tileHeight / 2);
    path.close();
    return path;
  }

  void _drawResource(Canvas canvas, double cx, double cy, ResourceType type) {
    if (type == ResourceType.none) return;

    final double ty = cy + MapConstants.tileHeight / 2;

    if (type == ResourceType.wood || type == ResourceType.food) {
      // Dibujar un pino simple
      final paintTrunk = Paint()..color = Colors.brown[700]!..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromCenter(center: Offset(cx, ty - 4), width: 4, height: 8), paintTrunk);

      final paintLeaves = Paint()
        ..color = type == ResourceType.wood ? Colors.green[800]! : Colors.lightGreen[400]!
        ..style = PaintingStyle.fill;
      
      final path1 = Path()
        ..moveTo(cx, ty - 24)
        ..lineTo(cx + 8, ty - 10)
        ..lineTo(cx - 8, ty - 10)
        ..close();
      canvas.drawPath(path1, paintLeaves);

      final path2 = Path()
        ..moveTo(cx, ty - 18)
        ..lineTo(cx + 10, ty - 4)
        ..lineTo(cx - 10, ty - 4)
        ..close();
      canvas.drawPath(path2, paintLeaves);
    } else {
      // Dibujar minas/rocas
      final paintRock = Paint()..style = PaintingStyle.fill;
      switch (type) {
        case ResourceType.gold:
          paintRock.color = Colors.amber[700]!;
          break;
        case ResourceType.stone:
          paintRock.color = Colors.grey[600]!;
          break;
        case ResourceType.coal:
          paintRock.color = Colors.black87;
          break;
        default:
          paintRock.color = Colors.grey;
      }

      final rockPath = Path()
        ..moveTo(cx - 6, ty)
        ..lineTo(cx - 8, ty - 6)
        ..lineTo(cx - 2, ty - 12)
        ..lineTo(cx + 4, ty - 10)
        ..lineTo(cx + 8, ty - 4)
        ..lineTo(cx + 6, ty)
        ..close();
      
      canvas.drawPath(rockPath, paintRock);
      
      // Sombra/Brillo para darle volumen a la roca
      final highlightPaint = Paint()..color = Colors.white.withOpacity(0.2)..style = PaintingStyle.fill;
      final highlightPath = Path()
        ..moveTo(cx - 2, ty - 12)
        ..lineTo(cx + 4, ty - 10)
        ..lineTo(cx, ty - 6)
        ..close();
      canvas.drawPath(highlightPath, highlightPaint);
    }
  }

  void _drawWallPreview(Canvas canvas, double sx, double sy) {
    final double w = MapConstants.tileWidth;
    final double h = MapConstants.tileHeight;
    final path = Path()
      ..moveTo(sx, sy)
      ..lineTo(sx + w / 2, sy + h / 2)
      ..lineTo(sx, sy + h)
      ..lineTo(sx - w / 2, sy + h / 2)
      ..close();

    final paint = Paint()
      ..color = Colors.yellowAccent.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = Colors.yellowAccent.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);

    // Texto de "Muro" arriba
    final textPainter = TextPainter(
      text: const TextSpan(
        text: "Muro",
        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(sx - textPainter.width / 2, sy + h / 4));
  }

  void _drawBuilding(Canvas canvas, double cx, double cy, Building building) {
    final bool underConstruction = building.isUnderConstruction;
    final Color baseColor = underConstruction
        ? building.playerColor.withOpacity(0.45)
        : building.playerColor;

    final bool isWall = building.name == "Muro";

    if (isWall) {
      _drawWall(canvas, cx, cy, baseColor, underConstruction);
    } else {
      _drawCube(canvas, cx, cy, baseColor, building);
    }

    // Barra de construcción si está siendo construido
    if (underConstruction) {
      _drawConstructionBar(canvas, cx, cy, building);
    } else {
      _drawHpBar(canvas, cx, cy, building);
    }

    // Building name label floating above the building
    if (!isWall) {
      final abbr = _buildingAbbrev(building.name);
      final style = TextStyle(
        color: Colors.white,
        fontSize: 7,
        fontWeight: FontWeight.w600,
        shadows: [Shadow(color: Colors.black, blurRadius: 2)],
      );
      final tp = TextPainter(
        text: TextSpan(text: abbr, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final double labelY = cy - 14;
      tp.paint(canvas, Offset(cx - tp.width / 2, labelY));
    }
  }

  String _buildingAbbrev(String name) {
    const map = {
      'Centro Urbano': '🏛 Centro',
      'Cuartel': '⚔ Cuartel',
      'Establo': '🐴 Establo',
      'Taller de Asedio': '💣 Asedio',
      'Granja': '🌾 Granja',
      'Aserradero': '🪵 Aserradero',
      'Mina': '⛏ Mina',
      'Muro': 'Muro',
      'Torre': '🗼 Torre',
      'Torre de Arqueros': '🏹 Torre',
      'Herrería': '🔨 Herrería',
    };
    return map[name] ?? name;
  }


  void _drawCube(Canvas canvas, double cx, double cy, Color color, Building building) {
    final double maxH = 20.0;
    final double h = building.isUnderConstruction
        ? maxH * building.constructionProgress.clamp(0.1, 1.0)
        : maxH;
        
    final double w = MapConstants.tileWidth / 3;
    final double ty = cy + MapConstants.tileHeight / 2;

    // Techo
    final topPaint = Paint()..color = color..style = PaintingStyle.fill;
    final topPath = Path();
    topPath.moveTo(cx, ty - h);
    topPath.lineTo(cx + w, ty + MapConstants.tileHeight / 4 - h);
    topPath.lineTo(cx, ty + MapConstants.tileHeight / 2 - h);
    topPath.lineTo(cx - w, ty + MapConstants.tileHeight / 4 - h);
    topPath.close();
    canvas.drawPath(topPath, topPaint);

    // Cara izquierda
    final leftPaint = Paint()..color = color.withOpacity(0.75)..style = PaintingStyle.fill;
    final leftPath = Path();
    leftPath.moveTo(cx - w, ty + MapConstants.tileHeight / 4 - h);
    leftPath.lineTo(cx, ty + MapConstants.tileHeight / 2 - h);
    leftPath.lineTo(cx, ty + MapConstants.tileHeight / 2);
    leftPath.lineTo(cx - w, ty + MapConstants.tileHeight / 4);
    leftPath.close();
    canvas.drawPath(leftPath, leftPaint);

    // Cara derecha
    final rightPaint = Paint()..color = color.withOpacity(0.55)..style = PaintingStyle.fill;
    final rightPath = Path();
    rightPath.moveTo(cx + w, ty + MapConstants.tileHeight / 4 - h);
    rightPath.lineTo(cx, ty + MapConstants.tileHeight / 2 - h);
    rightPath.lineTo(cx, ty + MapConstants.tileHeight / 2);
    rightPath.lineTo(cx + w, ty + MapConstants.tileHeight / 4);
    rightPath.close();
    canvas.drawPath(rightPath, rightPaint);
    
    // Si está en construcción, dibujar andamios básicos (líneas)
    if (building.isUnderConstruction) {
      final scaffoldPaint = Paint()
        ..color = Colors.brown[400]!
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(cx - w, ty + MapConstants.tileHeight / 4), Offset(cx - w, ty + MapConstants.tileHeight / 4 - maxH), scaffoldPaint);
      canvas.drawLine(Offset(cx + w, ty + MapConstants.tileHeight / 4), Offset(cx + w, ty + MapConstants.tileHeight / 4 - maxH), scaffoldPaint);
      canvas.drawLine(Offset(cx, ty + MapConstants.tileHeight / 2), Offset(cx, ty + MapConstants.tileHeight / 2 - maxH), scaffoldPaint);
    }
  }

  void _drawWall(Canvas canvas, double cx, double cy, Color color, bool underConstruction) {
    // Muro: cubo más bajo y ancho
    final double h = 10.0;
    final double w = MapConstants.tileWidth / 2.2;
    final double ty = cy + MapConstants.tileHeight / 2;

    final topPaint = Paint()..color = color..style = PaintingStyle.fill;
    final topPath = Path();
    topPath.moveTo(cx, ty - h);
    topPath.lineTo(cx + w, ty + MapConstants.tileHeight / 4 - h);
    topPath.lineTo(cx, ty + MapConstants.tileHeight / 2 - h);
    topPath.lineTo(cx - w, ty + MapConstants.tileHeight / 4 - h);
    topPath.close();
    canvas.drawPath(topPath, topPaint);

    final sidePaint = Paint()..color = color.withOpacity(0.6)..style = PaintingStyle.fill;
    final leftPath = Path();
    leftPath.moveTo(cx - w, ty + MapConstants.tileHeight / 4 - h);
    leftPath.lineTo(cx, ty + MapConstants.tileHeight / 2 - h);
    leftPath.lineTo(cx, ty + MapConstants.tileHeight / 2);
    leftPath.lineTo(cx - w, ty + MapConstants.tileHeight / 4);
    leftPath.close();
    canvas.drawPath(leftPath, sidePaint);

    final rightPath = Path();
    rightPath.moveTo(cx + w, ty + MapConstants.tileHeight / 4 - h);
    rightPath.lineTo(cx, ty + MapConstants.tileHeight / 2 - h);
    rightPath.lineTo(cx, ty + MapConstants.tileHeight / 2);
    rightPath.lineTo(cx + w, ty + MapConstants.tileHeight / 4);
    rightPath.close();
    canvas.drawPath(rightPath, sidePaint);
  }

  void _drawConstructionBar(Canvas canvas, double cx, double cy, Building building) {
    final double w = MapConstants.tileWidth * 0.6;
    final double barY = cy + 2;
    final double barH = 4.0;

    canvas.drawRect(
      Rect.fromLTWH(cx - w / 2, barY, w, barH),
      Paint()..color = Colors.black54,
    );
    canvas.drawRect(
      Rect.fromLTWH(cx - w / 2, barY, w * building.constructionProgress, barH),
      Paint()..color = Colors.amberAccent,
    );
  }

  void _drawHpBar(Canvas canvas, double cx, double cy, Building building) {
    final double w = MapConstants.tileWidth * 0.5;
    final double barY = cy + 2;
    final double barH = 3.0;
    final double hpRatio = (building.health / building.maxHealth).clamp(0.0, 1.0);

    canvas.drawRect(
      Rect.fromLTWH(cx - w / 2, barY, w, barH),
      Paint()..color = Colors.black54,
    );
    canvas.drawRect(
      Rect.fromLTWH(cx - w / 2, barY, w * hpRatio, barH),
      Paint()..color = Colors.green,
    );
  }

  @override
  bool shouldRepaint(covariant IsometricMapPainter oldDelegate) =>
      oldDelegate.grid != grid ||
      oldDelegate.hoveredTileX != hoveredTileX ||
      oldDelegate.hoveredTileY != hoveredTileY ||
      oldDelegate.selectionStart != selectionStart ||
      oldDelegate.selectionEnd != selectionEnd;
}
