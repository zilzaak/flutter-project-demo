import 'package:flutter/material.dart';
import 'models/employee_model.dart';
import 'screens/employee_details_screen.dart';
import 'screens/login_screen.dart';
import 'services/background_location_service.dart';
import 'services/cached_employee_checker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundLocationService.initialize();

  // Check for cached session before choosing root screen
  EmployeeModel? cachedEmployee;
  try {
    cachedEmployee = await cachedEmployeeChecker.checkCachedEmployee();
  } catch (_) {}

  runApp(MyApp(initialEmployee: cachedEmployee));
}

class MyApp extends StatelessWidget {
  final EmployeeModel? initialEmployee;
  const MyApp({super.key, this.initialEmployee});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DIU Geo Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: initialEmployee != null
          ? EmployeeDetailsScreen(employee: initialEmployee)
          : const LoginScreen(),
    );
  }
}
