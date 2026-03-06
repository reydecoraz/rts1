import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/civilization.dart';
import '../models/hero.dart';

class DataManager {
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  DataManager._internal();

  final Map<String, Civilization> _civilizations = {};
  final Map<String, HeroData> _heroes = {};

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  Future<void> loadAllData() async {
    if (_isLoaded) return;
    print("Loading JSON data...");
    await _loadCivilizations();
    await _loadHeroes();
    _isLoaded = true;
    print("JSON data loaded successfully.");
  }

  Future<void> _loadCivilizations() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/civilizations.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      
      for (var json in jsonList) {
        final bonuses = (json['bonuses'] as List<dynamic>?)?.map((b) => CivilizationBonus(
          description: b['description'],
          affectedStat: b['affectedStat'],
          multiplier: (b['multiplier'] as num).toDouble(),
        )).toList() ?? [];

        final civ = Civilization(
          id: json['id'],
          name: json['name'],
          description: json['description'],
          primaryColor: Color(int.parse(json['primaryColor'])),
          emblemAssetPath: json['emblemAssetPath'],
          bonuses: bonuses,
          uniqueTechnologies: List<String>.from(json['uniqueTechnologies'] ?? []),
          uniqueUnits: List<String>.from(json['uniqueUnits'] ?? []),
          uniqueBuildings: List<String>.from(json['uniqueBuildings'] ?? []),
          availableSkinIds: List<String>.from(json['availableSkinIds'] ?? []),
        );
        _civilizations[civ.id] = civ;
      }
    } catch (e) {
      print("Error loading civilizations.json: $e");
    }
  }

  Future<void> _loadHeroes() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/heroes.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);

      for (var json in jsonList) {
        final bonuses = (json['globalBonuses'] as List<dynamic>?)?.map((b) => CivilizationBonus(
          description: b['description'],
          affectedStat: b['affectedStat'],
          multiplier: (b['multiplier'] as num).toDouble(),
        )).toList() ?? [];

        final hero = HeroData(
          id: json['id'],
          name: json['name'],
          lore: json['lore'],
          avatarAssetPath: json['avatarAssetPath'],
          globalBonuses: bonuses,
        );
        _heroes[hero.id] = hero;
      }
    } catch (e) {
      print("Error loading heroes.json: $e");
    }
  }

  Civilization? getCivilization(String id) => _civilizations[id];
  HeroData? getHero(String id) => _heroes[id];
  
  List<Civilization> getAllCivilizations() => _civilizations.values.toList();
  List<HeroData> getAllHeroes() => _heroes.values.toList();
}
