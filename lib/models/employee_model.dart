class EmployeeModel {
  final String userId;
  final String name;
  final String designation;
  final String department;
  final String joiningDate;
  final String startTime;
  final String endTime;
  final String? token;

  const EmployeeModel({
    required this.userId,
    required this.name,
    required this.designation,
    required this.department,
    required this.joiningDate,
    required this.startTime,
    required this.endTime,
    this.token,
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
    };
  }

  /// Creates a demo employee profile for initial test/preview
  factory EmployeeModel.demo({required String userId}) {
    return EmployeeModel(
      userId: userId.isNotEmpty ? userId : 'EMP-2024-892',
      name: 'Alexander Wright',
      designation: 'Senior Software Engineer',
      department: 'Information Technology',
      joiningDate: '15 Jan 2022',
      startTime: '8:10 AM - 4:00 PM',
      endTime: '8:10 AM - 4:00 PM',
      token: 'demo_jwt_access_token_xyz_123456789',
    );
  }
}
