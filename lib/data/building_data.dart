import 'package:flutter/material.dart';
import '../models/building_enums.dart';
import '../models/resource_type.dart';

class BuildingTypeData {
  final String name;
  final String description;
  final BuildingCategory category;
  final int costWood;
  final int costStone;
  final int costGold;
  final int costCoal; // Nuevo recurso
  final IconData icon;
  final int constructionTime; // segundos
  final bool isChainingAllowed; // arrastrar para construir cadena
  final List<BuildingAction> availableActions;

  // Extracción
  final ResourceType? extractsResource;
  final int maxWorkers;
  final String? evolvesInto;
  final int populationProvided; // How much this building adds to max population (e.g. Casa = 5)

  const BuildingTypeData({
    required this.name,
    required this.description,
    required this.category,
    required this.costWood,
    required this.costStone,
    required this.costGold,
    this.costCoal = 0,
    required this.icon,
    required this.constructionTime,
    this.isChainingAllowed = false,
    this.availableActions = const [],
    this.extractsResource,
    this.maxWorkers = 0,
    this.evolvesInto,
    this.populationProvided = 0,
  });
}

class BuildingData {
  static const List<BuildingTypeData> buildings = [
    // --- Civil ---
    BuildingTypeData(
      name: "Casa",
      description: "Aumenta la población máxima.",
      category: BuildingCategory.civil,
      costWood: 50,
      costStone: 0,
      costGold: 0,
      icon: Icons.house,
      constructionTime: 5,
      availableActions: [],
      populationProvided: 5,
    ),
    BuildingTypeData(
      name: "Granja",
      description: "Genera comida cultivando tierras. Ocupa trabajadores.",
      category: BuildingCategory.civil,
      costWood: 100,
      costStone: 0,
      costGold: 0,
      icon: Icons.agriculture,
      constructionTime: 8,
      availableActions: const [BuildingAction.gather],
      extractsResource: ResourceType.food,
      maxWorkers: 5,
    ),
    BuildingTypeData(
      name: "Mercado",
      description: "Permite comerciar recursos.",
      category: BuildingCategory.civil,
      costWood: 150,
      costStone: 0,
      costGold: 50,
      icon: Icons.store,
      constructionTime: 10,
      availableActions: [BuildingAction.trade],
    ),

    // --- Militar ---
    BuildingTypeData(
      name: "Cuartel",
      description: "Entrena infantería básica.",
      category: BuildingCategory.military,
      costWood: 150,
      costStone: 50,
      costGold: 0,
      icon: Icons.security,
      constructionTime: 10,
      availableActions: [BuildingAction.production, BuildingAction.investigation],
    ),
    BuildingTypeData(
      name: "Galería de Tiro",
      description: "Entrena arqueros.",
      category: BuildingCategory.military,
      costWood: 150,
      costStone: 0,
      costGold: 50,
      icon: Icons.gps_fixed,
      constructionTime: 10,
      availableActions: [BuildingAction.production],
    ),
    BuildingTypeData(
      name: "Establo",
      description: "Entrena caballería.",
      category: BuildingCategory.military,
      costWood: 200,
      costStone: 0,
      costGold: 100,
      icon: Icons.bedroom_baby_outlined,
      constructionTime: 10,
      availableActions: [BuildingAction.production],
    ),
    BuildingTypeData(
      name: "Taller de Asedio",
      description: "Fabrica armas de asedio y artillería usando maderas y carbón.",
      category: BuildingCategory.military,
      costWood: 200,
      costStone: 100,
      costGold: 50,
      icon: Icons.construction,
      constructionTime: 20,
      availableActions: [BuildingAction.production],
    ),

    // --- Defensa ---
    BuildingTypeData(
      name: "Torre",
      description: "Defensa estática básica.",
      category: BuildingCategory.defense,
      costWood: 50,
      costStone: 150,
      costGold: 0,
      icon: Icons.visibility,
      constructionTime: 8,
      availableActions: [],
    ),
    BuildingTypeData(
      name: "Muro",
      description: "Bloquea el paso. Arrastra para construir una cadena.",
      category: BuildingCategory.defense,
      costWood: 20,
      costStone: 50,
      costGold: 0,
      icon: Icons.block,
      constructionTime: 2,
      isChainingAllowed: true,
      availableActions: [],
    ),

    // --- Extracción ---
    BuildingTypeData(
      name: "Mina",
      description: "Extrae el mineral sobre el que se construya asignando trabajadores (Cuenta en la población).",
      category: BuildingCategory.civil,
      costWood: 100,
      costStone: 50,
      costGold: 0,
      icon: Icons.monetization_on, // Icono genérico (podremos cambiarlo dinámicamente si es necesario luego)
      constructionTime: 12,
      availableActions: const [BuildingAction.gather, BuildingAction.evolve],
      extractsResource: null, // Dinámico
      maxWorkers: 10,
      evolvesInto: "Torre",
    ),
    BuildingTypeData(
      name: "Campamento Maderero",
      description: "Tala de árboles (Mecánica especial). Ocupa trabajadores asignados.",
      category: BuildingCategory.civil,
      costWood: 50,
      costStone: 0,
      costGold: 0,
      icon: Icons.forest,
      constructionTime: 10,
      availableActions: const [BuildingAction.gather],
      extractsResource: ResourceType.wood,
      maxWorkers: 10,
    ),
  ];
}
