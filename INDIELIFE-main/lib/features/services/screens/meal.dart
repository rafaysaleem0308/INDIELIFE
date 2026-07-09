import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hello/core/services/api_service.dart';
import 'package:hello/shared/widgets/review_list_widget.dart';

class MealScreen extends StatefulWidget {
  const MealScreen({super.key});

  @override
  State<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen> with TickerProviderStateMixin {
  List<dynamic> allProviders = [];
  bool loading = true;
  dynamic selectedProvider;
  Map<String, dynamic>? userData;
  bool showProviderDetails = false;
  List<Map<String, dynamic>> cartItems = [];
  bool _mounted = true;
  String _selectedFilter = 'All';
  String _sortBy = 'rating';
  final ScrollController _scrollController = ScrollController();
  Timer? _refreshTimer;

  final List<Map<String, dynamic>> _filters = [
    {'label': 'All', 'icon': Icons.grid_view_rounded},
    {'label': 'Home Food', 'icon': Icons.soup_kitchen},
    {'label': 'Fast Food', 'icon': Icons.fastfood},
    {'label': 'Chinese', 'icon': Icons.ramen_dining},
    {'label': 'Healthy', 'icon': Icons.eco},
    {'label': 'Italian', 'icon': Icons.local_pizza},
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _loadCart(); // Initial cart load
    _refreshTimer = Timer.periodic(
      Duration(seconds: 15),
      (_) => _silentRefresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mounted = false;
    _scrollController.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (_mounted && mounted) setState(fn);
  }

  Future<void> _silentRefresh() async {
    _loadCart(); // Keep cart in sync
    if (showProviderDetails && selectedProvider != null) {
      await _loadProviderDetails(selectedProvider['_id'], silent: true);
    } else {
      await _loadAllMealProviders(silent: true);
    }
  }

  Future<void> _loadAllData() async {
    await _loadUserData();
    await _loadAllMealProviders();
  }

  Future<void> _loadUserData() async {
    try {
      final data = await ApiService.getUserData();
      _safeSetState(() => userData = data);
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _loadCart() async {
    final result = await ApiService.getCart();
    if (result['success'] == true && result['cart'] != null) {
      _safeSetState(() {
        cartItems = List<Map<String, dynamic>>.from(result['cart']['items']);
      });
    } else if (result['success'] == true && result['cart'] == null) {
      _safeSetState(() {
        cartItems = [];
      });
    }
  }

  Future<void> _loadAllMealProviders({bool silent = false}) async {
    if (!silent) _safeSetState(() => loading = true);
    try {
      final params = <String, String>{};
      if (_selectedFilter != 'All') params['cuisine'] = _selectedFilter;
      params['sortBy'] = _sortBy;
      final result = await ApiService.getMealProviders(
        cuisine: _selectedFilter == 'All' ? null : _selectedFilter,
        sortBy: _sortBy,
      );
      if (_mounted) {
        _safeSetState(() {
          allProviders = result['success'] == true
              ? (result['mealProviders'] ?? [])
              : [];
          loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading meal providers: $e');
      if (_mounted) {
        if (!silent) _safeSetState(() => loading = false);
        if (!silent) _showSnack('Failed to load providers', Colors.red);
      }
    }
  }

  Future<void> _loadProviderDetails(
    String providerId, {
    bool silent = false,
  }) async {
    if (!silent) _safeSetState(() => loading = true);
    try {
      final result = await ApiService.getMealProviderDetails(providerId);
      if (!_mounted) return;
      _safeSetState(() {
        if (result['success'] == true) {
          selectedProvider = result['provider'];
          if (selectedProvider != null && result['meals'] != null) {
            selectedProvider['meals'] = List<Map<String, dynamic>>.from(
              result['meals'],
            );
          }
        } else {
          selectedProvider = allProviders.firstWhere(
            (p) => p['_id'] == providerId,
            orElse: () => null,
          );
        }
        showProviderDetails = true;
        loading = false;
      });
    } catch (e) {
      debugPrint('Error loading provider details: $e');
      if (_mounted) {
        if (!silent) _safeSetState(() => loading = false);
        if (!silent) _showSnack('Failed to load provider details', Colors.red);
      }
    }
  }

  void _addToCart(Map<String, dynamic> meal) async {
    final providerId = selectedProvider?['_id'];
    if (providerId == null) return;

    final cartItemData = {
      'serviceId': meal['_id'],
      'providerId': providerId,
      'providerName': selectedProvider?['username']?.toString() ?? 'Chef',
      'serviceType': 'Meal Provider',
      'quantity': 1,
      'name':
          meal['name']?.toString() ?? meal['serviceName']?.toString() ?? 'Meal',
      'price': double.tryParse(meal['price'].toString()) ?? 0.0,
      'image': meal['imageUrl'] ?? meal['image'] ?? '',
      'instructions': '', // Optional
    };

    final result = await ApiService.addToCart(cartItemData);

    if (result['success'] == true) {
      _loadCart(); // Refresh cart
      _showSnack('${cartItemData['name']} added to cart!', Colors.green);
    } else if (result['conflict'] == true) {
      _showConflictDialog(cartItemData);
    } else {
      _showSnack(result['message'] ?? 'Failed to add to cart', Colors.red);
    }
  }

  void _showConflictDialog(Map<String, dynamic> pendingItem) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          "Clear Cart?",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Your cart contains items from another provider. Would you like to clear it and add this item instead?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.clearCart();
              final result = await ApiService.addToCart(pendingItem);
              if (result['success'] == true) {
                _loadCart();
                _showSnack(
                  '${pendingItem['name']} added to cart!',
                  Colors.green,
                );
              } else {
                _showSnack(result['message'] ?? 'Failed to add', Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("Clear & Add", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !showProviderDetails,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && showProviderDetails) {
          _safeSetState(() => showProviderDetails = false);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        body: loading
            ? _buildShimmerLoading()
            : (showProviderDetails
                  ? _buildProviderProfile()
                  : _buildDiscoveryScreen()),
        floatingActionButton: cartItems.isNotEmpty && showProviderDetails
            ? _buildCartFAB()
            : null,
      ),
    );
  }

  // ─── DISCOVERY SCREEN ───
  Widget _buildDiscoveryScreen() {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverAppBar(),
        SliverToBoxAdapter(child: _buildFilterChips()),
        SliverToBoxAdapter(child: _buildSortRow()),
        if (allProviders.isEmpty)
          SliverFillRemaining(child: _buildEmptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildProviderCard(allProviders[i], i),
                childCount: allProviders.length,
              ),
            ),
          ),
      ],
    );
  }

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFFF8F9FD),
      centerTitle: true,
      title: Text(
        'Discover Meals',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: BackButton(color: Colors.black),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filters.length,
        itemBuilder: (ctx, i) {
          final f = _filters[i];
          final sel = _selectedFilter == f['label'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: sel,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    f['icon'] as IconData,
                    size: 16,
                    color: sel ? Colors.white : const Color(0xFFFF512F),
                  ),
                  const SizedBox(width: 6),
                  Text(f['label'] as String),
                ],
              ),
              labelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : Colors.black87,
              ),
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFFFF512F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: sel ? Colors.transparent : Colors.grey.shade200,
                ),
              ),
              onSelected: (_) {
                _safeSetState(() => _selectedFilter = f['label'] as String);
                _loadAllMealProviders();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          Text(
            '${allProviders.length} chefs found',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                isDense: true,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
                items: const [
                  DropdownMenuItem(value: 'rating', child: Text('Top Rated')),
                  DropdownMenuItem(value: 'price', child: Text('Price')),
                  DropdownMenuItem(value: 'name', child: Text('Name')),
                ],
                onChanged: (v) {
                  _safeSetState(() => _sortBy = v!);
                  _loadAllMealProviders();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(dynamic provider, int index) {
    // Filter out 'Pakistani' just in case it exists in old data
    String cuisines =
        (provider['cuisineTypes'] as List?)
            ?.where((c) => c.toString().toLowerCase() != 'pakistani')
            .join(', ') ??
        'Specialty Food';
    if (cuisines.isEmpty) cuisines = 'Specialty Food';

    final rating = (provider['rating'] ?? 0).toStringAsFixed(1);
    final verified = provider['isVerified'] == true;
    final String time =
        provider['deliveryTime'] ?? provider['cookingTime'] ?? '30-45 mins';

    // Pictures
    final String? profileImage = provider['profileImage'];
    final String? bannerImage =
        provider['bannerImage'] ?? provider['coverImage'] ?? profileImage;

    return GestureDetector(
          onTap: () => _loadProviderDetails(provider['_id']),
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Banner Image (Restaurant Picture)
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    color: Colors.grey[200],
                    image:
                        bannerImage != null && bannerImage.toString().isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(
                              bannerImage.toString().startsWith('http')
                                  ? bannerImage.toString()
                                  : ApiService.resolveImageUrl(bannerImage),
                            ),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: bannerImage == null || bannerImage.toString().isEmpty
                      ? Center(
                          child: Icon(
                            Icons.restaurant,
                            color: Colors.grey[400],
                            size: 50,
                          ),
                        )
                      : null,
                ),

                // Info Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Restaurant Logo Picture
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF512F).withValues(alpha: 0.1),
                          image:
                              profileImage != null &&
                                  profileImage.toString().isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(
                                    profileImage.toString().startsWith('http')
                                        ? profileImage.toString()
                                        : ApiService.resolveImageUrl(
                                            profileImage,
                                          ),
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child:
                            profileImage == null ||
                                profileImage.toString().isEmpty
                            ? Center(
                                child: Text(
                                  (provider['username'] ?? 'C')
                                      .toString()[0]
                                      .toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFFF512F),
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    provider['username']?.toString() ??
                                        provider['firstName']?.toString() ??
                                        'Restaurant',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (verified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified,
                                    color: Colors.blue,
                                    size: 16,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cuisines,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  rating,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Icon(
                                  Icons.schedule,
                                  color: Colors.grey[500],
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  time,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.grey[700],
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
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (index * 80).ms, duration: 400.ms)
        .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic);
  }

  // ─── PROVIDER PROFILE ───
  Widget _buildProviderProfile() {
    final meals = (selectedProvider?['meals'] as List?) ?? [];
    final provName = selectedProvider?['username'] ?? 'Chef';
    final provCity = selectedProvider?['city'] ?? '';
    final rating = (selectedProvider?['rating'] ?? 0).toStringAsFixed(1);
    final verified = selectedProvider?['isVerified'] == true;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          backgroundColor: const Color(0xFFFF512F),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => _safeSetState(() => showProviderDetails = false),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.chat_outlined, color: Colors.white),
              onPressed: () => _startChatWithProvider(),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFF512F),
                    Color(0xFFFF9D42),
                    Color(0xFFFFB74D),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Text(
                        provName[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          provName,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      provCity,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Stats bar
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statCol(Icons.star_rounded, rating, 'Rating', Colors.amber),
                _divider(),
                _statCol(
                  Icons.restaurant_menu,
                  '${meals.length}',
                  'Meals',
                  const Color(0xFFFF512F),
                ),
                _divider(),
                _statCol(
                  Icons.timer_outlined,
                  selectedProvider?['deliveryTime'] ?? '30m',
                  'Delivery',
                  Colors.blue,
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.1),
        ),
        // Action buttons
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    Icons.chat_bubble_outline,
                    'Chat',
                    const Color(0xFF2196F3),
                    _startChatWithProvider,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionBtn(
                    Icons.phone_outlined,
                    'Call',
                    Colors.green,
                    () {},
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionBtn(
                    Icons.share_outlined,
                    'Share',
                    Colors.purple,
                    () {},
                  ),
                ),
              ],
            ),
          ),
        ),
        // Menu header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF512F),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Menu',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${meals.length} items',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        // Meals list
        if (meals.isEmpty)
          SliverToBoxAdapter(child: _buildEmptyMenuState())
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildMealItem(meals[i], i),
                childCount: meals.length,
              ),
            ),
          ),
        // Reviews section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF512F),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Reviews',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          sliver: SliverToBoxAdapter(
            child: ReviewListWidget(
              spId:
                  selectedProvider?['serviceProviderId'] ??
                  selectedProvider?['_id'] ??
                  '',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMealItem(Map<String, dynamic> meal, int index) {
    final name = meal['name'] ?? meal['serviceName'] ?? 'Meal';
    final desc = meal['description'] ?? '';
    final price = meal['price'] ?? 0;
    final mealType = meal['mealType'] ?? '';
    final isVeg = meal['isVegetarian'] == true;
    final prepTime = meal['preparationTime'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showMealBottomSheet(meal),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Meal image placeholder
              Container(
                width: 85,
                height: 85,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF9D42).withValues(alpha: 0.15),
                      const Color(0xFFFF512F).withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.lunch_dining,
                        color: const Color(0xFFFF512F).withValues(alpha: 0.4),
                        size: 36,
                      ),
                    ),
                    if (isVeg)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.eco,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (mealType.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFF9D42,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              mealType,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFFF512F),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'PKR $price',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                        const Spacer(),
                        if (prepTime.isNotEmpty) ...[
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            prepTime,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        GestureDetector(
                          onTap: () => _addToCart(meal),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF512F),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 20,
                            ),
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
      ),
    ).animate().fadeIn(delay: (index * 60).ms).slideX(begin: 0.08, end: 0);
  }

  // ─── MEAL DETAIL SHEET ───
  void _showMealBottomSheet(Map<String, dynamic> meal) {
    final name = meal['name'] ?? meal['serviceName'] ?? 'Meal';
    final desc = meal['description'] ?? 'Delicious home-cooked meal';
    final price = meal['price'] ?? 0;
    final ingredients = (meal['ingredients'] as List?) ?? [];
    final mealType = meal['mealType'] ?? '';
    final cuisineType = meal['cuisineType'] ?? '';
    final isVeg = meal['isVegetarian'] == true;
    final prepTime = meal['preparationTime'] ?? '25 min';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        builder: (context, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: controller,
            padding: EdgeInsets.zero,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Image area
              Container(
                height: 180,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9D42), Color(0xFFFF512F)],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.fastfood_rounded,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 64,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isVeg)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.eco,
                                  color: Colors.green,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Veg',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Tags
                    Wrap(
                      spacing: 8,
                      children: [
                        if (mealType.isNotEmpty)
                          _tag(mealType, Icons.lunch_dining),
                        if (cuisineType.isNotEmpty)
                          _tag(cuisineType, Icons.public),
                        _tag(prepTime, Icons.timer_outlined),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      desc,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    if (ingredients.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Ingredients',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ingredients
                            .map(
                              (i) => Chip(
                                label: Text(
                                  i.toString(),
                                  style: GoogleFonts.inter(fontSize: 12),
                                ),
                                backgroundColor: Colors.grey[100],
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Price + Add to Cart
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Price',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              'PKR $price',
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () {
                            _addToCart(meal);
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.add_shopping_cart, size: 20),
                          label: Text(
                            'Add to Cart',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF512F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── CART FAB ───
  Widget _buildCartFAB() {
    final total = cartItems.fold<double>(
      0,
      (sum, i) => sum + (double.tryParse(i['price'].toString()) ?? 0),
    );
    return FloatingActionButton.extended(
      onPressed: _showCartSheet,
      backgroundColor: const Color(0xFFFF512F),
      icon: Badge(
        label: Text(
          '${cartItems.length}',
          style: const TextStyle(fontSize: 10, color: Colors.white),
        ),
        child: const Icon(Icons.shopping_cart, color: Colors.white),
      ),
      label: Text(
        'PKR ${total.toStringAsFixed(0)}',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ).animate().slideY(begin: 1, end: 0).fadeIn();
  }

  void _showCartSheet() {
    final total = cartItems.fold<double>(
      0,
      (sum, i) => sum + (double.tryParse(i['price'].toString()) ?? 0),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Your Order',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await ApiService.clearCart();
                    _safeSetState(() => cartItems.clear());
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(
                    'Clear All',
                    style: GoogleFonts.inter(color: Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: cartItems.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (_, i) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9D42).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lunch_dining,
                      color: Color(0xFFFF512F),
                    ),
                  ),
                  title: Text(
                    cartItems[i]['name'],
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'by ${cartItems[i]['providerName']}',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: Text(
                    'PKR ${cartItems[i]['price']}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Total',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'PKR ${total.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/checkout',
                    arguments: {
                      'cartItems': cartItems,
                      'provider':
                          selectedProvider ??
                          {
                            '_id': cartItems[0]['providerId'],
                            'username': cartItems[0]['providerName'],
                          },
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF512F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Proceed to Checkout',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── CHAT ───
  Future<void> _startChatWithProvider() async {
    if (selectedProvider == null) return;
    final providerId = selectedProvider['_id'];
    try {
      final result = await ApiService.startChat(providerId, providerId);
      if (result['success'] == true && mounted) {
        Navigator.pushNamed(
          context,
          '/chat',
          arguments: {
            'chatId': result['chat']['_id'],
            'otherUserName': selectedProvider['username'] ?? 'Chef',
            'otherUserImage': selectedProvider['profileImage'] ?? '',
            'serviceName': 'Meal Service',
            'receiverId': providerId,
          },
        );
      } else {
        _showSnack('Failed to start chat', Colors.red);
      }
    } catch (e) {
      _showSnack('Chat error: $e', Colors.red);
    }
  }

  // ─── HELPERS ───
  Widget _statCol(IconData icon, String val, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          val,
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _divider() => Container(width: 1, height: 40, color: Colors.grey[200]);

  Widget _actionBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.no_meals_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No meal providers found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try changing your filter or check back later',
            style: GoogleFonts.inter(color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () {
              _safeSetState(() => _selectedFilter = 'All');
              _loadAllMealProviders();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reset Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMenuState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.menu_book_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'Menu coming soon',
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 80),
          ...List.generate(
            4,
            (i) =>
                Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(duration: 1200.ms, color: Colors.grey[100]),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!_mounted || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
