import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'sync.dart';

/// Punto de entrada de la tarea en segundo plano (Android la ejecuta cada ~15 min).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await Sync.cicloCompleto();
    } catch (_) {}
    return true;
  });
}

Future<void> programarSync() async {
  await Workmanager().registerPeriodicTask(
    'finanzas-sync',
    'sync',
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.connected),
  );
}
