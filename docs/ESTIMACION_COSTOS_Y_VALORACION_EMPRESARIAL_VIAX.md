# Informe Ejecutivo: Estimacion de Costos y Valorizacion Empresarial de VIAX TECHNOLOGY S.A.S.

**Fecha de corte tecnica:** 21-mar-2026  
**Proyecto analizado:** Viax (Flutter + PHP + PostgreSQL + Redis + React/Vite + Cloudflare R2 + Python)  
**Objetivo:** actualizar costo de reconstruccion y rango de valorizacion para potenciales accionistas, en contexto colombiano

---

## 1) Resumen ejecutivo actualizado

Con base en un inventario **archivo por archivo** del repositorio actual, Viax se mantiene como un activo tecnologico de complejidad alta, multi-canal y con modulos operativos reales para usuario, conductor, empresa y administracion.

Resultados clave de esta actualizacion:

- **Costo de reconstruccion (CAPEX equivalente):** **COP 485.6M a COP 1,651.7M**.  
- **Valor del activo software ajustado por riesgo:** **COP 380M a COP 1,520M**.  
- **Valor empresarial temprano (sin KPIs comerciales auditados):** **COP 700M a COP 2,200M**.  
- **Moneda de referencia principal del informe:** pesos colombianos (COP).  
- **TRM de sensibilidad usada para equivalencia USD:** 3,692.48 COP/USD (referencia 20-mar-2026).

---

## 2) Metodologia de analisis archivo por archivo

Se realizo inventario automatizado de todos los archivos del proyecto y se regenero:

- `docs/ANEXO_INVENTARIO_ARCHIVOS.csv`

Campos del anexo:

- `Path`
- `Root`
- `Extension`
- `SizeBytes`
- `IsText`
- `Lines`

Alcance del inventario:

- **Arbol completo (incluyendo terceros y generados):** 28,176 archivos, 2.45 GB.
- **Analisis financiero-tecnico (codigo/documentacion propia):** 1,360 archivos.
- **Archivos de texto evaluados:** 1,204.
- **Lineas de texto evaluadas:** 256,098.

Exclusiones para valorizacion:

- `.git`, `.dart_tool`, `build`, `node_modules`, `vendor`, `.idea`, `.safe-release`, `backups`.

---

## 3) Evidencia cuantitativa actual del producto

### 3.1 Distribucion por tecnologia (codigo/documentacion propia)

| Tecnologia | Archivos | Lineas |
|---|---:|---:|
| Dart (Flutter) | 545 | 150,159 |
| PHP (Backend) | 260 | 42,223 |
| JSX/JS/CSS (Sitio web) | 110 | 26,272 |
| SQL (Migraciones) | 69 | 4,612 |
| Markdown (Docs) | 102 | 19,122 |
| JSON | 12 | 4,732 |

### 3.2 Distribucion por capa principal

| Capa | Archivos | Lineas de texto |
|---|---:|---:|
| `lib/` (Flutter app) | 545 | 150,416 |
| `backend/` (API + servicios) | 360 | 50,337 |
| `sitioweb/` (React/Vite) | 140 | 30,467 |
| `docs/` | 78 | 16,574 |

### 3.3 Modulos Flutter (lib/src/features)

| Modulo | Archivos | Lineas |
|---|---:|---:|
| conductor | 139 | 38,187 |
| user | 107 | 33,848 |
| admin | 46 | 16,720 |
| company | 47 | 13,488 |
| auth | 22 | 7,542 |

### 3.4 Modulos backend (PHP + SQL + soporte)

| Modulo | Archivos | Lineas |
|---|---:|---:|
| conductor | 40 | 8,615 |
| admin | 21 | 4,734 |
| migrations | 70 | 4,621 |
| company | 14 | 4,408 |
| user | 24 | 4,359 |
| services | 24 | 3,161 |
| workers | 6 | 1,163 |

### 3.5 Sitio web (sitioweb/src/features)

| Modulo | Archivos | Lineas |
|---|---:|---:|
| shared | 32 | 5,606 |
| empresa | 11 | 3,859 |
| admin | 13 | 3,412 |
| auth | 11 | 2,462 |
| locationShare | 4 | 1,175 |

### 3.6 Hallazgos de calidad para inversion

- Pruebas automatizadas identificadas en el repositorio: **4 archivos**.
- No se encontro pipeline activo en `.github/workflows`.
- Existen capacidades avanzadas (workers, colas, concurrencia), pero el riesgo de ejecucion aun depende de reforzar testing y CI.

---

## 4) Alcance funcional vigente

Capacidades implementadas y relevantes para negocio:

- Registro/login con OTP y flujos multirol.
- Onboarding de conductores, documentos y validaciones.
- Cotizacion de viaje y configuracion de tarifas.
- Operacion de viajes con geolocalizacion y lifecycle.
- Modulo empresa (pagos, deuda, reportes, conductores, vehiculos).
- Modulo admin para gobierno operativo y financiero.
- Sitio web comercial + dashboards operativos.
- Workers backend para dispatch/tracking/surge/cache/reposition/account deletion.

---

## 5) Estimacion de costos de reconstruccion (CAPEX) en COP

### 5.1 Supuestos de modelacion

- Reescritura funcional equivalente por equipo profesional en Colombia.
- Tarifas de ejecucion usadas (mezcla servicios/nomina): **70,000 a 200,000 COP/h** segun especialidad.
- No incluye compra de base de usuarios ni valor de marca.

### 5.2 Costo por componente

| Componente | Horas estimadas | Costo COP (rango) |
|---|---:|---:|
| App Flutter (multirol) | 2,300 - 3,400 | 184.0M - 578.0M |
| Sitio web React/Vite | 650 - 1,000 | 45.5M - 160.0M |
| Backend PHP + APIs negocio | 1,400 - 2,200 | 112.0M - 396.0M |
| Workers + Redis + concurrencia | 450 - 700 | 40.5M - 133.0M |
| Integraciones externas (Maps/Firebase/R2/Email/Biometria) | 280 - 450 | 23.8M - 81.0M |
| BD y migraciones | 300 - 520 | 22.5M - 83.2M |
| QA + hardening + DevOps | 500 - 850 | 37.5M - 144.5M |
| Arquitectura/gestion/producto | 220 - 380 | 19.8M - 76.0M |
| **TOTAL** | **6,100 - 9,500** | **485.6M - 1,651.7M** |

Equivalencia USD orientativa (TRM 3,692.48): **USD 131.5k - 447.3k**.

---

## 6) OPEX mensual recomendado en contexto colombiano

### 6.1 Infraestructura y servicios (COP/mes)

| Rubro | Rango COP/mes |
|---|---:|
| Hosting/API/DB/Redis/R2 | 900k - 5.5M |
| Mapas, trafico, geocoding y APIs externas | 400k - 4.5M |
| Email/push/observabilidad/backups | 250k - 2.0M |
| **Subtotal tecnico** | **1.55M - 12.0M** |

### 6.2 Talento minimo operativo (COP/mes)

Escenario contratacion por servicios:

- **18.0M - 38.0M**

Escenario nomina formal (cargas y prestaciones):

- **27.0M - 58.0M**

### 6.3 OPEX total sugerido

- **Modo servicios:** 19.55M - 50.0M COP/mes  
- **Modo nomina:** 28.55M - 70.0M COP/mes  

---

## 7) Valorizacion empresarial para futuros accionistas

### 7.1 Metodo

Se usa enfoque mixto:

1. costo de reemplazo (CAPEX),
2. ajuste por riesgo tecnico/regulatorio,
3. multiplicador por time-to-market.

### 7.2 Rango de valorizacion en COP

**A) Valor del activo software (IP + codigo + documentacion):**

- CAPEX ajustado por riesgo (factor 0.78x - 0.92x): **COP 380M - 1,520M**

**B) Valor empresa temprana (sin traccion auditada):**

- Rango negociable razonable: **COP 700M - 2,200M**

**C) Escenario con traccion auditada (KPI comerciales validados):**

- Puede escalar a: **COP 2,200M - 5,000M+**

> Sin evidencia auditada de ingresos recurrentes, CAC/LTV, retencion y margen unitario, defender la banda alta ante inversion profesional es dificil.

---

## 8) Contexto societario colombiano (SAS) para VIAX TECHNOLOGY S.A.S.

### 8.1 Punto de partida observado en el repo

- Se evidencia el nombre societario **VIAX TECHNOLOGY S.A.S.** y el NIT **902040253-1** en artefactos funcionales (emails/pdf/backend).
- No se encontraron en el repositorio: certificado de existencia y representacion legal, estatutos firmados, ni libros societarios registrados.

### 8.2 Requisitos clave para due diligence de accionistas (Camara de Comercio + ley societaria)

Para ronda de inversion, preparar carpeta legal minima:

1. Certificado de existencia y representacion legal reciente (ideal <= 30 dias).
2. Estatutos vigentes y todas sus reformas inscritas.
3. Libro de accionistas y libro de actas inscritos y actualizados.
4. Cap table formal: capital autorizado, suscrito y pagado, y trazabilidad de emisiones/cesiones.
5. Acuerdo de accionistas (drag/tag, preferencia, vesting, gobierno, lock-up).
6. Renovacion mercantil al dia (plazo legal anual dentro de los tres primeros meses del ano).
7. RUT y obligaciones tributarias al dia.
8. Reporte de beneficiarios finales (RUB) cuando aplique.
9. Cadena de titularidad de propiedad intelectual (cesiones a favor de la sociedad).

### 8.3 Revisor fiscal y umbrales societarios

Regla practica para SAS:

- La SAS no tiene revisor fiscal por defecto; aplica cuando la ley lo exige.
- Referencia de umbrales tradicionales (Ley 43/1990, art. 13): activos >= 5,000 SMMLV o ingresos >= 3,000 SMMLV.
- Con **SMMLV transitorio 2026 = 1,750,905 COP**, los umbrales aproximados son:
  - Activos: **8,754,525,000 COP**
  - Ingresos: **5,252,715,000 COP**

> Nota: el salario minimo 2026 tuvo ajuste judicial transitorio, por lo que este punto debe validarse al cierre legal de cada operacion.

### 8.4 Riesgo regulatorio para movilidad y plataforma

Para narrativa inversionista, sostener con claridad el modelo:

- VIAX como plataforma tecnologica de intermediacion.
- Contratos y trazabilidad con empresas transportadoras habilitadas donde aplique.
- Terminos, tratamiento de datos y practicas de consumidor alineados con normativa colombiana vigente.

---

## 9) Plan de incremento de valor (90 dias)

1. Cerrar brecha legal societaria para inversion (certificados, libros, estatutos, cap table).
2. Formalizar cadena de propiedad intelectual (laboral y contratistas) a favor de VIAX TECHNOLOGY S.A.S.
3. Subir madurez tecnica de riesgo:
   - cobertura de tests en auth/trips/payment/pricing;
   - CI automatizado para app/backend/web;
   - hardening de seguridad (secrets, CORS, monitoreo).
4. Instrumentar KPIs para valuation serio:
   - viajes, ingresos, take-rate, cancelacion, retencion, margen.

---

## 10) Conclusiones para negociacion con potenciales accionistas

- El activo tecnologico de Viax ya supera etapa MVP y tiene peso real de ejecucion.
- El rango tecnico-financiero defendible hoy, sin traccion auditada, es:
  - **Activo software:** 380M - 1,520M COP
  - **Empresa temprana:** 700M - 2,200M COP
- Para aspirar a banda alta, el mayor desbloqueador no es solo codigo: es **evidencia comercial + carpeta legal societaria impecable**.

---

## Anexo A) Entregables de esta actualizacion

- Informe actualizado: `docs/ESTIMACION_COSTOS_Y_VALORACION_EMPRESARIAL_VIAX.md`
- Inventario archivo por archivo actualizado: `docs/ANEXO_INVENTARIO_ARCHIVOS.csv`

---

## Anexo B) Fuentes normativas y economicas consultadas

- Ley 1258 de 2008 (SAS): https://www.secretariasenado.gov.co/senado/basedoc/ley_1258_2008.html
- Ley 1581 de 2012 (datos personales): https://www.secretariasenado.gov.co/senado/basedoc/ley_1581_2012.html
- Ley 1480 de 2011 (estatuto del consumidor): https://www.secretariasenado.gov.co/senado/basedoc/ley_1480_2011.html
- Ley 527 de 1999 (mensajes de datos/firma): https://www.secretariasenado.gov.co/senado/basedoc/ley_0527_1999.html
- Decreto 1074 de 2015 (DUR comercio/industria/turismo): https://www.suin-juriscol.gov.co/clp/contenidos.dll/Decretos/30019935
- Decreto 0159 de 2026 (salario minimo transitorio): https://normograma.mintic.gov.co/mintic/compilacion/docs/decreto_0159_2026.htm
- CCB certificados empresariales: https://www.ccb.org.co/es/tramites-y-consultas/certificados-ccb
- CCB inscripcion de libros: https://linea.ccb.org.co/inscripcionlibros/Index.aspx
- Renovacion mercantil (VUE): https://www.vue.gov.co/tramites-y-consultas/renovacion-de-matricula-mercantil
- Codigo de Comercio, art. 33 (renovacion anual): https://www.cancilleria.gov.co/sites/default/files/Normograma/docs/pdf/codigo_comercio_pr001.pdf
- SFC TRM (metodologia y fuente oficial): https://www.superfinanciera.gov.co/publicaciones/60819/informes-y-cifrascifrasestablecimientos-de-creditoinformacion-periodicadiariatasa-de-cambio-representativa-del-mercado-trm-60819/
- Referencia TRM reciente (historico): https://www.anif.com.co/indicador/TRM/
- DIAN Resolucion 000164 de 2021 (RUB): https://www.dian.gov.co/Documents/Intercambio_de_Informacion_Internacional/Resolucion-000164-de-2021.pdf
- Cartilla SAS (Supersociedades): https://www.supersociedades.gov.co/documents/20122/385464/Cartilla-Sociedad-Acciones-Simplificada.pdf

---

## Nota de responsabilidad

Este informe es tecnico-financiero y de pre-due-diligence. No reemplaza concepto legal, tributario, laboral ni de banca de inversion. Para apertura de ronda se recomienda validacion formal con abogado societario y revisor/contador de confianza.
