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

  Future<bool> isOfficeHourFinished(EmployeeModel? model) async {
    print('========== isOfficeHourFinished START ==========');

    if (model == null) {
      print('model = NULL');
      print('RESULT = false');
      print('========== isOfficeHourFinished END ==========');
      return true;
    }

    if(model.holiday=='true' || model.weekend=='true'){
      print('========== weekend or holidaye is true');
      return true;
    }

    final now = DateTime.now();

    print('Current DateTime = $now');
    print('Current Date = ${now.toLocal()}');

    // 1. If firstPunch is available
    final fp = model.firstPunch.trim();

    print('firstPunch raw = "${model.firstPunch}"');
    print('firstPunch trimmed = "$fp"');

    if (fp.isNotEmpty && fp.toLowerCase() != 'null') {
      print('firstPunch is NOT null/empty');

      DateTime? firstPunchTime;

      try {
        firstPunchTime = DateTime.parse(fp);
        print('firstPunch parsed using DateTime.parse = $firstPunchTime');
      } catch (e) {
        print('DateTime.parse failed = $e');
        firstPunchTime = _parseTimeOnDate(fp, now);
        print('firstPunch parsed using _parseTimeOnDate = $firstPunchTime');
      }

      if (firstPunchTime != null) {
        final difference = now.difference(firstPunchTime);
        final durationMinutes = difference.inMinutes;
        final durationHours = durationMinutes / 60.0;

        print('--- First Punch Calculation ---');
        print('firstPunchTime = $firstPunchTime');
        print('now = $now');
        print('difference = $difference');
        print('durationMinutes = $durationMinutes');
        print('durationHours = $durationHours');
        print('Required duration = > 8.0 hours');

        final result = durationHours > 8.0;

        print('durationHours > 8.0 = $result');
        print('RESULT = $result');
        print('========== isOfficeHourFinished END ==========');

        return result;
      } else {
        print('firstPunchTime = NULL');
        print('Could not determine first punch time.');
        print('Will fallback to startTime.');
      }
    } else {
      print('firstPunch is NULL or EMPTY');
    }

    // 2. If firstPunch is null, use startTime
    final st = model.startTime.trim();

    print('startTime raw = "${model.startTime}"');
    print('startTime trimmed = "$st"');

    if (st.isEmpty || st.toLowerCase() == 'null') {
      print('startTime is NULL or EMPTY');
      print('RESULT = false');
      print('========== isOfficeHourFinished END ==========');
      return false;
    }

    final rawTime = st.split('-').first.trim();

    print('rawTime extracted from startTime = "$rawTime"');

    final workStartTime = _parseTimeOnDate(rawTime, now);

    print('workStartTime parsed = $workStartTime');

    if (workStartTime == null) {
      print('workStartTime = NULL');
      print('Could not parse startTime.');
      print('RESULT = false');
      print('========== isOfficeHourFinished END ==========');
      return false;
    }

    // Current time is before startTime
    print('Current time = $now');
    print('Work start time = $workStartTime');

    if (now.isBefore(workStartTime)) {
      print('Current time is BEFORE workStartTime');
      print('RESULT = true');
      print('========== isOfficeHourFinished END ==========');
      return true;
    }

    // Calculate duration from startTime to current time
    final difference = now.difference(workStartTime);
    final durationMinutes = difference.inMinutes;
    final durationHours = durationMinutes / 60.0;

    print('--- Start Time Calculation ---');
    print('workStartTime = $workStartTime');
    print('now = $now');
    print('difference = $difference');
    print('durationMinutes = $durationMinutes');
    print('durationHours = $durationHours');
    print('Required duration = > 8.0 hours');

    // Must be greater than 8 hours
    final result = durationHours > 8.0;

    print('durationHours > 8.0 = $result');
    print('RESULT = $result');
    print('========== isOfficeHourFinished END ==========');

    return result;
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