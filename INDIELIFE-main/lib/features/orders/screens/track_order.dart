import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hello/core/services/api_service.dart';
import 'package:hello/shared/widgets/review_sheet.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class TrackOrderScreen extends StatefulWidget {
  const TrackOrderScreen({super.key});

  @override
  _TrackOrderScreenState createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  dynamic _activeOrder;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _refreshTimer = Timer.periodic(
      Duration(seconds: 15),
      (_) => _fetchOrders(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrders({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      // Fetch service orders
      final orderResult = await ApiService.getCustomerOrders(
        limit: 100,
        page: 1,
      );

      // Fetch housing bookings
      final housingResult = await ApiService.getCustomerHousingBookings();

      print("Fetched service orders: ${orderResult['orders']?.length ?? 0}");
      print(
        "Fetched housing bookings: ${housingResult['bookings']?.length ?? 0}",
      );

      if (mounted) {
        // Combine both lists
        List<dynamic> allOrders = [];

        if (orderResult['orders'] != null) {
          // Add booking type to service orders
          allOrders.addAll(
            (orderResult['orders'] as List).map((o) {
              return {...o, 'bookingType': 'service'};
            }),
          );
        }

        if (housingResult['bookings'] != null) {
          allOrders.addAll(housingResult['bookings'] as List);
        }

        // Sort by creation date (most recent first)
        allOrders.sort((a, b) {
          final dateA =
              DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
              DateTime.now();
          final dateB =
              DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
              DateTime.now();
          return dateB.compareTo(dateA);
        });

        setState(() {
          _orders = allOrders;
          // Consider the most recent non-completed order as active
          _activeOrder = _orders.firstWhere(
            (o) => ![
              'delivered',
              'completed',
              'cancelled',
            ].contains(o['status']?.toString().toLowerCase()),
            orElse: () =>
                null, // Don't show any active order if all are completed
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching orders: $e");
      if (mounted) {
        if (!silent) setState(() => _isLoading = false);
        if (!silent) _showErrorSnackBar('Failed to load orders.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FB),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFFFF9D42)))
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      if (_activeOrder != null)
                        _buildActiveTrackingSection(_activeOrder),
                      _buildHistorySection(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 150, // Shorter height without icons
      pinned: true,
      elevation: 0,
      backgroundColor: Color(0xFFFF9D42),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(background: ShortcutGradientBackground()),
    );
  }

  Widget ShortcutGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF9D42), Color(0xFFFF6B6B)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(
            "Track Order",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 26,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
        ),
      ),
    );
  }

  Widget _buildActiveTrackingSection(dynamic order) {
    String status = order['status'] ?? 'Pending';
    bool isCompleted = [
      'delivered',
      'completed',
    ].contains(status.toLowerCase());

    final isHousing = order['bookingType'] == 'housing';
    final displayName = isHousing
        ? (order['propertyTitle'] ?? 'Housing Booking')
        : (order['providerName'] ?? 'Service Provider');

    return Container(
      margin: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isHousing ? "🏠" : "🛒",
                              style: TextStyle(fontSize: 14),
                            ),
                            SizedBox(width: 6),
                            Text(
                              isHousing
                                  ? "Booking #${order['bookingNumber']?.toString().substring(0, 8).toUpperCase()}"
                                  : "Order #${order['_id']?.toString().substring(0, 8).toUpperCase()}",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          displayName,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    _badge(status.toUpperCase(), _getStatusColor(status)),
                  ],
                ),
                SizedBox(height: 32),

                // Timeline (only for service orders, not housing)
                if (!isHousing)
                  Column(
                    children: [_buildTimeline(order), SizedBox(height: 32)],
                  ),

                Divider(color: Colors.grey[100]),
                SizedBox(height: 20),

                // Order Details Expansion
                _buildOrderDetailsPreview(order),

                SizedBox(height: 28),

                // Action Buttons
                Row(
                  children: [
                    if (order['phone'] != null &&
                        order['phone'].toString().length > 5) ...[
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => _handleCall(order['phone']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.withOpacity(0.1),
                            foregroundColor: Colors.green,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Icon(Icons.phone_rounded, size: 20),
                        ),
                      ),
                      SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openChat(order),
                        icon: Icon(Icons.chat_bubble_rounded, size: 18),
                        label: Text("Message"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFFF9D42).withOpacity(0.1),
                          foregroundColor: Color(0xFFFF9D42),
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    if (isCompleted &&
                        (order['rating'] == null || order['rating'] == 0)) ...[
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showReviewSheet(order),
                          icon: Icon(Icons.star_rounded, size: 18),
                          label: Text("Rate"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildTimeline(dynamic order) {
    String status = (order['status'] ?? 'Pending').toLowerCase();
    bool isHousing = (order['orderType'] == 'hire_request');

    List<Map<String, dynamic>> steps = isHousing
        ? [
            {
              't': 'Request Sent',
              's': 'Waiting for confirmation',
              'done': true,
            },
            {
              't': 'Visit Scheduled',
              's': 'Host confirmed',
              'done': [
                'confirmed',
                'visit scheduled',
                'completed',
                'delivered',
              ].contains(status),
            },
            {
              't': 'Visit Completed',
              's': 'Service finalized',
              'done': ['completed', 'delivered'].contains(status),
            },
          ]
        : [
            {'t': 'Order Placed', 's': 'We received your order', 'done': true},
            {
              't': 'Preparing',
              's': 'Expert is working on it',
              'done': [
                'preparing',
                'ready for delivery',
                'out for delivery',
                'delivered',
                'completed',
              ].contains(status),
            },
            {
              't': 'On the Way',
              's': 'Arriving at your location',
              'done': [
                'out for delivery',
                'delivered',
                'completed',
              ].contains(status),
            },
            {
              't': 'Delivered',
              's': 'Service completed',
              'done': ['delivered', 'completed'].contains(status),
            },
          ];

    return Column(
      children: List.generate(steps.length, (index) {
        bool isLast = index == steps.length - 1;
        bool isDone = steps[index]['done'];
        bool isCurrent = isDone && (isLast || !steps[index + 1]['done']);

        return IntrinsicHeight(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? (isCurrent ? Color(0xFFFF9D42) : Colors.green)
                          : Colors.grey[200],
                    ),
                    child:
                        Icon(
                              isDone
                                  ? (isCurrent
                                        ? Icons.sync_rounded
                                        : Icons.check)
                                  : Icons.circle,
                              size: isDone ? 14 : 6,
                              color: isDone ? Colors.white : Colors.grey[400],
                            )
                            .animate(
                              onPlay: (controller) => controller.repeat(),
                            )
                            .rotate(duration: 2000.ms),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: EdgeInsets.symmetric(vertical: 4),
                        color: isDone && !isCurrent && steps[index + 1]['done']
                            ? Colors.green
                            : Colors.grey[100],
                      ),
                    ),
                ],
              ),
              SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[index]['t'],
                        style: GoogleFonts.inter(
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isDone ? Colors.black87 : Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        steps[index]['s'],
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDone ? Colors.grey[600] : Colors.grey[300],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildOrderDetailsPreview(dynamic order) {
    List items = order['items'] ?? [];
    final bool isHousing = order['bookingType'] == 'housing';

    // Extract provider/owner details
    String? providerName;
    String? providerEmail;
    String? providerPhone;
    String? providerCity;

    if (isHousing) {
      // For housing bookings, extract from populated ownerId
      final owner = order['ownerId'] ?? {};
      if (owner is Map) {
        providerName = '${owner['firstName'] ?? ''} ${owner['lastName'] ?? ''}'
            .trim();
        providerEmail = owner['email'];
        providerPhone = owner['phone'];
        providerCity = owner['city'];
      }
      // Fallback to ownerName if available
      if (providerName == null || providerName.isEmpty) {
        providerName = order['ownerName'] ?? 'Property Owner';
      }
    } else {
      // For service orders, extract from available provider fields
      if (order['providerName'] != null &&
          order['providerName'].toString().isNotEmpty) {
        providerName = order['providerName'];
      } else if (order['serviceProviderSpId'] is Map) {
        final sp = order['serviceProviderSpId'];
        providerName = '${sp['firstName'] ?? ''} ${sp['lastName'] ?? ''}'
            .trim();
        providerEmail = sp['email'];
        providerPhone = sp['phone'];
      } else if (order['serviceProviderId'] is Map) {
        final sp = order['serviceProviderId'];
        providerName = '${sp['firstName'] ?? ''} ${sp['lastName'] ?? ''}'
            .trim();
        providerEmail = sp['email'];
        providerPhone = sp['phone'];
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Service Provider / Owner Details Section
        if (providerName != null && providerName.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                isHousing ? Icons.home_outlined : Icons.person_outline,
                size: 16,
                color: Colors.grey,
              ),
              SizedBox(width: 8),
              Text(
                isHousing ? "Property Owner" : "Service Provider",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  providerName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                if (providerEmail != null && providerEmail.isNotEmpty) ...[
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 13, color: Colors.grey),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          providerEmail,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (providerPhone != null && providerPhone.isNotEmpty) ...[
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 13, color: Colors.grey),
                      SizedBox(width: 6),
                      Text(
                        providerPhone,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
                if (providerCity != null && providerCity.isNotEmpty) ...[
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_city_outlined,
                        size: 13,
                        color: Colors.grey,
                      ),
                      SizedBox(width: 6),
                      Text(
                        providerCity,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
        // Order Summary / Items Section (only for service orders)
        if (!isHousing && items.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                "Order Summary",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${item['quantity']}x ${item['name'] ?? item['serviceName']}",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    "PKR ${item['price'] ?? item['totalPrice']}",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        // Housing Booking Details
        if (isHousing) ...[
          if (order['propertyTitle'] != null) ...[
            Row(
              children: [
                Icon(Icons.apartment_outlined, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order['propertyTitle'],
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
          ],
          if (order['monthlyRent'] != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Monthly Rent",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  "PKR ${order['monthlyRent']}",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFFFF9D42),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
          ],
          if (order['address'] != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order['address'],
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
          ],
        ],
        // Total Amount Section (for service orders)
        if (!isHousing && order['totalAmount'] != null) ...[
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total Amount",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                "PKR ${order['totalAmount']}",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFFFF9D42),
                ),
              ),
            ],
          ),
        ],
        // Delivery Address (for service orders)
        if (!isHousing && order['deliveryAddress'] != null) ...[
          SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  order['deliveryAddress'],
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
        // Dates Section
        if (order['pickupDate'] != null || order['deliveryDate'] != null) ...[
          SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.event_available, size: 16, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (order['pickupDate'] != null)
                      Text(
                        "Pickup: ${DateFormat('MMM dd').format(DateTime.parse(order['pickupDate'].toString()))} at ${order['pickupTime'] ?? ''}",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    if (order['deliveryDate'] != null)
                      Text(
                        "Delivery: ${DateFormat('MMM dd').format(DateTime.parse(order['deliveryDate'].toString()))} at ${order['deliveryTime'] ?? ''}",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildHistorySection() {
    // Filter to show only active (non-completed) orders
    final activeOrders = _orders.where((order) {
      final status = order['status']?.toString().toLowerCase() ?? '';
      return !['delivered', 'completed', 'cancelled'].contains(status);
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Active Orders",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${activeOrders.length} active",
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (activeOrders.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 80,
                      color: Colors.grey[200],
                    ),
                    SizedBox(height: 16),
                    Text(
                      "No active orders",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: activeOrders.length,
              itemBuilder: (context, index) =>
                  _historyItem(activeOrders[index], index),
            ),
          SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _historyItem(dynamic order, int index) {
    // Extract provider name with multiple fallbacks
    String provider = 'Service Provider';
    final isHousing = order['bookingType'] == 'housing';

    if (isHousing) {
      provider = order['ownerName'] ?? 'Property Owner';
    } else if (order['providerName'] != null &&
        order['providerName'].toString().isNotEmpty) {
      provider = order['providerName'];
    } else if (order['serviceProviderSpId'] is Map) {
      provider = order['serviceProviderSpId']['firstName'] ?? 'Provider';
    } else if (order['serviceProviderId'] is Map) {
      final spId = order['serviceProviderId'];
      provider = '${spId['firstName'] ?? ''} ${spId['lastName'] ?? ''}'.trim();
      if (provider.isEmpty) provider = 'Service Provider';
    } else if (order['serviceName'] != null) {
      provider = order['serviceName'];
    }

    DateTime? date = order['createdAt'] != null
        ? DateTime.parse(order['createdAt'])
        : null;
    String status = order['status'] ?? 'Completed';
    bool isCompleted = [
      'delivered',
      'completed',
    ].contains(status.toLowerCase());

    return GestureDetector(
      onTap: () => _showOrderDetailsSheet(order),
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey[50]!),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isHousing
                    ? Icons.home_outlined
                    : (order['orderType'] == 'hire_request'
                          ? Icons.handyman_outlined
                          : Icons.restaurant_rounded),
                color: Colors.grey[400],
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isHousing ? "🏠" : "🛒",
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isHousing
                              ? (order['propertyTitle'] ?? provider)
                              : provider,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        date != null
                            ? DateFormat.yMMMd().format(date)
                            : "Recent",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Container(
                        width: 4,
                        height: 4,
                        margin: EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        "PKR ${order['totalAmount'] ?? '0'}",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF9D42),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _badge(status.toUpperCase(), _getStatusColor(status)),
                if (isCompleted) ...[
                  SizedBox(height: 8),
                  if (order['rating'] != null && order['rating'] > 0)
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          Icons.star_rounded,
                          size: 10,
                          color: i < (order['rating'] as num)
                              ? Colors.amber
                              : Colors.grey[100],
                        ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () => _showReviewSheet(order),
                      child: Text(
                        "Rate & Review",
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Color(0xFFFF9D42),
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.05, end: 0);
  }

  void _showOrderDetailsSheet(dynamic order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Order details",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _badge(
                  order['status']?.toString().toUpperCase() ?? "PENDING",
                  _getStatusColor(order['status'] ?? ""),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              "Order ID: #${order['_id']?.toString().toUpperCase()}",
              style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
            ),
            SizedBox(height: 32),
            _buildOrderDetailsPreview(order),
            Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  "Close",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _openChat(dynamic order) async {
    print("Opening chat for order: $order");

    // Try multiple fields for providerId (we need the ServiceProvider ID for chat)
    String? providerId;

    // Check serviceProviderSpId FIRST as chat system uses SP model for providers
    if (order['serviceProviderSpId'] != null) {
      providerId = order['serviceProviderSpId'] is Map
          ? order['serviceProviderSpId']['_id']?.toString()
          : order['serviceProviderSpId'].toString();
    }

    // Fallback to serviceProviderId
    if (providerId == null || providerId.length < 5) {
      if (order['serviceProviderId'] != null) {
        providerId = order['serviceProviderId'] is Map
            ? order['serviceProviderId']['_id']?.toString()
            : order['serviceProviderId'].toString();
      }
    }

    // Last ditch fallback: some orders might have it nested under items or providerId directly
    if (providerId == null || providerId.length < 5) {
      providerId = order['providerId']?.toString();
    }

    final providerName = order['providerName'] ?? 'Provider';

    // Extract serviceId and serviceName
    String? serviceId;
    String serviceName = 'Service';
    if ((order['items'] as List?)?.isNotEmpty == true) {
      serviceId = order['items'][0]['serviceId']?.toString();
      serviceName = order['items'][0]['serviceName'] ?? 'Service';
    }

    // If still no serviceId, use providerId as a fallback for chat starting
    serviceId ??= providerId;

    if (providerId == null) {
      print("Error: providerId is null. Order keys: ${order.keys}");
      _showErrorSnackBar("Provider information missing");
      return;
    }

    try {
      final result = await ApiService.startChat(
        providerId,
        serviceId ?? providerId,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        Navigator.pushNamed(
          context,
          '/chat',
          arguments: {
            'chatId': result['chat']['_id'],
            'otherUserName': providerName,
            'serviceName': serviceName,
            'receiverId': providerId,
          },
        );
      } else {
        _showErrorSnackBar(result['message'] ?? "Could not start chat");
      }
    } catch (e) {
      print("TrackOrder chat error: $e");
      if (mounted) _showErrorSnackBar("Connection failed: $e");
    }
  }

  void _handleCall(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else if (mounted) {
        _showErrorSnackBar("Could not open dialer for $phone");
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar("Could not open dialer: $e");
    }
  }

  void _showReviewSheet(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReviewSheet(
        order: order,
        onReviewSubmitted: (review) => _fetchOrders(),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'shipped':
      case 'out for delivery':
        return Colors.blue;
      case 'processing':
      case 'preparing':
        return Colors.orange;
      case 'pending':
        return Colors.amber;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _badge(String t, Color c) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: c.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      t,
      style: GoogleFonts.inter(
        fontSize: 9,
        fontWeight: FontWeight.bold,
        color: c,
      ),
    ),
  );

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(24),
      ),
    );
  }
}
