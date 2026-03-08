import 'dart:async';
import 'package:flutter/material.dart';
import '../models/civilization.dart';
import '../services/data_manager.dart';
import '../services/game_session.dart';
import '../models/hero.dart';
import '../data/unit_data.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  Civilization? _selectedCiv;
  HeroData? _selectedHero;
  int _countdown = 20;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final civs = DataManager().getAllCivilizations();
    if (civs.isNotEmpty) {
      _selectedCiv = civs.first;
      _updateDefaultHero();
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

  void _updateDefaultHero() {
    if (_selectedCiv != null && _selectedCiv!.availableHeroes.isNotEmpty) {
      String heroId = _selectedCiv!.availableHeroes.contains('hero_julius_caesar') 
          ? 'hero_julius_caesar' 
          : _selectedCiv!.availableHeroes.first;
      _selectedHero = DataManager().getHero(heroId);
    } else {
      _selectedHero = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    if (_selectedCiv != null) {
      GameSession().activeCivilizationId = _selectedCiv!.id;
      GameSession().activeHeroId = _selectedHero?.id;
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
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber[700]!, width: 2),
            ),
            child: Column(
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "SALA DE ESPERA 1v1",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.timer, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "00:${_countdown.toString().padLeft(2, '0')}",
                          style: TextStyle(
                            color: _countdown <= 5 ? Colors.redAccent : Colors.amber,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 32),
                
                // Main Layout
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Civ selection
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("1. CIVILIZACIÓN", style: TextStyle(color: Colors.amber[200], fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.builder(
                                itemCount: civs.length,
                                itemBuilder: (context, index) {
                                  final civ = civs[index];
                                  final isSelected = _selectedCiv?.id == civ.id;
                                  return Card(
                                    color: isSelected ? Colors.blue[900] : Colors.blueGrey[800],
                                    child: ListTile(
                                      title: Text(civ.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      onTap: () {
                                        setState(() {
                                          _selectedCiv = civ;
                                          _updateDefaultHero();
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
                      const SizedBox(width: 16),
                      
                      // 2. Hero selection
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("2. HÉROE LIDER", style: TextStyle(color: Colors.amber[200], fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            if (_selectedCiv == null)
                              const Expanded(child: Center(child: Text("Selecciona Civ", style: TextStyle(color: Colors.white54))))
                            else
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _selectedCiv!.availableHeroes.length,
                                  itemBuilder: (context, index) {
                                    final heroId = _selectedCiv!.availableHeroes[index];
                                    final hero = DataManager().getHero(heroId);
                                    if (hero == null) return const SizedBox.shrink();

                                    final isOwned = hero.id == 'hero_julius_caesar';
                                    final isSelected = _selectedHero?.id == hero.id;

                                    return Card(
                                      color: !isOwned ? Colors.grey[800] : (isSelected ? Colors.amber[900] : Colors.blueGrey[800]),
                                      child: ListTile(
                                        leading: Icon(isOwned ? Icons.star : Icons.lock, color: isOwned ? Colors.amber : Colors.white24),
                                        title: Text(hero.name, style: TextStyle(color: isOwned ? Colors.white : Colors.white24, fontWeight: FontWeight.bold)),
                                        onTap: isOwned ? () {
                                          setState(() => _selectedHero = hero);
                                        } : null,
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // 3. Details
                      Expanded(
                        flex: 3,
                        child: _selectedCiv == null
                            ? const Center(child: Text("Selecciona para ver detalles", style: TextStyle(color: Colors.white54)))
                            : Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_selectedCiv!.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text(_selectedCiv!.description, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                      const SizedBox(height: 16),
                                      const Text("Bonos de Civilización:", style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
                                      ..._selectedCiv!.bonuses.map((b) => Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text("• ${b.description}", style: const TextStyle(color: Colors.white, fontSize: 11)),
                                      )),
                                      if (_selectedHero != null) ...[
                                        const SizedBox(height: 16),
                                        const Divider(color: Colors.white24),
                                        const SizedBox(height: 8),
                                        Text(_selectedHero!.name, style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(_selectedHero!.lore, style: const TextStyle(color: Colors.white60, fontSize: 11, fontStyle: FontStyle.italic)),
                                        const SizedBox(height: 12),
                                        const Text("Bonos de Héroe:", style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
                                        ..._selectedHero!.globalBonuses.map((b) => Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text("• ${b.description}", style: const TextStyle(color: Colors.white, fontSize: 11)),
                                        )),
                                        if (_selectedHero!.uniqueUnits.isNotEmpty)
                                          const Padding(
                                            padding: EdgeInsets.only(top: 8),
                                            child: Text("★ Unidad Única desbloqueada", style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                
                // Footer
                const SizedBox(height: 16),
                const Text(
                  "La partida iniciará automáticamente...",
                  style: TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
