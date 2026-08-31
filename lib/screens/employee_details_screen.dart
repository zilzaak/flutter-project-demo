import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../app_global.dart';
import '../models/employee_model.dart';
import '../models/location_data_model.dart';
import '../models/location_graph_model.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/location_graph_service.dart';
import 'login_screen.dart';


class EmployeeDetailsScreen extends StatefulWidget {
  const EmployeeDetailsScreen({super.key});
  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  final LocationService _locationService = LocationService();
  final AuthService _authService = AuthService();
  final MapController _mapController = MapController();

  LocationDataModel? _currentLocation;
  bool _isFetchingLocation = false;
  String? _locationError;
  bool _isTracking = false;

  // Location Graph state & 5-minute scheduler
  Timer? _graphRefreshTimer;
  LocationGraphData? _graphData;
  bool _isLoadingGraph = false;
  String? _graphError;
  DateTime? _lastGraphUpdatedTime;
  bool _showAllWaypoints = true;

  @override
  void initState() {
    super.initState();
    _initializeLocationTracking();
    _fetchLocationGraph();
    _startGraphScheduler();
  }

  @override
  void dispose() {
    _graphRefreshTimer?.cancel();
    _locationService.stopScheduledSync();
    _locationService.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Start 5-minute periodic scheduler for refreshing the location graph
  void _startGraphScheduler() {
    _graphRefreshTimer?.cancel();
    _graphRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _fetchLocationGraph(isBackground: true);
    });
  }

  void _initializeLocationTracking() {
    if (globals.currentEmployee != null) {
      _locationService.startScheduledSync();
      setState(() {
        _isTracking = true;
      });
      _fetchLocation();
    }
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

  /// Fetch location graph from API (called on load, every 5 min, and after manual sync)
  Future<void> _fetchLocationGraph({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() {
        _isLoadingGraph = true;
        _graphError = null;
      });
    }

    try {
      final data = await LocationGraphService.fetchMyLocationGraph();
      if (!mounted) return;
      setState(() {
        _graphData = data;
        _graphError = null;
        _isLoadingGraph = false;
        _lastGraphUpdatedTime = DateTime.now();
      });

      // Fit map bounds once data is loaded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitMapBounds();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!isBackground) {
          _graphError = e.toString().replaceAll('Exception: ', '');
        }
        _isLoadingGraph = false;
      });
    }
  }

  void _fitMapBounds() {
    if (_graphData == null) return;

    final List<LatLng> allPoints = [];
    if (_graphData!.hasPoints) {
      allPoints.addAll(_graphData!.polylinePoints);
    }
    if (_graphData!.hasOfficeLocation) {
      allPoints.add(_graphData!.officeLatLng!);
    }

    if (allPoints.isEmpty) return;

    if (allPoints.length == 1) {
      _mapController.move(allPoints.first, 16.0);
    } else {
      final bounds = LatLngBounds.fromPoints(allPoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40.0),
        ),
      );
    }
  }

  Future<void> _manualSync() async {
    setState(() {
      _isFetchingLocation = true;
    });

    try {
      await _locationService.syncLocationNow();
      await _fetchLocation();
      // Also refresh the location graph immediately so new point is reflected
      await _fetchLocationGraph(isBackground: true);
      _showSnackBar('✅ Location synced & graph updated', Colors.green);
    } catch (e) {
      _showSnackBar('❌ Failed to sync: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  void _toggleTracking() {
    setState(() {
      _isTracking = !_isTracking;
    });

    if (_isTracking) {
      _locationService.startScheduledSync();
      _showSnackBar('📍 Tracking resumed', Colors.blue);
    } else {
      _locationService.stopScheduledSync();
      _showSnackBar('⏹️ Tracking paused', Colors.orange);
    }
  }

  void _handleLogout() {
    _graphRefreshTimer?.cancel();
    _locationService.stopScheduledSync();
    _authService.logout();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showWaypointsBottomSheet() {
    if (_graphData == null || !_graphData!.hasPoints) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Location Timeline (${_graphData!.totalPoints} Points)',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _graphData!.locationPoints.length,
                      separatorBuilder: (_, _) => const Divider(height: 12),
                      itemBuilder: (context, index) {
                        final point = _graphData!.locationPoints[index];
                        final isFirst = index == 0;
                        final isLast = index == _graphData!.locationPoints.length - 1;

                        Color tagColor = Colors.grey.shade700;
                        String tagText = 'Point #${index + 1}';
                        IconData iconData = Icons.location_pin;

                        if (isFirst) {
                          tagColor = Colors.green.shade700;
                          tagText = 'Start Point';
                          iconData = Icons.play_circle_fill;
                        } else if (isLast) {
                          tagColor = Colors.blue.shade700;
                          tagText = 'Latest Point';
                          iconData = Icons.flag;
                        }

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: tagColor.withValues(alpha: 0.15),
                            child: Icon(iconData, color: tagColor, size: 20),
                          ),
                          title: Text(
                            tagText,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: tagColor,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Lat: ${point.latitude.toStringAsFixed(6)}, Lng: ${point.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.center_focus_strong, size: 20),
                            tooltip: 'Focus on Map',
                            onPressed: () {
                              Navigator.pop(ctx);
                              _mapController.move(point.toLatLng(), 17.0);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final emp = globals.currentEmployee;

    if (emp == null) {
      return const Scaffold(
        body: Center(
          child: Text('No employee data found'),
        ),
      );
    }

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
        onRefresh: () async {
          await Future.wait([
            _fetchLocation(),
            _fetchLocationGraph(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Card
              _buildProfileCard(emp),
              const SizedBox(height: 24),

              // Employment Info
              const Text(
                'Employment Info',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildDetailTile(
                icon: Icons.business,
                title: 'Department',
                value: emp.department,
                color: Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildDetailTile(
                icon: Icons.calendar_today,
                title: 'Joining Date',
                value: emp.joiningDate,
                color: Colors.amber.shade700,
              ),
              const SizedBox(height: 12),
              _buildDetailTile(
                icon: Icons.access_time_filled,
                title: 'Duty Time',
                value: '${emp.startTime} - ${emp.endTime}',
                color: Colors.teal,
              ),
              const SizedBox(height: 24),

              // Location Tracking Status & Coordinates
              _buildLocationSection(),
              const SizedBox(height: 24),

              // Embedded Location Graph Section (Auto-refreshed every 5 min)
              _buildLocationGraphCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(EmployeeModel emp) {
    return Container(
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
            color: Colors.indigo.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: const Icon(Icons.person, size: 44, color: Colors.white),
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
                    color: Colors.white.withValues(alpha: 0.2),
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
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '📍 Location Tracking',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Icon(
                  _isTracking ? Icons.circle : Icons.circle_outlined,
                  color: _isTracking ? Colors.green : Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _toggleTracking,
                  icon: Icon(
                    _isTracking ? Icons.pause : Icons.play_arrow,
                    size: 16,
                    color: _isTracking ? Colors.orange : Colors.green,
                  ),
                  label: Text(
                    _isTracking ? 'Pause' : 'Resume',
                    style: TextStyle(
                      color: _isTracking ? Colors.orange : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          Text(
                            _isTracking ? '🟢 Tracking Active' : '⏸️ Tracking Paused',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: _isTracking ? Colors.green.shade700 : Colors.orange.shade700,
                            ),
                          ),
                          Text(
                            _currentLocation != null
                                ? 'Last sync: ${_currentLocation!.timestamp.toLocal().toString().substring(0, 19)}'
                                : 'Waiting for location...',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isFetchingLocation ? null : _manualSync,
                      icon: _isFetchingLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync, size: 16),
                      label: const Text('Sync Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 36),
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
                          'Accuracy: ~${_currentLocation!.accuracy.toStringAsFixed(1)}m | Auto-sync every 1 min',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
      ],
    );
  }

  /// Embedded Location Graph Card (Live Map & Stats, Auto-refreshed every 5 min)
  Widget _buildLocationGraphCard() {
    final String lastUpdatedStr = _lastGraphUpdatedTime != null
        ? '${_lastGraphUpdatedTime!.hour.toString().padLeft(2, '0')}:${_lastGraphUpdatedTime!.minute.toString().padLeft(2, '0')}:${_lastGraphUpdatedTime!.second.toString().padLeft(2, '0')}'
        : 'Loading...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with Auto-refresh badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🗺️ Live Location Graph',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Auto-refreshes every 5 mins (Last: $lastUpdatedStr)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            IconButton(
              icon: _isLoadingGraph
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 22, color: Colors.indigo),
              tooltip: 'Refresh Graph Now',
              onPressed: _isLoadingGraph ? null : () => _fetchLocationGraph(),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Card(
          elevation: 3,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Interactive Map
              SizedBox(
                height: 320,
                width: double.infinity,
                child: _buildMapWidget(),
              ),

              // Summary Stats bar below map
              if (_graphData != null) _buildGraphSummaryStats(_graphData!),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapWidget() {
    if (_isLoadingGraph && _graphData == null) {
      return Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.indigo),
              SizedBox(height: 12),
              Text(
                'Loading location graph...',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_graphError != null && _graphData == null) {
      return Container(
        color: Colors.grey.shade50,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 40, color: Colors.red.shade400),
              const SizedBox(height: 8),
              Text(
                _graphError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => _fetchLocationGraph(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final data = _graphData;
    final LatLng defaultCenter = const LatLng(23.777176, 90.399452);
    final initialCenter = data?.latestPoint?.toLatLng() ??
        data?.officeLatLng ??
        (_currentLocation != null ? LatLng(_currentLocation!.latitude, _currentLocation!.longitude) : defaultCenter);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 15.0,
            minZoom: 4.0,
            maxZoom: 19.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'bd.edu.diu.hressportal',
            ),

            // Office Geofence Circle
            if (data != null && data.hasOfficeLocation)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: data.officeLatLng!,
                    radius: 100,
                    useRadiusInMeter: true,
                    color: Colors.red.withValues(alpha: 0.18),
                    borderColor: Colors.red.shade700,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),

            // Polyline connecting chronological points
            if (data != null && data.hasPoints && data.locationPoints.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: data.polylinePoints,
                    color: Colors.indigo.shade600,
                    strokeWidth: 4.5,
                    borderStrokeWidth: 1.5,
                    borderColor: Colors.white,
                  ),
                ],
              ),

            // Markers Layer
            if (data != null)
              MarkerLayer(
                markers: _buildMarkers(data),
              ),
          ],
        ),

        // Floating Action Buttons on top-right of map
        Positioned(
          top: 10,
          right: 10,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'recenter_map',
                backgroundColor: Colors.white,
                foregroundColor: Colors.indigo,
                onPressed: _fitMapBounds,
                tooltip: 'Fit to Path',
                child: const Icon(Icons.crop_free, size: 20),
              ),
              const SizedBox(height: 6),
              FloatingActionButton.small(
                heroTag: 'toggle_points',
                backgroundColor: _showAllWaypoints ? Colors.indigo : Colors.white,
                foregroundColor: _showAllWaypoints ? Colors.white : Colors.indigo,
                onPressed: () {
                  setState(() {
                    _showAllWaypoints = !_showAllWaypoints;
                  });
                },
                tooltip: 'Toggle All Points',
                child: const Icon(Icons.grain, size: 20),
              ),
            ],
          ),
        ),

        // Bottom Banner when empty
        if (data == null || (!data.hasPoints && !data.hasOfficeLocation))
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No location history logged today yet.',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Marker> _buildMarkers(LocationGraphData data) {
    final List<Marker> markers = [];

    // Office Location Marker
    if (data.hasOfficeLocation) {
      markers.add(
        Marker(
          point: data.officeLatLng!,
          width: 80,
          height: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'OFFICE',
                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              Icon(Icons.location_on, color: Colors.red.shade700, size: 30),
            ],
          ),
        ),
      );
    }

    if (!data.hasPoints) return markers;

    // Intermediate Waypoints
    if (_showAllWaypoints && data.locationPoints.length > 2) {
      for (int i = 1; i < data.locationPoints.length - 1; i++) {
        final pt = data.locationPoints[i];
        markers.add(
          Marker(
            point: pt.toLatLng(),
            width: 20,
            height: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.indigo.shade600,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
              ),
              child: Center(
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        );
      }
    }

    // Start Point Marker
    if (data.startPoint != null) {
      markers.add(
        Marker(
          point: data.startPoint!.toLatLng(),
          width: 70,
          height: 55,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'START',
                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              Icon(Icons.location_pin, color: Colors.green.shade700, size: 28),
            ],
          ),
        ),
      );
    }

    // Latest Point Marker
    if (data.latestPoint != null && data.locationPoints.length > 1) {
      markers.add(
        Marker(
          point: data.latestPoint!.toLatLng(),
          width: 70,
          height: 55,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LATEST',
                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              Icon(Icons.person_pin_circle, color: Colors.blue.shade700, size: 30),
            ],
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildGraphSummaryStats(LocationGraphData data) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.timeline,
                label: 'Points',
                value: '${data.totalPoints}',
                color: Colors.indigo,
              ),
              Container(height: 28, width: 1, color: Colors.grey.shade300),
              _buildStatItem(
                icon: Icons.route,
                label: 'Distance',
                value: '${data.totalDistanceKm.toStringAsFixed(2)} km',
                color: Colors.teal,
              ),
              if (data.hasOfficeLocation && data.distanceFromOfficeKm != null) ...[
                Container(height: 28, width: 1, color: Colors.grey.shade300),
                _buildStatItem(
                  icon: Icons.business,
                  label: 'From Office',
                  value: '${data.distanceFromOfficeKm!.toStringAsFixed(2)} km',
                  color: Colors.red.shade700,
                ),
              ],
            ],
          ),
          if (data.hasPoints) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton.icon(
                onPressed: _showWaypointsBottomSheet,
                icon: const Icon(Icons.format_list_numbered, size: 16),
                label: const Text('View All Location Timeline Points', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.indigo,
                  side: BorderSide(color: Colors.indigo.shade200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
