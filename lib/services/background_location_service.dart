import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:my_demo_project/services/employee_api_service.dart';
import 'package:permission_handler/permission_handler.dart';

import '../global_config.dart';
import '../models/employee_model.dart';
import '../utility/CommonUtil.dart';
import 'employee_cached_location_service.dart';
import 'token_cache_service.dart';

class BackgroundLocationService {
  static final BackgroundLocationService _instance = BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String batteryPromptKey = 'battery_optimization_prompted';
  static const String activeEmployeeKey = 'active_tracking_employee';

  static Future<void> initialize() async {
    try {
      final service = FlutterBackgroundService();

      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onBackgroundServiceStart,
          autoStart: false,
          autoStartOnBoot: false,
          isForegroundMode: true,
          initialNotificationTitle: '📍 Location Tracking Active',
          initialNotificationContent: 'Syncing employee location every 1 minute...',
          foregroundServiceNotificationId: 8888,
          foregroundServiceTypes: [AndroidForegroundType.location],
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onBackgroundServiceStart,
          onBackground: onIosBackground,
        ),
      );
      if (kDebugMode) {
        print('🚀 [BackgroundLocationService] Service configured successfully.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [BackgroundLocationService] Configure error: $e');
      }
    }
  }

  /// Request essential permissions cleanly and non-redundantly.
  /// Battery optimization prompt is shown ONLY once ever.
  static Future<bool> ensurePermissions() async {
    try {
      // 1. Notification permission (Android 13+)
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        await Permission.notification.request();
      }
      // 2. Location permission
      var locStatus = await Permission.location.status;
      if (!locStatus.isGranted) {
        locStatus = await Permission.location.request();
      }

      // 3. Battery optimization exemption - only prompt ONCE across entire app lifetime
      final prompted = await _storage.read(key: batteryPromptKey);
      if (prompted != 'true') {
        final isIgnored = await Permission.ignoreBatteryOptimizations.isGranted;
        if (!isIgnored) {
          if (kDebugMode) {
            print('🔋 Requesting battery optimization exemption (first-time only)...');
          }
          await Permission.ignoreBatteryOptimizations.request();
        }
        await _storage.write(key: batteryPromptKey, value: 'true');
      }
      return locStatus.isGranted;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [BackgroundLocationService] Error ensuring permissions: $e');
      }
      return false;
    }
  }

  /// Starts the Android Foreground Service (WakeLock + Ongoing notification + background loop).
  /// Keeps tracking alive continuously even when the screen is off or app is minimized.
  static Future<void> startTracking(EmployeeModel? employee) async {
    if (employee == null) {
      return;
    }
    try {
      // Persist active employee info so background isolate has access across restarts
      await _storage.write(
        key: activeEmployeeKey,
        value: jsonEncode(employee.toJson()),
      );
      await ensurePermissions();
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (!isRunning) {
        await service.startService();
      }
      service.invoke('setEmployee', employee.toJson());
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [BackgroundLocationService] startTracking error: $e');
      }
    }
  }

  /// Pushes a fresh employee to the running isolate without stopping it.
  ///
  /// If the service is already running, only `setEmployee` fires — the 30s
  /// timer keeps ticking and no second timer is created.
  /// If the service is not running, it is started first.
  ///
  /// Safe to call any time, from any screen, repeatedly.
  static Future<void> updateActiveEmployee(EmployeeModel employee) async {
    try {
      // Persist first so a cold restart still sees fresh data.
      await _storage.write(
        key: activeEmployeeKey,
        value: jsonEncode(employee.toJson()),
      );

      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        // Push data only — do NOT call startService again.
        service.invoke('setEmployee', employee.toJson());
      } else {
        // Cold path — first login or service was stopped.
        await ensurePermissions();
        await service.startService();
        service.invoke('setEmployee', employee.toJson());
      }

      if (kDebugMode) {
        print('🔄 [BackgroundLocationService] Active employee pushed to isolate.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [BackgroundLocationService] updateActiveEmployee error: $e');
      }
    }
  }

  /// Requests the background service to execute a location sync immediately.
  static Future<void> syncNow() async {
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('syncNow');
      }
    } catch (_) {}
  }

  /// Updates the foreground notification text.
  static Future<void> updateNotification({required String title, required String content}) async {
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('updateNotification', {
          'title': title,
          'content': content,
        });
      }
    } catch (_) {}
  }

  /// Stops the background tracking foreground service.
  static Future<void> stopTracking() async {
    try {
      await _storage.delete(key: activeEmployeeKey);
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('stopService');
        if (kDebugMode) {
          print('⏹️ [BackgroundLocationService] Stop signal sent to background service.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [BackgroundLocationService] stopTracking error: $e');
      }
    }
  }
}

// ============================================================================
// BACKGROUND ISOLATE ENTRY POINT
// Runs in a dedicated background isolate managed by Android Foreground Service.
// Holds WakeLock, runs 1-minute tracking scheduler, caches & syncs to backend.
// ============================================================================

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  EmployeeModel? activeEmployee;
  DateTime? _employeeLoadedForDate;
  Timer? trackingTimer;
  final CommonUtil commonUtil = CommonUtil();
  final TokenCacheService tokenCache = TokenCacheService();
  final EmployeeCachedLocationService cachedLocationService = EmployeeCachedLocationService();
  const FlutterSecureStorage secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: '📍 Location Tracking Active',
      content: 'Initializing employee location tracking...',
    );
  }

  // Load employee from persistent storage if available
  Future<EmployeeModel?> loadStoredEmployee() async {
    try {
      final raw = await secureStorage.read(key: BackgroundLocationService.activeEmployeeKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return EmployeeModel.fromJson(decoded);
        }
      }else{
        print("loadStoredEmployee returned null employee");
      }
    } catch (_) {}
    return null;
  }

  /// Refresh activeEmployee when the calendar day has changed since it was
  /// last loaded. This runs before the duty-finished guard, so a new day
  /// automatically re-fetches today's startTime / endTime / weekend / holiday
  /// / firstPunch without needing the UI to be open.
  Future<void> ensureEmployeeForToday() async {
    final today = DateTime.now();
    final isSameDay = _employeeLoadedForDate != null &&
        _employeeLoadedForDate!.year  == today.year &&
        _employeeLoadedForDate!.month == today.month &&
        _employeeLoadedForDate!.day   == today.day;

    if (kDebugMode) {
      print('🔄 ensureEmployeeForToday value of is same day is : '
          '${isSameDay},');
    }
    if (isSameDay) return;
    final empId = activeEmployee?.userId ?? '';
    String? token = activeEmployee?.token;

    if (kDebugMode) {
      print(' ensureEmployeeForToday value of is employe id is: '
          'weekend=${empId},');
    }

    try {
      final fresh = await employeeApiService.fetchEmployeeInfo(
        employeeId:  empId,
        date:        today.toIso8601String().split('T').first,
        accessToken: token.toString(),
      );
      activeEmployee          = fresh.copyWith(token: token);
      _employeeLoadedForDate  = today;

      await secureStorage.write(
        key:   BackgroundLocationService.activeEmployeeKey,
        value: jsonEncode(activeEmployee!.toJson()),
      );

      if (kDebugMode) {
        print('🆕 [ensureEmployeeForToday] fetched new employee is fresh: '
            'start=${fresh.startTime}, end=${fresh.endTime}, '
            'weekend=${fresh.weekend}, holiday=${fresh.holiday}, '
            'firstPunch=${fresh.firstPunch}');
      }
      if (kDebugMode) {
        print('🆕 [ensureEmployeeForToday] fetched new employee is active employee: '
            'start=${activeEmployee?.startTime}, end=${activeEmployee?.endTime}, '
            'weekend=${activeEmployee?.weekend}, holiday=${activeEmployee?.holiday}, '
            'firstPunch=${activeEmployee?.firstPunch}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [ensureEmployeeForToday] New-day refresh failed: $e');
      }
      // leave _employeeLoadedForDate unchanged so the next tick retries
    }
  }

  /// Merges attendance fields returned by /sync-employee-location
  /// into the currently active employee, then persists the result.
  Future<void> applyAttendanceUpdate(Map<String, dynamic> updated) async {
    if (activeEmployee == null) return;
    String boolToString(dynamic v) {
      if (v == null) return 'false';
      if (v is bool) return v.toString();
      if (v is num)  return v == 0 ? 'false' : 'true';
      final s = v.toString().trim().toLowerCase();
      return (s == 'true' || s == '1' || s == 'yes') ? 'true' : 'false';
    }
    if (kDebugMode) {
      print('🔄 before update active is: '
          'weekend=${activeEmployee?.weekend}, holiday=${activeEmployee?.holiday}, '
          'start=${activeEmployee?.startTime}, end=${activeEmployee?.endTime}, '
          'firstPunch=${activeEmployee?.firstPunch}');
    }

    final patched = activeEmployee!.copyWith(
      startTime:  updated['startTime']?.toString(),
      endTime:    updated['endTime']?.toString(),
      firstPunch: updated['firstPunch']?.toString(),
      weekend:    updated.containsKey('weekend') ? boolToString(updated['weekend']) : null,
      holiday:    updated.containsKey('holiday') ? boolToString(updated['holiday']) : null,
    );

    activeEmployee = patched;
    await secureStorage.write(
      key:   BackgroundLocationService.activeEmployeeKey,
      value: jsonEncode(patched.toJson()),
    );
    if (kDebugMode) {
      print('🔄 after update active employee is patched: '
          'weekend=${patched.weekend}, holiday=${patched.holiday}, '
          'start=${patched.startTime}, end=${patched.endTime}, '
          'firstPunch=${patched.firstPunch}');
    }
    if (kDebugMode) {
      print('🔄 after update active employee is activeEmployee: '
          'weekend=${activeEmployee?.weekend}, holiday=${activeEmployee?.holiday}, '
          'start=${activeEmployee?.startTime}, end=${activeEmployee?.endTime}, '
          'firstPunch=${activeEmployee?.firstPunch}');
    }
  }

  // Execute one tracking cycle: GPS retrieval -> buffer caching -> batch HTTP sync
  Future<void> runTrackingTick() async {

    print("runTrackingTick is called at "+DateTime.now().toString());

    try {

      activeEmployee ??= await loadStoredEmployee();
      if(activeEmployee==null){
        print("in runTrackingTick  activeEmployee is null at "+DateTime.now().toString());
      }

      if (kDebugMode) {
        print('🆕 [runTrackingTick] activeEmployee from stored is : '
            'start=${activeEmployee?.startTime}, end=${activeEmployee?.endTime}, '
            'weekend=${activeEmployee?.weekend}, holiday=${activeEmployee?.holiday}, '
            'firstPunch=${activeEmployee?.firstPunch}');
      }
      await ensureEmployeeForToday();
      final  bool finishedOffishHourOrHoliday = await commonUtil.isOfficeHourFinished(activeEmployee);
     if (activeEmployee != null && finishedOffishHourOrHoliday) {
        if (kDebugMode) {
          print('⏹️ [BackgroundIsolate] Duty time completed (8 hours). Stopping service.');
        }
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: '📍 Duty Finished',
            content: 'Today\'s 8-hour duty completed. Location tracking stopped.',
          );
        }
/*        trackingTimer?.cancel();
        service.stopSelf();*/
        return;
      }
      // Verify GPS is on
      final bool isGpsEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isGpsEnabled) {
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: '⚠️ Location Services Disabled',
            content: 'Turn on GPS to resume continuous tracking',
          );
        }
        return;
      }
      // Acquire position
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }

      if (position == null) {
        if (kDebugMode) {
          print('⚠️ [BackgroundIsolate] Unable to get GPS coordinates on this tick.');
        }
        return;
      }

      // Resolve employee ID & token
      final String empId = activeEmployee?.userId ?? '';
      String? token = activeEmployee?.token;
      if (token == null || token.isEmpty) {
        token = await tokenCache.getToken();
      }

      final locationEntry = {
        'employeeId': empId,
        'longitude': position.longitude,
        'latitude': position.latitude,
        'date': position.timestamp.toIso8601String(),
        'accessToken': token,
      };

      // Store in persistent cache
      await cachedLocationService.addLocation(locationEntry);
      final List<Map<String, dynamic>> cachedLocations = await cachedLocationService.getCachedLocations();
      final int cacheCount = cachedLocations.length;
      final timeStr = DateFormat('hh:mm:ss a').format(DateTime.now());

      bool syncSuccess = false;

      // Batch sync when cache count reaches 5 or multiple of 5 (5*n)
      if (cacheCount > 0 && cacheCount%4==0) {
        if (kDebugMode) {
          print('🚀 [BackgroundIsolate] Syncing batch of $cacheCount locations to backend...');
        }
        try {
          final Uri syncUri = Uri.parse(
              '${GlobalConfig.baseUrl}/api/geo/portal/geo-location/sync-employee-location');
          final response = await http.post(
            syncUri,
            headers: {
              'Content-Type': 'application/json',
              if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(cachedLocations),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode >= 200 && response.statusCode < 300) {
            final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
            if (jsonResponse['status'] != false) {
              await cachedLocationService.clearCachedLocations();
              final dynamic data = jsonResponse['data'];
              if (data is Map<String, dynamic>) {
                await applyAttendanceUpdate(data);
              }
              syncSuccess = true;
              if (kDebugMode) {
                print('✅ [BackgroundIsolate] Batch sync succeeded: $cacheCount locations.');
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ [BackgroundIsolate] Batch sync failed (cache preserved): $e');
          }
        }
      }

      // Update Foreground Service Notification
      if (service is AndroidServiceInstance) {
        final contentText = syncSuccess
            ? 'Last sync: $timeStr | Synced $cacheCount pts | Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}'
            : 'Recorded: $timeStr | Cached: $cacheCount pts (next at ${((cacheCount ~/ 5) + 1) * 5}) | Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';

        service.setForegroundNotificationInfo(
          title: '📍 Location Tracking Active',
          content: contentText,
        );
      }

      // Emit event to UI isolate (if app is in foreground)
      service.invoke('locationUpdated', {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': position.timestamp.toIso8601String(),
        'cacheCount': syncSuccess ? 0 : cacheCount,
        'synced': syncSuccess,
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ [BackgroundIsolate] runTrackingTick error: $e');
      }
    }
  }

  // Event Listeners
  service.on('setEmployee').listen((data) {
    if (data != null) {
      activeEmployee = EmployeeModel.fromJson(data);
      _employeeLoadedForDate = DateTime.now();
      if (kDebugMode) {
        print('👤 [BackgroundIsolate] Active employee updated: ${activeEmployee?.name}');
      }
    }
  });

  service.on('syncNow').listen((_) {
    runTrackingTick();
  });

  service.on('stopService').listen((_) {
    trackingTimer?.cancel();
    service.stopSelf();
  });

  service.on('updateNotification').listen((data) {
    if (service is AndroidServiceInstance && data != null) {
      service.setForegroundNotificationInfo(
        title: data['title']?.toString() ?? '📍 Location Tracking Active',
        content: data['content']?.toString() ?? 'Tracking active',
      );
    }
  });

  // Start continuous 1-minute scheduler directly in this background service isolate
  trackingTimer =Timer.periodic(const Duration(seconds: 30), (_) {
    runTrackingTick();
  });

  // Run immediately on service start
  runTrackingTick();
}
