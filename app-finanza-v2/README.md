# Finanzas (APK Android, solo para ti)

App Flutter que vive 100 % en tu teléfono: lee tus correos bancarios, categoriza, controla topes
y te avisa con notificaciones nativas. Sin servidor, sin Telegram, sin Play Store.

## Cómo obtener el APK (sin instalar nada en tu PC)
1. Crea una cuenta gratis en github.com y un repositorio **privado** nuevo.
2. Sube **todo el contenido de esta carpeta** (incluida la carpeta oculta `.github`). Si usas git:
       git init && git add . && git commit -m "app" && git branch -M main
       git remote add origin https://github.com/TU_USUARIO/finanzas.git && git push -u origin main
3. En GitHub: pestaña **Actions → Compilar APK → Run workflow** (también corre solo al subir).
4. Espera ~8 min. Entra a la ejecución y descarga el artefacto **finanzas-apk** (ZIP con `app-release.apk`).
5. Pásalo al Redmi (Drive, cable o Telegram) y ábrelo. Android pedirá permitir «instalar apps desconocidas».

Si el workflow falla, copia el error del paso que quedó en rojo y pásamelo.

## Compilar en tu PC (alternativa)
    flutter create --platforms=android --org cl.personal --project-name finanzas_auto .
    python tool/preparar_android.py
    flutter pub get && flutter build apk --release
(usa Flutter 3.27.4; el APK queda en build/app/outputs/flutter-apk/)

## Primer uso
1. Abre la app → **Ajustes** → completa correo, **clave de aplicación de Gmail** (16 letras; requiere verificación en 2 pasos),
   bancos y, si quieres, la API key de Gemini (aistudio.google.com).
2. **Guardar y activar** → acepta el permiso de notificaciones → **Probar aviso**.
3. Configura tarjetas (tope, % de alerta, día de vencimiento) y presupuestos por categoría.
4. Sigue la guía **Xiaomi/Redmi** de Ajustes (inicio automático, batería sin restricciones, fijar la app). Sin eso HyperOS la cierra.

## Qué hace
- **Gastos por declarar:** cada gasto que llega por correo entra como «Por declarar» (con una categoría sugerida). Tú eliges la categoría
  (o creas una nueva) y, si quieres, un nombre: se muestra como «Supermercado · Cumpleaños de Sofi». Los topes por categoría
  cuentan solo gastos declarados. Si hay gastos sin declarar de ayer o antes, la app te lo recuerda una vez al día.
- Cada ~15 min (límite de Android) revisa el correo, aunque la app esté cerrada, y también al abrirla.
- Regex primero, Gemini solo si no reconoce el formato (con RUT/tarjeta/saldo enmascarados).
- Transferencias internas y pagos de tu tarjeta no cuentan como gasto.
- Movimiento manual + correo del banco con mismo monto (±1 día) se fusionan sin duplicar.
- Topes por tarjeta y categoría, proyección de fin de mes, disponible por día, suscripciones, gasto hormiga,
  anomalías, vencimientos y cierre mensual, todo con notificación.
- Memoria: si corriges una categoría, la recuerda para ese comercio.

## Ajustes a verificar
- Dominios de los bancos (`lib/core/consts.dart`): confirma con un correo real de cada uno, sobre todo Falabella.
- Patrones regex (`lib/core/parser.dart`): genéricos; lo que no reconocen va a Gemini.

## Aún no incluido (próximas versiones)
Vehículo/GPS, deudas en cuotas, lectura de notificaciones de las apps bancarias, respaldo automático a Drive.
