import 'dart:math';
import 'package:fast_noise/fast_noise.dart';
import '../models/map_grid.dart';
import '../models/biome_type.dart';
import '../models/resource_type.dart';
import '../models/resource.dart';
import '../models/tile.dart';
import '../models/building.dart';
import 'package:flutter/material.dart';

class MapGenerator {
  static MapGrid generate({
    required int width,
    required int height,
    required int seed,
    ResourceAbundance abundance = ResourceAbundance.medium,
  }) {
    final grid = MapGrid(width: width, height: height, seed: seed, abundance: abundance);
    final noise = buildNoise(
      seed: seed,
      frequency: 0.05,
      noiseType: NoiseType.perlin,
    );

    // 1. Generar Biomas
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final val = noise.getNoise2(x.toDouble(), y.toDouble());
        _assignBiome(grid.getTile(x, y), val);
      }
    }

    // 2. Colocar Recursos Minerales (Dispersos)
    _placeMinerals(grid, seed, abundance);

    // 3. Colocar Bosques (Agrupados)
    _placeForests(grid, seed, abundance);

    // 4. Ubicaciones de Bases (8 puntos)
    _placeBaseLocations(grid);

    return grid;
  }

  static void _assignBiome(Tile tile, double noiseValue) {
    if (noiseValue < -0.1) {
      tile.biome = BiomeType.grass;
    } else if (noiseValue < 0.2) {
      tile.biome = BiomeType.desert;
    } else if (noiseValue < 0.5) {
      tile.biome = BiomeType.grass;
    } else {
      tile.biome = BiomeType.mountain;
    }
  }

  static void _placeMinerals(MapGrid grid, int seed, ResourceAbundance abundance) {
    final rand = Random(seed);
    double threshold = 0.98; // Por defecto medio
    if (abundance == ResourceAbundance.low) threshold = 0.99;
    if (abundance == ResourceAbundance.high) threshold = 0.97;

    for (int x = 0; x < grid.width; x++) {
      for (int y = 0; y < grid.height; y++) {
        final tile = grid.getTile(x, y);
        if (tile.biome == BiomeType.grass || tile.biome == BiomeType.desert) {
          if (rand.nextDouble() > threshold) {
            final typeRoll = rand.nextDouble();
            ResourceType type;
            if (typeRoll < 0.4) {
              type = ResourceType.stone;
            } else if (typeRoll < 0.7) {
              type = ResourceType.coal;
            } else {
              type = ResourceType.gold;
            }
            tile.resource = Resource(type: type, amount: rand.nextInt(500) + 500, isPassable: false);
          }
        }
      }
    }
  }

  static void _placeForests(MapGrid grid, int seed, ResourceAbundance abundance) {
    final forestNoise = buildNoise(
      seed: seed + 1,
      frequency: 0.04, // Reducida la frecuencia para blobs más grandes
      noiseType: NoiseType.perlin,
    );

    double threshold = 0.15; // Bajado el umbral para bosques más densos
    if (abundance == ResourceAbundance.low) threshold = 0.3;
    if (abundance == ResourceAbundance.high) threshold = 0.05;

    for (int x = 0; x < grid.width; x++) {
      for (int y = 0; y < grid.height; y++) {
        final tile = grid.getTile(x, y);
        if (tile.biome == BiomeType.grass && tile.resource == null) {
          final val = forestNoise.getNoise2(x.toDouble(), y.toDouble());
          if (val > threshold) {
            tile.resource = Resource(
              type: ResourceType.wood,
              amount: 1000,
              isPassable: false, // Los bosques bloquean el paso
            );
          }
        }
      }
    }
  }

  static void _placeBaseLocations(MapGrid grid) {
    // Definimos 8 puntos aproximados en círculos o esquinas
    final w = grid.width;
    final h = grid.height;
    final margin = 5;

    final basePoints = [
      Point(margin, margin),
      Point(w - margin - 1, margin),
      Point(margin, h - margin - 1),
      Point(w - margin - 1, h - margin - 1),
      Point(w ~/ 2, margin),
      Point(w ~/ 2, h - margin - 1),
      Point(margin, h ~/ 2),
      Point(w - margin - 1, h ~/ 2),
    ];

    // Mezclamos para que el jugador 0 aparezca en un lugar aleatorio distinto cada vez
    basePoints.shuffle(Random());

    final baseColors = [
      Colors.blue, Colors.red, Colors.green, Colors.yellow,
      Colors.purple, Colors.orange, Colors.cyan, Colors.pink
    ];

    for (int i = 0; i < basePoints.length; i++) {
      final p = basePoints[i];
      final bx = p.x.toInt();
      final by = p.y.toInt();

      // Limpiar un radio de 3 tiles alrededor de la base para que las unidades puedan moverse
      for (int dx = -3; dx <= 3; dx++) {
        for (int dy = -3; dy <= 3; dy++) {
          final nx = bx + dx;
          final ny = by + dy;
          if (nx >= 0 && nx < grid.width && ny >= 0 && ny < grid.height) {
            final t = grid.getTile(nx, ny);
            t.biome = BiomeType.grass;
            t.resource = null;
          }
        }
      }

      final tile = grid.getTile(bx, by);
      tile.isBaseLocation = true;

      // Colocar Centro Urbano inicial
      tile.building = Building.urbanCenter(
        color: baseColors[i],
        playerId: i,
        x: bx,
        y: by,
      );

      // Asegurar recursos cerca (fuera del radio limpio)
      _ensureStarterResources(grid, bx, by);
    }
  }

  static void _ensureStarterResources(MapGrid grid, int bx, int by) {
    // Colocar un poco de madera y oro cerca de la base pero fuera del radio limpio (r=3)
    final directions = [
      Point(1, 0), Point(-1, 0), Point(0, 1), Point(0, -1),
      Point(1, 1), Point(-1, -1), Point(1, -1), Point(-1, 1)
    ];

    final rand = Random();
    for (int i = 0; i < 4; i++) {
        final d = directions[rand.nextInt(directions.length)];
        final dist = 4 + rand.nextInt(2); // 4 o 5 tiles de distancia
        final tx = bx + d.x.toInt() * dist;
        final ty = by + d.y.toInt() * dist;

        if (tx >= 0 && tx < grid.width && ty >= 0 && ty < grid.height) {
            final tile = grid.getTile(tx, ty);
            if (tile.building == null) {
              tile.biome = BiomeType.grass;
              tile.resource = Resource(
                  type: (i % 2 == 0) ? ResourceType.wood : ResourceType.gold,
                  amount: 500,
                  isPassable: false,
              );
            }
        }
    }
  }
}
