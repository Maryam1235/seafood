import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/notification_service.dart';
import 'orders_screen.dart';

class DeliverySelectionScreen extends StatefulWidget {
  final String orderId;
  final double orderTotal;

  const DeliverySelectionScreen({
    super.key,
    required this.orderId,
    required this.orderTotal,
  });

  @override
  State<DeliverySelectionScreen> createState() =>
      _DeliverySelectionScreenState();
}

class _DeliverySelectionScreenState extends State<DeliverySelectionScreen> {
  static const _navy = Color(0xFF1E1B4B);
  static const _indigo = Color(0xFF3730A3);

  String? _selectedDriverId;
  bool _isLoading = false;
  Map<String, dynamic>? _customerLocation;

  @override
  void initState() {
    super.initState();
    _loadCustomerLocation();
  }

  Future<void> _loadCustomerLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists && mounted) {
      setState(
        () => _customerLocation =
            doc.data()?['location'] as Map<String, dynamic>?,
      );
    }
  }

  // Haversine formula - distance in km
  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double deg) => deg * pi / 180;

  // Rate per km by vehicle type (TShs)
  double _ratePerKm(String v) {
    switch (v.toLowerCase()) {
      case 'bicycle':
        return 300;
      case 'motorcycle':
        return 500;
      case 'car':
        return 800;
      default:
        return 1200; // pickup
    }
  }

  // Minimum cost by vehicle type
  double _minCost(String v) {
    switch (v.toLowerCase()) {
      case 'bicycle':
        return 1000;
      case 'motorcycle':
        return 2000;
      case 'car':
        return 4000;
      default:
        return 6000;
    }
  }

  // Calculate cost based on distance
  double _calcCost(String vehicleType, Map<String, dynamic>? driverLoc) {
    if (_customerLocation == null || driverLoc == null) {
      return _minCost(vehicleType);
    }
    final cLat = (_customerLocation!['latitude'] as num).toDouble();
    final cLon = (_customerLocation!['longitude'] as num).toDouble();
    final dLat = (driverLoc['latitude'] as num?)?.toDouble();
    final dLon = (driverLoc['longitude'] as num?)?.toDouble();
    if (dLat == null || dLon == null) return _minCost(vehicleType);
    final dist = _distanceKm(cLat, cLon, dLat, dLon);
    final cost = dist * _ratePerKm(vehicleType);
    final rounded = (cost / 100).ceil() * 100.0;
    return rounded < _minCost(vehicleType) ? _minCost(vehicleType) : rounded;
  }

  String _distLabel(Map<String, dynamic>? driverLoc) {
    if (_customerLocation == null || driverLoc == null) return '';
    final cLat = (_customerLocation!['latitude'] as num).toDouble();
    final cLon = (_customerLocation!['longitude'] as num).toDouble();
    final dLat = (driverLoc['latitude'] as num?)?.toDouble();
    final dLon = (driverLoc['longitude'] as num?)?.toDouble();
    if (dLat == null || dLon == null) return '';
    final dist = _distanceKm(cLat, cLon, dLat, dLon);
    return '${dist.toStringAsFixed(1)} km';
  }

  String _vehicleIcon(String v) {
    switch (v.toLowerCase()) {
      case 'bicycle':
        return '�';
      case 'motorcycle':
        return '🏍️';
      case 'car':
        return '�';
      default:
        return '�';
    }
  }

  Future<void> _confirm(Map<String, dynamic> driver, double cost) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
            'delivery': {
              'vehicleType': driver['driverProfile']?['vehicleType'],
              'cost': cost,
              'driverId': _selectedDriverId,
              'driverName': driver['fullName'] ?? driver['username'],
              'driverPhone': driver['phone'],
              'status': 'assigned',
              'requestedAt': FieldValue.serverTimestamp(),
            },
            'grandTotal': widget.orderTotal + cost,
            'status': 'confirmed',
          });

      // Send notification to driver
      final customerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .get();
      final customerName =
          customerDoc.data()?['fullName'] ??
          customerDoc.data()?['username'] ??
          'Customer';

      await NotificationService.sendDeliveryNotification(
        driverId: _selectedDriverId!,
        orderId: widget.orderId,
        customerName: customerName,
        orderTotal: (widget.orderTotal + cost).toStringAsFixed(0),
        vehicleType: driver['driverProfile']?['vehicleType'] ?? '',
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OrdersScreen()),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Driver assigned! Your order is on the way.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_navy, _indigo],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.local_shipping_outlined,
                          color: Colors.white70,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lang.isSwahili ? 'Chagua Dereva' : 'Choose a Driver',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          lang.isSwahili
                              ? 'Bei inakokotolewa kulingana na umbali wako'
                              : 'Cost calculated based on your distance',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order subtotal card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.shade200, blurRadius: 6),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.isSwahili
                                  ? 'Jumla ya Bidhaa'
                                  : 'Order Subtotal',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              'TShs ${widget.orderTotal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _navy,
                              ),
                            ),
                          ],
                        ),
                        if (_customerLocation != null)
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.green.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _customerLocation!['name'] ?? 'Located',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    lang.isSwahili
                        ? 'Madereva Wanaopatikana'
                        : 'Available Drivers',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Drivers list
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'driver')
                        .where('driverProfile.status', isEqualTo: 'approved')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.delivery_dining,
                                  size: 60,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  lang.isSwahili
                                      ? 'Hakuna madereva sasa'
                                      : 'No drivers available right now',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 15,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: snapshot.data!.docs.map((doc) {
                          final driver = doc.data() as Map<String, dynamic>;
                          final profile =
                              driver['driverProfile'] as Map<String, dynamic>?;
                          final driverLoc =
                              driver['location'] as Map<String, dynamic>?;
                          final vehicle = profile?['vehicleType'] ?? 'Unknown';
                          final cost = _calcCost(vehicle, driverLoc);
                          final dist = _distLabel(driverLoc);
                          final selected = _selectedDriverId == doc.id;

                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedDriverId = doc.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? _navy
                                      : Colors.grey.shade200,
                                  width: selected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.shade200,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: selected
                                        ? _navy
                                        : Colors.grey.shade100,
                                    child: Text(
                                      (driver['username'] ?? '?')
                                          .toString()
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: selected ? Colors.white : _navy,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          driver['fullName'] ??
                                              driver['username'] ??
                                              '',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: selected
                                                ? _navy
                                                : const Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Text(
                                              _vehicleIcon(vehicle),
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              vehicle,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            if (dist.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.location_on,
                                                size: 12,
                                                color: Colors.orange.shade400,
                                              ),
                                              Text(
                                                dist,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.orange.shade600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.phone_outlined,
                                              size: 13,
                                              color: Colors.grey.shade500,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              driver['phone'] ?? 'N/A',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (profile?['licensePlate'] !=
                                            null) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons
                                                    .confirmation_number_outlined,
                                                size: 13,
                                                color: Colors.grey.shade500,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                profile!['licensePlate'],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'TShs ${cost.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: selected
                                              ? _navy
                                              : const Color(0xFF111827),
                                        ),
                                      ),
                                      Text(
                                        lang.isSwahili ? 'Utoaji' : 'Delivery',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: selected
                                                ? _navy
                                                : Colors.grey.shade300,
                                            width: 2,
                                          ),
                                          color: selected
                                              ? _navy
                                              : Colors.transparent,
                                        ),
                                        child: selected
                                            ? const Icon(
                                                Icons.check,
                                                size: 14,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // Grand total + confirm
                  if (_selectedDriverId != null)
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(_selectedDriverId)
                          .get(),
                      builder: (context, snap) {
                        if (!snap.hasData) return const SizedBox();
                        final driver =
                            snap.data!.data() as Map<String, dynamic>?;
                        final profile =
                            driver?['driverProfile'] as Map<String, dynamic>?;
                        final driverLoc =
                            driver?['location'] as Map<String, dynamic>?;
                        final vehicle = profile?['vehicleType'] ?? '';
                        final cost = _calcCost(vehicle, driverLoc);

                        return Column(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _navy.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _navy.withOpacity(0.1),
                                ),
                              ),
                              child: Column(
                                children: [
                                  _row(
                                    lang.isSwahili ? 'Bidhaa' : 'Products',
                                    'TShs ${widget.orderTotal.toStringAsFixed(0)}',
                                  ),
                                  const SizedBox(height: 8),
                                  _row(
                                    lang.isSwahili ? 'Utoaji' : 'Delivery',
                                    'TShs ${cost.toStringAsFixed(0)}',
                                  ),
                                  const Divider(height: 20),
                                  _row(
                                    lang.isSwahili
                                        ? 'Jumla Yote'
                                        : 'Grand Total',
                                    'TShs ${(widget.orderTotal + cost).toStringAsFixed(0)}',
                                    bold: true,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : () => _confirm(driver ?? {}, cost),
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.check_circle_outline),
                                label: Text(
                                  lang.isSwahili
                                      ? 'Thibitisha Utoaji'
                                      : 'Confirm Delivery',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _navy,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 15 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: bold ? _navy : Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: _navy,
          ),
        ),
      ],
    );
  }
}
