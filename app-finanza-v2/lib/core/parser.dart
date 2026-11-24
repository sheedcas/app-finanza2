import 'consts.dart';

/// Lectura de correos: regex primero (gratis y exacto), Gemini solo como respaldo.
class ParserCorreo {
  static const _entidades = {
    '&nbsp;': ' ', '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'",
    '&aacute;': 'á', '&eacute;': 'é', '&iacute;': 'í', '&oacute;': 'ó', '&uacute;': 'ú', '&ntilde;': 'ñ',
    '&Aacute;': 'Á', '&Eacute;': 'É', '&Iacute;': 'Í', '&Oacute;': 'Ó', '&Uacute;': 'Ú', '&Ntilde;': 'Ñ',
  };

  static String htmlATexto(String h) {
    var s = h.replaceAll(RegExp(r'<(script|style)[^>]*>.*?</\1>', caseSensitive: false, dotAll: true), ' ');
    s = s.replaceAll(RegExp(r'<(br|/p|/div|/tr|/li|/td|/h[1-6])[^>]*>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<[^>]+>'), ' ');
    _entidades.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m.group(1)!)));
    s = s.replaceAll(RegExp(r'[ \t\u00a0]+'), ' ').replaceAll(RegExp(r'\n\s*\n+'), '\n');
    return s.trim();
  }

  /// Quita RUT, números de tarjeta y saldos antes de enviar nada a la IA.
  static String enmascarar(String t) {
    t = t.replaceAll(RegExp(r'\b\d{1,2}\.?\d{3}\.?\d{3}-[\dkK]\b'), '[RUT]');
    t = t.replaceAll(RegExp(r'\b(?:\d[ -]?){13,19}\b'), '[TARJETA]');
    return t.replaceAll(RegExp(r'saldo[^\n]*', caseSensitive: false), '[saldo omitido]');
  }

  static final _saldo = RegExp(r'saldo[^\n]*', caseSensitive: false);
  static final _monto = RegExp(r'\$\s?(\d{1,3}(?:\.\d{3})+|\d+)');
  static final _interna = RegExp(r'pago (?:de |a )?(?:tu |su )?tarjeta|traspaso|cuenta propia|entre tus cuentas', caseSensitive: false);
  static final _ingreso = RegExp(r'abono|dep[oó]sito|transferencia recibida|te transfirieron|has recibido|recibiste|remuneraci[oó]n|sueldo', caseSensitive: false);
  static final _gasto = RegExp(r'compra|cargo|giro|pago|retiro|avance|transferencia (?:a |realizada|enviada)', caseSensitive: false);
  static final _comercio = RegExp(r"(?:\b[Ee]n|[Cc]omercio:?|[Dd]estinatario:?|[Aa] favor de)\s+([A-ZÁÉÍÓÚÑ0-9][A-Za-zÁÉÍÓÚÑáéíóúñ0-9&\.\-' ]{2,40})");
  static final _origen = RegExp(r"(?:\b[Dd]e|\b[Dd]esde|[Oo]rigen:?)\s+([A-ZÁÉÍÓÚÑ][A-Za-zÁÉÍÓÚÑáéíóúñ&\.\-' ]{2,40})");
  static final _corte = RegExp(r'\s+(?:el|por|con|a las|a la|tarjeta|desde|usando|de tu|en tu)\b');
  static final _pareceMov = RegExp(r'compra|cargo|abono|transferencia|pago|giro|retiro|dep[oó]sito', caseSensitive: false);

  static String _limpiar(String s) {
    final corte = '$s '.split(_corte).first;
    final t = corte.replaceAll(RegExp(r'^[ .,\-:]+|[ .,\-:]+$'), '');
    return t.length > 40 ? t.substring(0, 40) : t;
  }

  static bool pareceMovimiento(String t) => _monto.hasMatch(t) && _pareceMov.hasMatch(t);

  /// Conservador: ante cualquier ambigüedad (varios montos, señales mezcladas) devuelve null → IA.
  static Map<String, dynamic>? parseRegex(String cuerpo, [String asunto = '']) {
    final limpio = '$asunto\n$cuerpo'.replaceAll(_saldo, '');
    final montos = _monto.allMatches(limpio).map((m) => int.parse(m.group(1)!.replaceAll('.', ''))).toSet()..remove(0);
    if (montos.length != 1) return null;
    final esInterna = _interna.hasMatch(limpio);
    final ing = _ingreso.hasMatch(limpio);
    final gas = _gasto.hasMatch(limpio);
    String tipo;
    if (esInterna) {
      tipo = interna;
    } else if (ing && gas) {
      return null;
    } else if (ing) {
      tipo = ingreso;
    } else if (gas) {
      tipo = gasto;
    } else {
      return null;
    }
    final m = (tipo == ingreso ? _origen : _comercio).firstMatch(limpio);
    var comercio = m != null ? _limpiar(m.group(1)!) : '';
    if (tipo == interna) {
      if (comercio.isEmpty) comercio = 'Movimiento propio';
    } else if (comercio.length < 3) {
      return null;
    }
    return {
      'es_movimiento': true,
      'tipo': tipo,
      'comercio': comercio,
      'monto': montos.first,
      'motivo': asunto.length > 80 ? asunto.substring(0, 80) : asunto,
    };
  }

  /// Elige la tarjeta cuyo nombre comparte más palabras con el correo/banco.
  static String inferirTarjeta(String texto, String banco, List<String> tarjetas) {
    if (tarjetas.isEmpty) return 'Sin tarjeta';
    final t = '$texto $banco'.toLowerCase();
    var mejor = tarjetas.first;
    var pts = 0;
    for (final tj in tarjetas) {
      final p = RegExp(r'[a-záéíóúñü0-9]{3,}').allMatches(tj.toLowerCase()).where((w) => t.contains(w.group(0)!)).length;
      if (p > pts) {
        mejor = tj;
        pts = p;
      }
    }
    return mejor;
  }
}
