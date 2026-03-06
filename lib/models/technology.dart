import 'package:flutter/material.dart';
import 'era.dart';

class Technology {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final GameEra requiredEra;
  
  // Lista de IDs de tecnologías requeridas para investigar esta
  final List<String> requiredTechnologies;
  
  // Costos
  final int costWood;
  final int costStone;
  final int costGold;
  final int costCoal;
  final int researchTimeSeconds;

  Technology({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.requiredEra,
    this.requiredTechnologies = const [],
    this.costWood = 0,
    this.costStone = 0,
    this.costGold = 0,
    this.costCoal = 0,
    this.researchTimeSeconds = 30,
  });
}
