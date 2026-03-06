import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/map_grid.dart';
import '../utils/map_generator.dart';
import '../utils/constants.dart';
import 'isometric_map_renderer.dart';
import 'unit_sprite_overlay.dart';
import 'fan_menu.dart';
import 'construction_modal.dart';
import 'building_info_panel.dart';
import 'hud_overlay.dart';
import 'placement_banner.dart';
import 'virtual_joystick_overlay.dart';
import 'resource_bar.dart';
import '../models/era.dart';
import '../data/building_data.dart';
import '../models/building.dart';
import '../models/building_enums.dart';
import '../services/resource_system.dart';
import '../models/unit.dart';
import '../ai/ai_controller.dart';
import 'minimap.dart';
import 'groups_panel.dart';
import '../models/unit_group.dart';
import '../models/formation.dart';
import '../utils/pathfinder.dart';
import 'game_combat_mixin.dart';
import 'game_input_mixin.dart';
import '../services/game_session.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, GameCombatMixin<GameScreen>, GameInputMixin<GameScreen> {
  // ── Map ───────────────────────────────────────────────────────
  @override
  late MapGrid grid;
  late TransformationController _controller;
  late ResourceSystem _resourceSystem;

  // ── Building placement ────────────────────────────────────────
  @override
  BuildingTypeData? selectedBuilding$;
  @override
  bool isPlacementMode$ = false;
  @override
  int? hoveredTileX$;
  @override
  int? hoveredTileY$;
  @override
  Building? selectedExistingBuilding$;
  @override
  Map<String, Timer> constructionTimers$ = {};
  @override
  (int, int)? wallDragStartTile$;
  @override
  List<(int, int)> wallPreviewTiles$ = [];

  // ── Rally point ───────────────────────────────────────────────
  @override
  bool isRallyPointMode$ = false;

  // ── Selection drag ────────────────────────────────────────────
  @override
  Offset? selectionStart$;
  @override
  Offset? selectionEnd$;
  @override
  Offset? pointerDownScreenPos$;

  // ── Units / buildings ─────────────────────────────────────────
  @override
  List<Unit> units$ = [];
  @override
  List<Unit> selectedUnits$ = [];
  @override
  List<Building> activeBuildings$ = [];
  @override
  List<Projectile> activeProjectiles$ = [];
  @override
  List<FormationGroup> activeFormations$ = [];
  @override
  int projectileCounter$ = 0;

  // ── Tech / Era ────────────────────────────────────────────────
  @override
  List<String> researchedTechs$ = [];
  GameEra _currentEra = GameEra.stone;

  // ── AI ────────────────────────────────────────────────────────
  @override
  List<AiController> aiControllers$ = [];

  // ── Win / Loss ────────────────────────────────────────────────
  @override
  bool playerWon$ = false;
  @override
  bool playerLost$ = false;

  // ── Groups ────────────────────────────────────────────────────
  final List<UnitGroup> _savedGroups = [];
  @override
  int nextGroupId$ = 1;

  // ── Joystick ──────────────────────────────────────────────────
  double _joystickX = 0.0;
  double _joystickY = 0.0;
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;

  // ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
    _resourceSystem = ResourceSystem(onTick: () { if (mounted) setState(() {}); });
    _ticker = createTicker(_onTick)..start();
    _generateNewMap();
  }

  @override
  void dispose() {
    _resourceSystem.stop();
    for (final t in constructionTimers$.values) t.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ── Vision ────────────────────────────────────────────────────
  void _updateVision() {
    for (final unit in units$) {
      if (unit.playerId != 0 || unit.state == UnitState.dead) continue;
      _revealArea(unit.x.round(), unit.y.round(), 5);
    }
    for (final b in activeBuildings$) {
      if (b.playerId != 0) continue;
      _revealArea(b.x, b.y, 6);
    }
  }

  void _revealArea(int cx, int cy, int radius) {
    for (int dx = -radius; dx <= radius; dx++) {
      for (int dy = -radius; dy <= radius; dy++) {
        if (dx * dx + dy * dy > radius * radius) continue;
        final nx = cx + dx, ny = cy + dy;
        if (!grid.isValid(nx, ny)) continue;
        final t = grid.getTile(nx, ny);
        t.isVisible = true;
        t.isExplored = true;
      }
    }
  }

  // ── Game loop ─────────────────────────────────────────────────
  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) _lastTick = elapsed;
    double dt = (elapsed - _lastTick).inMilliseconds / 1000.0;
    if (dt > 0.1) dt = 0.1;
    _lastTick = elapsed;

    _updateVision();

    final needsRepaint = runCombatTick(dt);

    if (_joystickX == 0 && _joystickY == 0) {
      if (needsRepaint && mounted) setState(() {});
      return;
    }

    final double scale = _controller.value.getMaxScaleOnAxis();
    final double speed = 15.0 / scale;
    final double dx = -_joystickX * speed;
    final double dy = -_joystickY * speed;
    final Matrix4 matrix = _controller.value;
    matrix.translateByDouble(dx, dy, 0.0, 1.0);
    _controller.value = matrix;
    if (mounted) setState(() {});
  }

  void _resetGame() {
    GameSession().reset();
    _generateNewMap();
  }

  // ── Map generation ────────────────────────────────────────────
  void _generateNewMap() {
    setState(() {
      grid = MapGenerator.generate(
        width: MapConstants.gridSize,
        height: MapConstants.gridSize,
        seed: DateTime.now().millisecondsSinceEpoch,
      );
      isPlacementMode$ = false;
      playerWon$ = false;
      playerLost$ = false;
      units$.clear();
      selectedUnits$.clear();
      activeBuildings$.clear();
      activeProjectiles$.clear();
      activeFormations$.clear();
      projectileCounter$ = 0;
      aiControllers$.clear();
      researchedTechs$.clear();
      _currentEra = GameEra.stone;
      _savedGroups.clear();
      nextGroupId$ = 1;

      int? playerX;
      int? playerY;
      final aiPlayerColors = <int, Color>{
        1: Colors.red,
        2: Colors.green,
        3: Colors.purple,
        4: Colors.orange,
        5: Colors.teal,
        6: Colors.yellow,
        7: Colors.pink,
      };

      for (int x = 0; x < grid.width; x++) {
        for (int y = 0; y < grid.height; y++) {
          final tile = grid.getTile(x, y);
          if (tile.building != null) {
            activeBuildings$.add(tile.building!);
            if (tile.isBaseLocation && tile.building?.playerId == 0) {
              playerX = x;
              playerY = y;
            } else if (tile.isBaseLocation && tile.building != null && tile.building!.playerId > 0) {
              final aiId = tile.building!.playerId;
              if (!aiControllers$.any((a) => a.playerId == aiId)) {
                aiControllers$.add(AiController(
                  playerId: aiId,
                  playerColor: aiPlayerColors[aiId] ?? Colors.grey,
                  onPlaceBuilding: (typeData, tx, ty) {
                    if (!grid.isValid(tx, ty)) return;
                    final t = grid.getTile(tx, ty);
                    if (!t.isWalkable || t.building != null) return;
                    final building = Building(
                      name: typeData.name, x: tx, y: ty,
                      category: typeData.category,
                      availableActions: typeData.availableActions,
                      health: 500, maxHealth: 500,
                      playerColor: aiPlayerColors[aiId] ?? Colors.grey,
                      playerId: aiId,
                      isUnderConstruction: false,
                      constructionTotalSeconds: typeData.constructionTime,
                      constructionRemainingSeconds: 0,
                      productionQueue: [], currentWorkers: 0,
                    );
                    if (typeData.availableActions.contains(BuildingAction.production)) {
                      building.rallyPointX = tx + 1;
                      building.rallyPointY = ty + 1;
                    }
                    t.building = building;
                    setState(() { activeBuildings$.add(building); });
                  },
                  onQueueUnit: (barracks, unitId) {
                    setState(() { barracks.productionQueue.add(unitId); });
                  },
                  onMoveUnits: (army, tx, ty) {
                    final path = AStarPathfinder.findPath(
                      grid,
                      Point<int>(army.first.x.toInt(), army.first.y.toInt()),
                      Point<int>(tx.toInt(), ty.toInt()),
                    );
                    if (path.isNotEmpty) {
                      for (final u in army) {
                        u.currentPath = List.from(path);
                        u.state = UnitState.moving;
                      }
                    }
                  },
                ));
              }
            }
          }
        }
      }

      // Reveal starting area around player base and center camera
      if (playerX != null && playerY != null) {
        _revealArea(playerX, playerY, 8);
        
        // Center camera on player center (Isometric coordinates)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final double worldOriginX = (grid.width * MapConstants.tileWidth) / 2.0;
          final double worldX = (playerX! - playerY!) * (MapConstants.tileWidth / 2) + worldOriginX;
          final double worldY = (playerX! + playerY!) * (MapConstants.tileHeight / 2) + (MapConstants.tileHeight / 2);
          
          final double screenW = MediaQuery.of(context).size.width;
          final double screenH = MediaQuery.of(context).size.height;
          
          final double tx = -worldX + (screenW / 2);
          final double ty = -worldY + (screenH / 2);
          
          _controller.value = Matrix4.identity()..translate(tx, ty);
        });
      }
    });
    _resourceSystem.start(grid, aiControllers$);
  }

  // ──────────────────────────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────
          InteractiveViewer(
            transformationController: _controller,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.1, maxScale: 4.0,
            panEnabled: false, scaleEnabled: false, constrained: false,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: handlePointerDown,
              onPointerMove: handlePointerMove,
              onPointerUp: handlePointerUp,
              onPointerCancel: handlePointerCancel,
              child: Container(
                color: Colors.transparent,
                child: RepaintBoundary(
                  child: Stack(
                  children: [
                    CustomPaint(
                      size: Size(
                        MapConstants.gridSize * MapConstants.tileWidth,
                        MapConstants.gridSize * MapConstants.tileHeight,
                      ),
                      painter: IsometricMapPainter(
                        grid: grid,
                        hoveredTileX: hoveredTileX$,
                        hoveredTileY: hoveredTileY$,
                        selectionStart: selectionStart$,
                        selectionEnd: selectionEnd$,
                        selectedBuilding: selectedExistingBuilding$,
                        units: units$.where((u) =>
                          u.category != UnitCategory.infantry &&
                          u.category != UnitCategory.worker
                        ).toList(),
                        selectedUnits: selectedUnits$,
                        projectiles: activeProjectiles$,
                        wallPreviewTiles: wallPreviewTiles$,
                      ),
                    ),
                    SizedBox(
                      width: MapConstants.gridSize * MapConstants.tileWidth,
                      height: MapConstants.gridSize * MapConstants.tileHeight,
                      child: InfantryUnitOverlay(
                        units: units$,
                        selectedUnits: selectedUnits$,
                        grid: grid,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

          // ── HUD ────────────────────────────────────────────────
          const ResourceBar(),
          HudOverlay(
            onRefreshPressed: _resetGame,
            currentEra: _currentEra,
          ),

          if (isPlacementMode$ && selectedBuilding$ != null)
            PlacementBanner(selectedBuilding: selectedBuilding$!),

          if (isRallyPointMode$)
            Positioned(
              top: 80, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Toca en el mapa para asignar el Punto de Reunión',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

          if (!isPlacementMode$ && !isRallyPointMode$)
            Positioned(
              bottom: selectedExistingBuilding$ != null ? 160 : 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GroupsPanelButton(
                    groups: _savedGroups,
                    selectedUnits: selectedUnits$,
                    onSelectGroup: (g) {
                      setState(() {
                        selectedUnits$..clear()..addAll(g.aliveUnits);
                        selectedExistingBuilding$ = null;
                      });
                    },
                    onDeleteGroup: (g) => setState(() => _savedGroups.remove(g)),
                  ),
                  const SizedBox(height: 10),
                  FanMenu(
                    onConstructionPressed: () {
                      setState(() { selectedExistingBuilding$ = null; });
                      showDialog(
                        context: context,
                        builder: (_) => ConstructionModal(
                          onBuildingSelected: startPlacementMode,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

          if (isPlacementMode$ || isRallyPointMode$)
            Positioned(
              bottom: 20, right: 20,
              child: FloatingActionButton.extended(
                heroTag: 'cancel_btn',
                onPressed: () => setState(() {
                  cancelPlacementMode();
                  isRallyPointMode$ = false;
                }),
                label: const Text('Cancelar'),
                icon: const Icon(Icons.cancel),
                backgroundColor: Colors.red[700],
              ),
            ),

          if (selectedExistingBuilding$ != null && !isPlacementMode$ && !isRallyPointMode$)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: BuildingInfoPanel(
                building: selectedExistingBuilding$!,
                currentEra: _currentEra,
                onClose: () => setState(() { selectedExistingBuilding$ = null; }),
                onSetRallyPoint: () => setState(() { isRallyPointMode$ = true; }),
                onTrainUnit: (unit) => spawnUnitFromBuilding(selectedExistingBuilding$!, unit),
                researchedTechs: researchedTechs$,
                onResearchStarted: (tech) {
                  setState(() {
                    if (!researchedTechs$.contains(tech.id)) researchedTechs$.add(tech.id);
                  });
                },
                onEvolveEra: () {
                  setState(() {
                    if (_currentEra.nextEra != null) _currentEra = _currentEra.nextEra!;
                  });
                },
              ),
            ),

          if (!isPlacementMode$ && !isRallyPointMode$)
            VirtualJoystickOverlay(
              onDirectionChanged: (details) {
                setState(() {
                  _joystickX = details.x;
                  _joystickY = details.y;
                });
              },
            ),

          Positioned(
            top: 0, left: 20,
            child: MinimapWidget(
              grid: grid,
              units: units$,
              buildings: activeBuildings$,
              mapPixelWidth: MapConstants.gridSize * MapConstants.tileWidth.toDouble(),
              mapPixelHeight: MapConstants.gridSize * MapConstants.tileHeight.toDouble(),
              viewTransform: _controller.value,
              screenSize: MediaQuery.sizeOf(context),
            ),
          ),

          if (playerWon$ || playerLost$)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.72),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        playerWon$ ? '🏆 ¡VICTORIA!' : '💀 DERROTA',
                        style: TextStyle(
                          fontSize: 48, fontWeight: FontWeight.bold,
                          color: playerWon$ ? Colors.amberAccent : Colors.redAccent,
                          shadows: const [Shadow(blurRadius: 20, color: Colors.black)],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        playerWon$ ? 'Destruiste todas las bases enemigas.' : 'Tu Centro Urbano fue destruido.',
                        style: const TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() { playerWon$ = false; playerLost$ = false; });
                          _generateNewMap();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Nueva Partida'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amberAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
