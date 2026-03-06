import 'package:flutter/material.dart';

class CivilizationBonus {
  final String description;
  final String affectedStat; // e.g., 'infantry_health', 'wood_gathering_speed'
  final double multiplier;

  CivilizationBonus({
    required this.description,
    required this.affectedStat,
    required this.multiplier,
  });
}

class Civilization {
  final String id;
  final String name;
  final String description;
  final Color primaryColor;
  final String emblemAssetPath; // Path to emblem image

  // Ventajas únicas
  final List<CivilizationBonus> bonuses;

  // IDs de tecnologías, unidades, edificios y skins disponibles
  final List<String> uniqueTechnologies;
  final List<String> uniqueUnits;
  final List<String> uniqueBuildings;
  final List<String> availableSkinIds;

  Civilization({
    required this.id,
    required this.name,
    required this.description,
    required this.primaryColor,
    required this.emblemAssetPath,
    this.bonuses = const [],
    this.uniqueTechnologies = const [],
    this.uniqueUnits = const [],
    this.uniqueBuildings = const [],
    this.availableSkinIds = const [],
  });
}
