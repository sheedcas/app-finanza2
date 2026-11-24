import 'package:finanzas_auto/core/consts.dart';
import 'package:finanzas_auto/core/parser.dart';
import 'package:finanzas_auto/core/util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compra con saldo en el correo', () {
    final r = ParserCorreo.parseRegex(
        'Estimado cliente, se realizó una compra por \$23.990 en Jumbo Costanera con tu tarjeta de débito. Saldo disponible: \$500.000',
        'Compra con tarjeta');
    expect(r, isNotNull);
    expect(r!['tipo'], gasto);
    expect(r['monto'], 23990);
    expect(r['comercio'], 'Jumbo Costanera');
  });

  test('ingreso por transferencia recibida', () {
    final r = ParserCorreo.parseRegex('Has recibido una transferencia recibida de Juan Pérez por \$150.000.', 'Abono');
    expect(r!['tipo'], ingreso);
    expect(r['monto'], 150000);
  });

  test('pago de tarjeta propia es transferencia interna', () {
    final r = ParserCorreo.parseRegex('Pago de tarjeta de crédito por \$200.000', 'Pago tarjeta');
    expect(r!['tipo'], interna);
  });

  test('ambiguo → null (lo resuelve la IA)', () {
    expect(ParserCorreo.parseRegex('compra por \$1.000 y abono por \$2.000', 'x'), isNull);
  });

  test('enmascarar y normalizar', () {
    final t = ParserCorreo.enmascarar('RUT 12.345.678-9 tarjeta 4111 1111 1111 1111');
    expect(t.contains('12.345'), isFalse);
    expect(normComercio('Panadería Doña Rosa 3'), 'PANADERIA DONA ROSA');
    expect(clp(1234567), '\$1.234.567');
  });
}
