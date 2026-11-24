import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notificaciones nativas del teléfono (sin Telegram ni servidores).
class Notificar {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _listo = false;

  static Future<void> init() async {
    if (_listo) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    _listo = true;
  }

  static Future<bool> pedirPermiso() async {
    await init();
    final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return (await a?.requestNotificationsPermission()) ?? false;
  }

  static Future<void> mostrar(String titulo, String cuerpo) async {
    await init();
    final detalles = NotificationDetails(
      android: AndroidNotificationDetails(
        'finanzas',
        'Finanzas',
        channelDescription: 'Gastos, alertas de tope y cierres',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(cuerpo),
      ),
    );
    final id = DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;
    await _plugin.show(id, titulo, cuerpo, detalles);
  }
}
