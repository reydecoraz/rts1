import 'unit.dart';

/// Represents a saved group of units that the player named via drag-select.
class UnitGroup {
  final int id;
  String name;
  final List<Unit> units; // live references to Unit objects

  UnitGroup({required this.id, required this.name, required this.units});

  /// Returns only units that are still alive.
  List<Unit> get aliveUnits => units.where((u) => u.state != UnitState.dead).toList();

  bool get isEmpty => aliveUnits.isEmpty;

  /// Removes units from this group (e.g. they joined another group).
  void removeUnits(List<Unit> unitsToRemove) {
    units.removeWhere((u) => unitsToRemove.contains(u));
  }

  /// Counts units by typeId category
  Map<String, int> get composition {
    final map = <String, int>{};
    for (final u in aliveUnits) {
      map[u.typeId] = (map[u.typeId] ?? 0) + 1;
    }
    return map;
  }
}
