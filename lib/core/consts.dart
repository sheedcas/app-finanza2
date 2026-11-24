const gasto = 'Gasto / Pérdida';
const ingreso = 'Ingreso';
const interna = 'Transferencia interna';
const tipos = [gasto, ingreso, interna];

const categoriasBase = [
  'Supermercado', 'Gasto hormiga', 'Combustible', 'Mantención Auto', 'Luz', 'Agua', 'Gas',
  'Internet / Teléfono', 'Cuentas / Hogar', 'Comida / Delivery', 'Deudas / Cuotas',
  'Salud / Farmacia', 'Transporte', 'Educación', 'Ocio', 'Transferencias',
  'Sueldo / Ingreso', 'Ventas / Extra', 'Pérdida / Multa / Interés', 'Otros',
];

/// Categorías base + las que tú creas al declarar un gasto.
class Cats {
  static List<String> personalizadas = [];
  static List<String> get todas =>
      [...categoriasBase, ...personalizadas.where((c) => !categoriasBase.contains(c))];
}

// Verifica estos dominios con un correo real de cada banco. En Ajustes también puedes escribir el dominio directo.
const dominios = {
  'bancoestado': 'bancoestado.cl',
  'santander': 'santander.cl',
  'falabella': 'bancofalabella.cl',
  'bci': 'bci.cl',
  'tenpo': 'tenpo.cl',
  'itau': 'itau.cl',
  'scotiabank': 'scotiabank.cl',
  'chile': 'bancochile.cl',
};

const keywords = <String, List<String>>{
  'Combustible': ['COPEC', 'SHELL', 'PETROBRAS', 'ENEX', 'TERPEL'],
  'Supermercado': ['JUMBO', 'LIDER', 'UNIMARC', 'SANTA ISABEL', 'TOTTUS', 'ACUENTA'],
  'Comida / Delivery': ['UBER EATS', 'RAPPI', 'PEDIDOSYA', 'MCDONALD', 'STARBUCKS', 'BURGER KING'],
  'Salud / Farmacia': ['CRUZ VERDE', 'SALCOBRAND', 'AHUMADA', 'FARMACIA'],
  'Luz': ['ENEL', 'CGE', 'SAESA', 'FRONTEL'],
  'Agua': ['AGUAS ANDINAS', 'ESSBIO', 'ESVAL', 'AGUAS NUEVAS'],
  'Gas': ['METROGAS', 'LIPIGAS', 'ABASTIBLE', 'GASCO'],
  'Internet / Teléfono': ['VTR', 'ENTEL', 'MOVISTAR', 'CLARO', 'WOM', 'MUNDO'],
};
