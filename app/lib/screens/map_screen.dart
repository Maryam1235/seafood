import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MapScreen — full-featured in-app map
//
// Features:
//   • OpenStreetMap tiles (no API key)
//   • OSRM routing: draws a turn-by-turn polyline from user → destination
//   • Nominatim reverse geocoding: resolves lat/lng → human address
//   • Live user location marker (GPS)
//   • Distance + ETA info card (from OSRM)
//   • Zoom in/out + re-centre FABs
//   • Smooth animated map controller
// ─────────────────────────────────────────────────────────────────────────────

class MapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String label;

  /// Role-based pin colour: driver = teal, seller = orange, customer = navy
  final Color? pinColor;

  /// Optional subtitle shown in the bottom card (e.g. "Seller • Stone Town")
  final String? subtitle;

  const MapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.label,
    this.pinColor,
    this.subtitle,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  // ── Constants ────────────────────────────────────────────────────────────
  static const _osrmBase = 'https://router.project-osrm.org/route/v1/driving';
  static const _nominatimBase = 'https://nominatim.openstreetmap.org/reverse';
  static const _navy = Color(0xFF1E1B4B);

  // CartoDB Positron — free, no API key, no 403 issues
  static const _tileUrl =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
  static const _tileSubdomains = ['a', 'b', 'c', 'd'];

  // ── State ─────────────────────────────────────────────────────────────────
  final MapController _mapCtrl = MapController();
  late final AnimationController _pulseCtrl;
  bool _disposed = false;

  LatLng? _userLoc;
  List<LatLng> _routePoints = [];
  String _address = '…';
  double? _distanceKm;
  int? _etaMin;
  bool _loadingRoute = false;
  bool _loadingLoc = false;
  bool _showRoute = false;

  // Safe setState — ignores call if widget is disposed
  void _setState(VoidCallback fn) {
    if (_disposed || !mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _reverseGeocode();
    _fetchUserLocation();
  }

  @override
  void dispose() {
    _disposed = true;
    _pulseCtrl.dispose();
    // Do NOT call _mapCtrl.dispose() — flutter_map manages its lifecycle.
    super.dispose();
  }

  // ── Nominatim reverse geocode ─────────────────────────────────────────────
  Future<void> _reverseGeocode() async {
    try {
      final uri = Uri.parse(
        '$_nominatimBase?lat=${widget.latitude}&lon=${widget.longitude}'
        '&format=json&zoom=17&addressdetails=1',
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'ZanSeafoodApp/1.0 (contact@zanseafood.com)',
      }).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>?;
        final parts = <String>[
          if (addr?['road'] != null) addr!['road'] as String,
          if (addr?['suburb'] != null) addr!['suburb'] as String,
          if (addr?['city'] != null)
            addr!['city'] as String
          else if (addr?['town'] != null)
            addr!['town'] as String,
        ];
        _setState(() => _address = parts.isNotEmpty
            ? parts.join(', ')
            : (data['display_name'] as String? ?? ''));
      }
    } catch (_) {}
  }

  // ── Get user GPS location then fetch OSRM route ───────────────────────────
  Future<void> _fetchUserLocation() async {
    if (_loadingLoc || _disposed) return;
    _setState(() => _loadingLoc = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (_disposed) return;
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (_disposed) return;
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (_disposed) return;
      _setState(() => _userLoc = LatLng(pos.latitude, pos.longitude));
      await _fetchRoute();
    } catch (_) {
    } finally {
      _setState(() => _loadingLoc = false);
    }
  }

  // ── OSRM driving route ────────────────────────────────────────────────────
  Future<void> _fetchRoute() async {
    final origin = _userLoc;
    if (origin == null || _disposed) return;
    _setState(() => _loadingRoute = true);
    try {
      final dest = LatLng(widget.latitude, widget.longitude);
      final url = '$_osrmBase/${origin.longitude},${origin.latitude};'
          '${dest.longitude},${dest.latitude}'
          '?overview=full&geometries=geojson&steps=false';

      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (_disposed) return;
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return;

      final route = routes.first as Map<String, dynamic>;
      final distMeters = (route['distance'] as num).toDouble();
      final durSec = (route['duration'] as num).toDouble();

      final coords = (route['geometry']['coordinates'] as List)
          .map((c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();

      if (_disposed) return;
      _setState(() {
        _routePoints = coords;
        _distanceKm = distMeters / 1000;
        _etaMin = (durSec / 60).ceil();
        _showRoute = true;
      });

      _fitBounds(origin, dest);
    } catch (_) {
    } finally {
      _setState(() => _loadingRoute = false);
    }
  }

  void _fitBounds(LatLng a, LatLng b) {
    if (_disposed) return;
    final bounds = LatLngBounds(a, b);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      try {
        _mapCtrl.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(60),
          ),
        );
      } catch (_) {}
    });
  }

  Color get _pin => widget.pinColor ?? _navy;

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final dest = LatLng(widget.latitude, widget.longitude);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: dest,
              initialZoom: 15,
              minZoom: 3,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // CartoDB Positron tiles — no API key, no 403
              TileLayer(
                urlTemplate: _tileUrl,
                subdomains: _tileSubdomains,
                userAgentPackageName: 'com.zanseafood.app',
                maxZoom: 19,
                retinaMode: MediaQuery.of(context).devicePixelRatio > 1,
              ),

              // OSRM route polyline
              if (_showRoute && _routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5,
                      color: _pin.withValues(alpha: 0.85),
                      borderStrokeWidth: 2,
                      borderColor: Colors.white.withValues(alpha: 0.6),
                    ),
                  ],
                ),

              // Markers
              MarkerLayer(
                markers: [
                  // User location marker
                  if (_userLoc != null)
                    Marker(
                      point: _userLoc!,
                      width: 48,
                      height: 48,
                      child: _UserMarker(pulseCtrl: _pulseCtrl),
                    ),

                  // Destination marker
                  Marker(
                    point: dest,
                    width: 120,
                    height: 72,
                    alignment: Alignment.bottomCenter,
                    child: _DestMarker(
                      label: widget.label,
                      color: _pin,
                    ),
                  ),
                ],
              ),

              // Attribution
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution('© CartoDB'),
                  TextSourceAttribution('© OpenStreetMap contributors'),
                  TextSourceAttribution('Routing: OSRM'),
                ],
              ),
            ],
          ),

          // ── Top AppBar overlay ────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      _GlassBtn(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(blurRadius: 4, color: Colors.black54)
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.subtitle != null)
                              Text(
                                widget.subtitle!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  shadows: [
                                    Shadow(blurRadius: 4, color: Colors.black54)
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_loadingRoute || _loadingLoc)
                        Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(right: 8),
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Right FABs ────────────────────────────────────────────────────
          Positioned(
            right: 12,
            bottom: 220,
            child: Column(
              children: [
                _GlassBtn(
                  icon: Icons.add,
                  onTap: () {
                    if (_disposed) return;
                    final cur = _mapCtrl.camera.zoom;
                    _mapCtrl.move(
                        _mapCtrl.camera.center, math.min(cur + 1, 19));
                  },
                ),
                const SizedBox(height: 8),
                _GlassBtn(
                  icon: Icons.remove,
                  onTap: () {
                    if (_disposed) return;
                    final cur = _mapCtrl.camera.zoom;
                    _mapCtrl.move(_mapCtrl.camera.center, math.max(cur - 1, 3));
                  },
                ),
                const SizedBox(height: 8),
                _GlassBtn(
                  icon: Icons.my_location,
                  onTap: () {
                    if (_disposed) return;
                    if (_userLoc != null) {
                      _mapCtrl.move(_userLoc!, 15);
                    } else {
                      _fetchUserLocation();
                    }
                  },
                ),
                const SizedBox(height: 8),
                _GlassBtn(
                  icon: Icons.location_pin,
                  color: _pin,
                  onTap: () {
                    if (_disposed) return;
                    _mapCtrl.move(dest, 16);
                  },
                ),
              ],
            ),
          ),

          // ── Bottom info card ──────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomCard(
              label: widget.label,
              subtitle: widget.subtitle,
              address: _address,
              distanceKm: _distanceKm,
              etaMin: _etaMin,
              pin: _pin,
              lat: widget.latitude,
              lng: widget.longitude,
              hasRoute: _showRoute,
              onRouteToggle: _userLoc == null
                  ? _fetchUserLocation
                  : () {
                      if (_disposed) return;
                      if (_showRoute) {
                        _setState(() => _showRoute = false);
                      } else {
                        if (_routePoints.isNotEmpty) {
                          _setState(() => _showRoute = true);
                          _fitBounds(_userLoc!,
                              LatLng(widget.latitude, widget.longitude));
                        } else {
                          _fetchRoute();
                        }
                      }
                    },
              isLoadingRoute: _loadingRoute || _loadingLoc,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

// Animated pulsing user location dot
class _UserMarker extends StatelessWidget {
  final AnimationController pulseCtrl;
  const _UserMarker({required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (_, __) {
        final pulse = (math.sin(pulseCtrl.value * 2 * math.pi) + 1) / 2;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 36 + pulse * 12,
              height: 36 + pulse * 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.15 + pulse * 0.1),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade600,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// Destination pin with label bubble
class _DestMarker extends StatelessWidget {
  final String label;
  final Color color;
  const _DestMarker({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 2),
        Icon(Icons.location_pin, color: color, size: 34),
      ],
    );
  }
}

// Frosted-glass circular button
class _GlassBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _GlassBtn({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: color ?? Colors.black87),
      ),
    );
  }
}

// Bottom info card with address, distance, ETA, route toggle
class _BottomCard extends StatelessWidget {
  final String label;
  final String? subtitle;
  final String address;
  final double? distanceKm;
  final int? etaMin;
  final Color pin;
  final double lat;
  final double lng;
  final bool hasRoute;
  final bool isLoadingRoute;
  final VoidCallback onRouteToggle;

  const _BottomCard({
    required this.label,
    this.subtitle,
    required this.address,
    this.distanceKm,
    this.etaMin,
    required this.pin,
    required this.lat,
    required this.lng,
    required this.hasRoute,
    required this.isLoadingRoute,
    required this.onRouteToggle,
  });

  String _fmt(double km) =>
      km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pin icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: pin.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.location_pin, color: pin, size: 22),
                ),
                const SizedBox(width: 12),
                // Label + address
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(fontSize: 12, color: pin),
                        ),
                      const SizedBox(height: 3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.place_outlined,
                              size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              address,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Distance + ETA chips
          if (distanceKm != null || etaMin != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  if (distanceKm != null)
                    _Chip(
                      icon: Icons.straighten,
                      label: _fmt(distanceKm!),
                      color: pin,
                    ),
                  if (distanceKm != null && etaMin != null)
                    const SizedBox(width: 10),
                  if (etaMin != null)
                    _Chip(
                      icon: Icons.access_time,
                      label: etaMin! < 60
                          ? '$etaMin min'
                          : '${etaMin! ~/ 60}h ${etaMin! % 60}m',
                      color: Colors.green.shade700,
                    ),
                ],
              ),
            ),

          // Route toggle button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: isLoadingRoute ? null : onRouteToggle,
                icon: isLoadingRoute
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Icon(
                        hasRoute ? Icons.route : Icons.directions,
                        size: 20,
                      ),
                label: Text(
                  isLoadingRoute
                      ? 'Getting route…'
                      : hasRoute
                          ? 'Hide Route'
                          : 'Show Route',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pin,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: pin.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
