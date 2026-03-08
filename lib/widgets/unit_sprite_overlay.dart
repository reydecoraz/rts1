import 'dart:async';
import 'package:flutter/material.dart';
import '../models/unit.dart';
import '../models/map_grid.dart';
import '../utils/constants.dart';

// ─── Sprite Definition ────────────────────────────────────────────────────────

class _SpriteFrame {
  final String asset;
  const _SpriteFrame(this.asset);
}

enum _IsoDir { south, southEast, southWest, east, west, north }

// ─── Sprite Map ───────────────────────────────────────────────────────────────

const _base = 'assets/units/infanteria/';

final _infantrySprites = <UnitState, Map<_IsoDir, List<_SpriteFrame>>>{
  UnitState.idle: {
    _IsoDir.south:     [_SpriteFrame('${_base}soldado_inferior_quiero.png'),   _SpriteFrame('${_base}soldado_inferior_quiero.png')],
    _IsoDir.southEast: [_SpriteFrame('${_base}soldado_inferior_derecha_quiero.png'), _SpriteFrame('${_base}soldado_inferior_derecha_quiero.png')],
    _IsoDir.southWest: [_SpriteFrame('${_base}soldado_inferior_izquierda_quieto.png'), _SpriteFrame('${_base}soldado_inferior_izquierda_quieto.png')],
    _IsoDir.east:      [_SpriteFrame('${_base}soldado_inferior_derecha_quiero.png'), _SpriteFrame('${_base}soldado_inferior_derecha_quiero.png')],
    _IsoDir.west:      [_SpriteFrame('${_base}soldado_inferior_izquierda_quieto.png'), _SpriteFrame('${_base}soldado_inferior_izquierda_quieto.png')],
    _IsoDir.north:     [_SpriteFrame('${_base}soldado_superior_quieto.png'),   _SpriteFrame('${_base}soldado_superior_quieto.png')],
  },
  UnitState.moving: {
    _IsoDir.south:     [_SpriteFrame('${_base}soldado_inferior_quiero.png'),   _SpriteFrame('${_base}soldado_inferior_derecha_quiero.png')],
    _IsoDir.southEast: [_SpriteFrame('${_base}soldado_derecha_caminando.png'), _SpriteFrame('${_base}soldado_inferior_derecha_quiero.png')],
    _IsoDir.southWest: [_SpriteFrame('${_base}soldado_izquierda_caminando.png'), _SpriteFrame('${_base}soldado_inferior_izquierda_quieto.png')],
    _IsoDir.east:      [_SpriteFrame('${_base}soldado_derecha_caminando.png'), _SpriteFrame('${_base}soldado_inferior_derecha_quiero.png')],
    _IsoDir.west:      [_SpriteFrame('${_base}soldado_izquierda_caminando.png'), _SpriteFrame('${_base}soldado_inferior_izquierda_quieto.png')],
    _IsoDir.north:     [_SpriteFrame('${_base}soldado_superior_quieto.png'),   _SpriteFrame('${_base}soldado_inferior_quiero.png')],
  },
  UnitState.attacking: {
    _IsoDir.south:     [_SpriteFrame('${_base}soldado_inferior_derecha_ataca.png'), _SpriteFrame('${_base}soldado_inferior_quiero.png')],
    _IsoDir.southEast: [_SpriteFrame('${_base}soldado_inferior_derecha_ataca.png'), _SpriteFrame('${_base}soldado_inferior_derecha_quiero.png')],
    _IsoDir.southWest: [_SpriteFrame('${_base}soldado_inferior_izquierda_ataca.png'), _SpriteFrame('${_base}soldado_inferior_izquierda_quieto.png')],
    _IsoDir.east:      [_SpriteFrame('${_base}soldado_derecha_ataca.png'),     _SpriteFrame('${_base}soldado_inferior_derecha_quiero.png')],
    _IsoDir.west:      [_SpriteFrame('${_base}soldado_izquierda_ataca.png'),   _SpriteFrame('${_base}soldado_inferior_izquierda_quieto.png')],
    _IsoDir.north:     [_SpriteFrame('${_base}soldado_derecha_ataca.png'),     _SpriteFrame('${_base}soldado_superior_quieto.png')],
  },
};

// Non-infantry fallback states still need to be in the map even if unused
const _deadFrames = <_IsoDir, List<_SpriteFrame>>{
  _IsoDir.south: [_SpriteFrame('')],
};

// ─── Direction Helper ─────────────────────────────────────────────────────────

_IsoDir _dirFromMovement(double dx, double dy) {
  if (dx.abs() < 0.3 && dy > 0) return _IsoDir.south;
  if (dx.abs() < 0.3 && dy < 0) return _IsoDir.north;
  if (dx > 0 && dy >= 0) return _IsoDir.southEast;
  if (dx > 0 && dy < 0) return _IsoDir.east;
  if (dx < 0 && dy >= 0) return _IsoDir.southWest;
  return _IsoDir.west;
}

// ─── Single Unit Sprite ───────────────────────────────────────────────────────

class _UnitSprite extends StatelessWidget {
  final Unit unit;
  final double screenX;
  final double screenY;
  final bool isSelected;
  final Color tintColor;

  const _UnitSprite({
    required Key key,
    required this.unit,
    required this.screenX,
    required this.screenY,
    required this.isSelected,
    required this.tintColor,
  }) : super(key: key);

  static const double _w = 50.0;
  static const double _h = 58.0;

  _IsoDir _calculateDir() {
    if (unit.state == UnitState.moving && unit.currentPath.isNotEmpty) {
      final next = unit.currentPath.first;
      final dx = next.dx - unit.x;
      final dy = next.dy - unit.y;
      return _dirFromMovement(dx, dy);
    } else if (unit.state == UnitState.attacking) {
      final tu = unit.targetUnit;
      final tb = unit.targetBuilding;
      final tx = tu?.x ?? tb?.x.toDouble();
      final ty = tu?.y ?? tb?.y.toDouble();
      if (tx != null && ty != null) {
        return _dirFromMovement(tx - unit.x, ty - unit.y);
      }
    }
    return _IsoDir.south;
  }

  @override
  Widget build(BuildContext context) {
    if (unit.state == UnitState.dead) return const SizedBox.shrink();

    // ── Static Frame Calculation (No Timers!) ──────────────────
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int duration = unit.state == UnitState.attacking ? 260 : 400;
    final int frame = (now ~/ duration) % 2;

    final dir = _calculateDir();
    final effectiveState = unit.state;
    final stateMap = _infantrySprites[effectiveState] ?? _deadFrames;
    final frames = stateMap[dir] ?? stateMap[_IsoDir.south] ?? [const _SpriteFrame('')];
    
    if (frames.isEmpty) return const SizedBox.shrink();
    final asset = frames[frame % frames.length].asset;
    if (asset.isEmpty) return const SizedBox.shrink();

    final double ratio = (unit.currentHealth / unit.currentStats.maxHealth).clamp(0.0, 1.0);
    final bool showHp = true; // Siempre mostrar para ver la reducción por armadura

    return Positioned(
      left: screenX - _w / 2,
      top: screenY - _h,
      child: SizedBox(
        width: _w,
        height: _h + 6, // +6 for HP bar
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Selection ring under feet
            if (isSelected)
              Positioned(
                bottom: 6,
                child: Container(
                  width: 28,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.greenAccent, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3)],
                  ),
                ),
              ),
            // Sprite image
            Positioned(
              bottom: 6,
              child: ColorFiltered(
                colorFilter: tintColor == Colors.transparent
                    ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                    : ColorFilter.mode(tintColor, BlendMode.srcATop),
                child: Image.asset(
                  asset,
                  width: _w,
                  height: _h,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ),
            // HP bar
            if (showHp)
              Positioned(
                top: 0,
                left: 4,
                right: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: Colors.black54,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ratio > 0.6 ? Colors.greenAccent : (ratio > 0.3 ? Colors.orange : Colors.red),
                    ),
                    minHeight: 3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Color Palette (matches isometric renderer) ───────────────────────────────
const _palette = [
  Colors.transparent,       // Player 0: no tint
  Color(0x55FF0000),        // Player 1: red tint
  Color(0x5500CC00),        // Player 2: green tint
  Color(0x55AA00FF),        // Player 3: purple tint
  Color(0x55FF8800),        // Player 4: orange tint
  Color(0x5500AAAA),        // Player 5: teal tint
  Color(0x55CCCC00),        // Player 6: yellow tint
  Color(0x55FF44AA),        // Player 7: pink tint
];

Color _playerTint(int playerId) {
  if (playerId < _palette.length) return _palette[playerId];
  return const Color(0x55888888);
}

// ─── Overlay ─────────────────────────────────────────────────────────────────

/// Transparent overlay positioned over the isometric map that renders
/// infantry sprites with frame-based animation.
class InfantryUnitOverlay extends StatelessWidget {
  final List<Unit> units;
  final List<Unit> selectedUnits;
  final MapGrid grid;

  const InfantryUnitOverlay({
    super.key,
    required this.units,
    required this.selectedUnits,
    required this.grid,
  });

  double _sx(double gx, double gy) {
    final offsetX = (grid.width * MapConstants.tileWidth) / 2.0;
    return (gx - gy) * (MapConstants.tileWidth / 2.0) + offsetX;
  }

  double _sy(double gx, double gy) {
    return (gx + gy) * (MapConstants.tileHeight / 2.0) + MapConstants.tileHeight / 2.0;
  }

  @override
  Widget build(BuildContext context) {
    final visible = units.where((u) =>
      u.state != UnitState.dead &&
      (u.category == UnitCategory.infantry || u.category == UnitCategory.worker)
    ).toList();

    return Stack(
      clipBehavior: Clip.none,
      children: visible.map((u) => _UnitSprite(
        key: ValueKey(u.id),
        unit: u,
        screenX: _sx(u.x, u.y),
        screenY: _sy(u.x, u.y),
        isSelected: selectedUnits.contains(u),
        tintColor: _playerTint(u.playerId),
      )).toList(),
    );
  }
}
