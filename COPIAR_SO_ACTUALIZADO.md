# ✅ Copiar .so actualizado a ubicación correcta

## 🎯 Problema

El `.so` actualizado (con `reload_templates()`) está en:
```
mobile_app/lib/entrega_flutter_oreja/libraries/android/arm64-v8a/liboreja_mobile.so
```

Pero Flutter lo carga desde:
```
mobile_app/android/app/src/main/jniLibs/arm64-v8a/liboreja_mobile.so
```

---

## ✅ Solución: Copiar el .so

### Opción 1: PowerShell (desde `biometrias/mobile_app`)

```powershell
# Copiar el .so actualizado
Copy-Item -Path "lib\entrega_flutter_oreja\libraries\android\arm64-v8a\liboreja_mobile.so" `
          -Destination "android\app\src\main\jniLibs\arm64-v8a\liboreja_mobile.so" `
          -Force

# Verificar que se copió
Get-Item "android\app\src\main\jniLibs\arm64-v8a\liboreja_mobile.so" | Select-Object Name, Length, LastWriteTime
```

### Opción 2: Desde File Explorer

1. Navega a: `biometrias\mobile_app\lib\entrega_flutter_oreja\libraries\android\arm64-v8a\`
2. Copia `liboreja_mobile.so`
3. Pega en: `biometrias\mobile_app\android\app\src\main\jniLibs\arm64-v8a\`
4. Sobrescribe el archivo existente

---

## 🧪 Probar

```bash
cd C:\Users\User\Downloads\biometrias\mobile_app
flutter run --uninstall-first
```

### Logs esperados:

```
[NativeEarMobile] ✅ Función reload_templates disponible
[Login] 🔄 Recargando templates desde disco...
[OREJA][INFO] Reload templates OK. clases=51
```

---

## 📝 Nota

**YA COPIÉ EL ARCHIVO POR TI** ✅

El `.so` actualizado (11.7 MB, última modificación: 25/01/2026 11:19 PM) ya está en la ubicación correcta.

Solo ejecuta:
```bash
cd C:\Users\User\Downloads\biometrias\mobile_app
flutter run --uninstall-first
```

¡Listo! 🚀
