import 'package:flutter/foundation.dart';

/// Centralized Date & Time formatting utility for QuickBoom App.
/// Ensures identical parsing and formatting across Home Screen,
/// Attendance Logs Screen, Punch In Views, and Admin Dashboards.
class AppDateFormatter {
  /// Format a timestamp (ISO 8601 string, DateTime, or time string) to 'hh:mm a' (e.g. '07:14 PM')
  /// using device local timezone (Asia/Kolkata).
  static String formatAttendanceTime(
    dynamic timestamp, {
    String fallback = '--:--',
  }) {
    if (timestamp == null) return fallback;

    if (timestamp is DateTime) {
      final local = timestamp.isUtc ? timestamp.toLocal() : timestamp;
      return _formatHourMinute(local);
    }

    final rawStr = timestamp.toString().trim();
    if (rawStr.isEmpty ||
        rawStr == 'null' ||
        rawStr == '—' ||
        rawStr == '--:--' ||
        rawStr == '-') {
      return fallback;
    }

    // Check if it's already a formatted time like "07:14 PM" or "7:14 AM"
    final regexFormatted = RegExp(
      r'^(0?[1-9]|1[0-2]):([0-5][0-9])\s*(AM|PM)$',
      caseSensitive: false,
    );
    if (regexFormatted.hasMatch(rawStr)) {
      final match = regexFormatted.firstMatch(rawStr)!;
      final hour = int.parse(match.group(1)!);
      final minute = match.group(2)!;
      final ampm = match.group(3)!.toUpperCase();
      return '${hour.toString().padLeft(2, '0')}:$minute $ampm';
    }

    // Check if it's a 24-hour time like "19:14" or "19:14:00"
    final regex24h = RegExp(
      r'^([01]?[0-9]|2[0-3]):([0-5][0-9])(?::([0-5][0-9]))?$',
    );
    if (regex24h.hasMatch(rawStr)) {
      final match = regex24h.firstMatch(rawStr)!;
      final hour24 = int.parse(match.group(1)!);
      final minute = match.group(2)!;
      final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
      final ampm = hour24 >= 12 ? 'PM' : 'AM';
      return '${hour12.toString().padLeft(2, '0')}:$minute $ampm';
    }

    try {
      final parsedUtcOrLocal = DateTime.parse(rawStr);
      final local = parsedUtcOrLocal.isUtc
          ? parsedUtcOrLocal.toLocal()
          : parsedUtcOrLocal;
      final result = _formatHourMinute(local);

      if (kDebugMode) {
        debugPrint(
          '[ATTENDANCE TIME] API: $rawStr -> Local: $local -> Formatted: $result',
        );
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ATTENDANCE TIME ERROR] Could not parse "$rawStr": $e');
      }
      return rawStr;
    }
  }

  /// Formats a date to 'dd MMM yyyy' (e.g. '01 Sep 2026') or 'dd MMM'
  static String formatAttendanceDate(
    dynamic dateValue, {
    String fallback = '—',
    bool includeYear = true,
  }) {
    if (dateValue == null) return fallback;

    DateTime? date;
    if (dateValue is DateTime) {
      date = dateValue.isUtc ? dateValue.toLocal() : dateValue;
    } else {
      final str = dateValue.toString().trim();
      if (str.isEmpty || str == 'null' || str == '—') return fallback;
      try {
        date = DateTime.parse(str).toLocal();
      } catch (_) {
        return str;
      }
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dayStr = date.day.toString().padLeft(2, '0');
    final monthStr = months[date.month - 1];

    return includeYear ? '$dayStr $monthStr ${date.year}' : '$dayStr $monthStr';
  }

  /// Parses any timestamp to a local DateTime object safely.
  static DateTime? parseToLocal(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is DateTime) {
      return timestamp.isUtc ? timestamp.toLocal() : timestamp;
    }
    try {
      final parsed = DateTime.parse(timestamp.toString().trim());
      return parsed.isUtc ? parsed.toLocal() : parsed;
    } catch (_) {
      return null;
    }
  }

  /// Format duration minutes (or hours string) as 'Xh Ym' (e.g. 0 -> '0h 0m', 1 -> '0h 1m', 30 -> '0h 30m', 60 -> '1h 0m', 90 -> '1h 30m', 125 -> '2h 5m').
  static String formatDurationHoursMinutes(
    dynamic minutesOrHours, {
    String fallback = '0h 0m',
  }) {
    if (minutesOrHours == null) return fallback;

    if (minutesOrHours is num) {
      final totalMins = minutesOrHours.round();
      final hours = totalMins ~/ 60;
      final mins = totalMins % 60;
      return '${hours}h ${mins}m';
    }

    final rawStr = minutesOrHours.toString().trim();
    if (rawStr.isEmpty || rawStr == 'null' || rawStr == '—' || rawStr == '-') {
      return fallback;
    }

    // Already in "Xh Ym" format
    final regexHmM = RegExp(r'^(\d+)h\s*(\d+)m$', caseSensitive: false);
    if (regexHmM.hasMatch(rawStr)) {
      return rawStr;
    }

    // "90 min" or "90m"
    final regexMin = RegExp(
      r'^(\d+(?:\.\d+)?)\s*(?:min|m)?$',
      caseSensitive: false,
    );
    if (regexMin.hasMatch(rawStr)) {
      final val = double.tryParse(regexMin.firstMatch(rawStr)!.group(1)!) ?? 0;
      final totalMins = val.round();
      final hours = totalMins ~/ 60;
      final mins = totalMins % 60;
      return '${hours}h ${mins}m';
    }

    final parsed = double.tryParse(rawStr);
    if (parsed != null) {
      final totalMins = parsed.round();
      final hours = totalMins ~/ 60;
      final mins = totalMins % 60;
      return '${hours}h ${mins}m';
    }

    return rawStr;
  }

  static String _formatHourMinute(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    return '${hour12.toString().padLeft(2, '0')}:$minute $ampm';
  }
}
