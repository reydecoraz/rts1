import 'package:flutter/foundation.dart';
import '../models/resource_type.dart';

class GameSession extends ChangeNotifier {
  static final GameSession _instance = GameSession._internal();
  factory GameSession() => _instance;
  GameSession._internal();

  int wood = 1000;
  int food = 800;
  int gold = 500;
  int stone = 500;
  int coal = 300;

  // Player's active civilization
  String activeCivilizationId = 'civ_romans'; // Default safe value

  // Population
  int currentPopulation = 0; // Units alive/training
  int maxPopulation = 10;    // Grows with houses

  void addResource(ResourceType type, int amount) {
    if (amount <= 0) return;
    switch (type) {
      case ResourceType.wood: wood += amount; break;
      case ResourceType.food: food += amount; break;
      case ResourceType.gold: gold += amount; break;
      case ResourceType.stone: stone += amount; break;
      case ResourceType.coal: coal += amount; break;
      case ResourceType.none: break;
    }
    notifyListeners();
  }

  bool canAfford({int w = 0, int f = 0, int g = 0, int s = 0, int c = 0}) {
    return wood >= w && food >= f && gold >= g && stone >= s && coal >= c;
  }

  void spendResources({int w = 0, int f = 0, int g = 0, int s = 0, int c = 0}) {
     wood -= w;
     food -= f;
     gold -= g;
     stone -= s;
     coal -= c;
     notifyListeners();
  }

  /// Called each second by ResourceSystem to recalculate max population from houses
  void setMaxPopulation(int n) {
    if (n != maxPopulation) {
      maxPopulation = n;
      notifyListeners();
    }
  }

  /// Increase population count when a unit starts being trained
  bool tryConsumePopulation(int amount) {
    if (currentPopulation + amount > maxPopulation) return false;
    currentPopulation += amount;
    notifyListeners();
    return true;
  }

  /// Called when a unit dies or is disbanded
  void releasePopulation(int amount) {
    currentPopulation = (currentPopulation - amount).clamp(0, maxPopulation);
    notifyListeners();
  }

  /// Reset all resources and population to starting values
  void reset() {
    wood = 1000;
    food = 800;
    gold = 500;
    stone = 500;
    coal = 300;
    currentPopulation = 0;
    maxPopulation = 10;
    notifyListeners();
  }
}
