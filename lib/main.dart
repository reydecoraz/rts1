import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/main_menu_screen.dart';
import 'services/data_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DataManager().loadAllData();
  
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const RTSApp());
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
      home: const MainMenuScreen(),
    );
  }
}
