import 'dart:math';
import 'package:flutter/material.dart';
import '../models/unit.dart';
import '../models/building.dart';
import '../models/building_enums.dart';
import '../models/formation.dart';
import '../models/map_grid.dart';
import '../models/resource.dart';
import '../models/resource_type.dart';
import '../models/unit_group.dart';
import '../data/building_data.dart';
import '../data/unit_data.dart';
import '../utils/constants.dart';
import '../utils/pathfinder.dart';
import '../services/game_session.dart';
import 'dart:async';

/// Mixin that handles all pointer/touch input and building placement.
mixin GameInputMixin<T extends StatefulWidget> on State<T> {
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);
  (int, int)? _lastTapTile;
  // ── Abstract getters/setters provided by _GameScreenState ─────
  MapGrid get grid;
  List<Unit> get units$;
  List<Unit> get selectedUnits$;
  List<Building> get activeBuildings$;
  List<FormationGroup> get activeFormations$;
  BuildingTypeData? get selectedBuilding$;
  set selectedBuilding$(BuildingTypeData? v);
  bool get isPlacementMode$;
  set isPlacementMode$(bool v);
  bool get isRallyPointMode$;
  set isRallyPointMode$(bool v);
  int? get hoveredTileX$;
  set hoveredTileX$(int? v);
  int? get hoveredTileY$;
  set hoveredTileY$(int? v);
  Building? get selectedExistingBuilding$;
  set selectedExistingBuilding$(Building? v);
  Map<String, Timer> get constructionTimers$;
  (int, int)? get wallDragStartTile$;
  set wallDragStartTile$((int, int)? v);
  List<(int, int)> get wallPreviewTiles$;
  Offset? get selectionStart$;
  set selectionStart$(Offset? v);
  Offset? get selectionEnd$;
  set selectionEnd$(Offset? v);
  Offset? get pointerDownScreenPos$;
  set pointerDownScreenPos$(Offset? v);
  int get nextGroupId$;
  set nextGroupId$(int v);
  List<UnitGroup> get savedGroups$;
  double get heroRespawnTimer$;
  set heroRespawnTimer$(double v);

  // ── Coordinate conversion ─────────────────────────────────────
  (int, int) screenToTile(Offset local) {
    final double halfW = MapConstants.tileWidth / 2;
    final double halfH = MapConstants.tileHeight / 2;
    final double offsetX = (grid.width * MapConstants.tileWidth) / 2;
    final double x = local.dx - offsetX;
    final double y = local.dy - halfH;
    final double gx = (x / halfW + y / halfH) / 2;
    final double gy = (y / halfH - x / halfW) / 2;
    return (gx.round(), gy.round());
  }

  // ── Placement mode ────────────────────────────────────────────
  void startPlacementMode(BuildingTypeData data) {
    setState(() {
      selectedBuilding$ = data;
      isPlacementMode$ = true;
      selectedExistingBuilding$ = null;
      isRallyPointMode$ = false;
    });
  }

  void cancelPlacementMode() {
    selectedBuilding$ = null;
    isPlacementMode$ = false;
    hoveredTileX$ = null;
    hoveredTileY$ = null;
  }

  // ── Building placement ────────────────────────────────────────
  bool tryPlaceBuilding(int tx, int ty) {
    if (!grid.isValid(tx, ty)) return false;
    final tile = grid.getTile(tx, ty);
    final data = selectedBuilding$!;

    if (data.name == 'Mina') {
      if (tile.resource == null ||
          (tile.resource!.type != ResourceType.gold &&
           tile.resource!.type != ResourceType.stone &&
           tile.resource!.type != ResourceType.coal) ||
          tile.resource!.isEmpty) return false;
      if (tile.building != null) return false;
    } else if (data.extractsResource != null) {
      if (!tile.isWalkable || tile.building != null || tile.resource != null) return false;
    } else {
      if (!tile.isWalkable || tile.building != null || tile.resource != null) return false;
    }

    final session = GameSession();
    if (!session.canAfford(w: data.costWood, s: data.costStone, g: data.costGold, c: data.costCoal)) {
      if (!data.isChainingAllowed) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sin recursos: madera ${data.costWood} / piedra ${data.costStone} / oro ${data.costGold}'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red[800],
        ));
      }
      return false;
    }

    final building = Building(
      name: data.name, x: tx, y: ty,
      category: data.category,
      availableActions: data.availableActions,
      health: 500, maxHealth: 500,
      playerColor: Colors.blue, playerId: 0,
      isUnderConstruction: true,
      constructionTotalSeconds: data.constructionTime,
      constructionRemainingSeconds: data.constructionTime,
      currentWorkers: 0,
    );

    if (building.availableActions.contains(BuildingAction.production)) {
      building.rallyPointX = grid.isValid(tx + 1, ty + 1) ? tx + 1 : tx;
      building.rallyPointY = grid.isValid(tx + 1, ty + 1) ? ty + 1 : ty;
    }

    tile.building = building;
    activeBuildings$.add(building);
    startConstructionTimer(tx, ty, building);
    session.spendResources(w: data.costWood, s: data.costStone, g: data.costGold, c: data.costCoal);
    return true;
  }

  void startConstructionTimer(int tx, int ty, Building building) {
    final key = '$tx,$ty';
    constructionTimers$[key]?.cancel();
    constructionTimers$[key] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        building.constructionRemainingSeconds--;
        if (building.constructionRemainingSeconds <= 0) {
          building.isUnderConstruction = false;
          timer.cancel();
          constructionTimers$.remove(key);
        }
      });
    });
  }

  // ── Pointer handlers ──────────────────────────────────────────
  void handlePointerDown(PointerDownEvent event) {
    pointerDownScreenPos$ = event.position;
    final (tx, ty) = screenToTile(event.localPosition);

    if (isPlacementMode$ && selectedBuilding$ != null) {
      if (!selectedBuilding$!.isChainingAllowed) {
        setState(() {
          if (tryPlaceBuilding(tx, ty)) cancelPlacementMode();
        });
      } else {
        setState(() {
          wallDragStartTile$ = (tx, ty);
          wallPreviewTiles$..clear()..add((tx, ty));
          hoveredTileX$ = tx;
          hoveredTileY$ = ty;
        });
      }
      return;
    }

    if (isRallyPointMode$ && selectedExistingBuilding$ != null) {
      if (grid.isValid(tx, ty) && grid.getTile(tx, ty).isWalkable) {
        setState(() {
          selectedExistingBuilding$!.rallyPointX = tx;
          selectedExistingBuilding$!.rallyPointY = ty;
          isRallyPointMode$ = false;
          selectedExistingBuilding$ = null;
        });
      }
      return;
    }

    setState(() {
      selectionStart$ = event.localPosition;
      selectionEnd$ = event.localPosition;
    });
  }

  void handlePointerMove(PointerMoveEvent event) {
    final (tx, ty) = screenToTile(event.localPosition);

    if (isPlacementMode$ && (selectedBuilding$?.isChainingAllowed ?? false) && wallDragStartTile$ != null) {
      if (hoveredTileX$ == tx && hoveredTileY$ == ty) return;
      setState(() {
        hoveredTileX$ = tx;
        hoveredTileY$ = ty;
        final (sx, sy) = wallDragStartTile$!;
        wallPreviewTiles$..clear()..addAll(bresenhamLine(sx, sy, tx, ty));
      });
      return;
    }

    if (!isPlacementMode$ && selectionStart$ != null) {
      setState(() { selectionEnd$ = event.localPosition; });
    }
  }

  void handlePointerUp(PointerUpEvent event) {
    // Wall drag commit
    if (isPlacementMode$ && (selectedBuilding$?.isChainingAllowed ?? false)) {
      if (wallPreviewTiles$.isNotEmpty && selectedBuilding$ != null) {
        setState(() {
          final session = GameSession();
          final data = selectedBuilding$!;
          int placed = 0;
          for (final (px, py) in wallPreviewTiles$) {
            if (!grid.isValid(px, py)) continue;
            final tile = grid.getTile(px, py);
            if (!tile.isWalkable || tile.building != null || tile.resource != null) continue;
            if (!session.canAfford(w: data.costWood, s: data.costStone, g: data.costGold)) break;
            final b = Building(
              name: data.name, x: px, y: py,
              category: data.category, availableActions: data.availableActions,
              health: 300, maxHealth: 300,
              playerColor: Colors.blue, playerId: 0,
              isUnderConstruction: true,
              constructionTotalSeconds: data.constructionTime,
              constructionRemainingSeconds: data.constructionTime,
              currentWorkers: 0,
            );
            tile.building = b;
            activeBuildings$.add(b);
            startConstructionTimer(px, py, b);
            session.spendResources(w: data.costWood, s: data.costStone, g: data.costGold);
            placed++;
          }
          wallPreviewTiles$.clear();
          wallDragStartTile$ = null;
          hoveredTileX$ = null;
          hoveredTileY$ = null;
          if (placed > 0) cancelPlacementMode();
        });
      } else {
        setState(() {
          wallPreviewTiles$.clear();
          wallDragStartTile$ = null;
          hoveredTileX$ = null;
          hoveredTileY$ = null;
        });
      }
      return;
    }

    if (isPlacementMode$ || isRallyPointMode$) return;

    double dist = 0;
    if (pointerDownScreenPos$ != null) {
      dist = (event.position - pointerDownScreenPos$!).distance;
    }
    final (tx, ty) = screenToTile(event.localPosition);

    setState(() {
      if (dist < 10.0) {
        // TAP
        selectionStart$ = null;
        selectionEnd$ = null;

        Unit? clicked;
        for (final u in units$) {
          if (u.x.round() == tx && u.y.round() == ty) { clicked = u; break; }
        }

        if (clicked != null) {
          // Si hace clic en una unidad, la selecciona y limpia cualquier edificio
          selectedExistingBuilding$ = null;
          selectedUnits$..clear()..add(clicked);
        } else if (selectedUnits$.isNotEmpty) {
          // Si TENEMOS unidades seleccionadas y hacemos clic en el mapa:
          final now = DateTime.now();
          final bool isDoubleTap = now.difference(_lastTapTime).inMilliseconds < 400 && _lastTapTile == (tx, ty);
          _lastTapTime = now;
          _lastTapTile = (tx, ty);

          if (isDoubleTap) {
             // Doble toque en el mapa DESELECCIONA las unidades
             selectedUnits$.clear();
          } else {
             // Toque simple en el mapa con unidades seleccionadas MUEVE las unidades hacia allá.
             // (Incluso si es recurso o edificio, se moverán hacia allá o intentaremos acción)
             if (grid.isValid(tx, ty)) {
                _moveSelectedUnitsToTile(tx, ty);
             }
          }
        } else {
          // Si NO TENÍAMOS unidades seleccionadas, seleccionamos el edificio o el recurso
          selectedUnits$.clear();
          if (grid.isValid(tx, ty)) {
            final tile = grid.getTile(tx, ty);
            if (tile.building != null && !tile.building!.isUnderConstruction) {
              selectedExistingBuilding$ = tile.building;
            } else if (tile.resource != null && !tile.resource!.isEmpty) {
              selectedExistingBuilding$ = null;
              _showResourceInfo(tile.resource!);
            } else {
              selectedExistingBuilding$ = null;
            }
          }
        }
      } else {
        // DRAG — area selection
        if (selectionStart$ != null && selectionEnd$ != null) {
          final selRect = Rect.fromPoints(selectionStart$!, selectionEnd$!);
          final halfW = MapConstants.tileWidth / 2;
          final halfH = MapConstants.tileHeight / 2;
          final offsetX = (grid.width * MapConstants.tileWidth) / 2;
          selectedUnits$.clear();
          for (final u in units$) {
            if (u.playerId != 0) continue;
            final usx = (u.x - u.y) * halfW + offsetX;
            final usy = (u.x + u.y) * halfH + halfH;
            if (selRect.contains(Offset(usx, usy))) selectedUnits$.add(u);
          }
          if (selectedUnits$.isNotEmpty) {
             // 1. Exclusive Membership: Remove these units from any existing groups
             final List<Unit> newSelection = List.from(selectedUnits$);
             for (final g in savedGroups$) {
               g.removeUnits(newSelection);
             }
             
             // 2. Auto-Cleanup: Remove groups that are now empty
             savedGroups$.removeWhere((g) => g.isEmpty);

             // 3. Create and Add the new group
             final group = UnitGroup(
               id: nextGroupId$++, 
               name: 'Grupo ${nextGroupId$ - 1}', 
               units: newSelection,
             );
             savedGroups$.add(group);
          }
        }
        selectionStart$ = null;
        selectionEnd$ = null;
      }
    });
  }

  void handlePointerCancel(PointerCancelEvent event) {
    handlePointerUp(PointerUpEvent(position: event.position));
  }

  // ── Formation movement ────────────────────────────────────────
  void _moveSelectedUnitsToTile(int tx, int ty) {
    final alive = selectedUnits$.where((u) => u.state != UnitState.dead).toList();
    if (alive.isEmpty) return;

    double cx = 0, cy = 0;
    for (final u in alive) { cx += u.x; cy += u.y; }
    cx /= alive.length; cy /= alive.length;

    final slots = buildFormationSlots(tx, ty, alive.length);
    final offsets = <Offset>[];
    for (int i = 0; i < alive.length; i++) {
      offsets.add(Offset(slots[i].$1.toDouble() - tx.toDouble(), slots[i].$2.toDouble() - ty.toDouble()));
    }

    final anchorPath = AStarPathfinder.findPath(
      grid,
      Point<int>(cx.round().clamp(0, grid.width - 1), cy.round().clamp(0, grid.height - 1)),
      Point<int>(tx, ty),
    );

    if (anchorPath.isNotEmpty) {
      final slowestSpeed = alive.map((u) => u.currentStats.movementSpeed).reduce(min);
      for (final u in alive) { u.formationGroup?.removeMember(u); }
      final fg = FormationGroup(
        members: alive, offsets: offsets,
        anchorPath: anchorPath, anchorX: cx, anchorY: cy, speed: slowestSpeed,
      );
      for (final u in alive) { u.formationGroup = fg; }
      activeFormations$.add(fg);
    } else {
      final fallback = buildFormationSlots(tx, ty, alive.length);
      for (int i = 0; i < alive.length; i++) {
        final path = AStarPathfinder.findPath(grid, Point(alive[i].x.toInt(), alive[i].y.toInt()), Point(fallback[i].$1, fallback[i].$2));
        if (path.isNotEmpty) {
          alive[i].currentPath = path;
          alive[i].state = UnitState.moving;
        }
      }
    }
  }

  // ── Formation slot builder ────────────────────────────────────
  List<(int, int)> buildFormationSlots(int cx, int cy, int count) {
    final slots = <(int, int)>[];
    if (count == 0) return slots;
    if (grid.isValid(cx, cy) && grid.getTile(cx, cy).isWalkable) slots.add((cx, cy));
    int ring = 1;
    while (slots.length < count && ring <= 10) {
      for (int dx = -ring; dx <= ring && slots.length < count; dx++) {
        for (int dy = -ring; dy <= ring && slots.length < count; dy++) {
          if (dx.abs() != ring && dy.abs() != ring) continue;
          final nx = cx + dx, ny = cy + dy;
          if (!grid.isValid(nx, ny) || !grid.getTile(nx, ny).isWalkable) continue;
          if (!slots.contains((nx, ny))) slots.add((nx, ny));
        }
      }
      ring++;
    }
    while (slots.length < count) slots.add((cx, cy));
    return slots;
  }

  // ── Bresenham line ────────────────────────────────────────────
  List<(int, int)> bresenhamLine(int x0, int y0, int x1, int y1) {
    final result = <(int, int)>[];
    int dx = (x1 - x0).abs(), dy = (y1 - y0).abs();
    int sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
    int err = dx - dy, x = x0, y = y0;
    while (true) {
      result.add((x, y));
      if (x == x1 && y == y1) break;
      int e2 = 2 * err;
      if (e2 > -dy) { err -= dy; x += sx; }
      if (e2 < dx)  { err += dx; y += sy; }
    }
    return result;
  }

  // ── Unit production initiation ────────────────────────────────
  void spawnUnitFromBuilding(Building building, UnitTypeData unitData) {
    final session = GameSession();
    if (!session.tryConsumePopulation(unitData.populationCost)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Población llena (${session.currentPopulation}/${session.maxPopulation}). Construye una Casa.'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange[800],
      ));
      return;
    }
    final costMod = session.unitCostModifier;
    final int f = (unitData.costFood * costMod).round();
    final int w = (unitData.costWood * costMod).round();
    final int g = (unitData.costGold * costMod).round();
    final int s = (unitData.costStone * costMod).round();
    final int c = (unitData.costCoal * costMod).round();

    if (!session.canAfford(f: f, w: w, g: g, s: s, c: c)) {
      session.releasePopulation(unitData.populationCost);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sin recursos para entrenar ${unitData.name}.'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red[800],
      ));
      return;
    }
    session.spendResources(f: f, w: w, g: g, s: s, c: c);
    setState(() {
      building.productionQueue = List.from(building.productionQueue)..add(unitData.id);
      building.currentProductionProgress = 0.0;
    });
  }

  // ── Resource info dialog ──────────────────────────────────────
  void _showResourceInfo(Resource resource) {
    final name = switch (resource.type) {
      ResourceType.wood  => 'Bosque Maderero',
      ResourceType.gold  => 'Veta de Oro',
      ResourceType.stone => 'Cantera de Piedra',
      ResourceType.coal  => 'Mina de Carbón',
      ResourceType.food  => 'Arbustos de Bayas',
      ResourceType.none  => 'Recurso',
    };
    final icon = switch (resource.type) {
      ResourceType.wood  => Icons.forest,
      ResourceType.gold  => Icons.monetization_on,
      ResourceType.stone => Icons.landscape,
      ResourceType.coal  => Icons.terrain,
      ResourceType.food  => Icons.restaurant,
      ResourceType.none  => Icons.help,
    };
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blueGrey[900]?.withValues(alpha: 0.9),
            border: Border.all(color: Colors.amber[700]!, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.amber[400], size: 24),
                  const SizedBox(width: 8),
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),
              const Text('Cantidad Restante:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Text('${resource.amount}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[700], foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
