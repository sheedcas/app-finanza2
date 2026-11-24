import 'package:flutter/material.dart';

import '../core/analisis.dart';
import '../core/background.dart';
import '../core/cfg.dart';
import '../core/consts.dart';
import '../core/datos.dart';
import '../core/models.dart';
import '../core/sync.dart';
import '../core/util.dart';
import 'ahorro.dart';
import 'ajustes.dart';
import 'forms.dart';
import 'pendientes.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  int tab = 0;
  String mes = mesDe(DateTime.now());
  List<Mov> movs = [];
  List<Tarjeta> tarjetas = [];
  List<Presupuesto> pres = [];
  List<Map<String, Object?>> errores = [];
  String ultima = 'nunca';
  bool sincronizando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _arranque();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) recargar();
  }

  Future<void> _arranque() async {
    await recargar();
    if ((await Cfg.get('EMAIL_PASS')).isNotEmpty) {
      await programarSync();
      sincronizar(silencioso: true);
    } else if (mounted) {
      setState(() => tab = 3); // primera vez: directo a Ajustes
    }
  }

  Future<void> recargar() async {
    await Repo.cargarCategorias();
    final m = await Repo.todos();
    final t = await Repo.tarjetas();
    final p = await Repo.presupuestos();
    final e = await Repo.errores();
    final u = await Repo.getMeta('ultima_sync_ts');
    if (!mounted) return;
    setState(() {
      movs = m;
      tarjetas = t;
      pres = p;
      errores = e;
      ultima = u ?? 'nunca';
    });
  }

  void msg(String t) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> sincronizar({bool silencioso = false}) async {
    if (sincronizando) return;
    setState(() => sincronizando = true);
    try {
      final r = await Sync.cicloCompleto();
      if (!silencioso) msg(r.resumen());
    } catch (e) {
      if (!silencioso) msg('No se pudo sincronizar: $e');
    }
    if (mounted) setState(() => sincronizando = false);
    await recargar();
  }

  Future<void> _agregar() async {
    final m = await showMovForm(context, tarjetas);
    if (m == null) return;
    await Repo.insertar(m);
    if (m.comercio.isNotEmpty) await Repo.aprender(m.comercio, m.categoria);
    await recargar();
    msg('Guardado. Si luego llega el correo del banco, se fusiona solo (sin duplicar).');
  }

  Future<void> _abrirPendientes() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const Pendientes()));
    await recargar();
  }

  Future<void> _declarar(Mov m) async {
    final r = await showDeclarar(context, m);
    if (r == null) return;
    await Repo.declarar(m, r.categoria, r.nombre);
    await Sync.alertasTrasDeclarar(m.id!);
    await recargar();
  }

  Widget _bannerPendientes() {
    final p = Analisis.porDeclarar(movs);
    if (p.isEmpty) return const SizedBox.shrink();
    final total = p.fold<int>(0, (a, x) => a + x.monto);
    return Card(
      color: Colors.orange.withOpacity(0.2),
      child: ListTile(
        leading: const Icon(Icons.pending_actions),
        title: Text('${p.length} gastos por declarar (${clp(total)})'),
        subtitle: const Text('Toca para decir de qué es cada uno'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _abrirPendientes,
      ),
    );
  }

  List<String> get meses {
    final s = {mesDe(DateTime.now()), ...movs.map((m) => m.fecha.substring(0, 7))}.toList()..sort((a, b) => b.compareTo(a));
    return s;
  }

  Widget _selectorMes() => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          const Icon(Icons.calendar_month),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: meses.contains(mes) ? mes : meses.first,
            items: meses.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) => setState(() => mes = v!),
          ),
          const Spacer(),
          Text('🕒 $ultima', style: Theme.of(context).textTheme.bodySmall),
        ]),
      );

  Widget _metrica(String t, String v, {Color? color}) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(v, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            ]),
          ),
        ),
      );

  Color _colorNivel(String n) => n == 'superado' ? Colors.red : (n == 'alerta' ? Colors.orange : Colors.green);

  Widget _resumen() {
    final (ing, gas) = Analisis.totales(movs, mes);
    final proy = Analisis.proyeccion(movs, mes);
    final topes = Analisis.estadoTopes(movs, mes, tarjetas, pres);
    final venc = Analisis.vencimientos(tarjetas, dias: 7);
    final cats = Analisis.porCategoria(movs, mes);
    final maxCat = cats.isEmpty ? 1 : cats.values.first;
    final h = Theme.of(context).textTheme.titleMedium;
    return ListView(padding: const EdgeInsets.all(12), children: [
      _selectorMes(),
      if (errores.isNotEmpty)
        Card(
          color: Colors.orange.withOpacity(0.2),
          child: ListTile(
            leading: const Icon(Icons.warning_amber),
            title: Text('${errores.length} correos no se pudieron leer'),
            subtitle: const Text('Toca para revisarlos en Ajustes'),
            onTap: () => setState(() => tab = 3),
          ),
        ),
      _bannerPendientes(),
      Row(children: [
        _metrica('💰 Ingresos', clp(ing), color: Colors.green),
        _metrica('💸 Gastos', clp(gas), color: Colors.red),
        _metrica('🧮 Saldo', clp(ing - gas)),
      ]),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text('No cuenta pagos de tu propia tarjeta ni traspasos entre tus cuentas.', style: Theme.of(context).textTheme.bodySmall),
      ),
      if (proy != null)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('📈 A este ritmo cerrarás el mes con ${clp(proy.proyectado)} de gasto'
                  '${ing > 0 && proy.proyectado > ing ? ' (${clp(proy.proyectado - ing)} sobre tus ingresos)' : ''}.'),
              if (proy.disponibleDia != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Disponible por día (${proy.diasRestantes} días restantes): ${clp(proy.disponibleDia!)}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: proy.disponibleDia! < 0 ? Colors.red : null)),
                ),
            ]),
          ),
        ),
      for (final v in venc) Card(color: Colors.amber.withOpacity(0.25), child: ListTile(title: Text(v.$2))),
      const SizedBox(height: 8),
      Text('🎯 Topes', style: h),
      if (topes.isEmpty)
        const Padding(padding: EdgeInsets.all(8), child: Text('Define topes por tarjeta y por categoría en Ajustes.')),
      for (final t in topes)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${t.tipo}: ${t.nombre} — ${clp(t.usado)} / ${clp(t.tope)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: (t.pct / 100).clamp(0.0, 1.0), color: _colorNivel(t.nivel), minHeight: 8),
              const SizedBox(height: 6),
              Text(
                t.nivel == 'superado'
                    ? '🚨 Superado por ${clp(t.usado - t.tope)}'
                    : t.nivel == 'alerta'
                        ? '⚠️ Al ${t.pct.toStringAsFixed(0)}%. Quedan ${clp(t.tope - t.usado)}'
                        : '✅ Disponible: ${clp(t.tope - t.usado)}',
                style: TextStyle(color: _colorNivel(t.nivel)),
              ),
            ]),
          ),
        ),
      const SizedBox(height: 8),
      if (cats.isNotEmpty) Text('🧾 Gasto por categoría', style: h),
      for (final e in cats.entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(e.key)), Text(clp(e.value))]),
            LinearProgressIndicator(value: e.value / maxCat, minHeight: 6),
          ]),
        ),
      const SizedBox(height: 80),
    ]);
  }

  Widget _movimientos() {
    final lista = Analisis.delMes(movs, mes);
    return ListView(padding: const EdgeInsets.all(12), children: [
      _selectorMes(),
      _bannerPendientes(),
      Text('Toca un gasto por declarar para elegir su categoría y nombre · desliza para borrar.', style: Theme.of(context).textTheme.bodySmall),
      if (lista.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Sin movimientos este mes'))),
      for (final m in lista)
        Dismissible(
          key: ValueKey('mov-${m.id}'),
          direction: DismissDirection.endToStart,
          background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
          confirmDismiss: (_) async =>
              await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('¿Borrar movimiento?'),
                  content: Text('${m.comercio} · ${clp(m.monto)}'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Borrar')),
                  ],
                ),
              ) ??
              false,
          onDismissed: (_) {
            setState(() => movs.removeWhere((x) => x.id == m.id));
            Repo.borrar(m.id!).then((_) => recargar());
          },
          child: Card(
            child: ListTile(
              title: Text(m.titulo),
              subtitle: Text(m.subtitulo),
              trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(
                  '${m.tipo == ingreso ? '+' : (m.tipo == interna ? '↔ ' : '-')}${clp(m.monto)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: m.tipo == ingreso ? Colors.green : (m.tipo == interna ? Colors.grey : Colors.red)),
                ),
                if (m.pendiente) const Text('Por declarar', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
              ]),
              onTap: () async {
                if (m.pendiente) {
                  await _declarar(m);
                  return;
                }
                final n = await showMovForm(context, tarjetas, inicial: m);
                if (n == null) return;
                await Repo.actualizar(m, n);
                await recargar();
              },
            ),
          ),
        ),
      const SizedBox(height: 80),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cuerpo = [
      _resumen(),
      _movimientos(),
      Ahorro(movs: movs, mes: mes),
      Ajustes(tarjetas: tarjetas, pres: pres, errores: errores, movs: movs, recargar: recargar, sincronizar: () => sincronizar()),
    ][tab];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanzas'),
        actions: [
          sincronizando
              ? const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(icon: const Icon(Icons.sync), tooltip: 'Sincronizar correos', onPressed: () => sincronizar()),
        ],
      ),
      body: SafeArea(child: cuerpo),
      floatingActionButton: tab <= 1 ? FloatingActionButton(onPressed: _agregar, child: const Icon(Icons.add)) : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Resumen'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Movimientos'),
          NavigationDestination(icon: Icon(Icons.savings_outlined), label: 'Ahorro'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Ajustes'),
        ],
      ),
    );
  }
}
