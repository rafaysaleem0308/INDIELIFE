import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hello/core/services/api_service.dart';
import 'package:hello/core/services/chat_service.dart';
import 'package:hello/features/profile/screens/profile.dart';
import 'package:hello/features/services/screens/add_meal_service.dart';

class MealProviderHome extends StatefulWidget {
  const MealProviderHome({super.key});

  @override
  _MealProviderHomeState createState() => _MealProviderHomeState();
}

class _MealProviderHomeState extends State<MealProviderHome>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? userData;
  int _currentIndex = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _orders = [];
  Map<String, dynamic> _stats = {};
  bool _isAvailable = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    ChatService.init();
    _loadAllData();
    _refreshTimer = Timer.periodic(
      Duration(seconds: 15),
      (_) => _silentRefresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadUserData(), _loadServices(), _loadOrders()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _silentRefresh() async {
    if (!mounted) return;
    await Future.wait([_loadUserData(), _loadServices(), _loadOrders()]);
  }

  Future<void> _loadUserData() async {
    try {
      userData = await ApiService.getUserData();
      if (mounted && userData != null) {
        setState(() => _isAvailable = userData?['isAvailable'] ?? true);
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _loadServices() async {
    try {
      final s = await ApiService.getServices();
      if (mounted) {
        setState(() => _services = s.cast<Map<String, dynamic>>());
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _loadOrders() async {
    try {
      final ordersResult = await ApiService.getProviderOrders();
      final statsResult = await ApiService.getProviderOrderStats();
      if (mounted && ordersResult['success'] == true) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(
            ordersResult['orders'] ?? [],
          );
          _stats = Map<String, dynamic>.from(statsResult['stats'] ?? {});
        });
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      extendBody: true,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF9D42)),
            )
          : SafeArea(child: _buildBody()),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildServices();
      case 2:
        return _buildAnalytics();
      case 3:
        return _buildWalletSection();
      default:
        return Container();
    }
  }

  // ─── DASHBOARD ───
  Widget _buildDashboard() {
    final requests = _orders
        .where((o) => (o['status'] ?? 'Pending') == 'Pending')
        .toList();
    final active = _orders
        .where(
          (o) => [
            'Confirmed',
            'Preparing',
            'Ready for Delivery',
            'Out for Delivery',
          ].contains(o['status']),
        )
        .toList();
    final history = _orders
        .where(
          (o) => [
            'Delivered',
            'Completed',
            'Cancelled',
            'Rejected',
          ].contains(o['status']),
        )
        .toList();

    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverToBoxAdapter(child: _buildTopBar()),
          SliverToBoxAdapter(child: _buildWelcomeHeader()),
          SliverToBoxAdapter(child: _buildQuickStats()),
        ],
        body: Column(
          children: [
            TabBar(
              labelColor: const Color(0xFFFF9D42),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFFFF9D42),
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              tabs: [
                Tab(text: "New (${requests.length})"),
                Tab(text: "Active (${active.length})"),
                Tab(text: "History (${history.length})"),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildOrderList(requests, isRequest: true),
                  _buildOrderList(active, isActive: true),
                  _buildOrderList(history),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Meal Partner",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "Manage your kitchen & orders",
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const Spacer(),
          // Online/Offline toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isAvailable
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isAvailable ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _isAvailable ? "Online" : "Offline",
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _isAvailable ? Colors.green : Colors.red,
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _isAvailable,
                    activeThumbColor: Colors.green,
                    inactiveThumbColor: Colors.red,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) async {
                      final res = await ApiService.updateAvailability(v);
                      if (res['success']) setState(() => _isAvailable = v);
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 32,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.forum_outlined,
                color: Color(0xFFFF9D42),
                size: 20,
              ),
              onPressed: () => Navigator.pushNamed(context, '/my-chats'),
            ),
          ),
          SizedBox(
            width: 32,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.notifications_outlined,
                color: Color(0xFFFF9D42),
                size: 20,
              ),
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final isVerified = userData?['isVerified'] ?? false;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9D42), Color(0xFFFF512F)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9D42).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: const Icon(
                  Icons.restaurant_menu_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              if (isVerified)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello, ${userData?['username'] ?? ''}",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  "Master Chef • ${userData?['city'] ?? 'Active'}",
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              "Today's Earnings",
              "PKR ${_stats['todayEarnings'] ?? 0}",
              Icons.account_balance_wallet_outlined,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              "Pending",
              "${_stats['pendingOrders'] ?? 0}",
              Icons.pending_actions,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              "Total",
              "${_stats['totalOrders'] ?? 0}",
              Icons.shopping_bag_outlined,
              Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ─── ORDERS LIST ───
  Widget _buildOrderList(
    List<Map<String, dynamic>> orders, {
    bool isRequest = false,
    bool isActive = false,
  }) {
    if (orders.isEmpty) return _buildEmpty("No orders here", Icons.flatware);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (ctx, i) =>
          _orderCard(orders[i], isRequest: isRequest, isActive: isActive),
    );
  }

  Widget _orderCard(
    Map<String, dynamic> o, {
    bool isRequest = false,
    bool isActive = false,
  }) {
    final status = o['status'] ?? 'Pending';
    Color sCol = status == 'Delivered' || status == 'Completed'
        ? Colors.green
        : (status == 'Pending' ? Colors.orange : Colors.deepOrangeAccent);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: sCol.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lunch_dining_outlined, color: sCol, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Order #${o['orderNumber']?.toString().substring(0, 8) ?? o['_id']?.toString().substring(0, 6).toUpperCase()}",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      o['createdAt'] != null
                          ? o['createdAt'].toString().substring(0, 10)
                          : 'Just now',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (o['customerId'] != null)
                IconButton(
                  icon: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: const Color(0xFFFF9D42),
                    size: 20,
                  ),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/chat',
                    arguments: {
                      'receiverId': o['customerId'] is Map
                          ? o['customerId']['_id']
                          : o['customerId'],
                      'otherUserName': o['name'] ?? 'Customer',
                      'serviceName': 'Meal Order',
                      'serviceId':
                          (o['items'] != null &&
                              (o['items'] as List).isNotEmpty)
                          ? o['items'][0]['serviceId']
                          : "",
                    },
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: sCol.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: sCol,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _detailRow(Icons.person_outline, "Customer", o['name'] ?? 'Guest'),
          if (o['deliveryAddress'] != null)
            _detailRow(
              Icons.location_on_outlined,
              "Address",
              o['deliveryAddress'],
            ),
          const Divider(height: 20),
          Text(
            "Items",
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          ...(o['items'] as List? ?? []).map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "${item['quantity'] ?? 1}x",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item['serviceName'] ?? 'Item',
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ),
                  Text(
                    "PKR ${item['totalPrice'] ?? 0}",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Total
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              Text(
                "PKR ${o['totalAmount'] ?? 0}",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          if (isRequest) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateStatus(o['_id'], 'Rejected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text("Decline"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateStatus(o['_id'], 'Confirmed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Accept"),
                  ),
                ),
              ],
            ),
          ] else if (isActive) ...[
            const SizedBox(height: 14),
            _buildStatusButton(o),
          ],
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.05, end: 0);
  }

  Widget _buildStatusButton(Map<String, dynamic> o) {
    final s = o['status'];
    if (s == 'Confirmed') {
      return _fullBtn(
        "Start Cooking",
        Colors.blue,
        () => _updateStatus(o['_id'], 'Preparing'),
      );
    }
    if (s == 'Preparing') {
      return _fullBtn(
        "Ready for Pickup",
        Colors.orange,
        () => _updateStatus(o['_id'], 'Ready for Delivery'),
      );
    }
    if (s == 'Ready for Delivery') {
      return _fullBtn(
        "Out for Delivery",
        Colors.purple,
        () => _updateStatus(o['_id'], 'Out for Delivery'),
      );
    }
    if (s == 'Out for Delivery') {
      return _fullBtn(
        "Mark Delivered",
        Colors.green,
        () => _updateStatus(o['_id'], 'Delivered'),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _fullBtn(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String orderId, String status) async {
    setState(() => _isLoading = true);
    final result = await ApiService.updateOrderStatus(orderId, status, null);
    if (!mounted) return;
    if (result['success'] == true) {
      await _loadOrders();
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Updated to $status")));
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed: ${result['message']}")));
      }
    }
  }

  // ─── MY MENU ───
  Widget _buildServices() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "My Menu Items",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: Color(0xFFFF9D42),
            ),
            tooltip: "Add Dish",
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddMealServiceForm()),
              );
              if (result == true) _loadServices();
            },
          ),
        ],
      ),
      body: _services.isEmpty
          ? _buildEmpty("No menu items yet", Icons.restaurant_menu)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
              itemCount: _services.length,
              itemBuilder: (ctx, i) {
                final s = _services[i];
                final imageUrl = s['imageUrl'];
                final hasImage =
                    imageUrl != null && imageUrl.toString().isNotEmpty;
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image strip
                      if (hasImage)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          child: Image.network(
                            ApiService.resolveImageUrl(imageUrl),
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            if (!hasImage)
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFF9D42,
                                  ).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.lunch_dining,
                                  color: Color(0xFFFF512F),
                                ),
                              ),
                            if (!hasImage) const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s['serviceName'] ?? 'Item',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "PKR ${s['price']} / ${s['unit']}  •  ${s['mealType'] ?? ''}",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (s['status'] == 'Active'
                                            ? Colors.green
                                            : Colors.grey)
                                        .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                s['status'] ?? 'Active',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: s['status'] == 'Active'
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Edit / Delete row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: Text(
                                  "Edit",
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFFF9D42),
                                  side: const BorderSide(
                                    color: Color(0xFFFF9D42),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddMealServiceForm(
                                        existingService: s,
                                      ),
                                    ),
                                  );
                                  if (result == true) _loadServices();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                ),
                                label: Text(
                                  "Delete",
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => _confirmDelete(s['_id']),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: (i * 50).ms);
              },
            ),
    );
  }

  Future<void> _confirmDelete(String serviceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Delete Dish?",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "This action cannot be undone.",
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Delete",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final result = await ApiService.deleteService(serviceId);
      if (mounted) {
        if (result['success'] == true) {
          _loadServices();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Dish deleted"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? "Failed to delete"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ─── ANALYTICS ───
  Widget _buildAnalytics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Business Analytics",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Track your performance & earnings",
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          _largeStatCard(
            "Total Earnings",
            "PKR ${_stats['totalEarnings'] ?? 0}",
            Icons.payments,
            Colors.green,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _largeStatCard(
                  "Today",
                  "PKR ${_stats['todayEarnings'] ?? 0}",
                  Icons.trending_up,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _largeStatCard(
                  "Orders",
                  "${_stats['totalOrders'] ?? 0}",
                  Icons.shopping_bag,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            "Performance",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _perfRow(
            "Completion Rate",
            "${((_stats['completionRate'] ?? 0) * 100).toStringAsFixed(1)}%",
            Icons.check_circle_outline,
            Colors.teal,
          ),
          _perfRow(
            "Average Rating",
            "${(_stats['averageRating'] ?? 0).toStringAsFixed(1)}",
            Icons.star_outline,
            Colors.amber,
          ),
          _perfRow(
            "Total Orders",
            "${_stats['totalOrders'] ?? 0}",
            Icons.shopping_bag_outlined,
            Colors.indigo,
          ),
          _perfRow(
            "Cancelled",
            "${_stats['cancelledOrders'] ?? 0}",
            Icons.cancel_outlined,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _largeStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: color, size: 22),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _perfRow(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // ─── WALLET ───
  Widget _buildWalletSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Wallet",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Your earnings & transactions",
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          // Balance card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF512F), Color(0xFFFF9D42)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF512F).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Available Balance",
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  "PKR ${_stats['totalEarnings'] ?? 0}",
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("Withdraw"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFFF512F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("History"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 24),
          Text(
            "Quick Stats",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _perfRow(
            "Today's Earnings",
            "PKR ${_stats['todayEarnings'] ?? 0}",
            Icons.today,
            Colors.green,
          ),
          _perfRow(
            "Pending Amount",
            "PKR ${_stats['pendingEarnings'] ?? 0}",
            Icons.hourglass_empty,
            Colors.orange,
          ),
          _perfRow(
            "Total Orders",
            "${_stats['totalOrders'] ?? 0}",
            Icons.shopping_bag_outlined,
            Colors.blue,
          ),
        ],
      ),
    );
  }

  // ─── HELPERS ───
  Widget _buildEmpty(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(msg, style: GoogleFonts.inter(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.dashboard_rounded, "Home", 0),
          _navItem(Icons.restaurant_rounded, "Menu", 1),
          _navItem(Icons.analytics_outlined, "Stats", 2),
          _navItem(Icons.wallet_outlined, "Wallet", 3),
          _navItemProfile(),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int idx) {
    bool sel = _currentIndex == idx;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = idx),
      child: AnimatedContainer(
        duration: 300.ms,
        padding: EdgeInsets.symmetric(horizontal: sel ? 16 : 12, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFFF9D42) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: sel ? Colors.white : Colors.white60, size: 22),
            if (sel) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _navItemProfile() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen()),
      ),
      child: AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.all(10),
        child: const Icon(
          Icons.person_outline,
          color: Colors.white60,
          size: 22,
        ),
      ),
    );
  }
}
