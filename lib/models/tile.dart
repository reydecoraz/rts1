import 'biome_type.dart';
import 'resource.dart';
import 'building.dart';

class Tile {
  final int x;
  final int y;
  BiomeType biome;
  Resource? resource;
  Building? building;
  bool isBaseLocation; // Para las 8 bases de jugadores
  
  // Fog of War
  bool isExplored;
  bool isVisible;

  Tile({
    required this.x,
    required this.y,
    this.biome = BiomeType.grass,
    this.resource,
    this.building,
    this.isBaseLocation = false,
    this.isExplored = false,
    this.isVisible = false,
  });

  bool get isWalkable {
    if (building != null && !building!.isDestroyed) {
      return false;
    }
    if (resource != null && !resource!.isPassable && !resource!.isEmpty) {
      return false;
    }
    return biome != BiomeType.water && biome != BiomeType.mountain;
  }
}
