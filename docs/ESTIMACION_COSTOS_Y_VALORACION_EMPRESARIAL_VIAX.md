# Informe Ejecutivo: Estimación de Costos y Valoración Empresarial de Viax

**Fecha de corte:** 18-mar-2026  
**Proyecto analizado:** Viax (Flutter + React/Vite + PHP/PostgreSQL + Redis + Workers + Cloudflare R2 + Python)  
**Nivel del informe:** Empresarial / Due Diligence técnica actualizada

---

## 1) Resumen Ejecutivo

Viax es una plataforma de movilidad con alcance **multi-rol** (usuario, conductor, admin y empresa), con flujo operativo de punta a punta para registro, solicitud de viaje, cotización, matching en tiempo real, operación geolocalizada y gestión administrativa.

Desde la evaluación anterior (14-feb-2026), el proyecto ha experimentado un **crecimiento sustancial** en complejidad, arquitectura y capacidades:

- Se incorporó un **sitio web completo** (`sitioweb/`) con dashboards multi-rol (React/Vite, 107 archivos, 21,654 líneas).
- Se implementó una capa de **Redis** como motor de caché, colas de mensajes, Redis Streams y pub/sub.
- Se añadieron **7 workers de backend** para dispatch de viajes, tracking por streams, surge pricing, cache de zonas, reposicionamiento de conductores y eliminación de cuentas.
- Se integró **Cloudflare R2** como almacenamiento de objetos (logos, documentos, fotos de perfil).
- Se desarrolló un **ConcurrencyService** con bloqueos distribuidos, optimistic locking e idempotencia.
- El código total pasó de **938 a 2,401 archivos** inventariados.

**Conclusión principal actualizada:**
- El proyecto representa un activo de software **avanzado y arquitecturalmente maduro** con capacidades de producción reales.
- El costo de reconstrucción profesional se ubica en un rango de **USD 155,000 a USD 385,000** (aprox. **COP 620M a COP 1,540M** con tasa de referencia 4,000 COP/USD).
- La valoración empresarial razonable (sin métricas comerciales verificadas de tracción) se ubica en **USD 200,000 a USD 550,000** (aprox. **COP 800M a COP 2,200M**) bajo escenario pre-seed/seed temprano.

---

## 2) Metodología de evaluación

Se aplicó un enfoque mixto:
1. **Auditoría técnica estructural** (stack, módulos, dependencia funcional).
2. **Inventario archivo por archivo automatizado** con conteo y metadatos.
3. **Análisis de complejidad arquitectónica** (patrones asincrónicos, concurrencia, colas, caching).
4. **Estimación de costo de reconstrucción (Cost-to-Recreate)** por horas y tarifa blended.
5. **Ajustes por riesgo y deuda técnica** (seguridad, testing, consistencia de arquitectura).
6. **Valoración por escenarios** (activo software, operación temprana, operación con tracción).

> Se generó anexo técnico de inventario completo: `docs/ANEXO_INVENTARIO_ARCHIVOS.csv`.

---

## 3) Evidencia cuantitativa del proyecto

### 3.1 Inventario de código y documentación (limpio)

- **Archivos inventariados (total):** 2,401
- **Métricas de código/documentación relevantes:**

| Tecnología | Archivos | Líneas | Δ vs Feb-26 |
|---|---:|---:|---:|
| Dart (Flutter) | 528 | 147,873 | +14.5% / +19.8% |
| PHP (Backend) | 242 | 40,727 | +81.9% / +67.6% |
| JSX/JS/CSS (Sitio Web) | 107 | 21,654 | **NUEVO** |
| SQL (Migraciones) | 123 | 8,778 | +151% / +126% |
| Markdown (Docs) | 195 | 37,051 | +114% / +98% |

### 3.2 Distribución por módulos (Frontend Flutter)

| Módulo | Líneas | Δ vs Feb-26 |
|---|---:|---:|
| conductor | 38,101 | +14.7% |
| user | 34,004 | +13.5% |
| admin | 16,720 | +11.5% |
| company | 13,488 | +26.4% |
| auth | 7,405 | +13.4% |
| global | 13,421 | +27.3% |
| widgets | 5,211 | +11.9% |
| **Total features** | **128,350** | **+16.0%** |

### 3.3 Distribución por módulos (Backend PHP)

| Módulo | Líneas | Descripción |
|---|---:|---|
| conductor | 8,599 | Gestión de conductores, documentos, verificación |
| admin | 4,734 | Panel administrativo, gestión empresarial |
| company/empresa | 6,071 | Módulos de empresa combinados |
| user | 4,064 | Gestión de usuarios |
| migrations | 4,543 | Esquema DB y migraciones SQL |
| services | 3,129 | Servicios de negocio core (matching, pricing, tracking, traffic, ETA) |
| auth | 1,735 | Autenticación, OTP, verificación email |
| **workers** | **1,163** | **Colas, streams y procesos asíncronos** |
| config | 1,279 | Redis, DB, R2, concurrencia, timezone |
| support | 1,138 | Soporte y disputas |
| rating | 669 | Sistema de calificaciones |
| confianza | 640 | Verificación de confianza |
| chat | 615 | Mensajería en tiempo real |
| payment/pricing | 851 | Pagos y precios |
| notifications | 287 | Notificaciones push |
| otros (utils, core, middleware, routing) | ~3,200 | Utilidades, mailer, PDF, geolocalización |

### 3.4 Distribución (Sitio Web — React/Vite) **[NUEVO]**

| Módulo | Líneas | Descripción |
|---|---:|---|
| shared (layout/utils) | 5,606 | Layout compartido, DashboardLayout, contextos, utilidades |
| empresa | 3,859 | Dashboard empresa, pagos, conductores |
| admin | 3,412 | Panel administrativo web, comprobantes, gestión |
| auth | 2,462 | Login, registro, OTP, contexto de autenticación |
| locationShare | 1,175 | Compartir ubicación en tiempo real |
| conductor | 467 | Dashboard conductor web |
| cliente | 291 | Dashboard cliente web |
| pages (landing) | ~5,100 | Landing page, FAQ, legal, SEO |
| styles (global CSS) | ~1,300 | Sistema de estilos global dark/light mode |

---

## 4) Qué hace el producto (alcance funcional)

### Núcleo del negocio
- Registro/Login con verificación por email y OTP.
- Gestión de conductor con documentos y estado de verificación.
- Solicitud de viaje en flujo tipo DiDi/Uber (selección + preview/cotización).
- Cálculo de tarifas por reglas (distancia, tiempo, recargos, comisiones, surge pricing dinámico).
- Matching y dispatch en tiempo real con Redis queues y workers dedicados.
- Panel administrativo multi-plataforma (Flutter + Web).
- Módulos empresariales (company) con gestión de pagos y conductores asignados.
- Sitio web completo con dashboards multi-rol y landing corporativa.

### Nuevos diferenciadores (vs Feb-2026)

| Capacidad | Implementación |
|---|---|
| **Dispatch asíncrono por colas** | `dispatch_worker.php` — Worker Redis con BRPOP, ofertas por lotes, timeout configurable, observabilidad JSON |
| **Tracking por Redis Streams** | `tracking_stream_worker.php` — XREADGROUP consumer groups, batch insert, XAUTOCLAIM para mensajes huérfanos |
| **Surge pricing dinámico** | `surge_pricing_worker.php` — Multiplicador por grid basado en ratio demanda/oferta en ventana de 10 min |
| **Cache de zonas para dispatch** | `zone_cache_worker.php` — ZSET de top conductores por grid, TTL 10s, recálculo cada 2s |
| **Reposicionamiento de conductores** | `driver_reposition_worker.php` — Sugerencias de movimiento a hotspots, pub/sub a app conductor |
| **Concurrencia distribuida** | `ConcurrencyService` (496 líneas) — Bloqueos distribuidos, optimistic locking con versionamiento, idempotencia |
| **Almacenamiento en la nube** | `R2Service` (378 líneas) — Cloudflare R2 con firma AWS4-HMAC-SHA256, upload/get/delete/list |
| **Rate limiting de email** | `EmailRateLimiter` — Control de envío por ventana temporal |
| **Seguridad mejorada** | `SecurityLogger`, `AuthMiddleware`, `RateLimitMiddleware` |
| **Google OAuth** | `google_oauth.php` — Login con Google integrado |
| **Verificación biométrica** | `verify_face.py` — Python con face_recognition (modo real/mock) |
| **Máquina de estados de viaje** | `trip_state_machine.php` — Transiciones validadas del ciclo de vida de viaje |
| **Eliminación de cuentas** | `account_deletion_worker.php` — Proceso async de borrado GDPR-aware |

### Arquitectura de capas (Backend)

```
┌──────────────────────────────────────────────────────────┐
│                     CLIENTES                             │
│              Flutter App + Sitio Web React               │
├──────────────────────────────────────────────────────────┤
│                   API REST (PHP)                         │
│        Routes → Controllers → Services → Repos          │
├──────────────┬───────────────────────┬───────────────────┤
│   PostgreSQL │    Redis (Cache/Queue │   Cloudflare R2   │
│   (Primario) │    /Streams/PubSub)  │   (Almacenamiento)│
├──────────────┴───────────────────────┴───────────────────┤
│                 WORKERS ASÍNCRONOS                        │
│  dispatch │ tracking │ surge │ zone_cache │ reposition   │
│           │  stream  │pricing│   worker   │   worker     │
├──────────────────────────────────────────────────────────┤
│              SERVICIOS EXTERNOS                           │
│  Google Maps │ Firebase │ Email SMTP │ Python Face Auth   │
└──────────────────────────────────────────────────────────┘
```

---

## 5) Estado de madurez técnica

### Fortalezas (mejoradas vs Feb-2026)
- Arquitectura backend ahora exhibe **patrones de producción reales**: colas, streams, workers, locks distribuidos.
- **Redis integrado** como capa de caché y mensajería con graceful degradation (funciona sin Redis).
- **Plataforma multi-canal**: app Flutter + sitio web React con dashboards compartidos.
- Patrón MVC emergente (controllers, services, repositories) en backend.
- **Observabilidad**: métricas en Redis (`metrics:*`), logging estructurado JSON, heartbeats de workers.
- ConcurrencyService con **idempotencia** y **optimistic locking** — patrones enterprise.
- Almacenamiento cloud con Cloudflare R2 y proxy backend.
- Middleware de seguridad (auth, rate limit).
- Cobertura funcional amplia con 7+ módulos de negocio activos.
- Google OAuth y flujo OTP de registro implementados.

### Hallazgos críticos (impacto en valoración)
1. **Seguridad operativa mejorada pero aún con margen**:
   - CORS mejorado pero requiere configuración por whitelist en producción.
   - Middleware de rate limit implementado — nivel base correcto.
   - Credenciales manejadas por variables de entorno (mejora vs hardcoded).
2. **Consistencia de arquitectura**:
   - Backend unificado en PostgreSQL (migración completada).
   - Quedan servicios legacy con nomenclatura mixta (snake_case vs PascalCase).
3. **Calidad y mantenibilidad**:
   - Alto volumen de archivos grandes (pantallas monolíticas en Flutter persistentes).
   - Cobertura de pruebas automatizadas aún baja para tamaño de base de código.
   - `Mailer.php` (~70KB) es monolítico y candidato a refactorización.
4. **Riesgo de escalamiento**:
   - Workers operan como long-running PHP processes (Supervisor) — funcional pero no óptimo vs NodeJS/Go para alta escala.
   - CI/CD presente (`.github/`) pero madurez por verificar.

**Efecto empresarial:** la mejora arquitectónica reduce significativamente el riesgo técnico percibido. Quedan oportunidades de hardening para escala agresiva.

---

## 6) Estimación de costos de construcción (CAPEX histórico equivalente)

### Supuestos base
- Equipo profesional LATAM (mix semi-senior/senior).
- Tarifa blended: **USD 28–45/h**.
- Reescritura funcional equivalente (no copia exacta de defectos).
- **Incluye ahora**: sitio web, workers, Redis, R2, concurrencia.

### Estimación por componente

| Componente | Horas estimadas | Costo USD (rango) |
|---|---:|---:|
| App Flutter (multi-rol + mapas + UX) | 2,200 – 3,200 | 61,600 – 144,000 |
| Sitio Web React (dashboards + landing) | 500 – 800 | 14,000 – 36,000 |
| Backend APIs + lógica de negocio + admin | 1,200 – 1,800 | 33,600 – 81,000 |
| Workers + Redis + Colas + Streams | 350 – 550 | 9,800 – 24,750 |
| Almacenamiento R2 + proxy | 80 – 120 | 2,240 – 5,400 |
| Concurrencia + locks distribuidos | 100 – 160 | 2,800 – 7,200 |
| DB/migraciones + reglas precios/pagos | 300 – 500 | 8,400 – 22,500 |
| Email + notificaciones + PDF | 120 – 200 | 3,360 – 9,000 |
| QA, estabilización y pruebas | 350 – 550 | 9,800 – 24,750 |
| DevOps/Release/Seguridad/Supervisor | 200 – 350 | 5,600 – 15,750 |
| PM/Arquitectura/Coordinación | 150 – 300 | 4,200 – 13,500 |
| **TOTAL** | **5,550 – 8,530** | **155,400 – 383,850** |

**Equivalente COP (4,000 COP/USD):** **COP 621M – 1,535M**.

### Comparativa vs evaluación anterior (Feb-2026)

| Métrica | Feb-2026 | Mar-2026 | Δ |
|---|---:|---:|---:|
| Horas estimadas | 3,500 – 5,450 | 5,550 – 8,530 | **+58% – 56%** |
| Costo USD | 95k – 234k | 155k – 384k | **+63% – 64%** |
| Archivos totales | 938 | 2,401 | **+156%** |
| Líneas Dart | 123,397 | 147,873 | **+20%** |
| Líneas PHP | 24,300 | 40,727 | **+68%** |

---

## 7) Costos operativos mensuales (OPEX)

### Infraestructura y servicios (base, pre-escala)

| Rubro | Rango USD/mes |
|---|---:|
| Hosting backend (VPS/Railway) | 30 – 150 |
| Base de datos PostgreSQL gestionada | 30 – 200 |
| **Redis (managed / Upstash / Railway)** | **15 – 80** |
| **Cloudflare R2 (almacenamiento)** | **5 – 50** |
| APIs mapas/rutas/tráfico (uso variable) | 0 – 800 |
| Email transaccional (SMTP) | 10 – 80 |
| Firebase (auth/push) | 0 – 50 |
| Observabilidad/backups/CDN/dominios | 20 – 150 |
| **Subtotal técnico** | **110 – 1,560** |

### Operación mínima recomendada (equipo)

| Perfil | Dedicación | Rango USD/mes |
|---|---|---:|
| 1 Full-Stack (mantenimiento + evolutivo) | Full/Part | 2,000 – 5,000 |
| 1 Frontend React/Flutter | Part-time | 1,000 – 3,000 |
| QA/Soporte técnico | Part-time | 500 – 2,000 |
| DevOps/SecOps (bolsa) | Part-time | 300 – 1,500 |
| **Subtotal humano** |  | **3,800 – 11,500** |

**OPEX total sugerido:** **USD 3,910 – 13,060/mes** (sin marketing ni nómina comercial).

---

## 8) Valoración empresarial (escenarios)

### A) Valor del activo software (IP + código + documentación + arquitectura)
- Método principal: costo de reemplazo ajustado por deuda técnica.
- Factor de ajuste: 0.85x (mejora vs 0.75x anterior por reducción de deuda técnica).
- Rango razonable: **USD 130,000 – 325,000**.

### B) Valor empresa pre-seed/seed temprano (sin KPI comerciales auditados)
- Incluye activo + capacidad operativa + time-to-market ya ganado + plataforma multi-canal.
- Múltiplo time-to-market: 1.3x – 1.7x del activo (mejorado por madurez técnica).
- Rango razonable: **USD 200,000 – 550,000**.

### C) Escenario con tracción verificable (no disponible en este análisis)
- Si existen KPIs reales (GMV, take-rate, MAU, retención, CAC/LTV), la valoración puede aumentar significativamente.
- Banda orientativa: **USD 550,000 – 2,000,000+** según desempeño y crecimiento.

### Comparativa de valoración

| Escenario | Feb-2026 | Mar-2026 | Justificación del aumento |
|---|---:|---:|---|
| Activo software | 90k – 180k | 130k – 325k | +45%/+81% — arquitectura de producción real, multi-canal |
| Empresa temprana | 120k – 350k | 200k – 550k | +67%/+57% — reducción de riesgo técnico, time-to-market |
| Con tracción | 350k – 1.5M | 550k – 2M+ | Potencial aumentado por capacidad de escala real |

> Sin métricas comerciales auditadas, defender valoración por encima del rango B es difícil en comité de inversión.

---

## 9) Plan de incremento de valor (90 días)

1. **Hardening de seguridad (prioridad alta)**
   - Implementar whitelist CORS por dominio en producción.
   - Auditar exposición de secretos en historial de git.
   - Rotar credenciales R2/DB/Redis.
2. **Refactorización de servicios monolíticos**
   - Dividir `Mailer.php` (~70KB) en módulos especializados.
   - Estandarizar nomenclatura backend (PascalCase consistente).
3. **Calidad y pruebas**
   - Subir cobertura de test en módulos críticos (auth, pricing, payment, trip lifecycle, concurrency).
   - Tests de integración para workers (dispatch, tracking, surge pricing).
4. **Operación y observabilidad**
   - Dashboard de métricas Redis (Grafana/similar) para métricas `metrics:*` ya instrumentadas.
   - Alertas automatizadas en heartbeats de workers.
5. **Monetización y métricas de inversión**
   - Instrumentar KPIs: viajes/día, tasa de aceptación, cancelación, margen, surge factor promedio, cohortes de retención.
6. **Escalabilidad**
   - Evaluar migración de workers PHP a Node.js/Go para alta concurrencia.
   - Implementar circuit breakers en servicios externos (Google Maps, Firebase).

**Impacto esperado:** mejora de riesgo percibido, aumento de múltiplo de valoración y preparación para ronda seed.

---

## 10) Conclusión profesional

Viax ha evolucionado significativamente desde la evaluación inicial (Feb-2026). Ya no es un MVP avanzado: es una **plataforma multi-canal con arquitectura de producción** que incluye procesamiento asíncrono, caching distribuido, almacenamiento en la nube y concurrencia enterprise-grade.

El salto de 938 a 2,401 archivos, la incorporación de un sitio web completo con dashboards multi-rol, y la implementación de workers de dispatch, tracking y surge pricing representan una **inversión técnica sustancial** que incrementa tanto el costo de replicación como el valor intrínseco del activo.

**Rango recomendado para negociación hoy (sin tracción auditada):**
- **Valor activo tecnológico:** USD 130k – 325k
- **Valor empresarial temprano:** USD 200k – 550k

---

## Anexo A) Entregables de esta evaluación

- Informe ejecutivo: `docs/ESTIMACION_COSTOS_Y_VALORACION_EMPRESARIAL_VIAX.md`
- Inventario archivo por archivo: `docs/ANEXO_INVENTARIO_ARCHIVOS.csv`

---

## Anexo B) Stack tecnológico completo (Mar-2026)

| Capa | Tecnologías |
|---|---|
| App móvil | Flutter/Dart (528 archivos) |
| Sitio web | React + Vite + CSS (107 archivos) |
| Backend API | PHP 8.x (REST, MVC emergente) |
| Base de datos | PostgreSQL (123 migraciones SQL) |
| Cache/Colas | Redis (cache, BRPOP queues, Streams, Pub/Sub, ZSET) |
| Almacenamiento | Cloudflare R2 (S3-compatible, firma AWS4-HMAC-SHA256) |
| Workers | PHP long-running (Supervisor): dispatch, tracking, surge, zone_cache, reposition, account_deletion |
| Autenticación | Firebase Auth + Google OAuth + OTP email |
| Mapas | Google Maps (Places, Roads, Directions, Traffic) |
| Notificaciones | Firebase Cloud Messaging + Email SMTP |
| Biometría | Python (face_recognition) |
| CI/CD | GitHub Actions |
| Hosting | Railway (backend), Cloudflare (R2/CDN) |
| Documentación | 195 archivos Markdown, 37,051 líneas |

---

## Nota importante

Este informe es una **estimación técnica-financiera profesional** basada en evidencia del repositorio y su documentación interna. No sustituye una due diligence legal, fiscal o comercial completa, ni una auditoría externa de seguridad o estados financieros.
