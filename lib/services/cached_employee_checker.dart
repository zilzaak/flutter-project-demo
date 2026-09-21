// lib/services/cached_employee_checker.dart

import 'package:flutter/foundation.dart';
import 'package:my_demo_project/services/auth_service.dart';
import '../global_config.dart';
import '../models/employee_model.dart';
import '../services/employee_api_service.dart';
import '../services/token_cache_service.dart';

class CachedEmployeeChecker {

  Future<EmployeeModel?> checkCachedEmployee() async {
    try {
      final String? accessToken = await tokenCacheService.getToken();
      if (accessToken == null || accessToken.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[CachedEmployeeChecker] No cached JWT found.',
          );
        }
        return null;
      }

      if (kDebugMode) {
        debugPrint(
          '[CachedEmployeeChecker] Cached JWT found. '
              'Skipping login.',
        );
      }

      final Map<String, dynamic> claims = authService.decodeJwtPayload(accessToken);
      final String employeeId = claims['preferred_username']?.toString() ?? '';
      if (employeeId.isEmpty) {
        throw Exception(
          'Employee ID was not found in cached JWT.',
        );
      }

      if (kDebugMode) {
        debugPrint(
          '[CachedEmployeeChecker] Employee ID: $employeeId',
        );
      }

      final EmployeeModel employee = await employeeApiService.fetchEmployeeInfo(
        employeeId: employeeId,date: DateTime.now().toIso8601String().split('T').first,
        accessToken: accessToken,);

      final EmployeeModel employeeWithToken = EmployeeModel(
        userId: employee.userId,
        name: employee.name,
        designation: employee.designation,
        department: employee.department,
        joiningDate: employee.joiningDate,
        startTime: employee.startTime,
        endTime: employee.endTime,
        firstPunch: employee.firstPunch,
        token: accessToken,
      );

      globals.setAuthData(accessToken,employeeWithToken,);
      if (kDebugMode) {
        debugPrint('==============================================');
        debugPrint('CACHED JWT SESSION RESTORED');
        debugPrint(
          'Employee : ${employeeWithToken.name} '
              '(${employeeWithToken.userId})',
        );
        debugPrint('No login was required.');
        debugPrint('==============================================');
      }
      return employeeWithToken;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[CachedEmployeeChecker] Failed: $e',
        );
      }
      return null;
    }
  }
}

final cachedEmployeeChecker = CachedEmployeeChecker();