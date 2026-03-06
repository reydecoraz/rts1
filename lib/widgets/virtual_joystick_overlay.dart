import 'package:flutter/material.dart';

/// Small helper class to match the signature needed by the game screen
class StickDragDetails {
  final double x;
  final double y;
  StickDragDetails(this.x, this.y);
}

class VirtualJoystickOverlay extends StatefulWidget {
  final Function(StickDragDetails) onDirectionChanged;

  const VirtualJoystickOverlay({
    super.key,
    required this.onDirectionChanged,
  });

  @override
  State<VirtualJoystickOverlay> createState() => _VirtualJoystickOverlayState();
}

class _VirtualJoystickOverlayState extends State<VirtualJoystickOverlay> {
  Offset? _centerPoint;
  Offset? _currentPoint;
  static const double _maxRadius = 50.0;

  @override
  Widget build(BuildContext context) {
    // The touch area is a transparent container in the bottom-left
    return Positioned(
      bottom: 0,
      left: 0,
      child: Listener(
        onPointerDown: (event) {
          setState(() {
            _centerPoint = event.localPosition;
            _currentPoint = event.localPosition;
          });
        },
        onPointerMove: (event) {
          if (_centerPoint == null) return;
          setState(() {
            _currentPoint = event.localPosition;
          });
          
          final delta = _currentPoint! - _centerPoint!;
          final distance = delta.distance;
          final cappedDistance = distance.clamp(0.0, _maxRadius);
          
          final normalizedX = distance > 0 ? (delta.dx / distance) * (cappedDistance / _maxRadius) : 0.0;
          final normalizedY = distance > 0 ? (delta.dy / distance) * (cappedDistance / _maxRadius) : 0.0;
          
          widget.onDirectionChanged(StickDragDetails(normalizedX, normalizedY));
        },
        onPointerUp: (_) {
          setState(() {
            _centerPoint = null;
            _currentPoint = null;
          });
          widget.onDirectionChanged(StickDragDetails(0, 0));
        },
        child: Container(
          width: 120,
          height: 150,
          color: Colors.transparent, // Activation zone
          child: Stack(
            children: [
              if (_centerPoint != null)
                Positioned(
                  left: _centerPoint!.dx - 50,
                  top: _centerPoint!.dy - 50,
                  child: _buildJoystickVisual(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJoystickVisual() {
    final delta = _currentPoint! - _centerPoint!;
    final distance = delta.distance;
    final cappedDistance = distance.clamp(0.0, _maxRadius);
    final stickOffset = distance > 0 ? (delta / distance) * cappedDistance : Offset.zero;

    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white10,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
          ),
          // Stick
          Transform.translate(
            offset: stickOffset,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
