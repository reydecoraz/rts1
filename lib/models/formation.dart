import 'dart:math';
import 'package:flutter/material.dart';
import 'unit.dart';

/// Holds the shared marching state for a group of units moving in formation.
/// All members follow a single anchor point that walks a shared A* path
/// at the speed of the slowest unit. Each unit holds a [formationOffset]
/// (dx, dy) relative to the anchor.
class FormationGroup {
  /// The units currently part of this formation.
  final List<Unit> members;

  /// Per-unit formation offsets (index matches [members]).
  final List<Offset> offsets;

  /// The shared A* path for the anchor.
  List<Offset> anchorPath;

  /// Current continuous position of the anchor.
  double anchorX;
  double anchorY;

  /// Shared speed — set to the slowest member's movementSpeed.
  double speed;

  FormationGroup({
    required this.members,
    required this.offsets,
    required this.anchorPath,
    required this.anchorX,
    required this.anchorY,
    required this.speed,
  });

  bool get isActive => anchorPath.isNotEmpty || _notAllArrived;

  bool get _notAllArrived {
    for (final u in members) {
      final dx = u.x - (anchorX + offsets[members.indexOf(u)].dx);
      final dy = u.y - (anchorY + offsets[members.indexOf(u)].dy);
      if (sqrt(dx * dx + dy * dy) > 0.2) return true;
    }
    return false;
  }

  /// Advance the anchor along its path by [dt] seconds.
  /// Returns whether the anchor is still moving.
  bool tickAnchor(double dt) {
    if (anchorPath.isEmpty) return false;

    final target = anchorPath.first;
    final dx = target.dx - anchorX;
    final dy = target.dy - anchorY;
    final dist = sqrt(dx * dx + dy * dy);

    if (dist < 0.1) {
      anchorX = target.dx;
      anchorY = target.dy;
      anchorPath.removeAt(0);
      return anchorPath.isNotEmpty;
    }

    final step = speed * dt;
    if (step >= dist) {
      anchorX = target.dx;
      anchorY = target.dy;
      anchorPath.removeAt(0);
    } else {
      anchorX += (dx / dist) * step;
      anchorY += (dy / dist) * step;
    }
    return true;
  }

  /// Move each member unit toward its (anchor + offset) position.
  void applyToUnits(double dt) {
    for (int i = 0; i < members.length; i++) {
      final u = members[i];
      // Units that are fighting or dead break out of formation naturally
      if (u.state == UnitState.dead || u.targetUnit != null) continue;

      final targetX = anchorX + offsets[i].dx;
      final targetY = anchorY + offsets[i].dy;
      final dx = targetX - u.x;
      final dy = targetY - u.y;
      final dist = sqrt(dx * dx + dy * dy);

      if (dist < 0.1) {
        u.x = targetX;
        u.y = targetY;
        if (anchorPath.isEmpty) {
          u.state = UnitState.idle;
          u.currentPath.clear();
        } else {
          u.state = UnitState.moving;
        }
      } else {
        // Move unit toward its formation slot at its own speed (can be faster
        // than anchor to catch up if lagging), but cap at 1.5× anchor speed
        // so units run to catch up rather than teleport.
        final catchUpSpeed = min(u.currentStats.movementSpeed, speed * 1.5);
        final step = catchUpSpeed * dt;
        if (step >= dist) {
          u.x = targetX;
          u.y = targetY;
        } else {
          u.x += (dx / dist) * step;
          u.y += (dy / dist) * step;
        }
        u.state = UnitState.moving;
        // Clear any individual A* path since we're steering directly
        u.currentPath.clear();
      }
    }
  }

  /// Remove a unit from the formation (e.g., when it starts attacking).
  void removeMember(Unit u) {
    final idx = members.indexOf(u);
    if (idx == -1) return;
    members.removeAt(idx);
    offsets.removeAt(idx);
    u.formationGroup = null;
  }

  /// true if no living members remain.
  bool get isEmpty => members.every((u) => u.state == UnitState.dead);
}
