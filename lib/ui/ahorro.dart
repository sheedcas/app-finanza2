import 'package:flutter/material.dart';

import '../core/analisis.dart';
import '../core/cfg.dart';
import '../core/gemini.dart';
import '../core/models.dart';
import '../core/parser.dart';
import '../core/util.dart';

class Ahorro extends StatefulWidget {
  final List<Mov> movs;
  final String mes;
  const Ahorro({super.key, required this.movs, required this.mes});

  @override
  State<Ahorro> createState() => _AhorroState();
}

class _AhorroState extends State<Ahorro> {
  String? plan;
  bool cargando = false;

  Future<void> _pedirPlan() async {
    final api = await Cfg.get('GEMINI_API_KEY');
    final d = Analisis.delMes(widget.movs, widget.mes);
    if (api.isEmpty || d.isEmpty) {
      setState(() => plan = 'Necesitas movimientos en el mes y la API key de Gemini (Ajustes).');
      return;
    }
    setState(() => cargando = true);
    try {
      final (ing, _) = Analisis.totales(widget.movs, widget.mes);
      final lista = ParserCorreo.enmascarar(d.map((m) => '${m.fecha} | ${m.tipo} | ${m.comercio} | ${m.categoria} | ${m.monto}').join('\n'));
      final t = await Gemini.consultar(
          api,
          'Eres asesor financiero en Chile. Ingresos del mes: $ing. Los movimientos "Transferencia interna" no son gasto.\n'
          'Movimientos:\n$lista\n\nDa 4 acciones concretas de ahorro con montos aproximados. Responde en español, breve.');
      setState(() => plan = t);
    } catch (e) {
      setState(() => plan = 'Error: $e');
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subs = Analisis.suscripciones(widget.movs);
    final hor = Analisis.hormiga(widget.movs, widget.mes);
    final h = Theme.of(context).textTheme.titleMedium;
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text('🔁 Suscripciones y cargos recurrentes', style: h),
      if (subs.isEmpty)
        const Padding(padding: EdgeInsets.all(8), child: Text('Aún no detecto cargos recurrentes (necesito al menos 3 meses de historial).')),
      for (final s in subs)
        Card(
          child: ListTile(
            title: Text(s.comercio),
            subtitle: Text('${s.cargos} cargos · próximo ~${s.proximo}${s.subio ? '\n📈 Subió de ${clp(s.habitual)} a ${clp(s.ultimo)}' : ''}'),
            trailing: Text(clp(s.ultimo), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      if (subs.isNotEmpty)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text('Total mensual recurrente: ${clp(subs.fold<int>(0, (a, s) => a + s.ultimo))}'),
        ),
      const SizedBox(height: 12),
      Text('🐜 Gastos hormiga del mes', style: h),
      if (hor.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Sin patrones de gasto hormiga este mes.')),
      for (final x in hor)
        Card(child: ListTile(title: Text(x.comercio), subtitle: Text('${x.veces} compras pequeñas'), trailing: Text(clp(x.total)))),
      const SizedBox(height: 12),
      Text('🤖 Coach de ahorro IA', style: h),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: cargando ? null : _pedirPlan,
        icon: cargando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
        label: const Text('Analizar mi mes y dar un plan'),
      ),
      if (plan != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: SelectableText(plan!))),
    ]);
  }
}
