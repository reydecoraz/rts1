import 'dart:async';
import 'package:flutter/material.dart';
import '../models/civilization.dart';
import '../services/data_manager.dart';
import '../services/game_session.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  Civilization? _selectedCiv;
  int _countdown = 20;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final civs = DataManager().getAllCivilizations();
    if (civs.isNotEmpty) {
      _selectedCiv = civs.first;
    }
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _timer?.cancel();
          _startGame();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    if (_selectedCiv != null) {
      GameSession().activeCivilizationId = _selectedCiv!.id;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const GameScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final civs = DataManager().getAllCivilizations();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: Colors.blueGrey[900],
          image: const DecorationImage(
            image: AssetImage('assets/images/ui/main_bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black87, BlendMode.darken),
          ),
        ),
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber[700]!, width: 2),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "SALA DE ESPERA 1v1",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.timer, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          "00:${_countdown.toString().padLeft(2, '0')}",
                          style: TextStyle(
                            color: _countdown <= 5 ? Colors.redAccent : Colors.amber[400],
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 16, thickness: 1),
                Expanded(
                  child: Row(
                    children: [
                      // Left: Civilization List
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "SELECCIONA TU CIVILIZACIÓN",
                              style: TextStyle(color: Colors.amber[200], fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.builder(
                                itemCount: civs.length,
                                itemBuilder: (context, index) {
                                  final civ = civs[index];
                                  final isSelected = _selectedCiv?.id == civ.id;
                                  return Card(
                                    color: isSelected ? Colors.amber[900] : Colors.blueGrey[800],
                                    shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                        color: isSelected ? Colors.amber[400]! : Colors.transparent,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: civ.primaryColor,
                                        child: const Icon(Icons.public, color: Colors.white),
                                      ),
                                      title: Text(
                                        civ.name,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                      selected: isSelected,
                                      onTap: () {
                                        setState(() {
                                          _selectedCiv = civ;
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right: Civilization Details
                      Expanded(
                        flex: 3,
                        child: _selectedCiv == null
                            ? const Center(child: Text("Selecciona una civilización", style: TextStyle(color: Colors.white)))
                            : Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: _selectedCiv!.primaryColor,
                                          child: const Icon(Icons.shield, color: Colors.white, size: 20),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _selectedCiv!.name,
                                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _selectedCiv!.description,
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      "Bonificaciones:",
                                      style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    ..._selectedCiv!.bonuses.map((b) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.star, color: Colors.amber, size: 14),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              b.description,
                                              style: const TextStyle(color: Colors.white, fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                    const Spacer(),
                                    const Center(
                                      child: Text(
                                        "La partida iniciará automáticamente...",
                                        style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic, fontSize: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
