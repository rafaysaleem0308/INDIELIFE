import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hello/core/services/api_service.dart';
import 'package:intl/intl.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  _CommunityScreenState createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'News',
    'Offers',
    'Social',
    'Buy/Sell',
  ];

  List<dynamic> _posts = [];
  bool _isLoading = true;
  int _currentPage = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _postController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _postController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (_hasMore && !_isLoading) {
        _fetchPosts(page: _currentPage + 1);
      }
    }
  }

  Future<void> _fetchPosts({int page = 1}) async {
    if (page == 1) {
      setState(() => _isLoading = true);
    }

    try {
      final result = await ApiService.getCommunityPosts(
        page: page,
        limit: 20,
        category: _selectedCategory,
      );

      if (result['success'] == true) {
        if (page == 1) {
          setState(() {
            _posts = result['posts'] ?? [];
            _currentPage = 1;
            _hasMore = result['hasMore'] ?? false;
            _isLoading = false;
          });
        } else {
          setState(() {
            _posts.addAll(result['posts'] ?? []);
            _currentPage = page;
            _hasMore = result['hasMore'] ?? false;
          });
        }
      } else {
        _showErrorSnackBar(result['message'] ?? 'Failed to load posts');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading posts: $e');
      _showErrorSnackBar('Connection error. Please try again.');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createPost() async {
    if (_postController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter some text for your post');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          Center(child: CircularProgressIndicator(color: Color(0xFFFF9D42))),
    );

    try {
      final result = await ApiService.createCommunityPost({
        'content': _postController.text,
        'category': _selectedCategory == 'All' ? 'Social' : _selectedCategory,
      });

      if (mounted) Navigator.pop(context);

      if (result['success'] == true) {
        _postController.clear();
        _fetchPosts(page: 1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showErrorSnackBar(result['message'] ?? 'Failed to create post');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorSnackBar('Error creating post: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: _isLoading && _posts.isEmpty
          ? Center(child: CircularProgressIndicator(color: Color(0xFFFF9D42)))
          : CustomScrollView(
              controller: _scrollController,
              physics: BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(child: _buildCategoryFilters()),
                if (_posts.isEmpty && !_isLoading)
                  SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.forum_rounded,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No posts yet',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Be the first to share something!',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _buildPostCard(_posts[i], i),
                        childCount: _posts.length,
                      ),
                    ),
                  ),
                if (_isLoading && _posts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF9D42),
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePostDialog(),
        backgroundColor: Colors.black,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          "Post Something",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ).animate().scale(delay: 500.ms),
    );
  }

  void _showCreatePostDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Create Post",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "What's on your mind?",
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _postController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Share your thoughts...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFFFF9D42), width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _postController.clear();
              Navigator.pop(context);
            },
            child: Text("Cancel", style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createPost();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF9D42)),
            child: Text(
              "Post",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          "Neighborhood Hub",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 18,
          ),
        ),
        background: Stack(
          children: [
            Positioned(
              top: -50,
              right: -50,
              child: _blob(Color(0xFF4AC29A).withOpacity(0.1), 200),
            ),
            Positioned(
              bottom: 20,
              left: 30,
              child: _blob(Color(0xFFBDFFF3).withOpacity(0.2), 100),
            ),
            Center(
              child: Icon(
                Icons.forum_rounded,
                size: 80,
                color: Color(0xFF4AC29A).withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return Container(
      height: 60,
      margin: EdgeInsets.only(top: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 24),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          bool isSelected = _selectedCategory == _categories[i];
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategory = _categories[i]);
              _fetchPosts(page: 1);
            },
            child: AnimatedContainer(
              duration: 200.ms,
              margin: EdgeInsets.only(right: 12),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  _categories[i],
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostCard(dynamic post, int index) {
    // Provide default colors based on category if not in API
    final Map<String, Color> categoryColors = {
      'News': Color(0xFF4AC29A),
      'Offers': Color(0xFFFF9D42),
      'Social': Color(0xFF2196F3),
      'Buy/Sell': Color(0xFFFF6B9B),
    };

    final postCategory = post['category'] ?? 'Social';
    final postColor = categoryColors[postCategory] ?? Color(0xFF4AC29A);

    final createdAt = post['createdAt'] != null
        ? DateFormat('MMM dd, hh:mm').format(DateTime.parse(post['createdAt']))
        : 'Just now';

    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: postColor.withOpacity(0.1),
                child: Icon(Icons.person_rounded, color: postColor),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post['userName'] ?? 'Community Member',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      post['userRole'] ?? 'User',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              _typeBadge(postCategory, postColor),
            ],
          ),
          SizedBox(height: 16),
          Text(
            post['content'] ?? '',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              _interaction(
                Icons.favorite_border_rounded,
                (post['likes'] ?? 0).toString(),
              ),
              SizedBox(width: 20),
              _interaction(
                Icons.chat_bubble_outline_rounded,
                (post['comments'] ?? 0).toString(),
              ),
              Spacer(),
              Text(
                createdAt,
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1, end: 0);
  }

  Widget _typeBadge(String t, Color c) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: c.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      t,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: c,
      ),
    ),
  );

  Widget _interaction(IconData icon, String count) => Row(
    children: [
      Icon(icon, size: 18, color: Colors.grey[400]),
      SizedBox(width: 6),
      Text(
        count,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      ),
    ],
  );

  Widget _blob(Color c, double s) => Container(
    width: s,
    height: s,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}
