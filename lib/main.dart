import 'package:flutter/material.dart';
import 'widgets/game_screen.dart';

import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(RTSApp());
}

class RTSApp extends StatelessWidget {
  const RTSApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RTS Isometric Map',
      theme: ThemeData(
        primarySwatch: Colors.green,
        brightness: Brightness.dark,
      ),
      home: GameScreen(),
    );
  }
}
