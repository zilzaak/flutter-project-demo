import 'package:intl/intl.dart';

class EmployeeModel {
  final String userId;
  final String name;
  final String designation;
  final String department;
  final String joiningDate;
  final String startTime;
  final String endTime;
  final String? token;
  final String firstPunch;
  final String? weekend;
  final String? holiday;

  const EmployeeModel({
    required this.userId,
    required this.name,
    required this.designation,
    required this.department,
    required this.joiningDate,
    required this.startTime,
    required this.endTime,
    this.token,
    required this.firstPunch,
     this.weekend,
     this.holiday,
  });

  /// Factory method to create an EmployeeModel from API JSON response
  factory EmployeeModel.fromJson(Map<String, dynamic> json, {String? token}) {
    return EmployeeModel(
      userId: json['employeeId'] ?? '',
      name: json['fullName'] ?? '',
      designation: json['designation'] ?? '',
      department: json['department'] ?? '',
      joiningDate: json['joiningDate'] ?? '',
      startTime: json['startTime'] ?? '8:10 AM - 4:00 PM',
      endTime: json['endTime'] ?? '8:10 AM - 4:00 PM',
      token: token ?? json['token'] ?? json['access_token'],
      firstPunch: json['firstPunch']?.toString() ?? '',
      weekend: json['weekend']?.toString() ?? '',
      holiday: json['holiday']?.toString() ?? '',
    );
  }

  /// Converts EmployeeModel to Map/JSON for API transmission or storage
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'designation': designation,
      'department': department,
      'joiningDate': joiningDate,
      'startTime': startTime,
      'endTime': endTime,
      'token': token,
      'firstPunch': firstPunch,
      'weekend': weekend,
      'holiday': holiday,
    };
  }


  DateTime? getWorkStartDateTime(String firstPunch, String startTime) {
    final now = DateTime.now();
    final fp = firstPunch;
    if (fp.isNotEmpty) {
      try {
        return DateTime.parse(fp);
      } catch (_) {
      }
    }
    // 2. Fallback: combine today's date with startTime ("08:10:00")
    final st = startTime;
    if (st.isNotEmpty) {
      try {
        final t = DateFormat('HH:mm:ss').parse(st); // "08:10:00"
        return DateTime(now.year, now.month, now.day, t.hour, t.minute, t.second);
      } catch (_) {
      }
    }
    return null;
  }

  bool isOfficeHourFinished(DateTime startTime) {
    final hours = DateTime.now().difference(startTime).inMinutes/ 60.0;
    if (hours <= 8) {
      return false;
    } else {
      return true;
    }
  }

}
