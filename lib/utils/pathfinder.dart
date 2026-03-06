import 'dart:math';
import 'package:flutter/material.dart';
import '../models/map_grid.dart';
import '../models/tile.dart';

class PathNode {
  final int x;
  final int y;
  int gCost;
  int hCost;
  PathNode? parent;

  PathNode(this.x, this.y) : gCost = 0, hCost = 0;

  int get fCost => gCost + hCost;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PathNode && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

class AStarPathfinder {
  static List<Offset> findPath(MapGrid grid, Point<int> startPos, Point<int> targetPos) {
    if (startPos.x < 0 || startPos.x >= grid.width || startPos.y < 0 || startPos.y >= grid.height) return [];
    
    Point<int> endPos = targetPos;
    Tile? endTile;
    
    if (endPos.x >= 0 && endPos.x < grid.width && endPos.y >= 0 && endPos.y < grid.height) {
      endTile = grid.getTile(endPos.x, endPos.y);
      if (!endTile.isWalkable) {
         final nearest = _findNearestWalkable(grid, startPos, endPos);
         if (nearest == null) return [];
         endPos = Point(nearest.x, nearest.y);
      }
    } else {
       return [];
    }

    if (startPos == endPos) return [];

    List<PathNode> openList = [];
    Set<Point<int>> closedSet = {};

    PathNode startNode = PathNode(startPos.x, startPos.y);
    PathNode endNode = PathNode(endPos.x, endPos.y);

    openList.add(startNode);

    int maxIterations = 2000;
    int iterations = 0;

    while (openList.isNotEmpty && iterations < maxIterations) {
      iterations++;
      
      // Obtener nodo con menor fCost (Usar sort en vez de PriorityQueue para simplificar)
      openList.sort((a, b) {
        int result = a.fCost.compareTo(b.fCost);
        if (result == 0) {
          return a.hCost.compareTo(b.hCost);
        }
        return result;
      });
      
      PathNode currentNode = openList.removeAt(0);
      closedSet.add(Point(currentNode.x, currentNode.y));

      if (currentNode.x == endNode.x && currentNode.y == endNode.y) {
         return _retracePath(startNode, currentNode);
      }

      final neighbors = _getNeighbors(grid, currentNode);
      for (var neighbor in neighbors) {
         if (closedSet.contains(Point(neighbor.x, neighbor.y))) continue;

         Tile neighborTile = grid.getTile(neighbor.x, neighbor.y);
         if (!neighborTile.isWalkable) continue;

         // Check diagonales (no cortar esquinas unwalkables)
         if (currentNode.x != neighbor.x && currentNode.y != neighbor.y) {
           Tile n1 = grid.getTile(currentNode.x, neighbor.y);
           Tile n2 = grid.getTile(neighbor.x, currentNode.y);
           if (!n1.isWalkable || !n2.isWalkable) {
              continue; // Esquina bloqueada
           }
         }

         int moveCost = (currentNode.x != neighbor.x && currentNode.y != neighbor.y) ? 14 : 10;
         int tentativeGCost = currentNode.gCost + moveCost;

         PathNode? existingNeighbor;
         try {
           existingNeighbor = openList.firstWhere((n) => n.x == neighbor.x && n.y == neighbor.y);
         } catch (e) {
           existingNeighbor = null;
         }

         if (existingNeighbor != null) {
            if (tentativeGCost < existingNeighbor.gCost) {
               existingNeighbor.gCost = tentativeGCost;
               existingNeighbor.parent = currentNode;
            }
         } else {
            neighbor.gCost = tentativeGCost;
            neighbor.hCost = _getDistance(neighbor, endNode);
            neighbor.parent = currentNode;
            openList.add(neighbor);
         }
      }
    }

    return []; // Path not found
  }

  static List<PathNode> _getNeighbors(MapGrid grid, PathNode node) {
     List<PathNode> neighbors = [];
     for (int x = -1; x <= 1; x++) {
       for (int y = -1; y <= 1; y++) {
         if (x == 0 && y == 0) continue;
         int checkX = node.x + x;
         int checkY = node.y + y;

         if (checkX >= 0 && checkX < grid.width && checkY >= 0 && checkY < grid.height) {
             neighbors.add(PathNode(checkX, checkY));
         }
       }
     }
     return neighbors;
  }

  static int _getDistance(PathNode nodeA, PathNode nodeB) {
     int dstX = (nodeA.x - nodeB.x).abs();
     int dstY = (nodeA.y - nodeB.y).abs();
     if (dstX > dstY) return 14 * dstY + 10 * (dstX - dstY);
     return 14 * dstX + 10 * (dstY - dstX);
  }

  static List<Offset> _retracePath(PathNode start, PathNode end) {
     List<PathNode> path = [];
     PathNode? current = end;
     while (current != null && current != start) {
       path.add(current);
       current = current.parent;
     }
     path = path.reversed.toList();
     return path.map((n) => Offset(n.x.toDouble(), n.y.toDouble())).toList();
  }

  static Tile? _findNearestWalkable(MapGrid grid, Point<int> start, Point<int> target) {
     int radius = 1;
     Tile? bestTile;
     double minDistance = double.infinity;
     
     while (radius <= 5) {
        for (int x = -radius; x <= radius; x++) {
          for (int y = -radius; y <= radius; y++) {
             if (x.abs() == radius || y.abs() == radius) {
                int checkX = target.x + x;
                int checkY = target.y + y;
                if (checkX >= 0 && checkX < grid.width && checkY >= 0 && checkY < grid.height) {
                   Tile tile = grid.getTile(checkX, checkY);
                   if (tile.isWalkable) {
                      double dist = sqrt(pow(checkX - start.x, 2) + pow(checkY - start.y, 2));
                      if (dist < minDistance) {
                         minDistance = dist;
                         bestTile = tile;
                      }
                   }
                }
             }
          }
        }
        if (bestTile != null) return bestTile;
        radius++;
     }
     return null;
  }
}
