
// Helper script for debugging active trip checks
// Run this or examine the logic to see if fields match.

/*
 * CHECKLIST FOR DEBUGGING:
 * 
 * 1. CONDUCTOR SERVICE: getViajesActivos
 *    - Expected Response structure:
 *      {
 *        "success": true,
 *        "viajes": [
 *          {
 *            "id": 123,
 *            "estado": "en_curso" (or "en_camino", "conductor_llego"...)
 *          }
 *        ]
 *      }
 *    - If 'viajes' is null or empty, check if the backend is actually returning 'active_trips' instead of 'viajes'.
 *    - Check if 'estado' is the correct key. Maybe it's 'status'?
 * 
 * 2. USER SERVICE: getHistorial
 *    - We call `UserTripsService.getHistorial`.
 *    - Response structure:
 *      {
 *        "success": true,
 *        "viajes": [ ... ]
 *      }
 *    - We iterate and check `!t.isCompletado && !t.isCancelado`.
 *    - `isCompletado` check: `estado == 'completada' || estado == 'entregado'`
 *    - `isCancelado` check: `estado == 'cancelada'`
 * 
 *    - POTENTIAL ISSUES:
 *      - Backend returns 'finalizado' instead of 'completada'?
 *      - Backend returns 'terminado'?
 *      - Backend returns 'cancelado' (masculine) instead of 'cancelada'?
 * 
 *    - PROPOSED FIX:
 *      - Print the actual 'estado' values returned by the API.
 *      - Relax the check to include robust variations.
 */

import 'package:flutter/foundation.dart';

void debugActiveTripLogic(List<dynamic> trips) {
  debugPrint('--- DEBUGGING ACTIVE TRIPS ---');
  for (var trip in trips) {
    // Assuming trip is a map
    final estado = trip['estado']?.toString().toLowerCase() ?? 'unknown';
    debugPrint('Trip ID: ${trip['id']}, Estado Raw: "$estado"');
    
    final isCompletado = 
        estado == 'completada' || 
        estado == 'completado' || 
        estado == 'entregado' || 
        estado == 'finalizado' || 
        estado == 'finalizada';
        
    final isCancelado = 
        estado == 'cancelada' || 
        estado == 'cancelado';
        
    final isActive = !isCompletado && !isCancelado;
    
    debugPrint('  -> isCompletado: $isCompletado');
    debugPrint('  -> isCancelado: $isCancelado');
    debugPrint('  -> isActive: $isActive');
  }
}
