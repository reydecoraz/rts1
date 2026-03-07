import 'dart:math';
import 'package:flutter/material.dart';
import 'map_grid.dart';
import 'formation.dart';
import 'building.dart';
import '../utils/spatial_grid.dart';

enum UnitCategory { infantry, ranged, cavalry, siege, worker, special }
enum UnitState { idle, moving, attacking, dead }

class UnitStats {
  int maxHealth;
  double movementSpeed;

  // Ataque
  int meleeAttack;
  int rangedAttack;
  double attackSpeed; // Segundos entre ataques
  double attackRange;
  double aggroRange; // Distancia para detectar enemigos automáticamente
  double accuracy; // % de acierto (ej. 1.0 = 100%, 0.8 = 80%)

  // Daño de área
  double splashRadius;
  int splashDamage;

  // Defensa
  int meleeArmor;
  int rangedArmor;
  int cavalryArmor;

  UnitStats({
    required this.maxHealth,
    required this.movementSpeed,
    this.meleeAttack = 0,
    this.rangedAttack = 0,
    this.attackSpeed = 1.0,
    this.attackRange = 1.0,
    this.aggroRange = 6.0,
    this.splashRadius = 0.0,
    this.splashDamage = 0,
    this.meleeArmor = 0,
    this.rangedArmor = 0,
    this.cavalryArmor = 0,
    this.accuracy = 1.0,
  });

  UnitStats copyWith({
    int? maxHealth,
    double? movementSpeed,
    int? meleeAttack,
    int? rangedAttack,
    double? attackSpeed,
    int? rangedArmor,
    int? cavalryArmor,
    double? aggroRange,
    double? accuracy,
  }) {
    return UnitStats(
      maxHealth: maxHealth ?? this.maxHealth,
      movementSpeed: movementSpeed ?? this.movementSpeed,
      meleeAttack: meleeAttack ?? this.meleeAttack,
      rangedAttack: rangedAttack ?? this.rangedAttack,
      attackSpeed: attackSpeed ?? this.attackSpeed,
      attackRange: attackRange ?? this.attackRange,
      aggroRange: aggroRange ?? this.aggroRange,
      splashRadius: splashRadius ?? this.splashRadius,
      splashDamage: splashDamage ?? this.splashDamage,
      meleeArmor: meleeArmor ?? this.meleeArmor,
      rangedArmor: rangedArmor ?? this.rangedArmor,
      cavalryArmor: cavalryArmor ?? this.cavalryArmor,
      accuracy: accuracy ?? this.accuracy,
    );
  }
}

class Unit {
  final String id;
  final String typeId;
  final UnitCategory category;
  final int playerId;
  
  // Posición continua (coordenadas mundiales)
  double x;
  double y;

  int currentHealth;
  UnitState state;
  List<Offset> currentPath;
  
  UnitStats currentStats;

  // Para cooldown de ataque
  double attackCooldown;

  // Sistema de Combate
  Unit? targetUnit;
  Building? targetBuilding; // For attacking enemy buildings
  
  Unit({
    required this.id,
    required this.typeId,
    required this.category,
    required this.playerId,
    required this.x,
    required this.y,
    required this.currentStats,
  })  : currentHealth = currentStats.maxHealth,
        state = UnitState.idle,
        currentPath = [],
        attackCooldown = 0.0,
        formationGroup = null;

  /// The active formation this unit belongs to (null = no formation).
  FormationGroup? formationGroup;


  void takeDamage(int rawDamage, {bool isRanged = false}) {
    // 1. Identificar qué armadura usar
    int armor = isRanged ? currentStats.rangedArmor : currentStats.meleeArmor;
    
    // 2. Fórmula Clásica de RTS: Daño Real = Daño Bruto - Armadura
    // Usamos 'max(1, ...)' para asegurar que los ataques siempre hagan al menos 1 de daño 
    // y evitar tropas inmortales si la armadura es muy alta.
    int actualDamage = max(1, rawDamage - armor);

    currentHealth -= actualDamage;
    if (currentHealth <= 0) {
      currentHealth = 0;
      state = UnitState.dead;
    }
  }

  void update(double dt, List<Unit> allUnits, MapGrid grid, {SpatialGrid? spatialGrid}) {
    if (state == UnitState.dead) return;

    if (attackCooldown > 0) {
      attackCooldown -= dt;
    }

    // Formation members are moved by FormationGroup.applyToUnits() instead
    if (formationGroup != null && formationGroup!.members.contains(this)) {
      // Still apply separation so units don't pile up while in formation
      _applySeparation(dt, allUnits, grid, spatialGrid);
      return;
    }

    if (currentPath.isNotEmpty) {
      state = UnitState.moving;
      Offset nextTarget = currentPath.first;
      
      // Verify if the target tile is still walkable (e.g. a building was placed there)
      final int tx = nextTarget.dx.toInt();
      final int ty = nextTarget.dy.toInt();
      if (grid.isValid(tx, ty)) {
        if (!grid.getTile(tx, ty).isWalkable) {
          // Path is blocked! Stop moving or recalculate.
          // For now, let's just clear the path to stop the unit.
          currentPath.clear();
          state = UnitState.idle;
          return;
        }
      }

      double dx = nextTarget.dx - x;
      double dy = nextTarget.dy - y;
      double distance = sqrt(dx * dx + dy * dy);

      if (distance < 0.1) {
        x = nextTarget.dx;
        y = nextTarget.dy;
        currentPath.removeAt(0);
        if (currentPath.isEmpty) {
           state = UnitState.idle;
        }
      } else {
        double moveStep = currentStats.movementSpeed * dt;
        if (moveStep >= distance) {
           x = nextTarget.dx;
           y = nextTarget.dy;
           currentPath.removeAt(0);
           if (currentPath.isEmpty) {
              state = UnitState.idle;
           }
        } else {
           double ratio = moveStep / distance;
           x += dx * ratio;
           y += dy * ratio;
        }
      }
    } else {
       if (state == UnitState.moving) {
          state = UnitState.idle;
       }
    }

    _applySeparation(dt, allUnits, grid, spatialGrid);
  }

  void _applySeparation(double dt, List<Unit> allUnits, MapGrid grid, SpatialGrid? spatialGrid) {
    // ── Separación suave entre unidades (Optimización Espacial) ────────
    const double separationRadius = 0.75;
    const double radiusSq = separationRadius * separationRadius;
    const double separationStrength = 0.4;
 
    // Si tenemos grid espacial, solo chequeamos vecinos
    final List<Unit> targets = (spatialGrid != null) 
        ? spatialGrid.getNearby(x, y, separationRadius) 
        : allUnits;
 
    for (int i = 0; i < targets.length; i++) {
      final other = targets[i];
      if (other.id == id || other.state == UnitState.dead) continue;
      
      final double sdx = x - other.x;
      final double sdy = y - other.y;
      final double distSq = sdx * sdx + sdy * sdy;
      
      if (distSq > 0.0 && distSq < radiusSq) {
        final double sdist = sqrt(distSq);
        final double push = (separationRadius - sdist) * separationStrength * dt;
        x += (sdx / sdist) * push;
        y += (sdy / sdist) * push;
      }
    }

    // ── Colisión con edificios y obstáculos (Repulsión) ──────
    // Para que no se metan dentro de un edificio si se mueven por separación
    final int cx = x.round();
    final int cy = y.round();
    for (int ix = cx - 1; ix <= cx + 1; ix++) {
      for (int iy = cy - 1; iy <= cy + 1; iy++) {
        if (!grid.isValid(ix, iy)) continue;
        final tile = grid.getTile(ix, iy);
        if (!tile.isWalkable) {
          // Repeler desde el centro del tile bloqueado
          final double bdx = x - ix;
          final double bdy = y - iy;
          final double bdist = sqrt(bdx * bdx + bdy * bdy);
          const double buildingAvoidance = 0.7; // Radio de colisión
          if (bdist < buildingAvoidance) {
            final double push = (buildingAvoidance - bdist) * 2.0 * dt;
            if (bdist > 0.01) {
              x += (bdx / bdist) * push;
              y += (bdy / bdist) * push;
            } else {
              // Si está justo encima, empujar aleatoriamente
              x += 0.1;
            }
          }
        }
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Projectile system
// ─────────────────────────────────────────────────────────────────────────────

enum ProjectileType { arrow, cannonball }

class Projectile {
  final String id;
  final ProjectileType type;
  double x;
  double y;
  double targetX;
  double targetY;
  final Unit? targetUnit;
  final Building? targetBuilding; // attack target building
  final int damage;
  final double speed; // tiles/second
  bool arrived = false;

  // For arc effect (cannonball)
  double progress = 0.0; // 0..1

  Projectile({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.targetX,
    required this.targetY,
    this.targetUnit,
    this.targetBuilding,
    required this.damage,
    this.speed = 10.0,
  });

  /// Advance the projectile. Returns true on impact.
  bool update(double dt) {
    final double destX = (targetUnit != null && targetUnit!.state != UnitState.dead)
        ? targetUnit!.x
        : targetX;
    final double destY = (targetUnit != null && targetUnit!.state != UnitState.dead)
        ? targetUnit!.y
        : targetY;

    final double dx = destX - x;
    final double dy = destY - y;
    final double dist = sqrt(dx * dx + dy * dy);

    if (dist < 0.25) {
      x = destX;
      y = destY;
      arrived = true;
      return true;
    }

    final double step = speed * dt;
    final double ratio = (step / dist).clamp(0.0, 1.0);
    x += dx * ratio;
    y += dy * ratio;
    progress = (progress + dt * speed / max(dist, 0.01)).clamp(0.0, 1.0);
    return false;
  }
}
