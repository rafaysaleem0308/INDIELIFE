import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hello/core/services/api_service.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  _GlobalSearchScreenState createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  List<dynamic> _results = [];
  List<dynamic> _featuredServices = [];
  List<dynamic> _topRatedServices = [];
  List<dynamic> _personalizedRecommendations = [];
  bool _isLoading = false;
  bool _isLoggedIn = false;
  final List<String> _categories = [
    'All',
    'Meal',
    'Laundry',
    'Hostel/Flat Accommodation',
    'Maintenance',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
    _performSearch('');
  }

  Future<void> _loadRecommendations() async {
    try {
      // Check if user is logged in
      final token = await ApiService.getToken();
      _isLoggedIn = token != null;

      List<dynamic> personalized = [];
      final featured = await ApiService.getFeaturedServices(limit: 5);
      final topRated = await ApiService.getTopRatedServices(limit: 6);

      // Load personalized recommendations if authenticated
      if (_isLoggedIn) {
        personalized = await ApiService.getPersonalizedRecommendations(
          limit: 8,
        );
      }

      if (mounted) {
        setState(() {
          _personalizedRecommendations = personalized;
          _featuredServices = featured;
          _topRatedServices = topRated;
        });
      }
    } catch (e) {
      print("Load recommendations error: $e");
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      // Track search interaction
      if (_isLoggedIn && query.isNotEmpty) {
        ApiService.trackInteraction(
          interactionType: 'search',
          serviceType: _selectedCategory != 'All' ? _selectedCategory : null,
          metadata: {'query': query, 'category': _selectedCategory},
        );
      }

      String? backendCategory;
      if (_selectedCategory == 'Meal') backendCategory = 'Meal Provider';
      if (_selectedCategory == 'Laundry') backendCategory = 'Laundry';
      if (_selectedCategory == 'Hostel/Flat Accommodation')
        backendCategory = 'Hostel/Flat Accommodation';
      if (_selectedCategory == 'Maintenance') backendCategory = 'Maintenance';

      final List<Map<String, dynamic>> searchResults =
          await ApiService.searchServices(query, backendCategory);

      if (mounted) {
        setState(() {
          _results = searchResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Search failed: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToResult(dynamic item) {
    final String type = item['serviceType'] ?? '';
    final String serviceId = item['_id']?.toString() ?? '';

    // Track service view interaction
    if (_isLoggedIn) {
      ApiService.trackInteraction(
        interactionType: 'click',
        serviceId: serviceId,
        serviceType: type,
        metadata: {'source': 'search'},
      );
    }

    if (type == 'Meal Provider') {
      Navigator.pushNamed(context, '/meal_info', arguments: item);
    } else if (type == 'Laundry') {
      Navigator.pushNamed(context, '/laundry_info', arguments: item);
    } else if (type == 'Hostel/Flat Accommodation') {
      Navigator.pushNamed(context, '/accommodation_info', arguments: item);
    } else if (type == 'Maintenance') {
      Navigator.pushNamed(context, '/maintenance_info', arguments: item);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasSearchQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchHeader(),
            _buildCategoryFilters(),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF9D42),
                      ),
                    )
                  : hasSearchQuery
                  ? (_results.isEmpty
                        ? _buildEmptyState()
                        : _buildResultsList())
                  : _buildRecommendationsView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsView() {
    // Filter recommendations by selected category
    List<dynamic> filteredFeatured = _featuredServices;
    List<dynamic> filteredTopRated = _topRatedServices;
    List<dynamic> filteredPersonalized = _personalizedRecommendations;

    if (_selectedCategory != 'All') {
      // Define which service types to show for each category
      List<String> targetTypes = [];

      if (_selectedCategory == 'Meal') {
        targetTypes = ['Meal Provider'];
      } else if (_selectedCategory == 'Laundry') {
        targetTypes = ['Laundry'];
      } else if (_selectedCategory == 'Hostel/Flat Accommodation') {
        targetTypes = ['Hostel/Flat Accommodation'];
      } else if (_selectedCategory == 'Maintenance') {
        targetTypes = ['Maintenance'];
      }

      // Filter each list
      filteredFeatured = _featuredServices.where((item) {
        String type = item['serviceType'] ?? '';
        return targetTypes.contains(type);
      }).toList();

      filteredTopRated = _topRatedServices.where((item) {
        String type = item['serviceType'] ?? '';
        return targetTypes.contains(type);
      }).toList();

      filteredPersonalized = _personalizedRecommendations.where((item) {
        String type = item['serviceType'] ?? '';
        return targetTypes.contains(type);
      }).toList();
    }

    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show category filter indicator if not "All"
          if (_selectedCategory != 'All') ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Color(0xFFFF9D42).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Showing: $_selectedCategory Services',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Color(0xFFFF9D42),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 20),
          ],

          // Personalized Recommendations Section (if logged in)
          if (_isLoggedIn && filteredPersonalized.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "🎯 Recommended For You",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: filteredPersonalized.length,
                itemBuilder: (context, i) =>
                    _buildFeaturedCard(filteredPersonalized[i], i),
              ),
            ),
            SizedBox(height: 28),
          ],

          // Featured Services Section
          if (filteredFeatured.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "✨ Featured Services",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: filteredFeatured.length,
                itemBuilder: (context, i) =>
                    _buildFeaturedCard(filteredFeatured[i], i),
              ),
            ),
            SizedBox(height: 28),
          ],

          // Top Rated Section
          if (filteredTopRated.isNotEmpty) ...[
            Text(
              "⭐ Top Rated Services",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Column(
              children: List.generate(
                filteredTopRated.length,
                (i) => _buildTopRatedCard(filteredTopRated[i], i),
              ),
            ),
            SizedBox(height: 20),
          ],

          // Show message if no services match filter
          if (_selectedCategory != 'All' &&
              filteredFeatured.isEmpty &&
              filteredTopRated.isEmpty &&
              filteredPersonalized.isEmpty) ...[
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.inbox_rounded,
                        size: 56,
                        color: Colors.grey[400],
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'No $_selectedCategory Services',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'There are currently no $_selectedCategory services available.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                    SizedBox(height: 24),
                    GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategory = 'All');
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFFFF9D42),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Browse All Services',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Services by Category (only show if "All" is selected)
          if (_selectedCategory == 'All') ...[
            SizedBox(height: 20),
            Text(
              "🛍️ Browse by Category",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            _buildCategoryQuickLinks(),
          ],
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(dynamic item, int index) {
    String serviceName = item['serviceName'] ?? 'Service';
    String price = item['price']?.toString() ?? '0';
    double rating = (item['rating'] ?? 0).toDouble();

    return GestureDetector(
      onTap: () => _navigateToResult(item),
      child: Container(
        width: 160,
        margin: EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF9D42), Color(0xFFFF512F)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Color(0xFFFF9D42).withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Featured",
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    serviceName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: Colors.amber),
                      SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "PKR $price",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ).animate().fadeIn().slideX(begin: 0.2, end: 0),
    );
  }

  Widget _buildTopRatedCard(dynamic item, int index) {
    String serviceName = item['serviceName'] ?? 'Service';
    String type = item['serviceType'] ?? 'Service';
    String price = item['price']?.toString() ?? '0';
    double rating = (item['rating'] ?? 0).toDouble();

    return GestureDetector(
      onTap: () => _navigateToResult(item),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(0xFFFF9D42).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCategoryIcon(type),
                color: Color(0xFFFF9D42),
                size: 22,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (i) => Icon(
                          Icons.star,
                          size: 12,
                          color: i < rating.toInt()
                              ? Colors.amber
                              : Colors.grey[300],
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        "$rating",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              "PKR $price",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF9D42),
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[300]),
          ],
        ),
      ).animate().fadeIn().slideX(begin: 0.1, end: 0),
    );
  }

  Widget _buildCategoryQuickLinks() {
    final categoryOptions = [
      {
        'name': 'Meals',
        'icon': Icons.restaurant_rounded,
        'color': Color(0xFFFF9D42),
        'category': 'Meal',
      },
      {
        'name': 'Laundry',
        'icon': Icons.local_laundry_service_rounded,
        'color': Color(0xFF2196F3),
        'category': 'Laundry',
      },
      {
        'name': 'Housing',
        'icon': Icons.home_work_rounded,
        'color': Color(0xFF8E2DE2),
        'category': 'Hostel/Flat Accommodation',
      },
      {
        'name': 'Maintenance',
        'icon': Icons.build_rounded,
        'color': Color(0xFF11998e),
        'category': 'Maintenance',
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: categoryOptions.map((cat) {
        return GestureDetector(
          onTap: () {
            setState(() => _selectedCategory = cat['category'] as String);
            _performSearch(_searchController.text);
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (cat['color'] as Color).withOpacity(0.1),
                  (cat['color'] as Color).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (cat['color'] as Color).withOpacity(0.2),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (cat['color'] as Color).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    cat['icon'] as IconData,
                    color: cat['color'] as Color,
                    size: 28,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  cat['name'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.black87,
                size: 20,
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            "Search Services",
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _performSearch,
              decoration: InputDecoration(
                hintText: "Search for providers...",
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Color(0xFFFF9D42),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1, end: 0);
  }

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          bool isSelected = _selectedCategory == _categories[i];
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategory = _categories[i]);
              _performSearch(_searchController.text);
            },
            child: Container(
              margin: EdgeInsets.only(right: 12),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Color(0xFFFF9D42) : Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Color(0xFFFF9D42).withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ]
                    : [],
              ),
              child: Text(
                _categories[i],
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[300]),
          SizedBox(height: 16),
          Text(
            "No services found",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Try different keywords or browse recommendations below",
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          if (_topRatedServices.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Popular services:",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _topRatedServices.length,
                      itemBuilder: (context, i) {
                        final service = _topRatedServices[i];
                        return GestureDetector(
                          onTap: () => _navigateToResult(service),
                          child: Container(
                            width: 140,
                            margin: EdgeInsets.only(right: 10),
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Color(0xFFFF9D42),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  service['serviceName'] ?? 'Service',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "PKR ${service['price']}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Color(0xFFFF9D42),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    // Filter results based on selected category
    List<dynamic> filteredResults = _results;

    if (_selectedCategory != 'All') {
      // Map UI category to backend service types
      List<String> targetTypes = [];
      if (_selectedCategory == 'Meal') {
        targetTypes = ['Meal Provider', 'meal provider', 'MealProvider'];
      } else if (_selectedCategory == 'Laundry') {
        targetTypes = ['Laundry', 'laundry'];
      } else if (_selectedCategory == 'Hostel/Flat Accommodation') {
        targetTypes = [
          'Hostel/Flat Accommodation',
          'hostel/flat accommodation',
        ];
      } else if (_selectedCategory == 'Maintenance') {
        targetTypes = ['Maintenance', 'maintenance'];
      }

      filteredResults = _results.where((item) {
        String type = item['serviceType'] ?? '';
        return targetTypes.contains(type);
      }).toList();
    }

    // Group filtered results by normalized service type
    Map<String, List<dynamic>> groupedResults = {};

    // Normalization map
    Map<String, String> typeNormalization = {
      'Meal Provider': 'Meal Provider',
      'meal provider': 'Meal Provider',
      'MealProvider': 'Meal Provider',
      'Laundry': 'Laundry',
      'laundry': 'Laundry',
      'Hostel/Flat Accommodation': 'Hostel/Flat Accommodation',
      'hostel/flat accommodation': 'Hostel/Flat Accommodation',
      'Maintenance': 'Maintenance',
      'maintenance': 'Maintenance',
    };

    for (var item in filteredResults) {
      String rawType = item['serviceType'] ?? 'Other';
      String normalizedType = typeNormalization[rawType] ?? 'Other';

      if (!groupedResults.containsKey(normalizedType)) {
        groupedResults[normalizedType] = [];
      }
      groupedResults[normalizedType]!.add(item);
    }

    // Define category order and names
    final categoryOrder = [
      'Meal Provider',
      'Laundry',
      'Hostel/Flat Accommodation',
      'Maintenance',
      'Other',
    ];

    final categoryNames = {
      'Meal Provider': '🍽️ Meals',
      'Laundry': '🧺 Laundry',
      'Hostel/Flat Accommodation': '🏠 Housing',
      'Maintenance': '🔧 Maintenance',
      'Other': '📋 Other Services',
    };

    if (filteredResults.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedCategory != 'All')
            Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFFFF9D42).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Filtering: $_selectedCategory',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Color(0xFFFF9D42),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          for (var category in categoryOrder)
            if (groupedResults.containsKey(category) &&
                groupedResults[category]!.isNotEmpty) ...[
              Text(
                categoryNames[category] ?? category,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              ...List.generate(
                groupedResults[category]!.length,
                (i) => _buildResultCard(groupedResults[category]![i], i),
              ),
              SizedBox(height: 24),
            ],
        ],
      ),
    );
  }

  Widget _buildResultCard(dynamic item, int index) {
    String serviceName = item['serviceName'] ?? item['name'] ?? 'Service';
    String providerName =
        item['serviceProviderName'] ?? item['providerName'] ?? 'Provider';
    String type = item['serviceType'] ?? 'Service';
    String price = item['price']?.toString() ?? '0';
    String unit = item['unit'] ?? '';

    // Build service-specific unit label
    String unitLabel = '';
    if (type == 'Meal Provider') {
      // For meals ONLY: show unit (per plate, per kg, etc.)
      unitLabel = unit.isNotEmpty ? "per $unit" : '';
      if (item['mealType'] != null && item['mealType'].toString().isNotEmpty) {
        unitLabel = item['mealType']; // e.g., "Main Course"
      }
    } else if (type == 'Laundry') {
      // For laundry: only show service type, NOT "per kg/piece"
      if (item['laundryType'] != null &&
          item['laundryType'].toString().isNotEmpty) {
        unitLabel =
            item['laundryType']; // e.g., "Standard Wash", "Dry Cleaning"
      }
    } else if (type == 'Hostel/Flat Accommodation') {
      // For housing: only show accommodation type
      if (item['accommodationType'] != null &&
          item['accommodationType'].toString().isNotEmpty) {
        unitLabel = item['accommodationType']; // e.g., "Single Room"
      }
    } else if (type == 'Maintenance') {
      // For maintenance: only show if there's a specific service type
      if (item['maintenanceType'] != null &&
          item['maintenanceType'].toString().isNotEmpty) {
        unitLabel = item['maintenanceType'];
      }
    }

    return GestureDetector(
      onTap: () => _navigateToResult(item),
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFFF9D42).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getCategoryIcon(type),
                color: Color(0xFFFF9D42),
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serviceName,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "By $providerName",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "PKR $price",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF9D42),
                  ),
                ),
                if (unitLabel.isNotEmpty)
                  Text(
                    unitLabel,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.grey[400],
                    ),
                  ),
              ],
            ),
            SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[300]),
          ],
        ),
      ).animate().fadeIn().slideX(begin: 0.1, end: 0),
    );
  }

  IconData _getCategoryIcon(String type) {
    if (type.contains('Meal')) return Icons.restaurant_rounded;
    if (type.contains('Laundry')) return Icons.local_laundry_service_rounded;
    if (type.contains('Accommodation')) return Icons.home_work_rounded;
    return Icons.engineering_rounded;
  }
}
