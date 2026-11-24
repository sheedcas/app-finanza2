String clp(num n) {
  final neg = n < 0;
  final s = n.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${neg ? '-' : ''}\$$b';
}

String iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String mesDe(DateTime d) => iso(d).substring(0, 7);

String mesPrevio(String mes) {
  var y = int.parse(mes.substring(0, 4));
  var m = int.parse(mes.substring(5, 7)) - 1;
  if (m == 0) {
    y -= 1;
    m = 12;
  }
  return '$y-${m.toString().padLeft(2, '0')}';
}

int diasDelMes(int y, int m) => DateTime(y, m + 1, 0).day;

const _tildes = {
  'Á': 'A', 'À': 'A', 'Â': 'A', 'Ä': 'A', 'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
  'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I', 'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Ö': 'O',
  'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U', 'Ñ': 'N',
};

String sinTildes(String s) =>
    s.replaceAllMapped(RegExp('[ÁÀÂÄÉÈÊËÍÌÎÏÓÒÔÖÚÙÛÜÑ]'), (m) => _tildes[m.group(0)]!);

/// Clave estable de un comercio: mayúsculas, sin tildes ni números.
String normComercio(String c) {
  var s = sinTildes(c.toUpperCase());
  s = s.replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ').replaceAll(RegExp(r'\d+'), ' ');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

double mediana(List<num> v) {
  if (v.isEmpty) return 0;
  final s = v.map((e) => e.toDouble()).toList()..sort();
  final n = s.length;
  return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}
