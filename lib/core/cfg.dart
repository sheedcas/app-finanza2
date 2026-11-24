import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Credenciales cifradas en el teléfono (Android Keystore).
class Cfg {
  static const _s = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  static Future<String> get(String k, [String defecto = '']) async {
    try {
      return (await _s.read(key: k)) ?? defecto;
    } catch (_) {
      return defecto;
    }
  }

  static Future<void> set(String k, String v) async {
    await _s.write(key: k, value: v);
  }
}
