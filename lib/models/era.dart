enum GameEra {
  stone,
  bronze,
  iron,
  imperial
}

extension GameEraExtension on GameEra {
  String get name {
    switch (this) {
      case GameEra.stone:
        return 'Edad de Piedra';
      case GameEra.bronze:
        return 'Edad de Bronce';
      case GameEra.iron:
        return 'Edad de Hierro';
      case GameEra.imperial:
        return 'Edad Imperial';
    }
  }

  int get level {
    switch (this) {
      case GameEra.stone:
        return 1;
      case GameEra.bronze:
        return 2;
      case GameEra.iron:
        return 3;
      case GameEra.imperial:
        return 4;
    }
  }

  GameEra? get nextEra {
    switch (this) {
      case GameEra.stone:
        return GameEra.bronze;
      case GameEra.bronze:
        return GameEra.iron;
      case GameEra.iron:
        return GameEra.imperial;
      case GameEra.imperial:
        return null;
    }
  }

  // Costo para avanzar A LA SIGUIENTE era, estando en esta.
  int get evolutionCostFood {
    switch (this) {
      case GameEra.stone: return 500;
      case GameEra.bronze: return 1000;
      case GameEra.iron: return 2000;
      case GameEra.imperial: return 0;
    }
  }

  int get evolutionCostWood {
    switch (this) {
      case GameEra.stone: return 300;
      case GameEra.bronze: return 600;
      case GameEra.iron: return 1200;
      case GameEra.imperial: return 0;
    }
  }

  int get evolutionCostGold {
    switch (this) {
      case GameEra.stone: return 0;
      case GameEra.bronze: return 400;
      case GameEra.iron: return 1000;
      case GameEra.imperial: return 0;
    }
  }

  int get evolutionCostStone {
    switch (this) {
      case GameEra.stone: return 0;
      case GameEra.bronze: return 300;
      case GameEra.iron: return 800;
      case GameEra.imperial: return 0;
    }
  }

  int get evolutionCostCoal {
    switch (this) {
      case GameEra.stone: return 0;
      case GameEra.bronze: return 0;
      case GameEra.iron: return 500;
      case GameEra.imperial: return 0;
    }
  }
}
