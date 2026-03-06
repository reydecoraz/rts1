import 'package:flutter/material.dart';
import '../models/era.dart';
import '../models/unit.dart';

class UnitTypeData {
  final String id;
  final String name;
  final String description;
  final UnitCategory category;
  final UnitStats baseStats;

  final String producedIn; // Nombre del edificio donde se crea
  final int costFood;
  final int costWood;
  final int costGold;
  final int costStone;
  final int costCoal; // Nuevo recurso
  final int productionTime; // segundos
  final IconData icon;
  final GameEra requiredEra;
  final int populationCost; // Population slots this unit occupies

  UnitTypeData({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.baseStats,
    required this.producedIn,
    this.costFood = 0,
    this.costWood = 0,
    this.costGold = 0,
    this.costStone = 0,
    this.costCoal = 0,
    required this.productionTime,
    required this.icon,
    this.requiredEra = GameEra.stone,
    this.populationCost = 1,
  });
}

class UnitData {
  static final List<UnitTypeData> units = [
    // --- Centro Urbano ---
    UnitTypeData(
      id: "carreta",
      name: "Carreta de Comercio",
      description: "Genera oro comerciando entre mercados aliados.",
      category: UnitCategory.worker,
      baseStats: UnitStats(maxHealth: 100, movementSpeed: 1.0), // No ataca
      producedIn: "Centro Urbano",
      costWood: 100,
      costGold: 50,
      productionTime: 25,
      icon: Icons.shopping_cart,
      requiredEra: GameEra.bronze,
    ),

    // --- Cuartel ---
    UnitTypeData(
      id: "soldado_espada",
      name: "Soldado con Espada",
      description: "Infantería pesada. Buen daño y armadura.",
      category: UnitCategory.infantry,
      baseStats: UnitStats(
        maxHealth: 120, movementSpeed: 1.2,
        meleeAttack: 15, attackSpeed: 1.5, attackRange: 1.0,
        meleeArmor: 2, rangedArmor: 1,
      ),
      producedIn: "Cuartel",
      costFood: 60,
      costGold: 20,
      productionTime: 15,
      icon: Icons.security,
      requiredEra: GameEra.stone, // Para pruebas tempranas
    ),
    UnitTypeData(
      id: "lancero",
      name: "Lancero",
      description: "Infantería con bonificación contra caballería.",
      category: UnitCategory.infantry,
      baseStats: UnitStats(
        maxHealth: 100, movementSpeed: 1.3,
        meleeAttack: 10, attackSpeed: 1.4, attackRange: 1.2,
        cavalryArmor: 3,
      ),
      producedIn: "Cuartel",
      costFood: 25,
      costWood: 35,
      productionTime: 12,
      icon: Icons.api,
      requiredEra: GameEra.bronze,
    ),

    // --- Galería de Tiro ---
    UnitTypeData(
      id: "arquero",
      name: "Arquero",
      description: "Ataque a distancia. Débil en el cuerpo a cuerpo.",
      category: UnitCategory.ranged,
      baseStats: UnitStats(
        maxHealth: 70, movementSpeed: 1.3,
        rangedAttack: 12, attackSpeed: 1.2, attackRange: 5.0,
        meleeArmor: 0, rangedArmor: 1,
      ),
      producedIn: "Galería de Tiro",
      costWood: 25,
      costGold: 45,
      productionTime: 18,
      icon: Icons.gps_fixed,
      requiredEra: GameEra.bronze,
    ),

    // --- Establo ---
    UnitTypeData(
      id: "caballero",
      name: "Caballero",
      description: "Caballería pesada rápida con gran daño letal.",
      category: UnitCategory.cavalry,
      baseStats: UnitStats(
        maxHealth: 200, movementSpeed: 2.0,
        meleeAttack: 20, attackSpeed: 1.8, attackRange: 1.2,
        meleeArmor: 3, rangedArmor: 2,
      ),
      producedIn: "Establo",
      costFood: 60,
      costGold: 75,
      productionTime: 24,
      icon: Icons.directions_run,
      requiredEra: GameEra.iron,
    ),

    // --- Taller de Asedio ---
    UnitTypeData(
      id: "canon_asedio",
      name: "Cañón de Asedio",
      description: "Artillería pesada que inflige daño masivo a edificios. Usa carbón.",
      category: UnitCategory.siege,
      baseStats: UnitStats(
        maxHealth: 150, movementSpeed: 0.6,
        rangedAttack: 50, attackSpeed: 4.0, attackRange: 8.0,
        splashRadius: 2.0, splashDamage: 25,
        rangedArmor: 3, meleeArmor: -1, // Débil cuerpo a cuerpo
      ),
      producedIn: "Taller de Asedio",
      costWood: 100,
      costGold: 50,
      costCoal: 50,
      productionTime: 40,
      icon: Icons.local_fire_department,
      requiredEra: GameEra.imperial,
    ),
  ];
}
