# Informe Ejecutivo: Estimación de Costos y Valoración Empresarial de Viax

**Fecha de corte:** 14-feb-2026  
**Proyecto analizado:** Viax (Flutter + PHP/PostgreSQL/MySQL + APIs de mapas)  
**Nivel del informe:** Empresarial / Due Diligence técnica inicial

---

## 1) Resumen Ejecutivo

Viax es una plataforma de movilidad con alcance **multi-rol** (usuario, conductor, admin y empresa), con flujo operativo de punta a punta para registro, solicitud de viaje, cotización, matching, operación y gestión administrativa.

**Conclusión principal:**
- El proyecto representa un activo de software **real y avanzado** (no MVP básico), con módulos de negocio relevantes ya implementados.
- El costo de reconstrucción profesional se ubica en un rango de **USD 95,000 a USD 234,000** (aprox. **COP 380M a COP 936M** con tasa de referencia 4,000 COP/USD).
- La valoración empresarial razonable (sin métricas comerciales verificadas de tracción) se ubica en **USD 120,000 a USD 350,000** (aprox. **COP 480M a COP 1,400M**) bajo escenario pre-seed/seed temprano.

---

## 2) Metodología de evaluación

Se aplicó un enfoque mixto:
1. **Auditoría técnica estructural** (stack, módulos, dependencia funcional).
2. **Inventario archivo por archivo automatizado** con conteo y metadatos.
3. **Estimación de costo de reconstrucción (Cost-to-Recreate)** por horas y tarifa blended.
4. **Ajustes por riesgo y deuda técnica** (seguridad, testing, consistencia de arquitectura).
5. **Valoración por escenarios** (activo software, operación temprana, operación con tracción).

> Se generó anexo técnico de inventario completo: `docs/ANEXO_INVENTARIO_ARCHIVOS.csv`.

---

## 3) Evidencia cuantitativa del proyecto

### 3.1 Inventario de código y documentación (limpio)

- **Archivos inventariados (anexo):** 938
- **Métricas de código/documentación relevantes:**
  - Dart: **461 archivos / 123,397 líneas**
  - PHP: **133 archivos / 24,300 líneas**
  - Markdown: **91 archivos / 18,704 líneas**
  - SQL: **49 archivos / 3,877 líneas**

### 3.2 Distribución por módulos (Frontend Flutter)

- `features`: **104,329 líneas**
  - conductor: 33,203
  - user: 29,955
  - admin: 14,998
  - company: 10,671
  - auth: 6,530
- `global`: 10,539
- `widgets`: 4,656

### 3.3 Distribución por módulos (Backend)

- conductor: 5,219
- migrations: 3,933
- admin: 3,454
- company: 2,853
- user: 2,237
- auth: 1,584
- payment/pricing/rating/notifications/support/chat: presentes y funcionales en distintos niveles

---

## 4) Qué hace el producto (alcance funcional)

### Núcleo del negocio
- Registro/Login y verificación por email.
- Gestión de conductor y documentos.
- Solicitud de viaje en flujo tipo DiDi/Uber (selección + preview/cotización).
- Cálculo de tarifas por reglas (distancia, tiempo, recargos, comisiones).
- Matching y operación de viaje.
- Panel administrativo para gestión y monitoreo.
- Módulos empresariales (company) y soporte operativo.

### Diferenciadores observados
- Arquitectura modular amplia y documentación extensa.
- Integración de mapas, geolocalización, rutas y notificaciones.
- Manejo de disputas/pagos en backend.
- Inicio de capacidades biométricas (servicio Python en modo mock/real opcional).

---

## 5) Estado de madurez técnica

## Fortalezas
- Cobertura funcional amplia para etapa temprana.
- Estructura de carpetas y separación por dominios consistente en gran parte del sistema.
- Capacidad backend operativa y migraciones SQL disponibles.
- Evidencia de pensamiento de microservicios y escalabilidad modular.

## Hallazgos críticos (impacto en valoración)
1. **Seguridad operativa mejorable**:
   - CORS abierto (`Access-Control-Allow-Origin: *`) en endpoints.
   - `display_errors = 1` en configuración backend.
   - Presencia de datos sensibles/credenciales en documentación histórica.
2. **Inconsistencias de entorno/arquitectura**:
   - Evidencia mixta de MySQL y PostgreSQL en documentación/código.
   - Dependencias y documentación con señales de transición no cerrada.
3. **Calidad y mantenibilidad**:
   - Alto volumen de archivos grandes (pantallas monolíticas en Flutter).
   - Cobertura de pruebas automatizadas baja para tamaño de base de código.
4. **Riesgo de escalamiento**:
   - Faltan piezas típicas de hardening empresarial (observabilidad robusta, seguridad API estandarizada, CI/CD maduro de extremo a extremo).

**Efecto empresarial:** reduce múltiplos de valoración y exige presupuesto de hardening antes de escalar agresivamente.

---

## 6) Estimación de costos de construcción (CAPEX histórico equivalente)

## Supuestos base
- Equipo profesional LATAM (mix semi-senior/senior).
- Tarifa blended: **USD 28–45/h**.
- Reescritura funcional equivalente (no copia exacta de defectos).

## Estimación por componente

| Componente | Horas estimadas | Costo USD (rango) |
|---|---:|---:|
| App Flutter (multi-rol + mapas + UX) | 1,800 – 2,600 | 50,400 – 117,000 |
| Backend APIs + lógica de negocio + admin | 900 – 1,400 | 25,200 – 63,000 |
| DB/migraciones + reglas de precios/pagos | 250 – 450 | 7,000 – 20,250 |
| QA, estabilización y pruebas | 250 – 450 | 7,000 – 20,250 |
| DevOps/Release/Seguridad inicial | 180 – 300 | 5,040 – 13,500 |
| PM/Arquitectura/Coordinación | 120 – 250 | 3,360 – 11,250 |
| **TOTAL** | **3,500 – 5,450** | **95,000 – 234,000** |

**Equivalente COP (4,000 COP/USD):** **COP 380M – 936M**.

---

## 7) Costos operativos mensuales (OPEX)

## Infraestructura y servicios (base, pre-escala)

| Rubro | Rango USD/mes |
|---|---:|
| Hosting backend (Railway/VPS) | 20 – 120 |
| Base de datos gestionada | 30 – 200 |
| APIs mapas/rutas/tráfico (uso variable) | 0 – 800 |
| Email transaccional | 10 – 80 |
| Observabilidad/backups/CDN/dominios | 20 – 150 |
| **Subtotal técnico** | **80 – 1,350** |

## Operación mínima recomendada (equipo)

| Perfil | Dedicación | Rango USD/mes |
|---|---|---:|
| 1 Full-Stack (mantenimiento + evolutivo) | Full/Part | 2,000 – 5,000 |
| QA/Soporte técnico | Part-time | 500 – 2,000 |
| DevOps/SecOps (bolsa) | Part-time | 300 – 1,500 |
| **Subtotal humano** |  | **2,800 – 8,500** |

**OPEX total sugerido:** **USD 2,880 – 9,850/mes** (sin marketing ni nómina comercial).

---

## 8) Valoración empresarial (escenarios)

## A) Valor del activo software (IP + código + documentación)
- Método principal: costo de reemplazo ajustado por deuda técnica.
- Rango razonable: **USD 90,000 – 180,000**.

## B) Valor empresa pre-seed/seed temprano (sin KPI comerciales auditados)
- Incluye activo + capacidad operativa + time-to-market ya ganado.
- Rango razonable: **USD 120,000 – 350,000**.

## C) Escenario con tracción verificable (no disponible en este análisis)
- Si existen KPIs reales (GMV, take-rate, MAU, retención, CAC/LTV), la valoración puede aumentar significativamente.
- Banda orientativa: **USD 350,000 – 1,500,000+** según desempeño y crecimiento.

> Sin métricas comerciales auditadas, defender valoración por encima del rango B es difícil en comité de inversión.

---

## 9) Plan de incremento de valor (90 días)

1. **Hardening de seguridad (prioridad alta)**
   - Cerrar CORS por whitelist, ocultar errores en producción, rotar secretos, validar exposición histórica.
2. **Normalización de arquitectura y entornos**
   - Unificar motor DB objetivo y eliminar ambigüedades de configuración.
3. **Calidad y pruebas**
   - Subir cobertura en módulos críticos (auth, pricing, payment, trip lifecycle).
4. **Operación y observabilidad**
   - Trazabilidad de errores, dashboards y alertas de negocio/técnicas.
5. **Monetización y métricas de inversión**
   - Instrumentar KPIs: viajes/día, tasa de aceptación, cancelación, margen, cohortes.

**Impacto esperado:** mejora de riesgo percibido y potencial de múltiplo de valoración.

---

## 10) Conclusión profesional

Viax tiene un nivel de desarrollo técnico y funcional que supera un prototipo y puede considerarse un **activo digital de valor medio-alto en etapa temprana**. La base permite operar y evolucionar, pero para sostener una valoración empresarial superior requiere un ciclo corto de hardening técnico, seguridad y métricas comerciales trazables.

**Rango recomendado para negociación hoy (sin tracción auditada):**
- **Valor activo tecnológico:** USD 90k – 180k
- **Valor empresarial temprano:** USD 120k – 350k

---

## Anexo A) Entregables de esta evaluación

- Informe ejecutivo: `docs/ESTIMACION_COSTOS_Y_VALORACION_EMPRESARIAL_VIAX.md`
- Inventario archivo por archivo: `docs/ANEXO_INVENTARIO_ARCHIVOS.csv`

---

## Nota importante

Este informe es una **estimación técnica-financiera profesional** basada en evidencia del repositorio y su documentación interna. No sustituye una due diligence legal, fiscal o comercial completa, ni una auditoría externa de seguridad o estados financieros.
