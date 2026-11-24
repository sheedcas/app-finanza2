import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class Db {
  static Database? _db;

  static const _schema = [
    '''CREATE TABLE movimientos(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uid_correo TEXT UNIQUE,
      fecha TEXT NOT NULL, tipo TEXT NOT NULL, tarjeta TEXT, comercio TEXT, categoria TEXT,
      monto INTEGER NOT NULL, motivo TEXT DEFAULT '', origen TEXT DEFAULT 'manual',
      estado TEXT DEFAULT 'declarado', nombre TEXT DEFAULT '')''',
    'CREATE INDEX ix_mov_fecha ON movimientos(fecha)',
    'CREATE TABLE correos_procesados(uid TEXT PRIMARY KEY, fecha TEXT, resultado TEXT)',
    'CREATE TABLE errores_sync(uid TEXT PRIMARY KEY, fecha TEXT, motivo TEXT, intentos INTEGER DEFAULT 1)',
    'CREATE TABLE comercios(patron TEXT PRIMARY KEY, categoria TEXT NOT NULL)',
    'CREATE TABLE tarjetas(tarjeta TEXT PRIMARY KEY, tope INTEGER DEFAULT 0, alerta_pct INTEGER DEFAULT 80, dia_vencimiento INTEGER DEFAULT 0)',
    'CREATE TABLE presupuestos(categoria TEXT PRIMARY KEY, tope INTEGER DEFAULT 0, alerta_pct INTEGER DEFAULT 80)',
    'CREATE TABLE alertas_enviadas(clave TEXT PRIMARY KEY, fecha TEXT)',
    'CREATE TABLE meta(clave TEXT PRIMARY KEY, valor TEXT)',
    'CREATE TABLE categorias_usuario(nombre TEXT PRIMARY KEY)',
  ];

  static Future<Database> get() async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'finanzas.db');
    _db = await openDatabase(path, version: 2, onUpgrade: (db, antes, despues) async {
      if (antes < 2) {
        await db.execute("ALTER TABLE movimientos ADD COLUMN estado TEXT DEFAULT 'declarado'");
        await db.execute("ALTER TABLE movimientos ADD COLUMN nombre TEXT DEFAULT ''");
        await db.execute('CREATE TABLE IF NOT EXISTS categorias_usuario(nombre TEXT PRIMARY KEY)');
      }
    }, onCreate: (db, v) async {
      for (final s in _schema) {
        await db.execute(s);
      }
      await db.insert('tarjetas', {'tarjeta': 'Débito Principal', 'tope': 350000, 'alerta_pct': 80, 'dia_vencimiento': 0});
      await db.insert('tarjetas', {'tarjeta': 'Crédito', 'tope': 300000, 'alerta_pct': 80, 'dia_vencimiento': 0});
    });
    return _db!;
  }
}
