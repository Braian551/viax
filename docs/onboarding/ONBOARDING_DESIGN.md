# 🎯 Pantalla de Onboarding - Viax

## 📱 Descripción General

Sistema de introducción profesional con 5 pantallas deslizables que presentan las características principales de la app al usuario cuando la abre por primera vez.

---

## 🎨 Pantallas del Onboarding

### **Pantalla 1: Transporte Rápido y Seguro** 🏍️
- **Icono:** Motocicleta
- **Gradiente:** Amarillo brillante → Amarillo dorado
- **Título:** "Transporte Rápido y Seguro"
- **Descripción:** "Viaja con conductores verificados en motos. Llega a tu destino rápido evitando el tráfico."
- **Mensaje clave:** Velocidad y seguridad en el transporte

---

### **Pantalla 2: Envíos Express** 📦
- **Icono:** Camión de envíos
- **Gradiente:** Amarillo dorado → Amarillo medio
- **Título:** "Envíos Express"
- **Descripción:** "Envía y recibe paquetes de forma rápida y segura. Seguimiento en tiempo real de tus envíos."
- **Mensaje clave:** Servicio de mensajería rápido y rastreable

---

### **Pantalla 3: Viajes Grabados** 🛣️
- **Icono:** Ruta/Trayecto
- **Gradiente:** Amarillo medio → Amarillo naranja
- **Título:** "Viajes Grabados"
- **Descripción:** "Grabamos cada recorrido para tu seguridad. Comparte tu viaje en tiempo real con familiares."
- **Mensaje clave:** Seguridad y tranquilidad para usuarios y familiares

---

### **Pantalla 4: Confianza Total** 🛡️
- **Icono:** Escudo de verificación
- **Gradiente:** Amarillo naranja → Amarillo brillante
- **Título:** "Confianza Total"
- **Descripción:** "Conductores verificados, pagos seguros y soporte 24/7. Tu seguridad es nuestra prioridad."
- **Mensaje clave:** Plataforma confiable y segura

---

### **Pantalla 5: Calidad Garantizada** ⭐
- **Icono:** Estrella
- **Gradiente:** Amarillo brillante → Amarillo dorado
- **Título:** "Calidad Garantizada"
- **Descripción:** "Sistema de calificaciones bidireccional. Los mejores conductores, el mejor servicio."
- **Mensaje clave:** Control de calidad y excelencia en el servicio

---

## ✨ Características de Diseño

### **Header (Superior)**
- Logo pequeño de la app + nombre "Viax"
- Botón "Saltar" en la esquina derecha (se oculta en la última pantalla)

### **Contenido Central**
- Ícono grande con efecto de glow pulsante
- Gradiente circular radial con resplandor amarillo
- Sombra con desenfoque para efecto de profundidad
- Título en blanco, bold, centrado
- Descripción en gris claro, centrada

### **Indicadores de Página**
- Puntos deslizantes que muestran la página actual
- Punto activo: alargado y amarillo brillante
- Puntos inactivos: circulares y grises translúcidos
- Animación suave al cambiar de página

### **Footer (Inferior)**
- **Botón "Atrás"** (solo visible desde la 2da pantalla en adelante)
  - Estilo: Outlined con borde amarillo
  - Texto: amarillo
  
- **Botón "Siguiente"/"Comenzar"**
  - Estilo: Filled amarillo con texto negro
  - Ícono de flecha hacia adelante
  - Texto cambia a "Comenzar" en la última pantalla

---

## 🎯 Flujo de Usuario

```
┌─────────────┐
│   Splash    │ (3.5 seg)
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ AuthWrapper │ (Verificación)
└──────┬──────┘
       │
       ├──── Primera vez? ────► Onboarding (5 pantallas)
       │                              │
       │                              ▼
       │                         Welcome Screen
       │
       ├──── Sesión activa? ──► Home Screen
       │
       └──── Sin sesión? ─────► Welcome Screen
```

---

## 🔧 Configuración Técnica

### **Animaciones**
- PageView con scroll horizontal suave
- Transiciones con curvas `easeInOut` (300ms)
- Indicadores con `AnimatedContainer`
- Efectos de glow con `RadialGradient`

### **Persistencia**
- `SharedPreferences` para guardar estado de onboarding
- Key: `'onboarding_completed'`
- Valor: `true` después de completar o saltar

### **Responsividad**
- Tamaños basados en `MediaQuery`
- Padding adaptativo
- Iconos escalables según tamaño de pantalla

---

## 🎨 Paleta de Colores

| Color | Hex | Uso |
|-------|-----|-----|
| Amarillo Principal | `#FFFF00` | Botones, iconos, acentos |
| Amarillo Dorado | `#FFDD00` | Gradientes |
| Amarillo Medio | `#FFBB00` | Gradientes |
| Amarillo Naranja | `#FF9900` | Gradientes |
| Blanco | `#FFFFFF` | Títulos |
| Gris Claro | `#FFFFFF70` (70% opacity) | Descripciones |
| Negro | `#000000` | Fondo, texto en botones |

---

## 🚀 Mejoras Implementadas

✅ **Diseño profesional** inspirado en Uber, Rappi, DiDi
✅ **Consistencia visual** con la identidad de Viax
✅ **Animaciones fluidas** para mejor UX
✅ **Navegación intuitiva** con gestos y botones
✅ **Responsive design** para diferentes dispositivos
✅ **Iconografía clara** que representa cada característica
✅ **Gradientes dinámicos** para visual atractivo
✅ **Sistema de skip** para usuarios que quieren avanzar rápido
✅ **Persistencia de estado** para no repetir el onboarding
