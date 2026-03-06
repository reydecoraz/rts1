import 'package:flutter/material.dart';
import '../models/technology.dart';
import '../models/era.dart';

final List<Technology> mockTechnologies = [
  // --- Edad de Piedra ---
  Technology(
    id: "stone_tools",
    name: "Herramientas de Piedra",
    description: "Permite recolectar piedra más rápido y construir muros básicos.",
    icon: Icons.hardware,
    requiredEra: GameEra.stone,
    researchTimeSeconds: 15,
    costWood: 50,
  ),
  Technology(
    id: "agriculture",
    name: "Agricultura Básica",
    description: "Desbloquea granjas para generar comida (futuro).",
    icon: Icons.agriculture,
    requiredEra: GameEra.stone,
    researchTimeSeconds: 20,
    costWood: 100,
  ),

  // --- Edad de Bronce ---
  Technology(
    id: "bronze_working",
    name: "Forja de Bronce",
    description: "Desbloquea el cuartel avanzado y unidades de cuerpo a cuerpo.",
    icon: Icons.fireplace,
    requiredEra: GameEra.bronze,
    requiredTechnologies: ["stone_tools"],
    researchTimeSeconds: 30,
    costWood: 150,
    costStone: 100,
  ),
  Technology(
    id: "wheel",
    name: "La Rueda",
    description: "Mejora la velocidad de movimiento de las unidades en 20%.",
    icon: Icons.album,
    requiredEra: GameEra.bronze,
    requiredTechnologies: ["agriculture"],
    researchTimeSeconds: 25,
    costWood: 200,
  ),

  // --- Edad de Hierro ---
  Technology(
    id: "iron_working",
    name: "Forja de Hierro",
    description: "Armas y armaduras más fuertes. Desbloquea unidades pesadas.",
    icon: Icons.construction,
    requiredEra: GameEra.iron,
    requiredTechnologies: ["bronze_working"],
    researchTimeSeconds: 45,
    costWood: 250,
    costStone: 200,
    costGold: 100,
  ),
  Technology(
    id: "fortification",
    name: "Fortificaciones",
    description: "Desbloquea muros de piedra y torres de defensa avanzadas.",
    icon: Icons.castle,
    requiredEra: GameEra.iron,
    requiredTechnologies: ["stone_tools"],
    researchTimeSeconds: 40,
    costStone: 300,
    costGold: 50,
  ),

  // --- Edad Imperial ---
  Technology(
    id: "gunpowder",
    name: "Pólvora",
    description: "Desbloquea cañones y unidades a distancia explosivas.",
    icon: Icons.local_fire_department,
    requiredEra: GameEra.imperial,
    requiredTechnologies: ["iron_working"],
    researchTimeSeconds: 60,
    costWood: 300,
    costStone: 300,
    costGold: 400,
  ),
  Technology(
    id: "architecture",
    name: "Arquitectura Monumental",
    description: "Permite construir Maravillas.",
    icon: Icons.account_balance,
    requiredEra: GameEra.imperial,
    requiredTechnologies: ["fortification"],
    researchTimeSeconds: 80,
    costWood: 500,
    costStone: 500,
    costGold: 500,
  ),
];
