import 'dart:convert';

import 'package:http/http.dart' as http;

import 'consts.dart';
import 'parser.dart';

class Gemini {
  static const _modelo = 'gemini-2.5-flash';

  static Future<String> _llamar(String apiKey, Map<String, dynamic> body) async {
    Object? ultimo;
    for (var intento = 0; intento < 3; intento++) {
      try {
        final r = await http
            .post(
              Uri.https('generativelanguage.googleapis.com', '/v1beta/models/$_modelo:generateContent'),
              headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 40));
        if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}: ${r.body.length > 150 ? r.body.substring(0, 150) : r.body}');
        final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
        return j['candidates'][0]['content']['parts'][0]['text'] as String;
      } catch (e) {
        ultimo = e;
        await Future.delayed(Duration(seconds: 2 * (intento + 1)));
      }
    }
    throw Exception('Gemini falló: $ultimo');
  }

  static Future<Map<String, dynamic>> extraerMovimiento(
      String apiKey, String cuerpo, String asunto, List<String> tarjetas) async {
    final cuerpoSeguro = ParserCorreo.enmascarar(cuerpo);
    final prompt = "Analiza este correo de un banco chileno. Si NO es una transacción de dinero (publicidad, clave, aviso), "
        "es_movimiento=false y el resto vacío/0.\n"
        "tipo debe ser exactamente uno de: '$ingreso', '$gasto', '$interna' "
        "(Transferencia interna = pago de tu propia tarjeta o traspaso entre tus cuentas).\n"
        "tarjeta: la que mejor coincida de $tarjetas. categoria: una de ${Cats.todas}. "
        "monto: entero en pesos, sin puntos.\n"
        "Asunto: $asunto\nCorreo:\n${cuerpoSeguro.length > 4000 ? cuerpoSeguro.substring(0, 4000) : cuerpoSeguro}";
    final texto = await _llamar(apiKey, {
      'contents': [
        {'parts': [{'text': prompt}]}
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0,
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'es_movimiento': {'type': 'BOOLEAN'},
            'tipo': {'type': 'STRING'},
            'tarjeta': {'type': 'STRING'},
            'comercio': {'type': 'STRING'},
            'categoria': {'type': 'STRING'},
            'monto': {'type': 'INTEGER'},
            'motivo': {'type': 'STRING'},
          },
          'required': ['es_movimiento', 'tipo', 'tarjeta', 'comercio', 'categoria', 'monto', 'motivo'],
        },
      },
    });
    return jsonDecode(texto) as Map<String, dynamic>;
  }

  static Future<String> consultar(String apiKey, String prompt) => _llamar(apiKey, {
        'contents': [
          {'parts': [{'text': prompt}]}
        ],
      });
}
