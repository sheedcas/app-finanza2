import 'package:flutter/material.dart';

import '../core/consts.dart';
import '../core/datos.dart';
import '../core/models.dart';
import '../core/util.dart';

/// Hoja para agregar o editar un movimiento. Devuelve el Mov o null si se cancela.
Future<Mov?> showMovForm(BuildContext context, List<Tarjeta> tarjetas, {Mov? inicial}) {
  return showModalBottomSheet<Mov>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MovForm(tarjetas: tarjetas, inicial: inicial),
  );
}

class _MovForm extends StatefulWidget {
  final List<Tarjeta> tarjetas;
  final Mov? inicial;
  const _MovForm({required this.tarjetas, this.inicial});

  @override
  State<_MovForm> createState() => _MovFormState();
}

class _MovFormState extends State<_MovForm> {
  late String tipo, tarjeta, categoria, fecha;
  late List<String> nombresTarjeta, opcionesCat;
  final nombre = TextEditingController();
  final comercio = TextEditingController();
  final monto = TextEditingController();
  final motivo = TextEditingController();

  @override
  void initState() {
    super.initState();
    final i = widget.inicial;
    nombresTarjeta = widget.tarjetas.map((t) => t.nombre).toList();
    if (i != null && i.tarjeta.isNotEmpty && !nombresTarjeta.contains(i.tarjeta)) nombresTarjeta.add(i.tarjeta);
    if (nombresTarjeta.isEmpty) nombresTarjeta = ['Sin tarjeta'];
    tipo = i?.tipo ?? gasto;
    tarjeta = (i != null && nombresTarjeta.contains(i.tarjeta)) ? i.tarjeta : nombresTarjeta.first;
    opcionesCat = Cats.todas;
    if (i != null && !opcionesCat.contains(i.categoria)) opcionesCat.add(i.categoria);
    categoria = i?.categoria ?? 'Otros';
    nombre.text = i?.nombre ?? '';
    fecha = i?.fecha ?? iso(DateTime.now());
    comercio.text = i?.comercio ?? '';
    monto.text = i != null ? '${i.monto}' : '';
    motivo.text = i?.motivo ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.inicial == null ? 'Nuevo movimiento' : 'Editar movimiento', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: tipo,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => tipo = v!),
          ),
          DropdownButtonFormField<String>(
            value: tarjeta,
            decoration: const InputDecoration(labelText: 'Tarjeta'),
            items: nombresTarjeta.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => tarjeta = v!),
          ),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: categoria,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: opcionesCat.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => categoria = v!),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Nueva categoría',
              onPressed: () async {
                final n = await dialogNuevaCategoria(context);
                if (n != null) {
                  setState(() {
                    if (!opcionesCat.contains(n)) opcionesCat.add(n);
                    categoria = n;
                  });
                }
              },
            ),
          ]),
          TextField(controller: comercio, decoration: const InputDecoration(labelText: 'Comercio / Origen')),
          TextField(
            controller: nombre,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nombre del gasto (opcional)', hintText: 'Ej. Cumpleaños de Sofi'),
          ),
          TextField(
            controller: monto,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Monto (\$)'),
          ),
          TextField(controller: motivo, decoration: const InputDecoration(labelText: 'Motivo (opcional)')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text('Fecha: $fecha'),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.tryParse(fecha) ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => fecha = iso(d));
            },
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              final m = int.tryParse(monto.text.replaceAll('.', '').trim()) ?? 0;
              if (m <= 0) return;
              Navigator.pop(
                context,
                Mov(
                  id: widget.inicial?.id,
                  uid: widget.inicial?.uid,
                  fecha: fecha,
                  tipo: tipo,
                  tarjeta: tarjeta,
                  comercio: comercio.text.trim(),
                  categoria: categoria,
                  monto: m,
                  motivo: motivo.text.trim(),
                  origen: widget.inicial?.origen ?? 'manual',
                  estado: widget.inicial?.estado ?? 'declarado',
                  nombre: nombre.text.trim(),
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ]),
      ),
    );
  }
}

Future<Tarjeta?> dialogTarjeta(BuildContext context, [Tarjeta? t]) {
  final n = TextEditingController(text: t?.nombre ?? '');
  final tope = TextEditingController(text: '${t?.tope ?? 300000}');
  final al = TextEditingController(text: '${t?.alertaPct ?? 80}');
  final dv = TextEditingController(text: '${t?.diaVenc ?? 0}');
  return showDialog<Tarjeta>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(t == null ? 'Nueva tarjeta' : 'Editar tarjeta'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: n, decoration: const InputDecoration(labelText: 'Nombre (ej. BancoEstado Débito)')),
          TextField(controller: tope, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tope mensual (\$)')),
          TextField(controller: al, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Avisar al (%)')),
          TextField(controller: dv, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Día de vencimiento (0 = ninguno)')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (n.text.trim().isEmpty) return;
            Navigator.pop(
                c,
                Tarjeta(
                  nombre: n.text.trim(),
                  tope: int.tryParse(tope.text) ?? 0,
                  alertaPct: int.tryParse(al.text) ?? 80,
                  diaVenc: (int.tryParse(dv.text) ?? 0).clamp(0, 31),
                ));
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

Future<Presupuesto?> dialogPresupuesto(BuildContext context, [Presupuesto? p]) {
  final opciones = Cats.todas;
  var cat = p?.categoria ?? opciones.first;
  if (!opciones.contains(cat)) opciones.add(cat);
  final tope = TextEditingController(text: '${p?.tope ?? 100000}');
  final al = TextEditingController(text: '${p?.alertaPct ?? 80}');
  return showDialog<Presupuesto>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setSt) => AlertDialog(
        title: Text(p == null ? 'Nuevo presupuesto' : 'Editar presupuesto'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: cat,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: opciones.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
              onChanged: p == null ? (v) => setSt(() => cat = v!) : null,
            ),
            TextField(controller: tope, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tope mensual (\$)')),
            TextField(controller: al, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Avisar al (%)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(c, Presupuesto(categoria: cat, tope: int.tryParse(tope.text) ?? 0, alertaPct: int.tryParse(al.text) ?? 80)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

// ───────── Declarar un gasto: categoría + nombre opcional ─────────
Future<({String categoria, String nombre})?> showDeclarar(BuildContext context, Mov m) {
  return showModalBottomSheet<({String categoria, String nombre})>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _Declarar(mov: m),
  );
}

class _Declarar extends StatefulWidget {
  final Mov mov;
  const _Declarar({required this.mov});

  @override
  State<_Declarar> createState() => _DeclararState();
}

class _DeclararState extends State<_Declarar> {
  String? sel;
  final nombre = TextEditingController();

  @override
  void initState() {
    super.initState();
    final c = widget.mov.categoria;
    if (c != 'Otros' && Cats.todas.contains(c)) sel = c; // sugerencia lista, tú confirmas
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mov;
    final tema = Theme.of(context).textTheme;
    final n = nombre.text.trim();
    final vista = sel == null ? '—' : (n.isEmpty ? sel! : '$sel · $n');
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Declarar gasto', style: tema.titleLarge),
          const SizedBox(height: 4),
          Text('${clp(m.monto)} en ${m.comercio.isEmpty ? '(sin comercio)' : m.comercio}', style: tema.titleMedium),
          Text('${m.fecha} · ${m.tarjeta}', style: tema.bodySmall),
          const SizedBox(height: 12),
          Text('¿De qué es?', style: tema.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final c in Cats.todas.where((c) => c != 'Sueldo / Ingreso' && c != 'Ventas / Extra'))
              ChoiceChip(label: Text(c), selected: sel == c, onSelected: (_) => setState(() => sel = c)),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Nueva categoría'),
              onPressed: () async {
                final nueva = await dialogNuevaCategoria(context);
                if (nueva != null) setState(() => sel = nueva);
              },
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: nombre,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre del gasto (opcional)',
              hintText: 'Ej. Cumpleaños de Sofi',
            ),
          ),
          const SizedBox(height: 8),
          Text('Se verá así: $vista'),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: sel == null ? null : () => Navigator.pop(context, (categoria: sel!, nombre: n)),
            child: const Text('Declarar'),
          ),
        ]),
      ),
    );
  }
}

Future<String?> dialogNuevaCategoria(BuildContext context) async {
  final c = TextEditingController();
  final nombre = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Nueva categoría'),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Nombre (ej. Mascotas, Gas licuado)'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Crear')),
      ],
    ),
  );
  if (nombre == null || nombre.isEmpty) return null;
  return Repo.crearCategoria(nombre);
}
