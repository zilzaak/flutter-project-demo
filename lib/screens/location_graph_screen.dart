// lib/screens/location_graph_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../global_config.dart';
import '../models/location_graph_model.dart';
import '../services/location_graph_service.dart';

class LocationGraphScreen extends StatefulWidget {
  const LocationGraphScreen({super.key});

  @override
  State<LocationGraphScreen> createState() => _LocationGraphScreenState();
}

class _LocationGraphScreenState extends State<LocationGraphScreen> {
  final MapController _mapController = MapController();

  bool _isLoading = true;
  String? _errorMessage;
  LocationGraphData? _graphData;
  final bool _showOfficeGeofence = true;
  bool _showAllPointMarkers = true;

  @override
  void initState() {
    super.initState();
    _loadLocationGraph();
  }

  Future<void> _loadLocationGraph() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await LocationGraphService.fetchMyLocationGraph();
      if (!mounted) return;
      setState(() {
        _graphData = data;
        _isLoading = false;
      });

      // Fit map to points once loaded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitMapBounds();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
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
          padding: const EdgeInsets.all(60.0),
        ),
      );
    }
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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Location Graph',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            if (emp != null)
              Text(
                '${emp.name} (ID: ${emp.userId})',
                style: TextStyle(fontSize: 12, color: Colors.indigo.shade100),
              ),
          ],
        ),
        backgroundColor: Colors.indigo.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Reload Graph',
            onPressed: _loadLocationGraph,
          ),
          if (_graphData != null && _graphData!.hasPoints)
            IconButton(
              icon: const Icon(Icons.list_alt, color: Colors.white),
              tooltip: 'View Waypoints List',
              onPressed: _showWaypointsBottomSheet,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.indigo),
            const SizedBox(height: 16),
            Text(
              'Fetching today\'s location path...',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red.shade400),
              const SizedBox(height: 16),
              const Text(
                'Unable to load location graph',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadLocationGraph,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final data = _graphData;
    if (data == null || (!data.hasPoints && !data.hasOfficeLocation)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'No Location Data Recorded Today',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Location points are synchronized every 1 minute when tracking is enabled. Once logged, points will appear here chronologically.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadLocationGraph,
                icon: const Icon(Icons.refresh),
                label: const Text('Check Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final initialCenter = data.latestPoint?.toLatLng() ??
        data.officeLatLng ??
        const LatLng(23.777176, 90.399452);

    return Stack(
      children: [
        // OpenStreetMap Interactive Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 15.0,
            minZoom: 4.0,
            maxZoom: 19.0,
          ),
          children: [
            // Standard OpenStreetMap Tiles
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'bd.edu.diu.hressportal',
            ),

            // Office Geofence Circle (e.g. 100m radius)
            if (data.hasOfficeLocation && _showOfficeGeofence)
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

            // Polyline Path Track (connecting all chronological points)
            if (data.hasPoints && data.locationPoints.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: data.polylinePoints,
                    color: Colors.indigo.shade600,
                    strokeWidth: 5.0,
                    borderStrokeWidth: 2.0,
                    borderColor: Colors.white,
                  ),
                ],
              ),

            // Markers Layer
            MarkerLayer(
              markers: _buildMapMarkers(data),
            ),
          ],
        ),

        // Floating Map Controls (Right Side)
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'recenter_btn',
                backgroundColor: Colors.white,
                foregroundColor: Colors.indigo,
                onPressed: _fitMapBounds,
                tooltip: 'Fit to Track',
                child: const Icon(Icons.crop_free),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'toggle_markers_btn',
                backgroundColor: _showAllPointMarkers ? Colors.indigo : Colors.white,
                foregroundColor: _showAllPointMarkers ? Colors.white : Colors.indigo,
                onPressed: () {
                  setState(() {
                    _showAllPointMarkers = !_showAllPointMarkers;
                  });
                },
                tooltip: 'Toggle Waypoint Markers',
                child: const Icon(Icons.grain),
              ),
              const SizedBox(height: 8),
              if (data.hasOfficeLocation)
                FloatingActionButton.small(
                  heroTag: 'focus_office_btn',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red.shade700,
                  onPressed: () {
                    _mapController.move(data.officeLatLng!, 17.0);
                  },
                  tooltip: 'Focus Office',
                  child: const Icon(Icons.business),
                ),
            ],
          ),
        ),

        // Summary Card at Bottom
        Positioned(
          left: 16,
          right: 16,
          bottom: 20,
          child: _buildSummaryCard(data),
        ),
      ],
    );
  }

  List<Marker> _buildMapMarkers(LocationGraphData data) {
    final List<Marker> markers = [];

    // 1. Office Location Marker
    if (data.hasOfficeLocation) {
      markers.add(
        Marker(
          point: data.officeLatLng!,
          width: 90,
          height: 70,
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '🏢 Office Location: ${data.officeLatitude!.toStringAsFixed(5)}, ${data.officeLongitude!.toStringAsFixed(5)}',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: const Text(
                    'OFFICE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  Icons.location_on,
                  color: Colors.red.shade700,
                  size: 36,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!data.hasPoints) return markers;

    // 2. Intermediate Waypoints (if toggled on)
    if (_showAllPointMarkers && data.locationPoints.length > 2) {
      for (int i = 1; i < data.locationPoints.length - 1; i++) {
        final pt = data.locationPoints[i];
        markers.add(
          Marker(
            point: pt.toLatLng(),
            width: 22,
            height: 22,
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Point #${i + 1}: ${pt.latitude.toStringAsFixed(6)}, ${pt.longitude.toStringAsFixed(6)}',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    // 3. Start Point Marker (First recorded location)
    if (data.startPoint != null) {
      markers.add(
        Marker(
          point: data.startPoint!.toLatLng(),
          width: 80,
          height: 65,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: const Text(
                  'START',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(
                Icons.location_pin,
                color: Colors.green.shade700,
                size: 34,
              ),
            ],
          ),
        ),
      );
    }

    // 4. Latest / Current Point Marker (Last recorded location)
    if (data.latestPoint != null && data.locationPoints.length > 1) {
      markers.add(
        Marker(
          point: data.latestPoint!.toLatLng(),
          width: 80,
          height: 65,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: const Text(
                  'LATEST',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(
                Icons.person_pin_circle,
                color: Colors.blue.shade700,
                size: 36,
              ),
            ],
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildSummaryCard(LocationGraphData data) {
    return Card(
      elevation: 6,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.timeline,
                  label: 'Total Points',
                  value: '${data.totalPoints}',
                  color: Colors.indigo,
                ),
                Container(height: 35, width: 1, color: Colors.grey.shade300),
                _buildStatItem(
                  icon: Icons.route,
                  label: 'Distance',
                  value: '${data.totalDistanceKm.toStringAsFixed(2)} km',
                  color: Colors.teal,
                ),
                if (data.hasOfficeLocation && data.distanceFromOfficeKm != null) ...[
                  Container(height: 35, width: 1, color: Colors.grey.shade300),
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showWaypointsBottomSheet,
                  icon: const Icon(Icons.format_list_numbered, size: 18),
                  label: const Text('View All Location Points'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo,
                    side: BorderSide(color: Colors.indigo.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
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
            Icon(icon, size: 16, color: color),
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
    );
  }
}
