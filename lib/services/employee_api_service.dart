
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:my_demo_project/app_global.dart';
import '../models/employee_model.dart';

class EmployeeApiService {
  static const String baseUrl = AppGlobals.baseUrl;
  static const String employeeInfoEndpoint = '/api/ess/portal/employee-duty-monitoring/enroll-user';

  /// Fetch employee basic info from Spring Boot API
  static Future<EmployeeModel>  fetchEmployeeInfo({
    required String employeeId,
    required String date,
    required String accessToken,
  }) async {
    try {
      final Uri uri = Uri.parse(
          '$baseUrl$employeeInfoEndpoint'
              '?employeeId=$employeeId'
              '&date=$date&publicRsa=testrsa'
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        final Map<String, dynamic> employeeData = responseBody['data'];
        employeeData['token'] = accessToken;
        return EmployeeModel.fromJson(employeeData);
      } else {
        throw Exception('Failed to fetch employee info: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Employee API Error: $e');
    }
  }
}