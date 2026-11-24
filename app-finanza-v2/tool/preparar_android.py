"""Se ejecuta después de `flutter create`: deja el proyecto Android listo (permisos, desugaring, minSdk, sin R8)."""
import re
from pathlib import Path

gradle = next((p for p in (Path("android/app/build.gradle"), Path("android/app/build.gradle.kts")) if p.exists()), None)
manifest = Path("android/app/src/main/AndroidManifest.xml")
assert gradle and manifest.exists(), "No se encontró el proyecto Android; ¿corrió flutter create?"

g = gradle.read_text()
kts = gradle.suffix == ".kts"

# 1) desugaring (lo exige flutter_local_notifications)
if "isCoreLibraryDesugaringEnabled" not in g and "coreLibraryDesugaringEnabled" not in g:
    flag = "isCoreLibraryDesugaringEnabled = true" if kts else "coreLibraryDesugaringEnabled true"
    g = re.sub(r"compileOptions\s*\{", "compileOptions {\n        " + flag, g, count=1)
dep = ('    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")' if kts
       else "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'")
if "desugar_jdk_libs" not in g:
    if re.search(r"^dependencies\s*\{", g, re.M):
        g = re.sub(r"^dependencies\s*\{", "dependencies {\n" + dep, g, count=1, flags=re.M)
    else:
        g += "\ndependencies {\n" + dep + "\n}\n"

# 2) minSdk 23 (flutter_secure_storage)
g = re.sub(r"minSdk(?:Version)?\s*=?\s*flutter\.minSdkVersion", "minSdk = 23" if kts else "minSdkVersion 23", g)

# 3) sin minificación (evita problemas de R8 con notificaciones)
if "minifyEnabled" not in g and "isMinifyEnabled" not in g:
    extra = ("\n            isMinifyEnabled = false\n            isShrinkResources = false" if kts
             else "\n            minifyEnabled false\n            shrinkResources false")
    g = re.sub(r"(signingConfig\s*=?\s*signingConfigs\.(?:getByName\(\"debug\"\)|debug))", r"\1" + extra, g, count=1)
gradle.write_text(g)

# 4) permisos y nombre de la app
m = manifest.read_text()
perms = ["INTERNET", "POST_NOTIFICATIONS", "RECEIVE_BOOT_COMPLETED", "WAKE_LOCK", "REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"]
bloque = "".join(f'    <uses-permission android:name="android.permission.{p}"/>\n' for p in perms if p not in m)
m = m.replace("<application", bloque + "    <application", 1)
m = re.sub(r'android:label="[^"]*"', 'android:label="Finanzas"', m, count=1)
manifest.write_text(m)
print("Android listo")
