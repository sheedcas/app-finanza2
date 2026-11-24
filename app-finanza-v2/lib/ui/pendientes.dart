import 'package:flutter/material.dart';

import '../core/analisis.dart';
import '../core/datos.dart';
import '../core/models.dart';
import '../core/sync.dart';
import '../core/util.dart';
import 'forms.dart';

/// Gastos que llegaron por correo y esperan que digas de qué son.
class Pendientes extends StatefulWidget {
  const Pendientes({super.key});

  @override
  State<Pendientes> createState() => _PendientesState();
}

class _PendientesState extends State<Pendientes> {
  List<Mov> lista = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    await Repo.cargarCategorias();
    final t = await Repo.todos();
    if (!mounted) return;
    setState(() => lista = Analisis.porDeclarar(t));
  }

  Future<void> _declarar(Mov m) async {
    final r = await showDeclarar(context, m);
    if (r == null) return;
    await Repo.declarar(m, r.categoria, r.nombre);
    await Sync.alertasTrasDeclarar(m.id!);
    await _cargar();
  }

  Future<void> _aceptarSugeridas() async {
    final conSugerencia = lista.where((m) => m.categoria != 'Otros').toList();
    if (conSugerencia.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Aceptar sugerencias?'),
        content: Text('Se declararán ${conSugerencia.length} gastos con la categoría sugerida (sin nombre). Los demás quedan pendientes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Aceptar')),
        ],
      ),
    );
    if (ok != true) return;
    for (final m in conSugerencia) {
      await Repo.declarar(m, m.categoria, '');
    }
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Por declarar (${lista.length})'),
        actions: [
          if (lista.any((m) => m.categoria != 'Otros'))
            TextButton(onPressed: _aceptarSugeridas, child: const Text('Aceptar sugeridas')),
        ],
      ),
      body: SafeArea(
        child: lista.isEmpty
            ? const Center(child: Text('Todo declarado ✓'))
            : ListView(padding: const EdgeInsets.all(12), children: [
                for (final m in lista)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.pending_actions),
                      title: Text(m.comercio.isEmpty ? '(sin comercio)' : m.comercio),
                      subtitle: Text(m.subtitulo),
                      trailing: Text(clp(m.monto), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      onTap: () => _declarar(m),
                    ),
                  ),
              ]),
      ),
    );
  }
}
