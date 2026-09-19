// lib/screens/login_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:my_demo_project/models/employee_model.dart';
import 'package:my_demo_project/services/cached_employee_checker.dart';
import '../services/auth_service.dart';
import 'employee_details_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  EmployeeModel? employee;

  // Location status state
  bool _isLocationEnabled = true;
  bool _isCheckingLocation = true;
  bool _isAlertShowing = false;
  StreamSubscription<ServiceStatus>? _locationServiceSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocationListener();
    _checkLocationAndSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationServiceSubscription?.cancel();
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLocationService(promptIfOff: false);
    }
  }

  /// Listen for real-time location service changes (e.g. quick settings toggle)
  void _initLocationListener() {
    try {
      _locationServiceSubscription = Geolocator.getServiceStatusStream().listen((status) {
        final isEnabled = status == ServiceStatus.enabled;
        if (!mounted) return;
        setState(() {
          _isLocationEnabled = isEnabled;
        });

        if (!isEnabled) {
          _showLocationTurnedOffAlert();
        } else {
          _dismissAlertIfShowing();
          if (!_isLoading) {
            _checkCachedEmployee();
          }
        }
      });
    } catch (_) {}
  }

  /// Initial check on page load
  Future<void> _checkLocationAndSession() async {
    setState(() {
      _isCheckingLocation = true;
    });

    final bool isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;

    setState(() {
      _isLocationEnabled = isEnabled;
      _isCheckingLocation = false;
    });

    if (!isEnabled) {
      _showLocationTurnedOffAlert();
    } else {
      await _checkCachedEmployee();
    }
  }

  /// Check location service status and optionally show alert
  Future<void> _checkLocationService({bool promptIfOff = true}) async {
    final bool isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;

    final wasDisabled = !_isLocationEnabled;
    setState(() {
      _isLocationEnabled = isEnabled;
    });

    if (!isEnabled && promptIfOff) {
      _showLocationTurnedOffAlert();
    } else if (isEnabled) {
      _dismissAlertIfShowing();
      if (wasDisabled && !_isLoading) {
        await _checkCachedEmployee();
      }
    }
  }

  void _dismissAlertIfShowing() {
    if (_isAlertShowing && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _isAlertShowing = false;
    }
  }

  /// Displays an alert dialog informing the user to turn on their device location
  void _showLocationTurnedOffAlert() {
    if (_isAlertShowing || !mounted) return;
    _isAlertShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.location_off_rounded, color: Colors.red.shade700, size: 28),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Location Turned Off',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Your device location is currently turned off.\n\nTo use this employee location tracking app and sign in, please turn on Location Services.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () async {
                  final isEnabled = await Geolocator.isLocationServiceEnabled();
                  if (!mounted) return;
                  if (isEnabled) {
                    _dismissAlertIfShowing();
                    setState(() {
                      _isLocationEnabled = true;
                    });
                    _checkCachedEmployee();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Location is still turned off. Please turn it on in device settings.'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Text('Check Again'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                },
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('Turn On Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      _isAlertShowing = false;
    });
  }

  Future<void> _checkCachedEmployee() async {
    // Guard: don't auto-navigate if location is off
    if (!_isLocationEnabled) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final EmployeeModel? cachedEmployee = await cachedEmployeeChecker.checkCachedEmployee();
      if (!mounted) return;
      // ============================================================
      // CACHED TOKEN EXISTS + EMPLOYEE FETCH SUCCESSFUL
      // ============================================================
      if (cachedEmployee != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                EmployeeDetailsScreen(
                  employee: cachedEmployee,
                ),
          ),
        );
        return;
      }
      // ============================================================
      // NO CACHED TOKEN
      // ============================================================
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _login() async {
    if (!_isLocationEnabled) {
      _showLocationTurnedOffAlert();
      return;
    }

    final userId = _userIdController.text.trim();
    final password = _passwordController.text.trim();

    if (userId.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter Employee ID and Password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await authService.login(
        userId: userId,
        password: password,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => EmployeeDetailsScreen(employee: authService.employee),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loginWithSSO() async {
    if (!_isLocationEnabled) {
      _showLocationTurnedOffAlert();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await authService.loginWithSSO();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => EmployeeDetailsScreen(employee: authService.employee),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isFormDisabled = _isLoading || !_isLocationEnabled;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Institute Logo
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    'lib/diu-logo.png',
                    height: 85,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.school,
                        size: 44,
                        color: Colors.indigo.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Geo Location Tracker',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 6),

                const Text(
                  'Sign in with your DIU credentials',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 20),

                // Location Off Alert Banner
                if (!_isLocationEnabled) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_off_rounded,
                                color: Colors.red.shade700, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Location Services Disabled',
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The login form is disabled because device location is turned off. Please turn on location to proceed.',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await Geolocator.openLocationSettings();
                            },
                            icon: const Icon(Icons.settings, size: 16),
                            label: const Text('Turn On Location in Settings'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_isLoading || _isCheckingLocation) ...[
                  const SizedBox(height: 35),
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isCheckingLocation
                        ? 'Checking location service...'
                        : 'Checking existing session...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ] else ...[
                  // Disabled wrapper when location is turned off
                  AbsorbPointer(
                    absorbing: isFormDisabled,
                    child: Opacity(
                      opacity: _isLocationEnabled ? 1.0 : 0.45,
                      child: Column(
                        children: [
                          // SSO Sign In Button (Primary Option)
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: isFormDisabled ? null : _loginWithSSO,
                              icon: const Icon(Icons.vpn_key_rounded, color: Colors.white),
                              label: const Text(
                                'Sign in with DIU SSO',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo.shade800,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade400,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // User ID Field
                          TextField(
                            controller: _userIdController,
                            decoration: InputDecoration(
                              labelText: 'Employee ID',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabled: !isFormDisabled,
                            ),
                            enabled: !isFormDisabled,
                          ),
                          const SizedBox(height: 16),

                          // Password Field
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: isFormDisabled
                                    ? null
                                    : () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabled: !isFormDisabled,
                            ),
                            enabled: !isFormDisabled,
                            onSubmitted: isFormDisabled ? null : (_) => _login(),
                          ),
                          const SizedBox(height: 24),

                          // Direct Login Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: isFormDisabled ? null : _login,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: isFormDisabled
                                      ? Colors.grey.shade400
                                      : Colors.indigo.shade700,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Sign In with Password',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isFormDisabled
                                      ? Colors.grey.shade500
                                      : Colors.indigo.shade700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Error Message
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
