import 'dart:math';
import 'package:flutter/material.dart';
import '../models/resource_type.dart';
import '../models/building.dart';
import '../models/unit.dart';
import '../models/map_grid.dart';
import '../data/building_data.dart';
import '../data/unit_data.dart';

/// AI phases / priorities
/// AI priorities that can run in parallel
enum AiGoal {
  economy,    // Build houses / resources
  military,   // Build barracks / stables
  training,   // Produce units
  offense     // Attack enemy
}

class AiController {
  final int playerId;
  final Color playerColor;
  final Random _rng = Random();
  bool isDefeated = false;

  // Timers / cooldowns
  double _phaseCooldown = 3.0; // seconds before the AI makes its next action
  double _attackCooldown = 0.0;
  double _elapsedGameTime = 0.0; // tracks total seconds elapsed

  // References injected each tick by GameScreen
  List<Building> buildings = [];
  List<Building> allBuildings = [];
  List<Unit> units = [];
  MapGrid? grid;

  // Economy
  int wood = 1000;
  int food = 800;
  int gold = 500;
  int stone = 500;
  int coal = 300;
  int maxPopulation = 10;

  void addResources(ResourceType type, int amount) {
    if (amount <= 0) return;
    switch (type) {
      case ResourceType.wood: wood += amount; break;
      case ResourceType.food: food += amount; break;
      case ResourceType.gold: gold += amount; break;
      case ResourceType.stone: stone += amount; break;
      case ResourceType.coal: coal += amount; break;
      case ResourceType.none: break;
    }
  }

  bool canAfford({int w = 0, int f = 0, int g = 0, int s = 0, int c = 0}) {
    return wood >= w && food >= f && gold >= g && stone >= s && coal >= c;
  }

  void spendResources({int w = 0, int f = 0, int g = 0, int s = 0, int c = 0}) {
    wood -= w;
    food -= f;
    gold -= g;
    stone -= s;
    coal -= c;
  }

  // Callback to spawn a building on the map
  final void Function(BuildingTypeData data, int tx, int ty) onPlaceBuilding;

  // Callback to queue a unit inside a building
  final void Function(Building barracks, String unitId) onQueueUnit;

  // Callback to assign a move order to a list of units
  final void Function(List<Unit> army, double tx, double ty) onMoveUnits;

  // Optional: target player ID being attacked (usually 0)
  final int targetPlayerId;

  AiController({
    required this.playerId,
    required this.playerColor,
    required this.onPlaceBuilding,
    required this.onQueueUnit,
    required this.onMoveUnits,
    this.targetPlayerId = 0,
  });

  // ─── Public API ──────────────────────────────────────
  /// Called every game tick from GameScreen.
  void tick(double dt, List<Building> allBuildings, List<Unit> allUnits, MapGrid mapGrid) {
    if (isDefeated) return;
    grid = mapGrid;
 
    // Filter to only our buildings and units
    this.allBuildings = allBuildings;
    buildings = allBuildings.where((b) => b.playerId == playerId).toList();
    units = allUnits.where((u) => u.playerId == playerId).toList();
 
    _phaseCooldown -= dt;
    _attackCooldown -= dt;
    _elapsedGameTime += dt;

    if (_phaseCooldown <= 0) {
      _runLogic();
      // Reset with some jitter
      _phaseCooldown = 2.0 + _rng.nextDouble() * 2.0;
    }
  }

  void _runLogic() {
    _maintainPopulation();
    _maintainMilitaryInfrastructure();
    _produceArmy();
    _manageGathering();
    
    // Grace period of 2 minutes (120 seconds) before attacking
    if (_elapsedGameTime > 120.0) {
      if (_attackCooldown <= 0 && units.length >= 8) {
        _sendAttackWave();
        _attackCooldown = 20.0; // Wave every 20s
      }
    }
  }

  // ─── Phase Management ─────────────────────────────────
  // ─── Brain Modules ──────────────────────────────────
  
  void _maintainPopulation() {
    int currentPop = units.length;
    // Add units currently in training and workers
    for (var b in buildings) {
      currentPop += b.productionQueue.length;
      currentPop += b.currentWorkers;
    }

    if (currentPop >= maxPopulation - 2 && maxPopulation < 100) {
      _tryBuildBuilding('Casa', maxCount: 15);
    }
  }

  void _maintainMilitaryInfrastructure() {
    final barracksCount = buildings.where((b) => b.name == 'Cuartel').length;
    if (barracksCount < 1) {
      _tryBuildBuilding('Cuartel');
    } else if (barracksCount < 3 && units.length > 10) {
      _tryBuildBuilding('Cuartel');
    }
  }

  void _produceArmy() {
    // Find barracks that aren't too busy
    final availableBarracks = buildings
        .where((b) => b.name == 'Cuartel' && !b.isUnderConstruction && b.productionQueue.length < 3)
        .toList();
    
    for (var b in availableBarracks) {
       // Only produce if we haven't reached a soft cap or if we are aggressive
       if (units.length < 30) {
          _tryTrainUnitAt(b);
       }
    }
  }

  void _manageGathering() {
    // AI builds resource buildings occasionally near its base
    final campCount = buildings.where((b) => b.name == 'Campamento Maderero').length;
    if (campCount < 2) {
      _tryBuildBuilding('Campamento Maderero');
    }
    
    final mineCount = buildings.where((b) => b.name == 'Mina').length;
    if (mineCount < 2) {
      _tryBuildBuilding('Mina');
    }

    final farmCount = buildings.where((b) => b.name == 'Granja').length;
    if (farmCount < 3) {
      _tryBuildBuilding('Granja');
    }

    // Equip workers to active extraction buildings
    int currentPop = units.length;
    for (var b in buildings) {
      currentPop += b.productionQueue.length;
      currentPop += b.currentWorkers;
    }

    for (var b in buildings) {
      if (!b.isUnderConstruction) {
        if (b.name == 'Mina' || b.name == 'Campamento Maderero' || b.name == 'Granja') {
          final typeData = BuildingData.buildings.firstWhere((bd) => bd.name == b.name);
          if (b.currentWorkers < typeData.maxWorkers && currentPop < maxPopulation) {
            b.currentWorkers++;
            currentPop++;
          }
        }
      }
    }
  }

  // ─── Actions ──────────────────────────────────────────
  void _tryBuildBuilding(String buildingName, {int maxCount = 5}) {
    final mapGrid = grid;
    if (mapGrid == null) return;
 
    // Find the typedata for the building
    final BuildingTypeData? typeData = BuildingData.buildings
        .where((b) => b.name == buildingName)
        .firstOrNull;
    if (typeData == null) return;
 
    if (!canAfford(w: typeData.costWood, s: typeData.costStone, g: typeData.costGold, c: typeData.costCoal)) {
      return;
    }
 
    // Count existing of same type
    final currentCount = buildings.where((b) => b.name == buildingName).length;
    if (currentCount >= maxCount) return;

    // Find the AI's urban center or any building to build near it
    Building? anchor = buildings
        .where((b) => b.name == 'Centro Urbano' && !b.isUnderConstruction)
        .firstOrNull;
    anchor ??= buildings.firstOrNull;
    if (anchor == null) return;
 
    // Try to find a free tile nearby (random search in increasing radius)
    for (int radius = 3; radius <= 8; radius++) {
      for (int attempt = 0; attempt < 10; attempt++) {
        final int dx = _rng.nextInt(radius * 2 + 1) - radius;
        final int dy = _rng.nextInt(radius * 2 + 1) - radius;
        final int tx = anchor.x + dx;
        final int ty = anchor.y + dy;
 
        if (!mapGrid.isValid(tx, ty)) continue;
        final tile = mapGrid.getTile(tx, ty);
        
        // Ensure some distance from other buildings for pathing
        if (!tile.isWalkable || tile.building != null || tile.resource != null) continue;
        
        // Simple overlap check with neighbors
        bool tooClose = false;
        for (int nx = tx-1; nx <= tx+1; nx++) {
          for (int ny = ty-1; ny <= ty+1; ny++) {
             if (mapGrid.isValid(nx, ny) && mapGrid.getTile(nx, ny).building != null) {
               tooClose = true;
               break;
             }
          }
        }
        if (tooClose && _rng.nextDouble() > 0.3) continue; // Allow some density

        spendResources(w: typeData.costWood, s: typeData.costStone, g: typeData.costGold, c: typeData.costCoal);
        onPlaceBuilding(typeData, tx, ty);
        return;
      }
    }
  }
 
  void _tryTrainUnitAt(Building barracks) {
    // Queue the cheapest/first military unit
    final militaryUnit = UnitData.units
        .where((u) => u.category == UnitCategory.infantry)
        .firstOrNull;
    if (militaryUnit == null) return;
 
    int currentPop = units.length;
    for (var b in buildings) {
      currentPop += b.productionQueue.length;
      currentPop += b.currentWorkers;
    }

    if (currentPop + militaryUnit.populationCost <= maxPopulation && canAfford(w: militaryUnit.costWood, f: militaryUnit.costFood, g: militaryUnit.costGold, s: militaryUnit.costStone, c: militaryUnit.costCoal)) {
      spendResources(w: militaryUnit.costWood, f: militaryUnit.costFood, g: militaryUnit.costGold, s: militaryUnit.costStone, c: militaryUnit.costCoal);
      onQueueUnit(barracks, militaryUnit.id);
    }
  }

  void _sendAttackWave() {
    final mapGrid = grid;
    if (mapGrid == null) return;
    if (units.isEmpty) return;
 
    // Find a target: either a building or a unit
    double? targetX;
    double? targetY;
    double bestDist = double.infinity;
 
    final myBase = buildings.where((b) => b.name == 'Centro Urbano').firstOrNull;
    final originX = myBase?.x.toDouble() ?? units.first.x;
    final originY = myBase?.y.toDouble() ?? units.first.y;
 
    // 1. Target any enemy unit nearby if we are already out there? 
    // No, for a wave, let's target an enemy BUILDING.
    
    // We'll scan a few random locations to find an enemy building to avoid O(N^2) every time
    // But since the map is small, search is fine.
    // Target any enemy building. Optimized: iterate list instead of mapping tiles.
    for (final b in allBuildings) {
      if (b.playerId != playerId && !b.isDestroyed) {
        final dist = (b.x - originX).abs() + (b.y - originY).abs();
        if (dist < bestDist) {
          bestDist = dist.toDouble();
          targetX = b.x.toDouble();
          targetY = b.y.toDouble();
        }
      }
    }
 
    if (targetX == null || targetY == null) return;
 
    // Send army (all idle units)
    final army = units.where((u) => u.state == UnitState.idle).toList();
    if (army.isNotEmpty) {
      onMoveUnits(army, targetX, targetY);
    }
  }
}
