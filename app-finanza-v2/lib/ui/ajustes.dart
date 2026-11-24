import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/background.dart';
import '../core/cfg.dart';
import '../core/consts.dart';
import '../core/datos.dart';
import '../core/models.dart';
import '../core/notificar.dart';
import '../core/util.dart';
import 'forms.dart';

class Ajustes extends StatefulWidget {
  final List<Tarjeta> tarjetas;
  final List<Presupuesto> pres;
  final List<Map<String, Object?>> errores;
  final List<Mov> movs;
  final Future<void> Function() recargar;
  final Future<void> Function() sincronizar;
  const Ajustes({
    super.key,
    required this.tarjetas,
    required this.pres,
    required this.errores,
    required this.movs,
    required this.recargar,
    required this.sincronizar,
  });

  @override
  State<Ajustes> createState() => _AjustesState();
}

class _AjustesState extends State<Ajustes> {
  final user = TextEditingController();
  final pass = TextEditingController();
  final imap = TextEditingController();
  final bancos = TextEditingController();
  final api = TextEditingController();
  List<Map<String, Object?>> mem = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    user.text = await Cfg.get('EMAIL_USER');
    pass.text = await Cfg.get('EMAIL_PASS');
    imap.text = await Cfg.get('IMAP', 'imap.gmail.com');
    bancos.text = await Cfg.get('BANCOS', 'bancoestado, santander, falabella, bci, tenpo');
    api.text = await Cfg.get('GEMINI_API_KEY');
    mem = await Repo.comercios();
    await Repo.cargarCategorias();
    if (mounted) setState(() {});
  }

  void msg(String t) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _guardarCredenciales() async {
    await Cfg.set('EMAIL_USER', user.text.trim());
    await Cfg.set('EMAIL_PASS', pass.text.replaceAll(' ', ''));
    await Cfg.set('IMAP', imap.text.trim());
    await Cfg.set('BANCOS', bancos.text.trim());
    await Cfg.set('GEMINI_API_KEY', api.text.trim());
    await Notificar.pedirPermiso();
    await programarSync();
    msg('Guardado. La app revisará tus correos sola cada ~15 minutos.');
  }

  Widget _tarjeta(String titulo, List<Widget> hijos) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...hijos,
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(12), children: [
      _tarjeta('📧 Correo y bancos', [
        TextField(controller: user, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Tu correo (Gmail)')),
        TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Clave de aplicación (16 letras)')),
        TextField(controller: imap, decoration: const InputDecoration(labelText: 'Servidor IMAP')),
        TextField(controller: bancos, decoration: const InputDecoration(labelText: 'Bancos (nombre o dominio, separados por coma)')),
        TextField(controller: api, obscureText: true, decoration: const InputDecoration(labelText: 'API key de Gemini (opcional pero recomendada)')),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: _guardarCredenciales, icon: const Icon(Icons.save), label: const Text('Guardar y activar')),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: widget.sincronizar, child: const Text('Sincronizar ahora'))),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                await Notificar.pedirPermiso();
                await Notificar.mostrar('Prueba', 'Las notificaciones funcionan 🎉');
              },
              child: const Text('Probar aviso'),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        const Text('Las credenciales se guardan cifradas en este teléfono y solo se usan para leer tu correo.', style: TextStyle(fontSize: 12)),
      ]),
      _tarjeta('💳 Tarjetas (tope, alerta y vencimiento)', [
        for (final t in widget.tarjetas)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.nombre),
            subtitle: Text('Tope ${clp(t.tope)} · avisa al ${t.alertaPct}%${t.diaVenc > 0 ? ' · vence día ${t.diaVenc}' : ''}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await Repo.borrarTarjeta(t.nombre);
                await widget.recargar();
              },
            ),
            onTap: () async {
              final n = await dialogTarjeta(context, t);
              if (n != null) {
                await Repo.guardarTarjeta(n, anterior: t.nombre);
                await widget.recargar();
              }
            },
          ),
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Agregar tarjeta'),
          onPressed: () async {
            final n = await dialogTarjeta(context);
            if (n != null) {
              await Repo.guardarTarjeta(n);
              await widget.recargar();
            }
          },
        ),
        const Text('Tip: nómbralas con banco y tipo (ej. «BancoEstado Débito») para que se asignen solas desde el correo.', style: TextStyle(fontSize: 12)),
      ]),
      _tarjeta('🎯 Presupuesto por categoría', [
        for (final p in widget.pres)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(p.categoria),
            subtitle: Text('Tope ${clp(p.tope)} · avisa al ${p.alertaPct}%'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await Repo.borrarPresupuesto(p.categoria);
                await widget.recargar();
              },
            ),
            onTap: () async {
              final n = await dialogPresupuesto(context, p);
              if (n != null) {
                await Repo.guardarPresupuesto(n);
                await widget.recargar();
              }
            },
          ),
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Agregar presupuesto'),
          onPressed: () async {
            final n = await dialogPresupuesto(context);
            if (n != null) {
              await Repo.guardarPresupuesto(n);
              await widget.recargar();
            }
          },
        ),
      ]),
      _tarjeta('🏷️ Mis categorías', [
        if (Cats.personalizadas.isEmpty)
          const Text('Aún no creas ninguna. Puedes crearlas al declarar un gasto o aquí.'),
        for (final c in Cats.personalizadas)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(c),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Quitar de la lista (los gastos ya declarados la conservan)',
              onPressed: () async {
                await Repo.borrarCategoria(c);
                if (mounted) setState(() {});
              },
            ),
          ),
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Nueva categoría'),
          onPressed: () async {
            await dialogNuevaCategoria(context);
            if (mounted) setState(() {});
          },
        ),
      ]),
      _tarjeta('⚠️ Correos que no se pudieron leer', [
        if (widget.errores.isEmpty) const Text('Sin errores 🎉'),
        for (final e in widget.errores) ListTile(contentPadding: EdgeInsets.zero, dense: true, title: Text('${e['fecha']} · intentos ${e['intentos']}'), subtitle: Text('${e['motivo']}')),
        if (widget.errores.isNotEmpty)
          OutlinedButton(
            onPressed: () async {
              await Repo.limpiarErrores();
              await widget.recargar();
              msg('Se reintentarán en la próxima sincronización');
            },
            child: const Text('Reintentar todos'),
          ),
      ]),
      _tarjeta('🧠 Memoria de comercios (${mem.length})', [
        if (mem.isEmpty) const Text('Aún vacía. Se llena sola cuando corriges una categoría.'),
        for (final m in mem)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('${m['patron']}'),
            subtitle: Text('${m['categoria']}'),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () async {
                await Repo.borrarComercio('${m['patron']}');
                mem = await Repo.comercios();
                if (mounted) setState(() {});
              },
            ),
          ),
      ]),
      _tarjeta('🔋 Para que funcione siempre (Xiaomi / Redmi)', [
        const Text('Android cierra apps en segundo plano. En tu Redmi:\n'
            '1. Ajustes → Aplicaciones → Administrar aplicaciones → Finanzas.\n'
            '2. Activa «Inicio automático».\n'
            '3. Ahorro de batería → «Sin restricciones».\n'
            '4. Abre Recientes, mantén pulsada la app y toca el candado para fijarla.\n'
            '5. Acepta el permiso de notificaciones.'),
      ]),
      _tarjeta('📤 Respaldo', [
        OutlinedButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('Copiar movimientos como CSV'),
          onPressed: () async {
            final b = StringBuffer('fecha,tipo,tarjeta,comercio,categoria,monto,motivo\n');
            for (final m in widget.movs) {
              String c(String s) => '"${s.replaceAll('"', '""')}"';
              b.writeln('${m.fecha},${c(m.tipo)},${c(m.tarjeta)},${c(m.comercio)},${c(m.categoria)},${m.monto},${c(m.motivo)}');
            }
            await Clipboard.setData(ClipboardData(text: b.toString()));
            msg('CSV copiado al portapapeles');
          },
        ),
      ]),
      const SizedBox(height: 24),
    ]);
  }
}
