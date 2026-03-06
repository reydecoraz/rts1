import 'dart:math';
import 'package:flutter/material.dart';
import '../models/map_grid.dart';
import '../models/unit.dart';
import '../models/building.dart';
import '../models/tile.dart';
import '../utils/constants.dart';

class MinimapWidget extends StatelessWidget {
  final MapGrid grid;
  final List<Unit> units;
  final List<Building> buildings;
  final double mapPixelWidth;
  final double mapPixelHeight;
  final Matrix4 viewTransform;
  final Size screenSize;
  /// Called when user taps the minimap — returns the world tx, ty to center on
  final void Function(int tx, int ty)? onTap;

  const MinimapWidget({
    super.key,
    required this.grid,
    required this.units,
    required this.buildings,
    required this.mapPixelWidth,
    required this.mapPixelHeight,
    required this.viewTransform,
    required this.screenSize,
    this.onTap,
  });

  static const double _size = 140.0; // Reduced size as requested

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        if (onTap == null) return;
        
        final double unit = _size / (grid.width + grid.height);
        final double relX = details.localPosition.dx - _size / 2;
        final double relY = details.localPosition.dy;

        // Inversión de isometría:
        // RelX = (gx - gy) * unit
        // RelY = (gx + gy) * (unit / 2)
        // Entonces:
        // gx - gy = relX / unit
        // gx + gy = 2 * relY / unit
        
        final double gx = ((2 * relY / unit) + (relX / unit)) / 2;
        final double gy = ((2 * relY / unit) - (relX / unit)) / 2;

        final int tx = gx.round().clamp(0, grid.width - 1);
        final int ty = gy.round().clamp(0, grid.height - 1);
        onTap!(tx, ty);
      },
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: CustomPaint(
          size: const Size(_size, _size),
          painter: _MinimapPainter(
            grid: grid,
            units: units,
            buildings: buildings,
            viewTransform: viewTransform,
            screenSize: screenSize,
          ),
        ),
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  final MapGrid grid;
  final List<Unit> units;
  final List<Building> buildings;
  final Matrix4 viewTransform;
  final Size screenSize;

  _MinimapPainter({
    required this.grid,
    required this.units,
    required this.buildings,
    required this.viewTransform,
    required this.screenSize,
  });

  // Helpers isométricos para el minimapa
  double _mX(num gx, num gy, double width) {
    final double unit = width / (grid.width + grid.height);
    return (gx - gy) * unit + (width / 2);
  }

  double _mY(num gx, num gy, double width) {
    final double unit = width / (grid.width + grid.height);
    return (gx + gy) * (unit / 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    
    // Draw terrain
    final Paint terrainPaint = Paint();
    for (int x = 0; x < grid.width; x += 2) {
      for (int y = 0; y < grid.height; y += 2) {
        final tile = grid.getTile(x, y);
        if (!tile.isExplored) continue;
        
        terrainPaint.color = _tileColor(tile).withOpacity(0.6);
        canvas.drawCircle(Offset(_mX(x, y, w), _mY(x, y, w)), 1.2, terrainPaint);
      }
    }

    // Draw buildings
    for (final b in buildings) {
      if (!grid.getTile(b.x, b.y).isExplored) continue;
      final Paint bp = Paint()..color = b.playerColor;
      canvas.drawCircle(Offset(_mX(b.x, b.y, w), _mY(b.x, b.y, w)), 2.5, bp);
    }

    // Draw units
    for (final u in units) {
      if (u.state == UnitState.dead) continue;
      if (!grid.getTile(u.x.toInt(), u.y.toInt()).isVisible) continue;
      
      final Color uc = (u.playerId == 0) ? Colors.cyan : Colors.red;
      canvas.drawCircle(
        Offset(_mX(u.x, u.y, w), _mY(u.x, u.y, w)),
        2.0,
        Paint()..color = uc,
      );
    }

    _drawViewport(canvas, size);
  }

  void _drawViewport(Canvas canvas, Size size) {
    final double w = size.width;

    // Extract scale and translation from the InteractiveViewer transform.
    // viewTransform maps world → screen: screenPt = scale * worldPt + translation
    // So world = (screenPt - translation) / scale
    final double scale = viewTransform.getMaxScaleOnAxis();
    if (scale == 0) return;
    final double tx = viewTransform.entry(0, 3);
    final double ty = viewTransform.entry(1, 3);

    // The four screen corners mapped back to world pixel space
    Offset screenToWorld(Offset screen) {
      return Offset(
        (screen.dx - tx) / scale,
        (screen.dy - ty) / scale,
      );
    }

    // World pixel → isometric grid coords
    // worldOffsetX = half the total isometric width = (grid.width * tileW) / 2
    final double worldOffsetX = (grid.width * MapConstants.tileWidth) / 2;
    Point<double> worldPixToGrid(Offset p) {
      final double relX = p.dx - worldOffsetX;
      final double relY = p.dy;
      // Inverse isometric: gx = relY/tileH + relX/tileW, gy = relY/tileH - relX/tileW
      final double gx = (relY / (MapConstants.tileHeight / 2) + relX / (MapConstants.tileWidth / 2)) / 2;
      final double gy = (relY / (MapConstants.tileHeight / 2) - relX / (MapConstants.tileWidth / 2)) / 2;
      return Point(gx, gy);
    }

    final tl = worldPixToGrid(screenToWorld(Offset.zero));
    final tr = worldPixToGrid(screenToWorld(Offset(screenSize.width, 0)));
    final br = worldPixToGrid(screenToWorld(Offset(screenSize.width, screenSize.height)));
    final bl = worldPixToGrid(screenToWorld(Offset(0, screenSize.height)));

    final Path path = Path()
      ..moveTo(_mX(tl.x, tl.y, w), _mY(tl.x, tl.y, w))
      ..lineTo(_mX(tr.x, tr.y, w), _mY(tr.x, tr.y, w))
      ..lineTo(_mX(br.x, br.y, w), _mY(br.x, br.y, w))
      ..lineTo(_mX(bl.x, bl.y, w), _mY(bl.x, bl.y, w))
      ..close();

    canvas.drawPath(path, Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);

    // Draw a tiny cross at the exact center
    final center = worldPixToGrid(screenToWorld(Offset(screenSize.width / 2, screenSize.height / 2)));
    final cmx = _mX(center.x, center.y, w);
    final cmy = _mY(center.x, center.y, w);
    final crossPaint = Paint()..color = Colors.white..strokeWidth = 1.0..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cmx - 3, cmy), Offset(cmx + 3, cmy), crossPaint);
    canvas.drawLine(Offset(cmx, cmy - 3), Offset(cmx, cmy + 3), crossPaint);
  }


  Color _tileColor(Tile tile) {
    if (!tile.isWalkable) return const Color(0xff2a5a1a);
    if (tile.resource != null) return const Color(0xff4aaa2a);
    return const Color(0xff3a6a2a);
  }

  @override
  bool shouldRepaint(_MinimapPainter old) => true;
}

// No extra helpers needed — Vector3 from matrix translation is used directly.
