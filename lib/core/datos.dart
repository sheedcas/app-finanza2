import 'package:sqflite/sqflite.dart';

import 'consts.dart';
import 'db.dart';
import 'models.dart';
import 'util.dart';

class Repo {
  static Future<Database> get _db => Db.get();

  // ───── meta / lock / alertas ─────
  static Future<String?> getMeta(String k) async {
    final r = await (await _db).query('meta', where: 'clave=?', whereArgs: [k]);
    return r.isEmpty ? null : r.first['valor'] as String?;
  }

  static Future<void> setMeta(String k, String v) async {
    await (await _db).insert('meta', {'clave': k, 'valor': v}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Evita que la app y la tarea en segundo plano sincronicen a la vez.
  static Future<bool> tomarLock() async {
    final ts = int.tryParse(await getMeta('lock_ts') ?? '0') ?? 0;
    final ahora = DateTime.now().millisecondsSinceEpoch;
    if (ahora - ts < 5 * 60 * 1000) return false;
    await setMeta('lock_ts', '$ahora');
    return true;
  }

  static Future<void> soltarLock() async {
    await setMeta('lock_ts', '0');
  }

  /// true si esta alerta aún no se había enviado.
  static Future<bool> alertaNueva(String clave) async {
    final db = await _db;
    final r = await db.query('alertas_enviadas', where: 'clave=?', whereArgs: [clave]);
    if (r.isNotEmpty) return false;
    await db.insert('alertas_enviadas', {'clave': clave, 'fecha': iso(DateTime.now())});
    return true;
  }

  // ───── movimientos ─────
  static Future<List<Mov>> todos() async {
    final r = await (await _db).query('movimientos', orderBy: 'fecha DESC, id DESC');
    return r.map(Mov.fromMap).toList();
  }

  /// → (id, estado) con estado 'nuevo' | 'conciliado' | 'duplicado'.
  /// Un movimiento de correo se fusiona con uno manual de mismo monto y tipo (±1 día).
  static Future<(int?, String)> insertar(Mov m, {String? uid, String origen = 'manual'}) async {
    final db = await _db;
    return db.transaction<(int?, String)>((txn) async {
      if (uid != null) {
        final ex = await txn.query('movimientos', columns: ['id'], where: 'uid_correo=?', whereArgs: [uid]);
        if (ex.isNotEmpty) return (null, 'duplicado');
        final f = DateTime.parse(m.fecha);
        final fechas = [-1, 0, 1].map((d) => iso(f.add(Duration(days: d)))).toList();
        final c = await txn.query('movimientos',
            where: 'uid_correo IS NULL AND monto=? AND tipo=? AND fecha IN (?,?,?)',
            whereArgs: [m.monto, m.tipo, ...fechas]);
        if (c.isNotEmpty) {
          final lista = List<Map<String, Object?>>.of(c);
          lista.sort((a, b) => DateTime.parse(a['fecha'] as String).difference(f).inDays.abs()
              .compareTo(DateTime.parse(b['fecha'] as String).difference(f).inDays.abs()));
          final id = lista.first['id'] as int;
          await txn.update('movimientos', {'uid_correo': uid, 'origen': 'conciliado'}, where: 'id=?', whereArgs: [id]);
          return (id, 'conciliado');
        }
      }
      final datos = m.toMap();
      datos['uid_correo'] = uid;
      datos['origen'] = origen;
      final id = await txn.insert('movimientos', datos);
      return (id, 'nuevo');
    });
  }

  static Future<void> actualizar(Mov viejo, Mov nuevo) async {
    final datos = nuevo.toMap()
      ..remove('uid_correo')
      ..remove('origen');
    await (await _db).update('movimientos', datos, where: 'id=?', whereArgs: [viejo.id]);
    if (viejo.categoria != nuevo.categoria && normComercio(nuevo.comercio).isNotEmpty) {
      await aprender(nuevo.comercio, nuevo.categoria);
    }
  }

  static Future<void> borrar(int id) async {
    await (await _db).delete('movimientos', where: 'id=?', whereArgs: [id]);
  }

  // ───── memoria de comercios ─────
  static Future<void> aprender(String comercio, String categoria) async {
    final n = normComercio(comercio);
    if (n.isEmpty) return;
    await (await _db).insert('comercios', {'patron': n, 'categoria': categoria}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Memoria aprendida primero; luego palabras clave. null si no sabe.
  static Future<String?> categoriaPara(String comercio) async {
    final n = normComercio(comercio);
    if (n.isEmpty) return null;
    final filas = await (await _db).query('comercios');
    String? mejor;
    var largo = 0;
    for (final f in filas) {
      final p = f['patron'] as String;
      if (p.isNotEmpty && n.contains(p) && p.length > largo) {
        largo = p.length;
        mejor = f['categoria'] as String;
      }
    }
    if (mejor != null) return mejor;
    for (final e in keywords.entries) {
      for (final k in e.value) {
        if (' $n '.contains(' $k ')) return e.key;
      }
    }
    return null;
  }

  static Future<List<Map<String, Object?>>> comercios() async =>
      (await _db).query('comercios', orderBy: 'patron');

  static Future<void> borrarComercio(String patron) async {
    await (await _db).delete('comercios', where: 'patron=?', whereArgs: [patron]);
  }

  // ───── declarar gastos y categorías propias ─────
  static Future<void> declarar(Mov m, String categoria, String nombre) async {
    await (await _db).update('movimientos', {'estado': 'declarado', 'categoria': categoria, 'nombre': nombre.trim()},
        where: 'id=?', whereArgs: [m.id]);
    await aprender(m.comercio, categoria); // la próxima vez te la sugiere sola
  }

  static Future<void> cargarCategorias() async {
    final r = await (await _db).query('categorias_usuario', orderBy: 'nombre');
    Cats.personalizadas = r.map((e) => e['nombre'] as String).toList();
  }

  /// Crea la categoría (o devuelve la existente si ya estaba, sin importar mayúsculas).
  static Future<String?> crearCategoria(String nombre) async {
    final n = nombre.trim();
    if (n.isEmpty) return null;
    final igual = Cats.todas.where((c) => c.toLowerCase() == n.toLowerCase());
    if (igual.isNotEmpty) return igual.first;
    await (await _db).insert('categorias_usuario', {'nombre': n}, conflictAlgorithm: ConflictAlgorithm.replace);
    await cargarCategorias();
    return n;
  }

  static Future<void> borrarCategoria(String nombre) async {
    await (await _db).delete('categorias_usuario', where: 'nombre=?', whereArgs: [nombre]);
    await cargarCategorias();
  }

  // ───── tarjetas y presupuestos ─────
  static Future<List<Tarjeta>> tarjetas() async {
    final r = await (await _db).query('tarjetas', orderBy: 'tarjeta');
    return r
        .map((m) => Tarjeta(
              nombre: m['tarjeta'] as String,
              tope: (m['tope'] as num?)?.toInt() ?? 0,
              alertaPct: (m['alerta_pct'] as num?)?.toInt() ?? 80,
              diaVenc: (m['dia_vencimiento'] as num?)?.toInt() ?? 0,
            ))
        .toList();
  }

  static Future<void> guardarTarjeta(Tarjeta t, {String? anterior}) async {
    final db = await _db;
    if (anterior != null && anterior != t.nombre) {
      await db.delete('tarjetas', where: 'tarjeta=?', whereArgs: [anterior]);
      await db.update('movimientos', {'tarjeta': t.nombre}, where: 'tarjeta=?', whereArgs: [anterior]);
    }
    await db.insert('tarjetas',
        {'tarjeta': t.nombre, 'tope': t.tope, 'alerta_pct': t.alertaPct, 'dia_vencimiento': t.diaVenc},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> borrarTarjeta(String nombre) async {
    await (await _db).delete('tarjetas', where: 'tarjeta=?', whereArgs: [nombre]);
  }

  static Future<List<Presupuesto>> presupuestos() async {
    final r = await (await _db).query('presupuestos', orderBy: 'categoria');
    return r
        .map((m) => Presupuesto(
              categoria: m['categoria'] as String,
              tope: (m['tope'] as num?)?.toInt() ?? 0,
              alertaPct: (m['alerta_pct'] as num?)?.toInt() ?? 80,
            ))
        .toList();
  }

  static Future<void> guardarPresupuesto(Presupuesto p) async {
    await (await _db).insert('presupuestos', {'categoria': p.categoria, 'tope': p.tope, 'alerta_pct': p.alertaPct},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> borrarPresupuesto(String categoria) async {
    await (await _db).delete('presupuestos', where: 'categoria=?', whereArgs: [categoria]);
  }

  // ───── control de sincronización ─────
  static Future<Set<String>> uidsProcesados() async {
    final r = await (await _db).query('correos_procesados', columns: ['uid']);
    return r.map((e) => e['uid'] as String).toSet();
  }

  static Future<void> marcarProcesado(String uid, String resultado) async {
    await (await _db).insert('correos_procesados', {'uid': uid, 'fecha': iso(DateTime.now()), 'resultado': resultado},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<int> registrarError(String uid, String motivo) async {
    final db = await _db;
    final r = await db.query('errores_sync', where: 'uid=?', whereArgs: [uid]);
    final n = r.isEmpty ? 1 : (r.first['intentos'] as int) + 1;
    final cortado = motivo.length > 300 ? motivo.substring(0, 300) : motivo;
    await db.insert('errores_sync',
        {'uid': uid, 'fecha': DateTime.now().toIso8601String().substring(0, 16), 'motivo': cortado, 'intentos': n},
        conflictAlgorithm: ConflictAlgorithm.replace);
    return n;
  }

  static Future<List<Map<String, Object?>>> errores() async =>
      (await _db).query('errores_sync', orderBy: 'fecha DESC');

  static Future<void> limpiarErrores() async {
    final db = await _db;
    await db.delete('correos_procesados', where: "resultado='error'");
    await db.delete('errores_sync');
  }
}
