import 'package:intl/intl.dart';
import 'package:my_demo_project/models/employee_model.dart';

class CommonUtil {
  /// Checks whether 8 hours have elapsed from the start of duty.
  /// Priority:
  /// 1. firstPunch (preferred if available and belongs to today, or time-only format)
  /// 2. startTime (fallback if firstPunch is null/empty/from another date)
  /// Smooth continuous duty: exactly 8 hours duration.
/*  bool isOfficeHourFinished(EmployeeModel? model) {
    if (model == null) return false;

    final now = DateTime.now();
    DateTime? workStartTime;

    // 1. Prefer firstPunch (full LocalDateTime or time string from backend)
    final fp = model.firstPunch.trim();
    if (fp.isNotEmpty && fp.toLowerCase() != 'null') {
      try {
        final parsed = DateTime.parse(fp);
        // Only consider valid if firstPunch belongs to today!
        // If it is from a previous day, disregard it so tracking doesn't prematurely stop.
        if (parsed.year == now.year && parsed.month == now.month && parsed.day == now.day) {
          workStartTime = parsed;
        }
      } catch (_) {
        // Fallback for time-only string e.g. "08:15:00", "08:15", "8:15 AM"
        workStartTime = _parseTimeOnDate(fp, now);
      }
    }

    // 2. Fallback: combine today's date with startTime (e.g. "08:10:00", "08:10", "8:10 AM - 4:00 PM")
    if (workStartTime == null) {
      final st = model.startTime.trim();
      if (st.isNotEmpty && st.toLowerCase() != 'null') {
        final rawTime = st.split('-').first.trim();
        workStartTime = _parseTimeOnDate(rawTime, now);
      }
    }

    // Fail-safe: if duty start time cannot be determined, treat as NOT finished so tracking continues
    if (workStartTime == null) {
      return false;
    }

    // If duty start time is in the future today, office hours are definitely not finished yet
    if (now.isBefore(workStartTime)) {
      return false;
    }

    final hours = now.difference(workStartTime).inMinutes / 60.0;
    return hours >= 8.0;
  }*/

  /// Returns true  → SKIP the backend API call this tick.
  /// Returns false → PROCEED with the tracking cycle.
  ///
  /// Rule:
  ///   • firstPunch present today:
  ///       - skip when (now − firstPunch) > 8h
  ///       - proceed when (now − firstPunch) <= 8h
  ///   • firstPunch empty / null (or from a previous day):
  ///       - skip until now >= startTime
  ///       - proceed from startTime onwards
  bool isOfficeHourFinished(EmployeeModel? model) {
    if (model == null) return true;

    final now = DateTime.now();
    final fp  = model.firstPunch.trim();

    // ── Branch 1: firstPunch exists ────────────────────────────────
    if (fp.isNotEmpty && fp.toLowerCase() != 'null') {
      final DateTime? firstPunch = DateTime.tryParse(fp);

      if (firstPunch != null) {
        final sameDay = firstPunch.year  == now.year && firstPunch.month == now.month && firstPunch.day   == now.day;
        if (sameDay) {
          if (now.isBefore(firstPunch)) return true;   // future punch → skip
          final hours = now.difference(firstPunch).inMinutes / 60.0;
          return hours > 8.0;                          // ← strictly greater
        }else{
          return true;
        }
        // punch is yesterday → treat as no-punch today (fall through)
      }
      // malformed punch → fall through
    }
    // ── Branch 2: no punch today — compare against startTime ───────
    final DateTime? scheduled = _parseLocalTime(model.startTime, now);
    if (scheduled == null) return false;   // unknown → proceed
    return now.isBefore(scheduled);        // skip until startTime
  }

  DateTime? _parseLocalTime(String raw, DateTime date) {
    final s = raw.trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;

    final token = s.split(RegExp(r'\s*-\s*')).first.trim();
    final parts = token.split(':');
    if (parts.length < 2) return null;

    final h  = int.tryParse(parts[0]);
    final m  = int.tryParse(parts[1]);
    final ss = parts.length >= 3 ? int.tryParse(parts[2].split('.').first) : 0;

    if (h == null || m == null) return null;
    return DateTime(date.year, date.month, date.day, h, m, ss ?? 0);
  }

  /// Parses a time string (e.g. "8:10 AM", "08:10:00", "08:10") on a given date
  DateTime? _parseTimeOnDate(String timeStr, DateTime date) {
    try {
      final clean = timeStr.trim();
      DateTime parsed;
      if (clean.toUpperCase().contains('AM') || clean.toUpperCase().contains('PM')) {
        parsed = DateFormat('h:mm a').parse(clean.toUpperCase());
      } else if (clean.split(':').length >= 3) {
        parsed = DateFormat('HH:mm:ss').parse(clean);
      } else {
        parsed = DateFormat('HH:mm').parse(clean);
      }
      return DateTime(date.year, date.month, date.day, parsed.hour, parsed.minute, parsed.second);
    } catch (_) {
      return null;
    }
  }
}

final commonUtil = CommonUtil();