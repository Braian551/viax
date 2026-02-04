/// Utilidades centralizadas para manejo de fechas y zonas horarias
/// 
/// Este módulo garantiza que todas las fechas del servidor (en UTC) 
/// se conviertan correctamente a la zona horaria local del dispositivo.
library;

import 'package:intl/intl.dart';

/// Clase de utilidades para manejo consistente de fechas
/// 
/// El servidor envía todas las fechas en UTC, esta clase se encarga de:
/// - Parsear fechas del servidor interpretándolas como UTC
/// - Convertir a la hora local del dispositivo
/// - Formatear para visualización con el locale correcto
class DateTimeUtils {
  // Locale por defecto para formato en español Colombia
  static const String defaultLocale = 'es_CO';
  
  // Formateadores pre-configurados (cached para performance)
  static final DateFormat _fullDateTimeFormat = DateFormat('EEEE d \'de\' MMMM yyyy, HH:mm', defaultLocale);
  static final DateFormat _shortDateTimeFormat = DateFormat('dd MMM yyyy, HH:mm', defaultLocale);
  static final DateFormat _dateOnlyFormat = DateFormat('dd MMM yyyy', defaultLocale);
  static final DateFormat _timeOnlyFormat = DateFormat('HH:mm', defaultLocale);
  static final DateFormat _dayMonthFormat = DateFormat('d \'de\' MMMM', defaultLocale);
  static final DateFormat _fullDayFormat = DateFormat('EEEE d \'de\' MMMM yyyy', defaultLocale);
  static final DateFormat _shortDayFormat = DateFormat('EEE d MMM, HH:mm', defaultLocale);
  static final DateFormat _iso8601Format = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
  
  /// Parsea una fecha del servidor (UTC) y la convierte a hora local
  /// 
  /// El servidor envía fechas en formato ISO8601 o 'yyyy-MM-dd HH:mm:ss'
  /// Esta función las interpreta como UTC y las convierte a hora local.
  /// 
  /// Ejemplo:
  /// ```dart
  /// final local = DateTimeUtils.parseServerDate('2026-02-03 18:30:00');
  /// // Si estás en Colombia (UTC-5), retorna 2026-02-03 13:30:00
  /// ```
  static DateTime? parseServerDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    
    try {
      DateTime parsed;
      
      // Verificar si ya tiene indicador de timezone
      if (dateString.endsWith('Z')) {
        // Ya es UTC explícito
        parsed = DateTime.parse(dateString);
      } else if (dateString.contains('+') || 
                 (dateString.contains('-') && dateString.lastIndexOf('-') > 10)) {
        // Tiene offset de timezone (ej: +00:00 o -05:00)
        parsed = DateTime.parse(dateString);
      } else {
        // Sin timezone - asumimos UTC (hora del servidor)
        // Limpiamos y parseamos
        String cleanDate = dateString.trim();
        
        // Convertir formato 'yyyy-MM-dd HH:mm:ss' a ISO8601
        if (cleanDate.contains(' ') && !cleanDate.contains('T')) {
          cleanDate = cleanDate.replaceFirst(' ', 'T');
        }
        
        // Asegurar que termine en Z para interpretar como UTC
        if (!cleanDate.endsWith('Z')) {
          cleanDate = '${cleanDate}Z';
        }
        
        parsed = DateTime.parse(cleanDate);
      }
      
      // Convertir a hora local del dispositivo
      return parsed.toLocal();
    } catch (e) {
      // Log para debugging, en producción usar logging apropiado
      assert(() {
        // ignore: avoid_print
        print('DateTimeUtils: Error parseando fecha "$dateString": $e');
        return true;
      }());
      return null;
    }
  }
  
  /// Parsea y convierte una fecha, retornando DateTime.now() si falla
  static DateTime parseServerDateOrNow(String? dateString) {
    return parseServerDate(dateString) ?? DateTime.now();
  }
  
  /// Formatea fecha completa con día de la semana
  /// Ejemplo: "Lunes 3 de febrero 2026, 13:30"
  static String formatFullDateTime(DateTime? date, {bool includeTime = true}) {
    if (date == null) return '';
    
    if (includeTime) {
      return _fullDateTimeFormat.format(date);
    } else {
      return _fullDayFormat.format(date);
    }
  }
  
  /// Formatea fecha corta
  /// Ejemplo: "03 Feb 2026, 13:30"
  static String formatShortDateTime(DateTime? date) {
    if (date == null) return '';
    return _shortDateTimeFormat.format(date);
  }
  
  /// Formatea solo la fecha sin hora
  /// Ejemplo: "03 Feb 2026"
  static String formatDateOnly(DateTime? date) {
    if (date == null) return '';
    return _dateOnlyFormat.format(date);
  }
  
  /// Formatea solo la hora
  /// Ejemplo: "13:30"
  static String formatTimeOnly(DateTime? date) {
    if (date == null) return '';
    return _timeOnlyFormat.format(date);
  }
  
  /// Formatea día y mes
  /// Ejemplo: "3 de febrero"
  static String formatDayMonth(DateTime? date) {
    if (date == null) return '';
    return _dayMonthFormat.format(date);
  }
  
  /// Formatea día corto con hora
  /// Ejemplo: "Lun 3 Feb, 13:30"
  static String formatShortDayWithTime(DateTime? date) {
    if (date == null) return '';
    return _shortDayFormat.format(date);
  }
  
  /// Formatea fecha relativa ("Hace 5 minutos", "Ayer", etc.)
  static String formatRelative(DateTime? date) {
    if (date == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inSeconds < 60) {
      return 'Hace un momento';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return 'Hace $mins ${mins == 1 ? 'minuto' : 'minutos'}';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return 'Hace $hours ${hours == 1 ? 'hora' : 'horas'}';
    } else if (difference.inDays == 1) {
      return 'Ayer, ${_timeOnlyFormat.format(date)}';
    } else if (difference.inDays < 7) {
      return _shortDayFormat.format(date);
    } else {
      return _shortDateTimeFormat.format(date);
    }
  }
  
  /// Formatea fecha para mostrar en cards de historial
  /// Muestra formato relativo si es reciente, o fecha completa si no
  static String formatForHistoryCard(DateTime? date) {
    if (date == null) return '';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    
    if (dateDay == today) {
      return 'Hoy, ${_timeOnlyFormat.format(date)}';
    } else if (dateDay == today.subtract(const Duration(days: 1))) {
      return 'Ayer, ${_timeOnlyFormat.format(date)}';
    } else if (now.difference(date).inDays < 7) {
      // Dentro de la última semana
      return _shortDayFormat.format(date);
    } else {
      return _shortDateTimeFormat.format(date);
    }
  }
  
  /// Formatea fecha con estado "Completado el Lun 3 de febrero 2026, 13:30"
  static String formatCompletedDate(DateTime? date) {
    if (date == null) return '';
    return 'Completado el ${_shortDayFormat.format(date)}';
  }
  
  /// Convierte DateTime local a UTC ISO8601 para enviar al servidor
  static String toServerFormat(DateTime localDate) {
    return localDate.toUtc().toIso8601String();
  }
  
  /// Convierte DateTime a formato solo fecha para APIs
  static String toServerDateOnly(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
  
  /// Verifica si una fecha es hoy
  static bool isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }
  
  /// Verifica si una fecha es ayer
  static bool isYesterday(DateTime? date) {
    if (date == null) return false;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year && 
           date.month == yesterday.month && 
           date.day == yesterday.day;
  }
  
  /// Obtiene el inicio del día en hora local
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
  
  /// Obtiene el fin del día en hora local
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }
  
  /// Formatea duración en formato legible
  static String formatDuration(int? minutes) {
    if (minutes == null || minutes <= 0) return '';
    
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins == 0) {
        return '$hours ${hours == 1 ? 'hora' : 'horas'}';
      }
      return '$hours h $mins min';
    }
  }
}

/// Extensión para DateTime que facilita el formateo
extension DateTimeFormatExtension on DateTime {
  /// Formatea la fecha usando DateTimeUtils
  String get fullFormat => DateTimeUtils.formatFullDateTime(this);
  String get shortFormat => DateTimeUtils.formatShortDateTime(this);
  String get dateOnly => DateTimeUtils.formatDateOnly(this);
  String get timeOnly => DateTimeUtils.formatTimeOnly(this);
  String get relative => DateTimeUtils.formatRelative(this);
  String get forHistory => DateTimeUtils.formatForHistoryCard(this);
  String get serverFormat => DateTimeUtils.toServerFormat(this);
}

/// Extensión para String que facilita el parseo de fechas del servidor
extension StringDateExtension on String {
  /// Parsea string de fecha del servidor a DateTime local
  DateTime? get toLocalDate => DateTimeUtils.parseServerDate(this);
  
  /// Parsea o retorna DateTime.now() si falla
  DateTime get toLocalDateOrNow => DateTimeUtils.parseServerDateOrNow(this);
}
