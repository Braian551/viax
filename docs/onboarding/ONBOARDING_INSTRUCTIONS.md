# Instrucciones para Probar el Onboarding

## Para ver el Onboarding nuevamente

Si ya completaste el onboarding y quieres verlo de nuevo, ejecuta este comando en la terminal:

### Android (Emulador o Dispositivo)
```bash
flutter run --dart-define=RESET_ONBOARDING=true
```

O simplemente elimina los datos de la app desde el dispositivo/emulador:
- Settings → Apps → Viax → Storage → Clear Data

### Alternativa rápida (Durante desarrollo)
Puedes modificar temporalmente el código en `auth_wrapper.dart` para forzar que siempre muestre el onboarding:

```dart
// En _checkSession(), cambia esta línea:
final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

// Por esta (temporalmente):
final onboardingCompleted = false; // Siempre mostrará onboarding
```

## Flujo Completo de la App

1. **Splash Screen** (3.5 segundos) - Logo con animación
2. **Auth Wrapper** - Verifica:
   - Si es primera vez → **Onboarding**
   - Si hay sesión activa → **Home**
   - Si no hay sesión → **Welcome**
3. **Onboarding** (5 pantallas con sliders)
4. **Welcome/Login/Register** - Proceso de autenticación
5. **Home** - Pantalla principal de la app

## Características del Onboarding

- ✅ 5 pantallas informativas con deslizamiento
- ✅ Botón "Saltar" para omitir el onboarding
- ✅ Botón "Atrás" para regresar a la pantalla anterior
- ✅ Indicadores de página animados
- ✅ Iconos con efectos de gradiente y glow
- ✅ Diseño consistente con la identidad visual de la app
- ✅ Se muestra solo la primera vez que se abre la app
- ✅ Responsive y optimizado para diferentes tamaños de pantalla
