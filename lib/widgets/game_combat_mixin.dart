import 'dart:math';
import 'package:flutter/material.dart';
import '../models/unit.dart';
import '../models/building.dart';
import '../models/formation.dart';
import '../utils/pathfinder.dart';
import '../data/unit_data.dart';
import '../ai/ai_controller.dart';
import '../services/game_session.dart';
import '../models/map_grid.dart';
import '../utils/spatial_grid.dart';
import '../services/data_manager.dart';

/// Mixin that implements the game loop (combat, AI, production, projectiles).
/// It must be used on _GameScreenState-compatible classes that expose the
/// required state fields.
mixin GameCombatMixin<T extends StatefulWidget> on State<T> {
  // ── Abstract getters/setters provided by _GameScreenState ─────
  MapGrid get grid;
  List<Unit> get units$;
  List<Building> get activeBuildings$;
  List<Projectile> get activeProjectiles$;
  List<FormationGroup> get activeFormations$;
  List<AiController> get aiControllers$;
  List<String> get researchedTechs$;
  int get projectileCounter$;
  set projectileCounter$(int v);
  bool get playerWon$;
  set playerWon$(bool v);
  bool get playerLost$;
  set playerLost$(bool v);
  double get heroRespawnTimer$;
  set heroRespawnTimer$(double v);
 
  // ── Performance optimization state ──────
  final SpatialGrid _spatialGrid = SpatialGrid(cellSize: 3.0);

  // ── Main combat tick ─────────────────────────────────────────
  /// Call this from _onTick with the current [dt] (delta-time in seconds).
  /// Returns true if the scene needs a repaint.
  bool runCombatTick(double dt) {
    // Tick AI controllers
    for (final ai in aiControllers$) {
      ai.tick(dt, activeBuildings$, units$, grid);
    }
 
    // Rebuild spatial grid for this tick
    _spatialGrid.clear();
    for (final u in units$) {
      _spatialGrid.add(u);
    }

    // Tick active formation groups
    activeFormations$.removeWhere((fg) => fg.isEmpty);
    for (final fg in activeFormations$) {
      fg.tickAnchor(dt);
      fg.applyToUnits(dt);
    }

    bool needsRepaint = false;
    for (int i = 0; i < units$.length; i++) {
      final unit = units$[i];
      if (unit.state == UnitState.dead) continue;

      if (unit.state == UnitState.moving || unit.state == UnitState.attacking) {
        needsRepaint = true;
      }
      unit.update(dt, units$, grid, spatialGrid: _spatialGrid);

      if (unit.currentStats.meleeAttack > 0 || unit.currentStats.rangedAttack > 0) {
        needsRepaint |= _tickUnitCombat(unit, dt);
      }
    }

    needsRepaint |= _tickProjectiles(dt);
    needsRepaint |= _cleanupDestroyedBuildings();
    needsRepaint |= _cleanupDeadUnits();
    _checkWinLoss();
    needsRepaint |= _tickProduction(dt);

    if (heroRespawnTimer$ > 0) {
      heroRespawnTimer$ -= dt;
      if (heroRespawnTimer$ <= 0) {
        heroRespawnTimer$ = 0;
        _respawnHero();
        needsRepaint = true;
      }
    }

    return needsRepaint;
  }

  void _respawnHero() {
    final session = GameSession();
    if (session.activeHeroId == null) return;
    final heroData = DataManager().getHero(session.activeHeroId!);
    if (heroData == null || heroData.heroUnitId.isEmpty) return;
    final heroUnitType = UnitData.units.where((u) => u.id == heroData.heroUnitId).firstOrNull;
    if (heroUnitType == null) return;

    final tc = activeBuildings$.where((b) => b.playerId == 0 && b.name == 'Centro Urbano').firstOrNull;
    if (tc == null) return;

    bool spawned = false;
    for (int r = 1; r <= 3 && !spawned; r++) {
      for (int dx = -r; dx <= r && !spawned; dx++) {
        for (int dy = -r; dy <= r && !spawned; dy++) {
          final tx = tc.x + dx, ty = tc.y + dy;
          if (grid.isValid(tx, ty) && grid.getTile(tx, ty).isWalkable && grid.getTile(tx, ty).building == null) {
            units$.add(Unit(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              typeId: heroUnitType.id,
              category: heroUnitType.category,
              x: tx.toDouble(),
              y: ty.toDouble(),
              playerId: 0,
              currentStats: heroUnitType.baseStats,
            ));
            spawned = true;
          }
        }
      }
    }
  }

  // ── Unit combat (targeting + attacking) ──────────────────────
  bool _tickUnitCombat(Unit unit, double dt) {
    bool repaint = false;
    // Clear dead target
    if (unit.targetUnit != null && unit.targetUnit!.state == UnitState.dead) {
      unit.targetUnit = null;
    }

    final bool isMovingManually = unit.state == UnitState.moving && unit.targetUnit == null;

    // Auto-acquire enemy unit target (Optimized: use squared distance)
    if (unit.targetUnit == null && !isMovingManually) {
      double bestAggroDistSq = unit.currentStats.aggroRange * unit.currentStats.aggroRange;
      Unit? bestTarget;
      
      // Optimization: Only scan for targets in nearby cells
      final nearbyEnemies = _spatialGrid.getNearby(unit.x, unit.y, unit.currentStats.aggroRange);
      
      for (final enemy in nearbyEnemies) {
        if (enemy.playerId != unit.playerId && enemy.state != UnitState.dead) {
          final double edx = enemy.x - unit.x;
          final double edy = enemy.y - unit.y;
          final double dSq = edx * edx + edy * edy;
          
          if (dSq < bestAggroDistSq) {
            bestAggroDistSq = dSq;
            bestTarget = enemy;
          }
        }
      }
      unit.targetUnit = bestTarget;
    }

    // Attack or chase unit target
    if (unit.targetUnit != null) {
      unit.formationGroup?.removeMember(unit);
      final dist = sqrt(pow(unit.targetUnit!.x - unit.x, 2) + pow(unit.targetUnit!.y - unit.y, 2));
      if (dist <= unit.currentStats.attackRange) {
        if (unit.state == UnitState.moving) unit.currentPath.clear();
        unit.state = UnitState.attacking;
        if (unit.attackCooldown <= 0) {
          unit.attackCooldown = unit.currentStats.attackSpeed;
          repaint = true;
          if (unit.currentStats.rangedAttack > 0) {
            final pType = unit.category == UnitCategory.siege
                ? ProjectileType.cannonball
                : ProjectileType.arrow;
            activeProjectiles$.add(Projectile(
              id: 'proj_${projectileCounter$++}',
              type: pType,
              x: unit.x, y: unit.y,
              targetX: unit.targetUnit!.x,
              targetY: unit.targetUnit!.y,
              targetUnit: unit.targetUnit,
              damage: unit.currentStats.rangedAttack,
              speed: pType == ProjectileType.cannonball ? 7.0 : 12.0,
            ));
          } else {
            // Ataque melee
            if (Random().nextDouble() <= unit.currentStats.accuracy) {
              int baseDamage = unit.currentStats.meleeAttack;
              unit.targetUnit!.takeDamage(baseDamage, isRanged: false);
            }
          }
        }
      } else {
        final bool needsNewPath = unit.currentPath.isEmpty ||
            (unit.currentPath.last.dx - unit.targetUnit!.x).abs() > 1.0 ||
            (unit.currentPath.last.dy - unit.targetUnit!.y).abs() > 1.0;
        if (needsNewPath) {
          final path = AStarPathfinder.findPath(
            grid,
            Point(unit.x.toInt(), unit.y.toInt()),
            Point(unit.targetUnit!.x.toInt(), unit.targetUnit!.y.toInt()),
          );
          if (path.isNotEmpty) {
            unit.currentPath = path;
            unit.state = UnitState.moving;
          } else if (dist > unit.currentStats.aggroRange * 1.5) {
            unit.targetUnit = null;
          }
        }
      }
    } else if (unit.state == UnitState.attacking) {
      unit.state = UnitState.idle;
    }

    // Attack building targets
    if (unit.targetUnit == null) {
      if (unit.targetBuilding != null && unit.targetBuilding!.isDestroyed) {
        unit.targetBuilding = null;
      }
      if (unit.targetBuilding == null && !isMovingManually) {
        Building? closest;
        double closestDist = unit.currentStats.aggroRange;
        for (final b in activeBuildings$) {
          if (b.playerId == unit.playerId || b.isDestroyed || b.isUnderConstruction) continue;
          final d = sqrt(pow(b.x - unit.x, 2) + pow(b.y - unit.y, 2));
          if (d < closestDist) { closestDist = d; closest = b; }
        }
        unit.targetBuilding = closest;
      }
      if (unit.targetBuilding != null) {
        unit.formationGroup?.removeMember(unit);
        final bx = unit.targetBuilding!.x.toDouble();
        final by = unit.targetBuilding!.y.toDouble();
        final dist = sqrt(pow(bx - unit.x, 2) + pow(by - unit.y, 2));
        if (dist <= unit.currentStats.attackRange + 1.0) {
          unit.currentPath.clear();
          unit.state = UnitState.attacking;
          if (unit.attackCooldown <= 0) {
            unit.attackCooldown = unit.currentStats.attackSpeed;
            final dmg = unit.currentStats.meleeAttack > 0
                ? unit.currentStats.meleeAttack
                : unit.currentStats.rangedAttack;
            if (unit.currentStats.rangedAttack > 0) {
              final pType = unit.category == UnitCategory.siege
                  ? ProjectileType.cannonball
                  : ProjectileType.arrow;
              activeProjectiles$.add(Projectile(
                id: 'proj_${projectileCounter$++}',
                type: pType,
                x: unit.x, y: unit.y,
                targetX: bx, targetY: by,
                damage: dmg,
                targetBuilding: unit.targetBuilding,
                speed: pType == ProjectileType.cannonball ? 7.0 : 12.0,
              ));
            } else {
              unit.targetBuilding!.takeDamage(dmg.toDouble());
            }
            repaint = true;
          }
        } else {
          final needsPath = unit.currentPath.isEmpty ||
              (unit.currentPath.last.dx - bx).abs() > 1.5 ||
              (unit.currentPath.last.dy - by).abs() > 1.5;
          if (needsPath) {
            final path = AStarPathfinder.findPath(
              grid,
              Point(unit.x.toInt(), unit.y.toInt()),
              Point(bx.toInt(), by.toInt()),
            );
            if (path.isNotEmpty) {
              unit.currentPath = path;
              unit.state = UnitState.moving;
            }
          }
        }
      }
    }
    return repaint;
  }

  // ── Projectiles ───────────────────────────────────────────────
  bool _tickProjectiles(double dt) {
    bool repaint = false;
    final toRemove = <Projectile>[];
    for (final proj in activeProjectiles$) {
      if (proj.update(dt)) {
        if (proj.targetUnit != null && proj.targetUnit!.state != UnitState.dead) {
          proj.targetUnit!.takeDamage(proj.damage, isRanged: true);
        }
        if (proj.targetBuilding != null && !proj.targetBuilding!.isDestroyed) {
          int finalDamage = max(1, proj.damage); // Edificios sin armor por ahora o asumiendo 0
          proj.targetBuilding!.takeDamage(finalDamage.toDouble());
        }
        toRemove.add(proj);
        repaint = true;
      }
    }
    activeProjectiles$.removeWhere((p) => toRemove.contains(p));
    return repaint;
  }

  // ── Building / Unit cleanup ───────────────────────────────────
  bool _cleanupDestroyedBuildings() {
    final before = activeBuildings$.length;
    activeBuildings$.removeWhere((b) {
      if (b.isDestroyed) {
        if (b.currentWorkers > 0 && b.playerId == 0) {
           GameSession().releasePopulation(b.currentWorkers);
           b.currentWorkers = 0;
        }
        if (grid.isValid(b.x, b.y)) grid.getTile(b.x, b.y).building = null;
        return true;
      }
      return false;
    });
    return activeBuildings$.length != before;
  }

  bool _cleanupDeadUnits() {
    final dying = units$.where((u) => u.state == UnitState.dead && u.playerId == 0).toList();
    for (final u in dying) {
      if (u.category == UnitCategory.hero) heroRespawnTimer$ = 10.0;
    }
    if (dying.isNotEmpty) GameSession().releasePopulation(dying.length);
    final before = units$.length;
    units$.removeWhere((u) => u.state == UnitState.dead);
    return units$.length != before;
  }

  void _checkWinLoss() {
    if (playerWon$ || playerLost$) return;

    // 1. Check Player (0)
    final playerBase = activeBuildings$
        .where((b) => b.playerId == 0 && b.name == 'Centro Urbano')
        .firstOrNull;
    if (playerBase == null || playerBase.isDestroyed) {
      setState(() { playerLost$ = true; });
      return; // Stop checking if player lost
    }

    // 2. Check each AI individually
    bool allEnemiesDefeated = true;
    for (final ai in aiControllers$) {
      if (ai.isDefeated) continue;

      final aiBase = activeBuildings$
          .where((b) => b.playerId == ai.playerId && b.name == 'Centro Urbano')
          .firstOrNull;
      
      if (aiBase == null || aiBase.isDestroyed) {
        ai.isDefeated = true;
        // Optionally: trigger a "Player X defeated" message or effect here
      } else {
        allEnemiesDefeated = false;
      }
    }

    if (allEnemiesDefeated && aiControllers$.isNotEmpty) {
      setState(() { playerWon$ = true; });
    }
  }

  // ── Production queues ─────────────────────────────────────────
  bool _tickProduction(double dt) {
    bool repaint = false;
    for (final b in activeBuildings$) {
      // Unit production
      if (b.productionQueue.isNotEmpty) {
        final unitType = UnitData.units.firstWhere((u) => u.id == b.productionQueue.first);
        final double mod = b.playerId == 0 ? GameSession().trainingSpeedModifier : 1.0;
        b.currentProductionProgress += dt / (unitType.productionTime * mod);
        if (b.currentProductionProgress >= 1.0) {
          b.currentProductionProgress = 0.0;
          b.productionQueue.removeAt(0);
          _spawnUnit(b, unitType);
          repaint = true;
        }
      }

      // Research
      if (b.researchQueue.isNotEmpty) {
        b.currentResearchProgress += dt / 10.0;
        if (b.currentResearchProgress >= 1.0) {
          b.currentResearchProgress = 0.0;
          final techId = b.researchQueue.removeAt(0);
          if (!researchedTechs$.contains(techId)) {
            researchedTechs$.add(techId);
          }
          repaint = true;
        }
      }
    }
    return repaint;
  }

  void _spawnUnit(Building b, UnitTypeData unitType) {
    // Find free adjacent tile
    const offsets = [[0,1],[1,0],[0,-1],[-1,0],[1,1],[-1,1],[1,-1],[-1,-1]];
    int spawnX = b.x, spawnY = b.y;
    for (final off in offsets) {
      final cx = b.x + off[0], cy = b.y + off[1];
      if (!grid.isValid(cx, cy)) continue;
      final tile = grid.getTile(cx, cy);
      if (!tile.isWalkable || tile.building != null) continue;
      if (units$.any((u) => u.state != UnitState.dead && (u.x - cx).abs() < 0.5 && (u.y - cy).abs() < 0.5)) continue;
      spawnX = cx; spawnY = cy;
      break;
    }

    // Calcular estadísticas base y modificadores de civilización
    UnitStats finalStats = unitType.baseStats.copyWith();
    
    // Obtener civilización del jugador creador
    String civId = b.playerId == 0 ? GameSession().activeCivilizationId : 'civ_romans'; // TODO para IA
    final civ = DataManager().getCivilization(civId);
    
    if (civ != null) {
      for (var bonus in civ.bonuses) {
        if (bonus.affectedStat == 'infantry_melee_attack' && unitType.category == UnitCategory.infantry) {
          finalStats.meleeAttack = (finalStats.meleeAttack * bonus.multiplier).round();
        } else if (bonus.affectedStat == 'infantry_armor' && unitType.category == UnitCategory.infantry) {
          finalStats.meleeArmor = (finalStats.meleeArmor * bonus.multiplier).round();
          finalStats.rangedArmor = (finalStats.rangedArmor * bonus.multiplier).round();
        } else if (bonus.affectedStat == 'archer_attack_accuracy' && unitType.category == UnitCategory.ranged) {
          finalStats.rangedAttack = (finalStats.rangedAttack * bonus.multiplier).round();
          finalStats.accuracy = min(1.0, finalStats.accuracy * bonus.multiplier);
        } else if (bonus.affectedStat == 'cavalry_defense' && unitType.category == UnitCategory.cavalry) {
          finalStats.maxHealth = (finalStats.maxHealth * bonus.multiplier).round();
          finalStats.meleeArmor = (finalStats.meleeArmor * bonus.multiplier).round();
          finalStats.rangedArmor = (finalStats.rangedArmor * bonus.multiplier).round();
          finalStats.cavalryArmor = (finalStats.cavalryArmor * bonus.multiplier).round();
        }
      }
      
      // Bonus específico de Romanos MVP: +15% de armadura cuerpo a cuerpo (meleeArmor)
      if (civ.id == 'civ_romans') {
         finalStats.meleeArmor = (finalStats.meleeArmor * 1.15).round();
      }
    }

    final newUnit = Unit(
      id: '${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(1000)}',
      typeId: unitType.id,
      category: unitType.category,
      playerId: b.playerId,
      x: spawnX.toDouble(),
      y: spawnY.toDouble(),
      currentStats: finalStats,
    );

    if (b.rallyPointX != null && b.rallyPointY != null) {
      final path = AStarPathfinder.findPath(
        grid,
        Point<int>(spawnX, spawnY),
        Point<int>(b.rallyPointX!, b.rallyPointY!),
      );
      if (path.isNotEmpty) {
        newUnit.currentPath = path;
        newUnit.state = UnitState.moving;
      }
    }
    units$.add(newUnit);
  }
}
