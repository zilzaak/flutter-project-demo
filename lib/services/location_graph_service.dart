import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../global_config.dart';
import '../models/location_graph_model.dart';
import 'security_service.dart';

class LocationGraphService {

  static const String endpoint = '/api/geoportal/geo-location/my-location-graph';

  /// Fetch today's logged-in employee location graph from Spring Boot API
  static Future<LocationGraphData> fetchMyLocationGraph({String? token, String? employeeId}) async {
    final authToken = token ?? globals.accessToken;
    final empId = employeeId ?? globals.employeeId ?? globals.currentEmployee?.userId;

    if (authToken == null || authToken.isEmpty) {
      throw Exception('User is not authenticated. Access token is missing.');
    }
    if (empId == null || empId.isEmpty) {
      throw Exception('Employee ID is missing.');
    }

    final String todayDate = DateTime.now().toIso8601String().split('T').first;
    final String canonicalPayload = '$empId|$todayDate';
    final String? signature = await SecurityService().signPayload(canonicalPayload);

    final Uri uri = Uri.parse('${GlobalConfig.baseUrl}$endpoint').replace(
      queryParameters: {
        'employeeId': empId,
        'accessToken': authToken,
      },
    );

    if (kDebugMode) {
      print('🌐 Calling Location Graph API: $uri');
    }

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $authToken',
    };

    if (signature != null && signature.isNotEmpty) {
      headers['X-Signature'] = signature;
    }

    try {
      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: 20));

      if (kDebugMode) {
        print('📡 Location Graph API Status: ${response.statusCode}');
        print('📡 Response Body: ${response.body}');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final bool status = jsonResponse['status'] == true;
        if (!status) {
          throw Exception('Failed to retrieve location points');
        }
        final dynamic data = jsonResponse['data'];
        if (data == null) {
          return const LocationGraphData(locationPoints: []);
        }
        return LocationGraphData.fromJson(Map<String, dynamic>.from(data));
      } else {
        throw Exception('Server returned error code ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ LocationGraphService Error: $e');
      }
      rethrow;
    }
  }
}
