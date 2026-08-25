
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/employee_model.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'login_screen.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  final EmployeeModel employee;
  const EmployeeDetailsScreen({super.key, required this.employee});
  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  final LocationService _locationService = LocationService();
  LocationDataModel? _currentLocation;
  bool _isFetchingLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }


  Future<void> _fetchLocation() async {
    setState(() {
      _isFetchingLocation = true;
      _locationError = null;
    });

    try {
      final loc = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _currentLocation = loc;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }




  void _handleLogout() {
    AuthService().logout();
    Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }


  @override
  Widget build(BuildContext context) {
    final emp = widget.employee;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Employee Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.indigo.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLocation,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Employee Profile Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade700, Colors.indigo.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: const Icon(
                        Icons.person,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            emp.designation,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.indigo.shade100,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'ID: ${emp.userId}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'Employment Info',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // Detail Item Cards
              _buildDetailTile(
                icon: Icons.business,
                title: 'Department Name',
                value: emp.department,
                iconColor: Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildDetailTile(
                icon: Icons.calendar_today,
                title: 'Joining Date',
                value: emp.joiningDate,
                iconColor: Colors.amber.shade700,
              ),
              const SizedBox(height: 12),
              _buildDetailTile(
                icon: Icons.access_time_filled,
                title: 'Duty Time Shift',
                value: emp.startTime+' to ' +emp.endTime, // e.g. "8:10 AM - 4:00 PM"
                iconColor: Colors.teal,
              ),

              const SizedBox(height: 28),

              // Background FLP Location Card
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'FLP Location Tracking',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: _isFetchingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, color: Colors.indigo),
                    onPressed: _isFetchingLocation ? null : _fetchLocation,
                    tooltip: 'Fetch Current Location',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: _currentLocation != null ? Colors.green : Colors.red,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Fused Location Provider (Free)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  _currentLocation != null
                                      ? 'Status: Active & Updated'
                                      : (_locationError != null ? 'Status: Permission/GPS Error' : 'Status: Fetching coordinates...'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      if (_locationError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _locationError!,
                            style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _fetchLocation,
                          icon: const Icon(Icons.gps_fixed, size: 18),
                          label: const Text('Grant Permission / Retry FLP'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ] else if (_currentLocation != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildCoordinateBox(
                                label: 'LATITUDE',
                                value: _currentLocation!.latitude.toStringAsFixed(6),
                                color: Colors.blue.shade800,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildCoordinateBox(
                                label: 'LONGITUDE',
                                value: _currentLocation!.longitude.toStringAsFixed(6),
                                color: Colors.indigo.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Accuracy: ~${_currentLocation!.accuracy.toStringAsFixed(1)}m | Api Hook Ready',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinateBox({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
