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
    final fp = model.firstPunch.trim();
    if (fp.isNotEmpty && fp.toLowerCase() != 'null') {
      try {
        final parsed = DateTime.parse(fp);
        if (parsed.year == now.year && parsed.month == now.month && parsed.day == now.day) {
          workStartTime = parsed;
        }
      } catch (_) {
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

  bool isOfficeHourFinished(EmployeeModel? model) {
    if (model == null) return false;

    final now = DateTime.now();

    // 1. If firstPunch is available
    final fp = model.firstPunch.trim();

    if (fp.isNotEmpty && fp.toLowerCase() != 'null') {
      DateTime? firstPunchTime;

      try {
        firstPunchTime = DateTime.parse(fp);
      } catch (_) {
        firstPunchTime = _parseTimeOnDate(fp, now);
      }

      if (firstPunchTime != null) {
        final duration = now.difference(firstPunchTime).inMinutes / 60.0;

        // Must be greater than 8 hours
        return duration > 8.0;
      }
    }

    // 2. If firstPunch is null, use startTime
    final st = model.startTime.trim();

    if (st.isEmpty || st.toLowerCase() == 'null') {
      return false;
    }

    final rawTime = st.split('-').first.trim();
    final workStartTime = _parseTimeOnDate(rawTime, now);
    if (workStartTime == null) {
      return false;
    }

    // Current time is before startTime
    if (now.isBefore(workStartTime)) {
      return true;
    }

    // Calculate duration from startTime to current time
    final duration = now.difference(workStartTime).inMinutes / 60.0;

    // Must be greater than 8 hours
    return duration > 8.0;
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