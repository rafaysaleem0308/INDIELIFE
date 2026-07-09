import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hello/core/services/api_service.dart';
import 'package:hello/shared/widgets/review_list_widget.dart';

class AccommodationScreen extends StatefulWidget {
  const AccommodationScreen({super.key});

  @override
  _AccommodationScreenState createState() => _AccommodationScreenState();
}

class _AccommodationScreenState extends State<AccommodationScreen> {
  List<dynamic> allProviders = [];
  bool loading = true;
  dynamic selectedProvider;
  bool showProviderDetails = false;
  bool _mounted = true;

  // Filters
  String _selectedType = 'All'; // All, Hostel, Flat, Room
  String _searchQuery = '';
  RangeValues _priceRange = RangeValues(0, 100000);
  final double _maxPrice = 100000;
  bool _isSharedFilter = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllProviders();
  }

  @override
  void dispose() {
    _mounted = false;
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllProviders() async {
    if (!_mounted) return;
    setState(() => loading = true);

    try {
      final result = await ApiService.getServiceProvidersByType(
        'Hostel/Flat Accommodation',
        city: _searchQuery.isNotEmpty ? _searchQuery : null,
        accommodationType: _selectedType != 'All' ? _selectedType : null,
        isShared: _isSharedFilter ? true : null,
        minPrice: _priceRange.start > 0 ? _priceRange.start : null,
        maxPrice: _priceRange.end < _maxPrice ? _priceRange.end : null,
      );

      if (_mounted) {
        final backendProviders = result['success'] == true ? (result['providers'] ?? []) : [];
        setState(() {
          allProviders = backendProviders;
          loading = false;
        });
      }
    } catch (e) {
      print("Error loading providers: $e");
      if (_mounted) {
        setState(() => loading = false);
        _showErrorSnackBar('Failed to load properties. Please check your connection.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (showProviderDetails && selectedProvider != null) {
      return _buildProviderDetails();
    }

    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Header + Search + Filters
          _buildHeader(),
          
          // Content
          Expanded(
            child: loading
                ? Center(child: CircularProgressIndicator(color: Color(0xFF2193b0)))
                : _buildProvidersList(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Icon(Icons.arrow_back, color: Colors.black, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
         IconButton(
          icon: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(Icons.tune, color: Colors.black, size: 20),
          ),
          onPressed: _showFilterBottomSheet,
        ),
        SizedBox(width: 16),
      ],
    );
  }

  // ... (Header and Categories remain same) ...
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 100, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Find your\nperfect stay", style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2)),
          SizedBox(height: 16),
          
          // Search Bar
          TextField(
            controller: _searchController,
            onSubmitted: (value) {
              setState(() => _searchQuery = value);
              _loadAllProviders();
            },
            decoration: InputDecoration(
              hintText: "Search for city, area...",
              hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.search, color: Colors.black87),
              filled: true,
              fillColor: Color(0xFFF5F7FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
          SizedBox(height: 20),

          // Categories
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _categoryChip("All", Icons.apps),
                _categoryChip("Hostel", Icons.apartment),
                _categoryChip("Flat", Icons.bedroom_parent_outlined),
                _categoryChip("Room", Icons.single_bed_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, IconData icon) {
    bool isSelected = _selectedType == label;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedType = label);
        _loadAllProviders();
      },
      child: Container(
        margin: EdgeInsets.only(right: 12),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? Colors.black : Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.black54),
            SizedBox(width: 8),
            Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildProvidersList() {
    if (allProviders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text("No properties found", style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600)),
            Text("Try adjusting your filters", style: GoogleFonts.inter(color: Colors.grey[400])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(20),
      itemCount: allProviders.length,
      itemBuilder: (context, index) {
        return _buildProviderCard(allProviders[index], index);
      },
    );
  }

  Widget _buildProviderCard(dynamic p, int index) {
    // Placeholder image logic
    return GestureDetector(
      onTap: () => setState(() { selectedProvider = p; showProviderDetails = true; }),
      child: Container(
        margin: EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Stack
            Stack(
              children: [
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    image: DecorationImage(
                      image: NetworkImage(p['imageUrl'] ?? 'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80'), // Fallback placeholder
                      fit: BoxFit.cover,
                      onError: (e, s) {}, // Handle error gracefully
                    ),
                    color: Colors.grey[200],
                  ),
                  child: p['imageUrl'] == null ? Center(child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 40)) : null,
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      "PKR ${p['price']}",
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                 if (p['isShared'] == true)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                      child: Text("Shared", style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)),
                    ),
                  ),
              ],
            ),
            
            // Content
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Expanded(
                         child: Text(
                            p['username'] ?? 'Listing',
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                       ),
                        Row(
                          children: [
                            Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                            SizedBox(width: 4),
                            Text("${p['rating'] ?? 'New'}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          ],
                        )
                     ],
                   ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                      SizedBox(width: 4),
                      Expanded(child: Text(p['city'] ?? 'Location', style: GoogleFonts.inter(color: Colors.grey))),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      _featureIcon(Icons.bed_outlined, "${p['availableRooms'] ?? 0} Rooms"),
                      SizedBox(width: 16),
                      _featureIcon(Icons.people_outline, "${p['currentOccupants']}/${p['maxOccupants']}"),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: (index * 50).ms).slideY(begin: 0.1, end: 0),
    );
  }

  Widget _featureIcon(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13)),
      ],
    );
  }

  // ... (buildProvidersList and buildProviderCard remain same) ...

  // --- DETAILS VIEW UPDATED ---
  Widget _buildProviderDetails() {
    final p = selectedProvider;
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.arrow_back, color: Colors.black, size: 20),
              ),
              onPressed: () => setState(() => showProviderDetails = false),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                p['imageUrl'] ?? 'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
                fit: BoxFit.cover,
                 errorBuilder: (c, o, s) => Container(color: Colors.grey[200], child: Center(child: Icon(Icons.apartment, size: 50, color: Colors.grey))),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['username'] ?? 'Property', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: Color(0xFF2193b0)),
                              SizedBox(width: 4),
                              Expanded(child: Text(p['address'] ?? 'No Address', style: GoogleFonts.inter(color: Colors.grey[600]))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text("PKR ${p['price']}", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2193b0))),
                        Text("per month", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                      ],
                    )
                  ],
                ),
                SizedBox(height: 32),
                
                // Stats
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                       _detailStat(Icons.king_bed_outlined, "${p['availableRooms'] ?? 0}", "Rooms"),
                       _detailStat(Icons.people_outline, "${p['currentOccupants']}/${p['maxOccupants']}", "Occupancy"),
                       _detailStat(Icons.wifi, "Included", "Wifi"), 
                    ],
                  ),
                ),
                
                SizedBox(height: 32),
                Text("About this place", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Text(
                  p['description'] ?? "No description available.",
                  style: GoogleFonts.inter(height: 1.6, color: Colors.grey[700], fontSize: 15),
                ),
                
                SizedBox(height: 32),
                Text("Hosted by", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 40, backgroundColor: Color(0xFF2193b0).withOpacity(0.1), child: Icon(Icons.home_work_rounded, size: 40, color: Color(0xFF2193b0))),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['providerName'] ?? 'Host', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                            Text("Joined recently", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: _handleChat, icon: Icon(Icons.chat_bubble_outline_rounded)),
                    ],
                  ),
                ),
                
                SizedBox(height: 32),
                ReviewListWidget(spId: p['serviceProviderId'] ?? p['_id'], themeColor: Color(0xFF2193b0)),

                 SizedBox(height: 100), // Spacing for bottom bar
              ]),
            ),
          )
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
           boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: Offset(0, -5))],
        ),
        child: SafeArea( // Ensure button is safe on notches
          child: ElevatedButton(
            onPressed: () => _handleBooking(p),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text("Book a Visit", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  void _handleBooking(dynamic provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Book a Visit?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to request a visit for this property? The host will be notified.", style: GoogleFonts.inter()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitVisitRequest(provider);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: StadiumBorder()),
            child: Text("Yes, Request Visit", style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitVisitRequest(dynamic provider) async {
    setState(() => loading = true);
    
    // Get current user ID (handled by ApiService using token)
    final userData = await ApiService.getUserData();
    final userId = userData['_id'];
    
    if (userId == null) {
      if (mounted) setState(() => loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please login to book a visit")));
      return;
    }

    final hireData = {
      'serviceProviderId': provider['serviceProviderId'] ?? provider['_id'],
      'userId': userId,
      'description': "Visit Request for ${provider['username']}",
      'date': DateTime.now().toString().substring(0, 10), // Current date for now
      'time': "Flexible",
    };

    try {
      final result = await ApiService.createHireRequest(hireData);
      
      if (mounted) setState(() => loading = false);

      if (mounted) {
        if (result['success'] == true) {
          // Close details view
          setState(() => showProviderDetails = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Visit Request Sent! Status: Pending"),
            backgroundColor: Colors.green,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Failed: ${result['message']}"),
            backgroundColor: Colors.red,
          ));
        }
      }
    } catch (e) {
      print("Error creating visit request: $e");
      if (mounted) {
        setState(() => loading = false);
        _showErrorSnackBar('Failed to submit request. Please try again.');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!_mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontSize: 14)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(20),
        action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              if (showProviderDetails && selectedProvider != null) {
                // If in details view, maybe retry booking? 
                // For now, simpler to just reload the main list if general error
                _loadAllProviders(); 
              } else {
                _loadAllProviders();
              }
            }
        ),
      ),
    );
  }

  // Helper Widgets
  Widget _detailStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Colors.black87),
        SizedBox(height: 8),
        Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  // Chats
  Future<void> _handleChat() async {
    final providerId = selectedProvider['serviceProviderId'] ?? selectedProvider['_id'];
    final result = await ApiService.startChat(providerId, selectedProvider['_id']);
    if (!mounted) return;
    if (result['success'] == true) {
      Navigator.pushNamed(context, '/chat', arguments: {
        'chatId': result['chat']['_id'],
        'otherUserName': selectedProvider['username'] ?? selectedProvider['serviceName'] ?? "Provider",
        'otherUserImage': selectedProvider['profileImage'] ?? "",
        'serviceName': selectedProvider['serviceName'] ?? selectedProvider['username'] ?? "Accommodation",
        'receiverId': providerId,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to start chat: ${result['message']}")));
    }
  }

  // Filter Bottom Sheet
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.all(24),
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                SizedBox(height: 24),
                Text("Filters", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 32),
                
                 Text("Price Range (PKR)", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                 RangeSlider(
                   values: _priceRange,
                   min: 0, 
                   max: _maxPrice,
                   divisions: 20,
                   activeColor: Colors.black,
                   inactiveColor: Colors.grey[200],
                   labels: RangeLabels("${_priceRange.start.round()}", "${_priceRange.end.round()}"),
                   onChanged: (v) => setSheetState(() => _priceRange = v),
                 ),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text("${_priceRange.start.round()}", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                     Text("${_priceRange.end.round()}+", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                   ],
                 ),
                 
                 SizedBox(height: 32),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text("Shared Accommodation", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                     Switch(
                       value: _isSharedFilter, 
                       onChanged: (v) => setSheetState(() => _isSharedFilter = v),
                       activeThumbColor: Colors.black,
                     ),
                   ],
                 ),
                 
                 Spacer(),
                 Row(
                   children: [
                     Expanded(
                       child: TextButton(
                         onPressed: () {
                           setState(() {
                             _priceRange = RangeValues(0, 100000);
                             _isSharedFilter = false;
                           });
                           Navigator.pop(context);
                           _loadAllProviders();
                         }, 
                         child: Text("Reset", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold))
                        ),
                     ),
                     SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                       child: ElevatedButton(
                         onPressed: () {
                           Navigator.pop(context);
                           _filterProviders();
                         },
                         style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: EdgeInsets.symmetric(vertical: 16)),
                         child: Text("Show listings", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                     ),
                   ],
                 )
              ],
            );
          }
        ),
      ),
    );
  }

  void _filterProviders() {
    setState(() {}); // Trigger rebuild to use new filter values (already updated state variables in modal)
    _loadAllProviders();
  }
}
