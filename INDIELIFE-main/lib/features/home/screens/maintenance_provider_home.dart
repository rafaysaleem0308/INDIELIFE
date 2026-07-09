import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hello/core/services/api_service.dart';
import 'package:hello/features/profile/screens/profile.dart';
import 'package:url_launcher/url_launcher.dart';
import 'maintenance_profile_edit.dart';
import 'package:hello/features/services/screens/add_maintenance_service.dart';

class MaintenanceProviderHome extends StatefulWidget {
  const MaintenanceProviderHome({super.key});

  @override
  _MaintenanceProviderHomeState createState() =>
      _MaintenanceProviderHomeState();
}

class _MaintenanceProviderHomeState extends State<MaintenanceProviderHome>
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
        setState(() {
          _isAvailable = userData?['isAvailable'] ?? true;
        });
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _loadServices() async {
    try {
      final s = await ApiService.getServices();
      if (mounted) setState(() => _services = s.cast<Map<String, dynamic>>());
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
      backgroundColor: Color(0xFFF5F7FA),
      extendBody: true,
      appBar: _currentIndex == 0 ? _buildDashboardAppBar() : null,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF43cea2)))
          : SafeArea(child: _buildBody()),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  AppBar _buildDashboardAppBar() {
    String title = _currentIndex == 0
        ? "Maintenance Partner"
        : "Business Analytics";
    String sub = _currentIndex == 0
        ? "Manage jobs & requests"
        : "Track performance & earnings";
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      title: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              sub,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        if (_currentIndex == 0) ...[
          Row(
            children: [
              Text(
                _isAvailable ? "Ready" : "Busy",
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
                  onChanged: (v) async {
                    final res = await ApiService.updateAvailability(v);
                    if (res['success']) {
                      setState(() => _isAvailable = v);
                    }
                  },
                ),
              ),
            ],
          ),
          SizedBox(
            width: 32,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.forum_outlined,
                color: Color(0xFF43cea2),
                size: 20,
              ),
              onPressed: () => Navigator.pushNamed(context, '/my-chats'),
            ),
          ),
        ],
        SizedBox(width: 4),
      ],
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
        return _buildProfile();
      default:
        return Container();
    }
  }

  Widget _buildDashboard() {
    final requests = _orders
        .where((o) => (o['status'] ?? 'Pending') == 'Pending')
        .toList();
    final active = _orders
        .where(
          (o) => [
            'Confirmed',
            'Scheduled',
            'On the Way',
            'In Progress',
          ].contains(o['status']),
        )
        .toList(); // Active jobs
    final history = _orders
        .where(
          (o) => ['Completed', 'Cancelled', 'Rejected'].contains(o['status']),
        )
        .toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          _buildWelcomeHeader(),
          _buildQuickStats(),
          TabBar(
            labelColor: Color(0xFF43cea2),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF43cea2),
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: "New Job Requests (${requests.length})"),
              Tab(text: "Active Jobs (${active.length})"),
              Tab(text: "History"),
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
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              "Total Earnings",
              "PKR ${_stats['totalEarnings'] ?? 0}",
              Icons.wallet_outlined,
              Colors.teal,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _statCard(
              "Active Jobs",
              "${_stats['activeOrders'] ?? 0}",
              Icons.handyman_outlined,
              Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
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

  Widget _buildAnalytics() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Financial Overview",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          _largeStatCard(
            "Total Revenue",
            "PKR ${_stats['totalEarnings'] ?? 0}",
            Icons.payments_outlined,
            Colors.teal,
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _largeStatCard(
                  "Today",
                  "PKR ${_stats['todayEarnings'] ?? 0}",
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _largeStatCard(
                  "Jobs Done",
                  "${_stats['deliveredOrders'] ?? 0}",
                  Icons.assignment_turned_in_outlined,
                  Colors.blue,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Text(
            "Work Excellence",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          _performanceRow(
            "Job Completion",
            "${((_stats['completionRate'] ?? 0) * 100).toStringAsFixed(1)}%",
            Icons.verified_outlined,
            Colors.blueAccent,
          ),
          _performanceRow(
            "Skill Rating",
            "${(_stats['averageRating'] ?? 0).toStringAsFixed(1)}",
            Icons.star_border_rounded,
            Colors.orange,
          ),
          _performanceRow(
            "Total Requests",
            "${_stats['totalOrders'] ?? 0}",
            Icons.history_edu_outlined,
            Colors.indigo,
          ),
          _performanceRow(
            "Declined/Cancelled",
            "${_stats['cancelledOrders'] ?? 0}",
            Icons.cancel_presentation_outlined,
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
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
              Icon(icon, color: color, size: 24),
            ],
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _performanceRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 16),
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
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(
    List<Map<String, dynamic>> orders, {
    bool isRequest = false,
    bool isActive = false,
  }) {
    if (orders.isEmpty) return _buildEmptyOrders();
    return ListView.builder(
      padding: EdgeInsets.all(20),
      itemCount: orders.length,
      itemBuilder: (context, index) =>
          _orderCard(orders[index], isRequest: isRequest, isActive: isActive),
    );
  }

  Widget _buildWelcomeHeader() {
    bool isVerified = userData?['isVerified'] ?? false;
    return Container(
      margin: EdgeInsets.fromLTRB(20, 10, 20, 10),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF43cea2), Color(0xFF185a9d)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF43cea2).withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Icon(
                  Icons.handyman_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              if (isVerified)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, color: Colors.white, size: 12),
                  ),
                ),
            ],
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Hello, ${userData?['username'] ?? ''}",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (isVerified) SizedBox(width: 4),
                    if (isVerified)
                      Icon(Icons.verified, color: Colors.blue[100], size: 16),
                  ],
                ),
                Text(
                  "Service Specialist • ${userData?['city'] ?? 'Active'}",
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildEmptyOrders() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.assignment_ind_outlined, size: 48, color: Colors.grey[300]),
        SizedBox(height: 12),
        Text("No jobs found", style: GoogleFonts.inter(color: Colors.grey)),
      ],
    ),
  );

  Widget _orderCard(
    Map<String, dynamic> o, {
    bool isRequest = false,
    bool isActive = false,
  }) {
    Color sCol = (o['status'] == 'Completed')
        ? Colors.green
        : (o['status'] == 'Pending' ? Colors.orange : Colors.blueAccent);
    String displayStatus = o['status'] ?? 'Pending';
    String address = o['deliveryAddress'] ?? '';

    // Check for hire request special fields
    String jobDescription = o['specialInstructions'] ?? '';
    if (jobDescription.isEmpty && (o['items'] as List).isNotEmpty) {
      jobDescription = o['items'][0]['specialInstructions'] ?? '';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: sCol.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.work_outline_rounded, color: sCol, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Job #${o['orderNumber']?.toString().substring(0, 8) ?? o['_id']?.toString().substring(0, 6).toUpperCase()}",
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
                    color: Color(0xFF43cea2),
                    size: 20,
                  ),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/chat',
                    arguments: {
                      'receiverId': o['customerId']['_id'] ?? o['customerId'],
                      'otherUserName': o['customerName'] ?? 'Customer',
                      'serviceName': 'Maintenance Job',
                      'serviceId':
                          (o['items'] != null &&
                              (o['items'] as List).isNotEmpty)
                          ? o['items'][0]['serviceId']
                          : "",
                    },
                  ),
                ),
              if (address.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.directions_rounded,
                    color: Colors.blue,
                    size: 20,
                  ),
                  onPressed: () => launchUrl(
                    Uri.parse(
                      "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}",
                    ),
                  ),
                ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sCol.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  displayStatus,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: sCol,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          Divider(height: 24, thickness: 0.5),

          _detailRow(
            Icons.person_outline,
            "Customer",
            "${o['customerName'] ?? 'Guest'}",
          ),
          if (o['deliveryAddress'] != null)
            _detailRow(
              Icons.location_on_outlined,
              "Location",
              "${o['deliveryAddress']}",
            ),

          Divider(height: 24, thickness: 0.5),

          Text(
            "Job Details",
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),

          if (jobDescription.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                jobDescription,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
              ),
            )
          else
            Text("Standard Service", style: GoogleFonts.inter(fontSize: 13)),

          if (isRequest || isActive) SizedBox(height: 16),

          if (isRequest) ...[
            Container(
              height: 1,
              color: Colors.grey[100],
              margin: EdgeInsets.only(bottom: 16),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateStatus(o['_id'], 'Rejected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                    ),
                    child: Text("Decline"),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateStatus(o['_id'], 'Confirmed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text("Accept Job"),
                  ),
                ),
              ],
            ),
          ] else if (isActive) ...[
            Container(
              height: 1,
              color: Colors.grey[100],
              margin: EdgeInsets.only(bottom: 16),
            ),
            if (o['status'] == 'Confirmed')
              ElevatedButton(
                onPressed: () => _updateStatus(o['_id'], 'Scheduled'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 45),
                ),
                child: Text("Schedule Visit"),
              ),
            if (o['status'] == 'Scheduled')
              ElevatedButton(
                onPressed: () => _updateStatus(o['_id'], 'On the Way'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 45),
                ),
                child: Text("Mark On the Way"),
              ),
            if (o['status'] == 'On the Way')
              ElevatedButton(
                onPressed: () => _updateStatus(o['_id'], 'In Progress'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 45),
                ),
                child: Text("Start Work"),
              ),
            if (o['status'] == 'In Progress')
              ElevatedButton(
                onPressed: () => _updateStatus(o['_id'], 'Completed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 45),
                ),
                child: Text("Mark Job Completed"),
              ),
          ],
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.05, end: 0);
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          SizedBox(width: 12),
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

  Widget _buildServices() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "My Services",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: Color(0xFF43cea2),
            ),
            tooltip: "Add Service",
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddMaintenanceServiceForm(),
                ),
              );
              if (result == true) _loadServices();
            },
          ),
        ],
      ),
      body: _services.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.handyman_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "No services listed yet",
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
              itemCount: _services.length,
              itemBuilder: (context, i) {
                final s = _services[i];
                final imageUrl = s['imageUrl'];
                final hasImage =
                    imageUrl != null && imageUrl.toString().isNotEmpty;
                final services =
                    (s['servicesOffered'] as List?)?.join(', ') ?? '';
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
                      if (hasImage)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          child: Image.network(
                            ApiService.resolveImageUrl(imageUrl),
                            height: 130,
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
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF43cea2,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.build_rounded,
                                  color: Color(0xFF43cea2),
                                ),
                              ),
                            if (!hasImage) const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s['serviceName'] ?? 'Service',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    "PKR ${s['price']} / ${s['unit']}",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  if (services.isNotEmpty)
                                    Text(
                                      services,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.teal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
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
                                  foregroundColor: const Color(0xFF43cea2),
                                  side: const BorderSide(
                                    color: Color(0xFF43cea2),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddMaintenanceServiceForm(
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
          "Delete Service?",
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
              content: Text("Service deleted"),
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

  Widget _buildProfile() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Color(0xFF43cea2).withOpacity(0.1),
            child: Icon(Icons.person, size: 50, color: Color(0xFF43cea2)),
          ),
          SizedBox(height: 16),
          Text(
            userData?['username'] ?? 'Partner',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            userData?['email'] ?? '',
            style: GoogleFonts.inter(color: Colors.grey),
          ),
          SizedBox(height: 32),

          _profileOption(Icons.edit, "Edit Service Profile", () async {
            if (userData == null) return;
            final changed = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MaintenanceProfileEditScreen(userData: userData!),
              ),
            );
            if (changed == true) _loadUserData();
          }),
          _profileOption(Icons.settings, "App Settings", () {}),
          _profileOption(Icons.help_outline, "Help & Support", () {}),

          SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => ApiService.logout().then(
              (_) => Navigator.pushReplacementNamed(context, '/login'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: StadiumBorder(),
              padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            ),
            child: Text(
              "Logout",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileOption(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.black87),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: EdgeInsets.all(24),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.dashboard_rounded, 0),
          _navItem(Icons.handyman_rounded, 1),
          _navItem(Icons.list_alt_rounded, 2),
          _navItem(Icons.person_outline, 3),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, int idx) {
    bool sel = _currentIndex == idx;
    return GestureDetector(
      onTap: () {
        if (idx == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProfileScreen()),
          );
        } else {
          setState(() => _currentIndex = idx);
        }
      },
      child: AnimatedContainer(
        duration: 300.ms,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? Color(0xFF43cea2) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: sel ? Colors.white : Colors.white60, size: 24),
      ),
    );
  }
}
