# Metricas Operativas - Dispatch Service

**Fecha:** 2026-05-02  
**Tipo:** Observabilidad pasiva - contadores en Redis, sin nuevo servicio

---

## Que son

Contadores atomicos en Redis que el `dispatch-service` incrementa
automaticamente cada vez que procesa un evento. Permiten saber cuanto
trafico maneja el servicio sin tener que leer logs linea por linea.

No son un microservicio nuevo. Son unas lineas en `worker.js` que
llaman a `INCR` en Redis.

---

## Como consultarlas

**Desde local (forma recomendada):**

```bash
bash scripts/check_dispatch_metrics.sh
bash scripts/check_dispatch_metrics.sh 2026-05-01
```

**Desde el servidor directamente:**

```bash
TODAY=$(date +%Y-%m-%d)
redis-cli GET dispatch:metrics:offers:$TODAY
redis-cli GET dispatch:metrics:no_driver:$TODAY
redis-cli GET dispatch:metrics:total:$TODAY
```

**Ver todas las claves activas:**

```bash
redis-cli --scan --pattern "dispatch:metrics:*" | sort
```

---

## Que significa cada metrica

| Metrica | Clave Redis | Significado |
|---|---|---|
| `offers` | `dispatch:metrics:offers:YYYY-MM-DD` | El dispatch encontro conductor disponible y emitio oferta. |
| `no_driver` | `dispatch:metrics:no_driver:YYYY-MM-DD` | El evento fue valido y procesado, pero no habia conductor elegible en ese momento. |
| `duplicates` | `dispatch:metrics:duplicates:YYYY-MM-DD` | Eventos ignorados por el lock anti-duplicacion. Si este valor sube mucho, algo esta republicando viajes. |
| `legacy` | `dispatch:metrics:legacy:YYYY-MM-DD` | Mensajes del `dispatch_worker.php` legacy que siguen llegando en modo hybrid. |
| `invalid` | `dispatch:metrics:invalid:YYYY-MM-DD` | Mensajes no parseables que llegaron al canal. En produccion normal debe ser 0 o muy bajo. |
| `total` | `dispatch:metrics:total:YYYY-MM-DD` | Suma de `offers` + `no_driver`. Es la metrica principal de volumen procesado. |

---

## TTL y retencion

Cada clave tiene TTL de 30 dias. Despues de ese periodo Redis la elimina
automaticamente sin necesidad de limpieza manual.

---

## Senales de alerta

| Situacion | Que revisar |
|---|---|
| `invalid` sube de 0 | Hay un publicador nuevo enviando JSON malformado al canal |
| `duplicates` es alto vs `total` | Algo esta republicando viajes con demasiada frecuencia |
| `total` = 0 en horario activo | El dispatch-service puede no estar recibiendo eventos; revisar subscriber |
| `offers` = 0 pero `total` alto | No hay conductores elegibles o el matching necesita revision |

---

## Archivos relacionados

- Implementacion: `services/dispatch/src/worker.js` - funcion `incrementMetric()`
- Script de consulta: `scripts/check_dispatch_metrics.sh`
- Arquitectura general: `docs/architecture/dispatch-service-architecture.md`