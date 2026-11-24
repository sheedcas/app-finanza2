import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'core/background.dart';
import 'core/notificar.dart';
import 'ui/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notificar.init();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    const semilla = Color(0xFF1E88E5);
    return MaterialApp(
      title: 'Finanzas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: semilla, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: semilla, brightness: Brightness.dark, useMaterial3: true),
      home: const Home(),
    );
  }
}
