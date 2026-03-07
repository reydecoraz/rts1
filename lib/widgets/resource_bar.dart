import 'package:flutter/material.dart';
import '../services/game_session.dart';

class ResourceBar extends StatelessWidget {
  const ResourceBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: ListenableBuilder(
        listenable: GameSession(),
        builder: (context, _) {
          final session = GameSession();
          final bool popFull = session.currentPopulation >= session.maxPopulation;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _res(Icons.forest, session.wood, Colors.brown[300]!),
              _sep(),
              _res(Icons.restaurant, session.food, Colors.green[300]!),
              _sep(),
              _res(Icons.monetization_on, session.gold, Colors.yellow[300]!),
              _sep(),
              _res(Icons.landscape, session.stone, Colors.grey[400]!),
              _sep(),
              _res(Icons.terrain, session.coal, Colors.grey[700]!),
              _sep(),
              // Population badge
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people, size: 14, color: popFull ? Colors.orange[300] : Colors.lightBlue[300]),
                  const SizedBox(width: 3),
                  Text(
                    '${session.currentPopulation}/${session.maxPopulation}',
                    style: TextStyle(
                      color: popFull ? Colors.orange[300] : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sep() => const SizedBox(width: 12);

  Widget _res(IconData icon, int amount, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$amount',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
          ),
        ),
      ],
    );
  }
}
