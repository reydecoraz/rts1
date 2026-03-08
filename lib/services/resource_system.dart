import 'dart:async';
import '../models/map_grid.dart';
import '../models/resource_type.dart';
import '../data/building_data.dart';
import 'game_session.dart';
import '../ai/ai_controller.dart';

class ResourceSystem {
  Timer? _timer;
  final GameSession session = GameSession();
  final void Function() onTick; 
  List<AiController> aiControllers = [];

  ResourceSystem({required this.onTick});
  
  void start(MapGrid grid, List<AiController> aiControllers) {
    this.aiControllers = aiControllers;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _tick(grid);
    });
  }

  void stop() {
    _timer?.cancel();
  }

  void _addResourceToPlayer(int playerId, ResourceType type, int amount) {
    if (playerId == 0) {
      final int modAmount = (amount * session.gatheringSpeedModifier).round();
      session.addResource(type, modAmount);
    } else {
      final ai = aiControllers.where((a) => a.playerId == playerId).firstOrNull;
      ai?.addResources(type, amount);
    }
  }

  void _tick(MapGrid grid) {
    bool stateChanged = false; // Solo true si cambian gráficos en el mapa
    
    // Repasar todos los tiles para procesar edificios extractivos
    for (int x = 0; x < grid.width; x++) {
      for (int y = 0; y < grid.height; y++) {
        final tile = grid.getTile(x, y);
        if (tile.building == null || tile.building!.isUnderConstruction) continue;
        
        final building = tile.building!;
        
        // Granja (Food pasivo)
        if (building.name == "Granja") {
           _addResourceToPlayer(building.playerId, ResourceType.food, 2);
        }
        
        // Minas
        if (building.name == "Mina") {
           if (building.currentWorkers > 0 && tile.resource != null && !tile.resource!.isEmpty) {
              final extractionAmount = building.currentWorkers; // 1 unidad por trabajador por segundo
              final actualExtracted = (tile.resource!.amount >= extractionAmount) 
                 ? extractionAmount 
                 : tile.resource!.amount;
                 
              tile.resource!.amount -= actualExtracted;
              _addResourceToPlayer(building.playerId, tile.resource!.type, actualExtracted);
              
              if (tile.resource!.amount <= 0) {
                 building.isDepleted = true;
                 building.currentWorkers = 0;
                 stateChanged = true;
              }
           }
        }
        
        // Campamento Maderero
        if (building.name == "Campamento Maderero" && building.currentWorkers > 0) {
           final targetTree = _findNearestTree(grid, x, y);
           if (targetTree != null) {
              final distSq = (targetTree.$1 - x)*(targetTree.$1 - x) + (targetTree.$2 - y)*(targetTree.$2 - y);
              
              // A mayor distancia, menos eficiencia (mínimo 1)
              double efficiency = 1.0 / (1.0 + (distSq * 0.05)); 
              int extracted = (building.currentWorkers * efficiency).ceil();
              if (extracted < 1) extracted = 1;

              final treeTile = grid.getTile(targetTree.$1, targetTree.$2);
              
              // Ajustar la cantidad a extraer para no exceder la cantidad del árbol
              if (extracted > treeTile.resource!.amount) {
                extracted = treeTile.resource!.amount;
              }

              treeTile.resource!.amount -= extracted;
              _addResourceToPlayer(building.playerId, ResourceType.wood, extracted);
              
              building.targetExtractX = targetTree.$1;
              building.targetExtractY = targetTree.$2;
              stateChanged = true; // Se dibuja la línea visual

              if (treeTile.resource!.amount <= 0) {
                 treeTile.resource = null; // Árbol destruido (libera la casilla)
                 building.targetExtractX = null;
                 building.targetExtractY = null;
                 stateChanged = true; // El mapa perdió un árbol
              }
           } else {
              if (building.targetExtractX != null) {
                 building.targetExtractX = null;
                 building.targetExtractY = null;
                 stateChanged = true; // Quitar la línea
              }
           }
        }
      }
    }
    
    // Recompute max population for all players
    Map<int, int> playerMaxPop = {0: 10};
    for (final ai in aiControllers) {
      playerMaxPop[ai.playerId] = 10;
    }

    for (int x = 0; x < grid.width; x++) {
      for (int y = 0; y < grid.height; y++) {
        final b = grid.getTile(x, y).building;
        if (b == null || b.isUnderConstruction) continue;
        final data = BuildingData.buildings.where((d) => d.name == b.name).firstOrNull;
        if (data != null && data.populationProvided > 0) {
          playerMaxPop[b.playerId] = (playerMaxPop[b.playerId] ?? 10) + data.populationProvided;
        }
      }
    }

    session.setMaxPopulation(playerMaxPop[0] ?? 10);
    for (final ai in aiControllers) {
      ai.maxPopulation = playerMaxPop[ai.playerId] ?? 10;
    }

    // Si hubo cambios visuales en el terreno
    if (stateChanged) {
       onTick();
    }
  }

  (int, int)? _findNearestTree(MapGrid grid, int startX, int startY) {
     int maxRadius = 15; // Buscar hasta a 15 tiles de distancia
     int bestDist = 999999;
     (int, int)? bestTarget;

     for (int r = 1; r <= maxRadius; r++) {
       for (int dx = -r; dx <= r; dx++) {
         for (int dy = -r; dy <= r; dy++) {
           if (dx.abs() != r && dy.abs() != r) continue;
           final nx = startX + dx;
           final ny = startY + dy;
           if (!grid.isValid(nx, ny)) continue;
           
           final t = grid.getTile(nx, ny);
           if (t.resource != null && t.resource!.type == ResourceType.wood && !t.resource!.isEmpty) {
              int dist = dx*dx + dy*dy;
              if (dist < bestDist) {
                 bestDist = dist;
                 bestTarget = (nx, ny);
              }
           }
         }
       }
       if (bestTarget != null) break; // Termina en cuanto encuentra la capa más interna con árboles
     }
     return bestTarget;
  }
}
