import 'package:flutter/material.dart';
import 'building_enums.dart';

class Building {
  String name;
  BuildingCategory category;
  List<BuildingAction> availableActions;

  double health;
  double maxHealth;
  final Color playerColor;
  final int playerId;
  
  // Posición en el tile
  int x;
  int y;

  // Colas
  List<String> productionQueue;
  double currentProductionProgress;
  List<String> researchQueue;
  double currentResearchProgress;
  // Construcción
  bool isUnderConstruction;
  int constructionTotalSeconds;
  int constructionRemainingSeconds;

  // Extracción
  int currentWorkers;
  int? targetExtractX;
  int? targetExtractY;
  bool isDepleted;

  // Punto de reunión para unidades producidas
  int? rallyPointX;
  int? rallyPointY;
  
  // Rango de visión
  int sightRadius;

  Building({
    required this.name,
    required this.category,
    required this.availableActions,
    required this.health,
    required this.maxHealth,
    required this.playerColor,
    required this.playerId,
    required this.x,
    required this.y,
    this.isUnderConstruction = false,
    this.constructionTotalSeconds = 0,
    this.constructionRemainingSeconds = 0,
    this.productionQueue = const [],
    this.currentProductionProgress = 0.0,
    this.researchQueue = const [],
    this.currentResearchProgress = 0.0,
    this.currentWorkers = 0,
    this.isDepleted = false,
    this.sightRadius = 5,
  });

  bool get isDestroyed => health <= 0;

  double get constructionProgress {
    if (constructionTotalSeconds <= 0) return 1.0;
    return 1.0 -
        (constructionRemainingSeconds / constructionTotalSeconds).clamp(0.0, 1.0);
  }

  void takeDamage(double amount) {
    health = (health - amount).clamp(0, maxHealth);
  }

  factory Building.urbanCenter({
    required Color color,
    required int playerId,
    required int x,
    required int y,
  }) {
    return Building(
      name: "Centro Urbano",
      category: BuildingCategory.civil,
      availableActions: [
        BuildingAction.production,
        BuildingAction.investigation,
      ],
      health: 2000,
      maxHealth: 2000,
      playerColor: color,
      playerId: playerId,
      x: x,
      y: y,
    );
  }
}
