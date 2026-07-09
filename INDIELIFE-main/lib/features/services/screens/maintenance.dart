import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hello/core/services/api_service.dart';
import 'maintenance_provider_detail.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  _MaintenanceScreenState createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  List<dynamic> allProviders = [];
  bool loading = true;
  String? errorMessage;
  bool _mounted = true;

  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Electrician', 'Plumber', 'AC Technician', 'Carpenter', 'Painter', 'Appliance Repair', 'Handyman'];

  @override
  void initState() {
    super.initState();
    _loadAllProviders();
    _searchController.addListener(() { setState(() {}); });
  }

  @override
  void dispose() { 
    _mounted = false; 
    _searchController.dispose();
    super.dispose(); 
  }

  List<dynamic> get _filteredProviders {
    return allProviders.where((p) {
      final name = '${p['firstName']} ${p['lastName']}'.toLowerCase();
      final serviceName = (p['serviceName'] ?? '').toLowerCase();
      final skills = (p['skills'] as List?)?.join(' ').toLowerCase() ?? '';
      final services = (p['servicesOffered'] as List?)?.join(' ').toLowerCase() ?? '';
      final search = _searchController.text.toLowerCase();
      
      final matchesSearch = name.contains(search) || serviceName.contains(search) || skills.contains(search) || services.contains(search);
      final matchesCategory = _selectedCategory == 'All' || 
                              serviceName.contains(_selectedCategory.toLowerCase()) || 
                              skills.contains(_selectedCategory.toLowerCase()) ||
                              services.contains(_selectedCategory.toLowerCase());
                              
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> _loadAllProviders() async {
    if (mounted) {
      setState(() {
      loading = true;
      errorMessage = null;
    });
    }
    
    try {
      final result = await ApiService.getServiceProvidersByType(
        'Maintenance',
      );
      
      if (_mounted && mounted) {
        setState(() {
          if (result['success'] == true) {
            allProviders = result['providers'] ?? [];
            errorMessage = null;
          } else {
            allProviders = [];
            errorMessage = result['message'] ?? 'Failed to load providers';
          }
          loading = false;
        });
      }
    } catch (e) {
      if (_mounted && mounted) {
        setState(() {
          allProviders = [];
          errorMessage = 'Network error. Please check your connection.';
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: loading 
          ? Center(child: CircularProgressIndicator(color: Color(0xFF11998e))) 
          : _buildProvidersList(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
      title: Text("Maintenance", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      flexibleSpace: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF11998e), Color(0xFF38ef7d)]))),
      leading: SafeArea(child: BackButton(color: Colors.white)),
    );
  }

  Widget _buildProvidersList() {
    // Error state
    if (errorMessage != null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          SizedBox(height: 16),
          Text(errorMessage!, style: GoogleFonts.poppins(color: Colors.grey), textAlign: TextAlign.center),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadAllProviders, // Keep retry for error recovery
            icon: Icon(Icons.refresh),
            label: Text("Retry"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF11998e),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ));
    }

    // Empty state
    if (allProviders.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.engineering, size: 64, color: Colors.grey[300]),
          SizedBox(height: 16),
          Text("No maintenance professionals found", style: GoogleFonts.poppins(color: Colors.grey)),
        ],
      ));
    }

    // Success state with providers
    return CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 120, 20, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text("Home Help", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
                Text("Verified professionals for your repairs", style: GoogleFonts.inter(color: Colors.grey)),
                SizedBox(height: 8),
                Text("${_filteredProviders.length} expert${_filteredProviders.length == 1 ? '' : 's'} available", 
                  style: GoogleFonts.inter(fontSize: 12, color: Color(0xFF11998e), fontWeight: FontWeight.w600)),
                SizedBox(height: 16),
                
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search for Electrician, Plumber...",
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: Icon(Icons.clear, color: Colors.grey), onPressed: () => _searchController.clear()) : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                SizedBox(height: 16),
                
                // Categories
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((c) {
                      final isSelected = _selectedCategory == c;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(c),
                          selected: isSelected,
                          onSelected: (sel) => setState(() => _selectedCategory = c),
                          backgroundColor: Colors.white,
                          selectedColor: Color(0xFF11998e).withOpacity(0.2),
                          checkmarkColor: Color(0xFF11998e),
                          labelStyle: GoogleFonts.inter(
                            color: isSelected ? Color(0xFF11998e) : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          shape: StadiumBorder(side: BorderSide(color: isSelected ? Color(0xFF11998e) : Colors.transparent)),
                          elevation: 0,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(height: 16),
              ]),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildProviderCard(_filteredProviders[index], index),
                childCount: _filteredProviders.length,
              ),
            ),
          ),
        ],
      );
  }

  Widget _buildProviderCard(dynamic p, int index) {
    final hasServices = p['servicesOffered'] != null && (p['servicesOffered'] as List).isNotEmpty;
    final servicesList = hasServices ? (p['servicesOffered'] as List).take(3).join(', ') : 'General Maintenance';
    final rating = p['rating']?.toString() ?? "New";
    final isVerified = p['isVerified'] == true;
    final expertise = p['serviceName']?.toString() ?? servicesList;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MaintenanceProviderDetailScreen(provider: p),
          ),
        ).then((_) => _loadAllProviders());
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(20), 
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06), 
              blurRadius: 15, 
              offset: Offset(0, 4),
              spreadRadius: 0,
            )
          ]
        ),
        child: Column(children: [
          // Header Image/Gradient
          Container(
            height: 120, 
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF11998e).withOpacity(0.85), Color(0xFF38ef7d).withOpacity(0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ), 
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              image: p['profileImage'] != null && p['profileImage'].isNotEmpty 
                ? DecorationImage(
                    image: NetworkImage(p['profileImage']), 
                    fit: BoxFit.cover, 
                    colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken)
                  )
                : null
            ), 
            child: Stack(
              children: [
                if (p['profileImage'] == null || p['profileImage'].isEmpty)
                  Center(
                    child: Icon(Icons.engineering_outlined, color: Colors.white.withOpacity(0.2), size: 70) 
                  ),
                if (isVerified)
                  Positioned(top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.verified, color: Colors.blue, size: 14),
                        const SizedBox(width: 4),
                        Text('Verified', style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue)),
                      ]),
                    )),
                 Positioned(bottom: 12, left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(rating, style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    ]),
                  )),
                 Positioned(bottom: 12, right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text('Available',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                    ]),
                  )),
              ]
            )
          ),
          
           Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(radius: 24,
                backgroundColor: const Color(0xFF11998e).withOpacity(0.1),
                child: Text(
                  (p['firstName'] ?? p['username'] ?? 'M')[0].toUpperCase(),
                  style: GoogleFonts.poppins(fontSize: 20,
                    fontWeight: FontWeight.bold, color: const Color(0xFF11998e)),
                )),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim().isEmpty 
                          ? (p['username'] ?? 'Expert') 
                          : '${p['firstName']} ${p['lastName']}',
                    style: GoogleFonts.poppins(fontSize: 16,
                      fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(expertise, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
                ],
              )),

            ]),
          ),
          if (hasServices)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text("Top Services", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                     SizedBox(height: 4),
                     Text(servicesList, style: GoogleFonts.inter(fontSize: 13, color: Colors.black87)),
                  ],
                ),
              ),
            ),
        ]),
      ).animate().fadeIn(delay: (index * 80).ms).slideY(begin: 0.15, end: 0),
    );
  }

}
