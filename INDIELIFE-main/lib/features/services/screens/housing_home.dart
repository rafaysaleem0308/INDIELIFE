import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hello/core/services/api_service.dart';
import 'package:hello/features/services/screens/housing_detail.dart';

class HousingHomeScreen extends StatefulWidget {
  const HousingHomeScreen({super.key});

  @override
  State<HousingHomeScreen> createState() => _HousingHomeScreenState();
}

class _HousingHomeScreenState extends State<HousingHomeScreen> {
  // ─── State ──────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _properties = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedType;
  String? _selectedCity;
  String _sortBy = 'createdAt';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _refreshTimer;

  final List<String> _propertyTypes = ['All', 'Room', 'Flat', 'Hostel', 'Apartment', 'Shared Room', 'Portion'];
  final List<String> _cities = ['All', 'Lahore', 'Karachi', 'Islamabad', 'Rawalpindi', 'Faisalabad', 'Multan', 'Gojra'];

  @override
  void initState() {
    super.initState();
    _loadProperties();
    _refreshTimer = Timer.periodic(Duration(seconds: 15), (_) => _loadProperties(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProperties({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final result = await ApiService.getHousingProperties(
        city: _selectedCity != null && _selectedCity != 'All' ? _selectedCity : null,
        propertyType: _selectedType != null && _selectedType != 'All' ? _selectedType : null,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        sortBy: _sortBy,
      );

      if (result['success'] == true && mounted) {
        setState(() {
          _properties = List<Map<String, dynamic>>.from(result['properties'] ?? []);
          _isLoading = false;
        });
      } else if (mounted) {
        if (!silent) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildSearchBar()),
          SliverToBoxAdapter(child: _buildTypeFilter()),
          SliverToBoxAdapter(child: _buildCityAndSortRow()),
          _isLoading ? _buildLoadingSliver() : _buildPropertyGrid(),
        ],
      ),
    );
  }

  // ─── App Bar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF8E2DE2),
      centerTitle: true,
      title: Text('Discover Housing', 
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF8E2DE2), Color(0xFF6A11CB)],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.favorite_outline_rounded, color: Colors.white),
          onPressed: () => Navigator.pushNamed(context, '/housing-favorites'),
        ),
      ],
    );
  }

  // ─── Search Bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: TextField(
          controller: _searchController,
          onSubmitted: (v) {
            _searchQuery = v;
            _loadProperties();
          },
          decoration: InputDecoration(
            hintText: 'Search by location, title...',
            hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF8E2DE2)),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                    _searchController.clear();
                    _searchQuery = '';
                    _loadProperties();
                  })
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
    );
  }

  // ─── Type Filter Chips ──────────────────────────────────────────────────────
  Widget _buildTypeFilter() {
    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _propertyTypes.length,
        itemBuilder: (_, i) {
          final type = _propertyTypes[i];
          final isSelected = (_selectedType ?? 'All') == type;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(type, style: GoogleFonts.inter(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              )),
              selected: isSelected,
              selectedColor: const Color(0xFF8E2DE2),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(color: isSelected ? const Color(0xFF8E2DE2) : Colors.grey.withValues(alpha: 0.3)),
              onSelected: (_) {
                setState(() => _selectedType = type == 'All' ? null : type);
                _loadProperties();
              },
            ),
          );
        },
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  // ─── City + Sort Row ────────────────────────────────────────────────────────
  Widget _buildCityAndSortRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCity ?? 'All',
                  isExpanded: true,
                  hint: Text('City', style: GoogleFonts.inter(fontSize: 13)),
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
                  items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) {
                    setState(() => _selectedCity = v == 'All' ? null : v);
                    _loadProperties();
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
                items: const [
                  DropdownMenuItem(value: 'createdAt', child: Text('Newest')),
                  DropdownMenuItem(value: 'monthlyRent', child: Text('Price ↑')),
                  DropdownMenuItem(value: 'rating', child: Text('Top Rated')),
                ],
                onChanged: (v) {
                  setState(() => _sortBy = v ?? 'createdAt');
                  _loadProperties();
                },
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }

  // ─── Loading State ──────────────────────────────────────────────────────────
  Widget _buildLoadingSliver() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF8E2DE2)),
            const SizedBox(height: 16),
            Text('Finding properties...', style: GoogleFonts.inter(color: Colors.grey.withValues(alpha: 0.5))),
          ],
        ),
      ),
    );
  }

  // ─── Property Grid ──────────────────────────────────────────────────────────
  Widget _buildPropertyGrid() {
    if (_properties.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.home_work_outlined, size: 80, color: Colors.grey.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text('No properties found', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.withValues(alpha: 0.4))),
              const SizedBox(height: 8),
              Text('Try adjusting your filters', style: GoogleFonts.inter(color: Colors.grey.withValues(alpha: 0.4))),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final property = _properties[index];
            return _PropertyCard(
              property: property,
              onTap: () {
                final id = property['_id']?.toString() ?? '';
                if (id.isNotEmpty) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => HousingDetailScreen(propertyId: id),
                  ));
                }
              },
            ).animate().fadeIn(delay: (100 * index).ms, duration: 500.ms).slideY(begin: 0.1);
          },
          childCount: _properties.length,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// Property Card Widget
// ════════════════════════════════════════════════════════════════════════════════
class _PropertyCard extends StatelessWidget {
  final Map<String, dynamic> property;
  final VoidCallback onTap;

  const _PropertyCard({required this.property, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final images = List<String>.from(property['images'] ?? []);
    final thumbnailImage = property['thumbnailImage'] ?? '';
    final displayImage = images.isNotEmpty ? images[0] : thumbnailImage;
    final hasImage = displayImage.toString().isNotEmpty && displayImage.toString().startsWith('http');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: hasImage
                    ? Image.network(displayImage, fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _placeholderImage())
                    : _placeholderImage(),
              ),
            ),
            // Property type badge overlay
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8E2DE2).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          property['propertyType'] ?? 'Property',
                          style: GoogleFonts.inter(color: const Color(0xFF4A00E0), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (property['roomType'] == 'Shared')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Shared', style: GoogleFonts.inter(color: Colors.blue[700], fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      const Spacer(),
                      Icon(Icons.star, color: Colors.amber[600], size: 16),
                      const SizedBox(width: 2),
                      Text(
                        (property['rating'] ?? 0).toStringAsFixed(1),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    property['title'] ?? 'Untitled',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    property['address'] ?? '',
                    style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Price + Owner
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Rs ${_formatPrice(property['monthlyRent'])}',
                              style: GoogleFonts.poppins(color: const Color(0xFF8E2DE2), fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            TextSpan(
                              text: '/mo',
                              style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: const Color(0xFF8E2DE2).withValues(alpha: 0.2),
                            child: Text(
                              (property['ownerName'] ?? 'O')[0].toUpperCase(),
                              style: GoogleFonts.poppins(color: const Color(0xFF4A00E0), fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            property['ownerName'] ?? 'Owner',
                            style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      color: const Color(0xFF8E2DE2).withValues(alpha: 0.1),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.home_work, size: 48, color: const Color(0xFF8E2DE2).withValues(alpha: 0.4)),
            const SizedBox(height: 4),
            Text('No Image', style: GoogleFonts.inter(color: Colors.grey.withValues(alpha: 0.4), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    num p;
    if (price is num) {
      p = price;
    } else {
      p = num.tryParse(price.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    }
    
    if (p >= 100000) return '${(p / 1000).toStringAsFixed(0)}K';
    if (p >= 1000) return '${(p / 1000).toStringAsFixed(1)}K';
    return p.toInt().toString();
  }
}
