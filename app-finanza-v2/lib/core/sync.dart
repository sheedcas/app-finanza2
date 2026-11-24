import 'package:enough_mail/enough_mail.dart' as em;

import 'analisis.dart';
import 'cfg.dart';
import 'consts.dart';
import 'datos.dart';
import 'gemini.dart';
import 'models.dart';
import 'notificar.dart';
import 'parser.dart';
import 'util.dart';

class SyncResult {
  int nuevos = 0, conciliados = 0, ignorados = 0, errores = 0;
  bool omitido = false;
  String resumen() => omitido
      ? 'Ya hay una sincronización en curso'
      : '$nuevos nuevos · $conciliados fusionados con registros manuales · $ignorados no eran movimientos · $errores con error';
}

class Sync {
  static const _meses = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _emoji = {ingreso: '💰', gasto: '💸', interna: '🔁'};

  static Map<String, String> _dominios(String texto) {
    final r = <String, String>{};
    for (final b in texto.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty)) {
      r[b] = b.contains('.') ? b : (dominios[b] ?? b);
    }
    return r;
  }

  static Future<Mov?> _procesar(em.MimeMessage msg, String banco, List<String> tarjetas, String api) async {
    final asunto = msg.decodeSubject() ?? '';
    var cuerpo = msg.decodeTextPlainPart() ?? '';
    if (cuerpo.trim().length < 40) {
      final h = msg.decodeTextHtmlPart();
      if (h != null) cuerpo = ParserCorreo.htmlATexto(h);
    }
    var mov = ParserCorreo.parseRegex(cuerpo, asunto);
    if (mov == null) {
      if (!ParserCorreo.pareceMovimiento('$asunto $cuerpo')) return null;
      if (api.isEmpty) throw Exception('Correo no reconocido por regex y falta la API key de Gemini');
      mov = await Gemini.extraerMovimiento(api, cuerpo, asunto, tarjetas);
      if (mov['es_movimiento'] != true) return null;
    }
    final m = mov!;
    final tipo = m['tipo'] as String;
    if (!tipos.contains(tipo)) throw Exception('Tipo inválido: $tipo');
    final monto = (m['monto'] as num).toInt();
    if (monto <= 0) throw Exception('Monto inválido');
    final comercio = (m['comercio'] as String?) ?? '';
    final tIA = m['tarjeta'] as String?;
    final tarjeta = (tIA != null && tarjetas.contains(tIA)) ? tIA : ParserCorreo.inferirTarjeta('$asunto $cuerpo', banco, tarjetas);
    var cat = await Repo.categoriaPara(comercio);
    final cIA = m['categoria'] as String?;
    cat ??= (cIA != null && Cats.todas.contains(cIA)) ? cIA : null;
    if (tipo == interna) cat = 'Transferencias';
    final fecha = (msg.decodeDate() ?? DateTime.now()).toLocal();
    return Mov(
      fecha: iso(fecha),
      tipo: tipo,
      tarjeta: tarjeta,
      comercio: comercio,
      categoria: cat ?? 'Otros', // si es gasto, queda solo como sugerencia hasta que lo declares
      monto: monto,
      motivo: (m['motivo'] as String?) ?? '',
      estado: tipo == gasto ? 'pendiente' : 'declarado',
    );
  }

  static Future<String> _mensaje(Mov m, int id) async {
    final movs = await Repo.todos();
    final l = <String>[];
    if (m.tipo == gasto) {
      l.add('💸 ${clp(m.monto)} en ${m.comercio} (${m.tarjeta})');
      if (m.categoria != 'Otros') l.add('Sugerida: ${m.categoria}');
      l.add('Ábrela para declararlo: ¿de qué es?');
      // los topes por categoría se avisan al declarar; aquí solo el de la tarjeta
      final alertas = Analisis.alertasTopes(movs, m, await Repo.tarjetas(), await Repo.presupuestos(), conCategoria: false);
      for (final a in alertas) {
        if (await Repo.alertaNueva(a.$1)) l.add(a.$2);
      }
      for (final a in Analisis.anomalias(movs, m, id)) {
        l.add('🔎 $a');
      }
    } else {
      l.add('${_emoji[m.tipo]} ${m.tipo}: ${clp(m.monto)} en ${m.comercio} (${m.tarjeta}) · ${m.categoria}');
    }
    return l.join('\n');
  }

  /// Tras declarar un gasto: avisa si la categoría elegida alcanzó su tope.
  static Future<void> alertasTrasDeclarar(int id) async {
    final movs = await Repo.todos();
    final lista = movs.where((x) => x.id == id).toList();
    if (lista.isEmpty) return;
    final alertas = Analisis.alertasTopes(movs, lista.first, await Repo.tarjetas(), await Repo.presupuestos());
    for (final a in alertas) {
      if (await Repo.alertaNueva(a.$1)) await Notificar.mostrar('Presupuesto', a.$2);
    }
  }

  static Future<SyncResult> sincronizar({void Function(String)? log}) async {
    final user = await Cfg.get('EMAIL_USER');
    final pass = await Cfg.get('EMAIL_PASS');
    final server = await Cfg.get('IMAP', 'imap.gmail.com');
    final api = await Cfg.get('GEMINI_API_KEY');
    final bancos = _dominios(await Cfg.get('BANCOS', 'bancoestado, santander, falabella, bci, tenpo'));
    if (user.isEmpty || pass.isEmpty) throw Exception('Falta configurar el correo en Ajustes');
    await Repo.cargarCategorias();

    final res = SyncResult();
    if (!await Repo.tomarLock()) return res..omitido = true;
    final cliente = em.ImapClient(isLogEnabled: false);
    try {
      final ultima = await Repo.getMeta('ultima_sync');
      final desde = ultima != null
          ? DateTime.parse(ultima).subtract(const Duration(days: 7))
          : DateTime.now().subtract(const Duration(days: 35));
      final tarjetas = (await Repo.tarjetas()).map((t) => t.nombre).toList();
      final pendientes = <(Mov, int)>[];

      await cliente.connectToServer(server, 993, isSecure: true);
      await cliente.login(user, pass);
      await cliente.selectInbox();

      final uids = <int, String>{};
      final fechaImap = '${desde.day.toString().padLeft(2, '0')}-${_meses[desde.month - 1]}-${desde.year}';
      for (final e in bancos.entries) {
        final r = await cliente.uidSearchMessages(searchCriteria: 'SINCE $fechaImap FROM "${e.value}"');
        final seq = r.matchingSequence;
        if (seq != null && seq.isNotEmpty) {
          for (final u in seq.toList()) {
            uids[u] = e.key;
          }
        }
      }

      final hechos = await Repo.uidsProcesados();
      final ordenados = uids.keys.toList()..sort();
      for (final uid in ordenados) {
        final uidStr = '$uid';
        if (hechos.contains(uidStr)) continue;
        try {
          final fr = await cliente.uidFetchMessages(em.MessageSequence.fromId(uid, isUid: true), 'BODY.PEEK[]');
          if (fr.messages.isEmpty) throw Exception('Correo vacío');
          final mov = await _procesar(fr.messages.first, uids[uid]!, tarjetas, api);
          if (mov == null) {
            await Repo.marcarProcesado(uidStr, 'ignorado');
            res.ignorados++;
            continue;
          }
          final (id, estado) = await Repo.insertar(mov, uid: uidStr, origen: 'correo');
          await Repo.marcarProcesado(uidStr, estado);
          if (estado == 'conciliado') {
            res.conciliados++;
          } else if (estado == 'nuevo') {
            res.nuevos++;
            pendientes.add((mov, id!));
          }
        } catch (e) {
          res.errores++;
          log?.call('✗ correo $uid: $e');
          if (await Repo.registrarError(uidStr, '$e') >= 3) await Repo.marcarProcesado(uidStr, 'error');
        }
      }

      if (pendientes.length > 8) {
        // importación masiva: un solo resumen en vez de decenas de avisos
        final g = pendientes.where((p) => p.$1.tipo == gasto).fold<int>(0, (a, p) => a + p.$1.monto);
        final i = pendientes.where((p) => p.$1.tipo == ingreso).fold<int>(0, (a, p) => a + p.$1.monto);
        await Notificar.mostrar('📥 ${pendientes.length} movimientos importados', 'Gastos por declarar ${clp(g)} · Ingresos ${clp(i)}');
      } else {
        for (final p in pendientes) {
          await Notificar.mostrar(p.$1.pendiente ? 'Gasto por declarar' : 'Nuevo movimiento', await _mensaje(p.$1, p.$2));
        }
      }
      if (res.errores > 0) {
        await Notificar.mostrar('⚠️ Correos sin leer', '${res.errores} correos no se pudieron leer. Revisa Ajustes en la app.');
      }
      await Repo.setMeta('ultima_sync', iso(DateTime.now()));
      await Repo.setMeta('ultima_sync_ts', DateTime.now().toIso8601String().substring(0, 16).replaceFirst('T', ' '));
    } finally {
      try {
        await cliente.logout();
      } catch (_) {}
      await Repo.soltarLock();
    }
    return res;
  }

  static Future<void> _recordatorios() async {
    for (final v in Analisis.vencimientos(await Repo.tarjetas(), dias: 3)) {
      if (await Repo.alertaNueva(v.$1)) await Notificar.mostrar('Vencimiento próximo', v.$2);
    }
    // recordatorio diario si hay gastos sin declarar de ayer o antes
    final pend = Analisis.porDeclarar(await Repo.todos());
    final viejos = pend.any((x) => DateTime.now().difference(DateTime.parse(x.fecha)).inDays >= 1);
    if (viejos && await Repo.alertaNueva('pend:${iso(DateTime.now())}')) {
      final total = pend.fold<int>(0, (a, x) => a + x.monto);
      await Notificar.mostrar('Gastos por declarar', 'Tienes ${pend.length} gastos sin declarar (${clp(total)}).');
    }
  }

  static Future<void> _cierreMensual() async {
    final mes = mesPrevio(mesDe(DateTime.now()));
    final movs = await Repo.todos();
    if (Analisis.delMes(movs, mes).isEmpty) return;
    if (await Repo.alertaNueva('cierre:$mes')) await Notificar.mostrar('Cierre mensual', Analisis.cierreMensual(movs, mes));
  }

  /// Sincroniza + recordatorios + cierre mensual. Lo usan la app y la tarea en segundo plano.
  static Future<SyncResult> cicloCompleto({void Function(String)? log}) async {
    SyncResult? res;
    Object? fallo;
    try {
      res = await sincronizar(log: log);
    } catch (e) {
      fallo = e;
      if (await Repo.alertaNueva('fallo_sync:${iso(DateTime.now())}')) {
        await Notificar.mostrar('🚨 Falló la sincronización', '$e');
      }
    }
    try {
      await _recordatorios();
      await _cierreMensual();
    } catch (_) {}
    if (fallo != null) throw fallo;
    return res!;
  }
}
