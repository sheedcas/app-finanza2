import 'consts.dart';

class Mov {
  int? id;
  String? uid;
  String fecha, tipo, tarjeta, comercio, categoria, motivo, origen, estado, nombre;
  int monto;

  Mov({
    this.id,
    this.uid,
    required this.fecha,
    required this.tipo,
    this.tarjeta = '',
    this.comercio = '',
    this.categoria = 'Otros',
    required this.monto,
    this.motivo = '',
    this.origen = 'manual',
    this.estado = 'declarado', // 'pendiente' = gasto por declarar
    this.nombre = '',
  });

  bool get pendiente => tipo == gasto && estado == 'pendiente';

  /// Gasto declarado → «Categoría · nombre»; el resto muestra el comercio.
  String get titulo {
    if (tipo == gasto && estado == 'declarado') return nombre.isEmpty ? categoria : '$categoria · $nombre';
    return comercio.isEmpty ? '(sin comercio)' : comercio;
  }

  String get subtitulo {
    if (pendiente) return '$fecha · $tarjeta · sugerida: $categoria';
    if (tipo == gasto) return '${comercio.isEmpty ? '' : '$comercio · '}$fecha · $tarjeta';
    return '$categoria · $fecha · $tarjeta';
  }

  factory Mov.fromMap(Map<String, Object?> m) => Mov(
        id: m['id'] as int?,
        uid: m['uid_correo'] as String?,
        fecha: m['fecha'] as String,
        tipo: m['tipo'] as String,
        tarjeta: (m['tarjeta'] as String?) ?? '',
        comercio: (m['comercio'] as String?) ?? '',
        categoria: (m['categoria'] as String?) ?? 'Otros',
        monto: (m['monto'] as num).toInt(),
        motivo: (m['motivo'] as String?) ?? '',
        origen: (m['origen'] as String?) ?? 'manual',
        estado: (m['estado'] as String?) ?? 'declarado',
        nombre: (m['nombre'] as String?) ?? '',
      );

  Map<String, Object?> toMap() => {
        'uid_correo': uid,
        'fecha': fecha,
        'tipo': tipo,
        'tarjeta': tarjeta,
        'comercio': comercio,
        'categoria': categoria,
        'monto': monto,
        'motivo': motivo,
        'origen': origen,
        'estado': estado,
        'nombre': nombre,
      };
}

class Tarjeta {
  String nombre;
  int tope, alertaPct, diaVenc;
  Tarjeta({required this.nombre, this.tope = 0, this.alertaPct = 80, this.diaVenc = 0});
}

class Presupuesto {
  String categoria;
  int tope, alertaPct;
  Presupuesto({required this.categoria, this.tope = 0, this.alertaPct = 80});
}
