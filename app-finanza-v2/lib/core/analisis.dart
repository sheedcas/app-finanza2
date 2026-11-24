import 'dart:math';

import 'consts.dart';
import 'models.dart';
import 'util.dart';

class Tope {
  final String tipo, nombre, nivel; // nivel: ok | alerta | superado
  final int usado, tope;
  final double pct;
  Tope(this.tipo, this.nombre, this.usado, this.tope, this.pct, this.nivel);
}

class Proy {
  final int gastado, ingresos, diasRestantes;
  final double proyectado;
  final double? disponibleDia;
  Proy(this.gastado, this.ingresos, this.proyectado, this.diasRestantes, this.disponibleDia);
}

class Sub {
  final String comercio, proximo;
  final int cargos, habitual, ultimo;
  final bool subio;
  Sub(this.comercio, this.cargos, this.habitual, this.ultimo, this.subio, this.proximo);
}

class Hormiga {
  final String comercio;
  final int veces, total;
  Hormiga(this.comercio, this.veces, this.total);
}

class Analisis {
  static List<Mov> delMes(List<Mov> m, String mes) => m.where((x) => x.fecha.startsWith(mes)).toList();

  /// Solo gastos reales: excluye ingresos y transferencias internas (sin doble conteo).
  static List<Mov> gastos(List<Mov> m) => m.where((x) => x.tipo == gasto).toList();

  /// Gastos que llegaron por correo y aún no declaras.
  static List<Mov> porDeclarar(List<Mov> m) => m.where((x) => x.pendiente).toList();

  static (int, int) totales(List<Mov> movs, String mes) {
    var i = 0, g = 0;
    for (final x in delMes(movs, mes)) {
      if (x.tipo == ingreso) i += x.monto;
      if (x.tipo == gasto) g += x.monto;
    }
    return (i, g);
  }

  static Map<String, int> porCategoria(List<Mov> movs, String mes) {
    final r = <String, int>{};
    for (final x in gastos(delMes(movs, mes))) {
      final k = x.pendiente ? 'Por declarar' : x.categoria;
      r[k] = (r[k] ?? 0) + x.monto;
    }
    return Map.fromEntries(r.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  static List<Tope> estadoTopes(List<Mov> movs, String mes, List<Tarjeta> tj, List<Presupuesto> pr) {
    final g = gastos(delMes(movs, mes));
    final out = <Tope>[];
    Tope? calc(String tipo, String nombre, int tope, int alerta, bool Function(Mov) filtro) {
      if (tope <= 0) return null;
      final usado = g.where(filtro).fold<int>(0, (a, x) => a + x.monto);
      final pct = usado / tope * 100;
      final nivel = pct >= 100 ? 'superado' : (pct >= alerta ? 'alerta' : 'ok');
      return Tope(tipo, nombre, usado, tope, pct, nivel);
    }

    for (final t in tj) {
      final r = calc('Tarjeta', t.nombre, t.tope, t.alertaPct, (x) => x.tarjeta == t.nombre);
      if (r != null) out.add(r);
    }
    for (final p in pr) {
      final r = calc('Categoría', p.categoria, p.tope, p.alertaPct, (x) => !x.pendiente && x.categoria == p.categoria);
      if (r != null) out.add(r);
    }
    return out;
  }

  /// Alertas de tope relevantes para este movimiento: (clave única, texto).
  static List<(String, String)> alertasTopes(List<Mov> movs, Mov mov, List<Tarjeta> tj, List<Presupuesto> pr,
      {bool conCategoria = true}) {
    final mes = mov.fecha.substring(0, 7);
    final res = <(String, String)>[];
    for (final it in estadoTopes(movs, mes, tj, pr)) {
      if (it.nivel == 'ok') continue;
      final relevante = (it.tipo == 'Tarjeta' && it.nombre == mov.tarjeta) ||
          (conCategoria && it.tipo == 'Categoría' && it.nombre == mov.categoria);
      if (!relevante) continue;
      final icono = it.nivel == 'superado' ? '🚨 Tope superado' : '⚠️ Cerca del tope';
      res.add(('tope:${it.tipo}:${it.nombre}:$mes:${it.nivel}',
          '$icono · ${it.tipo} ${it.nombre}: ${clp(it.usado)} de ${clp(it.tope)} (${it.pct.toStringAsFixed(0)}%)'));
    }
    return res;
  }

  static Proy? proyeccion(List<Mov> movs, String mes, {DateTime? hoy}) {
    hoy ??= DateTime.now();
    if (mes != mesDe(hoy)) return null;
    final (ing, gas) = totales(movs, mes);
    final diasMes = diasDelMes(hoy.year, hoy.month);
    final proyectado = gas / hoy.day * diasMes;
    final restantes = max(diasMes - hoy.day, 1);
    return Proy(gas, ing, proyectado, diasMes - hoy.day, ing > 0 ? (ing - gas) / restantes : null);
  }

  static List<Sub> suscripciones(List<Mov> movs) {
    final grupos = <String, List<Mov>>{};
    for (final x in gastos(movs)) {
      final k = normComercio(x.comercio);
      if (k.isEmpty) continue;
      (grupos[k] ??= []).add(x);
    }
    final out = <Sub>[];
    for (final l in grupos.values) {
      if (l.length < 3) continue;
      l.sort((a, b) => a.fecha.compareTo(b.fecha));
      final fechas = l.map((x) => DateTime.parse(x.fecha)).toList();
      final gaps = <int>[];
      for (var i = 1; i < fechas.length; i++) {
        gaps.add(fechas[i].difference(fechas[i - 1]).inDays);
      }
      final mg = mediana(gaps);
      if (mg < 26 || mg > 34) continue;
      if (gaps.where((d) => d >= 25 && d <= 36).length / gaps.length < 0.7) continue;
      final montos = l.map((x) => x.monto).toList();
      final med = mediana(montos);
      if (med <= 0) continue;
      if (montos.where((v) => (v - med).abs() / med <= 0.30).length / montos.length < 0.7) continue;
      final previo = mediana(montos.sublist(0, montos.length - 1));
      out.add(Sub(l.last.comercio, l.length, previo.round(), montos.last, montos.last > previo * 1.05,
          iso(fechas.last.add(Duration(days: mg.round())))));
    }
    return out;
  }

  static List<Hormiga> hormiga(List<Mov> movs, String mes, {int maxMonto = 10000, int minVeces = 4}) {
    final grupos = <String, List<Mov>>{};
    for (final x in gastos(delMes(movs, mes))) {
      if (x.monto > maxMonto) continue;
      final k = normComercio(x.comercio);
      if (k.isEmpty) continue;
      (grupos[k] ??= []).add(x);
    }
    final out = grupos.values
        .where((l) => l.length >= minVeces)
        .map((l) => Hormiga(l.first.comercio, l.length, l.fold<int>(0, (a, x) => a + x.monto)))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return out;
  }

  /// Cargo inusual para su categoría, comercio nuevo con monto alto, posible duplicado.
  static List<String> anomalias(List<Mov> movs, Mov mov, int? id) {
    final hist = gastos(movs).where((x) => x.id != id).toList();
    final clave = normComercio(mov.comercio);
    final av = <String>[];
    final catH = hist.where((x) => x.categoria == mov.categoria).map((x) => x.monto).toList();
    if (catH.length >= 5) {
      final med = mediana(catH);
      if (mov.monto > max(3 * med, 15000)) {
        av.add('Cargo inusual: ${clp(mov.monto)} en ${mov.comercio} (lo habitual en ${mov.categoria} ronda ${clp(med)})');
      }
    }
    if (clave.isNotEmpty && mov.monto >= 50000 && hist.length >= 10 && !hist.any((x) => normComercio(x.comercio) == clave)) {
      av.add('Comercio nuevo con monto alto: ${mov.comercio} (${clp(mov.monto)}). ¿Lo reconoces?');
    }
    if (hist.any((x) => x.fecha == mov.fecha && x.monto == mov.monto && normComercio(x.comercio) == clave)) {
      av.add('Posible cargo duplicado: mismo comercio y monto hoy (${clp(mov.monto)}).');
    }
    return av;
  }

  /// Vencimientos de tarjetas dentro de [dias] días: (clave única, texto).
  static List<(String, String)> vencimientos(List<Tarjeta> tj, {int dias = 3, DateTime? hoy}) {
    final ahora = hoy ?? DateTime.now();
    final h0 = DateTime(ahora.year, ahora.month, ahora.day);
    DateTime prox(int dia) {
      for (var off = 0; off < 2; off++) {
        final m0 = h0.month + off;
        final y = h0.year + (m0 - 1) ~/ 12;
        final m = (m0 - 1) % 12 + 1;
        final f = DateTime(y, m, min(dia, diasDelMes(y, m)));
        if (!f.isBefore(h0)) return f;
      }
      return h0;
    }

    final out = <(String, String)>[];
    for (final t in tj) {
      if (t.diaVenc <= 0) continue;
      final f = prox(t.diaVenc);
      final d = f.difference(h0).inDays;
      if (d <= dias) {
        out.add(('venc:${t.nombre}:${iso(f)}', '📅 Vence el pago de ${t.nombre} el ${iso(f).substring(8)}-${iso(f).substring(5, 7)} (en $d días)'));
      }
    }
    return out;
  }

  static String cierreMensual(List<Mov> movs, String mes) {
    final (ing, gas) = totales(movs, mes);
    final act = porCategoria(movs, mes);
    final prev = porCategoria(movs, mesPrevio(mes));
    final delta = act.entries.map((e) => MapEntry(e.key, e.value - (prev[e.key] ?? 0))).where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final l = <String>[
      '📊 Cierre $mes',
      'Ingresos: ${clp(ing)}',
      'Gastos: ${clp(gas)}',
      ing > 0 ? 'Ahorro: ${clp(ing - gas)} (${((ing - gas) / ing * 100).toStringAsFixed(0)}% del ingreso)' : 'Saldo: ${clp(ing - gas)}',
    ];
    if (delta.isNotEmpty) {
      l.add('Categorías que más subieron vs mes anterior:');
      for (final e in delta.take(3)) {
        l.add('  • ${e.key}: +${clp(e.value)}');
      }
      l.add('👉 Recomendación: parte revisando «${delta.first.key}».');
    }
    return l.join('\n');
  }
}
