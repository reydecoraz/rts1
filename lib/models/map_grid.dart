import 'tile.dart';

enum ResourceAbundance { low, medium, high }

class MapGrid {
  final int width;
  final int height;
  final List<List<Tile>> tiles;
  final int seed;
  final ResourceAbundance abundance;

  MapGrid({
    required this.width,
    required this.height,
    required this.seed,
    this.abundance = ResourceAbundance.medium,
  }) : tiles = List.generate(
          width,
          (x) => List.generate(
            height,
            (y) => Tile(x: x, y: y),
          ),
        );

  Tile getTile(int x, int y) {
    return tiles[x][y];
  }

  bool isValid(int x, int y) {
    return x >= 0 && x < width && y >= 0 && y < height;
  }
}
