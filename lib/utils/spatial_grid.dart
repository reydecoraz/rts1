import '../models/unit.dart';

class SpatialGrid {
  final double cellSize;
  final Map<String, List<Unit>> cells = {};

  SpatialGrid({this.cellSize = 2.0});

  void clear() {
    cells.clear();
  }

  String _getHash(double x, double y) {
    int ix = (x / cellSize).floor();
    int iy = (y / cellSize).floor();
    return "${ix}_${iy}";
  }

  void add(Unit unit) {
    if (unit.state == UnitState.dead) return;
    String hash = _getHash(unit.x, unit.y);
    cells.putIfAbsent(hash, () => []).add(unit);
  }

  List<Unit> getNearby(double x, double y, double radius) {
    List<Unit> nearby = [];
    int minX = ((x - radius) / cellSize).floor();
    int maxX = ((x + radius) / cellSize).floor();
    int minY = ((y - radius) / cellSize).floor();
    int maxY = ((y + radius) / cellSize).floor();

    for (int ix = minX; ix <= maxX; ix++) {
      for (int iy = minY; iy <= maxY; iy++) {
        String hash = "${ix}_${iy}";
        final cell = cells[hash];
        if (cell != null) {
          nearby.addAll(cell);
        }
      }
    }
    return nearby;
  }
}
